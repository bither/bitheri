//
//  BTBlockProvider.h
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


@interface BTBlockProvider : NSObject

+ (instancetype)instance;

- (int)getBlockCount;

- (NSMutableArray *)getAllBlocks;

- (NSMutableArray *)getBlocksFrom:(uint)blockNo;

- (BTBlockItem *)getLastBlock;
- (BTBlockItem *)getLastOrphanBlock;

- (BTBlockItem *)getBlock:(NSData *)blockHash;

//- (void)clear;

//- (void)deleteBlocksNotInHashes:(NSSet *) blockHashes;

//- (NSArray *)exists:(NSSet *) blockHashes;

- (BOOL)isExist:(NSData *)blockHash;

//- (void)addBlocks:(NSArray *)blocks;

- (void)addBlock:(BTBlockItem *)block;

- (void)addBlocks:(NSArray *)blocks;

- (void)updateBlock:(NSData *)blockHash withIsMain:(BOOL)isMain;

- (BTBlockItem *)getOrphanBlockByPrevHash:(NSData *)prevHash;

- (BTBlockItem *)getMainChainBlock:(NSData *)blockHash;

- (void)removeBlock:(NSData *)blockHash;

- (void)cleanOldBlock;

@end