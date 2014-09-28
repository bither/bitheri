//
//  BTPasswordSeed.m
//  bitheri
//
//  Copyright 2014 http://Bither.net
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "BTPasswordSeed.h"
#import "BTQRCodeUtil.h"

@interface BTPasswordSeed ()

@property (nonatomic, copy) NSString *address;
@property (nonatomic, copy) NSString *keyStr;

@end

@implementation BTPasswordSeed
- (instancetype)initWithString:(NSString *)message {
    self = [super init];
    if (self) {
        NSArray *array = [BTQRCodeUtil splitQRCode:message];
        _address = array[0];
        _keyStr = [message substringFromIndex:self.address.length + 1];

    }
    return self;
}

- (instancetype)initWithBTAddress:(BTAddress *)btAddress {
    self = [super init];
    if (self) {
        _address = btAddress.address;
        _keyStr = btAddress.encryptPrivKey;

    }
    return self;
}

- (BOOL)checkPassword:(NSString *)password {
    BTKey *key = [BTKey keyWithBitcoinj:self.keyStr andPassphrase:password];
    if (key) {
        return [key.address isEqualToString:self.address];
    } else {
        return NO;
    }
}
-(NSString *)toPasswrodSeedString{
    NSArray *array=[[NSArray alloc] initWithObjects:self.address,self.keyStr, nil];
    return [[BTQRCodeUtil joinedQRCode:array] toUppercaseStringWithEn];
}


@end
