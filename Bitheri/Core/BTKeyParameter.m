//
//  BTKeyParameter.m
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
//  limitations under the License.#import "BTKeyParameter.h"


#import "BTKeyParameter.h"
#import "NSString+Base58.h"

@implementation BTKeyParameter {

}

+ (BIGNUM *)maxN {
    static BIGNUM *n = nil;
    if (n == nil) {
        n = BN_bin2bn([ECKEY_MAX_N hexToData].bytes, 32, NULL);
    }
    return n;
}

+ (BIGNUM *)minN {
    static BIGNUM *minN = nil;
    if (minN == nil) {
        minN = BN_bin2bn([ECKEY_MIN_N hexToData].bytes, 1, NULL);
    }
    return minN;
}
@end