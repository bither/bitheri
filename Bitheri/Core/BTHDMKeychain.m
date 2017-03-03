//
//  BTHDMKeychain.m
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
#import "BTHDMKeychain.h"
#import "BTBIP39.h"
#import "BTAddressProvider.h"
#import "BTUtils.h"
#import "BTHDMKeychainRecover.h"
#import "BTEncryptData.h"
#import "BTQRCodeUtil.h"

@interface BTHDMKeychain () {
    BOOL _isFromXRandom;
}
@property NSData *hdSeed;
@property NSData *mnemonicSeed;
@end

@implementation BTHDMKeychain

- (instancetype)initWithMnemonicSeed:(NSData *)seed password:(NSString *)password andXRandom:(BOOL)xrandom {
    self = [super init];
    if (self) {
        self.hdSeedId = -1;
        self.mnemonicSeed = seed;
        self.hdSeed = [BTHDMKeychain seedFromMnemonic:self.mnemonicSeed];
        BTEncryptData *encryptedMnemonicSeed = [[BTEncryptData alloc] initWithData:self.mnemonicSeed andPassowrd:password andIsXRandom:xrandom];
        BTEncryptData *encryptedHDSeed = [[BTEncryptData alloc] initWithData:self.hdSeed andPassowrd:password andIsXRandom:xrandom];
        BTKey *priv = [[BTKey alloc] initWithSecret:self.mnemonicSeed compressed:encryptedMnemonicSeed.isCompressed];
        NSString *passwordSeedAddress = priv.address;
        NSString *firstAddress = [self firstAddressFromSeed:password];
        [self wipeHDSeed];
        [self wipeMnemonicSeed];
        _isFromXRandom = xrandom;
        self.hdSeedId = [[BTAddressProvider instance] addHDSeedWithMnemonicEncryptSeed:encryptedMnemonicSeed.toEncryptedString andEncryptHDSeed:encryptedHDSeed.toEncryptedString andFirstAddress:firstAddress andIsXRandom:xrandom andAddressOfPs:passwordSeedAddress];
        self.allCompletedAddresses = [[NSMutableArray alloc] init];
    }
    return self;
}

- (instancetype)initWithSeedId:(int)seedId {
    self = [super init];
    if (self) {
        self.hdSeedId = seedId;
        self.allCompletedAddresses = [[NSMutableArray alloc] init];
        [self initFromDb];
    }
    return self;
}

- (instancetype)initWithEncrypted:(NSString *)encryptedMnemonicSeedStr password:(NSString *)password andFetchBlock:(NSArray *(^)(NSString *password))fetchBlock {
    self = [super init];
    if (self) {
        self.hdSeedId = -1;
        BTEncryptData *encryptedMnemonicSeed = [[BTEncryptData alloc] initWithStr:encryptedMnemonicSeedStr];
        self.mnemonicSeed = [encryptedMnemonicSeed decrypt:password];
        self.hdSeed = [BTHDMKeychain seedFromMnemonic:self.mnemonicSeed];
        _isFromXRandom = encryptedMnemonicSeed.isXRandom;
        BTEncryptData *encryptedHDSeed = [[BTEncryptData alloc] initWithData:self.hdSeed andPassowrd:password andIsXRandom:_isFromXRandom];
        self.allCompletedAddresses = [[NSMutableArray alloc] init];
        NSMutableArray *as = [[NSMutableArray alloc] init];
        NSMutableArray *uncompPubs = [[NSMutableArray alloc] init];
        if (fetchBlock) {
            NSArray *pubs = fetchBlock(password);
            if (pubs && pubs.count > 0) {
                BTBIP32Key *root = [self externalChainRoot:password];
                NSData *pubDerived = [root deriveSoftened:0].pubKey;
                BTHDMPubs *p0 = pubs[0];
                NSData *pubFetched = p0.hot;
                [root wipe];
                if (![pubDerived isEqualToData:pubFetched]) {
                    [self wipeMnemonicSeed];
                    [self wipeHDSeed];
                    [NSException raise:@"HDM Bither ID Not Match" format:nil];
                }
            }
            for (BTHDMPubs *p in pubs) {
                if (p.isCompleted) {
                    BTHDMAddress *a = [[BTHDMAddress alloc] initWithPubs:p andKeychain:self syncCompleted:NO];
                    [as addObject:a];
                } else {
                    [uncompPubs addObject:p];
                }
            }
        }
        BTKey *priv = [[BTKey alloc] initWithSecret:self.mnemonicSeed compressed:encryptedMnemonicSeed.isCompressed];
        NSString *passwordSeedAddress = priv.address;
        NSString *firstAddress = [self firstAddressFromSeed:password];
        [self wipeHDSeed];
        [self wipeMnemonicSeed];
        self.hdSeedId = [[BTAddressProvider instance] addHDSeedWithMnemonicEncryptSeed:encryptedMnemonicSeed.toEncryptedString
                                                                      andEncryptHDSeed:encryptedHDSeed.toEncryptedString
                                                                       andFirstAddress:firstAddress andIsXRandom:_isFromXRandom
                                                                        andAddressOfPs:passwordSeedAddress];
        if (as.count > 0) {
            [[BTAddressProvider instance] completeHDMAddressesWithHDSeedId:self.hdSeedId andHDMAddresses:as];
            [self.allCompletedAddresses addObjectsFromArray:as];
            if (uncompPubs.count > 0) {
                [[BTAddressProvider instance] prepareHDMAddressesWithHDSeedId:self.hdSeedId andPubs:uncompPubs];
                for (BTHDMPubs *p in uncompPubs) {
                    [[BTAddressProvider instance] setHDMPubsRemoteWithHDSeedId:self.hdSeedId andIndex:p.index andPubKeyRemote:p.remote];
                }
            }
        }
    }
    return self;
}

- (NSUInteger)prepareAddressesWithCount:(UInt32)count password:(NSString *)password andColdExternalPub:(NSData *)coldExternalPub {
    BTBIP32Key *externalRootCold = [[BTBIP32Key alloc] initWithMasterPubKey:coldExternalPub];
    BTBIP32Key *externalRootHot = [self externalChainRoot:password];
    NSMutableArray *pubs = [NSMutableArray new];
    UInt32 startIndex = 0;
    int32_t maxIndex = [[BTAddressProvider instance] maxHDMAddressPubIndex:self.hdSeedId];
    if (maxIndex >= 0) {
        startIndex = maxIndex + 1;
    }
    
    if (startIndex > 0) {
        BTHDMBid *bid = [BTHDMBid getHDMBidFromDb];
        if (bid) {
            NSString *hdmIdAddress = bid.address;
            if (![BTUtils compareString:hdmIdAddress compare:[externalRootCold deriveSoftened:0].key.address]) {
                [BTHDMColdPubNotSameException raise:@"BTHDMColdPubNotSameException" format:nil];
            }
        }
    }
    
    for (UInt32 i = startIndex; pubs.count < count; i++) {
        BTHDMPubs *p = [BTHDMPubs new];
        p.hot = [externalRootHot deriveSoftened:i].pubKey;
        if (!p.hot) {
            p.hot = [BTHDMPubs EmptyBytes];
        }
        p.cold = [externalRootCold deriveSoftened:i].pubKey;
        if (!p.cold) {
            p.cold = [BTHDMPubs EmptyBytes];
        }
        p.index = i;
        [pubs addObject:p];
    }
    
    [[BTAddressProvider instance] prepareHDMAddressesWithHDSeedId:self.hdSeedId andPubs:pubs];
    if (externalRootCold) {
        [externalRootCold wipe];
    }
    
    if (externalRootHot) {
        [externalRootHot wipe];
    }
    
    return pubs.count;
}

- (NSArray *)completeAddressesWithCount:(UInt32)count password:(NSString *)password andFetchBlock:(void (^)(NSString *password, NSArray *partialPubs))fetchBlock {
    UInt32 uncompletedAddressCount = self.uncompletedAddressCount;
    if (uncompletedAddressCount < count) {
        [NSException raise:@"Not enough uncompleted addesses" format:@"Not enough uncompleted addesses. Need %d, Has %d", count, uncompletedAddressCount, nil];
    }
    NSMutableArray *as = [NSMutableArray new];
    NSArray *pubs = [[BTAddressProvider instance] getUncompletedHDMAddressPubs:self.hdSeedId andCount:count];
    fetchBlock(password, pubs);
    for (BTHDMPubs *p in pubs) {
        if (p.isCompleted) {
            [as addObject:[[BTHDMAddress alloc] initWithPubs:p andKeychain:self syncCompleted:YES]];
        } else if (p.remote) {
            [[BTAddressProvider instance] setHDMPubsRemoteWithHDSeedId:self.hdSeedId andIndex:p.index andPubKeyRemote:p.remote];
        }
    }
    [[BTAddressProvider instance] completeHDMAddressesWithHDSeedId:self.hdSeedId andHDMAddresses:as];
    [self.allCompletedAddresses addObjectsFromArray:as];
    if (self.addressChangeDelegate && [self.addressChangeDelegate respondsToSelector:@selector(hdmAddressAdded:)]) {
        for (BTHDMAddress *a in as) {
            [self.addressChangeDelegate hdmAddressAdded:a];
        }
    }
    return as;
}

- (BTBIP32Key *)masterKey:(NSString *)password {
    [self decryptHDSeed:password];
    BTBIP32Key *master = [[BTBIP32Key alloc] initWithSeed:self.hdSeed];
    [self wipeHDSeed];
    return master;
}

- (BTBIP32Key *)externalChainRoot:(NSString *)password {
    BTBIP32Key *master = [self masterKey:password];
    BTBIP32Key *purpose = [master deriveHardened:44];
    BTBIP32Key *coinType = [purpose deriveHardened:0];
    BTBIP32Key *account = [coinType deriveHardened:0];
    BTBIP32Key *external = [account deriveSoftened:0];
    [master wipe];
    [purpose wipe];
    [coinType wipe];
    [account wipe];
    return external;
}

- (BTBIP32Key *)externalKeyWithIndex:(uint)index andPassword:(NSString *)password {
    BTBIP32Key *externalChainRoot = [self externalChainRoot:password];
    BTBIP32Key *key = [externalChainRoot deriveSoftened:index];
    [externalChainRoot wipe];
    return key;
}

- (NSData *)externalChainRootPubExtended:(NSString *)password {
    BTBIP32Key *ex = [self externalChainRoot:password];
    NSData *pub = [ex getPubKeyExtended];
    [ex wipe];
    return pub;
}

- (NSString *)externalChainRootPubExtendedAsHex:(NSString *)password {
    NSData *pub = [self externalChainRootPubExtended:password];
    return [NSString hexWithData:pub];
}

- (void)decryptHDSeed:(NSString *)password {
    if (self.hdSeedId < 0 || !password) {
        return;
    }
    NSString *encrypted = [self encryptedHDSeed];
    if (![BTUtils isEmpty:encrypted]) {
        self.hdSeed = [[[BTEncryptData alloc] initWithStr:encrypted] decrypt:password];
        if (!self.hdSeed) {
            [BTHDMPasswordWrongException raise:@"password wrong" format:nil];
        }
    }
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

- (NSArray *)addresses {
    return self.allCompletedAddresses;
}

- (NSString *)encryptedHDSeed {
    if (self.isInRecovery) {
        [NSException raise:@"HDMRecover" format:@"recover mode hdm keychain do not have encrypted hd seed"];
    }
    if (self.hdSeedId < 0) {
        return nil;
    }
    return [[BTAddressProvider instance] getEncryptHDSeed:self.hdSeedId];
}

- (NSString *)encryptedMnemonicSeed {
    if (self.isInRecovery) {
        [NSException raise:@"HDMRecover" format:@"recover mode hdm keychain do not have encrypted mnemonic seed"];
    }
    if (self.hdSeedId < 0) {
        return nil;
    }
    return [[BTAddressProvider instance] getEncryptMnemonicSeed:self.hdSeedId];
}

- (NSString *)firstAddressFromSeed:(NSString *)password {
    BTBIP32Key *key = [self externalKeyWithIndex:0 andPassword:password];
    NSString *address = key.key.address;
    [key wipe];
    return address;
}

- (NSString *)firstAddressFromDb {
    return [[BTAddressProvider instance] getHDMFirstAddress:self.hdSeedId];
}

- (BOOL)checkWithPassword:(NSString *)password {
    if (self.isInRecovery) {
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
    BOOL hdSeedSafe = [BTUtils compareString:[self firstAddressFromDb] compare:[self firstAddressFromSeed:nil]];
    BOOL mnemonicSeefSafe = [[BTHDMKeychain seedFromMnemonic:self.mnemonicSeed] isEqualToData:hdCopy];
    hdCopy = nil;
    [self wipeHDSeed];
    [self wipeMnemonicSeed];
    return hdSeedSafe && mnemonicSeefSafe;
}

- (NSString *)signHDMBIdWithMessageHash:(NSString *)messageHash andPassword:(NSString *)password {
    BTBIP32Key *key = [self externalKeyWithIndex:0 andPassword:password];
    NSData *sign = [key.key signHash:[messageHash hexToData]];
    return [NSString hexWithData:sign];
}

- (BOOL)isFromXRandom {
    return _isFromXRandom;
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

- (void)initFromDb {
    _isFromXRandom = [[BTAddressProvider instance] isHDSeedFromXRandom:self.hdSeedId];
    [self initAddressesFromDb];
}

- (void)initAddressesFromDb {
    NSArray *addresses = [[BTAddressProvider instance] getHDMAddressInUse:self];
    if (addresses) {
        [self.allCompletedAddresses addObjectsFromArray:addresses];
    }
}

- (UInt32)uncompletedAddressCount {
    return [[BTAddressProvider instance] uncompletedHDMAddressCount:self.hdSeedId];
}

- (NSArray *)seedWords:(NSString *)password {
    [self decryptMnemonicSeed:password];
    NSArray *words = [[BTBIP39 sharedInstance] toMnemonicArray:self.mnemonicSeed];
    [self wipeMnemonicSeed];
    return words;
}

- (BOOL)isInRecovery {
    return [BTUtils compareString:[[BTAddressProvider instance] getEncryptMnemonicSeed:self.hdSeedId] compare:[BTHDMKeychainRecover RecoverPlaceHolder]] ||
    [BTUtils compareString:[[BTAddressProvider instance] getEncryptHDSeed:self.hdSeedId] compare:[BTHDMKeychainRecover RecoverPlaceHolder]] ||
    [BTUtils compareString:self.firstAddressFromDb compare:[BTHDMKeychainRecover RecoverPlaceHolder]];
}

- (NSString *)getFullEncryptPrivKey {
    return [BTEncryptData encryptedString:self.encryptedMnemonicSeed addIsCompressed:YES andIsXRandom:self.isFromXRandom];
}

- (NSString *)getFullEncryptPrivKeyWithHDMFlag {
    return [HDM_QR_CODE_FLAG stringByAppendingString:[BTEncryptData encryptedString:self.encryptedMnemonicSeed addIsCompressed:YES andIsXRandom:self.isFromXRandom]];
}

- (void)setSingularModeBackup:(NSString *)singularModeBackup {
    [[BTAddressProvider instance] setSingularModeBackupWithHDSeedId:self.hdSeedId andSingularModeBackup:singularModeBackup];
}

+ (NSData *)seedFromMnemonic:(NSData *)mnemonicSeed {
    return [[BTBIP39 sharedInstance] toSeed:[[BTBIP39 sharedInstance] toMnemonic:mnemonicSeed] withPassphrase:@""];
}
@end
