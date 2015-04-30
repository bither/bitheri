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
//
//  Copyright (c) 2013-2014 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <Foundation/Foundation.h>
//#import "BTBlockItem.h"

@interface BTBlock : NSObject

@property(nonatomic, assign) uint32_t blockNo;
@property(nonatomic, readonly) NSData *blockHash;
@property(nonatomic, readonly) NSData *blockRoot;
@property(nonatomic, readonly) uint32_t blockVer;
@property(nonatomic, readonly) uint32_t blockBits;
@property(nonatomic, readonly) uint32_t blockNonce;
@property(nonatomic, readonly) uint32_t blockTime;
@property(nonatomic, readonly) NSData *blockPrev;
@property(nonatomic, assign) BOOL isMain;

@property(nonatomic, readonly) NSArray *txHashes; // the matched tx hashes in the block

@property(nonatomic, readonly) uint32_t totalTransactions;
@property(nonatomic, readonly) NSData *hashes;
@property(nonatomic, readonly) NSData *flags;

// true if merkle tree and timestamp are valid, and proof-of-work matches the stated difficulty target
// NOTE: this only checks if the block difficulty matches the difficulty target in the header, it does not check if the
// target is correct for the block's height in the chain, use verifyDifficultyFromPreviousBlock: for that
@property(nonatomic, readonly, getter = isValid) BOOL valid;

@property(nonatomic, readonly, getter = toData) NSData *data;

// message can be either a merkle block or header message
+ (instancetype)blockWithMessage:(NSData *)message;

- (instancetype)initWithMessage:(NSData *)message;

- (instancetype)initWithBlockHash:(NSData *)blockHash version:(uint32_t)version prevBlock:(NSData *)prevBlock
                       merkleRoot:(NSData *)merkleRoot timestamp:(NSTimeInterval)timestamp target:(uint32_t)target nonce:(uint32_t)nonce
                totalTransactions:(uint32_t)totalTransactions hashes:(NSData *)hashes flags:(NSData *)flags height:(uint32_t)height;

- initWithBlockNo:(uint32_t)blockNo blockHash:(NSData *)blockHash blockRoot:(NSData *)blockRoot blockVer:(uint32_t)blockVer
        blockBits:(uint32_t)blockBits blockNonce:(uint32_t)blockNonce blockTime:(uint32_t)blockTime
        blockPrev:(NSData *)blockPrev isMain:(BOOL)isMain;

// true if the given tx hash is known to be included in the block
- (BOOL)containsTxHash:(NSData *)txHash;

// Verifies the block difficulty target is correct for the block's position in the chain. Transition time may be 0 if
// height is not a multiple of BLOCK_DIFFICULTY_INTERVAL.
- (BOOL)verifyDifficultyFromPreviousBlock:(BTBlock *)previous andTransitionTime:(NSTimeInterval)time;

//+ (instancetype)blockWithBlockItem:(BTBlockItem *)blockItem;
//- (BTBlockItem *)formatToBlockItem;

//- (instancetype)initWithBlockItem:(BTBlockItem *)blockItem;

- (instancetype)initWithVersion:(uint32_t)version prevBlock:(NSData *)prevBlock merkleRoot:(NSData *)merkleRoot timestamp:(NSTimeInterval)timestamp target:(uint32_t)target nonce:(uint32_t)nonce height:(uint32_t)height;

- (NSData *)toDataWithHash;


@end
