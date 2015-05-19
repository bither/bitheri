//
//  BTScript.h
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

#import <Foundation/Foundation.h>
#import "BTTx.h"

const static int MAX_SCRIPT_ELEMENT_SIZE = 520;
const static int SIG_SIZE = 75;

@interface BTScript : NSObject

@property(nonatomic, copy) NSArray *chunks;
@property(nonatomic, weak) BTTx *tx;
@property NSUInteger index;
@property(nonatomic, copy) NSData *program;

- (instancetype)initWithProgram:(NSData *)program;

- (instancetype)initWithChunks:(NSArray *)chunks;

- (NSData *)getPubKey;

- (NSData *)getPubKeyHash;

- (NSString *)getFromAddress;

- (NSString *)getToAddress;

- (NSData *)getSig;

- (NSArray *)getSigs;


- (BOOL)correctlySpends:(BTScript *)scriptPubKey and:(BOOL)enforceP2SH;

- (NSArray *)getP2SHPubKeys;

- (uint)getSizeRequiredToSpendWithRedeemScript:(BTScript *)redeemScript andIsCompressed:(BOOL)isCompressed;

#pragma mark - standard script

- (BOOL)isSentToRawPubKey;

- (BOOL)isSentToAddress;

- (BOOL)isSentToP2SH;

- (BOOL)isSentToOldMultiSig;

- (BOOL)isSendFromMultiSig;

- (BOOL)isMultiSigRedeem;


#pragma mark - help method

+ (NSData *)removeAllInstancesOf:(NSData *)inputScript and:(NSData *)chunkToRemove;

+ (uint8_t)encodeToOpN:(long long)value;

+ (long long)decodeFromOpN:(uint8_t)opCode;;

+ (NSData *)castInt64ToData:(long long)val;

+ (long long)castToInt64:(NSData *)data;

+ (BOOL)castToBool:(NSData *)data;

@end