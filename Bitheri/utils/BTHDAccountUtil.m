//
//  BTHDAccountUtil.m
//  Bitheri
//
//  Created by 韩珍 on 2018/9/17.
//  Copyright © 2018年 Bither. All rights reserved.
//

#import "BTHDAccountUtil.h"
#import "NSMutableData+Bitcoin.h"
#import "NSData+Hash.h"
#import "BTSettings.h"

@implementation BTHDAccountUtil

+ (NSData *)getRedeemScript:(NSData *)pubKey {
    NSMutableData *redeem = [NSMutableData secureData];
    NSData *pubKeyHash160 = [pubKey hash160];
    [redeem appendUInt8:pubKeyHash160.length + 2];
    [redeem appendUInt8:0];
    [redeem appendScriptPushData:pubKeyHash160];
    return redeem;
}

+ (NSData *)getSign:(BTKey *)key unsignedHash:(NSData *)unsignedHash {
    NSMutableData *s = [NSMutableData dataWithData:[key sign:unsignedHash]];
    [s appendUInt8:SIG_HASH_ALL];
    return s;
}

+ (NSData *)getWitness:(NSData *)pubKey sign:(NSData *)sign {
    NSMutableData *witness = [NSMutableData secureData];
    [witness appendVarInt:2];
    [witness appendScriptPushData:sign];
    [witness appendScriptPushData:pubKey];
    return witness;
}

@end
