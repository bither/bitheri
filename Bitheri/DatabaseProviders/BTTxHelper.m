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
    if ([rs columnIndexForName:@"tx_hash"] >= 0) {
        inItem.txHash = [[rs stringForColumn:@"tx_hash"] base58ToData];
    }
    if ([rs columnIndexForName:@"in_sn"] >= 0) {
        inItem.inSn = (uint) [rs intForColumn:@"in_sn"];
    }
    if ([rs columnIndexForName:@"prev_tx_hash"] >= 0) {
        inItem.prevTxHash = [[rs stringForColumn:@"prev_tx_hash"] base58ToData];
    }
    if ([rs columnIndexForName:@"prev_out_sn"] >= 0) {
        inItem.prevOutSn = (uint) [rs intForColumn:@"prev_out_sn"];
    }
    if ([rs columnIndexForName:@"in_signature"] >= 0) {
        if ([rs columnIsNull:@"in_signature"]) {
            inItem.inSignature = (id) [NSNull null];
        } else {
            inItem.inSignature = [[rs stringForColumn:@"in_signature"] base58ToData];
        }
    }
    if ([rs columnIndexForName:@"in_sequence"] >= 0) {
        inItem.inSequence = (uint) [rs intForColumn:@"in_sequence"];
    }
    return inItem;
}

+ (BTOut *)formatOut:(FMResultSet *)rs {
    BTOut *outItem = [BTOut new];
    if ([rs columnIndexForName:@"tx_hash"] >= 0) {
        outItem.txHash = [[rs stringForColumn:@"tx_hash"] base58ToData];
    }
    if ([rs columnIndexForName:@"out_sn"] >= 0) {
        outItem.outSn = (uint) [rs intForColumn:@"out_sn"];
    }
    if ([rs columnIndexForName:@"out_script"] >= 0) {
        outItem.outScript = [[rs stringForColumn:@"out_script"] base58ToData];
    }
    if ([rs columnIndexForName:@"out_value"] >= 0) {
        outItem.outValue = [rs unsignedLongLongIntForColumn:@"out_value"];
    }
    if ([rs columnIndexForName:@"out_status"] >= 0) {
        outItem.outStatus = [rs intForColumn:@"out_status"];
    }
    if ([rs columnIndexForName:@"out_address"] >= 0) {
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