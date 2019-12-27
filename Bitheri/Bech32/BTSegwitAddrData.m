//
//  BTSegwitAddrData.m
//  Bitheri
//
//  Created by hanzhenzhen on 2019/12/19.
//  Copyright © 2019 Bither. All rights reserved.
//

#import "BTSegwitAddrData.h"

@implementation BTSegwitAddrData

- (instancetype)initWithVersion:(int)version program:(NSData *)program {
    self = [super init];
    if (self) {
        _version = version;
        _program = program;
    }
    return self;
}

@end
