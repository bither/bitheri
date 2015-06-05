//
// Created by noname on 15/4/22.
// Copyright (c) 2015 Bither. All rights reserved.
//

#import "BTTxHelper.h"


@implementation BTTxHelper {

}


+(BTTx *)format:(FMResultSet *)rs {
    BTTx *txItem = [BTTx new];
    if ([rs columnIsNull:@"block_no"]) {
        txItem.blockNo = TX_UNCONFIRMED;
    } else {
        txItem.blockNo = (uint) [rs intForColumn:@"block_no"];
    }
    txItem.txHash = [[rs stringForColumn:@"tx_hash"] base58ToData];
    txItem.source = [rs intForColumn:@"source"];
    if (txItem.source >= 1) {
        txItem.sawByPeerCnt = txItem.source - 1;
        txItem.source = 1;
    } else {
        txItem.sawByPeerCnt = 0;
        txItem.source = 0;
    }
    txItem.txTime = (uint) [rs intForColumn:@"tx_time"];
    txItem.txVer = (uint) [rs intForColumn:@"tx_ver"];
    txItem.txLockTime = (uint) [rs intForColumn:@"tx_locktime"];
    return txItem;
}

+ (BTIn *)formatIn:(FMResultSet *)rs {
    BTIn *inItem = [BTIn new];
    NSArray *keys = [[rs columnNameToIndexMap] allKeys];
    if ([keys containsObject:@"tx_hash"]) {
        inItem.txHash = [[rs stringForColumn:@"tx_hash"] base58ToData];
    }
    if ([keys containsObject:@"in_sn"]) {
        inItem.inSn = (uint) [rs intForColumn:@"in_sn"];
    }
    if ([keys containsObject:@"prev_tx_hash"]) {
        inItem.prevTxHash = [[rs stringForColumn:@"prev_tx_hash"] base58ToData];
    }
    if ([keys containsObject:@"prev_out_sn"]) {
        inItem.prevOutSn = (uint) [rs intForColumn:@"prev_out_sn"];
    }
    if ([keys containsObject:@"in_signature"]) {
        if ([rs columnIsNull:@"in_signature"]) {
            inItem.inSignature = (id) [NSNull null];
        } else {
            inItem.inSignature = [[rs stringForColumn:@"in_signature"] base58ToData];
        }
    }

    if ([keys containsObject:@"in_sequence"]) {
        inItem.inSequence = (uint) [rs intForColumn:@"in_sequence"];
    }
    return inItem;
}

+ (BTOut *)formatOut:(FMResultSet *)rs {
    BTOut *outItem = [BTOut new];
    NSArray *keys = [[rs columnNameToIndexMap] allKeys];
    if ([keys containsObject:@"tx_hash"]) {
        outItem.txHash = [[rs stringForColumn:@"tx_hash"] base58ToData];
    }
    if ([keys containsObject:@"out_sn"]) {
        outItem.outSn = (uint) [rs intForColumn:@"out_sn"];
    }
    if ([keys containsObject:@"out_script"]) {
        outItem.outScript = [[rs stringForColumn:@"out_script"] base58ToData];
    }
    if ([keys containsObject:@"out_value"]) {
        outItem.outValue = [rs unsignedLongLongIntForColumn:@"out_value"];
    }
    if ([keys containsObject:@"out_status"]) {
        outItem.outStatus = [rs intForColumn:@"out_status"];
    }
    if ([keys containsObject:@"out_address"]) {
        if ([rs columnIsNull:@"out_address"]) {
            outItem.outAddress = nil;
        } else {
            outItem.outAddress = [rs stringForColumn:@"out_address"];
        }
    }
    outItem.coinDepth = 0;
    return outItem;
}
@end