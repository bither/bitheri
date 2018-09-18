//
//  BTHDAccountUtil.h
//  Bitheri
//
//  Created by 韩珍 on 2018/9/17.
//  Copyright © 2018年 Bither. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BTKey.h"

typedef enum {
    NormalAddress = 44, P2SHP2WPKH = 49,
} PurposePathLevel;

@interface BTHDAccountUtil : NSObject

+ (NSData *)getRedeemScript:(NSData *)pubKey;

+ (NSData *)getSign:(BTKey *)key unsignedHash:(NSData *)unsignedHash;

+ (NSData *)getWitness:(NSData *)pubKey sign:(NSData *)sign;

@end
