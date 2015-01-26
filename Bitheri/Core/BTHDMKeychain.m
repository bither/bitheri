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
#import "NSString+Base58.h"

@interface BTHDMKeychain(){
    BOOL _isFromXRandom;
}
@property NSData* hdSeed;
@property NSData* mnemonicSeed;
@end

@implementation BTHDMKeychain

-(instancetype)initWithMnemonicSeed:(NSData*)seed password:(NSString*)password andXRandom:(BOOL)xrandom{
    self = [super init];
    if(self){
        self.hdSeedId = -1;
        self.mnemonicSeed = seed;
        self.hdSeed = [BTHDMKeychain seedFromMnemonic:self.mnemonicSeed];
        //TODO: encrypt hdSeed and mnemonic seed
        NSString *firstAddress = [self firstAddressFromSeed:password];
        [self wipeHDSeed];
        [self wipeMnemonicSeed];
        _isFromXRandom = xrandom;
        self.hdSeedId = [[BTAddressProvider instance]addHDSeedWithEncryptSeed:nil andEncryptHDSeed:nil andFirstAddress:firstAddress andIsXRandom:xrandom];
        self.allCompletedAddresses = [[NSMutableArray alloc]init];
    }
    return self;
}

-(instancetype)initWithSeedId:(int)seedId{
    self = [super init];
    if(self){
        self.hdSeedId = seedId;
        self.allCompletedAddresses = [[NSMutableArray alloc]init];
        [self initFromDb];
    }
    return self;
}

-(instancetype)initWithEncrypted:(NSString*)encryptedMnemonicSeed password:(NSString*) password andFetchDelegate:(NSObject<BTHDMFetchRemoteAddressesDelegate>*)fetchDelegate{
    self = [super init];
    if(self){
        self.hdSeedId = -1;
        self.mnemonicSeed = nil; //TODO: decrype encrypted mnemonic seed
        self.hdSeed = [BTHDMKeychain seedFromMnemonic:self.mnemonicSeed];
        _isFromXRandom = NO; //TODO: is from xrandom from encrypted mnemonic seed
        //TODO: encrypt hd seed here
        self.allCompletedAddresses = [[NSMutableArray alloc]init];
        NSMutableArray* as = [[NSMutableArray alloc]init];
        NSMutableArray* uncompPubs = [[NSMutableArray alloc]init];
        if(fetchDelegate){
            NSArray* pubs = [fetchDelegate getRemoteExistsPublicKeysWithPassword:password];
            if(pubs && pubs.count > 0){
                BTBIP32Key* root = [self externalChainRoot:password];
                NSData* pubDerived = [root deriveSoftened:0].pubKey;
                NSData* pubFetched = pubs[0].hot;
                [root wipe];
                if(![pubDerived isEqualToData:pubFetched]){
                    [self wipeMnemonicSeed];
                    [self wipeHDSeed];
                    [NSException raise:@"HDM Bither ID Not Match" format:nil];
                }
            }
            for(BTHDMPubs* p in pubs){
                if(p.isCompleted){
                    BTHDMAddress* a = [[BTHDMAddress alloc]initWithPubs:p andKeychain:self];
                    [as addObject: a];
                }else{
                    [uncompPubs addObject:p];
                }
            }
        }
        NSString* firstAddress = [self firstAddressFromSeed:password];
        [self wipeHDSeed];
        [self wipeMnemonicSeed];
        self.hdSeedId = [[BTAddressProvider instance]addHDSeedWithEncryptSeed:nil andEncryptHDSeed:nil andFirstAddress:firstAddress andIsXRandom:_isFromXRandom];
        if(as.count > 0){
            [[BTAddressProvider instance]completeHDMAddressesWithHDSeedId:self.hdSeedId andHDMAddresses:as];
            [self.allCompletedAddresses addObjectsFromArray:as];
            if(uncompPubs.count > 0){
                [[BTAddressProvider instance]prepareHDMAddressesWithHDSeedId:self.hdSeedId andPubs:uncompPubs];
                for(BTHDMPubs* p : uncompPubs){
                    [[BTAddressProvider instance] setHDMPubsRemoteWithHDSeedId:self.hdSeedId andIndex:p.index andPubKeyRemote:p.remote];
                }
            }
        }
    }
    return self;
}

-(BTBIP32Key*)masterKey:(NSString*)password{
    [self decryptHDSeed:password];
    BTBIP32Key *master = [[BTBIP32Key alloc]initWithSeed:self.hdSeed];
    [self wipeHDSeed];
    return master;
}

-(BTBIP32Key*)externalChainRoot:(NSString*)password{
    BTBIP32Key* master = [self masterKey:password];
    BTBIP32Key* purpose = [master deriveHardened:44];
    BTBIP32Key* coinType = [purpose deriveHardened:0];
    BTBIP32Key* account = [coinType deriveHardened:0];
    BTBIP32Key* external = [account deriveSoftened:0];
    [master wipe];
    [purpose wipe];
    [coinType wipe];
    [account wipe];
    return external;
}

-(BTBIP32Key*)externalKeyWithIndex:(uint) index andPassword:(NSString*)password{
    BTBIP32Key* externalChainRoot = [self externalChainRoot:password];
    BTBIP32Key* key = [externalChainRoot deriveSoftened:index];
    [externalChainRoot wipe];
    return key;
}

-(NSData*)externalChainRootPubExtended:(NSString*)password{
    BTBIP32Key* ex = [self externalChainRoot:password];
    NSData* pub = [ex getPubKeyExtended];
    [ex wipe];
    return pub;
}

-(NSString*)externalChainRootPubExtendedAsHex:(NSString*)password{
    NSData* pub = [self externalChainRootPubExtended:password];
    return [NSString hexWithData:pub];
}

-(void)decryptHDSeed:(NSString*)password{
    if(self.hdSeedId < 0 || !password){
        return;
    }
    NSString* encrypted = [self encryptedHDSeed];
    if(![BTUtils isEmpty:encrypted]){
        //TODO: encrypted data goes here
    }
}

-(void)decryptMnemonicSeed:(NSString*)password{
    if(self.hdSeedId < 0 || !password){
        return;
    }
    NSString* encrypted = [self encryptedMnemonicSeed];
    if(![BTUtils isEmpty:encrypted]){
        //TODO: encrypted data goes here
    }
}

-(NSArray*)addresses{
    return self.allCompletedAddresses;
}

-(NSString*)encryptedHDSeed{
    if(self.isInRecovery){
        [NSException raise:@"HDMRecover" format:@"recover mode hdm keychain do not have encrypted hd seed"];
    }
    if(self.hdSeedId < 0){
        return nil;
    }
    return [[BTAddressProvider instance]getEncryptHDSeed:self.hdSeedId];
}

-(NSString*)encryptedMnemonicSeed{
    if(self.isInRecovery){
        [NSException raise:@"HDMRecover" format:@"recover mode hdm keychain do not have encrypted mnemonic seed"];
    }
    if(self.hdSeedId < 0){
        return nil;
    }
    return [[BTAddressProvider instance]getEncryptSeed:self.hdSeedId];
}

-(NSString*)firstAddressFromSeed:(NSString*)password {
    BTBIP32Key* key = [self externalKeyWithIndex:0 andPassword:password];
    NSString *address = key.key.address;
    [key wipe];
    return address;
}

-(NSString*)firstAddressFromDb{
    return [[BTAddressProvider instance]getHDFirstAddress:self.hdSeedId];
}

-(BOOL)checkWithPassword:(NSString*)password{
    if(self.isInRecovery){
        return YES;
    }
    [self decryptHDSeed:password];
    if(!self.hdSeed){
        return NO;
    }
    [self decryptMnemonicSeed:password];
    if(!self.mnemonicSeed){
        return NO;
    }
    NSData* hdCopy = [NSData dataWithBytes:self.hdSeed length:self.hdSeed.length];
    BOOL hdSeedSafe = [BTUtils compareString:[self firstAddressFromDb] compare:[self firstAddressFromSeed:nil]];
    BOOL mnemonicSeefSafe = [[BTHDMKeychain seedFromMnemonic:self.mnemonicSeed] isEqualToData:hdCopy];
    hdCopy = nil;
    [self wipeHDSeed];
    [self wipeMnemonicSeed];
    return hdSeedSafe && mnemonicSeefSafe;
}

-(NSString*)signHDMBIdWithMessageHash:(NSString*)messageHash andPassword:(NSString*)password{
    BTBIP32Key *key = [self externalKeyWithIndex:0 andPassword:password];
    NSData* sign = [key.key sign:[messageHash hexToData]];
    return [[NSString hexWithData:sign] uppercaseString];
}

-(BOOL)isFromXRandom{
    return _isFromXRandom;
}

-(void)wipeHDSeed{
    if(!self.hdSeed){
        return;
    }
    self.hdSeed = nil;
}

-(void)wipeMnemonicSeed{
    if(!self.mnemonicSeed){
        return;
    }
    self.mnemonicSeed = nil;
}

-(void)initFromDb{
    _isFromXRandom = [[BTAddressProvider instance]isHDSeedFromXRandom:self.hdSeedId];
    [self initAddressesFromDb];
}

-(void)initAddressesFromDb{
    NSArray* addresses = [[BTAddressProvider instance]getHDMAddressInUse:self];
    if(addresses){
        [self.allCompletedAddresses addObjectsFromArray:addresses];
    }
}

-(NSUInteger)uncompletedAddressCount{
    return [[BTAddressProvider instance] uncompletedHDMAddressCount:self.hdSeedId];
}

-(BOOL)isInRecovery{
    return [BTUtils compareString:[[BTAddressProvider instance]getEncryptSeed:self.hdSeedId] compare:[BTHDMKeychainRecover RecoverPlaceHolder]] ||
    [BTUtils compareString:[[BTAddressProvider instance]getEncryptHDSeed:self.hdSeedId] compare:[BTHDMKeychainRecover RecoverPlaceHolder]] ||
    [BTUtils compareString:self.firstAddressFromDb compare:[BTHDMKeychainRecover RecoverPlaceHolder]];
}

+(NSData*)seedFromMnemonic:(NSData*) mnemonicSeed{
    return [[BTBIP39 sharedInstance] toSeed:[[BTBIP39 sharedInstance] toMnemonic:mnemonicSeed] withPassphrase:@""];
}
@end