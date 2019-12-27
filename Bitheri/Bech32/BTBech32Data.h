//
//  BTBech32Data.h
//  Bitheri
//
//  Created by hanzhenzhen on 2019/12/18.
//  Copyright © 2019 Bither. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BTBech32Data : NSObject

@property(nonatomic, strong) NSString *hrp;
@property(nonatomic, copy) NSData *checksum;

- (instancetype)initWithHrp:(NSString *)hrp checksum:(NSData *)checksum;

@end

NS_ASSUME_NONNULL_END
