//
//  BTBloomFilter.h
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

#define BLOOM_DEFAULT_FALSEPOSITIVE_RATE 0.0005 // same as bitcoinj, use 0.0001 for less data, 0.001 for good anonymity
#define BLOOM_REDUCED_FALSEPOSITIVE_RATE 0.0001
#define BLOOM_UPDATE_NONE                0
#define BLOOM_UPDATE_ALL                 1
#define BLOOM_UPDATE_P2PUBKEY_ONLY       2
#define BLOOM_MAX_FILTER_LENGTH          36000

@class BTTx;

@interface BTBloomFilter : NSObject

@property (nonatomic, readonly) uint32_t tweak;
@property (nonatomic, readonly) uint8_t flags;
@property (nonatomic, readonly, getter = toData) NSData *data;
@property (nonatomic, readonly) NSUInteger elementCount;
@property (nonatomic, readonly) double falsePositiveRate;
@property (nonatomic, readonly) NSUInteger length;

+ (instancetype)filterWithMessage:(NSData *)message;
+ (instancetype)filterWithFullMatch;

- (instancetype)initWithMessage:(NSData *)message;
- (instancetype)initWithFullMatch;
- (instancetype)initWithFalsePositiveRate:(double)fpRate forElementCount:(NSUInteger)count tweak:(uint32_t)tweak
flags:(uint8_t)flags;
- (BOOL)containsData:(NSData *)data;
- (void)insertData:(NSData *)data;
- (void)updateWithTransaction:(BTTx *)tx;

@end
