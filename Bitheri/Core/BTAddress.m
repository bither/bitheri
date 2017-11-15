//
//  BTAddress.m
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

#import "BTAddress.h"
#import "BTTxProvider.h"
#import "BTBlockChain.h"
#import "BTTxBuilder.h"
#import "BTIn.h"
#import "BTAddressProvider.h"
#import "BTHDAccount.h"

NSComparator const txComparator = ^NSComparisonResult(id obj1, id obj2) {
    BTTx *tx1 = (BTTx *) obj1;
    BTTx *tx2 = (BTTx *) obj2;
    if ([obj1 blockNo] > [obj2 blockNo]) return NSOrderedAscending;
    if ([obj1 blockNo] < [obj2 blockNo]) return NSOrderedDescending;
    NSMutableSet *inputHashSet1 = [NSMutableSet new];
    for (BTIn *in in tx1.ins) {
        [inputHashSet1 addObject:in.prevTxHash];
    }
    NSMutableSet *inputHashSet2 = [NSMutableSet new];
    for (BTIn *in in tx2.ins) {
        [inputHashSet2 addObject:in.prevTxHash];
    }
    if ([inputHashSet1 containsObject:[obj2 txHash]]) return NSOrderedAscending;
    if ([inputHashSet2 containsObject:[obj1 txHash]]) return NSOrderedDescending;
    if ([obj1 txTime] > [obj2 txTime]) return NSOrderedAscending;
    if ([obj1 txTime] < [obj2 txTime]) return NSOrderedDescending;
    return NSOrderedSame;
};

@interface BTAddress () {

}

@property(nonatomic, copy, readonly) NSString *encryptPrivKey;

@end

@implementation BTAddress {
    NSString *_address;
}

- (instancetype)initWithBitcoinjKey:(NSString *)encryptPrivKey withPassphrase:(NSString *)passphrase isSyncComplete:(BOOL)isSyncComplete {
    BTKey *key = [BTKey keyWithBitcoinj:encryptPrivKey andPassphrase:passphrase];
    return key ? [self initWithKey:key encryptPrivKey:encryptPrivKey isSyncComplete:isSyncComplete isXRandom:key.isFromXRandom] : nil;
}

- (instancetype)initWithKey:(BTKey *)key encryptPrivKey:(NSString *)encryptPrivKey isSyncComplete:(BOOL)isSyncComplete isXRandom:(BOOL)isXRandom {
    if (!(self = [super init])) return nil;
    _hasPrivKey = encryptPrivKey != nil;
    _encryptPrivKeyForCreate = encryptPrivKey;
    _address = key.address;
    _pubKey = key.publicKey;
    _isSyncComplete = isSyncComplete;
    _isFromXRandom = isXRandom;
    _txCount = 0;
    _recentlyTx = nil;
    return self;
}

- (instancetype)initWithAddress:(NSString *)address encryptPrivKey:(NSString *)encryptPrivKey pubKey:(NSData *)pubKey hasPrivKey:(BOOL)hasPrivKey isSyncComplete:(BOOL)isSyncComplete isXRandom:(BOOL)isXRandom {
    if (!(self = [super init])) return nil;

    _hasPrivKey = hasPrivKey;
    _encryptPrivKeyForCreate = encryptPrivKey;
    _address = address;
    _pubKey = pubKey;
    _isFromXRandom = isXRandom;
    _isSyncComplete = isSyncComplete;
    [self updateCache];

    return self;
}

- (instancetype)initWithWithPubKey:(NSString *)pubKey encryptPrivKey:(NSString *)encryptPrivKey isSyncComplete:(BOOL)isSyncComplete {
    if (!(self = [super init])) return nil;

    _hasPrivKey = encryptPrivKey != nil;
    _encryptPrivKeyForCreate = encryptPrivKey;
    _pubKey = [pubKey hexToData];
    _address = [NSString addressWithPubKey:_pubKey];
    _isFromXRandom = [BTKey isXRandom:encryptPrivKey];
    _isSyncComplete = isSyncComplete;
    [self updateCache];

    return self;
}

- (NSString *)address {
    return _address;
}

- (NSData *)scriptPubKey {
    NSMutableData *_scriptPubKey = [NSMutableData data];
    [_scriptPubKey appendScriptPubKeyForAddress:_address];
    return _scriptPubKey;
}

- (NSArray *)unspentOuts {
    NSMutableArray *result = [NSMutableArray new];
    for (BTOut *outItem in [[BTTxProvider instance] getUnSpendOutCanSpendWithAddress:self.address]) {
        [result addObject:getOutPoint(outItem.txHash, outItem.outSn)];
    }
    return result;
}

- (NSString *)encryptPrivKey {
    if (self.hasPrivKey) {
        return [[BTAddressProvider instance] getEncryptPrivKeyWith:[self address]];
    } else {
        return nil;
    }
}

- (NSString *)fullEncryptPrivKey {
    return [BTEncryptData encryptedString:self.encryptPrivKey addIsCompressed:self.pubKey.length == 33 andIsXRandom:self.isFromXRandom];
}

- (BOOL)isHDM {
    return NO;
}

- (BOOL)isCompressed {
    return self.pubKey.length == 33;
}

#pragma mark - manage tx

- (BOOL)initTxs:(NSArray *)txs {
    NSMutableArray *txItemList = [NSMutableArray new];
    for (BTTx *tx  in txs) {
        [txItemList addObject:tx];
    }
    [[BTTxProvider instance] addTxs:txItemList];

    if ([txs count] > 0) {
        uint64_t oldBalance = _balance;
        [self updateCache];
        int deltaBalance = (int) (_balance - oldBalance);
        dispatch_async(dispatch_get_main_queue(), ^{
            DDLogWarn(@"[notification]%@ recieve some tx, delta balance is %d", _address, deltaBalance);
            [[NSNotificationCenter defaultCenter] postNotificationName:BitherBalanceChangedNotification object:@[_address, @(deltaBalance), [NSNull null], @(txFromApi)]];
        });
    }
    return YES;
}

- (void)registerTx:(BTTx *)tx withTxNotificationType:(TxNotificationType)txNotificationType; {
    uint64_t oldBalance = _balance;
    [self updateCache];
    if (_balance != oldBalance) {
        int deltaBalance = (int) (_balance - oldBalance);
        DDLogWarn(@"[notification]%@ recieve tx[%@], delta balance is %d", _address, [NSString hexWithHash:tx.txHash], deltaBalance);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:BitherBalanceChangedNotification
                                                                object:@[_address, @(_balance - oldBalance), tx, @(txNotificationType)]];
        });
    }
}

- (void)removeTx:(NSData *)txHash {
    [[BTTxProvider instance] remove:txHash];
}

- (void)setBlockHeight:(uint)height forTxHashes:(NSArray *)txHashes {
    NSMutableArray *needUpdateTxHash = [NSMutableArray new];
    for (NSData *hash in txHashes) {
        BTTx *tx = [[BTTxProvider instance] getTxDetailByTxHash:hash];
        if (!tx || tx.blockNo == height) continue;
        tx.blockNo = height;
        [needUpdateTxHash addObject:tx.txHash];
    }

    if (needUpdateTxHash.count > 0) {
        uint64_t oldBalance = _balance;
        [self updateCache];
        if (_balance != oldBalance) {
            dispatch_async(dispatch_get_main_queue(), ^{
                int deltaBalance = (int) (_balance - oldBalance);
                DDLogWarn(@"[notification]%@ remove some double spend tx, delta balance is %d", _address, deltaBalance);
                [[NSNotificationCenter defaultCenter] postNotificationName:BitherBalanceChangedNotification
                                                                    object:@[_address, @(_balance - oldBalance), [NSNull null], @(txDoubleSpend)]];
            });
        }
    }
}


#pragma mark - update status

- (void)updateCache; {
    [self updateBalance];
    _txCount = [[BTTxProvider instance] txCount:_address];
    [self updateRecentlyTx];
}

- (void)updateBalance {
    _balance = [[BTTxProvider instance] getConfirmedBalanceWithAddress:self.address] + [self calculateUnconfirmedBalance];
}

- (uint64_t)calculateUnconfirmedBalance {
    uint64_t balance = 0;
    NSMutableOrderedSet *utxos = [NSMutableOrderedSet orderedSet];
    NSMutableSet *spentOutputs = [NSMutableSet set], *invalidTx = [NSMutableSet set];

    NSMutableArray *txs = [NSMutableArray arrayWithArray:[[BTTxProvider instance] getUnconfirmedTxWithAddress:self.address]];
    [txs sortUsingComparator:txComparator];

    for (BTTx *tx in [txs reverseObjectEnumerator]) {
        NSMutableSet *spent = [NSMutableSet set];

        for (BTIn *btIn in tx.ins) {
            [spent addObject:getOutPoint(btIn.prevTxHash, btIn.prevOutSn)];
        }

        // check if any inputs are invalid or already spent
        NSMutableSet *inputHashSet = [NSMutableSet new];
        for (BTIn *in in tx.ins) {
            [inputHashSet addObject:in.prevTxHash];
        }
        if (tx.blockNo == TX_UNCONFIRMED &&
                ([spent intersectsSet:spentOutputs] || [inputHashSet intersectsSet:invalidTx])) {
            [invalidTx addObject:tx.txHash];
            continue;
        }

        [spentOutputs unionSet:spent]; // add inputs to spent output set

        for (BTOut *out in tx.outs) { // add outputs to UTXO set
            if ([self.address isEqualToString:out.outAddress]) {
                [utxos addObject:getOutPoint(tx.txHash, out.outSn)];
                balance += out.outValue;
            }
        }

        // transaction ordering is not guaranteed, so check the entire UTXO set against the entire spent output set
        [spent setSet:[utxos set]];
        [spent intersectSet:spentOutputs];

        for (NSData *o in spent) { // remove any spent outputs from UTXO set
            BTTx *transaction = [[BTTxProvider instance] getTxDetailByTxHash:[o hashAtOffset:0]];
            uint n = [o UInt32AtOffset:CC_SHA256_DIGEST_LENGTH];

            [utxos removeObject:o];
            balance -= [transaction getOut:n].outValue;
        }
    }
    return balance;
}

- (void)updateRecentlyTx; {
    NSArray *txs = [self getRecentlyTxsWithConfirmationCntLessThan:6 andLimit:1];
    if (txs != nil && [txs count] > 0) {
        _recentlyTx = txs[0];
    } else {
        _recentlyTx = nil;
    }
}

- (NSArray *)getRecentlyTxsWithConfirmationCntLessThan:(int)confirmationCnt andLimit:(int)limit; {
    int blockNo = [BTBlockChain instance].lastBlock.blockNo - confirmationCnt + 1;
    return [[BTTxProvider instance] getRecentlyTxsByAddress:self.address andGreaterThanBlockNo:blockNo andLimit:limit];
}

- (void)updateSyncComplete; {
    [[BTAddressProvider instance] updateSyncComplete:self];
}


#pragma mark - send tx

- (BTTx *)txForAmounts:(NSArray *)amounts andAddress:(NSArray *)addresses andError:(NSError **)error {
    return [self txForAmounts:amounts andAddress:addresses andChangeAddress:self.address andError:error];
}

- (BTTx *)txForAmounts:(NSArray *)amounts andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andError:(NSError **)error {
    return [self txForAmounts:amounts andAddress:addresses andChangeAddress:changeAddress andError:error coin:BTC];
}

- (BTTx *)txForAmounts:(NSArray *)amounts andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andError:(NSError **)error coin:(Coin)coin {
    BTTx *tx = [[BTTxBuilder instance] buildTxForAddress:self andScriptPubKey:self.scriptPubKey andAmount:amounts andAddress:addresses andChangeAddress:changeAddress andError:error coin:coin];
    if (tx != nil) {
        tx.coin = coin;
    }
    return tx;
}

- (NSArray *)splitCoinTxsForAmounts:(NSArray *)amounts andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andError:(NSError **)error coin:(Coin)coin {
    NSArray *txs = [[BTTxBuilder instance] buildSplitCoinTxsForAddress:self andScriptPubKey:self.scriptPubKey andAmount:amounts andAddress:addresses andChangeAddress:changeAddress andError:error coin:coin];
    return txs;
}

- (NSArray *)bccTxsForAmounts:(NSArray *)amounts andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andUnspentOuts:(NSArray *)unspentOuts andError:(NSError **)error {
    NSArray *txs = [[BTTxBuilder instance]buildBccTxsForAddress:self andScriptPubKey:self.scriptPubKey andAmount:amounts andAddress:addresses andChangeAddress:changeAddress andUnspentOuts:unspentOuts andError:error];
    
    return txs;
}

// sign any inputs in the given transaction that can be signed using private keys from the wallet
- (BOOL)signTransaction:(BTTx *)transaction withPassphrase:(NSString *)passphrase; {
    [transaction signWithPrivateKeys:@[[BTKey keyWithBitcoinj:self.fullEncryptPrivKey andPassphrase:passphrase].privateKey]];
    return [transaction isSigned];
}

- (BOOL)signTransaction:(BTTx *)transaction withPassphrase:(NSString *)passphrase andUnspentOuts:(NSArray*) unspentOuts; {
    [transaction signWithPrivateKeys:@[[BTKey keyWithBitcoinj:self.fullEncryptPrivKey andPassphrase:passphrase].privateKey] andUnspentOuts:unspentOuts];
    return [transaction isSigned];
}

- (NSArray *)signHashes:(NSArray *)unsignedInHashes withPassphrase:(NSString *)passphrase; {
    BTKey *key = [BTKey keyWithBitcoinj:self.fullEncryptPrivKey andPassphrase:passphrase];
    NSMutableArray *result = [NSMutableArray new];
    for (NSData *hash in unsignedInHashes) {
        NSMutableData *sig = [NSMutableData data];
        NSMutableData *s = [NSMutableData dataWithData:[key sign:hash]];

        [s appendUInt8:SIG_HASH_ALL];
        [sig appendScriptPushData:s];
        [sig appendScriptPushData:[key publicKey]];
        [result addObject:sig];
    }
    return result;
}

- (NSString *)signMessage:(NSString *)message withPassphrase:(NSString *)passphrase; {
    BTKey *key = [BTKey keyWithBitcoinj:self.fullEncryptPrivKey andPassphrase:passphrase];
    return [key signMessage:message];
}


#pragma mark - query tx

- (NSArray *)txs:(int)page {
    return [self sortTxs:[[BTTxProvider instance] getTxAndDetailByAddress:self.address andPage:page]];
}

- (NSArray *)sortTxs:(NSArray *)txs; {
    NSMutableArray *result = [NSMutableArray arrayWithArray:txs];
    [result sortUsingComparator:txComparator];
    return result;
}

// returns the amount received to the wallet by the transaction (total outputs to change and/or recieve addresses)
- (uint64_t)amountReceivedFromTransaction:(BTTx *)transaction {
    uint64_t amount = 0;

    for (BTOut *out in transaction.outs) {
        if ([self.address isEqualToString:out.outAddress])
            amount += out.outValue;
    }

    return amount;
}

// returns the amount sent from the wallet by the transaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(BTTx *)transaction {
    uint64_t amount = 0;

    for (BTIn *btIn in transaction.ins) {
        BTTx *tx = [[BTTxProvider instance] getTxDetailByTxHash:btIn.prevTxHash];
        uint32_t n = btIn.prevOutSn;

        BTOut *out = [tx getOut:n];
        if ([self.address isEqualToString:out.outAddress]) {
            amount += out.outValue;
        }
    }

    return amount;
}

// returns the fee for the given transaction if all its inputs are from wallet transactions, UINT64_MAX otherwise
- (uint64_t)feeForTransaction:(BTTx *)transaction {
    uint64_t amount = 0;

    for (BTIn *btIn in transaction.ins) {
        BTTx *tx = [[BTTxProvider instance] getTxDetailByTxHash:btIn.prevTxHash];
        uint32_t n = btIn.prevOutSn;

        amount += [tx getOut:n].outValue;
    }

    for (BTOut *out in transaction.outs) {
        amount -= out.outValue;
    }

    return amount;
}

// returns the first non-change transaction output address, or nil if there aren't any
- (NSString *)addressForTransaction:(BTTx *)transaction {
    uint64_t sent = [self amountSentByTransaction:transaction];

    for (BTOut *out in transaction.outs) {
        // first non-wallet address if it's a send transaction, first wallet address if it's a receive transaction
        if ((sent > 0) != [self.address isEqualToString:out.outAddress]) return out.outAddress;
    }

    return nil;
}

// Returns the block height after which the transaction is likely to be processed without including a fee. This is based
// on the default satoshi client settings, but on the real network it's way off. In testing, a 0.01btc transaction that
// was expected to take an additional 90 days worth of blocks to confirm was confirmed in under an hour by Eligius pool.
- (uint32_t)blockHeightUntilFree:(BTTx *)transaction {
    // TODO: calculate estimated time based on the median priority of free transactions in last 144 blocks (24hrs)
    NSMutableArray *amounts = [NSMutableArray array], *heights = [NSMutableArray array];


    for (BTIn *btIn in transaction.ins) { // get the amounts and block heights of all the transaction inputs
        BTTx *tx = [[BTTxProvider instance] getTxDetailByTxHash:btIn.prevTxHash];
        uint32_t n = btIn.prevOutSn;

        [amounts addObject:@([tx getOut:n].outValue)];
        [heights addObject:@(tx.blockNo)];
    };

    return [transaction blockHeightUntilFreeForAmounts:amounts withBlockHeights:heights];
}


#pragma mark - r check

- (void)completeInSignature:(NSArray *)ins; {
    [[BTTxProvider instance] completeInSignatureWithIns:ins];
}

- (uint32_t)needCompleteInSignature; {
    return [[BTTxProvider instance] needCompleteInSignature:self.address];
}

- (BOOL)isHDAccount {
    return [self isKindOfClass:[BTHDAccount class]];
}

- (BOOL)isEqual:(id)object {
    if ([object isMemberOfClass:[BTAddress class]]) {
        BTAddress *other = object;
        return [self.address isEqualToString:other.address];
    } else {
        return NO;
    }
}

#pragma  mark - alias

- (void)updateAlias:(NSString *)alias {
    _alias = alias;
    [[BTAddressProvider instance] updateAliasWithAddress:self.address andAlias:self.alias];

}

- (void)removeAlias {
    _alias = nil;
    [[BTAddressProvider instance] updateAliasWithAddress:self.address andAlias:self.alias];
}

#pragma  mark- vanity address

- (void)updateVanityLen:(int)len {
    _vanityLen = len;
    [[BTAddressProvider instance] updateVanityAddress:self.address andLen:_vanityLen];
}

- (void)removeVanity {
    _vanityLen = VANITY_LEN_NO_EXSITS;
    [[BTAddressProvider instance] updateVanityAddress:self.address andLen:VANITY_LEN_NO_EXSITS];

}

- (BOOL)exsitsVanityLen {
    return _vanityLen != VANITY_LEN_NO_EXSITS;

}

@end
