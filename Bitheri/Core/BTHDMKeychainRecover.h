//
//  BTHDMKeychainRecover.h
//  Bitheri
//
//  Created by 宋辰文 on 15/1/26.
//  Copyright (c) 2015年 Bither. All rights reserved.
//

#import "BTHDMKeychain.h"

@interface BTHDMKeychainRecover : BTHDMKeychain
+ (NSString *)RecoverPlaceHolder;

- (instancetype)initWithColdExternalRootPub:(NSData *)coldExternalRootPub password:(NSString *)password andFetchBlock:(NSArray *(^)(NSString *password))fetchBlock;
@end
