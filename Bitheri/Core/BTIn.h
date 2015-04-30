//
//  BTIn.h
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
//  limitations under the License.#import <Foundation/Foundation.h>


#import <CommonCrypto/CommonDigest.h>
#import "NSMutableData+Bitcoin.h"

@class BTTx;

static NSData *getOutPoint(NSData *txHash, uint32_t n) {
    NSMutableData *d = [NSMutableData dataWithCapacity:CC_SHA256_DIGEST_LENGTH + sizeof(uint32_t)];

    [d appendData:txHash];
    [d appendUInt32:n];
    return d;
}

@interface BTIn : NSObject

@property(nonatomic, copy) NSData *txHash;
@property uint inSn;

@property(nonatomic, copy) NSData *prevTxHash;
@property uint prevOutSn;
@property(nonatomic, copy) NSData *inSignature;
@property uint inSequence;

@property(nonatomic, weak) BTTx *tx;
@property(nonatomic, copy) NSData *inScript;

@property(nonatomic, readonly) BOOL isCoinBase;

- (NSArray *)getP2SHPubKeys;

@end