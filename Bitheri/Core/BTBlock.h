//
//  BTBlock.h
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
#import "BTBlockItem.h"

@interface BTBlock : NSObject

@property (nonatomic, readonly) NSData *blockHash;
@property (nonatomic, readonly) uint32_t version;
@property (nonatomic, readonly) NSData *prevBlock;
@property (nonatomic, readonly) NSData *merkleRoot;
@property (nonatomic, readonly) uint32_t blockTime; // time interval since refrence date, 00:00:00 01/01/01 GMT
@property (nonatomic, readonly) uint32_t target;
@property (nonatomic, readonly) uint32_t nonce;
@property (nonatomic, readonly) uint32_t totalTransactions;
@property (nonatomic, readonly) NSData *hashes;
@property (nonatomic, readonly) NSData *flags;
@property (nonatomic, assign) uint32_t height;
@property (nonatomic, assign) BOOL isMain;

@property (nonatomic, readonly) NSArray *txHashes; // the matched tx hashes in the block

// true if merkle tree and timestamp are valid, and proof-of-work matches the stated difficulty target
// NOTE: this only checks if the block difficulty matches the difficulty target in the header, it does not check if the
// target is correct for the block's height in the chain, use verifyDifficultyFromPreviousBlock: for that
@property (nonatomic, readonly, getter = isValid) BOOL valid;

@property (nonatomic, readonly, getter = toData) NSData *data;

// message can be either a merkle block or header message
+ (instancetype)blockWithMessage:(NSData *)message;

- (instancetype)initWithMessage:(NSData *)message;
- (instancetype)initWithBlockHash:(NSData *)blockHash version:(uint32_t)version prevBlock:(NSData *)prevBlock
                       merkleRoot:(NSData *)merkleRoot timestamp:(NSTimeInterval)timestamp target:(uint32_t)target nonce:(uint32_t)nonce
                totalTransactions:(uint32_t)totalTransactions hashes:(NSData *)hashes flags:(NSData *)flags height:(uint32_t)height;


// true if the given tx hash is known to be included in the block
- (BOOL)containsTxHash:(NSData *)txHash;

// Verifies the block difficulty target is correct for the block's position in the chain. Transition time may be 0 if
// height is not a multiple of BLOCK_DIFFICULTY_INTERVAL.
- (BOOL)verifyDifficultyFromPreviousBlock:(BTBlock *)previous andTransitionTime:(NSTimeInterval)time;

+ (instancetype)blockWithBlockItem:(BTBlockItem *)blockItem;
- (BTBlockItem *)formatToBlockItem;

- (instancetype)initWithBlockItem:(BTBlockItem *)blockItem;

- (instancetype)initWithVersion:(uint32_t)version prevBlock:(NSData *)prevBlock merkleRoot:(NSData *)merkleRoot timestamp:(NSTimeInterval)timestamp target:(uint32_t)target nonce:(uint32_t)nonce height:(uint32_t)height;
- (NSData *)toDataWithHash;


@end
