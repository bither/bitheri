//
//  BTBech32.h
//  Bitheri
//
//  Created by hanzhenzhen on 2019/12/18.
//  Copyright © 2019 Bither. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BTBech32Data.h"

NS_ASSUME_NONNULL_BEGIN

@interface BTBech32 : NSObject

- (NSString *)encode:(NSString *)hrp values: (NSData *)values;

- (BTBech32Data *)decode:(NSString *)str;

@end

NS_ASSUME_NONNULL_END
