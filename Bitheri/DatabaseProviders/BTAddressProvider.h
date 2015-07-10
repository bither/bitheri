//
//  BTAddressProvider.h
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
#import <Foundation/Foundation.h>
#import "BTHDMBid.h"
#import "BTHDMAddress.h"
#import "BTHDMKeychain.h"
#import "BTAddress.h"
#import "BTPasswordSeed.h"
#import "BTDatabaseManager.h"

@interface BTAddressProvider : NSObject

+ (instancetype)instance;

#pragma mark - password

- (BOOL)changePasswordWithOldPassword:(NSString *)oldPassword andNewPassword:(NSString *)newPassword;

- (BTPasswordSeed *)getPasswordSeed;

- (BOOL)hasPasswordSeed;

+ (BOOL)addPasswordSeedWithPasswordSeed:(BTPasswordSeed *)passwordSeed andDB:(FMDatabase *)db;

#pragma mark - hdm

- (NSArray *)getHDSeedIds;

- (NSString *)getEncryptMnemonicSeed:(int)hdSeedId;

- (NSString *)getEncryptHDSeed:(int)hdSeedId;

//- (void)updateHDSeedWithHDSeedId:(int)hdAccountId andEncryptHDSeed:(NSString *)encryptHDSeed;
//- (void)updateHDSeedWithHDSeedId:(int)hdAccountId andEncryptSeed:(NSString *)encryptSeed andEncryptHDSeed:(NSString *)encryptHDSeed;
- (BOOL)isHDSeedFromXRandom:(int)hdSeedId;

- (NSString *)getHDMFirstAddress:(int)hdSeedId;

- (NSString *)getSingularModeBackup:(int)hdSeedId;

- (void)setSingularModeBackupWithHDSeedId:(int)hdSeedId andSingularModeBackup:(NSString *)singularModeBackup;

- (int)addHDSeedWithMnemonicEncryptSeed:(NSString *)encryptMnemonicSeed andEncryptHDSeed:(NSString *)encryptHDSeed
                        andFirstAddress:(NSString *)firstAddress andIsXRandom:(BOOL)isXRandom
                         andAddressOfPs:(NSString *)addressOfPs;

- (BTHDMBid *)getHDMBid;

- (BOOL)addHDMBid:(BTHDMBid *)hdmBid andAddressOfPS:(NSString *)addressOfPS;

- (NSArray *)getHDMAddressInUse:(BTHDMKeychain *)keychain;

- (BOOL)prepareHDMAddressesWithHDSeedId:(int)hdSeedId andPubs:(NSArray *)pubs;

- (NSArray *)getUncompletedHDMAddressPubs:(int)hdSeedId andCount:(int)count;

- (int)maxHDMAddressPubIndex:(int)hdSeedId;

//including completed and uncompleted
- (BOOL)recoverHDMAddressesWithHDSeedId:(int)hdSeedId andHDMAddresses:(NSArray *)addresses;

- (BOOL)completeHDMAddressesWithHDSeedId:(int)hdSeedId andHDMAddresses:(NSArray *)addresses;

- (void)setHDMPubsRemoteWithHDSeedId:(int)hdSeedId andIndex:(int)index andPubKeyRemote:(NSData *)pubKeyRemote;

- (int)uncompletedHDMAddressCount:(int)hdSeedId;

- (void)updateSyncCompleteHDSeedId:(int)hdSeedId hdSeedIndex:(uint)hdSeedIndex syncComplete:(BOOL)syncComplete;

#pragma mark - normal

- (NSArray *)getAddresses;

- (BOOL)addAddress:(BTAddress *)address;

- (BOOL)addAddresses:(NSArray *)addresses andPasswordSeed:(BTPasswordSeed *)passwordSeed;

- (NSString *)getEncryptPrivKeyWith:(NSString *)address;

- (void)updatePrivateKey:(BTAddress *)address;

- (void)removeWatchOnlyAddress:(BTAddress *)address;

- (void)trashPrivKeyAddress:(BTAddress *)address;

- (void)restorePrivKeyAddress:(BTAddress *)address;

- (void)updateSyncComplete:(BTAddress *)address;

- (NSString *)getAlias:(NSString *)address;

- (NSDictionary *)getAliases;

- (void)updateAliasWithAddress:(NSString *)address andAlias:(NSString *)alias;

-(int) getVanityLen:(NSString *)address;
-(NSDictionary *)getVanityAddresses;
-(void)updateVanityAddress:(NSString *)address andLen:(int)len;

#pragma mark - hd account

//- (int)addHDAccount:(NSString *)encryptedMnemonicSeed encryptSeed:(NSString *)encryptSeed
//       firstAddress:(NSString *)firstAddress isXrandom:(BOOL)isXrandom encryptSeedOfPS:(NSString *)encryptSeedOfPs addressOfPS:(NSString *)addressOfPs
//        externalPub:(NSData *)externalPub internalPub:(NSData *)internalPub;
//
//- (NSData *)getExternalPub:(int)hdSeedid;
//
//- (NSData *)getInternalPub:(int)hdSeedid;
//
//- (NSString *)getHDAccountEncryptSeed:(int)hdAccountId;
//
//- (NSString *)getHDAccountEncryptMnmonicSeed:(int)hdAccountId;
//
//- (NSArray *)getHDAccountSeeds;
//
//- (NSString *)getHDAccountFristAddress:(int)seedId;
//
//- (BOOL)hdAccountIsXRandom:(int)seedId;


@end