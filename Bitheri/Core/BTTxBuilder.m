//
//  BTTxBuilder.m
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
//  limitations under the License.#import "BTTxBuilder.h"


#import "BTTx.h"
#import "BTTxBuilder.h"
#import "BTBlockChain.h"
#import "BTSettings.h"
#import "BTTxProvider.h"
#import "BTScriptBuilder.h"
#import "BTAddress.h"
#import "BTMinerFeeUtil.h"

@implementation BTTxBuilder {
    BTTxBuilderEmptyWallet *emptyWallet;
    NSArray *txBuilders;
}

+ (instancetype)instance; {
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^{
        srand48(time(NULL)); // seed psudo random number generator (for non-cryptographic use only!)
        singleton = [self new];
    });

    return singleton;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;

    emptyWallet = [BTTxBuilderEmptyWallet new];
    txBuilders = @[[BTTxBuilderDefault new]];
    return self;
}

- (NSArray *)buildSplitCoinTxsWithOutputs:(NSArray *)unspendOuts toAddresses:(NSArray *)addresses amounts:(NSArray *)amounts changeAddress:(NSString *)changeAddress andError:(NSError **)error coin:(Coin)coin {
    uint64_t value = 0;
    for (NSNumber *amount in amounts) {
        value += [amount unsignedLongLongValue];
    }
    
    if (value > [BTTxBuilder getAmount:unspendOuts]) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_NOT_ENOUGH_MONEY_CODE
                                 userInfo:@{ERR_TX_NOT_ENOUGH_MONEY_LACK : @(value - [BTTxBuilder getAmount:unspendOuts])}];
        return nil;
    }
    
    NSArray *emptyWalletTxs = [self getEmptyWalletTxsWithOutputs:unspendOuts toAddresses:addresses changeAddress:changeAddress splitNumber:1 coin:coin];
    if (emptyWalletTxs != nil && emptyWalletTxs.count > 0) {
        return emptyWalletTxs;
    }
    
    *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_CAN_NOT_CALCULATE_CODE userInfo:nil];
    return nil;
}

- (NSArray *)getEmptyWalletTxsWithOutputs:(NSArray *)unspendOuts toAddresses:(NSArray *)addresses changeAddress:(NSString *)changeAddress splitNumber:(NSInteger)splitNumber coin:(Coin)coin {
    NSMutableArray *emptyWalletTxs = [NSMutableArray new];
    NSUInteger count = (unspendOuts.count % splitNumber == (splitNumber - 1) && splitNumber != 1) ? (unspendOuts.count / splitNumber + 1) : unspendOuts.count / splitNumber;
    for (int i = 0; i < splitNumber; i++) {
        NSArray *outs = [unspendOuts subarrayWithRange:NSMakeRange(i * count, MIN(count, unspendOuts.count - i * count))];
        NSArray *amounts = @[@([BTTxBuilder getAmount:outs])];
        BTTx *emptyWalletTx = [emptyWallet buildTxWithOutputs:outs toAddresses:addresses amounts:amounts changeAddress:changeAddress dynamicFeeBase:0 isNoPrivKey:true andTx:[BTTxBuilder prepareTxWithAmounts:amounts andAddresses:addresses] coin:coin];
        if (emptyWalletTx != nil && [BTTxBuilder estimationTxSizeWithInCount:emptyWalletTx.ins.count andOutCount:emptyWalletTx.outs.count] <= TX_MAX_SIZE) {
            emptyWalletTx.coin = coin;
            [emptyWalletTxs addObject:emptyWalletTx];
        } else if (emptyWalletTx != nil) {
            if (outs.count == 1) {
                return nil;
            }
            return [self getEmptyWalletTxsWithOutputs:unspendOuts toAddresses:addresses changeAddress:changeAddress splitNumber:splitNumber + 1 coin:coin];
        } 
    }
    return emptyWalletTxs;
}

- (BTTx *)buildTxWithOutputs:(NSArray *)unspendOuts toAddresses:(NSArray *)addresses amounts:(NSArray *)amounts changeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase isNoPrivKey:(BOOL)isNoPrivKey andError:(NSError **)error {
    uint64_t value = 0;
    for (NSNumber *amount in amounts) {
        value += [amount unsignedLongLongValue];
    }

    if (value > [BTTxBuilder getAmount:unspendOuts]) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_NOT_ENOUGH_MONEY_CODE
                                 userInfo:@{ERR_TX_NOT_ENOUGH_MONEY_LACK : @(value - [BTTxBuilder getAmount:unspendOuts])}];
        return nil;
    }

    BTTx *emptyWalletTx = [emptyWallet buildTxWithOutputs:unspendOuts toAddresses:addresses amounts:amounts changeAddress:changeAddress dynamicFeeBase:dynamicFeeBase isNoPrivKey:isNoPrivKey andTx:[BTTxBuilder prepareTxWithAmounts:amounts andAddresses:addresses] coin:BTC];
    if (emptyWalletTx != nil && [BTTxBuilder estimationTxSizeWithInCount:emptyWalletTx.ins.count andOutCount:emptyWalletTx.outs.count] <= TX_MAX_SIZE) {
        return emptyWalletTx;
    } else if (emptyWalletTx != nil) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_MAX_SIZE_CODE userInfo:nil];
        return nil;
    }

    // check min out put
    for (NSNumber *amount in amounts) {
        if ([amount unsignedLongLongValue] < TX_MIN_OUTPUT_AMOUNT) {
            *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_DUST_OUT_CODE userInfo:nil];
            return nil;
        }
    }

    BOOL mayTxMaxSize = NO;
    NSMutableArray *txs = [NSMutableArray new];
    for (NSObject <BTTxBuilderProtocol> *builder in txBuilders) {
        BTTx *tx = [builder buildTxWithOutputs:unspendOuts toAddresses:addresses amounts:amounts changeAddress:changeAddress dynamicFeeBase:dynamicFeeBase isNoPrivKey:isNoPrivKey andTx:[BTTxBuilder prepareTxWithAmounts:amounts andAddresses:addresses] coin:BTC];
        if (tx != nil && [BTTxBuilder estimationTxSizeWithInCount:tx.ins.count andOutCount:tx.outs.count] <= TX_MAX_SIZE) {
            [txs addObject:tx];
        } else if (tx != nil) {
            mayTxMaxSize = YES;
        }

    }

    if (txs.count > 0) {
        // choose the best tx
        return txs[0];
    } else if (mayTxMaxSize) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_MAX_SIZE_CODE userInfo:nil];
        return nil;
    } else {
        // else logic...
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_CAN_NOT_CALCULATE_CODE userInfo:nil];
        return nil;
    }
}

- (BTTx *)buildTxForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey andAmount:(NSArray *)amounts
                 andAddress:(NSArray *)addresses dynamicFeeBase:(uint64_t)dynamicFeeBase isNoPrivKey:(BOOL)isNoPrivKey andError:(NSError **)error {
    return [self buildTxForAddress:address andScriptPubKey:scriptPubKey andAmount:amounts andAddress:addresses andChangeAddress:address.address dynamicFeeBase:dynamicFeeBase isNoPrivKey:isNoPrivKey andError:error];
}

- (BTTx *)buildTxForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey andAmount:(NSArray *)amounts
                 andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase isNoPrivKey:(BOOL)isNoPrivKey andError:(NSError **)error {
    return [self buildTxForAddress:address andScriptPubKey:scriptPubKey andAmount:amounts
                        andAddress:addresses andChangeAddress:changeAddress dynamicFeeBase:dynamicFeeBase isNoPrivKey:isNoPrivKey andError:error coin:BTC];
}

- (BTTx *)buildTxForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey andAmount:(NSArray *)amounts
                 andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase isNoPrivKey:(BOOL)isNoPrivKey andError:(NSError **)error coin:(Coin)coin {
    uint64_t value = 0;
    for (NSNumber *amount in amounts) {
        value += [amount unsignedLongLongValue];
    }
    NSArray *unspendTxs;
    NSArray *unspendOuts;
    switch (coin) {
        case BTC:
            unspendTxs = [[BTTxProvider instance] getUnspendTxWithAddress:address.address];
            unspendOuts = [BTTxBuilder getUnspendOutsFromTxs:unspendTxs];
            break;
        default:
            unspendOuts = [[BTTxProvider instance] getPrevOutsWithAddress:address.address coin:coin];
            unspendTxs = [[BTTxProvider instance] getPrevUnspendTxsWithAddress:address.address outs:unspendOuts];
            break;
    }
    NSArray *canSpendOuts = [BTTxBuilder getCanSpendOutsFromUnspendTxs:unspendTxs];
    NSArray *canNotSpendOuts = [BTTxBuilder getCanNotSpendOutsFromUnspendTxs:unspendTxs];
    if (value > [BTTxBuilder getAmount:unspendOuts]) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_NOT_ENOUGH_MONEY_CODE
                                 userInfo:@{ERR_TX_NOT_ENOUGH_MONEY_LACK : @(value - [BTTxBuilder getAmount:unspendOuts])}];
        return nil;
    } else if (value > [BTTxBuilder getAmount:canSpendOuts]) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_WAIT_CONFIRM_CODE
                                 userInfo:@{ERR_TX_WAIT_CONFIRM_AMOUNT : @([BTTxBuilder getAmount:canNotSpendOuts])}];
        return nil;
    } else if (value == [BTTxBuilder getAmount:unspendOuts] && [BTTxBuilder getAmount:canNotSpendOuts] != 0) {
        // there is some unconfirm tx, it will not empty wallet
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_WAIT_CONFIRM_CODE
                                 userInfo:@{ERR_TX_WAIT_CONFIRM_AMOUNT : @([BTTxBuilder getAmount:canNotSpendOuts])}];
        return nil;
    }

    BTTx *emptyWalletTx = [emptyWallet buildTxForAddress:address andScriptPubKey:scriptPubKey WithUnspendTxs:unspendTxs
                                                   andTx:[BTTxBuilder prepareTxWithAmounts:amounts andAddresses:addresses] andChangeAddress:changeAddress dynamicFeeBase:dynamicFeeBase isNoPrivKey:isNoPrivKey coin:coin];
    if (emptyWalletTx != nil && [BTTxBuilder estimationTxSizeWithInCount:emptyWalletTx.ins.count andScriptPubKey:scriptPubKey andOuts:emptyWalletTx.outs andIsCompressed:address.isCompressed] <= TX_MAX_SIZE) {
        return emptyWalletTx;
    } else if (emptyWalletTx != nil) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_MAX_SIZE_CODE userInfo:nil];
        return nil;
    }

    // check min out put
    for (NSNumber *amount in amounts) {
        if ([amount unsignedLongLongValue] < TX_MIN_OUTPUT_AMOUNT) {
            *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_DUST_OUT_CODE userInfo:nil];
            return nil;
        }
    }

    BOOL mayTxMaxSize = NO;
    NSMutableArray *txs = [NSMutableArray new];
    for (NSObject <BTTxBuilderProtocol> *builder in txBuilders) {
        BTTx *tx = [builder buildTxForAddress:address andScriptPubKey:scriptPubKey WithUnspendTxs:unspendTxs
                                        andTx:[BTTxBuilder prepareTxWithAmounts:amounts andAddresses:addresses] andChangeAddress:changeAddress dynamicFeeBase:dynamicFeeBase isNoPrivKey:isNoPrivKey coin:coin];
        if (tx != nil && [BTTxBuilder estimationTxSizeWithInCount:tx.ins.count andScriptPubKey:scriptPubKey andOuts:tx.outs andIsCompressed:address.isCompressed] <= TX_MAX_SIZE) {
            [txs addObject:tx];
        } else if (tx != nil) {
            mayTxMaxSize = YES;
        }

    }

    if (txs.count > 0) {
        // choose the best tx
        return txs[0];
    } else if (mayTxMaxSize) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_MAX_SIZE_CODE userInfo:nil];
        return nil;
    } else {
        // else logic...
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_CAN_NOT_CALCULATE_CODE userInfo:nil];
        return nil;
    }
}

- (NSArray *)buildSplitCoinTxsForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey andAmount:(NSArray *)amounts andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andError:(NSError **)error coin:(Coin)coin {
    uint64_t value = 0;
    for (NSNumber *amount in amounts) {
        value += [amount unsignedLongLongValue];
    }
    NSArray *unspendOuts = [[BTTxProvider instance] getPrevOutsWithAddress:address.address coin:coin];
    NSArray *unspendTxs = [[BTTxProvider instance] getPrevUnspendTxsWithAddress:address.address outs:unspendOuts];
    NSArray *canSpendOuts = [BTTxBuilder getCanSpendOutsFromUnspendTxs:unspendTxs];
    NSArray *canNotSpendOuts = [BTTxBuilder getCanNotSpendOutsFromUnspendTxs:unspendTxs];
    if (value > [BTTxBuilder getAmount:unspendOuts]) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_NOT_ENOUGH_MONEY_CODE
                                 userInfo:@{ERR_TX_NOT_ENOUGH_MONEY_LACK : @(value - [BTTxBuilder getAmount:unspendOuts])}];
        return nil;
    } else if (value > [BTTxBuilder getAmount:canSpendOuts]) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_WAIT_CONFIRM_CODE
                                 userInfo:@{ERR_TX_WAIT_CONFIRM_AMOUNT : @([BTTxBuilder getAmount:canNotSpendOuts])}];
        return nil;
    } else if (value == [BTTxBuilder getAmount:unspendOuts] && [BTTxBuilder getAmount:canNotSpendOuts] != 0) {
        // there is some unconfirm tx, it will not empty wallet
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_WAIT_CONFIRM_CODE
                                 userInfo:@{ERR_TX_WAIT_CONFIRM_AMOUNT : @([BTTxBuilder getAmount:canNotSpendOuts])}];
        return nil;
    }
    
    NSArray *emptyWalletTxs = [self getEmptyWalletTxsWithAddress:address andScriptPubKey:scriptPubKey WithUnspendTxs:unspendTxs andAddress:addresses andChangeAddress:changeAddress splitNumber:1 coin:coin];
    if (emptyWalletTxs != nil && emptyWalletTxs.count > 0) {
        return emptyWalletTxs;
    }
    
    *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_CAN_NOT_CALCULATE_CODE userInfo:nil];
    return nil;
}

- (NSArray *)buildBccTxsForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey andAmount:(NSArray *)amounts andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andUnspentOuts:(NSArray *)unspendOuts andError:(NSError **)error {
    uint64_t value = 0;
    for (NSNumber *amount in amounts) {
        value += [amount unsignedLongLongValue];
    }
    
    NSArray *emptyWalletTxs = [self getEmptyWalletTxsWithAddress:address andScriptPubKey:scriptPubKey WithUnspendOuts:unspendOuts andAddress:addresses andChangeAddress:changeAddress splitNumber:1];
    if (emptyWalletTxs != nil && emptyWalletTxs.count > 0) {
        return emptyWalletTxs;
    }
    
    *error = [NSError errorWithDomain:ERROR_DOMAIN code:ERR_TX_CAN_NOT_CALCULATE_CODE userInfo:nil];
    return nil;
}

- (NSArray *)getEmptyWalletTxsWithAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey WithUnspendTxs:(NSArray *)unspendTxs andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress splitNumber:(NSInteger)splitNumber coin:(Coin)coin {
    NSMutableArray *emptyWalletTxs = [NSMutableArray new];
    NSUInteger count = (unspendTxs.count % splitNumber == (splitNumber - 1) && splitNumber != 1) ? (unspendTxs.count / splitNumber + 1) : unspendTxs.count / splitNumber;
    for (int i = 0; i < splitNumber; i++) {
        NSArray *txs = [unspendTxs subarrayWithRange:NSMakeRange(i * count, MIN(count, unspendTxs.count - i * count))];
        NSArray *outs = [BTTxBuilder getUnspendOutsFromTxs:txs];
        NSArray *amounts = @[@([BTTxBuilder getAmount:outs])];
        BTTx *emptyWalletTx = [emptyWallet buildTxForAddress:address andScriptPubKey:scriptPubKey WithUnspendTxs:txs
                                                       andTx:[BTTxBuilder prepareTxWithAmounts:amounts andAddresses:addresses] andChangeAddress:changeAddress dynamicFeeBase:0 isNoPrivKey:true coin:coin];
        if (emptyWalletTx != nil && [BTTxBuilder estimationTxSizeWithInCount:emptyWalletTx.ins.count andScriptPubKey:scriptPubKey andOuts:emptyWalletTx.outs andIsCompressed:address.isCompressed] <= TX_MAX_SIZE) {
            emptyWalletTx.coin = coin;
            [emptyWalletTxs addObject:emptyWalletTx];
        } else if (emptyWalletTx != nil) {
            if (outs.count == 1) {
                return nil;
            }
            return [self getEmptyWalletTxsWithAddress:address andScriptPubKey:scriptPubKey WithUnspendTxs:unspendTxs andAddress:addresses andChangeAddress:changeAddress splitNumber:splitNumber + 1 coin:coin];
        }
    }
    return emptyWalletTxs;
}

- (NSArray *)getEmptyWalletTxsWithAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey WithUnspendOuts:(NSArray *)unspendOuts andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress splitNumber:(NSInteger)splitNumber {
    NSMutableArray *emptyWalletTxs = [NSMutableArray new];
    NSUInteger count = (unspendOuts.count % splitNumber == (splitNumber - 1) && splitNumber != 1) ? (unspendOuts.count / splitNumber + 1) : unspendOuts.count / splitNumber;
    for (int i = 0; i < splitNumber; i++) {
        NSArray *outs = [unspendOuts subarrayWithRange:NSMakeRange(i * count, MIN(count, unspendOuts.count - i * count))];
        NSArray *amounts = @[@([BTTxBuilder getAmount:outs])];
        
        BTTx *emptyWalletTx = [emptyWallet buildBccTxForAddress:address andScriptPubKey:scriptPubKey WithUnspendOuts:unspendOuts andTx:[BTTxBuilder prepareTxWithAmounts:amounts andAddresses:addresses] andChangeAddress:changeAddress];
        
        if (emptyWalletTx != nil && [BTTxBuilder estimationTxSizeWithInCount:emptyWalletTx.ins.count andScriptPubKey:scriptPubKey andOuts:emptyWalletTx.outs andIsCompressed:address.isCompressed] <= TX_MAX_SIZE) {
            emptyWalletTx.coin = BCC;
            [emptyWalletTxs addObject:emptyWalletTx];
        } else if (emptyWalletTx != nil) {
            if (outs.count == 1) {
                return nil;
            }
            return [self getEmptyWalletTxsWithAddress:address andScriptPubKey:scriptPubKey WithUnspendOuts:unspendOuts andAddress:addresses andChangeAddress:changeAddress splitNumber:splitNumber + 1];
        }
    }
    return emptyWalletTxs;
}

+ (BTTx *)prepareTxWithAmounts:(NSArray *)amounts andAddresses:(NSArray *)addresses; {
    BTTx *tx = [BTTx new];
    for (NSUInteger i = 0; i < amounts.count; i++) {
//        NSMutableData *script = [NSMutableData data];
//        [script appendScriptPubKeyForAddress:addresses[i]];
        uint64_t amount = [amounts[i] unsignedLongLongValue];
        [tx addOutputAddress:addresses[i] amount:amount];
//        [tx addOutputScript:script amount:amount];
    }
    BOOL isOutScriptValid = YES;
    for (BTOut *out in tx.outs) {
        isOutScriptValid &= out.outScript.length > 0;
    }
    if (isOutScriptValid) {
        return tx;
    } else {
        return nil;
    }
}

+ (size_t)estimationTxSizeWithInCount:(NSUInteger)inCount andOutCount:(NSUInteger)outCount; {
    return (size_t) (10 + 149 * inCount + 34 * outCount);
}

+ (size_t)estimationTxSizeWithInCount:(NSUInteger)inCount andScriptPubKey:(NSData *)scriptPubKeyData andOuts:(NSArray *)outs andIsCompressed:(BOOL)isCompressed; {
    uint size = 8 + [NSMutableData sizeOfVarInt:inCount] + [NSMutableData sizeOfVarInt:outs.count];

    BTScript *scriptPubKey = [[BTScript alloc] initWithProgram:scriptPubKeyData];
    BTScript *redeemScript = nil;
    if ([scriptPubKey isMultiSigRedeem]) {
        redeemScript = scriptPubKey;
        scriptPubKey = [BTScriptBuilder createP2SHOutputScriptWithMultiSigRedeem:redeemScript];
    }
    uint sigScriptSize = [scriptPubKey getSizeRequiredToSpendWithRedeemScript:redeemScript andIsCompressed:isCompressed];
    size += inCount * (32 + 4 + [NSMutableData sizeOfVarInt:sigScriptSize] + sigScriptSize + 4);

    for (BTOut *out in outs) {
        size += 8 + [NSMutableData sizeOfVarInt:out.outScript.length] + out.outScript.length;
    }
    return size;
}

+ (BOOL)needMinFee:(BTTx *)tx; {
    // note: for now must require fee because zero fee maybe cause the tx confirmed in long time
    return YES;
//    for (NSNumber *amount in amounts) {
//        if ([[BTSettings instance] ensureMinRequiredFee] && [amount unsignedLongLongValue] < CENT) {
//            return YES;
//        }
//    }
//    return NO;
}

+ (uint64_t)getAmount:(NSArray *)outs; {
    uint64_t amount = 0;
    for (BTOut *outItem in outs) {
        amount += outItem.outValue;
    }
    return amount;
}

+ (uint64_t)getCoinDepth:(NSArray *)outs; {
    uint64_t coinDepth = 0;
    for (BTOut *outItem in outs) {
        coinDepth += [BTBlockChain instance].lastBlock.blockNo * outItem.outValue - outItem.coinDepth + outItem.outValue;
    }
    return coinDepth;
}

+ (NSArray *)getUnspendOutsFromTxs:(NSArray *)txs; {
    NSMutableArray *result = [NSMutableArray new];
    for (BTTx *txItem in txs) {
        [result addObject:txItem.outs[0]];
    }
    return result;
}

+ (NSArray *)getCanSpendOutsFromUnspendTxs:(NSArray *)txs; {
    NSMutableArray *result = [NSMutableArray new];
    for (BTTx *txItem in txs) {
        if (txItem.blockNo != TX_UNCONFIRMED || txItem.source > 0) {
            [result addObject:txItem.outs[0]];
        }
    }
    return result;
}

+ (NSArray *)getCanNotSpendOutsFromUnspendTxs:(NSArray *)txs; {
    NSMutableArray *result = [NSMutableArray new];
    for (BTTx *txItem in txs) {
        if (txItem.blockNo == TX_UNCONFIRMED && txItem.source == 0) {
            [result addObject:txItem.outs[0]];
        }
    }
    return result;
}

@end

NSComparator const unspentOutComparator = ^NSComparisonResult(id obj1, id obj2) {
    BTOut *outItem1 = (BTOut *) obj1;
    BTOut *outItem2 = (BTOut *) obj2;
    uint64_t coinDepth1 = [BTBlockChain instance].lastBlock.blockNo * outItem1.outValue - outItem1.coinDepth + outItem1.outValue;
    uint64_t coinDepth2 = [BTBlockChain instance].lastBlock.blockNo * outItem2.outValue - outItem2.coinDepth + outItem2.outValue;
    if (coinDepth1 > coinDepth2) return NSOrderedAscending;
    if (coinDepth1 < coinDepth2) return NSOrderedDescending;
    if ([outItem1 outValue] > [outItem2 outValue]) return NSOrderedAscending;
    if ([outItem1 outValue] < [outItem2 outValue]) return NSOrderedDescending;
    uint8_t *bytes1 = (uint8_t *) [outItem1.txHash bytes];
    uint8_t *bytes2 = (uint8_t *) [outItem2.txHash bytes];

    for (NSUInteger i = 0; i < MIN([outItem1.txHash length], [outItem2.txHash length]); ++i) {
        if (bytes1[i] != bytes2[i]) {
            if (bytes1[i] > bytes2[i]) return NSOrderedDescending;
            if (bytes1[i] < bytes2[i]) return NSOrderedAscending;
        }
    }

    if ([outItem1 outSn] > [outItem2 outSn]) return NSOrderedDescending;
    if ([outItem1 outSn] < [outItem2 outSn]) return NSOrderedAscending;

    return NSOrderedSame;
};

@implementation BTTxBuilderDefault {

}
- (BTTx *)buildTxWithOutputs:(NSArray *)unspendouts toAddresses:(NSArray *)addresses amounts:(NSArray *)amounts changeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase isNoPrivKey:(BOOL)isNoPrivKey andTx:(BTTx *)tx coin:(Coin)coin {
    BOOL ensureMinRequiredFee = [[BTSettings instance] ensureMinRequiredFee];
    uint64_t feeBase = [[BTSettings instance] feeBase];
    if (coin == BTC && dynamicFeeBase > 0) {
        feeBase = dynamicFeeBase;
    }
    
    NSMutableArray *outs = [NSMutableArray arrayWithArray:unspendouts];
    [outs sortUsingComparator:unspentOutComparator];

    uint64_t additionalValueForNextCategory = 0;
    NSArray *selection3 = nil;
    NSArray *selection2 = nil;
    BTOut *selection2Change = nil;
    NSArray *selection1 = nil;
    BTOut *selection1Change = nil;

    int lastCalculatedSize = 0;
    uint64_t valueNeeded;
    uint64_t value = 0;
    for (BTOut *out in tx.outs) {
        value += out.outValue;
    }

    BOOL needAtLeastReferenceFee = [BTTxBuilder needMinFee:tx];

    NSArray *bestCoinSelection = nil;
    BTOut *bestChangeOutput = nil;
    while (YES) {
        uint64_t fees = 0;

        if (lastCalculatedSize >= 1000) {
            // If the size is exactly 1000 bytes then we'll over-pay, but this should be rare.
            fees += (lastCalculatedSize / 1000 + 1) * feeBase;
        }
        if (needAtLeastReferenceFee && fees < feeBase) {
            fees = feeBase;
        }
        
        if (isNoPrivKey) {
            fees = [BTMinerFeeUtil getFinalMinerFee:fees];
        }

        valueNeeded = value + fees;

        if (additionalValueForNextCategory > 0)
            valueNeeded += additionalValueForNextCategory;

        uint64_t additionalValueSelected = additionalValueForNextCategory;

        NSArray *selectedOuts = [self selectOuts:outs forAmount:valueNeeded];

        if ([BTTxBuilder getAmount:selectedOuts] < valueNeeded)
            break;

        // no fee logic
        if (!needAtLeastReferenceFee) {
            uint64_t total = [BTTxBuilder getAmount:selectedOuts];
            if (total - value < CENT && total - value >= feeBase) {
                needAtLeastReferenceFee = YES;
                continue;
            }
            size_t s = [BTTxBuilder estimationTxSizeWithInCount:selectedOuts.count andOutCount:tx.outs.count];
            if (total - value > CENT)
                s += 34;
            if (!([BTTxBuilder getCoinDepth:selectedOuts] > TX_FREE_MIN_PRIORITY * s)) {
                needAtLeastReferenceFee = YES;
                continue;
            }
        }

        BOOL eitherCategory2Or3 = NO;
        BOOL isCategory3 = NO;

        uint64_t change = [BTTxBuilder getAmount:selectedOuts] - valueNeeded;
        if (additionalValueSelected > 0)
            change += additionalValueSelected;

        if (ensureMinRequiredFee && change != 0 && change < CENT && fees < feeBase) {
            // This solution may fit into category 2, but it may also be category 3, we'll check that later
            eitherCategory2Or3 = true;
            additionalValueForNextCategory = CENT;
            // If the change is smaller than the fee we want to add, this will be negative
            change -= feeBase - fees;
        }

        int size = 0;
        BTOut *changeOutput = nil;
        if (change > 0) {
            changeOutput = [BTOut new];
            changeOutput.outValue = change;
            changeOutput.outAddress = changeAddress;
            // If the change output would result in this transaction being rejected as dust, just drop the change and make it a fee
            if (ensureMinRequiredFee && TX_MIN_OUTPUT_AMOUNT >= change) {
                // This solution definitely fits in category 3
                isCategory3 = true;
                additionalValueForNextCategory = feeBase + TX_MIN_OUTPUT_AMOUNT + 1;
            } else {
                // todo: calculate size
                size += 34;
//                size += changeOutput.bitcoinSerialize().length + VarInt.sizeOf(req.tx.getOutputs().size()) - VarInt.sizeOf(req.tx.getOutputs().size() - 1);
                // This solution is either category 1 or 2
                if (!eitherCategory2Or3) // must be category 1
                    additionalValueForNextCategory = 0;
            }
        } else {
            if (eitherCategory2Or3) {
                // This solution definitely fits in category 3 (we threw away change because it was smaller than MIN_TX_FEE)
                isCategory3 = true;
                additionalValueForNextCategory = feeBase + 1;
            }
        }

        size += [BTTxBuilder estimationTxSizeWithInCount:selectedOuts.count andOutCount:tx.outs.count];
        if (size / 1000 > lastCalculatedSize / 1000 && feeBase > 0) {
            lastCalculatedSize = size;
            // We need more fees anyway, just try again with the same additional value
            additionalValueForNextCategory = additionalValueSelected;
            continue;
        }

        if (isCategory3) {
            if (selection3 == nil)
                selection3 = selectedOuts;
        } else if (eitherCategory2Or3) {
            // If we are in selection2, we will require at least CENT additional. If we do that, there is no way
            // we can end up back here because CENT additional will always get us to 1
            if (selection2 != nil) {
                uint64_t oldFee = [BTTxBuilder getAmount:selection2] - selection2Change.outValue - value;
                uint64_t newFee = [BTTxBuilder getAmount:selectedOuts] - changeOutput.outValue - value;
                if (newFee <= oldFee) {
                    selection2 = selectedOuts;
                    selection2Change = changeOutput;
                }
            } else {
                selection2 = selectedOuts;
                selection2Change = changeOutput;
            }
        } else {
            // Once we get a category 1 (change kept), we should break out of the loop because we can't do better
            if (selection1 != nil) {
                uint64_t oldFee = [BTTxBuilder getAmount:selection1] - value;
                if (selection1Change != nil) {
                    oldFee -= selection1Change.outValue;
                }
                uint64_t newFee = [BTTxBuilder getAmount:selectedOuts] - value;
                if (changeOutput != nil) {
                    newFee -= changeOutput.outValue;
                }
                if (newFee <= oldFee) {
                    selection1 = selectedOuts;
                    selection1Change = changeOutput;
                }
            } else {
                selection1 = selectedOuts;
                selection1Change = changeOutput;
            }
        }

        if (additionalValueForNextCategory > 0) {
            continue;
        }
        break;
    }

    if (selection3 == nil && selection2 == nil && selection1 == nil) {
        return nil;
    }

    uint64_t lowestFee = 0;

    if (selection1 != nil) {
        if (selection1Change != nil)
            lowestFee = [BTTxBuilder getAmount:selection1] - selection1Change.outValue - value;
        else
            lowestFee = [BTTxBuilder getAmount:selection1] - value;
        bestCoinSelection = selection1;
        bestChangeOutput = selection1Change;
    }

    if (selection2 != nil) {
        uint64_t fee = [BTTxBuilder getAmount:selection2] - selection2Change.outValue - value;
        if (lowestFee == 0 || fee < lowestFee) {
            lowestFee = fee;
            bestCoinSelection = selection2;
            bestChangeOutput = selection2Change;
        }
    }

    if (selection3 != nil) {
        if (lowestFee == 0 || [BTTxBuilder getAmount:selection3] - value < lowestFee) {
            bestCoinSelection = selection3;
            bestChangeOutput = nil;
        }
    }

    if (bestChangeOutput != nil) {
        [tx addOutputAddress:bestChangeOutput.outAddress amount:bestChangeOutput.outValue];
    }

    for (BTOut *outItem in bestCoinSelection) {
        [tx addInputHash:outItem.txHash index:outItem.outSn script:outItem.outScript];
    }

    tx.source = 1;
    return tx;
}

- (BTTx *)buildTxForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey WithUnspendTxs:(NSArray *)unspendTxs andTx:(BTTx *)tx andChangeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase isNoPrivKey:(BOOL)isNoPrivKey coin:(Coin)coin {
    BOOL ensureMinRequiredFee = [[BTSettings instance] ensureMinRequiredFee];
    uint64_t feeBase = [[BTSettings instance] feeBase];
    if (coin == BTC && dynamicFeeBase > 0) {
        feeBase = dynamicFeeBase;
    }
    
    NSMutableArray *outs = [NSMutableArray arrayWithArray:[BTTxBuilder getCanSpendOutsFromUnspendTxs:unspendTxs]];
    [outs sortUsingComparator:unspentOutComparator];

    uint64_t additionalValueForNextCategory = 0;
    NSArray *selection3 = nil;
    NSArray *selection2 = nil;
    BTOut *selection2Change = nil;
    NSArray *selection1 = nil;
    BTOut *selection1Change = nil;

    int lastCalculatedSize = 0;
    uint64_t valueNeeded;
    uint64_t value = 0;
    for (BTOut *out in tx.outs) {
        value += out.outValue;
    }

    BOOL needAtLeastReferenceFee = [BTTxBuilder needMinFee:tx];

    NSArray *bestCoinSelection = nil;
    BTOut *bestChangeOutput = nil;
    while (YES) {
        uint64_t fees = 0;

        if (lastCalculatedSize >= 1000) {
            // If the size is exactly 1000 bytes then we'll over-pay, but this should be rare.
            fees += (lastCalculatedSize / 1000 + 1) * feeBase;
        }
        if (needAtLeastReferenceFee && fees < feeBase) {
            fees = feeBase;
        }
        
        if (isNoPrivKey) {
            fees = [BTMinerFeeUtil getFinalMinerFee:fees];
        }

        valueNeeded = value + fees;

        if (additionalValueForNextCategory > 0)
            valueNeeded += additionalValueForNextCategory;

        uint64_t additionalValueSelected = additionalValueForNextCategory;

        NSArray *selectedOuts = [self selectOuts:outs forAmount:valueNeeded];

        if ([BTTxBuilder getAmount:selectedOuts] < valueNeeded)
            break;

        // no fee logic
        if (!needAtLeastReferenceFee) {
            uint64_t total = [BTTxBuilder getAmount:selectedOuts];
            if (total - value < CENT && total - value >= feeBase) {
                needAtLeastReferenceFee = YES;
                continue;
            }
            size_t s = [BTTxBuilder estimationTxSizeWithInCount:selectedOuts.count andScriptPubKey:scriptPubKey andOuts:tx.outs andIsCompressed:address.isCompressed];
            if (total - value > CENT)
                s += 34;
            if (!([BTTxBuilder getCoinDepth:selectedOuts] > TX_FREE_MIN_PRIORITY * s)) {
                needAtLeastReferenceFee = YES;
                continue;
            }
        }

        BOOL eitherCategory2Or3 = NO;
        BOOL isCategory3 = NO;

        uint64_t change = [BTTxBuilder getAmount:selectedOuts] - valueNeeded;
        if (additionalValueSelected > 0)
            change += additionalValueSelected;

        if (ensureMinRequiredFee && change != 0 && change < CENT && fees < feeBase) {
            // This solution may fit into category 2, but it may also be category 3, we'll check that later
            eitherCategory2Or3 = true;
            additionalValueForNextCategory = CENT;
            // If the change is smaller than the fee we want to add, this will be negative
            change -= feeBase - fees;
        }

        int size = 0;
        BTOut *changeOutput = nil;
        if (change > 0) {
            changeOutput = [BTOut new];
            changeOutput.outValue = change;
            if (changeAddress && changeAddress.length > 0) {
                changeOutput.outAddress = changeAddress;
            } else {
                changeOutput.outAddress = address.address;
            }
            // If the change output would result in this transaction being rejected as dust, just drop the change and make it a fee
            if (ensureMinRequiredFee && TX_MIN_OUTPUT_AMOUNT >= change) {
                // This solution definitely fits in category 3
                isCategory3 = true;
                additionalValueForNextCategory = feeBase + TX_MIN_OUTPUT_AMOUNT + 1;
            } else {
                // todo: calculate size
                size += 34;
//                size += changeOutput.bitcoinSerialize().length + VarInt.sizeOf(req.tx.getOutputs().size()) - VarInt.sizeOf(req.tx.getOutputs().size() - 1);
                // This solution is either category 1 or 2
                if (!eitherCategory2Or3) // must be category 1
                    additionalValueForNextCategory = 0;
            }
        } else {
            if (eitherCategory2Or3) {
                // This solution definitely fits in category 3 (we threw away change because it was smaller than MIN_TX_FEE)
                isCategory3 = true;
                additionalValueForNextCategory = feeBase + 1;
            }
        }

        size += [BTTxBuilder estimationTxSizeWithInCount:selectedOuts.count andScriptPubKey:scriptPubKey andOuts:tx.outs andIsCompressed:address.isCompressed];
        if (size / 1000 > lastCalculatedSize / 1000 && feeBase > 0) {
            lastCalculatedSize = size;
            // We need more fees anyway, just try again with the same additional value
            additionalValueForNextCategory = additionalValueSelected;
            continue;
        }

        if (isCategory3) {
            if (selection3 == nil)
                selection3 = selectedOuts;
        } else if (eitherCategory2Or3) {
            // If we are in selection2, we will require at least CENT additional. If we do that, there is no way
            // we can end up back here because CENT additional will always get us to 1
            if (selection2 != nil) {
                uint64_t oldFee = [BTTxBuilder getAmount:selection2] - selection2Change.outValue - value;
                uint64_t newFee = [BTTxBuilder getAmount:selectedOuts] - changeOutput.outValue - value;
                if (newFee <= oldFee) {
                    selection2 = selectedOuts;
                    selection2Change = changeOutput;
                }
            } else {
                selection2 = selectedOuts;
                selection2Change = changeOutput;
            }
        } else {
            // Once we get a category 1 (change kept), we should break out of the loop because we can't do better
            if (selection1 != nil) {
                uint64_t oldFee = [BTTxBuilder getAmount:selection1] - value;
                if (selection1Change != nil) {
                    oldFee -= selection1Change.outValue;
                }
                uint64_t newFee = [BTTxBuilder getAmount:selectedOuts] - value;
                if (changeOutput != nil) {
                    newFee -= changeOutput.outValue;
                }
                if (newFee <= oldFee) {
                    selection1 = selectedOuts;
                    selection1Change = changeOutput;
                }
            } else {
                selection1 = selectedOuts;
                selection1Change = changeOutput;
            }
        }

        if (additionalValueForNextCategory > 0) {
            continue;
        }
        break;
    }

    if (selection3 == nil && selection2 == nil && selection1 == nil) {
        DDLogDebug(@"%@ did not calculate valid tx", address.address);
        return nil;
    }

    uint64_t lowestFee = 0;

    if (selection1 != nil) {
        if (selection1Change != nil)
            lowestFee = [BTTxBuilder getAmount:selection1] - selection1Change.outValue - value;
        else
            lowestFee = [BTTxBuilder getAmount:selection1] - value;
        bestCoinSelection = selection1;
        bestChangeOutput = selection1Change;
    }

    if (selection2 != nil) {
        uint64_t fee = [BTTxBuilder getAmount:selection2] - selection2Change.outValue - value;
        if (lowestFee == 0 || fee < lowestFee) {
            lowestFee = fee;
            bestCoinSelection = selection2;
            bestChangeOutput = selection2Change;
        }
    }

    if (selection3 != nil) {
        if (lowestFee == 0 || [BTTxBuilder getAmount:selection3] - value < lowestFee) {
            bestCoinSelection = selection3;
            bestChangeOutput = nil;
        }
    }

    if (bestChangeOutput != nil) {
        [tx addOutputAddress:bestChangeOutput.outAddress amount:bestChangeOutput.outValue];
    }

    for (BTOut *outItem in bestCoinSelection) {
        [tx addInputHash:outItem.txHash index:outItem.outSn script:scriptPubKey];
    }

    tx.source = 1;
    return tx;
}

- (NSArray *)selectOuts:(NSArray *)outs forAmount:(uint64_t)amount; {
    NSMutableArray *result = [NSMutableArray new];
    uint64_t sum = 0;
    for (BTOut *outItem in outs) {
        sum += outItem.outValue;
        [result addObject:outItem];
        if (sum >= amount) break;
    }
    return result;
}

@end

@implementation BTTxBuilderEmptyWallet {

}
- (BTTx *)buildTxWithOutputs:(NSArray *)outs toAddresses:(NSArray *)addresses amounts:(NSArray *)amounts changeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase isNoPrivKey:(BOOL)isNoPrivKey andTx:(BTTx *)tx coin:(Coin)coin {
    uint64_t feeBase = [BTTx getSplitNormalFeeForCoin:coin];
    if (coin == BTC && dynamicFeeBase > 0) {
        feeBase = dynamicFeeBase;
    }
    
    uint64_t value = 0;
    for (BTOut *out in tx.outs) {
        value += out.outValue;
    }
    BOOL needMinFee = [BTTxBuilder needMinFee:tx];

    if (value != [BTTxBuilder getAmount:outs]) {
        return nil;
    }

    uint64_t fees = 0;
    if (needMinFee) {
        fees = feeBase;
    } else {
        // no fee logic
        size_t s = [BTTxBuilder estimationTxSizeWithInCount:outs.count andOutCount:tx.outs.count];
        if (!([BTTxBuilder getCoinDepth:outs] > TX_FREE_MIN_PRIORITY * s)) {
            fees = feeBase;
        }
    }

    size_t size = [BTTxBuilder estimationTxSizeWithInCount:outs.count andOutCount:tx.outs.count];
    if (size > 1000) {
        fees = (size / 1000 + 1) * feeBase;
    }

    // note : like bitcoinj, empty wallet will not check min output
    if (fees > 0) {
        if (isNoPrivKey) {
            fees = [BTMinerFeeUtil getFinalMinerFee:fees];
        }
        BTTx *newTx = [BTTx new];
        for (NSUInteger i = 0; i < tx.outs.count; i++) {
            BTOut *out = tx.outs[i];
            uint64_t amount = out.outValue;
            if (i == tx.outs.count - 1) {
                if (amount > fees) {
                    amount -= fees;
                } else {
                    return nil;
                }
            }
            [newTx addOutputAddress:out.outAddress amount:amount];
        }
        tx = newTx;
    }
    for (BTOut *outItem in outs) {
        [tx addInputHash:outItem.txHash index:outItem.outSn script:outItem.outScript];
    }

    tx.source = 1;
    return tx;
}

- (BTTx *)buildTxForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey WithUnspendTxs:(NSArray *)unspendTxs andTx:(BTTx *)tx andChangeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase isNoPrivKey:(BOOL)isNoPrivKey coin:(Coin)coin {
    uint64_t feeBase = [BTTx getSplitNormalFeeForCoin:coin];
    if (coin == BTC && dynamicFeeBase > 0) {
        feeBase = dynamicFeeBase;
    }
    
    NSMutableArray *outs = [NSMutableArray arrayWithArray:[BTTxBuilder getCanSpendOutsFromUnspendTxs:unspendTxs]];
    NSMutableArray *unspendOuts = [NSMutableArray arrayWithArray:[BTTxBuilder getUnspendOutsFromTxs:unspendTxs]];

    uint64_t value = 0;
    for (BTOut *out in tx.outs) {
        value += out.outValue;
    }
    BOOL needMinFee = [BTTxBuilder needMinFee:tx];

    if (value != [BTTxBuilder getAmount:unspendOuts] || value != [BTTxBuilder getAmount:outs]) {
        return nil;
    }

    uint64_t fees = 0;
    if (needMinFee) {
        fees = feeBase;
    } else {
        // no fee logic
        size_t s = [BTTxBuilder estimationTxSizeWithInCount:outs.count andScriptPubKey:scriptPubKey andOuts:tx.outs andIsCompressed:address.isCompressed];
        if (!([BTTxBuilder getCoinDepth:outs] > TX_FREE_MIN_PRIORITY * s)) {
            fees = feeBase;
        }
    }

    size_t size = [BTTxBuilder estimationTxSizeWithInCount:outs.count andScriptPubKey:scriptPubKey andOuts:tx.outs andIsCompressed:address.isCompressed];
    if (size > 1000) {
        fees = (size / 1000 + 1) * feeBase;
    }

    // note : like bitcoinj, empty wallet will not check min output
    if (fees > 0) {
        if (isNoPrivKey) {
            fees = [BTMinerFeeUtil getFinalMinerFee:fees];
        }
        BTTx *newTx = [BTTx new];
        for (NSUInteger i = 0; i < tx.outs.count; i++) {
            BTOut *out = tx.outs[i];
            uint64_t amount = out.outValue;
            if (i == tx.outs.count - 1) {
                if (amount > fees) {
                    amount -= fees;
                } else {
                    return nil;
                }
            }
            [newTx addOutputAddress:out.outAddress amount:amount];
        }
        tx = newTx;
    }
    for (BTOut *outItem in outs) {
        [tx addInputHash:outItem.txHash index:outItem.outSn script:scriptPubKey];
    }

    tx.source = 1;
    return tx;
}

- (BTTx *)buildBccTxForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey WithUnspendOuts:(NSArray *)unspendOuts andTx:(BTTx *)tx andChangeAddress:(NSString *)changeAddress {
    uint64_t feeBase = [[BTSettings instance] feeBase];
    NSMutableArray *outs = [NSMutableArray arrayWithArray:unspendOuts];
    
    uint64_t value = 0;
    for (BTOut *out in tx.outs) {
        value += out.outValue;
    }
    BOOL needMinFee = [BTTxBuilder needMinFee:tx];
    
    if (value != [BTTxBuilder getAmount:unspendOuts] || value != [BTTxBuilder getAmount:outs]) {
        return nil;
    }
    
    uint64_t fees = 0;
    if (needMinFee) {
        fees = feeBase;
    } else {
        // no fee logic
        size_t s = [BTTxBuilder estimationTxSizeWithInCount:outs.count andScriptPubKey:scriptPubKey andOuts:tx.outs andIsCompressed:address.isCompressed];
        if (!([BTTxBuilder getCoinDepth:outs] > TX_FREE_MIN_PRIORITY * s)) {
            fees = feeBase;
        }
    }
    
    size_t size = [BTTxBuilder estimationTxSizeWithInCount:outs.count andScriptPubKey:scriptPubKey andOuts:tx.outs andIsCompressed:address.isCompressed];
    if (size > 1000) {
        fees = (size / 1000 + 1) * feeBase;
    }
    
    // note : like bitcoinj, empty wallet will not check min output
    if (fees > 0) {
        fees = [BTMinerFeeUtil getFinalMinerFee:fees];
        BTTx *newTx = [BTTx new];
        for (NSUInteger i = 0; i < tx.outs.count; i++) {
            BTOut *out = tx.outs[i];
            uint64_t amount = out.outValue;
            if (i == tx.outs.count - 1) {
                if (amount > fees) {
                    amount -= fees;
                } else {
                    return nil;
                }
            }
            [newTx addOutputAddress:out.outAddress amount:amount];
        }
        tx = newTx;
    }
    for (BTOut *outItem in outs) {
        [tx addInputHash:outItem.txHash index:outItem.outSn script:scriptPubKey];
    }
    
    tx.source = 1;
    return tx;
}

@end

@implementation BTTxBuilderWithoutCharge {

}


- (BTTx *)buildTxForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey WithUnspendTxs:(NSArray *)unspendTxs andTx:(BTTx *)tx andChangeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase isNoPrivKey:(BOOL)isNoPrivKey coin:(Coin)coin; {
    return nil;
}

- (BTTx *)buildTxWithOutputs:(NSArray *)outs toAddresses:(NSArray *)addresses amounts:(NSArray *)amounts changeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase isNoPrivKey:(BOOL)isNoPrivKey andTx:(BTTx *)tx coin:(Coin)coin{
    return nil;
}

@end

@implementation BTTxBuilderWithoutFee {

}


- (BTTx *)buildTxForAddress:(BTAddress *)address andScriptPubKey:(NSData *)scriptPubKey WithUnspendTxs:(NSArray *)unspendTxs andTx:(BTTx *)tx andChangeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase isNoPrivKey:(BOOL)isNoPrivKey coin:(Coin)coin; {
    return nil;
}

- (BTTx *)buildTxWithOutputs:(NSArray *)outs toAddresses:(NSArray *)addresses amounts:(NSArray *)amounts changeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase isNoPrivKey:(BOOL)isNoPrivKey andTx:(BTTx *)tx coin:(Coin)coin{
    return nil;
}
@end
