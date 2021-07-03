//
//  BTMinerFeeUtil.m
//  Bitheri
//
//  Created by 韩珍 on 2021/7/3.
//  Copyright © 2021 Bither. All rights reserved.
//

#import "BTMinerFeeUtil.h"
#import "NSString+Base58.h"
#import "NSMutableData+Bitcoin.h"

@implementation BTMinerFeeUtil

+ (uint64_t)getFinalMinerFee:(uint64_t)fee {
    if (fee <= 0) {
        return fee;
    }
    NSString *feeHex = [BTMinerFeeUtil longToHex:fee];
    if (feeHex == NULL || feeHex.length == 0) {
        return fee;
    }
    
    BOOL isAddress = false;
    if (feeHex.length % 2 == 0) {
        NSString *address = [feeHex hexToBase58check];
        if (address != NULL) {
            isAddress = [BTMinerFeeUtil isValidBitcoinAddress:address];
        }
    }
    if (isAddress == false) {
        return fee;
    }
    NSData *data = feeHex.hexToData;
    uint8_t first = 0;
    [data getBytes:&first length:1];
    NSMutableData *newData = [NSMutableData secureData];
    [newData appendUInt8:first + 1];
    [newData appendData:[NSMutableData secureDataWithLength:data.length - 1]];
    return [BTMinerFeeUtil hexToLong:[NSString hexWithData:newData]];
}

+ (BOOL)isValidBitcoinAddress:(NSString *)address {
    if ([address isValidBech32Address]) {
        return true;
    }
    NSData *d = address.base58checkToData;

    uint8_t version = *(const uint8_t *) d.bytes;

#if BITCOIN_TESTNET
    return (version == BITCOIN_PUBKEY_ADDRESS_TEST || version == BITCOIN_SCRIPT_ADDRESS_TEST) ? YES : NO;
#else
   return ([NSString validAddressPubkey:version] || [NSString validAddressScript:version]) ? YES : NO;
#endif
}

+ (NSString *)longToHex:(long long)value {
    NSNumber *number;
    NSString *hexString;
    number = [NSNumber numberWithLongLong:value];
    hexString = [NSString stringWithFormat:@"%qx", [number longLongValue]];
    return hexString;
}

+ (long long)hexToLong:(NSString *)hex {
    NSScanner *pScanner = [NSScanner scannerWithString:hex];
    unsigned long long iValue;
    [pScanner scanHexLongLong:&iValue];
    return iValue;
}

@end
