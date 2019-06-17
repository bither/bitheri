//
//  BTTx.h
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
//#import "BTTxItem.h"

#import "NSString+Base58.h"
#import "NSMutableData+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "NSData+Hash.h"

@class BTKey;
@class BTAddress;
@class BTOut;
@class BTHDAccount;
@class BTIn;

#if TX_FEE_07_RULES
#define TX_FEE_PER_KB        50000llu    // standard tx fee per kb of tx size, rounded up to the nearest kb (0.7 rules)
#else
#define TX_FEE_PER_KB        10000llu    // standard tx fee per kb of tx size, rounded up to the nearest kb
#endif

typedef enum {
    BTC, BCC, BTG, SBTC, BTW, BCD, BTF, BTP, BTN
} Coin;

@interface BTTx : NSObject

@property(nonatomic, assign) uint32_t blockNo;
@property(nonatomic, copy) NSData *txHash;
@property(nonatomic, copy) NSData *blockHash;
@property(nonatomic, assign) uint32_t txVer;
@property(nonatomic, assign) uint32_t txLockTime;
@property(nonatomic, assign) uint32_t txTime;
@property(nonatomic, assign) int source;
@property(nonatomic, assign) int sawByPeerCnt;

@property(nonatomic, strong) NSMutableArray *ins;
@property(nonatomic, strong) NSMutableArray *outs;

@property(nonatomic, readonly) uint confirmationCnt;
@property(nonatomic, readonly) BOOL isCoinBase;
@property(nonatomic, readwrite) Coin coin;
@property(nonatomic, readwrite) BOOL isDetectBcc;
@property(nonatomic, assign) BOOL isSegwitAddress;
@property(nonatomic, strong) NSMutableArray *witnesses;

+ (instancetype)transactionWithMessage:(NSData *)message;

- (instancetype)initWithMessage:(NSData *)message;

- (instancetype)initWithTxDict:(NSDictionary *)txDict unspentOutAddress:(NSString *)unspentOutAddress;

#pragma mark - manage in & out

- (void)addInputHash:(NSData *)hash index:(NSUInteger)index script:(NSData *)script;

- (void)addInputHash:(NSData *)hash index:(NSUInteger)index script:(NSData *)script signature:(NSData *)signature
            sequence:(uint32_t)sequence;

- (void)setInputAddress:(NSString *)address atIndex:(NSUInteger)index;

- (void)setInScript:(NSData *)script forInHash:(NSData *)inHash andInIndex:(NSUInteger)inIndex;

- (void)clearIns;

- (void)addOutputAddress:(NSString *)address amount:(uint64_t)amount;

- (void)addOutputScript:(NSData *)script amount:(uint64_t)amount;


#pragma mark - sign

- (BOOL)signWithPrivateKeys:(NSArray *)privateKeys;

- (NSArray *)unsignedInHashes;

- (NSArray *)unsignedInHashesForBcc:(uint64_t []) preOutValues;

- (NSData *)getSegwitUnsignedInHashesForRedeemScript:(NSData *)redeemScript btIn:(BTIn *)btIn;

- (NSData *)getUnsignedInHashesForIn:(BTIn *)btIn;

- (BOOL)signWithSignatures:(NSArray *)signatures;

- (BOOL)signWithPrivateKeys:(NSArray *)privateKeys andUnspentOuts:(NSArray *) unspentOuts;

- (NSData *)hashForSignature:(NSUInteger)inputIndex connectedScript:(NSData *)connectedScript sigHashType:(uint8_t)sigHashType;

- (NSData *)bcdHashForSignature:(NSUInteger)inputIndex connectedScript:(NSData *)connectedScript sigHashType:(uint8_t)sigHashType;

- (NSData *)sbtcHashForSignature:(NSUInteger)inputIndex connectedScript:(NSData *)connectedScript sigHashType:(uint8_t)sigHashType;

- (NSData *)hashForSignatureWitness:(NSUInteger)inputIndex connectedScript:(NSData *)connectedScript type:(u_int8_t)type prevValue:(uint64_t)prevValue anyoneCanPay:(BOOL)anyoneCanPay coin:(Coin)coin;

- (BOOL)isSigned;

- (BOOL)verify;

- (BOOL)verifySignatures;

#pragma mark - query

- (NSArray *)getInAddresses;

- (NSData *)toData;

- (NSData *)toSegwitTxHashData;

- (NSData *)bcdToData;

- (size_t)size;

- (BOOL)hasDustOut;

- (BTOut *)getOut:(uint)outSn;

// priority = sum(input_amount_in_satoshis*input_age_in_blocks)/tx_size_in_bytes
- (uint64_t)priorityForAmounts:(NSArray *)amounts withAges:(NSArray *)ages;

// the block height after which the transaction can be confirmed without a fee, or TX_UNCONFIRMED for never
- (uint32_t)blockHeightUntilFreeForAmounts:(NSArray *)amounts withBlockHeights:(NSArray *)heights;

- (uint64_t)amountReceivedFrom:(BTAddress *)addr;;

- (uint64_t)amountSentFrom:(BTAddress *)addr;

- (uint64_t)amountSentTo:(NSString *)addr;

- (int64_t)deltaAmountFrom:(BTAddress *)addr;

- (NSArray *)getOutAddressList;

- (int64_t)deltaAmountFromHDAccount:(BTHDAccount *)account;

- (uint64_t)feeForTransaction;

- (uint32_t)blockHeightUntilFree;


#pragma mark - confirm

- (void)sawByPeer;

- (u_int32_t)getSigHashType;

+ (u_int64_t)getSplitNormalFeeForCoin:(Coin)coin;

+ (uint64_t)getForkBlockHeightForCoin:(Coin)coin;

@end
