//
//  BTPrivateKeyUtil.m
//  bither-ios
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
#import "BTPrivateKeyUtil.h"
#import "NSData+Hash.h"
#import "NSMutableData+Bitcoin.h"
#import "BTAddress.h"




@implementation BTPrivateKeyUtil

+(NSString *)getPrivateKeyString:(BTKey *) key passphrase:(NSString *)passphrase {
    uint8_t flag=0;
    if (key.compressed) {
        flag=flag+IS_COMPRESSED_FLAG;
    }
    if (key.isFromXRandom) {
        flag=flag+IS_FROMXRANDOM_FLAG;
    }
    NSString *encryptPrivKey = [key bitcoinjKeyWithPassphrase:passphrase andSalt:[NSData randomWithSize:8] andIV:[NSData randomWithSize:16] flag:flag];
    return encryptPrivKey;
}


@end
