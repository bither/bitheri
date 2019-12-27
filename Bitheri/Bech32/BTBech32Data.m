//
//  BTBech32Data.m
//  Bitheri
//
//  Created by hanzhenzhen on 2019/12/18.
//  Copyright © 2019 Bither. All rights reserved.
//

#import "BTBech32Data.h"

@implementation BTBech32Data

- (instancetype)initWithHrp:(NSString *)hrp checksum:(NSData *)checksum {
    self = [super init];
    if (self) {
        _hrp = hrp;
        _checksum = checksum;
    }
    return self;
}

@end
