//
//  BTBlockChain.h
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
#import "BTBlock.h"
#import "NSString+Base58.h"
#import "NSData+Hash.h"
#import "BTPeer.h"

@interface BTBlockChain : NSObject

@property(nonatomic, strong) NSMutableDictionary *singleBlocks;
@property(nonatomic, strong, readonly) BTBlock *lastBlock;


+ (instancetype)instance;

- (void)addSPVBlock:(BTBlock *)block;

- (int)getBlockCount;

- (NSArray *)blockLocatorArray;

- (void)relayedBlock:(BTBlock *)block withCallback:(void (^)(BTBlock *b, BOOL isConfirm))callback;

- (int)relayedBlockHeadersForMainChain:(NSArray *)blocks;

- (int)relayedBlocks:(NSArray *)blocks;

- (BOOL)rollbackBlock:(uint32_t)blockNo;

- (NSArray *)getAllBlocks;

- (NSArray *)getBlocksWithLimit:(NSInteger)limit;

@end
