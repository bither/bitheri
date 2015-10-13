//
//  BTAddressManager.h
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
#import "BTAddress.h"
#import "BTSettings.h"
#import "BTHDMKeychain.h"
#import "BTHDAccount.h"
#import "BTHDAccountCold.h"

#define BTAddressManagerIsReady @"BTAddressManagerIsReady"

@interface BTAddressManager : NSObject

@property(nonatomic, strong) NSMutableArray *privKeyAddresses;
@property(nonatomic, strong) NSMutableArray *watchOnlyAddresses;
@property(nonatomic, strong) NSMutableArray *trashAddresses;
@property(nonatomic, strong) BTHDMKeychain *hdmKeychain;
@property(nonatomic, strong) BTHDAccount *hdAccountHot;
@property(nonatomic, strong) BTHDAccount *hdAccountMonitored;
@property(nonatomic, readonly) BTHDAccountCold* hdAccountCold;
@property(nonatomic, readonly) BOOL hasHDMKeychain;
@property(nonatomic, readonly) BOOL hasHDAccountHot;
@property(nonatomic, readonly) BOOL hasHDAccountMonitored;
@property(nonatomic, readonly) BOOL hasHDAccountCold;
@property(nonatomic, strong) NSMutableSet *addressesSet;
@property(nonatomic, readonly) NSMutableArray *allAddresses;
@property(nonatomic, readonly) NSTimeInterval creationTime; // interval since refrence date, 00:00:00 01/01/01 GMT
@property(nonatomic, readwrite) BOOL isReady;

+ (instancetype)instance;

- (void)initAddress;

- (NSInteger)addressCount;

- (void)addAddress:(BTAddress *)address;

- (void)stopMonitor:(BTAddress *)address;

- (void)trashPrivKey:(BTAddress *)address;

- (void)restorePrivKey:(BTAddress *)address;

- (NSMutableArray *)allAddresses;

- (BOOL)changePassphraseWithOldPassphrase:(NSString *)oldPassphrase andNewPassphrase:(NSString *)newPassphrase;

- (BOOL)allSyncComplete;

- (BOOL)registerTx:(BTTx *)tx withTxNotificationType:(TxNotificationType)txNotificationType confirmed:(BOOL) confirmed;

- (BOOL)isTxRelated:(BTTx *)tx;

- (NSArray *)outs;

- (NSArray *)unSpentOuts;

- (void)blockChainChanged;

- (NSArray *)compressTxsForApi:(NSArray *)txList andAddress:(NSString *)address;

- (BTHDAccount *)getHDAccountByHDAccountId:(int)hdAccountId;

#pragma mark - for old version

+ (BOOL)updateKeyStoreFromFileToDbWithPasswordSeed:(BTPasswordSeed *)passwordSeed;
@end