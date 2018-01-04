//
//  BTTxBuilder.h
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
//  limitations under the License.#import <Foundation/Foundation.h>


@class BTTx;
@class BTAddress;

@interface BTTxBuilder : NSObject
+ (instancetype)instance;

- (BTTx *)buildTxForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey andAmount:(NSArray *)amounts
                 andAddress:(NSArray *)addresses andError:(NSError **)error;

- (BTTx *)buildTxForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey andAmount:(NSArray *)amounts
                 andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andError:(NSError **)error;

- (BTTx *)buildTxForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey andAmount:(NSArray *)amounts
                 andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andError:(NSError **)error coin:(Coin)coin;

- (NSArray *)buildSplitCoinTxsForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey andAmount:(NSArray *)amounts andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andError:(NSError **)error coin:(Coin)coin;

- (NSArray *)buildBccTxsForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey andAmount:(NSArray *)amounts andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andUnspentOuts:(NSArray *)unspendOuts andError:(NSError **)error;

- (BTTx *)buildTxWithOutputs:(NSArray *)outs toAddresses:(NSArray *)addresses amounts:(NSArray *)amounts changeAddress:(NSString *)changeAddress andError:(NSError **)error;

- (NSArray *)buildSplitCoinTxsWithOutputs:(NSArray *)unspendOuts toAddresses:(NSArray *)addresses amounts:(NSArray *)amounts changeAddress:(NSString *)changeAddress andError:(NSError **)error coin:(Coin)coin;

+ (uint64_t)getAmount:(NSArray *)outs;

@end

@protocol BTTxBuilderProtocol

@required
- (BTTx *)buildTxForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey WithUnspendTxs:(NSArray *)unspendTxs andTx:(BTTx *)tx andChangeAddress:(NSString *)changeAddress coin:(Coin)coin;

- (BTTx *)buildTxWithOutputs:(NSArray *)outs toAddresses:(NSArray *)addresses amounts:(NSArray *)amounts changeAddress:(NSString *)changeAddress andTx:(BTTx *)tx coin:(Coin)coin;
@optional
- (BTTx *)buildBccTxForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey WithUnspendOuts:(NSArray *)unspendOuts andTx:(BTTx *)tx andChangeAddress:(NSString *)changeAddress;
@end

@interface BTTxBuilderEmptyWallet : NSObject <BTTxBuilderProtocol>
@end

@interface BTTxBuilderWithoutFee : NSObject <BTTxBuilderProtocol>
@end

@interface BTTxBuilderWithoutCharge : NSObject <BTTxBuilderProtocol>
@end

@interface BTTxBuilderDefault : NSObject <BTTxBuilderProtocol>
@end
