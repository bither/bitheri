//
//  BTHDAccountAddressProvider.h
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
#import "BTTx.h"

@class BTOut;

@interface BTHDAccountAddressProvider : NSObject

+ (instancetype)instance;

- (void)addAddress:(NSArray *)array;

- (int)getIssuedIndexByHDAccountId:(int)hdAccountId pathType:(PathType)path;

- (int)getGeneratedAddressCountByHDAccountId:(int)hdAccountId pathType:(PathType)pathType;

- (void)updateIssuedByHDAccountId:(int)hdAccountId pathType:(PathType)pathType index:(int)index;

- (NSString *)getExternalAddress:(int)hdAccountId path:(PathType)type;

- (BTHDAccountAddress *)getAddressByHDAccountId:(int)hdAccountId path:(PathType)type index:(int)index;

- (NSArray *)getPubsByHDAccountId:(int)hdAccountId pathType:(PathType)pathType;

- (NSArray *)getBelongHDAccount:(int)hdAccountId fromAddresses:(NSArray *)addresses;

- (NSArray *)getBelongHDAccountFrom:(NSArray *)addresses;

- (void)updateSyncedCompleteByHDAccountId:(int)hdAccountId address:(BTHDAccountAddress *)address;

- (void)setSyncedAllNotComplete;

- (int)getUnSyncedAddressCount:(int)hdAccountId;

- (int)getUnSyncedAddressCountByHDAccountId:(int)hdAccountId pathType:(PathType)pathType;

- (void)updateSyncedByHDAccountId:(int)hdAccountId pathType:(PathType)pathType index:(int)index;

- (NSArray *)getSigningAddressesByHDAccountId:(int)hdAccountId fromInputs:(NSArray *)inList;

- (int)getHDAccountTxCount:(int)hdAccountId;

- (uint64_t)getHDAccountConfirmedBalance:(int)hdAccountId;

- (NSArray *)getHDAccountUnconfirmedTx:(int)hdAccountId;

- (uint64_t)getAmountSentFromHDAccount:(int)hdAccountId txHash:(NSData *)txHash;

- (NSArray *)getTxAndDetailByHDAccount:(int)hdAccountId;

- (NSArray *)getTxAndDetailByHDAccount:(int)hdAccountId page:(int)page;

- (NSArray *)getUnspendOutByHDAccount:(int)hdAccountId;

- (BTOut *)getPrevOutByTxHash:(NSData *)txHash outSn:(uint)outSn;

- (NSArray *)getPrevCanSplitOutsByHDAccount:(int)hdAccountId coin:(Coin)coin;

- (NSArray *)getRecentlyTxsByHDAccount:(int)hdAccountId blockNo:(int)greaterThanBlockNo limit:(int)limit;

- (NSSet *)getBelongHDAccountAddressesFromAddresses:(NSArray *)addressList;

- (NSSet *)getAddressesByHDAccount:(int)hdAccountId fromAddresses:(NSArray *)addressList;

- (NSSet *)getBelongHDAccountAddressesFromDb:(FMDatabase *)db addressList:(NSArray *)addressList;

- (int)getUnspendOutCountByHDAccountId:(int)hdAccountId pathType:(PathType)pathType;

- (NSArray *)getUnspendOutByHDAccountId:(int)hdAccountId pathType:(PathType)pathType;

- (int)getUnconfirmedSpentOutCountByHDAccountId:(int)hdAccountId pathType:(PathType)pathType;

- (NSArray *)getUnconfirmedSpentOutByHDAccountId:(int)hdAccountId pathType:(PathType)pathType;

- (BTTx *)updateOutHDAccountId:(BTTx *)tx;

- (NSArray *)getRelatedHDAccountIdListFromAddresses:(NSArray *)addresses;

- (BOOL)requestNewReceivingAddress:(int)hdAccountId pathType:(PathType)pathType;

- (BOOL)hasHDAccount:(int)hdAccountId pathType:(PathType) pathType receiveTxInAddressCount:(int) addressCount;

- (void)deleteHDAccountAddress:(int)hdAccountId;

@end
