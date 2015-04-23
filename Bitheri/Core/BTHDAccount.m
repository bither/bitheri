//
//  BTHDAccount.m
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

#import "BTHDAccount.h"
#import "BTHDAccountProvider.h"
#import "BTBIP39.h"
#import "BTBIP32Key.h"
#import "BTAddressProvider.h"
#import "BTIn.h"
#import "BTOut.h"
#import "BTTxProvider.h"
#import "BTQRCodeUtil.h"

#define kBTHDAccountLookAheadSize (100)

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

@interface BTHDAccount () {
    BOOL _isFromXRandom;
    uint64_t _balance;
}
@property NSData *hdSeed;
@property NSData *mnemonicSeed;
@property NSUInteger hdSeedId;
@end

@implementation BTHDAccount

- (instancetype)initWithMnemonicSeed:(NSData *)mnemonicSeed password:(NSString *)password andFromXRandom:(BOOL)fromXRandom {
    self = [self initWithMnemonicSeed:mnemonicSeed password:password fromXRandom:fromXRandom andSyncedComplete:YES];
    return self;
}

- (instancetype)initWithMnemonicSeed:(NSData *)mnemonicSeed password:(NSString *)password fromXRandom:(BOOL)fromXRandom andSyncedComplete:(BOOL)isSyncedComplete {
    self = [super init];
    if (self) {
        self.hdSeedId = -1;
        self.mnemonicSeed = mnemonicSeed;
        self.hdSeed = [BTHDAccount seedFromMnemonic:self.mnemonicSeed];
        BTBIP32Key *master = [[BTBIP32Key alloc] initWithSeed:self.hdSeed];
        [self initHDAccountWithMaster:master encryptedMnemonicSeed:[[BTEncryptData alloc] initWithData:self.mnemonicSeed andPassowrd:password andIsXRandom:fromXRandom] encryptedHDSeed:[[BTEncryptData alloc] initWithData:self.hdSeed andPassowrd:password andIsXRandom:fromXRandom] andSyncedComplete:isSyncedComplete];
    }
    return self;
}

- (instancetype)initWithEncryptedMnemonicSeed:(BTEncryptData *)encryptedMnemonicSeed password:(NSString *)password andSyncedComplete:(BOOL)isSyncedComplete {
    self = [super init];
    if (self) {
        self.hdSeedId = -1;
        self.mnemonicSeed = [encryptedMnemonicSeed decrypt:password];
        if (!self.mnemonicSeed) {
            return nil;
        }
        self.hdSeed = [BTHDAccount seedFromMnemonic:self.mnemonicSeed];
        BTBIP32Key *master = [[BTBIP32Key alloc] initWithSeed:self.hdSeed];
        [self initHDAccountWithMaster:master encryptedMnemonicSeed:encryptedMnemonicSeed encryptedHDSeed:[[BTEncryptData alloc] initWithData:self.hdSeed andPassowrd:password andIsXRandom:encryptedMnemonicSeed.isXRandom] andSyncedComplete:isSyncedComplete];
    }
    return self;
}

- (instancetype)initWithSeedId:(int)seedId {
    self = [super init];
    if (self) {
        self.hdSeedId = seedId;
        [self updateBalance];
    }
    return self;
}

- (void)initHDAccountWithMaster:(BTBIP32Key *)master encryptedMnemonicSeed:(BTEncryptData *)encryptedMnemonicSeed encryptedHDSeed:(BTEncryptData *)encryptedHDSeed andSyncedComplete:(BOOL)isSyncedComplete {
    NSString *firstAddress;
    BTKey *k = [[BTKey alloc] initWithSecret:self.mnemonicSeed compressed:YES];
    NSString *address = k.address;
    BTBIP32Key *accountKey = [self getAccount:master];
    BTBIP32Key *internalKey = [self getChainRootKeyFromAccount:accountKey withPathType:INTERNAL_ROOT_PATH];
    BTBIP32Key *externalKey = [self getChainRootKeyFromAccount:accountKey withPathType:EXTERNAL_ROOT_PATH];
    BTBIP32Key *key = [externalKey deriveSoftened:0];
    firstAddress = key.address;
    [key wipe];
    [accountKey wipe];
    [master wipe];

    NSMutableArray *externalAddresses = [[NSMutableArray alloc] initWithCapacity:kBTHDAccountLookAheadSize];
    NSMutableArray *internalAddresses = [[NSMutableArray alloc] initWithCapacity:kBTHDAccountLookAheadSize];
    for (NSUInteger i = 0; i < kBTHDAccountLookAheadSize; i++) {
        NSData *subExternalPub = [externalKey deriveSoftened:i].pubKey;
        NSData *subInternalPub = [internalKey deriveSoftened:i].pubKey;
        BTHDAccountAddress *externalAddress = [[BTHDAccountAddress alloc] initWithPub:subExternalPub path:EXTERNAL_ROOT_PATH index:i andSyncedComplete:isSyncedComplete];
        BTHDAccountAddress *internalAddress = [[BTHDAccountAddress alloc] initWithPub:subInternalPub path:INTERNAL_ROOT_PATH index:i andSyncedComplete:isSyncedComplete];
        [externalAddresses addObject:externalAddress];
        [internalAddresses addObject:internalAddress];
    }
    [self wipeHDSeed];
    [self wipeMnemonicSeed];
    [[BTHDAccountProvider instance] addAddress:externalAddresses];
    [[BTHDAccountProvider instance] addAddress:internalAddresses];
    self.hdSeedId = [[BTAddressProvider instance] addHDAccount:[encryptedMnemonicSeed toEncryptedString] encryptSeed:[encryptedHDSeed toEncryptedString] firstAddress:firstAddress isXrandom:encryptedMnemonicSeed.isXRandom addressOfPS:address externalPub:[externalKey getPubKeyExtended] internalPub:[internalKey getPubKeyExtended]];
    [internalKey wipe];
    [externalKey wipe];
}

- (void)onNewTx:(BTTx *)tx withRelatedAddresses:(NSArray *)relatedAddresses andTxNotificationType:(TxNotificationType)txNotificationType {
    if (!relatedAddresses || relatedAddresses.count == 0) {
        return;
    }

    NSInteger maxInternal = -1, maxExternal = -1;
    for (BTHDAccountAddress *a in relatedAddresses) {
        if (a.pathType == EXTERNAL_ROOT_PATH) {
            if (a.index > maxExternal) {
                maxExternal = a.index;
            }
        } else {
            if (a.index > maxInternal) {
                maxInternal = a.index;
            }
        }
    }

    DDLogInfo(@"HD on new tx issued ex %d, issued in %d", maxExternal, maxInternal);
    if (maxExternal >= 0 && maxExternal > self.issuedExternalIndex) {
        [self updateIssuedExternalIndex:maxExternal];
    }
    if (maxInternal >= 0 && maxInternal > self.issuedInternalIndex) {
        [self updateIssuedInternalIndex:maxInternal];
    }

    [self supplyEnoughKeys:YES];

    [[NSNotificationCenter defaultCenter] postNotificationName:BitherBalanceChangedNotification object:@[kHDAccountPlaceHolder, @([self getDeltaBalance]), tx, @(txNotificationType)]];
}

- (void)supplyEnoughKeys:(BOOL)isSyncedComplete {
    NSInteger lackOfExternal = self.issuedExternalIndex + 1 + kBTHDAccountLookAheadSize - self.allGeneratedExternalAddressCount;
    if (lackOfExternal > 0) {
        [self supplyNewExternalKeyForCount:lackOfExternal andSyncedComplete:isSyncedComplete];
    }

    NSInteger lackOfInternal = self.issuedInternalIndex + 1 + kBTHDAccountLookAheadSize - self.allGeneratedInternalAddressCount;
    if (lackOfInternal > 0) {
        [self supplyNewInternalKeyForCount:lackOfInternal andSyncedComplete:isSyncedComplete];
    }
}

- (void)supplyNewInternalKeyForCount:(NSUInteger)count andSyncedComplete:(BOOL)isSyncedComplete {
    BTBIP32Key *root = [[BTBIP32Key alloc] initWithMasterPubKey:[self getInternalPub]];
    NSUInteger firstIndex = self.allGeneratedInternalAddressCount;
    NSMutableArray *as = [[NSMutableArray alloc] initWithCapacity:count];
    for (NSUInteger i = firstIndex; i < firstIndex + count; i++) {
        [as addObject:[[BTHDAccountAddress alloc] initWithPub:[root deriveSoftened:i] path:INTERNAL_ROOT_PATH index:i andSyncedComplete:isSyncedComplete]];
    }
    [[BTHDAccountProvider instance] addAddress:as];
    DDLogInfo(@"HD supplied %d internal addresses", as.count);
}

- (void)supplyNewExternalKeyForCount:(NSUInteger)count andSyncedComplete:(BOOL)isSyncedComplete {
    BTBIP32Key *root = [[BTBIP32Key alloc] initWithMasterPubKey:[self getExternalPub]];
    NSUInteger firstIndex = self.allGeneratedExternalAddressCount;
    NSMutableArray *as = [[NSMutableArray alloc] initWithCapacity:count];
    for (NSUInteger i = firstIndex; i < firstIndex + count; i++) {
        [as addObject:[[BTHDAccountAddress alloc] initWithPub:[root deriveSoftened:i] path:EXTERNAL_ROOT_PATH index:i andSyncedComplete:isSyncedComplete]];
    }
    [[BTHDAccountProvider instance] addAddress:as];
    DDLogInfo(@"HD supplied %d external addresses", as.count);
}

- (NSString *)address {
    return [[BTHDAccountProvider instance] externalAddress];
}

- (void)updateBalance {
    _balance = [[BTHDAccountProvider instance] getHDAccountConfirmedBanlance:self.hdSeedId] + [self calculateUnconfirmedBalance];
}

- (uint64_t)calculateUnconfirmedBalance {
    uint64_t balance = 0;
    NSMutableOrderedSet *utxos = [NSMutableOrderedSet orderedSet];
    NSMutableSet *spentOutputs = [NSMutableSet set], *invalidTx = [NSMutableSet set];

    NSMutableArray *txs = [NSMutableArray arrayWithArray:[[BTHDAccountProvider instance] getHDAccountUnconfirmedTx]];
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

        NSArray *addressSet = [self getBelongAccountAddressesFromAdresses:[tx getOutAddressList]];
        for (BTOut *out in tx.outs) { // add outputs to UTXO set
            if ([addressSet containsObject:out.outAddress]) {
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

- (void)wipeHDSeed {
    if (!self.hdSeed) {
        return;
    }
    self.hdSeed = nil;
}

- (void)wipeMnemonicSeed {
    if (!self.mnemonicSeed) {
        return;
    }
    self.mnemonicSeed = nil;
}

- (BTBIP32Key *)masterKey:(NSString *)password {
    [self decryptHDSeed:password];
    BTBIP32Key *master = [[BTBIP32Key alloc] initWithSeed:self.hdSeed];
    [self wipeHDSeed];
    return master;
}

- (BTBIP32Key *)getAccount:(BTBIP32Key *)master {
    BTBIP32Key *purpose = [master deriveHardened:44];
    BTBIP32Key *coinType = [purpose deriveHardened:0];
    BTBIP32Key *account = [coinType deriveHardened:0];
    [purpose wipe];
    [coinType wipe];
    return account;
}

- (void)decryptHDSeed:(NSString *)password {
    if (self.hdSeed < 0 || !password) {
        return;
    }
    NSString *encryptedHDSeed = self.encryptedHDSeed;
    self.hdSeed = [[[BTEncryptData alloc] initWithStr:encryptedHDSeed] decrypt:password];
}

- (NSString *)encryptedHDSeed {
    return [[BTAddressProvider instance] getHDAccountEncryptSeed:self.hdSeedId];
}

- (NSString *)encryptedMnemonicSeed {
    return [[BTAddressProvider instance] getHDAccountEncryptMnmonicSeed:self.hdSeedId];
}

- (BTBIP32Key *)getChainRootKeyFromAccount:(BTBIP32Key *)account withPathType:(PathType)path {
    return [account deriveSoftened:path];
}

- (BOOL)hasPrivKey {
    return YES;
}

- (uint64_t)balance {
    return _balance;
}

- (int64_t)getDeltaBalance {
    uint64_t oldBalance = self.balance;
    [self updateBalance];
    return self.balance - oldBalance;
}

- (NSUInteger)elementCountForBloomFilter {
    return [self allGeneratedExternalAddressCount] * 2 + [self allGeneratedInternalAddressCount] * 2;
}

- (void)addElementsForBloomFilter:(BTBloomFilter *)filter {
    NSArray *pubs = [[BTHDAccountProvider instance] getPubs:EXTERNAL_ROOT_PATH];
    for (NSData *pub in pubs) {
        [filter insertData:pub];
        [filter insertData:[[BTKey alloc] initWithPublicKey:pub].address.addressToHash160];
    }
    pubs = nil;
    pubs = [[BTHDAccountProvider instance] getPubs:INTERNAL_ROOT_PATH];
    for (NSData *pub in pubs) {
        [filter insertData:pub];
        [filter insertData:[[BTKey alloc] initWithPublicKey:pub].address.addressToHash160];
    }
}

- (NSInteger)issuedInternalIndex {
    return [[BTHDAccountProvider instance] issuedIndex:INTERNAL_ROOT_PATH];
}

- (NSInteger)issuedExternalIndex {
    return [[BTHDAccountProvider instance] issuedIndex:EXTERNAL_ROOT_PATH];
}

- (NSUInteger)allGeneratedInternalAddressCount {
    return [[BTHDAccountProvider instance] allGeneratedAddressCount:INTERNAL_ROOT_PATH];
}

- (NSUInteger)allGeneratedExternalAddressCount {
    return [[BTHDAccountProvider instance] allGeneratedAddressCount:EXTERNAL_ROOT_PATH];
}

- (BTHDAccountAddress *)addressForPath:(PathType)path atIndex:(NSUInteger)index {
    return [[BTHDAccountProvider instance] addressForPath:path index:index];
}

- (void)updateIssuedInternalIndex:(int)index {
    [[BTHDAccountProvider instance] updateIssuedIndex:INTERNAL_ROOT_PATH index:index];
}

- (void)updateIssuedExternalIndex:(int)index {
    [[BTHDAccountProvider instance] updateIssuedIndex:EXTERNAL_ROOT_PATH index:index];
}

- (NSString *)getNewChangeAddress {
    return [self addressForPath:INTERNAL_ROOT_PATH atIndex:[self issuedInternalIndex] + 1].address;
}

- (void)updateSyncComplete:(BTHDAccountAddress *)address {
    [[BTHDAccountProvider instance] updateSyncdComplete:address];
}

- (uint32_t)txCount {
    return [[BTHDAccountProvider instance] hdAccountTxCount];
}

- (BTTx *)recentlyTx {
    NSArray *txs = [[BTHDAccountProvider instance] getRecentlyTxsByAccount:6 limit:1];
    if (txs && txs.count > 0) {
        return txs[0];
    }
    return nil;
}

- (BOOL)initTxs:(NSArray *)txs {
    [[BTTxProvider instance] addTxs:txs];
    if (txs.count > 0) {
        [self notificateTx:nil withNotificationType:txFromApi];
    }
    return YES;
}

- (NSArray *)txs:(int)page {
    return [[BTHDAccountProvider instance] getTxAndDetailByHDAccount:page];
}

- (NSArray *)getRelatedAddressesForTx:(BTTx *)tx {
    NSMutableArray *outAddressList = [NSMutableArray new];
    NSMutableArray *hdAccountAddressList = [NSMutableArray new];
    for (BTOut *out in tx.outs) {
        NSString *outAddress = out.outAddress;
        [outAddressList addObject:outAddress];
    }
    NSArray *belongAccountOfOutList = [self getBelongAccountAddressesFromAdresses:outAddressList];
    if (belongAccountOfOutList && belongAccountOfOutList.count > 0) {
        [hdAccountAddressList addObjectsFromArray:belongAccountOfOutList];
    }

    NSArray *belongAccountOfInList = [self getAddressFromIn:tx];
    if (belongAccountOfInList && belongAccountOfInList.count > 0) {
        [hdAccountAddressList addObjectsFromArray:belongAccountOfInList];
    }

    return hdAccountAddressList;
}

- (BOOL)isTxRelated:(BTTx *)tx {
    return [self getRelatedAddressesForTx:tx].count > 0;
}

- (NSArray *)getBelongAccountAddressesFromAdresses:(NSArray *)addresses {
    //TODO hddb: getBelongAccountAddressesFromAdresses
    return [NSArray new];
}

- (NSArray *)getAddressFromIn:(BTTx *)tx {
    //TODO hddb getAddressFromIn
    return [NSArray new];
}

- (NSData *)getInternalPub {
    return [[BTAddressProvider instance] getInternalPub:self.hdSeedId];
}

- (NSData *)getExternalPub {
    return [[BTAddressProvider instance] getExternalPub:self.hdSeedId];
}

- (NSString *)getFirstAddressFromDb {
    return [[BTAddressProvider instance] getHDFirstAddress:self.hdSeedId];
}

- (NSString *)getFullEncryptPrivKey {
    return [BTEncryptData encryptedString:self.encryptedMnemonicSeed addIsCompressed:YES andIsXRandom:self.isFromXRandom];
}

- (NSString *)getQRCodeFullEncryptPrivKey {
    return [HD_QR_CODE_FLAT stringByAppendingString:[BTEncryptData encryptedString:self.encryptedMnemonicSeed addIsCompressed:YES andIsXRandom:self.isFromXRandom]];
}

+ (NSData *)seedFromMnemonic:(NSData *)mnemonicSeed {
    return [[BTBIP39 sharedInstance] toSeed:[[BTBIP39 sharedInstance] toMnemonic:mnemonicSeed] withPassphrase:@""];
}

- (void)notificateTx:(BTTx *)tx withNotificationType:(TxNotificationType)type {
    int64_t deltaBalance = [self getDeltaBalance];
    [[NSNotificationCenter defaultCenter] postNotificationName:BitherBalanceChangedNotification object:@[kHDAccountPlaceHolder, @(deltaBalance), tx, @(type)]];
}

- (BOOL)isFromXRandom {
    return _isFromXRandom;
}
@end