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


@interface BTAddressManager : NSObject

@property (nonatomic, strong) NSMutableArray *privKeyAddresses;
@property (nonatomic, strong) NSMutableArray *watchOnlyAddresses;
@property (nonatomic, readonly) NSMutableArray *allAddresses;
@property (nonatomic, readonly) NSTimeInterval creationTime; // interval since refrence date, 00:00:00 01/01/01 GMT
+ (instancetype)instance;

- (void)initAddress;
- (NSInteger)addressCount;

- (void)addAddress:(BTAddress *)address;

- (void)stopMonitor:(BTAddress *)address;

- (NSMutableArray *)allAddresses;
- (BOOL)changePassphraseWithOldPassphrase:(NSString *)oldPassphrase andNewPassphrase:(NSString *)newPassphrase;
- (BOOL)allSyncComplete;

- (BOOL)registerTx:(BTTx *)tx withTxNotificationType:(TxNotificationType)txNotificationType;
- (BOOL)isTxRelated:(BTTx *)tx;
- (NSArray *)outs;

@end