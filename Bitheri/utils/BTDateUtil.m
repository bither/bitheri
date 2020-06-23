//
//  BTDateUtil.m
//  Bitheri
//
//  Created by 韩珍 on 2020/6/23.
//  Copyright © 2020 Bither. All rights reserved.
//

#import "BTDateUtil.h"

@implementation BTDateUtil

+ (NSDate *)getDateFormStringWithTimeZone:(NSString *)str {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:8]];
    return [dateFormatter dateFromString:str];
}

@end
