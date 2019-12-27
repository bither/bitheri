//
//  BTSegwitAddrData.h
//  Bitheri
//
//  Created by hanzhenzhen on 2019/12/19.
//  Copyright © 2019 Bither. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BTSegwitAddrData : NSObject

@property(nonatomic, assign) int version;
@property(nonatomic, copy) NSData *program;

- (instancetype)initWithVersion:(int)version program:(NSData *)program;

@end

NS_ASSUME_NONNULL_END
