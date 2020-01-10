//
//  BTSegwitAddrCoder.h
//  Bitheri
//
//  Created by hanzhenzhen on 2019/12/19.
//  Copyright © 2019 Bither. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BTSegwitAddrData.h"

NS_ASSUME_NONNULL_BEGIN

#define kSegwitAddressHrp @"bc"

@interface BTSegwitAddrCoder : NSObject

- (BTSegwitAddrData *)decode:(NSString *)hrp addr:(NSString *)addr;

- (NSString *)encode:(NSString *)hrp version:(int)version program:(NSData *)program;

+ (int)getWitnessVersion:(NSData *)program;

+ (NSData *)getWitnessProgram:(NSData *)program;

+ (NSData *)convertBits:(NSData *)idata inStart:(int)inStart inLen:(NSUInteger)inLen from:(int)from to:(int)to pad:(BOOL)pad;

@end

NS_ASSUME_NONNULL_END
