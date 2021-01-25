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
#import "BTHDAccountAddressProvider.h"
#import "BTBIP32Key.h"
#import "BTAddressProvider.h"
#import "BTIn.h"
#import "BTOut.h"
#import "BTTxProvider.h"
#import "BTTxBuilder.h"
#import "BTUtils.h"
#import "BTBlockChain.h"
#import "BTHDAccountProvider.h"
#import "BTAddressManager.h"

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
    BOOL _hasSeed;
    NSInteger _preIssuedExternalIndex;
}
@property NSData *hdSeed;
@property NSData *mnemonicSeed;
@property int hdAccountId;
@end

@implementation BTHDAccount

- (instancetype)initWithMnemonicSeed:(NSData *)mnemonicSeed password:(NSString *)password fromXRandom:(BOOL)fromXRandom andGenerationCallback:(void (^)(CGFloat progres))callback {
    self = [self initWithMnemonicSeed:mnemonicSeed btBip39:nil password:password fromXRandom:fromXRandom syncedComplete:YES andGenerationCallback:callback];
    return self;
}

- (instancetype)initWithMnemonicSeed:(NSData *)mnemonicSeed btBip39:(BTBIP39 *)bip39 password:(NSString *)password fromXRandom:(BOOL)fromXRandom syncedComplete:(BOOL)isSyncedComplete andGenerationCallback:(void (^)(CGFloat progres))callback {
    self = [super init];
    if (self) {
        self.hdAccountId = -1;
        self.mnemonicSeed = mnemonicSeed;
        self.hdSeed = [BTHDAccount seedFromMnemonic:self.mnemonicSeed btBip39:bip39];
        BTEncryptData *encryptedMnemonicSeed = [[BTEncryptData alloc] initWithData:self.mnemonicSeed andPassowrd:password andIsXRandom:fromXRandom];
        BTEncryptData *encryptedHDSeed = [[BTEncryptData alloc] initWithData:self.hdSeed andPassowrd:password andIsXRandom:fromXRandom];
        
        NSData *validMnemonicSeed = [encryptedMnemonicSeed decrypt:password];
        NSData *validHdSeed = [BTHDAccount seedFromMnemonic:validMnemonicSeed btBip39:bip39];
        if (![mnemonicSeed isEqualToData:validMnemonicSeed] || ![_hdSeed isEqualToData:validHdSeed]) {
            @throw [[EncryptionException alloc] initWithName:@"EncryptionException" reason:@"EncryptionException" userInfo:nil];
        }
        
        BTBIP32Key *master = [[BTBIP32Key alloc] initWithSeed:self.hdSeed];
        BTBIP32Key *account = [self getAccount:master withPurposePathLevel:NormalAddress];
        BTBIP32Key *segwitAccount = [self getAccount:master withPurposePathLevel:P2SHP2WPKH];
        [account clearPrivateKey];
        [master clearPrivateKey];
        [segwitAccount clearPrivateKey];
        [self initHDAccountWithAccount:account segwitAccountKey:segwitAccount password:password encryptedMnemonicSeed:encryptedMnemonicSeed encryptedHDSeed:encryptedHDSeed fromXRandom:fromXRandom syncedComplete:isSyncedComplete andGenerationCallback:callback];
    }
    return self;
}

- (instancetype)initWithEncryptedMnemonicSeed:(BTEncryptData *)encryptedMnemonicSeed btBip39:(BTBIP39 *)bip39 password:(NSString *)password syncedComplete:(BOOL)isSyncedComplete andGenerationCallback:(void (^)(CGFloat progres))callback {
    self = [super init];
    if (self) {
        self.hdAccountId = -1;
        self.mnemonicSeed = [encryptedMnemonicSeed decrypt:password];
        if (!self.mnemonicSeed) {
            return nil;
        }
        self.hdSeed = [BTHDAccount seedFromMnemonic:self.mnemonicSeed btBip39:bip39];
        BTBIP32Key *master = [[BTBIP32Key alloc] initWithSeed:self.hdSeed];
        BTBIP32Key *account = [self getAccount:master withPurposePathLevel:NormalAddress];
        BTBIP32Key *segwitAccount = [self getAccount:master withPurposePathLevel:P2SHP2WPKH];
        [account clearPrivateKey];
        [master clearPrivateKey];
        [segwitAccount clearPrivateKey];
        [self initHDAccountWithAccount:account segwitAccountKey:segwitAccount password:password encryptedMnemonicSeed:encryptedMnemonicSeed encryptedHDSeed:[[BTEncryptData alloc] initWithData:self.hdSeed andPassowrd:password andIsXRandom:encryptedMnemonicSeed.isXRandom] fromXRandom:encryptedMnemonicSeed.isXRandom syncedComplete:isSyncedComplete andGenerationCallback:callback];
    }
    return self;
}

- (instancetype)initWithAccountExtendedPub:(NSData *)accountExtendedPub p2shp2wpkhAccountExtentedPub:(NSData *)p2shp2wpkhAccountExtentedPub {
    self = [self initWithAccountExtendedPub:accountExtendedPub p2shp2wpkhAccountExtentedPub:p2shp2wpkhAccountExtentedPub andFromXRandom:NO];
    return self;
}

- (instancetype)initWithAccountExtendedPub:(NSData *)accountExtendedPub p2shp2wpkhAccountExtentedPub:(NSData *)p2shp2wpkhAccountExtentedPub andFromXRandom:(BOOL)isFromXRandom {
    self = [self initWithAccountExtendedPub:accountExtendedPub p2shp2wpkhAccountExtentedPub:p2shp2wpkhAccountExtentedPub fromXRandom:isFromXRandom syncedComplete:YES andGenerationCallback:nil];
    return self;
}

- (instancetype)initWithAccountExtendedPub:(NSData *)accountExtendedPub p2shp2wpkhAccountExtentedPub:(NSData *)p2shp2wpkhAccountExtentedPub fromXRandom:(BOOL)isFromXRandom syncedComplete:(BOOL)isSyncedComplete andGenerationCallback:(void (^)(CGFloat progres))callback {
    self = [super init];
    if (self) {
        _isFromXRandom = isFromXRandom;
        BTBIP32Key *account = [[BTBIP32Key alloc] initWithMasterPubKey:accountExtendedPub];
        BTBIP32Key *segwitAccount = p2shp2wpkhAccountExtentedPub == nil ? nil : [[BTBIP32Key alloc] initWithMasterPubKey:p2shp2wpkhAccountExtentedPub];
        [self initHDAccountWithAccount:account segwitAccountKey:segwitAccount password:nil encryptedMnemonicSeed:nil encryptedHDSeed:nil fromXRandom:isFromXRandom syncedComplete:isSyncedComplete andGenerationCallback:callback];
    }
    return self;
}

- (instancetype)initWithSeedId:(int)seedId {
    self = [super init];
    if (self) {
        self.hdAccountId = seedId;
        _isFromXRandom = [[BTHDAccountProvider instance] hdAccountIsXRandom:seedId];
        _hasSeed = [[BTHDAccountProvider instance] hasMnemonicSeed:self.hdAccountId];
        _preIssuedExternalIndex = [self issuedExternalIndexForPathType:[self getCurrentExternalPathType]];
        [self updateBalance];
    }
    return self;
}

- (NSInteger)getHDAccountId {
    return self.hdAccountId;
}

- (void)initHDAccountWithAccount:(BTBIP32Key *)accountKey segwitAccountKey:(BTBIP32Key *)segwitAccountKey password:(NSString *)password encryptedMnemonicSeed:(BTEncryptData *)encryptedMnemonicSeed encryptedHDSeed:(BTEncryptData *)encryptedHDSeed fromXRandom:(BOOL)isFromXRandom syncedComplete:(BOOL)isSyncedComplete andGenerationCallback:(void (^)(CGFloat progres))callback {
    _isFromXRandom = isFromXRandom;
    CGFloat progress = 0;
    
    if (callback) {
        callback(progress);
    }
    NSString *addressOfPs = nil;
    BTEncryptData *encryptedDataOfPS = nil;
    if (encryptedMnemonicSeed && password && self.hdSeed) {
        BTBIP32Key *master = [[BTBIP32Key alloc] initWithSeed:self.hdSeed];
        addressOfPs = master.key.address;
        encryptedDataOfPS = [[BTEncryptData alloc] initWithData:master.secret andPassowrd:password andIsXRandom:isFromXRandom];
    }
    BTBIP32Key *internalKey = [self getChainRootKeyFromAccount:accountKey withPathType:INTERNAL_ROOT_PATH];
    BTBIP32Key *externalKey = [self getChainRootKeyFromAccount:accountKey withPathType:EXTERNAL_ROOT_PATH];
    BTBIP32Key *segwitInternalKey = nil;
    BTBIP32Key *segwitExternalKey = nil;
    if (segwitAccountKey) {
        segwitInternalKey = [self getChainRootKeyFromAccount:segwitAccountKey withPathType:INTERNAL_ROOT_PATH];
        segwitExternalKey = [self getChainRootKeyFromAccount:segwitAccountKey withPathType:EXTERNAL_ROOT_PATH];
    }
    BTBIP32Key *key = [externalKey deriveSoftened:0];
    NSString *firstAddress = key.address;
    [key wipe];
    [accountKey wipe];
    if ([BTHDAccount isRepeatHD:firstAddress]) {
        @throw [[DuplicatedHDAccountException alloc] initWithName:@"DuplicatedHDAccountException" reason:@"DuplicatedHDAccountException" userInfo:nil];
    }
    
    progress = kGenerationInitialProgress;
    if (callback) {
        callback(progress);
    }
    
    CGFloat itemProgress = (1.0 - progress) / (double) (kBTHDAccountLookAheadSize * 2);
    
    NSMutableArray *externalAddresses = [[NSMutableArray alloc] initWithCapacity:kBTHDAccountLookAheadSize];
    NSMutableArray *internalAddresses = [[NSMutableArray alloc] initWithCapacity:kBTHDAccountLookAheadSize];
    NSMutableArray *externalSegwitAddresses = [[NSMutableArray alloc] initWithCapacity:kBTHDAccountLookAheadSize];
    NSMutableArray *internalSegwitAddresses = [[NSMutableArray alloc] initWithCapacity:kBTHDAccountLookAheadSize];
    
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
        
        if (segwitExternalKey) {
            NSData *subSegwitExternalPub = [segwitExternalKey deriveSoftened:i].pubKey;
            BTHDAccountAddress *externalSegwitAddress = [[BTHDAccountAddress alloc] initWithPub:subSegwitExternalPub path:EXTERNAL_BIP49_PATH index:i andSyncedComplete:isSyncedComplete];
            [externalSegwitAddresses addObject:externalSegwitAddress];
            
            progress += itemProgress;
            if (callback) {
                callback(MIN(progress, 1));
            }
        }
        
        if (segwitInternalKey) {
            NSData *subSegwitInternalPub = [segwitInternalKey deriveSoftened:i].pubKey;
            BTHDAccountAddress *internalSegwitAddress = [[BTHDAccountAddress alloc] initWithPub:subSegwitInternalPub path:INTERNAL_BIP49_PATH index:i andSyncedComplete:isSyncedComplete];
            [internalSegwitAddresses addObject:internalSegwitAddress];
            progress += itemProgress;
            if (callback) {
                callback(MIN(progress, 1));
                
            }
        }
    }
    [self wipeHDSeed];
    [self wipeMnemonicSeed];
    if (encryptedMnemonicSeed) {
        self.hdAccountId = [[BTHDAccountProvider instance] addHDAccountWithEncryptedMnemonicSeed:[encryptedMnemonicSeed toEncryptedString] encryptSeed:[encryptedHDSeed toEncryptedString] firstAddress:firstAddress isXRandom:isFromXRandom encryptSeedOfPS:encryptedDataOfPS.toEncryptedString addressOfPS:addressOfPs externalPub:[externalKey getPubKeyExtended] internalPub:[internalKey getPubKeyExtended]];
        _hasSeed = YES;
        
        @try {
            [self seedWords:password];
        } @catch (NSException *e) {
            [self validFailedDelete:password];
            [internalKey wipe];
            [externalKey wipe];
            if (segwitInternalKey) {
                [segwitInternalKey wipe];
            }
            if (segwitExternalKey) {
                [segwitExternalKey wipe];
            }
            @throw [[EncryptionException alloc] initWithName:@"EncryptionException" reason:@"EncryptionException" userInfo:nil];
        }
    } else {
        self.hdAccountId = [[BTHDAccountProvider instance] addMonitoredHDAccount:firstAddress isXRandom:isFromXRandom externalPub:externalKey.getPubKeyExtended internalPub:internalKey.getPubKeyExtended];
        _hasSeed = NO;
    }
    if (segwitExternalKey && segwitInternalKey) {
        [[BTHDAccountProvider instance] addHDAccountSegwitPubForHDAccountId:_hdAccountId segwitExternalPub:segwitExternalKey.getPubKeyExtended segwitInternalPub:segwitInternalKey.getPubKeyExtended];
    }
    for (BTHDAccountAddress *each in externalAddresses) {
        each.hdAccountId = _hdAccountId;
    }
    for (BTHDAccountAddress *each in internalAddresses) {
        each.hdAccountId = _hdAccountId;
    }
    for (BTHDAccountAddress *each in externalSegwitAddresses) {
        each.hdAccountId = _hdAccountId;
    }
    for (BTHDAccountAddress *each in internalSegwitAddresses) {
        each.hdAccountId = _hdAccountId;
    }
    [[BTHDAccountAddressProvider instance] addAddress:externalAddresses];
    [[BTHDAccountAddressProvider instance] addAddress:internalAddresses];
    [[BTHDAccountAddressProvider instance] addAddress:externalSegwitAddresses];
    [[BTHDAccountAddressProvider instance] addAddress:internalSegwitAddresses];
    _preIssuedExternalIndex = -1;
    [internalKey wipe];
    [externalKey wipe];
    if (segwitInternalKey) {
        [segwitInternalKey wipe];
    }
    if (segwitExternalKey) {
        [segwitExternalKey wipe];
    }
}

- (void)validFailedDelete:(NSString *)password {
    if ([[BTAddressManager instance] noAddress]) {
        [[BTAddressProvider instance] deletePassword:password];
    }
    [[BTHDAccountProvider instance] deleteHDAccount:_hdAccountId];
    [[BTHDAccountAddressProvider instance] deleteHDAccountAddress:_hdAccountId];
}

- (void)addSegwitPub:(NSString *)password complete:(void (^)(BOOL))complete {
    BTHDAccountProvider *provider = [BTHDAccountProvider instance];
    if (![provider getHDAccountEncryptSeed:_hdAccountId]) {
        if (complete) {
            complete(false);
        }
        return;
    }
    if ([provider getSegwitExternalPub:_hdAccountId] && [provider getSegwitInternalPub:_hdAccountId]) {
        if (complete) {
            complete(true);
        }
        return;
    }
    BTBIP32Key *master = [self masterKey:password];
    if (!master) {
        if (complete) {
            complete(false);
        }
        return;
    }
    BTBIP32Key *accountPurpose49Key = [self getAccount:master withPurposePathLevel:P2SHP2WPKH];
    BTBIP32Key *externalBIP49Key = [self getChainRootKeyFromAccount:accountPurpose49Key withPathType:EXTERNAL_ROOT_PATH];
    BTBIP32Key *internalBIP49Key = [self getChainRootKeyFromAccount:accountPurpose49Key withPathType:INTERNAL_ROOT_PATH];
    [provider addHDAccountSegwitPubForHDAccountId:_hdAccountId segwitExternalPub:externalBIP49Key.getPubKeyExtended segwitInternalPub:internalBIP49Key.getPubKeyExtended];
    NSMutableArray *externalSegwitAddresses = [[NSMutableArray alloc] initWithCapacity:kBTHDAccountLookAheadSize];
    NSMutableArray *internalSegwitAddresses = [[NSMutableArray alloc] initWithCapacity:kBTHDAccountLookAheadSize];
    
    for (uint i = 0; i < kBTHDAccountLookAheadSize; i++) {
        NSData *subSegwitExternalPub = [externalBIP49Key deriveSoftened:i].pubKey;
        BTHDAccountAddress *externalSegwitAddress = [[BTHDAccountAddress alloc] initWithPub:subSegwitExternalPub path:EXTERNAL_BIP49_PATH index:i andSyncedComplete:[self isSyncComplete]];
        [externalSegwitAddresses addObject:externalSegwitAddress];
        
        NSData *subSegwitInternalPub = [internalBIP49Key deriveSoftened:i].pubKey;
        BTHDAccountAddress *internalSegwitAddress = [[BTHDAccountAddress alloc] initWithPub:subSegwitInternalPub path:INTERNAL_BIP49_PATH index:i andSyncedComplete:[self isSyncComplete]];
        [internalSegwitAddresses addObject:internalSegwitAddress];
    }
    for (BTHDAccountAddress *each in externalSegwitAddresses) {
        each.hdAccountId = _hdAccountId;
    }
    for (BTHDAccountAddress *each in internalSegwitAddresses) {
        each.hdAccountId = _hdAccountId;
    }
    [[BTHDAccountAddressProvider instance] addAddress:externalSegwitAddresses];
    [[BTHDAccountAddressProvider instance] addAddress:internalSegwitAddresses];
    [externalBIP49Key wipe];
    [internalBIP49Key wipe];
    if (complete) {
        complete(true);
    }
}

+ (BOOL)isRepeatHD:(NSString *)firstAddress {
    BTHDAccount *hdAccountHot = [[BTAddressManager instance] hdAccountHot];
    BTHDAccount *hdAccountMonitored = [[BTAddressManager instance] hdAccountMonitored];
    if (hdAccountHot == nil && hdAccountMonitored == nil) {
        return false;
    }
    
    BTHDAccountAddress *addressMonitored = nil;
    if (hdAccountHot != nil) {
        addressMonitored = [hdAccountHot addressForPath:EXTERNAL_ROOT_PATH atIndex:0];
    } else if (hdAccountMonitored != nil) {
        addressMonitored = [hdAccountMonitored addressForPath:EXTERNAL_ROOT_PATH atIndex:0];
    }
    if ([firstAddress isEqualToString:addressMonitored.address]) {
        return true;
    }
    return false;
}

- (void)onNewTx:(BTTx *)tx andTxNotificationType:(TxNotificationType)txNotificationType {
    [self supplyEnoughKeys:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:BitherBalanceChangedNotification object:@[self.hasPrivKey ? kHDAccountPlaceHolder : kHDAccountMonitoredPlaceHolder, @([self getDeltaBalance]), tx, @(txNotificationType)]];
}

- (BTTx *)newTxToAddress:(NSString *)toAddress withAmount:(uint64_t)amount pathType:(PathType)pathType dynamicFeeBase:(uint64_t)dynamicFeeBase andError:(NSError **)error  {
    return [self newTxToAddresses:@[toAddress] withAmounts:@[@(amount)] dynamicFeeBase:dynamicFeeBase andError:error andChangeAddress:[self getNewChangeAddressForPathType:pathType] coin:BTC];
}

- (BTTx *)newTxToAddress:(NSString *)toAddress withAmount:(uint64_t)amount dynamicFeeBase:(uint64_t)dynamicFeeBase andError:(NSError **)error andChangeAddress:(NSString *)changeAddress coin:(Coin)coin  {
    return [self newTxToAddresses:@[toAddress] withAmounts:@[@(amount)] dynamicFeeBase:dynamicFeeBase andError:error andChangeAddress:changeAddress coin:coin];
}

- (BTTx *)newTxToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts dynamicFeeBase:(uint64_t)dynamicFeeBase andError:(NSError **)error andChangeAddress:(NSString *)changeAddress coin:(Coin)coin {
    NSArray *outs;
    if (coin != BTC) {
        outs = [[BTHDAccountAddressProvider instance] getPrevCanSplitOutsByHDAccount:self.hdAccountId coin:coin];
    } else {
        outs = [[BTHDAccountAddressProvider instance] getUnspendOutByHDAccount:self.hdAccountId];
    }
    BTTx *tx = [[BTTxBuilder instance] buildTxWithOutputs:outs toAddresses:toAddresses amounts:amounts changeAddress:changeAddress dynamicFeeBase:dynamicFeeBase andError:error];
    if (error && !tx) {
        return nil;
    }
    tx.coin = coin;
    return tx;
}

- (NSArray *)newSplitCoinTxsToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts andError:(NSError **)error andChangeAddress:(NSString *)changeAddress coin:(Coin)coin {
    NSArray *outs = [[BTHDAccountAddressProvider instance] getPrevCanSplitOutsByHDAccount:self.hdAccountId coin:coin];
    NSArray *txs = [[BTTxBuilder instance] buildSplitCoinTxsWithOutputs:outs toAddresses:toAddresses amounts:amounts changeAddress:changeAddress andError:error coin:coin];
    if (error && !txs) {
        return nil;
    }
    return txs;
}

- (NSArray *)newBccTxsToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts andError:(NSError **)error andChangeAddress:(NSString *)changeAddress andUnspentOut:(NSArray *) outs {
    NSArray *txs = [[BTTxBuilder instance] buildSplitCoinTxsWithOutputs:outs toAddresses:toAddresses amounts:amounts changeAddress:changeAddress andError:error coin:BCC];
    if (error && !txs) {
        return nil;
    }
    return txs;
}

- (BTTx *)newTxToAddress:(NSString *)toAddress withAmount:(uint64_t)amount pathType:(PathType)pathType dynamicFeeBase:(uint64_t)dynamicFeeBase password:(NSString *)password andError:(NSError **)error {
    return [self newTxToAddresses:@[toAddress] withAmounts:@[@(amount)] andChangeAddress:[self getNewChangeAddressForPathType:pathType] dynamicFeeBase:dynamicFeeBase password:password andError:error coin:BTC];
}

- (BTTx *)newTxToAddress:(NSString *)toAddress withAmount:(uint64_t)amount andChangeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase password:(NSString *)password andError:(NSError **)error coin:(Coin)coin {
    return [self newTxToAddresses:@[toAddress] withAmounts:@[@(amount)] andChangeAddress:changeAddress dynamicFeeBase:dynamicFeeBase password:password andError:error coin:coin];
}

- (BTTx *)newTxToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts pathType:(PathType)pathType dynamicFeeBase:(uint64_t)dynamicFeeBase password:(NSString *)password andError:(NSError **)error {
    return [self newTxToAddresses:toAddresses withAmounts:amounts andChangeAddress:[self getNewChangeAddressForPathType:pathType] dynamicFeeBase:dynamicFeeBase password:password andError:error coin:BTC];
}

- (BTTx *)newTxToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts andChangeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase password:(NSString *)password andError:(NSError **)error coin:(Coin)coin {
    if (password && !self.hasPrivKey) {
        return nil;
    }
    NSArray *outs;
    if (coin != BTC) {
        outs = [[BTHDAccountAddressProvider instance] getPrevCanSplitOutsByHDAccount:self.hdAccountId coin:coin];
    } else {
        outs = [[BTHDAccountAddressProvider instance] getUnspendOutByHDAccount:self.hdAccountId];
    }
    BTTx *tx = [[BTTxBuilder instance] buildTxWithOutputs:outs toAddresses:toAddresses amounts:amounts changeAddress:changeAddress dynamicFeeBase:dynamicFeeBase andError:error];
    if (error && !tx) {
        return nil;
    }
    tx.coin = coin;
    NSArray *signingAddresses = [self getSigningAddressesForInputs:tx.ins];
    BTBIP32Key *master = [self masterKey:password];
    if (!master) {
        [BTHDMPasswordWrongException raise:@"password wrong" format:nil];
        return nil;
    }
    
    BTBIP32Key *account = [self getAccount:master withPurposePathLevel:NormalAddress];
    BTBIP32Key *segwitAccount = [self getAccount:master withPurposePathLevel:P2SHP2WPKH];
    BTBIP32Key *external = [self getChainRootKeyFromAccount:account withPathType:EXTERNAL_ROOT_PATH];
    BTBIP32Key *internal = [self getChainRootKeyFromAccount:account withPathType:INTERNAL_ROOT_PATH];
    BTBIP32Key *segwitExternal = [self getChainRootKeyFromAccount:segwitAccount withPathType:EXTERNAL_ROOT_PATH];
    BTBIP32Key *segwitInternal = [self getChainRootKeyFromAccount:segwitAccount withPathType:INTERNAL_ROOT_PATH];
    [account wipe];
    [segwitAccount wipe];
    [master wipe];
    
    NSMutableArray *signatures = [[NSMutableArray alloc] initWithCapacity:signingAddresses.count];
    NSMutableArray *witnesses = [[NSMutableArray alloc] initWithCapacity:signingAddresses.count];
    NSMutableDictionary *addressToKeyDict = [NSMutableDictionary new];
    for (NSUInteger i = 0; i < signingAddresses.count; i++) {
        BTHDAccountAddress *a = signingAddresses[i];        
        if (![addressToKeyDict.allKeys containsObject:a.address]) {
            if (a.pathType == EXTERNAL_ROOT_PATH) {
                [addressToKeyDict setObject:[external deriveSoftened:a.index] forKey:a.address];
            } else if (a.pathType == INTERNAL_ROOT_PATH) {
                [addressToKeyDict setObject:[internal deriveSoftened:a.index] forKey:a.address];
            } else if (a.pathType == EXTERNAL_BIP49_PATH) {
                [addressToKeyDict setObject:[segwitExternal deriveSoftened:a.index] forKey:a.address];
                if (!tx.isSegwitAddress) {
                    tx.isSegwitAddress = true;
                }
            } else {
                [addressToKeyDict setObject:[segwitInternal deriveSoftened:a.index] forKey:a.address];
                if (!tx.isSegwitAddress) {
                    tx.isSegwitAddress = true;
                }
            }
        }
        
        BTBIP32Key *key = [addressToKeyDict objectForKey:a.address];
        BTIn *btIn = tx.ins[i];
        if (a.pathType == EXTERNAL_BIP49_PATH || a.pathType == INTERNAL_BIP49_PATH) {
            [signatures addObject:[BTHDAccountUtil getRedeemScript:key.pubKey]];
            NSData *unsignedHash = [tx getSegwitUnsignedInHashesForRedeemScript:key.getRedeemScript btIn:btIn];
            [witnesses addObject:[BTHDAccountUtil getWitness:key.pubKey sign:[BTHDAccountUtil getSign:key.key unsignedHash:unsignedHash]]];
        } else {
            NSData *unsignedHash = [tx getUnsignedInHashesForIn:btIn];
            NSMutableData *sig = [NSMutableData data];
            NSMutableData *s = [NSMutableData dataWithData:[key.key sign:unsignedHash]];
            [s appendUInt8:[tx getSigHashType]];
            [sig appendScriptPushData:s];
            [sig appendScriptPushData:[key.key publicKey]];
            [signatures addObject:sig];
            NSMutableData *witness = [[NSMutableData alloc] initWithCapacity:1];
            [witness appendUInt8:0];
            [witnesses addObject:witness];
        }
    }
    tx.witnesses = witnesses;
    if (![tx signWithSignatures:signatures]) {
        return nil;
    }
    [external wipe];
    [internal wipe];
    [segwitExternal wipe];
    [segwitInternal wipe];
    for (BTBIP32Key *key in addressToKeyDict.allValues) {
        [key wipe];
    }
    return tx;
}

- (NSArray *)newSplitCoinTxsToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts andChangeAddress:(NSString *)changeAddress password:(NSString *)password andError:(NSError **)error coin:(Coin)coin blockHah:(NSString*)hash; {
    if (password && !self.hasPrivKey) {
        return nil;
    }
    NSArray *outs = [[BTHDAccountAddressProvider instance] getPrevCanSplitOutsByHDAccount:self.hdAccountId coin:coin];
    NSArray *txs = [[BTTxBuilder instance] buildSplitCoinTxsWithOutputs:outs toAddresses:toAddresses amounts:amounts changeAddress:changeAddress andError:error coin:coin];
    if (error && !txs) {
        return nil;
    }
    
    for (BTTx *tx in txs) {
        if(hash != NULL && ![hash isEqualToString:@""]) {
            tx.blockHash = [hash hexToData];
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
            
            [s appendUInt8:[tx getSigHashType]];
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
    }
    return txs;
}
- (NSArray *)extractBccToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts andChangeAddress:(NSString *)changeAddress andUnspentOuts:(NSArray *)outs andPathTypeIndex:(PathTypeIndex *) pathTypeIndex password:(NSString *)password andError:(NSError **)error {
    if (password && !self.hasPrivKey) {
        return nil;
    }
    NSArray *txs = [[BTTxBuilder instance] buildSplitCoinTxsWithOutputs:outs toAddresses:toAddresses amounts:amounts changeAddress:changeAddress andError:error coin:BCC];
    if (error && !txs) {
        return nil;
    }
    
    for (BTTx *tx in txs) {
        tx.isDetectBcc = true;
        BTBIP32Key *master = [self masterKey:password];
        if (!master) {
            [BTHDMPasswordWrongException raise:@"password wrong" format:nil];
            return nil;
        }
        
        u_int64_t preOutValues[] = {};
        for (int idx = 0; idx< outs.count; idx ++) {
            preOutValues[idx] = [ outs[idx]outValue];
        }
        NSArray *unsignedHashes = [tx unsignedInHashesForBcc:preOutValues];
        
        NSMutableArray *signatures = [[NSMutableArray alloc] initWithCapacity:unsignedHashes.count];
        
        NSMutableDictionary *addressToKeyDict = [NSMutableDictionary new];
        for (NSUInteger i = 0; i < tx.ins.count; i++) {
            NSData *unsignedHash = unsignedHashes[i];
            
            BTBIP32Key *account = [self getAccount:master];
            BTBIP32Key *pathPrivate = [account deriveSoftened: pathTypeIndex.pathType];
            BTBIP32Key *key = [pathPrivate deriveSoftened:(uint)pathTypeIndex.index];
            
            NSMutableData *sig = [NSMutableData data];
            NSMutableData *s = [NSMutableData dataWithData:[key.key sign:unsignedHash]];
            
            [s appendUInt8:[tx getSigHashType]];
            [sig appendScriptPushData:s];
            [sig appendScriptPushData:[key.key publicKey]];
            [signatures addObject:sig];
            
        }
        
        if (![tx signWithSignatures:signatures]) {
            return nil;
        }
        
        for (BTBIP32Key *key in addressToKeyDict.allValues) {
            [key wipe];
        }
    }
    return txs;
}

- (NSArray *)getSigningAddressesForInputs:(NSArray *)inputs {
    return [[BTHDAccountAddressProvider instance] getSigningAddressesByHDAccountId:self.hdAccountId fromInputs:inputs];
}

- (void)supplyEnoughKeys:(BOOL)isSyncedComplete {
    NSInteger currentIssuedExternalIndex = [self issuedExternalIndexForPathType:[self getCurrentExternalPathType]];
    BOOL paymentAddressChanged = (_preIssuedExternalIndex != currentIssuedExternalIndex);
    _preIssuedExternalIndex = currentIssuedExternalIndex;
    PathType externalPath = EXTERNAL_ROOT_PATH;
    NSInteger lackOfExternal = [self issuedExternalIndexForPathType:externalPath] + 1 + kBTHDAccountLookAheadSize - [self allGeneratedExternalAddressCountForPathType:externalPath];
    if (lackOfExternal > 0) {
        [self supplyNewExternalKeyForCount:lackOfExternal pathType:externalPath andSyncedComplete:isSyncedComplete];
    }
    PathType internalPath = INTERNAL_ROOT_PATH;
    NSInteger lackOfInternal = [self issuedInternalIndexForPathType:internalPath] + 1 + kBTHDAccountLookAheadSize - [self allGeneratedInternalAddressCountForPathType:internalPath];
    if (lackOfInternal > 0) {
        [self supplyNewInternalKeyForCount:lackOfInternal pathType:internalPath andSyncedComplete:isSyncedComplete];
    }
    
    PathType segwitExternalPath = EXTERNAL_BIP49_PATH;
    if ([self getExternalPub:segwitExternalPath]) {
        NSInteger lackOfSegwitExternal = [self issuedExternalIndexForPathType:segwitExternalPath] + 1 + kBTHDAccountLookAheadSize - [self allGeneratedExternalAddressCountForPathType:segwitExternalPath];
        if (lackOfSegwitExternal > 0) {
            [self supplyNewExternalKeyForCount:lackOfSegwitExternal pathType:segwitExternalPath andSyncedComplete:isSyncedComplete];
        }
    }
    
    PathType segwitInternalPath = INTERNAL_BIP49_PATH;
    if ([self getInternalPub:segwitInternalPath]) {
        NSInteger lackOfSegwitInternal = [self issuedInternalIndexForPathType:segwitInternalPath] + 1 + kBTHDAccountLookAheadSize - [self allGeneratedInternalAddressCountForPathType:segwitInternalPath];
        if (lackOfSegwitInternal > 0) {
            [self supplyNewInternalKeyForCount:lackOfSegwitInternal pathType:segwitInternalPath andSyncedComplete:isSyncedComplete];
        }
    }
    
    if (paymentAddressChanged) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kHDAccountPaymentAddressChangedNotification object:[self addressForPath:[self getCurrentExternalPathType]] userInfo:@{kHDAccountPaymentAddressChangedNotificationFirstAdding : @(NO)}];
    }
}

- (void)supplyNewInternalKeyForCount:(NSUInteger)count pathType:(PathType)pathType andSyncedComplete:(BOOL)isSyncedComplete {
    BTBIP32Key *root = [[BTBIP32Key alloc] initWithMasterPubKey:[self getInternalPub:pathType]];
    NSUInteger firstIndex = [self allGeneratedInternalAddressCountForPathType:pathType];
    NSMutableArray *as = [[NSMutableArray alloc] initWithCapacity:count];
    for (NSUInteger i = firstIndex; i < firstIndex + count; i++) {
        BTHDAccountAddress *address = [[BTHDAccountAddress alloc] initWithPub:[root deriveSoftened:i].pubKey path:pathType index:i andSyncedComplete:isSyncedComplete];
        address.hdAccountId = self.hdAccountId;
        [as addObject:address];
    }
    [[BTHDAccountAddressProvider instance] addAddress:as];
    DDLogInfo(@"HD supplied %d internal addresses", as.count);
}

- (void)supplyNewExternalKeyForCount:(NSUInteger)count pathType:(PathType)pathType andSyncedComplete:(BOOL)isSyncedComplete {
    BTBIP32Key *root = [[BTBIP32Key alloc] initWithMasterPubKey:[self getExternalPub:pathType]];
    NSUInteger firstIndex = [self allGeneratedExternalAddressCountForPathType:pathType];
    NSMutableArray *as = [[NSMutableArray alloc] initWithCapacity:count];
    for (NSUInteger i = firstIndex; i < firstIndex + count; i++) {
        BTHDAccountAddress *address = [[BTHDAccountAddress alloc] initWithPub:[root deriveSoftened:i].pubKey path:pathType index:i andSyncedComplete:isSyncedComplete];
        address.hdAccountId = self.hdAccountId;
        [as addObject:address];
    }
    [[BTHDAccountAddressProvider instance] addAddress:as];
    DDLogInfo(@"HD supplied %d external addresses", as.count);
}

- (NSString *)address {
    return [[BTHDAccountAddressProvider instance] getExternalAddress:self.hdAccountId path:EXTERNAL_ROOT_PATH];
}

- (NSString *)addressForPath:(PathType)path {
    NSString *address = [[BTHDAccountAddressProvider instance] getExternalAddress:self.hdAccountId path:path];
    if (!address) {
        if (path == EXTERNAL_BIP49_PATH) {
            address = [[BTHDAccountAddressProvider instance] getExternalAddress:self.hdAccountId path:EXTERNAL_ROOT_PATH];
        } else if (path == INTERNAL_BIP49_PATH) {
            address = [[BTHDAccountAddressProvider instance] getExternalAddress:self.hdAccountId path:INTERNAL_ROOT_PATH];
        }
    }
    return address;
}

- (void)updateBalance {
    _balance = [[BTHDAccountAddressProvider instance] getHDAccountConfirmedBalance:self.hdAccountId] + [self calculateUnconfirmedBalance];
}

- (uint64_t)calculateUnconfirmedBalance {
    uint64_t balance = 0;
    NSMutableOrderedSet *utxos = [NSMutableOrderedSet orderedSet];
    NSMutableSet *spentOutputs = [NSMutableSet set], *invalidTx = [NSMutableSet set];
    
    NSMutableArray *txs = [NSMutableArray arrayWithArray:[[BTHDAccountAddressProvider instance] getHDAccountUnconfirmedTx:self.hdAccountId]];
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
        
        NSSet *addressSet = [self getBelongAccountAddressesFromAddresses:[tx getOutAddressList]];
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
    if (!self.hasPrivKey) {
        return nil;
    }
    if (password) {
        [self decryptHDSeed:password];
    }
    BTBIP32Key *master = [[BTBIP32Key alloc] initWithSeed:self.hdSeed];
    [self wipeHDSeed];
    return master;
}

- (BTBIP32Key *)getAccount:(BTBIP32Key *)master {
    BTBIP32Key *purpose = [master deriveHardened:[self getPurposePathLevel]];
    BTBIP32Key *coinType = [purpose deriveHardened:0];
    BTBIP32Key *account = [coinType deriveHardened:0];
    [purpose wipe];
    [coinType wipe];
    return account;
}

- (BTBIP32Key *)getAccount:(BTBIP32Key *)master withPurposePathLevel:(PurposePathLevel)purposeLevel {
    BTBIP32Key *purpose = [master deriveHardened:purposeLevel];
    BTBIP32Key *coinType = [purpose deriveHardened:0];
    BTBIP32Key *account = [coinType deriveHardened:0];
    [purpose wipe];
    [coinType wipe];
    return account;
}

- (void)decryptHDSeed:(NSString *)password {
    if (self.hdSeed < 0 || !password || !self.hasPrivKey) {
        return;
    }
    NSString *encryptedHDSeed = self.encryptedHDSeed;
    self.hdSeed = [[[BTEncryptData alloc] initWithStr:encryptedHDSeed] decrypt:password];
}

- (void)decryptMnemonicSeed:(NSString *)password {
    if (self.hdAccountId < 0 || !password || !self.hasPrivKey) {
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
    if (!self.hasPrivKey) {
        return nil;
    }
    return [[BTHDAccountProvider instance] getHDAccountEncryptSeed:self.hdAccountId];
}

- (NSString *)encryptedMnemonicSeed {
    if (!self.hasPrivKey) {
        return nil;
    }
    return [[BTHDAccountProvider instance] getHDAccountEncryptMnemonicSeed:self.hdAccountId];
}

- (BTBIP32Key *)getChainRootKeyFromAccount:(BTBIP32Key *)account withPathType:(PathType)path {
    return [account deriveSoftened:path];
}

- (BOOL)hasPrivKey {
    return _hasSeed;
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
    NSUInteger count = [self allGeneratedExternalAddressCountForPathType:EXTERNAL_ROOT_PATH] * 2 +
    [[BTHDAccountAddressProvider instance] getUnspendOutCountByHDAccountId:self.hdAccountId pathType:INTERNAL_ROOT_PATH] +
    [[BTHDAccountAddressProvider instance] getUnconfirmedSpentOutCountByHDAccountId:self.hdAccountId pathType:INTERNAL_ROOT_PATH];
    if ([self getExternalPub:EXTERNAL_BIP49_PATH]) {
        count += [self allGeneratedExternalAddressCountForPathType:EXTERNAL_BIP49_PATH] * 2;
    }
    if ([self getInternalPub:INTERNAL_BIP49_PATH]) {
        count += [[BTHDAccountAddressProvider instance] getUnspendOutCountByHDAccountId:self.hdAccountId pathType:INTERNAL_BIP49_PATH] +
        [[BTHDAccountAddressProvider instance] getUnconfirmedSpentOutCountByHDAccountId:self.hdAccountId pathType:INTERNAL_BIP49_PATH];
    }
    return count;
}

- (void)addElementsForBloomFilter:(BTBloomFilter *)filter {
    NSArray *pubs = [[BTHDAccountAddressProvider instance] getPubsByHDAccountId:self.hdAccountId pathType:EXTERNAL_ROOT_PATH];
    for (NSData *pub in pubs) {
        [filter insertData:pub];
        [filter insertData:[[BTKey alloc] initWithPublicKey:pub].address.addressToHash160];
    }
    pubs = [[BTHDAccountAddressProvider instance] getPubsByHDAccountId:self.hdAccountId pathType:EXTERNAL_BIP49_PATH];
    for (NSData *pub in pubs) {
        [filter insertData:pub];
        [filter insertData:[[BTKey alloc] initWithPublicKey:pub].toSegwitAddress.addressToHash160];
    }
    NSArray *outs = [[BTHDAccountAddressProvider instance] getUnspendOutByHDAccountId:self.hdAccountId pathType:INTERNAL_ROOT_PATH];
    for (BTOut *out in outs) {
        [filter insertData:getOutPoint(out.txHash, out.outSn)];
    }
    outs = [[BTHDAccountAddressProvider instance] getUnconfirmedSpentOutByHDAccountId:self.hdAccountId pathType:INTERNAL_ROOT_PATH];
    for (BTOut *out in outs) {
        [filter insertData:getOutPoint(out.txHash, out.outSn)];
    }
    outs = [[BTHDAccountAddressProvider instance] getUnspendOutByHDAccountId:self.hdAccountId pathType:INTERNAL_BIP49_PATH];
    for (BTOut *out in outs) {
        [filter insertData:getOutPoint(out.txHash, out.outSn)];
    }
    outs = [[BTHDAccountAddressProvider instance] getUnconfirmedSpentOutByHDAccountId:self.hdAccountId pathType:INTERNAL_BIP49_PATH];
    for (BTOut *out in outs) {
        [filter insertData:getOutPoint(out.txHash, out.outSn)];
    }
}

- (NSInteger)issuedInternalIndexForPathType:(PathType)pathType {
    return [[BTHDAccountAddressProvider instance] getIssuedIndexByHDAccountId:self.hdAccountId pathType:pathType];
}

- (NSInteger)issuedExternalIndexForPathType:(PathType)pathType {
    return [[BTHDAccountAddressProvider instance] getIssuedIndexByHDAccountId:self.hdAccountId pathType:pathType];
}

- (NSUInteger)allGeneratedInternalAddressCountForPathType:(PathType)pathType {
    return [[BTHDAccountAddressProvider instance] getGeneratedAddressCountByHDAccountId:self.hdAccountId pathType:pathType];
}

- (NSUInteger)allGeneratedExternalAddressCountForPathType:(PathType)pathType {
    return [[BTHDAccountAddressProvider instance] getGeneratedAddressCountByHDAccountId:self.hdAccountId pathType:pathType];
}

- (BTHDAccountAddress *)addressForPath:(PathType)path atIndex:(NSUInteger)index {
    return [[BTHDAccountAddressProvider instance] getAddressByHDAccountId:self.hdAccountId path:path index:index];
}

- (void)updateIssuedInternalIndex:(int)index pathType:(PathType)pathType {
    [[BTHDAccountAddressProvider instance] updateIssuedByHDAccountId:self.hdAccountId pathType:pathType index:index];
}

- (void)updateIssuedExternalIndex:(int)index pathType:(PathType)pathType {
    [[BTHDAccountAddressProvider instance] updateIssuedByHDAccountId:self.hdAccountId pathType:pathType index:index];
}

- (NSString *)getNewChangeAddressForPathType:(PathType)pathType {
    return [self addressForPath:pathType atIndex:[self issuedExternalIndexForPathType:pathType] + 1].address;
}

- (void)updateSyncComplete:(BTHDAccountAddress *)address {
    [[BTHDAccountAddressProvider instance] updateSyncedCompleteByHDAccountId:self.hdAccountId address:address];
}

- (BOOL)isSyncComplete {
    int unsyncedAddressCount = [[BTHDAccountAddressProvider instance] getUnSyncedAddressCount:self.hdAccountId];
    return unsyncedAddressCount == 0;
}

- (uint32_t)txCount {
    return [[BTHDAccountAddressProvider instance] getHDAccountTxCount:self.hdAccountId];
}

- (BTTx *)recentlyTx {
    NSArray *txs = [[BTHDAccountAddressProvider instance] getRecentlyTxsByHDAccount:self.hdAccountId blockNo:[BTBlockChain instance].lastBlock.blockNo - 6 + 1 limit:1];
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
    NSArray *arr = [[BTHDAccountAddressProvider instance] getTxAndDetailByHDAccount:self.hdAccountId page:page];
    return [self handleTxs:arr];
}

- (NSArray *)handleTxs:(NSArray *)txs {
    NSMutableArray *arr = [NSMutableArray array];
    for (BTTx *tx in txs) {
        BOOL isAdd = false;
        for (BTOut *out in tx.outs) {
            if (out.outAddress == NULL) {
                continue;
            }
            NSMutableArray *addresses = [NSMutableArray array];
            [addresses addObject:out.outAddress];
            BOOL isMeOut = [[BTHDAccountAddressProvider instance] getBelongHDAccount:self.hdAccountId fromAddresses:addresses].count > 0;
            if (out.outStatus != reloadSpent && isMeOut) {
                isAdd = true;
                break;
            } else if (!out.isReload) {
                isAdd = true;
                break;
            }
        }
        if (isAdd) {
            [arr addObject:tx];
        }
    }
    return arr;
}

- (NSArray *)getRelatedAddressesForTx:(BTTx *)tx {
    NSMutableArray *outAddressList = [tx getOutAddressList];
    NSMutableArray *hdAccountAddressList = [NSMutableArray new];
    NSArray *belongAccountOfOutList = [[BTHDAccountAddressProvider instance] getBelongHDAccount:self.hdAccountId fromAddresses:outAddressList];
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

- (NSSet *)getBelongAccountAddressesFromAddresses:(NSArray *)addresses {
    return [[BTHDAccountAddressProvider instance] getAddressesByHDAccount:self.hdAccountId fromAddresses:addresses];
}

- (NSArray *)getAddressFromIn:(BTTx *)tx {
    NSArray *addresses = [tx getInAddresses];
    return [[BTHDAccountAddressProvider instance] getBelongHDAccount:self.hdAccountId fromAddresses:addresses];
}

- (BOOL)isSendFromMe:(BTTx *)tx {
    return [self getAddressFromIn:tx].count > 0;
}

- (NSData *)getInternalPub:(PathType)pathType {
    if (pathType == INTERNAL_BIP49_PATH) {
        return [[BTHDAccountProvider instance] getSegwitInternalPub:self.hdAccountId];
    } else {
        return [[BTHDAccountProvider instance] getInternalPub:self.hdAccountId];
    }
}

- (NSData *)getExternalPub:(PathType)pathType {
    if (pathType == EXTERNAL_BIP49_PATH) {
        return [[BTHDAccountProvider instance] getSegwitExternalPub:self.hdAccountId];
    } else {
        return [[BTHDAccountProvider instance] getExternalPub:self.hdAccountId];
    }
}

- (NSString *)getFirstAddressFromDb {
    return [[BTHDAccountProvider instance] getHDFirstAddress:self.hdAccountId];
}

- (NSString *)getFullEncryptPrivKey {
    if (!self.hasPrivKey) {
        return nil;
    }
    return [BTEncryptData encryptedString:self.encryptedMnemonicSeed addIsCompressed:YES andIsXRandom:self.isFromXRandom];
}

- (NSArray *)seedWords:(NSString *)password {
    if (!self.hasPrivKey) {
        return nil;
    }
    [self decryptMnemonicSeed:password];
    NSArray *words = [[BTBIP39 sharedInstance] toMnemonicArray:self.mnemonicSeed];
    NSString *validFirstAddress = [self getValidFirstAddress:words];
    NSString *dbFirstAddress = [self getFirstAddressFromDb];
    [self wipeMnemonicSeed];
    if (![validFirstAddress isEqualToString:dbFirstAddress]) {
        @throw [[EncryptionException alloc] initWithName:@"EncryptionException" reason:@"EncryptionException" userInfo:nil];
    }
    return words;
}

- (NSString *)getValidFirstAddress:(NSArray *)words {
    if (words == NULL || words.count == 0) {
        @throw [[EncryptionException alloc] initWithName:@"EncryptionException" reason:@"EncryptionException" userInfo:nil];
    }
    NSString *code = [[BTBIP39 sharedInstance] toMnemonicWithArray:words];
    NSData *mnemonicCodeSeed = [[BTBIP39 sharedInstance] toEntropy:code];
    if (mnemonicCodeSeed == NULL) {
        @throw [[EncryptionException alloc] initWithName:@"EncryptionException" reason:@"EncryptionException" userInfo:nil];
    }
    NSData *hdSeed = [BTHDAccount seedFromMnemonic:mnemonicCodeSeed btBip39:[BTBIP39 sharedInstance]];
    BTBIP32Key *master = [[BTBIP32Key alloc] initWithSeed:hdSeed];
    BTBIP32Key *account = [self getAccount:master withPurposePathLevel:NormalAddress];
    [account clearPrivateKey];
    [master clearPrivateKey];
    BTBIP32Key *externalKey = [self getChainRootKeyFromAccount:account withPathType:EXTERNAL_ROOT_PATH];
    BTBIP32Key *key = [externalKey deriveSoftened:0];
    NSString *firstAddress = key.address;
    [key wipe];
    [externalKey wipe];
    [account wipe];
    return firstAddress;
}

- (BOOL)checkWithPassword:(NSString *)password {
    if (!self.hasPrivKey) {
        return YES;
    }
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
    BOOL mnemonicSeefSafe = [[BTHDAccount seedFromMnemonic:self.mnemonicSeed btBip39:[BTBIP39 sharedInstance]] isEqualToData:hdCopy];
    [self wipeHDSeed];
    [self wipeMnemonicSeed];
    return hdSeedSafe && mnemonicSeefSafe;
}

- (NSString *)firstAddressFromSeed:(NSString *)password {
    if (!self.hasPrivKey) {
        return nil;
    }
    BTBIP32Key *master = [self masterKey:password];
    BTBIP32Key *account = [self getAccount:master withPurposePathLevel:NormalAddress];
    BTBIP32Key *external = [self getChainRootKeyFromAccount:account withPathType:EXTERNAL_ROOT_PATH];
    BTBIP32Key *key = [external deriveSoftened:0];
    NSString *address = key.address;
    [master wipe];
    [account wipe];
    [external wipe];
    [key wipe];
    return address;
}

- (NSString *)getQRCodeFullEncryptPrivKeyWithHDQrCodeFlatType:(HDQrCodeFlatType)qrCodeFlatType {
    if (!self.hasPrivKey) {
        return nil;
    }
    return [[BTQRCodeUtil getHDQrCodeFlat:qrCodeFlatType] stringByAppendingString:[BTEncryptData encryptedString:self.encryptedMnemonicSeed addIsCompressed:YES andIsXRandom:self.isFromXRandom]];
}

+ (NSData *)seedFromMnemonic:(NSData *)mnemonicSeed btBip39:(BTBIP39 *)bit39 {
    if (!bit39) {
        return [[BTBIP39 sharedInstance] toSeed:[[BTBIP39 sharedInstance] toMnemonic:mnemonicSeed] withPassphrase:@""];
    }
    return [bit39 toSeed:[bit39 toMnemonic:mnemonicSeed] withPassphrase:@""];
}

- (void)notificateTx:(BTTx *)tx withNotificationType:(TxNotificationType)type {
    int64_t deltaBalance = [self getDeltaBalance];
    [[NSNotificationCenter defaultCenter] postNotificationName:BitherBalanceChangedNotification object:@[self.hasPrivKey ? kHDAccountPlaceHolder : kHDAccountMonitoredPlaceHolder, @(deltaBalance), tx, @(type)]];
}

- (BOOL)isFromXRandom {
    return _isFromXRandom;
}

- (BOOL)requestNewReceivingAddress:(PathType)pathType {
    BOOL result = [[BTHDAccountAddressProvider instance] requestNewReceivingAddress:self.hdAccountId pathType:pathType];
    if (result) {
        [self supplyEnoughKeys:YES];
    }
    return result;
}

- (void)updateIssuedIndex:(int)index pathType:(PathType)pathType {
    if (pathType == EXTERNAL_ROOT_PATH || pathType == EXTERNAL_BIP49_PATH) {
        [self updateIssuedExternalIndex:index pathType:pathType];
    } else {
        [self updateIssuedInternalIndex:index pathType:pathType];
    }
}

+ (BOOL)checkDuplicatedHDAccountWithExternalRoot:(NSData *)ex andInternalRoot:(NSData *)in {
    //TODO checkDuplicatedHDAccount
    return NO;
}

- (BTBIP32Key *)xPub:(NSString *)password {
    return [self xPub:password withPurposePathLevel:NormalAddress];
}

- (BTBIP32Key *)xPub:(NSString *)password withPurposePathLevel:(PurposePathLevel)purposeLevel {
    BTBIP32Key *master = [self masterKey:password];
    BTBIP32Key *account = [self getAccount:master withPurposePathLevel:purposeLevel];
    [master wipe];
    return account;
}

- (BTBIP32Key *)privateKeyWithPath:(PathType)path index:(int)index password:(NSString *)password {
    BTBIP32Key *accountKey = [self xPub:password];
    BTBIP32Key *pathKey = [self getChainRootKeyFromAccount:accountKey withPathType:path];
    BTBIP32Key *key = [pathKey deriveSoftened:index];
    [accountKey wipe];
    [pathKey wipe];
    return key;
}

- (PathType) getCurrentExternalPathType {
    if ([self isSegwitAddressType]) {
        return EXTERNAL_BIP49_PATH;
    } else {
        return EXTERNAL_ROOT_PATH;
    }
}

- (PathType) getCurrentInternalPathType {
    if ([self isSegwitAddressType]) {
        return INTERNAL_BIP49_PATH;
    } else {
        return INTERNAL_ROOT_PATH;
    }
}

- (PurposePathLevel) getPurposePathLevel {
    if ([self isSegwitAddressType]) {
        return P2SHP2WPKH;
    } else {
        return NormalAddress;
    }
}

- (BOOL)isSegwitAddressType {
    return [[NSUserDefaults standardUserDefaults] objectForKey:BTHDAccountIsSegwitAddressType];
}

@end

@implementation DuplicatedHDAccountException
@end


