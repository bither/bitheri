//
//  BTTxProvider.h
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
#import "BTDatabaseManager.h"
#import "BTTx.h"
#import "BTOut.h"

@interface BTTxProvider : NSObject

+ (instancetype)instance;

- (void)add:(BTTx *)txItem;

- (void)addTxs:(NSArray *)txs;

- (BOOL)isExist:(NSData *)txHash;

- (BTTx *)getTxDetailByTxHash:(NSData *)txHash;

- (NSArray *)getTxAndDetailByAddress:(NSString *)address;

- (NSArray *)getTxAndDetailByAddress:(NSString *)address andPage:(int)page;

- (uint64_t)sentFromAddress:(NSData *)txHash address:(NSString *)address;

- (bool)isAddress:(NSString *)address containsTx:(BTTx *)txItem;

- (bool)isTxDoubleSpendWithConfirmedTx:(BTTx *)tx;

- (NSArray *)getInAddresses:(BTTx *)tx;

- (void)confirmTx:(NSArray *)txHashes withBlockNo:(int)blockNo;

- (void)unConfirmTxByBlockNo:(int)blockNo;

- (NSArray *)getUnspendTxWithAddress:(NSString *)address;

- (NSArray *)getUnspendOutWithAddress:(NSString *)address;

- (NSArray *)getUnSpendOutCanSpendWithAddress:(NSString *)address;

- (NSArray *)getUnSpendOutButNotConfirmWithAddress:(NSString *)address;

- (void)remove:(NSData *)txHash;

- (uint32_t)txCount:(NSString *)address;

- (void)txSentBySelfHasSaw:(NSData *)txHash;

- (NSArray *)getOuts;

- (NSArray *)getUnSpentOuts;

- (NSArray *)getRelatedIn:(NSString *)address;

- (NSArray *)getRecentlyTxsByAddress:(NSString *)address andGreaterThanBlockNo:(int)blockNo andLimit:(int)limit;

- (NSArray *)txInValues:(NSData *)txHash;

- (NSDictionary *)getTxDependencies:(BTTx *)txItem;

- (NSArray *)getPublishedTxs;

- (void)clearAllTx;

- (BTOut *)getOutByTxHash:(NSData *)txHash andOutSn:(int)outSn;

- (void)completeInSignatureWithIns:(NSArray *)ins;

- (uint32_t)needCompleteInSignature:(NSString *)address;

- (uint64_t)getConfirmedBalanceWithAddress:(NSString *)address;

- (NSArray *)getUnconfirmedTxWithAddress:(NSString *)address;

- (uint64_t)getTotalReceiveWithAddress:(NSString *)address;

- (NSData *)isIdentify:(BTTx *)tx;

- (NSArray *)getPrevOutsWithAddress:(NSString *)address coin:(Coin)coin;

- (NSArray *)getPrevUnspendTxsWithAddress:(NSString *)address outs:(NSArray *)outs;

@end
