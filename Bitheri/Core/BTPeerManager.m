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

#import "BTPeerManager.h"
#import "BTBloomFilter.h"
#import "BTTx.h"
#import "BTAddressManager.h"
#import <netdb.h>
#import "BTPeerProvider.h"
#import "BTTxProvider.h"

#if BITCOIN_TESTNET
static const char *dns_seeds[] = { "testnet-seed.bitcoin.petertodd.org", "testnet-seed.bluematt.me" };
#else // main net
static const char *dns_seeds[] = {
        "seed.bitcoin.sipa.be", "dnsseed.bluematt.me", "bitseed.xf2.org", "seed.bitcoinstats.com", "seed.bitnodes.io"
};
#endif

#define MAX_FAILED_COUNT (12)

NSString *const BITHERI_DONE_SYNC_FROM_SPV = @"bitheri_done_sync_from_spv";

@interface BTPeerManager ()

@property (nonatomic, strong) NSMutableSet *abandonPeers;
@property (nonatomic, assign) uint32_t tweak, syncStartHeight, filterUpdateHeight;
@property (nonatomic, strong) BTBloomFilter *bloomFilter;
@property (nonatomic, assign) double filterFpRate;
@property (nonatomic, assign) NSUInteger taskId, connectFailures;
//@property (nonatomic, assign) NSTimeInterval earliestKeyTime;
@property (nonatomic, assign) NSTimeInterval lastRelayTime;
@property (nonatomic, strong) NSMutableDictionary *txRelays;
@property (nonatomic, strong) NSMutableDictionary *publishedTx, *publishedCallback;
@property (nonatomic, strong) dispatch_queue_t q;
@property (nonatomic, strong) id activeObserver;
@property BOOL synchronizing;
@property BOOL running;

@end

@implementation BTPeerManager

+ (instancetype)sharedInstance {
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
    _q = dispatch_queue_create("net.bither.peermanager", NULL);
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

    _activeObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil
                                                               queue:nil usingBlock:^(NSNotification *note) {
                if (self.syncProgress >= 1.0)
                    [self.connectedPeers makeObjectsPerformSelector:@selector(disconnectPeer)];
            }];

    return self;
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if (self.activeObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.activeObserver];
}

- (uint32_t)lastBlockHeight {
    return self.blockChain.lastBlock.blockNo;
}

- (double)syncProgress {
    if (!self.downloadPeer) return (self.syncStartHeight == self.lastBlockHeight) ? 0.05 : 0.0;
    if (self.lastBlockHeight >= self.downloadPeer.versionLastBlock) return 1.0;
    return 0.1 + 0.9 * (self.lastBlockHeight - self.syncStartHeight) / (self.downloadPeer.versionLastBlock - self.syncStartHeight);
}

- (BOOL)doneSyncFromSPV {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults boolForKey:BITHERI_DONE_SYNC_FROM_SPV];
}

- (BTBloomFilter *)bloomFilter {
    if (_bloomFilter) return _bloomFilter;

    self.filterUpdateHeight = self.lastBlockHeight;
    self.filterFpRate = BLOOM_DEFAULT_FALSEPOSITIVE_RATE;

    if (self.lastBlockHeight + BLOCK_DIFFICULTY_INTERVAL < self.downloadPeer.versionLastBlock) {
        self.filterFpRate = BLOOM_REDUCED_FALSEPOSITIVE_RATE; // lower false positive rate during chain sync
    }
    else if (self.lastBlockHeight < self.downloadPeer.versionLastBlock) { // partially lower fp rate if we're nearly synced
        self.filterFpRate -= (BLOOM_DEFAULT_FALSEPOSITIVE_RATE - BLOOM_REDUCED_FALSEPOSITIVE_RATE) *
                (self.downloadPeer.versionLastBlock - self.lastBlockHeight) / BLOCK_DIFFICULTY_INTERVAL;
    }

    NSArray *outs = [[BTAddressManager sharedInstance] outs];
    NSUInteger elemCount = [[BTAddressManager sharedInstance] allAddresses].count * 2 + outs.count;
//    for (BTAddress *addr in [[BTAddressManager sharedInstance] allAddresses]){
//        elemCount += addr.unspentOuts.count;
//    }
    elemCount += 100;
    BTBloomFilter *filter = [[BTBloomFilter alloc] initWithFalsePositiveRate:self.filterFpRate
                                                             forElementCount:elemCount
                                                                       tweak:self.tweak flags:BLOOM_UPDATE_ALL];


    for (BTAddress *addr in [[BTAddressManager sharedInstance] allAddresses]) { // add addresses to watch for any tx receiveing money to the wallet
        NSData *hash = addr.address.addressToHash160;
        if (hash && ![filter containsData:hash]) [filter insertData:hash];

        if (addr.pubKey)
            [filter insertData:addr.pubKey];
    }

    for (NSData *utxo in outs) {
        if (![filter containsData:utxo]) [filter insertData:utxo];
    }

    _bloomFilter = filter;
    return _bloomFilter;
}

#pragma mark - peer & sync

- (NSArray *)bestPeers; {
    NSArray *bestPeers = [[BTPeerProvider instance] getPeersWithLimit:[BTSettings instance].maxPeerConnections];
    if (bestPeers.count < [BTSettings instance].maxPeerConnections) {
        [[BTPeerProvider instance] addPeers:[self getDnsPeers]];
        bestPeers = [[BTPeerProvider instance] getPeersWithLimit:[BTSettings instance].maxPeerConnections];
    }
    return bestPeers;
//    NSMutableArray *result = [NSMutableArray new];
//    for (BTPeerItem *peerItem in bestPeers) {
//        [result addObject:[[BTPeer alloc] initWithPeerItem:peerItem]];
//    }
//    return result;
}

- (NSArray *)getDnsPeers; {
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

- (void)connect {
    DDLogDebug(@"peer manager begin connect");
    // rebuild bloom filter
    _bloomFilter = nil;
    if (self.connectFailures >= MAX_CONNECT_FAILURES) self.connectFailures = 0; // this attempt is a manual retry
    self.running = YES;
    [self reconnect];
}

- (void)reconnect {
    if (!self.running)
        return;
    if (self.syncProgress < 1.0) {
        if (self.syncStartHeight == 0) self.syncStartHeight = self.lastBlockHeight;

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerSyncStartedNotification object:nil];
        });
    }

    dispatch_async(self.q, ^{
        [self.connectedPeers minusSet:[self.connectedPeers objectsPassingTest:^BOOL(id obj, BOOL *stop) {
            return [obj status] == BTPeerStatusDisconnected;
        }]];

        if (self.connectedPeers.count >= [BTSettings instance].maxPeerConnections)
            return; // we're already connected to [BTSettings instance].maxPeerConnections peers

        NSMutableOrderedSet *peers = [NSMutableOrderedSet orderedSetWithArray:[self bestPeers]];

        while (peers.count > 0 && self.connectedPeers.count < [BTSettings instance].maxPeerConnections) {
            // pick a random peer biased towards peers with more recent timestamps
            BTPeer *p = peers.firstObject;//peers[(NSUInteger)(pow(lrand48() % peers.count, 2)/peers.count)];

            BOOL isInConnectedPeers = NO;
            for (BTPeer *connectedPeer in [NSSet setWithSet:self.connectedPeers]) {
                isInConnectedPeers |= connectedPeer.peerAddress == p.peerAddress;
            }

            if (p && !isInConnectedPeers) {
                p.delegate = self;
                p.delegateQueue = self.q;
//                p.earliestKeyTime = self.earliestKeyTime;
                [self.connectedPeers addObject:p];
                [p connectPeer];
            }

            [peers removeObject:p];
        }

        if (self.connectedPeers.count == 0) {
            [self syncStopped];
            self.syncStartHeight = 0;

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerSyncFailedNotification
                                                                    object:nil userInfo:@{@"error" : [NSError errorWithDomain:@"bitheri" code:1
                                                                                                                     userInfo:@{NSLocalizedDescriptionKey : @"no peers found"}]}];
            });
        }
    });
}

- (void)disconnect {
    self.running = NO;
    self.connectFailures = MAX_CONNECT_FAILURES;
    // clear bloom filter
    _bloomFilter = nil;
    _connected = NO;
    NSSet *set = [NSSet setWithSet:self.connectedPeers];
    for (BTPeer *peer in set) {
        [peer disconnectPeer];
    }
    DDLogDebug(@"peer manager disconnect");
    dispatch_async(dispatch_get_main_queue(), ^{
        // todo: disconnect notification
    });
}

- (void)syncTimeout {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

    if (now - self.lastRelayTime < PROTOCOL_TIMEOUT) { // the download peer relayed something in time, so restart timer
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncTimeout) object:nil];
        [self performSelector:@selector(syncTimeout) withObject:nil
                   afterDelay:PROTOCOL_TIMEOUT - (now - self.lastRelayTime)];
    } else {
        DDLogDebug(@"%@:%d chain sync timed out", self.downloadPeer.host, self.downloadPeer.peerPort);
        self.synchronizing = NO;
//        [self.peers removeObject:self.downloadPeer];
        [self.downloadPeer disconnectPeer];
    }
}

- (void)syncStopped {
    self.synchronizing = NO;
//    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
//        [self.connectedPeers makeObjectsPerformSelector:@selector(disconnectPeer)];
//        [self.connectedPeers removeAllObjects];
//    }

    if (self.taskId != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
        self.taskId = UIBackgroundTaskInvalid;

        for (BTPeer *p in [NSSet setWithSet:self.connectedPeers]) { // after syncing, load filters and get mempools from the other peers
            if (p != self.downloadPeer) [p sendFilterLoadMessage:self.bloomFilter.data];
            for (BTTx *tx in self.publishedTx.allValues) {
                if (tx.source > 0 && tx.source <= MAX_PEERS_COUNT) {
                    [p sendInvMessageWithTxHash:tx.txHash];
                }
            }
            [p sendMemPoolMessage];
            //BUG: XXXX sometimes a peer relays thousands of transactions after mempool msg, should detect and
            // disconnect if it's more than BLOOM_DEFAULT_FALSEPOSITIVE_RATE*10*<typical mempool size>*2
        }
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

    [[BTAddressManager sharedInstance] registerTx:transaction withTxNotificationType:txSend];
    self.publishedTx[transaction.txHash] = transaction;

    if (completion) {
        completion(nil);
    }

    _bloomFilter = nil;
    for (BTPeer *p in [NSSet setWithSet:self.connectedPeers]) {
        [p sendFilterLoadMessage:self.bloomFilter.data];
    }

//    if (! self.connected) {
//        if (completion) {
//            completion([NSError errorWithDomain:@"bitheri" code:-1009
//                        userInfo:@{NSLocalizedDescriptionKey:@"not connected to the bitcoin network"}]);
//        }
//        return;
//    }

    // if (completion) self.publishedCallback[transaction.txHash] = completion;

    NSMutableSet *peers = [NSMutableSet setWithSet:self.connectedPeers];

    // instead of publishing to all peers, leave one out to see if the tx propogates and is relayed back to us
    if (peers.count > 1) [peers removeObject:[peers anyObject]];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(txTimeout:) withObject:transaction.txHash afterDelay:PROTOCOL_TIMEOUT];

        for (BTPeer *p in peers) {
            [p sendInvMessageWithTxHash:transaction.txHash];
        }
    });
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
        for (BTAddress *address in [[BTAddressManager sharedInstance] allAddresses]) {
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

    if (callback) {
        callback([NSError errorWithDomain:@"bitheri" code:ERR_PEER_TIMEOUT_CODE
                                 userInfo:@{NSLocalizedDescriptionKey : @"transaction canceled, network timeout"}]);
    }
}

// unconfirmed transactions that aren't in the mempools of any of connected peers have likely dropped off the network
- (void)removeUnrelayedTransactions {
    for (BTAddress *addr in [[BTAddressManager sharedInstance] allAddresses]) {
        for (BTTx *tx in addr.txs) {
            if (tx.blockNo != TX_UNCONFIRMED) break;
            if ([self.txRelays[tx.txHash] count] == 0 && tx.source == 0) [addr removeTx:tx.txHash];
        }
    }
}

#pragma mark - BTPeerDelegate

- (void)peerConnected:(BTPeer *)peer {
    DDLogDebug(@"%@:%d connected with lastblock %d", peer.host, peer.peerPort, peer.versionLastBlock);
    if (!self.running) {
        [peer disconnectPeer];
        return;
    }


    self.connectFailures = 0;
//    peer.timestamp = [NSDate timeIntervalSinceReferenceDate]; // set last seen timestamp for peer

    if (peer.versionLastBlock + 10 < self.lastBlockHeight) { // drop peers that aren't synced yet, we can't help them
//        [peer disconnectPeer];
        [self peerAbandon:peer];
        return;
    }

    [peer connectSucceed];
    if (self.connected && (self.downloadPeer.versionLastBlock >= peer.versionLastBlock || self.lastBlockHeight >= peer.versionLastBlock)) {
        if (self.lastBlockHeight < self.downloadPeer.versionLastBlock) return; // don't load bloom filter yet if we're syncing
        [peer sendFilterLoadMessage:self.bloomFilter.data];
        for (BTTx *tx in self.publishedTx.allValues) {
            if (tx.source > 0 && tx.source <= MAX_PEERS_COUNT) {
                [peer sendInvMessageWithTxHash:tx.txHash];
            }
        }
        [peer sendMemPoolMessage];
        return; // we're already connected to a download peer
    }

    // select the peer with the lowest ping time to download the chain from if we're behind
    for (BTPeer *p in [NSSet setWithSet:self.connectedPeers]) {
        if ((p.pingTime < peer.pingTime && p.versionLastBlock >= peer.versionLastBlock) || p.versionLastBlock > peer.versionLastBlock)
            peer = p;
    }

    [self.downloadPeer disconnectPeer];
    self.downloadPeer = peer;
    _connected = YES;

    // every time a new wallet address is added, the bloom filter has to be rebuilt, and each address is only used for
    // one transaction, so here we generate some spare addresses to avoid rebuilding the filter each time a wallet
    // transaction is encountered during the blockchain download (generates twice the external gap limit for both
    // address chains)

    _bloomFilter = nil; // make sure the bloom filter is updated with any newly generated addresses
    [peer sendFilterLoadMessage:self.bloomFilter.data];

    if (self.lastBlockHeight < peer.versionLastBlock) { // start blockchain sync
        if (self.taskId == UIBackgroundTaskInvalid) { // start a background task for the chain sync
            self.taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            }];
        }

        self.lastRelayTime = 0;

        dispatch_async(dispatch_get_main_queue(), ^{ // setup a timer to detect if the sync stalls
            self.synchronizing = YES;
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncTimeout) object:nil];
            [self performSelector:@selector(syncTimeout) withObject:nil afterDelay:PROTOCOL_TIMEOUT];

            // request just block headers up to a week before earliestKeyTime, and then merkleblocks after that
//            if (self.blockChain.lastBlock.blockTime-NSTimeIntervalSince1970 + ONE_WEEK >= self.earliestKeyTime) {
            if (self.doneSyncFromSPV) {
                [peer sendGetBlocksMessageWithLocators:[self.blockChain blockLocatorArray] andHashStop:nil];
            } else {
                [peer sendGetHeadersMessageWithLocators:[self.blockChain blockLocatorArray] andHashStop:nil];
            }
        });
    }
    else { // we're already synced
        [self syncStopped];
        [peer sendGetAddrMessage]; // request a list of other bitcoin peers
        self.syncStartHeight = 0;

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
}

- (void)peer:(BTPeer *)peer disconnectedWithError:(NSError *)error {
    if (error == nil) {
        [peer connectFail];
    } else if ([error.domain isEqual:@"bitheri"] && error.code == ERR_PEER_TIMEOUT_CODE) {
        if(peer.peerConnectedCnt > MAX_FAILED_COUNT){
            // Failed too many times, we don't want to play with it any more.
            [self peerAbandon:peer];
        }else {
            [peer connectFail];
        }
//        [self peerNetworkError:peer]; // if it's protocol error other than timeout, the peer isn't following the rules
    } else { // timeout or some non-protocol related network error
        [peer connectError];
//        [self.peers removeObject:peer];
        self.connectFailures++;
    }

    for (NSData *txHash in self.txRelays.allKeys) {
        [self.txRelays[txHash] removeObject:peer];
    }

    if ([self.downloadPeer isEqual:peer]) { // download peer disconnected
        _connected = NO;
        self.downloadPeer = nil;
        [self syncStopped];
        if (self.connectFailures > MAX_CONNECT_FAILURES)
            self.connectFailures = MAX_CONNECT_FAILURES;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.connected && self.connectFailures == MAX_CONNECT_FAILURES) {
            self.syncStartHeight = 0;
            [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerSyncFailedNotification
                                                                object:nil userInfo:error ? @{@"error" : error} : nil];
        }
        else if (self.connectFailures < MAX_CONNECT_FAILURES)
            [self reconnect]; // try connecting to another peer
    });
}

- (void)peer:(BTPeer *)peer relayedPeers:(NSArray *)peers {
    DDLogDebug(@"%@:%d relayed %d peer(s)", peer.host, peer.peerPort, (int) peers.count);
    if (peer == self.downloadPeer)
        self.lastRelayTime = [NSDate timeIntervalSinceReferenceDate];
    if ([peers count] > MAX_PEERS_COUNT) {
        peers = [peers subarrayWithRange:NSMakeRange(0, MAX_PEERS_COUNT)];
    }
    [self addRelayedPeers:peers];
}

- (void)peer:(BTPeer *)peer relayedTransaction:(BTTx *)transaction {
//    DDLogDebug(@"%@:%d relayed transaction %@", peer.host, peer.port, transaction.txHash);
    if (peer == self.downloadPeer) self.lastRelayTime = [NSDate timeIntervalSinceReferenceDate];

//    NSMutableArray *addrs = [NSMutableArray new];
//    for (BTAddress *addr in [[BTAddressManager sharedInstance] allAddresses]){
//        if ([addr registerTx:transaction withTxNotificationType:txReceive]){
//            [addrs addObject:addr];
//        }
//    }
    BOOL isAlreadyInDb = [[BTTxProvider instance] isExist:transaction.txHash];
    BOOL isRel = [[BTAddressManager sharedInstance] registerTx:transaction withTxNotificationType:txReceive];

    if (isRel) {
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

//        if (self.lastBlockHeight >= self.downloadPeer.lastBlock) { // if we're syncing, only update download peer
//            for (BTPeer *p in self.connectedPeers) {
//                [p sendFilterLoadMessage:self.bloomFilter.data];
//            }
//        } else {
//            [self.downloadPeer sendFilterLoadMessage:self.bloomFilter.data];
//        }

        // after adding addresses to the filter, re-request upcoming blocks that were requested using the old one
        [self.downloadPeer refetchBlocksFrom:[BTBlockChain instance].lastBlock.blockHash];

//        if ([self.txRelays[transaction.txHash] count] == self.connectedPeers.count) { // tx was relayed by all peers
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerTxNotification
//                                                                    object:@[transaction, @(txBroadcast)]];
//            });
//        }
    }
}

- (void)peer:(BTPeer *)peer relayedBlock:(BTBlock *)block {
    if (peer == self.downloadPeer) self.lastRelayTime = [NSDate timeIntervalSinceReferenceDate];

    // ignore block headers that are newer than one week before earliestKeyTime (headers have 0 totalTransactions)
//    if (block.totalTransactions == 0 && block.blockTime - NSTimeIntervalSince1970 + ONE_WEEK > self.earliestKeyTime) return;

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

    [self.blockChain relayedBlock:block withPeer:peer andCallback:^(BTBlock *b, BOOL isConfirm) {
        if (isConfirm) {
            if ((b.blockNo % 500) == 0 || b.txHashes.count > 0 || b.blockNo > peer.versionLastBlock) {
                DDLogDebug(@"%@:%d relayed block at height %d, false positive rate: %f", peer.host, peer.peerPort, b.blockNo, self.filterFpRate);
            }
            [self setBlockHeight:b.blockNo forTxHashes:b.txHashes];
        } else {
            DDLogDebug(@"%@:%d relayed block with invalid difficulty target %x, blockHash: %@", peer.host, peer.peerPort,
                            b.blockBits, b.blockHash);
            [self peerAbandon:peer];
        }
    }];

    if (block.blockNo == peer.versionLastBlock && block == self.blockChain.lastBlock) { // chain download is complete
        [self syncStopped];
        [peer sendGetAddrMessage]; // request a list of other bitcoin peers
        self.syncStartHeight = 0;

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
}

- (void)peer:(BTPeer *)peer relayedHeaders:(NSArray *)headers {
    if (headers == nil || headers.count == 0)
        return;

    if (peer == self.downloadPeer) {
        self.lastRelayTime = [NSDate timeIntervalSinceReferenceDate];
    }

    int oldLastBlockNo = [BTBlockChain instance].lastBlock.blockNo;
    int relayedCount = [[BTBlockChain instance] relayedBlockHeadersForMainChain:headers];
    if (relayedCount == headers.count) {
        DDLogDebug(@"Peer %@ relay %d block headers OK, last block No.%d, total block:%d", peer.host, relayedCount
        , [BTBlockChain instance].lastBlock.blockNo, [[BTBlockChain instance] getBlockCount]);
    } else {
        [self peerAbandon:peer];
        DDLogDebug(@"Peer %@ relay %d/%d block headers. drop this peer", peer.host, relayedCount
        , headers.count);
    }

    if (self.lastBlockHeight == peer.versionLastBlock) {
        [self syncStopped];
        [peer sendGetAddrMessage];
        self.syncStartHeight = 0;

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
}

- (BTTx *)peer:(BTPeer *)peer requestedTransaction:(NSData *)txHash {
    BTTx *tx = self.publishedTx[txHash];
    void (^callback)(NSError *error) = self.publishedCallback[txHash];

    if (tx) {
        // when publish tx , it is already register, so do not need register now and refresh bloom filter
//        [[BTAddressManager sharedInstance] registerTx:tx withTxNotificationType:txSend];
//        for (BTAddress *addr in [BTAddressManager sharedInstance].allAddresses){
//            [addr registerTx:tx withTxNotificationType:txSend];
//        }
        // refresh bloom filter
//        _bloomFilter = nil;
        if (!self.txRelays[txHash]) {
            self.txRelays[txHash] = [NSMutableSet set];
        }
        NSUInteger count = ((NSMutableSet *) self.txRelays[txHash]).count;
        [self.txRelays[txHash] addObject:peer];
        if (((NSMutableSet *) self.txRelays[txHash]).count > count) {
            [tx sawByPeer];
        }

//        if ([self.txRelays[txHash] count] == self.connectedPeers.count) {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [[NSNotificationCenter defaultCenter] postNotificationName:BTPeerManagerTxNotification
//                                                                    object:@[tx, @(txSend)]];
//            });
//        }

        [self.publishedCallback removeObjectForKey:txHash];

        dispatch_async(dispatch_get_main_queue(), ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(txTimeout:) object:txHash];
            if (callback) callback(nil);
        });
    }

    return tx;
}

- (NSData *)peerBloomFilter:(BTPeer *)peer {
    self.filterFpRate = self.bloomFilter.falsePositiveRate;
    self.filterUpdateHeight = self.lastBlockHeight;
    return self.bloomFilter.data;
}

@end
