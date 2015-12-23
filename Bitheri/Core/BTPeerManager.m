//
//  BTPeerManager.m
//  bitheri
//
//  Copyright 2014 http://Bither.net
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  Copyright (c) 2013-2014 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "BTPeerManager.h"
#import "BTBloomFilter.h"
#import "BTTx.h"
#import "BTAddressManager.h"
#import <netdb.h>
#import "BTPeerProvider.h"
#import "BTTxProvider.h"
#import <openssl/asn1t.h>
#import "BTHDAccount.h"

#if BITCOIN_TESTNET
static const char *dns_seeds[] = { "testnet-seed.bitcoin.petertodd.org", "testnet-seed.bluematt.me" };
#else // main net
static const char *dns_seeds[] = {
        "seed.bitcoin.sipa.be", "dnsseed.bluematt.me", "bitseed.xf2.org", "seed.bitcoinstats.com", "seed.bitnodes.io"
};
#endif

#define MAX_FAILED_COUNT (6)

NSString *const BITHERI_DONE_SYNC_FROM_SPV = @"bitheri_done_sync_from_spv";

@interface BTPeerManager ()

@property(nonatomic, strong) NSMutableSet *abandonPeers;
@property(nonatomic, assign) uint32_t tweak, syncStartHeight, filterUpdateHeight;
@property(nonatomic, strong) BTBloomFilter *bloomFilter;
@property(nonatomic, assign) double filterFpRate;
@property(nonatomic, assign) NSUInteger taskId, connectFailure;
//@property (nonatomic, assign) NSTimeInterval earliestKeyTime;
@property(nonatomic, assign) NSTimeInterval lastRelayTime;
@property(nonatomic, strong) NSMutableDictionary *txRelays;
@property(nonatomic, strong) NSMutableDictionary *publishedTx, *publishedCallback;
@property(nonatomic, strong) NSOperationQueue *q;
//@property (nonatomic, strong) id activeObserver;

@end

@implementation BTPeerManager

+ (instancetype)instance {
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^{
        srand48(time(NULL)); // seed psudo random number generator (for non-cryptographic use only!)
        singleton = [self new];
    });

    return singleton;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;

//    _earliestKeyTime = [[BTAddressManager sharedInstance] creationTime];
    _connectedPeers = [NSMutableSet set];
    _abandonPeers = [NSMutableSet set];
    _tweak = (uint32_t) mrand48();
    _taskId = UIBackgroundTaskInvalid;
    _q = [[NSOperationQueue alloc] init];
    _q.name = @"net.bither.peermanager";
    _q.maxConcurrentOperationCount = 1;
    if ([_q respondsToSelector:@selector(setQualityOfService:)]) {
        _q.qualityOfService = NSQualityOfServiceUserInitiated;
    }
    _txRelays = [NSMutableDictionary dictionary];
    _publishedTx = [NSMutableDictionary dictionary];
    _publishedCallback = [NSMutableDictionary dictionary];
    _blockChain = [BTBlockChain instance];
    _running = NO;
    _connected = NO;

    NSMutableArray *txs = [NSMutableArray arrayWithArray:[[BTTxProvider instance] getPublishedTxs]];

    for (BTTx *tx in txs) {
        if (tx.blockNo != TX_UNCONFIRMED) continue;
        self.publishedTx[tx.txHash] = tx; // add unconfirmed tx to mem pool
    }

//    _activeObserver =
//            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil
//                                                               queue:nil usingBlock:^(NSNotification *note) {
//                        if (self.syncProgress >= 1.0 || self.syncProgress < 0.1)
//                            [self stop];
//                    }];

    return self;
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
//    if (self.activeObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.activeObserver];
}

- (uint32_t)lastBlockHeight {
    return self.blockChain.lastBlock.blockNo;
}

- (double)syncProgress {
    if (self.synchronizing && self.syncStartHeight > 0 && self.downloadPeer != nil
            && self.lastBlockHeight >= self.syncStartHeight
            && self.lastBlockHeight <= self.downloadPeer.versionLastBlock) {
        return (double) (self.lastBlockHeight - self.syncStartHeight) / (double) (self.downloadPeer.versionLastBlock - self.syncStartHeight);
    } else {
        return -1.0;
    }
}

- (void)sendSyncProgressNotification; {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerSyncProgressNotification object:@(self.syncProgress)];
    });
}

- (BOOL)doneSyncFromSPV {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults boolForKey:BITHERI_DONE_SYNC_FROM_SPV];
}

- (void)requestBloomFilterRecalculate {
    _bloomFilter = nil;
}

- (BTBloomFilter *)bloomFilter {
    if (_bloomFilter) return _bloomFilter;

    self.filterUpdateHeight = self.lastBlockHeight;
    self.filterFpRate = BLOOM_DEFAULT_FALSEPOSITIVE_RATE;

    if (self.lastBlockHeight + 500 < self.downloadPeer.versionLastBlock) {
        self.filterFpRate = BLOOM_REDUCED_FALSEPOSITIVE_RATE; // lower false positive rate during chain sync
    }
    else if (self.lastBlockHeight < self.downloadPeer.versionLastBlock) { // partially lower fp rate if we're nearly synced
        self.filterFpRate -= (BLOOM_DEFAULT_FALSEPOSITIVE_RATE - BLOOM_REDUCED_FALSEPOSITIVE_RATE) *
                (self.downloadPeer.versionLastBlock - self.lastBlockHeight) / BLOCK_DIFFICULTY_INTERVAL;
    }

    NSArray *outs = [[BTAddressManager instance] outs];

    NSUInteger elemCount = [[BTAddressManager instance] allAddresses].count * 2 + outs.count + ([BTAddressManager instance].hasHDAccountHot ? [BTAddressManager instance].hdAccountHot.elementCountForBloomFilter : 0) + ([BTAddressManager instance].hasHDAccountMonitored ? [BTAddressManager instance].hdAccountMonitored.elementCountForBloomFilter : 0);
    elemCount += 100;
    BTBloomFilter *filter = [[BTBloomFilter alloc] initWithFalsePositiveRate:self.filterFpRate
                                                             forElementCount:elemCount
                                                                       tweak:self.tweak flags:BLOOM_UPDATE_ALL];


    for (BTAddress *addr in [[BTAddressManager instance] allAddresses]) { // add addresses to watch for any tx receiveing money to the wallet
        NSData *hash = addr.address.addressToHash160;
        if (hash && ![filter containsData:hash]) [filter insertData:hash];

        if (addr.pubKey)
            [filter insertData:addr.pubKey];
    }

    for (NSData *utxo in outs) {
        if (![filter containsData:utxo]) [filter insertData:utxo];
    }

    if ([BTAddressManager instance].hasHDAccountHot) {
        [[BTAddressManager instance].hdAccountHot addElementsForBloomFilter:filter];
    }

    if ([BTAddressManager instance].hasHDAccountMonitored) {
        [[BTAddressManager instance].hdAccountMonitored addElementsForBloomFilter:filter];
    }

    _bloomFilter = filter;
    return _bloomFilter;
}

- (int)waitingTaskCount; {
    return self.q.operationCount;
}

#pragma mark - peer & sync

- (NSArray *)bestPeers; {
    NSArray *bestPeers = [[BTPeerProvider instance] getPeersWithLimit:[self maxPeerCount]];
    if (bestPeers.count < [self maxPeerCount]) {
        [[BTPeerProvider instance] recreate];
        [[BTPeerProvider instance] addPeers:bestPeers];
        [[BTPeerProvider instance] addPeers:[self getPeersFromDns]];
        bestPeers = [[BTPeerProvider instance] getPeersWithLimit:[self maxPeerCount]];
    }
    return bestPeers;
}

- (NSArray *)getPeersFromDns; {
    NSMutableArray *result = [NSMutableArray new];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    for (int i = 0; i < sizeof(dns_seeds) / sizeof(*dns_seeds); i++) { // DNS peer discovery
        struct hostent *h = gethostbyname(dns_seeds[i]);

        for (int j = 0; h != NULL && h->h_addr_list[j] != NULL; j++) {
            uint32_t addr = CFSwapInt32BigToHost(((struct in_addr *) h->h_addr_list[j])->s_addr);

            // give dns peers a timestamp between 3 and 7 days ago
            [result addObject:[[BTPeer alloc] initWithAddress:addr port:BITCOIN_STANDARD_PORT
                                                    timestamp:now - 24 * 60 * 60 * (3 + drand48() * 4) services:NODE_NETWORK]];
        }
    }
    return result;
}

- (void)addRelayedPeers:(NSArray *)peers; {
    NSMutableArray *result = [NSMutableArray new];
    for (BTPeer *peer in peers) {
        if (![self.abandonPeers containsObject:@(peer.peerAddress)]) {
            [result addObject:peer];
        }
    }
    [[BTPeerProvider instance] addPeers:result];
    [[BTPeerProvider instance] cleanPeers];
}

- (void)start {
    // [self initAddress];
    if (!self.running) {
        DDLogDebug(@"peer manager start");
        self.running = YES;
        // rebuild bloom filter
        _bloomFilter = nil;
        if (self.connectFailure >= MAX_CONNECT_FAILURE_COUNT)
            self.connectFailure = 0; // this attempt is a manual retry
        if (self.connectedPeers.count > 0) {
            NSSet *set = [NSSet setWithSet:self.connectedPeers];
            for (BTPeer *peer in set) {
                [peer connectError];
                [self.abandonPeers addObject:@(peer.peerAddress)];
                [peer disconnectWithError:[NSError errorWithDomain:@"bitheri" code:ERR_PEER_DISCONNECT_CODE
                                                          userInfo:@{NSLocalizedDescriptionKey : @"peer is abandon"}]];
            }
            [self.connectedPeers removeAllObjects];
        }
        [self reconnect];
    }

}

- (void)initAddress {
    [self.q addOperationWithBlock:^{
        [[BTAddressManager instance] initAddress];
    }];
}

- (void)reconnect {
    if (!self.running)
        return;

    [self.q addOperationWithBlock:^{
        [self.connectedPeers minusSet:[self.connectedPeers objectsPassingTest:^BOOL(id obj, BOOL *stop) {
            return [obj status] == BTPeerStatusDisconnected;
        }]];

        if (self.connectedPeers.count >= [self maxPeerCount])
            return; // we're already connected to [self maxPeerCount] peers

        NSMutableOrderedSet *peers = [NSMutableOrderedSet orderedSetWithArray:[self bestPeers]];

        for (BTPeer *peer in peers) {
            if (self.connectedPeers.count >= [self maxPeerCount]) {
                break;
            }
            if (![self.connectedPeers containsObject:peer]) {
                [self.connectedPeers addObject:peer];
                peer.delegate = self;
//                peer.delegateQueue = self.q;
                [peer connectPeer];
            }
        }

        [self sendPeerCountChangeNotification:self.connectedPeers.count];
        if (self.connectedPeers.count == 0) {
            [self.downloadPeer setSynchronising:NO];
            [self syncStopped];

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerSyncFailedNotification
                                                                    object:nil userInfo:@{@"error" : [NSError errorWithDomain:@"bitheri" code:1
                                                                                                                     userInfo:@{NSLocalizedDescriptionKey : @"no peers found"}]}];
            });
        }
    }];
}

- (void)stop {
    if (self.running) {
        DDLogDebug(@"peer manager stop");
        self.running = NO;
        self.connectFailure = MAX_CONNECT_FAILURE_COUNT;
        // clear bloom filter
        _bloomFilter = nil;
        _connected = NO;
        self.syncStartHeight = 0;
        [self sendConnectedChangeNotification];
        [self sendSyncProgressNotification];
        [self.q addOperationWithBlock:^{
            NSSet *set = [NSSet setWithSet:self.connectedPeers];
            for (BTPeer *peer in set) {
                [peer disconnectPeer];
            }
        }];
    }
}

- (void)clearPeerAndRestart; {
    [self stop];
    [[BTPeerProvider instance] recreate];
    [self start];
}

- (void)syncTimeout {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

    if (now - self.lastRelayTime < PROTOCOL_TIMEOUT) { // the download peer relayed something in time, so restart timer
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncTimeout) object:nil];
        [self performSelector:@selector(syncTimeout) withObject:nil
                   afterDelay:PROTOCOL_TIMEOUT - (now - self.lastRelayTime)];
    } else {
        DDLogDebug(@"%@:%d chain sync timed out", self.downloadPeer.host, self.downloadPeer.peerPort);
//        [self.peers removeObject:self.downloadPeer];
        [self.downloadPeer disconnectPeer];
    }
}

- (void)syncStopped {
    self.synchronizing = NO;
    self.syncStartHeight = 0;
    [self sendSyncProgressNotification];
    if (self.taskId != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
        self.taskId = UIBackgroundTaskInvalid;
    }

    self.bloomFilter = nil;
    for (BTPeer *peer in [NSSet setWithSet:self.connectedPeers]) {
        [peer sendFilterLoadMessage:[self peerBloomFilter:peer]];
        for (BTTx *tx in self.publishedTx.allValues) {
            if (tx.source > 0 && tx.source <= MAX_PEERS_COUNT) {
                [peer sendInvMessageWithTxHash:tx.txHash];
            }
        }
        [peer sendMemPoolMessage];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncTimeout) object:nil];
    });
}

- (void)peerNetworkError:(BTPeer *)peer {
    [peer connectFail];
    [self.connectedPeers removeObject:peer];
}

- (void)peerAbandon:(BTPeer *)peer; {
    [peer connectError];
    [self.connectedPeers removeObject:peer];
    [self.abandonPeers addObject:@(peer.peerAddress)];
    [peer disconnectWithError:[NSError errorWithDomain:@"bitheri" code:ERR_PEER_DISCONNECT_CODE
                                              userInfo:@{NSLocalizedDescriptionKey : @"peer is abandon"}]];
    [self reconnect];
}

#pragma mark - publish tx;

- (void)publishTransaction:(BTTx *)transaction completion:(void (^)(NSError *error))completion {
    if (![transaction isSigned]) {
        if (completion) {
            completion([NSError errorWithDomain:@"bitheri" code:401
                                       userInfo:@{NSLocalizedDescriptionKey : @"bitcoin transaction not signed"}]);
        }
        return;
    }

    [[BTAddressManager instance] registerTx:transaction withTxNotificationType:txSend confirmed:NO];
    self.publishedTx[transaction.txHash] = transaction;

    if (completion) {
        completion(nil);
    }

//    _bloomFilter = nil;
//    for (BTPeer *p in [NSSet setWithSet:self.connectedPeers]) {
//        [p sendFilterLoadMessage:self.bloomFilter.data];
//    }

//    if (! self.connected) {
//        if (completion) {
//            completion([NSError errorWithDomain:@"bitheri" code:-1009
//                        userInfo:@{NSLocalizedDescriptionKey:@"not connected to the bitcoin network"}]);
//        }
//        return;
//    }

    // if (completion) self.publishedCallback[transaction.txHash] = completion;
    
    [self.q addOperationWithBlock:^{
        [self performSelector:@selector(txTimeout:) withObject:transaction.txHash afterDelay:PROTOCOL_TIMEOUT];
        
        NSMutableSet *peers = [NSMutableSet setWithSet:self.connectedPeers];
        for (BTPeer *p in peers) {
            [p sendInvMessageWithTxHash:transaction.txHash];
        }
    }];
}

// transaction is considered verified when all peers have relayed it
- (BOOL)transactionIsVerified:(NSData *)txHash {
    //BUG: XXXX received transactions remain unverified until disconnecting/reconnecting
    return [self.txRelays[txHash] count] >= self.connectedPeers.count;
}

- (void)setBlockHeight:(uint)height forTxHashes:(NSArray *)txHashes {
    if (height != TX_UNCONFIRMED) {
        // update all tx in db
        [[BTTxProvider instance] confirmTx:txHashes withBlockNo:height];
        // update all address 's tx and balance
        for (BTAddress *address in [[BTAddressManager instance] allAddresses]) {
            [address setBlockHeight:height forTxHashes:txHashes];
        }

        // remove confirmed tx from publish list and relay counts
        [self.publishedTx removeObjectsForKeys:txHashes];
        [self.publishedCallback removeObjectsForKeys:txHashes];
        [self.txRelays removeObjectsForKeys:txHashes];
    }
}

- (void)txTimeout:(NSData *)txHash {
    void (^callback)(NSError *error) = self.publishedCallback[txHash];

//    [self.publishedTx removeObjectForKey:txHash];
    [self.publishedCallback removeObjectForKey:txHash];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(txTimeout:) object:txHash];
    for (BTPeer *peer in self.connectedPeers) {
        [peer disconnectPeer];
    }
    if (callback) {
        callback([NSError errorWithDomain:@"bitheri" code:ERR_PEER_TIMEOUT_CODE
                                 userInfo:@{NSLocalizedDescriptionKey : @"transaction canceled, network timeout"}]);
    }
}

#pragma mark - BTPeerDelegate

- (void)peerConnected:(BTPeer *)peer {
    if (!self.running) {
        [peer disconnectPeer];
        return;
    }
    if (peer.versionLastBlock + 10 < self.lastBlockHeight) { // drop peers that aren't synced yet, we can't help them
        [self.q addOperationWithBlock:^{
            [self peerAbandon:peer];
        }];
        return;
    }

    [self.q addOperationWithBlock:^{
        DDLogDebug(@"%@:%d connected with lastblock %d", peer.host, peer.peerPort, peer.versionLastBlock);
        self.connectFailure = 0;
        if (!_connected) {
            _connected = YES;
            [self sendConnectedChangeNotification];
        }

        [peer connectSucceed];
        _bloomFilter = nil; // make sure the bloom filter is updated
        [peer sendFilterLoadMessage:[self peerBloomFilter:peer]];

        if (!self.doneSyncFromSPV && self.lastBlockHeight >= peer.versionLastBlock) {
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            [userDefaults setBool:YES forKey:BITHERI_DONE_SYNC_FROM_SPV];
            [userDefaults synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerSyncFromSPVFinishedNotification object:nil];
        }

        if (self.downloadPeer.versionLastBlock >= peer.versionLastBlock
                || self.lastBlockHeight >= peer.versionLastBlock) {
            if (self.lastBlockHeight < self.downloadPeer.versionLastBlock)
                return;
            for (BTTx *tx in self.publishedTx.allValues) {
                if (tx.source > 0 && tx.source <= MAX_PEERS_COUNT) {
                    [peer sendInvMessageWithTxHash:tx.txHash];
                }
            }
            [peer sendMemPoolMessage];
            return; // we're already connected to a download peer or do not need to sync from this peer
        }

        // select the peer with the lowest ping time to download the chain from if we're behind
        BTPeer *dPeer = peer;
        for (BTPeer *p in [NSSet setWithSet:self.connectedPeers]) {
            if ((p.pingTime < dPeer.pingTime && p.versionLastBlock >= dPeer.versionLastBlock) || p.versionLastBlock > dPeer.versionLastBlock)
                dPeer = p;
        }

        // ensure download peer has send bloom filter
        if (peer.peerAddress != dPeer.peerAddress) {
            [dPeer sendFilterLoadMessage:[self peerBloomFilter:peer]];
        }

        // start blockchain sync
        if (self.downloadPeer == nil || ![self.downloadPeer isEqual:dPeer]) {
            [self.downloadPeer disconnectPeer];
            self.downloadPeer = dPeer;
        }

        if (self.taskId == UIBackgroundTaskInvalid) { // start a background task for the chain sync
            self.taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            }];
        }

        self.lastRelayTime = [NSDate timeIntervalSinceReferenceDate];
        self.syncStartHeight = self.lastBlockHeight;
        DDLogDebug(@"%@:%d is downloading now", self.downloadPeer.host, self.downloadPeer.peerPort);
        self.synchronizing = YES;
        [self sendSyncProgressNotification];

        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncTimeout) object:nil];
        [self performSelector:@selector(syncTimeout) withObject:nil afterDelay:PROTOCOL_TIMEOUT];

        // request just block headers up to a week before earliestKeyTime, and then merkleblocks after that
        if (self.doneSyncFromSPV) {
            [dPeer sendGetBlocksMessageWithLocators:[self.blockChain blockLocatorArray] andHashStop:nil];
        } else {
            [dPeer sendGetHeadersMessageWithLocators:[self.blockChain blockLocatorArray] andHashStop:nil];
        }
        [dPeer setSynchronising:YES];
    }];
}

- (void)peer:(BTPeer *)peer disconnectedWithError:(NSError *)error {
    [self.q addOperationWithBlock:^{
        if (error == nil) {
            [self peerNetworkError:peer];
        } else if ([error.domain isEqual:@"bitheri"] && error.code == ERR_PEER_TIMEOUT_CODE) {
            if (peer.peerConnectedCnt > MAX_FAILED_COUNT) {
                // Failed too many times, we don't want to play with it any more.
                [self peerAbandon:peer];
            } else {
                [self peerNetworkError:peer];
//                [peer connectFail];
            }
//        [self peerNetworkError:peer]; // if it's protocol error other than timeout, the peer isn't following the rules
        } else { // timeout or some non-protocol related network error
            [peer connectError];
//        [self.peers removeObject:peer];
            self.connectFailure++;
        }

        for (NSData *txHash in self.txRelays.allKeys) {
            [self.txRelays[txHash] removeObject:peer];
        }

        if ([self.downloadPeer isEqual:peer]) { // download peer disconnected
            _connected = NO;
            [self.downloadPeer setSynchronising:NO];
            self.downloadPeer = nil;
            [self syncStopped];
            if (self.connectFailure > MAX_CONNECT_FAILURE_COUNT)
                self.connectFailure = MAX_CONNECT_FAILURE_COUNT;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.connected && self.connectFailure == MAX_CONNECT_FAILURE_COUNT) {
                [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerSyncFailedNotification
                                                                    object:nil userInfo:error ? @{@"error" : error} : nil];
            }
            else if (self.connectFailure < MAX_CONNECT_FAILURE_COUNT)
                [self reconnect]; // try connecting to another peer
        });
    }];
}

- (void)peer:(BTPeer *)peer relayedPeers:(NSArray *)peers {
    if (!self.running)
        return;
    DDLogDebug(@"%@:%d relayed %d peer(s)", peer.host, peer.peerPort, (int) peers.count);
    if (peer == self.downloadPeer)
        self.lastRelayTime = [NSDate timeIntervalSinceReferenceDate];
    // will add relay peer in future, for now only use dns peer
//    if ([peers count] > MAX_PEERS_COUNT) {
//        peers = [peers subarrayWithRange:NSMakeRange(0, MAX_PEERS_COUNT)];
//    }
//    [self addRelayedPeers:peers];
}

- (void)peer:(BTPeer *)peer relayedTransaction:(BTTx *)transaction confirmed:(BOOL) confirmed{
    if (!self.running)
        return;

    if (peer == self.downloadPeer) self.lastRelayTime = [NSDate timeIntervalSinceReferenceDate];

    [self.q addOperationWithBlock:^{
        BOOL isRel = [[BTAddressManager instance] registerTx:transaction withTxNotificationType:txReceive confirmed:confirmed];

        if (isRel) {
            BOOL isAlreadyInDb = [[BTTxProvider instance] isExist:transaction.txHash];
            if (self.publishedTx[transaction.txHash] == nil) {
                self.publishedTx[transaction.txHash] = transaction;
            }

            // keep track of how many peers relay a tx, this indicates how likely it is to be confirmed in future blocks
            if (!self.txRelays[transaction.txHash])
                self.txRelays[transaction.txHash] = [NSMutableSet set];

            NSUInteger count = ((NSMutableSet *) self.txRelays[transaction.txHash]).count;
            [self.txRelays[transaction.txHash] addObject:peer];
            if (((NSMutableSet *) self.txRelays[transaction.txHash]).count > count) {
                [transaction sawByPeer];
            }

            if (!isAlreadyInDb) {
                _bloomFilter = nil; // reset the filter so a new one will be created with the new wallet addresses

                for (BTPeer *p in [NSSet setWithSet:self.connectedPeers]) {
                    [p sendFilterLoadMessage:self.bloomFilter.data];
                }
            }
            // after adding addresses to the filter, re-request upcoming blocks that were requested using the old one
            [self.downloadPeer refetchBlocksFrom:[BTBlockChain instance].lastBlock.blockHash];
        }
    }];
}

- (void)peer:(BTPeer *)peer relayedHeaders:(NSArray *)headers {
    if (!self.running)
        return;
    if (headers == nil || headers.count == 0)
        return;

    if (peer == self.downloadPeer) {
        self.lastRelayTime = [NSDate timeIntervalSinceReferenceDate];
    }

    [self.q addOperationWithBlock:^{
        int oldLastBlockNo = [BTBlockChain instance].lastBlock.blockNo;
        int relayedCount = [[BTBlockChain instance] relayedBlockHeadersForMainChain:headers];
        if (relayedCount == headers.count) {
            [[BTAddressManager instance] blockChainChanged];
            DDLogDebug(@"%@:%d relay %d block headers OK, last block No.%d, total block:%d", peer.host, peer.peerPort, relayedCount, [BTBlockChain instance].lastBlock.blockNo, [[BTBlockChain instance] getBlockCount]);
        } else {
            [self peerAbandon:peer];
            DDLogDebug(@"%@:%d relay %d/%d block headers. drop this peer", peer.host, peer.peerPort, relayedCount, headers.count);
        }
        [self sendSyncProgressNotification];

        if (self.lastBlockHeight == peer.versionLastBlock) {
            [self.downloadPeer setSynchronising:NO];
            [self syncStopped];
            [peer sendGetAddrMessage];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.doneSyncFromSPV) {
                    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                    [userDefaults setBool:YES forKey:BITHERI_DONE_SYNC_FROM_SPV];
                    [userDefaults synchronize];
                    [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerSyncFromSPVFinishedNotification object:nil];
                } else {
                    [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerSyncFinishedNotification object:nil];
                }
            });
        }

        if (oldLastBlockNo != [BTBlockChain instance].lastBlock.blockNo) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerLastBlockChangedNotification object:nil];
            });
        }
    }];
}

- (void)peer:(BTPeer *)peer relayedBlock:(BTBlock *)block {
    if (!self.running)
        return;
    if (peer == self.downloadPeer) self.lastRelayTime = [NSDate timeIntervalSinceReferenceDate];

    [self.q addOperationWithBlock:^{
        // track the observed bloom filter false positive rate using a low pass filter to smooth out variance
        if (peer == self.downloadPeer && block.totalTransactions > 0) {
            // 1% low pass filter, also weights each block by total transactions, using 400 tx per block as typical
            self.filterFpRate = self.filterFpRate * (1.0 - 0.01 * block.totalTransactions / 400) + 0.01 * block.txHashes.count / 400;

            // todo: do not check bloom filter now. may be it's useful
//        if (self.filterFpRate > BLOOM_DEFAULT_FALSEPOSITIVE_RATE*10.0) { // false positive rate sanity check
//            DDLogDebug(@"%@:%d bloom filter false positive rate too high after %d blocks, disconnecting...", peer.host,
//                  peer.port, self.lastBlockHeight - self.filterUpdateHeight);
//            [self.downloadPeer disconnect];
//        }
        }

        NSData *oldLastHash = self.blockChain.lastBlock.blockHash;

        [self.blockChain relayedBlock:block withCallback:^(BTBlock *b, BOOL isConfirm) {
            if (isConfirm) {
                if ((b.blockNo % 500) == 0 || b.txHashes.count > 0 || b.blockNo > peer.versionLastBlock) {
                    DDLogDebug(@"%@:%d relayed block at height %d, false positive rate: %f", peer.host, peer.peerPort, b.blockNo, self.filterFpRate);
                }
                [self setBlockHeight:b.blockNo forTxHashes:b.txHashes];
                [[BTAddressManager instance] blockChainChanged];
            } else {
                DDLogDebug(@"%@:%d relayed block with invalid difficulty target %x, blockHash: %@", peer.host, peer.peerPort,
                        b.blockBits, b.blockHash);
                [self peerAbandon:peer];
            }
        }];
        [self sendSyncProgressNotification];

        if (block.blockNo == peer.versionLastBlock && block == self.blockChain.lastBlock) { // chain download is complete
            [self.downloadPeer setSynchronising:NO];
            [self syncStopped];
            [peer sendGetAddrMessage]; // request a list of other bitcoin peers

            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.doneSyncFromSPV) {
                    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                    [userDefaults setBool:YES forKey:BITHERI_DONE_SYNC_FROM_SPV];
                    [userDefaults synchronize];
                    [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerSyncFromSPVFinishedNotification object:nil];
                } else {
                    [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerSyncFinishedNotification object:nil];
                }
            });
        }

        // check if the next block was received as an orphan
        if (block == self.blockChain.lastBlock && self.blockChain.singleBlocks[block.blockHash]) {
            BTBlock *b = self.blockChain.singleBlocks[block.blockHash];

            [self.blockChain.singleBlocks removeObjectForKey:block.blockHash];
            [self peer:peer relayedBlock:b];
        }

        if (!self.synchronizing && ![self.blockChain.lastBlock.blockHash isEqualToData:oldLastHash]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerLastBlockChangedNotification object:nil];
            });
        }
    }];
}

- (void)peer:(BTPeer *)peer relayedBlocks:(NSArray *)blocks; {
    blocks = [NSArray arrayWithArray:blocks];
    if (!self.running)
        return;
    if (peer == self.downloadPeer)
        self.lastRelayTime = [NSDate timeIntervalSinceReferenceDate];
    else
        return;

    [self.q addOperationWithBlock:^{
        // track the observed bloom filter false positive rate using a low pass filter to smooth out variance
        for (BTBlock *block in blocks) {
            if (block.totalTransactions > 0) {
                // 1% low pass filter, also weights each block by total transactions, using 400 tx per block as typical
                self.filterFpRate = self.filterFpRate * (1.0 - 0.01 * block.totalTransactions / 400) + 0.01 * block.txHashes.count / 400;

                // todo: do not check bloom filter now. may be it's useful
//        if (self.filterFpRate > BLOOM_DEFAULT_FALSEPOSITIVE_RATE*10.0) { // false positive rate sanity check
//            DDLogDebug(@"%@:%d bloom filter false positive rate too high after %d blocks, disconnecting...", peer.host,
//                  peer.port, self.lastBlockHeight - self.filterUpdateHeight);
//            [self.downloadPeer disconnect];
//        }
            }
        }

        int relayedCnt = [self.blockChain relayedBlocks:blocks];
        if (relayedCnt > 0) {
            DDLogDebug(@"%@:%d relayed block at height %d, false positive rate: %f", peer.host, peer.peerPort, self.lastBlockHeight, self.filterFpRate);
            [self sendSyncProgressNotification];
            [[BTAddressManager instance] blockChainChanged];
            if (self.blockChain.lastBlock.blockNo >= peer.versionLastBlock) { // chain download is complete
                [self.downloadPeer setSynchronising:NO];
                [self syncStopped];
                [peer sendGetAddrMessage]; // request a list of other bitcoin peers

                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerSyncFinishedNotification object:nil];
                });
            }

            // check if the next block was received as an orphan
            if (self.blockChain.singleBlocks[self.blockChain.lastBlock.blockHash]) {
                BTBlock *b = self.blockChain.singleBlocks[self.blockChain.lastBlock.blockHash];

                [self.blockChain.singleBlocks removeObjectForKey:self.blockChain.lastBlock.blockHash];
                [self peer:peer relayedBlock:b];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerLastBlockChangedNotification object:nil];
            });
        } else {
            DDLogDebug(@"%@:%d relayed blocks failed", peer.host, peer.peerPort);
            [self peerAbandon:peer];
        }
    }];
}

- (BTTx *)peer:(BTPeer *)peer requestedTransaction:(NSData *)txHash {
    if (!self.running)
        return nil;
    BTTx *tx = self.publishedTx[txHash];
    void (^callback)(NSError *error) = self.publishedCallback[txHash];

    if (tx) {
        // refresh bloom filter
        _bloomFilter = nil;
        [self.q addOperationWithBlock:^{
            if (!self.txRelays[txHash]) {
                self.txRelays[txHash] = [NSMutableSet set];
            }
            NSUInteger count = ((NSMutableSet *) self.txRelays[txHash]).count;
            [self.txRelays[txHash] addObject:peer];
            if (((NSMutableSet *) self.txRelays[txHash]).count > count) {
                [tx sawByPeer];
            }

            [self.publishedCallback removeObjectForKey:txHash];

            dispatch_async(dispatch_get_main_queue(), ^{
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(txTimeout:) object:txHash];
                if (callback) callback(nil);
            });
        }];
    }
    return tx;
}

- (NSData *)peerBloomFilter:(BTPeer *)peer {
    self.filterFpRate = self.bloomFilter.falsePositiveRate;
    self.filterUpdateHeight = self.lastBlockHeight;
    return self.bloomFilter.data;
}

- (void)sendPeerCountChangeNotification:(int)peerNum; {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerPeerStateNotification
                                                            object:@{@"num_peers" : @(peerNum)}];
    });
}

- (void)sendConnectedChangeNotification; {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerConnectedChangedNotification
                                                            object:@{@"connected" : @(self.connected)}];
        DDLogDebug(@"peer manager availability changed to %d", self.connected);
    });
}

- (int)maxPeerCount; {
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if (state == UIApplicationStateBackground) {
        return [BTSettings instance].maxBackgroundPeerConnections;
    } else {
        return [BTSettings instance].maxPeerConnections;
    }
}

@end
