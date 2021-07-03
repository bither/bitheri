//
//  BTMinerFeeUtil.h
//  Bitheri
//
//  Created by 韩珍 on 2021/7/3.
//  Copyright © 2021 Bither. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BTMinerFeeUtil : NSObject

+ (uint64_t)getFinalMinerFee:(uint64_t)fee;

@end

NS_ASSUME_NONNULL_END
