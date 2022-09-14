//
//  BTHDAccountCold.m
//  Bitheri
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
//  Created by songchenwen on 15/7/13.
//

#import "BTHDAccountCold.h"
#import "BTEncryptData.h"
#import "BTBIP32Key.h"
#import "BTUtils.h"
#import "BTHDMAddress.h"
#import "BTHDAccountProvider.h"
#import "BTHDAccountAddress.h"
#import "BTAddressManager.h"
#import "BTAddressProvider.h"

@interface BTHDAccountCold () {
    BOOL _isFromXRandom;
}
@property NSData *hdSeed;
@property NSData *mnemonicSeed;
@property int hdAccountId;
@property BTBIP39 *btBip39;

@end

@implementation BTHDAccountCold

- (instancetype)initWithMnemonicSeed:(NSData *)mnemonicSeed btBip39:(BTBIP39 *)bip39 password:(NSString *)password andFromXRandom:(BOOL)isFromXRandom addMode:(AddressAddMode)addMode {
    self = [super init];
    if (self) {
        self.mnemonicSeed = mnemonicSeed;
        self.btBip39 = bip39;
        self.hdSeed = [BTHDAccountCold seedFromMnemonic:mnemonicSeed btBip39:_btBip39];
        _isFromXRandom = isFromXRandom;
        self.addMode = addMode;
        BTBIP32Key *master = [[BTBIP32Key alloc] initWithSeed:self.hdSeed];
        BTEncryptData *encryptedHDSeed = [[BTEncryptData alloc] initWithData:self.hdSeed andPassowrd:password andIsXRandom:isFromXRandom];
        BTEncryptData *encryptedMnemonicSeed = [[BTEncryptData alloc] initWithData:self.mnemonicSeed andPassowrd:password andIsXRandom:isFromXRandom];
        
        NSData *validMnemonicSeed = [encryptedMnemonicSeed decrypt:password];
        NSData *validHdSeed = [BTHDAccountCold seedFromMnemonic:validMnemonicSeed btBip39:_btBip39];
        if (![mnemonicSeed isEqualToData:validMnemonicSeed] || ![_hdSeed isEqualToData:validHdSeed]) {
            @throw [[EncryptionException alloc] initWithName:@"EncryptionException" reason:@"EncryptionException" userInfo:nil];
        }
        
        NSString *addressOfPs = master.key.address;
        BTEncryptData *encryptedDataOfPS = [[BTEncryptData alloc] initWithData:master.secret andPassowrd:password andIsXRandom:isFromXRandom];
        BTBIP32Key *accountKey = [self getAccount:master];
        BTBIP32Key *externalKey = [self getChainRootKeyFromAccount:accountKey withPathType:EXTERNAL_ROOT_PATH];
        BTBIP32Key *internalKey = [self getChainRootKeyFromAccount:accountKey withPathType:INTERNAL_ROOT_PATH];
        BTBIP32Key *key = [externalKey deriveSoftened:0];
        NSString *firstAddress = key.address;
        [accountKey wipe];
        [master wipe];
        [self wipeHDSeed];
        [self wipeMnemonicSeed];
        self.hdAccountId = [[BTHDAccountProvider instance] addHDAccountWithEncryptedMnemonicSeed:encryptedMnemonicSeed.toEncryptedString encryptSeed:encryptedHDSeed.toEncryptedString firstAddress:firstAddress isXRandom:isFromXRandom encryptSeedOfPS:encryptedDataOfPS.toEncryptedString addressOfPS:addressOfPs externalPub:externalKey.getPubKeyExtended internalPub:internalKey.getPubKeyExtended addMode:addMode];
        [externalKey wipe];
        [internalKey wipe];
        
        @try {
            [self seedWords:password];
        } @catch (NSException *e) {
            [self validFailedDelete:password];
            @throw [[EncryptionException alloc] initWithName:@"EncryptionException" reason:@"EncryptionException" userInfo:nil];
        }
    }
    return self;
}

- (instancetype)initWithMnemonicSeed:(NSData *)mnemonicSeed btBip39:(BTBIP39 *)bip39 andPassword:(NSString *)password addMode:(AddressAddMode)addMode {
    return [self initWithMnemonicSeed:mnemonicSeed btBip39:bip39 password:password andFromXRandom:NO addMode:addMode];
}

- (instancetype)initWithEncryptedMnemonicSeed:(BTEncryptData *)encryptedMnemonicSeed btBip39:(BTBIP39 *)bip39 andPassword:(NSString *)password addMode:(AddressAddMode)addMode {
    return [self initWithMnemonicSeed:[encryptedMnemonicSeed decrypt:password] btBip39:bip39 password:password andFromXRandom:encryptedMnemonicSeed.isXRandom addMode:addMode];
}

- (instancetype)initWithSeedId:(int)seedId {
    self = [super init];
    if (self) {
        self.hdAccountId = seedId;
        _isFromXRandom = [[BTHDAccountProvider instance] hdAccountIsXRandom:self.hdAccountId];
        self.addMode = [[BTAddressProvider instance] getAddressAddMode:[NSString stringWithFormat:@"%d", seedId]];
    }
    return self;
}

- (void)validFailedDelete:(NSString *)password {
    if ([[BTAddressManager instance] noAddress]) {
        [[BTAddressProvider instance] deletePassword:password];
    }
    [[BTHDAccountProvider instance] deleteHDAccount:_hdAccountId];
}

- (NSArray *)signHashHexes:(NSArray *)hashes paths:(NSArray *)paths andPassword:(NSString *)password {
    NSMutableArray *a = [[NSMutableArray alloc] init];
    for (NSString *hex in hashes) {
        [a addObject:[hex hexToData]];
    }
    return [self signHashes:a paths:paths andPassword:password];
}

- (NSArray *)signHashes:(NSArray *)hashes paths:(NSArray *)paths andPassword:(NSString *)password {
    assert(hashes.count == paths.count);
    NSMutableArray *sigs = [[NSMutableArray alloc] init];
    BTBIP32Key *master = [self masterKey:password];
    BTBIP32Key *account = [self getAccount:master];
    BTBIP32Key *purpose49Account = [self getAccount:master withPurposePathLevel:P2SHP2WPKH];
    BTBIP32Key *external = [self getChainRootKeyFromAccount:account withPathType:EXTERNAL_ROOT_PATH];
    BTBIP32Key *internal = [self getChainRootKeyFromAccount:account withPathType:INTERNAL_ROOT_PATH];
    BTBIP32Key *purpose49External = [self getChainRootKeyFromAccount:purpose49Account withPathType:EXTERNAL_ROOT_PATH];
    BTBIP32Key *purpose49Internal = [self getChainRootKeyFromAccount:purpose49Account withPathType:INTERNAL_ROOT_PATH];
    [master wipe];
    [account wipe];
    [purpose49Account wipe];
    NSUInteger count = hashes.count;
    for (NSUInteger i = 0; i < count; i++) {
        NSData *hash = [hashes objectAtIndex:i];
        PathTypeIndex *path = [paths objectAtIndex:i];
        BTBIP32Key *key;
        if (path.pathType == EXTERNAL_ROOT_PATH) {
            key = [external deriveSoftened:(uint) path.index];
        } else if (path.pathType == INTERNAL_ROOT_PATH) {
            key = [internal deriveSoftened:(uint) path.index];
        } else if (path.pathType == EXTERNAL_BIP49_PATH) {
            key = [purpose49External deriveSoftened:(uint) path.index];
        } else {
            key = [purpose49Internal deriveSoftened:(uint) path.index];
        }
        if ([path isSegwit]) {
            NSData *sign = [BTHDAccountUtil getSign:key.key unsignedHash:hash];
            [sigs addObject:[BTHDAccountUtil getWitness:key.pubKey sign:sign]];
        } else {
            NSMutableData *s = [NSMutableData dataWithData:[key.key sign:hash]];
            NSMutableData *sig = [NSMutableData data];
            [s appendUInt8:SIG_HASH_ALL];
            [sig appendScriptPushData:s];
            [sig appendScriptPushData:[key.key publicKey]];
            [sigs addObject:sig];
        }
        [key wipe];
    }
    [external wipe];
    [internal wipe];
    [purpose49External wipe];
    [purpose49Internal wipe];
    return sigs;
}

- (NSData *)accountPubExtended:(NSString *)password {
    BTBIP32Key *master = [self masterKey:password];
    BTBIP32Key *account = [self getAccount:master];
    NSData *extended = account.getPubKeyExtended;
    [master wipe];
    [account wipe];
    return extended;
}

- (NSString *)accountPubExtendedString:(NSString *)password {
    NSData *extended = [self accountPubExtended:password];
    return [NSString stringWithFormat:@"%@%@", self.isFromXRandom ? XRANDOM_FLAG : @"", [NSString hexWithData:extended]];
}

- (NSString *)getQRCodeFullEncryptPrivKeyWithHDQrCodeFlatType:(HDQrCodeFlatType)qrCodeFlatType {
    return [[BTQRCodeUtil getHDQrCodeFlat:qrCodeFlatType] stringByAppendingString:[BTEncryptData encryptedString:self.encryptedMnemonicSeed addIsCompressed:YES andIsXRandom:self.isFromXRandom]];
}

- (NSArray *)seedWords:(NSString *)password {
    [self decryptMnemonicSeed:password];
    NSArray *words = [[self getBip39] toMnemonicArray:self.mnemonicSeed];
    NSString *validFirstAddress = [self getValidFirstAddress:words];
    NSString *dbFirstAddress = [self getFirstAddressFromDb];
    [self wipeMnemonicSeed];
    if (![validFirstAddress isEqualToString:dbFirstAddress]) {
        @throw [[EncryptionException alloc] initWithName:@"EncryptionException" reason:@"EncryptionException" userInfo:nil];
    }
    return words;
}

- (BTBIP39 *)getBip39 {
    return  !_btBip39 ? [BTBIP39 sharedInstance] : _btBip39;
}

- (NSString *)getValidFirstAddress:(NSArray *)words {
    if (words == NULL || words.count == 0) {
        @throw [[EncryptionException alloc] initWithName:@"EncryptionException" reason:@"EncryptionException" userInfo:nil];
    }
    BTBIP39 *bip39 = [BTBIP39 sharedInstance];
    NSString *code = [bip39 toMnemonicWithArray:words];
    NSData *mnemonicCodeSeed = [bip39 toEntropy:code];
    if (mnemonicCodeSeed == NULL) {
        @throw [[EncryptionException alloc] initWithName:@"EncryptionException" reason:@"EncryptionException" userInfo:nil];
    }
    NSData *hdSeed = [BTHDAccountCold seedFromMnemonic:mnemonicCodeSeed btBip39:bip39];
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
    BOOL mnemonicSeefSafe = [[BTHDAccountCold seedFromMnemonic:self.mnemonicSeed btBip39:nil] isEqualToData:hdCopy];
    [self wipeHDSeed];
    [self wipeMnemonicSeed];
    return hdSeedSafe && mnemonicSeefSafe;
}

- (NSString *)getFirstAddressFromDb {
    return [[BTHDAccountProvider instance] getHDFirstAddress:self.hdAccountId];
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

- (NSInteger)getHDAccountId {
    return self.hdAccountId;
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
    BTBIP32Key *purpose = [master deriveHardened:NormalAddress];
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

- (BTBIP32Key *)xPub:(NSString *)password withPurposePathLevel:(PurposePathLevel)purposePathLevel {
    BTBIP32Key *master = [self masterKey:password];
    BTBIP32Key *account = [self getAccount:master withPurposePathLevel:purposePathLevel];
    [master wipe];
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
    if (self.hdAccountId < 0 || !password) {
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
    return [[BTHDAccountProvider instance] getHDAccountEncryptSeed:self.hdAccountId];
}

- (NSString *)encryptedMnemonicSeed {
    return [[BTHDAccountProvider instance] getHDAccountEncryptMnemonicSeed:self.hdAccountId];
}

- (BTBIP32Key *)getChainRootKeyFromAccount:(BTBIP32Key *)account withPathType:(PathType)path {
    return [account deriveSoftened:path];
}

+ (NSData *)seedFromMnemonic:(NSData *)mnemonicSeed btBip39:(BTBIP39 *)bip39 {
    if (!bip39) {
        return [[BTBIP39 sharedInstance] toSeed:[[BTBIP39 sharedInstance] toMnemonic:mnemonicSeed] withPassphrase:@""];
    }
    return [bip39 toSeed:[bip39 toMnemonic:mnemonicSeed] withPassphrase:@""];
}

- (void)setIsFromXRandom:(BOOL)isFromXRandom {
    _isFromXRandom = isFromXRandom;
}

- (BOOL)isFromXRandom {
    return _isFromXRandom;
}
@end
