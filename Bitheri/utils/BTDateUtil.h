//
//  BTDateUtil.h
//  Bitheri
//
//  Created by 韩珍 on 2020/6/23.
//  Copyright © 2020 Bither. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BTDateUtil : BlockchairQueryApi

+ (NSDate *)getDateFormStringWithTimeZone:(NSString *)str;

@end

NS_ASSUME_NONNULL_END
