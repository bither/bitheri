//
//  BTHDAccountProvider.h
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
#import "BTHDAccountAddress.h"
#import "BTDatabaseManager.h"


@interface BTHDAccountProvider : NSObject

+ (instancetype)instance;

- (void)addAddress:(NSArray *)array;

- (int)issuedIndex:(PathType)path;

- (int)allGeneratedAddressCount:(PathType)pathType;

- (void)updateIssuedIndex:(PathType)pathType index:(int)index;

- (NSString *)externalAddress;

- (BTHDAccountAddress *)addressForPath:(PathType)type index:(int)index;

- (NSArray *)getPubs:(PathType)pathType;

- (NSArray *)belongAccount:(NSArray *)addresses;

- (void)updateSyncdComplete:(BTHDAccountAddress *)address;

- (void)setSyncdNotComplete;

- (int)unSyncedAddressCount;

- (int)unSyncedCountOfPath:(PathType)pathType;

- (void)updateSyncdForIndex:(PathType)pathType index:(int)index;

- (NSArray *)getSigningAddressesForInputs:(NSArray *)inList;

- (int)hdAccountTxCount;

- (long long)getHDAccountConfirmedBanlance:(int)hdAccountId;

- (NSArray *)getHDAccountUnconfirmedTx;

- (long long)sentFromAccount:(int)hdAccountId txHash:(NSData *)txHash;

- (NSArray *)getTxAndDetailByHDAccount:(int)page;

- (NSArray *)getUnspendOutByHDAccount:(int)hdAccountId;

- (NSArray *)getRecentlyTxsByAccount:(int)greateThanBlockNo limit:(int)limit;

- (NSSet *)getBelongAccountAddressesFromAdresses:(NSArray *)addressList;

- (NSSet *)getBelongAccountAddressesFromDb:(FMDatabase *)db addressList:(NSArray *)addressList;

@end