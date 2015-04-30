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
#import "BTTxBuilder.h"
#import "BTUtils.h"
#import "BTBlockChain.h"

#define kBTHDAccountLookAheadSize (100)
#define kGenerationInitialProgress (0.02)

NSComparator const hdTxComparator = ^NSComparisonResult(id obj1, id obj2) {
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

- (instancetype)initWithMnemonicSeed:(NSData *)mnemonicSeed password:(NSString *)password fromXRandom:(BOOL)fromXRandom andGenerationCallback:(void (^)(CGFloat progres))callback {
    self = [self initWithMnemonicSeed:mnemonicSeed password:password fromXRandom:fromXRandom syncedComplete:YES andGenerationCallback:callback];
    return self;
}

- (instancetype)initWithMnemonicSeed:(NSData *)mnemonicSeed password:(NSString *)password fromXRandom:(BOOL)fromXRandom syncedComplete:(BOOL)isSyncedComplete andGenerationCallback:(void (^)(CGFloat progres))callback {
    self = [super init];
    if (self) {
        self.hdSeedId = -1;
        self.mnemonicSeed = mnemonicSeed;
        self.hdSeed = [BTHDAccount seedFromMnemonic:self.mnemonicSeed];
        BTBIP32Key *master = [[BTBIP32Key alloc] initWithSeed:self.hdSeed];
        [self initHDAccountWithMaster:master encryptedMnemonicSeed:[[BTEncryptData alloc] initWithData:self.mnemonicSeed andPassowrd:password andIsXRandom:fromXRandom] encryptedHDSeed:[[BTEncryptData alloc] initWithData:self.hdSeed andPassowrd:password andIsXRandom:fromXRandom] password:password syncedComplete:isSyncedComplete andGenerationCallback:callback];
    }
    return self;
}

- (instancetype)initWithEncryptedMnemonicSeed:(BTEncryptData *)encryptedMnemonicSeed password:(NSString *)password syncedComplete:(BOOL)isSyncedComplete andGenerationCallback:(void (^)(CGFloat progres))callback {
    self = [super init];
    if (self) {
        self.hdSeedId = -1;
        self.mnemonicSeed = [encryptedMnemonicSeed decrypt:password];
        if (!self.mnemonicSeed) {
            return nil;
        }
        self.hdSeed = [BTHDAccount seedFromMnemonic:self.mnemonicSeed];
        BTBIP32Key *master = [[BTBIP32Key alloc] initWithSeed:self.hdSeed];
        [self initHDAccountWithMaster:master encryptedMnemonicSeed:encryptedMnemonicSeed encryptedHDSeed:[[BTEncryptData alloc] initWithData:self.hdSeed andPassowrd:password andIsXRandom:encryptedMnemonicSeed.isXRandom] password:password syncedComplete:isSyncedComplete andGenerationCallback:callback];
    }
    return self;
}

- (instancetype)initWithSeedId:(int)seedId {
    self = [super init];
    if (self) {
        self.hdSeedId = seedId;
        _isFromXRandom = [[BTAddressProvider instance] hdAccountIsXRandom:seedId];
        [self updateBalance];
    }
    return self;
}

- (NSInteger)getHDAccountId {
    return self.hdSeedId;
}

- (void)initHDAccountWithMaster:(BTBIP32Key *)master encryptedMnemonicSeed:(BTEncryptData *)encryptedMnemonicSeed encryptedHDSeed:(BTEncryptData *)encryptedHDSeed password:(NSString *)password syncedComplete:(BOOL)isSyncedComplete andGenerationCallback:(void (^)(CGFloat progres))callback {
    CGFloat progress = 0;
    if (callback) {
        callback(progress);
    }
    _isFromXRandom = encryptedMnemonicSeed.isXRandom;
    NSString *address = master.key.address;
    BTEncryptData *encryptedSeedOfPasswordSeed = [[BTEncryptData alloc] initWithData:master.secret andPassowrd:password andIsXRandom:encryptedMnemonicSeed.isXRandom];
    BTBIP32Key *accountKey = [self getAccount:master];
    BTBIP32Key *internalKey = [self getChainRootKeyFromAccount:accountKey withPathType:INTERNAL_ROOT_PATH];
    BTBIP32Key *externalKey = [self getChainRootKeyFromAccount:accountKey withPathType:EXTERNAL_ROOT_PATH];
    BTBIP32Key *key = [externalKey deriveSoftened:0];
    NSString *firstAddress = key.address;
    [key wipe];
    [accountKey wipe];
    [master wipe];

    progress = kGenerationInitialProgress;
    if (callback) {
        callback(progress);
    }

    CGFloat itemProgress = (1.0 - progress) / (double) (kBTHDAccountLookAheadSize * 2);

    NSMutableArray *externalAddresses = [[NSMutableArray alloc] initWithCapacity:kBTHDAccountLookAheadSize];
    NSMutableArray *internalAddresses = [[NSMutableArray alloc] initWithCapacity:kBTHDAccountLookAheadSize];
    for (NSUInteger i = 0; i < kBTHDAccountLookAheadSize; i++) {
        NSData *subExternalPub = [externalKey deriveSoftened:i].pubKey;
        BTHDAccountAddress *externalAddress = [[BTHDAccountAddress alloc] initWithPub:subExternalPub path:EXTERNAL_ROOT_PATH index:i andSyncedComplete:isSyncedComplete];
        [externalAddresses addObject:externalAddress];

        progress += itemProgress;
        if (callback) {
            callback(MIN(progress, 1));
        }

        NSData *subInternalPub = [internalKey deriveSoftened:i].pubKey;
        BTHDAccountAddress *internalAddress = [[BTHDAccountAddress alloc] initWithPub:subInternalPub path:INTERNAL_ROOT_PATH index:i andSyncedComplete:isSyncedComplete];
        [internalAddresses addObject:internalAddress];

        progress += itemProgress;
        if (callback) {
            callback(MIN(progress, 1));
        }
    }
    [self wipeHDSeed];
    [self wipeMnemonicSeed];
    [[BTHDAccountProvider instance] addAddress:externalAddresses];
    [[BTHDAccountProvider instance] addAddress:internalAddresses];
    self.hdSeedId = [[BTAddressProvider instance] addHDAccount:[encryptedMnemonicSeed toEncryptedString] encryptSeed:[encryptedHDSeed toEncryptedString] firstAddress:firstAddress isXrandom:encryptedMnemonicSeed.isXRandom encryptSeedOfPS:encryptedSeedOfPasswordSeed.toEncryptedString addressOfPS:address externalPub:[externalKey getPubKeyExtended] internalPub:[internalKey getPubKeyExtended]];
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


- (BTTx *)newTxToAddress:(NSString *)toAddress withAmount:(uint64_t)amount password:(NSString *)password andError:(NSError **)error {
    return [self newTxToAddresses:@[toAddress] withAmounts:@[@(amount)] password:password andError:error];
}

- (BTTx *)newTxToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts password:(NSString *)password andError:(NSError **)error {
    NSArray *outs = [[BTHDAccountProvider instance] getUnspendOutByHDAccount:self.hdSeedId];
    BTTx *tx = [[BTTxBuilder instance] buildTxWithOutputs:outs toAddresses:toAddresses amounts:amounts changeAddress:[self getNewChangeAddress] andError:error];
    if (error && !tx) {
        return nil;
    }
    NSArray *signingAddresses = [self getSigningAddressesForInputs:tx.ins];
    BTBIP32Key *master = [self masterKey:password];
    if (!master) {
        [BTHDMPasswordWrongException raise:@"password wrong" format:nil];
        return nil;
    }

    BTBIP32Key *account = [self getAccount:master];
    BTBIP32Key *external = [self getChainRootKeyFromAccount:account withPathType:EXTERNAL_ROOT_PATH];
    BTBIP32Key *internal = [self getChainRootKeyFromAccount:account withPathType:INTERNAL_ROOT_PATH];
    [account wipe];
    [master wipe];

    NSArray *unsignedHashes = [tx unsignedInHashes];

    NSMutableArray *signatures = [[NSMutableArray alloc] initWithCapacity:unsignedHashes.count];

    NSMutableDictionary *addressToKeyDict = [NSMutableDictionary new];
    for (NSUInteger i = 0; i < signingAddresses.count; i++) {
        BTHDAccountAddress *a = signingAddresses[i];
        NSData *unsignedHash = unsignedHashes[i];

        if (![addressToKeyDict.allKeys containsObject:a.address]) {
            if (a.pathType == EXTERNAL_ROOT_PATH) {
                [addressToKeyDict setObject:[external deriveSoftened:a.index] forKey:a.address];
            } else {
                [addressToKeyDict setObject:[internal deriveSoftened:a.index] forKey:a.address];
            }
        }

        BTBIP32Key *key = [addressToKeyDict objectForKey:a.address];

        NSMutableData *sig = [NSMutableData data];
        NSMutableData *s = [NSMutableData dataWithData:[key.key sign:unsignedHash]];

        [s appendUInt8:SIG_HASH_ALL];
        [sig appendScriptPushData:s];
        [sig appendScriptPushData:[key.key publicKey]];
        [signatures addObject:sig];

    }

    if (![tx signWithSignatures:signatures]) {
        return nil;
    }
    [external wipe];
    [internal wipe];
    for (BTBIP32Key *key in addressToKeyDict.allValues) {
        [key wipe];
    }
    return tx;
}

- (NSArray *)getSigningAddressesForInputs:(NSArray *)inputs {
    return [[BTHDAccountProvider instance] getSigningAddressesForInputs:inputs];
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
        [as addObject:[[BTHDAccountAddress alloc] initWithPub:[root deriveSoftened:i].pubKey path:INTERNAL_ROOT_PATH index:i andSyncedComplete:isSyncedComplete]];
    }
    [[BTHDAccountProvider instance] addAddress:as];
    DDLogInfo(@"HD supplied %d internal addresses", as.count);
}

- (void)supplyNewExternalKeyForCount:(NSUInteger)count andSyncedComplete:(BOOL)isSyncedComplete {
    BTBIP32Key *root = [[BTBIP32Key alloc] initWithMasterPubKey:[self getExternalPub]];
    NSUInteger firstIndex = self.allGeneratedExternalAddressCount;
    NSMutableArray *as = [[NSMutableArray alloc] initWithCapacity:count];
    for (NSUInteger i = firstIndex; i < firstIndex + count; i++) {
        [as addObject:[[BTHDAccountAddress alloc] initWithPub:[root deriveSoftened:i].pubKey path:EXTERNAL_ROOT_PATH index:i andSyncedComplete:isSyncedComplete]];
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
    [txs sortUsingComparator:hdTxComparator];

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

        NSSet *addressSet = [self getBelongAccountAddressesFromAdresses:[tx getOutAddressList]];
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
    if (password) {
        [self decryptHDSeed:password];
    }
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

- (void)decryptMnemonicSeed:(NSString *)password {
    if (self.hdSeedId < 0 || !password) {
        return;
    }
    NSString *encrypted = [self encryptedMnemonicSeed];
    if (![BTUtils isEmpty:encrypted]) {
        self.mnemonicSeed = [[[BTEncryptData alloc] initWithStr:encrypted] decrypt:password];
        if (!self.mnemonicSeed) {
            [BTHDMPasswordWrongException raise:@"password wrong" format:nil];
        }
    }
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

- (BOOL)isSyncComplete {
    int unsyncedAddressCount = [BTHDAccountProvider instance].unSyncedAddressCount;
    return unsyncedAddressCount == 0;
}

- (uint32_t)txCount {
    return [[BTHDAccountProvider instance] hdAccountTxCount];
}

- (BTTx *)recentlyTx {
    NSArray *txs = [[BTHDAccountProvider instance] getRecentlyTxsByAccount:[BTBlockChain instance].lastBlock.blockNo - 6 + 1 limit:1];
    if (txs && txs.count > 0) {
        return txs[0];
    }
    return nil;
}

- (BOOL)initTxs:(NSArray *)txs {
    [[BTTxProvider instance] addTxs:txs];
    if (txs.count > 0) {
        [self notificateTx:[txs objectAtIndex:0] withNotificationType:txFromApi];
    }
    return YES;
}

- (NSArray *)txs:(int)page {
    return [[BTHDAccountProvider instance] getTxAndDetailByHDAccount:page];
}

- (NSArray *)getRelatedAddressesForTx:(BTTx *)tx {
    NSMutableArray *outAddressList = [tx getOutAddressList];
    NSMutableArray *hdAccountAddressList = [NSMutableArray new];
    NSArray *belongAccountOfOutList = [[BTHDAccountProvider instance] belongAccount:outAddressList];
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

- (NSSet *)getBelongAccountAddressesFromAdresses:(NSArray *)addresses {
    return [[BTHDAccountProvider instance] getBelongAccountAddressesFromAdresses:addresses];
}

- (NSArray *)getAddressFromIn:(BTTx *)tx {
    NSArray *addresses = [tx getInAddresses];
    return [[BTHDAccountProvider instance] belongAccount:addresses];
}

- (BOOL)isSendFromMe:(BTTx *)tx {
    return [self getAddressFromIn:tx].count > 0;
}

- (NSData *)getInternalPub {
    return [[BTAddressProvider instance] getInternalPub:self.hdSeedId];
}

- (NSData *)getExternalPub {
    return [[BTAddressProvider instance] getExternalPub:self.hdSeedId];
}

- (NSString *)getFirstAddressFromDb {
    return [[BTAddressProvider instance] getHDAccountFristAddress:self.hdSeedId];
}

- (NSString *)getFullEncryptPrivKey {
    return [BTEncryptData encryptedString:self.encryptedMnemonicSeed addIsCompressed:YES andIsXRandom:self.isFromXRandom];
}

- (NSArray *)seedWords:(NSString *)password {
    [self decryptMnemonicSeed:password];
    NSArray *words = [[BTBIP39 sharedInstance] toMnemonicArray:self.mnemonicSeed];
    [self wipeMnemonicSeed];
    return words;
}

- (BOOL)checkWithPassword:(NSString *)password {
    [self decryptHDSeed:password];
    if (!self.hdSeed) {
        return NO;
    }
    [self decryptMnemonicSeed:password];
    if (!self.mnemonicSeed) {
        return NO;
    }
    NSData *hdCopy = [NSData dataWithBytes:self.hdSeed.bytes length:self.hdSeed.length];
    BOOL hdSeedSafe = [BTUtils compareString:[self getFirstAddressFromDb] compare:[self firstAddressFromSeed:nil]];
    BOOL mnemonicSeefSafe = [[BTHDAccount seedFromMnemonic:self.mnemonicSeed] isEqualToData:hdCopy];
    [self wipeHDSeed];
    [self wipeMnemonicSeed];
    return hdSeedSafe && mnemonicSeefSafe;
}

- (NSString *)firstAddressFromSeed:(NSString *)password {
    BTBIP32Key *master = [self masterKey:password];
    BTBIP32Key *account = [self getAccount:master];
    BTBIP32Key *external = [self getChainRootKeyFromAccount:account withPathType:EXTERNAL_ROOT_PATH];
    BTBIP32Key *key = [external deriveSoftened:0];
    NSString *address = key.key.address;
    [master wipe];
    [account wipe];
    [external wipe];
    [key wipe];
    return address;
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

- (void)updateIssuedIndex:(PathType)pathType index:(int)index {
    [[BTHDAccountProvider instance] updateIssuedIndex:pathType index:index];
}
@end