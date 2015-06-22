//
//  BTBlockChain.m
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

#import "BTBlockChain.h"
#import "BTBlockProvider.h"
#import "BTTxProvider.h"
#import "BTSettings.h"
#import "BTPeer.h"

@interface BTBlockChain ()

@property(nonatomic, strong) BTBlock *lastOrphan;

@end

@implementation BTBlockChain

+ (instancetype)instance {
    static BTBlockChain *blockChain = nil;
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        blockChain = [[BTBlockChain alloc] init];
    });
    return blockChain;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;

    [[BTBlockProvider instance] cleanOldBlock];
    _singleBlocks = [NSMutableDictionary new];

    _lastBlock = [[BTBlockProvider instance] getLastBlock];
    _lastOrphan = [[BTBlockProvider instance] getLastOrphanBlock];

    return self;
}

- (NSDictionary *)getMainChainFromBlocks:(NSArray *)blocks; {
    // this method can re compute the main chain which not need now.
    NSMutableDictionary *prevDict = [NSMutableDictionary new];
    NSMutableDictionary *blockDict = [NSMutableDictionary new];
    for (BTBlock *block in blocks) {
        prevDict[block.blockPrev] = block;
        blockDict[block.blockHash] = block;
    }

    NSMutableArray *ends = [NSMutableArray new];
    for (BTBlock *block in blocks) {
        if (prevDict[block.blockHash] == nil) {
            [ends addObject:block];
        }
    }
    NSDictionary *mainChain = nil;
    NSMutableDictionary *chain = nil;
    BTBlock *lastBlock = nil;
    int maxLength = 0;
    for (BTBlock *block in ends) {
        chain = [NSMutableDictionary new];
        int len = 0;
        BTBlock *b = block;
        while (b != nil) {
            chain[b.blockHash] = block;
//            b = prevDict[b.blockHash];
            b = blockDict[b.blockPrev];
            len += 1;
        }
        if (lastBlock == nil) {
            mainChain = chain;
            maxLength = len;
        } else if (len > maxLength) {
            lastBlock = block;
            mainChain = chain;
            maxLength = len;
        }
    }

    if (mainChain == nil) {
        mainChain = [NSMutableDictionary new];
    }
    return mainChain;
}

- (void)addBlock:(BTBlock *)block {
    [[BTBlockProvider instance] addBlock:block];
}

- (void)addBlocks:(NSArray *)blocks {
    [[BTBlockProvider instance] addBlocks:blocks];
}

- (BOOL)isExist:(NSData *)blockHash; {
    return [[BTBlockProvider instance] isExist:blockHash];
}

- (BTBlock *)getBlock:(NSData *)blockHash; {
    return [[BTBlockProvider instance] getBlock:blockHash];
}

- (BTBlock *)getMainChainBlock:(NSData *)blockHash; {
    return [[BTBlockProvider instance] getMainChainBlock:blockHash];
}

- (BTBlock *)getOrphanBlockByPrevHash:(NSData *)prevHash; {
    return [[BTBlockProvider instance] getOrphanBlockByPrevHash:prevHash];
}

- (int)getBlockCount {
    return [[BTBlockProvider instance] getBlockCount];
}

- (NSTimeInterval)getTransactionTime:(BTBlock *)block; {
    NSTimeInterval transitionTime = 0;
    // hit a difficulty transition, find previous transition time
    if ((block.blockNo % BLOCK_DIFFICULTY_INTERVAL) == 0) {
        BTBlock *b = block;
        for (uint32_t i = 0; b && i < BLOCK_DIFFICULTY_INTERVAL; i++) {
            b = [self getBlock:b.blockPrev];
        }
        transitionTime = b.blockTime;
    }
    return transitionTime;
}

- (BOOL)inMainChain:(BTBlock *)block; {
    BTBlock *b = [self lastBlock];
    while (b && b.blockNo > block.blockNo) {
        b = [self getBlock:b.blockPrev];
    }
    return [b.blockHash isEqual:block.blockHash];
}

- (BTBlock *)getSameParent:(BTBlock *)block1 with:(BTBlock *)block2; {
    BTBlock *b = block1, *b2 = block2;

    // walk back to where the fork joins the main chain
    while (b && b2 && ![b.blockHash isEqual:b2.blockHash]) {
        b = [self getBlock:b.blockPrev];
        if (b.blockNo < b2.blockNo)
            b2 = [self getBlock:b2.blockPrev];
    }
    return b;
}

- (void)addSPVBlock:(BTBlock *)block; {
    // only none block need add spv block
    if ([self getBlockCount] == 0) {
        block.isMain = YES;
        [self addBlock:block];
        _lastBlock = block;
    }
}

- (void)extendMainChain:(BTBlock *)block; {
    if ([block.blockPrev isEqualToData:self.lastBlock.blockHash]) {
        block.isMain = YES;
        [self addBlock:block];
        _lastBlock = block;
    }
}

- (void)forkMainChainFrom:(BTBlock *)forkStartBlock andLast:(BTBlock *)lastBlock; {
    BTBlock *b = self.lastBlock;
    BTBlock *next = lastBlock;
    while (![b.blockHash isEqualToData:forkStartBlock.blockHash]) {
        next = [self getOrphanBlockByPrevHash:b.blockPrev];

        [[BTBlockProvider instance] updateBlock:b.blockHash withIsMain:NO];
        b = [self getMainChainBlock:b.blockPrev];
        _lastBlock = b;
    }
    b = next;
    [[BTBlockProvider instance] updateBlock:next.blockHash withIsMain:YES];
    _lastBlock = next;
    while (![b.blockHash isEqualToData:lastBlock.blockPrev]) {
        [[BTBlockProvider instance] updateBlock:b.blockHash withIsMain:YES];
        _lastBlock = b;
        b = [self getOrphanBlockByPrevHash:b.blockHash];
    }
    lastBlock.isMain = YES;
    [self addBlock:lastBlock];
    _lastBlock = lastBlock;
}

- (void)addOrphan:(BTBlock *)block; {
    [self addBlock:block];
    block.isMain = NO;
    self.lastOrphan = block;
}

- (void)relayedBlock:(BTBlock *)block withCallback:(void (^)(BTBlock *b, BOOL isConfirm))callback {
    BTBlock *prev = [self getBlock:block.blockPrev];

    if (!prev) {
        // block is an orphan
        DDLogDebug(@"orphan block %@, previous %@, last block is %@, height %d", block.blockHash, block.blockPrev, self.lastBlock.blockHash, self.lastBlock.blockNo);

        // ignore orphans older than one week ago
        if (block.blockTime - NSTimeIntervalSince1970 < [NSDate timeIntervalSinceReferenceDate] - ONE_WEEK) return;
        self.singleBlocks[block.blockPrev] = block;
//        // call get blocks, unless we already did with the previous block, or we're still downloading the chain
//        if (self.lastBlock.blockNo >= peer.versionLastBlock && ![self.lastOrphan.blockHash isEqual:block.blockPrev]) {
//            DDLogDebug(@"%@:%d calling getblocks", peer.host, peer.peerPort);
//            [peer sendGetBlocksMessageWithLocators:[self blockLocatorArray] andHashStop:nil];
//        }
        return;
    }

    block.blockNo = prev.blockNo + 1;
    NSTimeInterval transitionTime = [self getTransactionTime:block];

    // verify block difficulty
    if (![block verifyDifficultyFromPreviousBlock:prev andTransitionTime:transitionTime]) {
        callback(block, NO);
        return;
    }

    if ([block.blockPrev isEqual:self.lastBlock.blockHash]) {
        // new block extends main chain
        [self extendMainChain:block];
        callback(block, YES);
    }
    else if ([self inMainChain:block]) {
        // we already have the block (or at least the header)
        callback(block, YES);
    }
    else {
        // new block is on a fork
        if (block.blockNo <= BITCOIN_REFERENCE_BLOCK_HEIGHT) { // fork is older than the most recent checkpoint
            DDLogDebug(@"ignoring block on fork older than most recent checkpoint, fork height: %d, blockHash: %@",
                    block.blockNo, block.blockHash);
            return;
        }

        // special case, if a new block is mined while we're rescaning the chain, mark as orphan til we're caught up
        if (block.blockNo <= self.lastBlock.blockNo) {
            [self addOrphan:block];
            return;
        }

        DDLogDebug(@"chain fork to height %d", block.blockNo);
        // if fork is shorter than main chain, ingore it for now
        if (block.blockNo > self.lastBlock.blockNo) {
            BTBlock *b = [self getSameParent:block with:self.lastBlock];
            DDLogDebug(@"reorganizing chain from height %d, new height is %d", b.blockNo, block.blockNo);
            [self rollbackBlock:b.blockNo];
        }
    }
}

- (int)relayedBlockHeadersForMainChain:(NSArray *)blocks; {
    if (blocks.count == 0)
        return 0;
    NSMutableArray *blocksToAdd = [NSMutableArray new];
    BTBlock *prev = self.lastBlock;
    if (prev == nil)
        return 0;
    for (int i = 0; i < blocks.count; i++) {
        BTBlock *block = blocks[i];
        if (![block.blockPrev isEqualToData:prev.blockHash]) {
            BTBlock *alreadyIn = [self getBlock:block.blockHash];
            if (alreadyIn == nil) {
                continue;
            } else {
                self.singleBlocks[block.blockHash] = block;
                break;
            }
        }
        block.blockNo = prev.blockNo + 1;
        NSTimeInterval transitionTime = [self getTransactionTime:block];
        if (![block verifyDifficultyFromPreviousBlock:prev andTransitionTime:transitionTime]) {
            break;
        }

        block.isMain = YES;
        [blocksToAdd addObject:block];
        prev = block;
    }

    if (blocksToAdd.count > 0) {
        [self addBlocks:blocksToAdd];
        _lastBlock = blocksToAdd[blocksToAdd.count - 1];
    }
    return blocksToAdd.count;
}

- (int)relayedBlocks:(NSArray *)blocks; {
    if (blocks.count == 0) {
        return 0;
    }
    BTBlock *prev = nil;
    BTBlock *first = blocks[0];
    uint32_t rollbackBlockNo = 0;
    if ([first.blockPrev isEqualToData:self.lastBlock.blockHash]) {
        prev = self.lastBlock;
    } else if ([self getMainChainBlock:first.blockPrev] != nil) {
        prev = [self getSameParent:self.lastBlock with:first];
        rollbackBlockNo = prev.blockNo;
    }
    if (prev == nil)
        return 0;
    // check blocks
    BOOL valid = YES;
    for (BTBlock *block in blocks) {
        if (![block.blockPrev isEqualToData:prev.blockHash]) {
            valid = NO;
            break;
        }
        block.blockNo = prev.blockNo + 1;
//        NSTimeInterval transitionTime = [self getTransactionTime:block];
        NSTimeInterval transitionTime = 0;
        // hit a difficulty transition, find previous transition time
        if ((block.blockNo % BLOCK_DIFFICULTY_INTERVAL) == 0) {
            BTBlock *b = first;
            for (uint32_t i = 0; b && i < BLOCK_DIFFICULTY_INTERVAL - block.blockNo + first.blockNo; i++) {
                b = [self getBlock:b.blockPrev];
            }
            transitionTime = b.blockTime;
        }

        if (![block verifyDifficultyFromPreviousBlock:prev andTransitionTime:transitionTime]) {
            valid = NO;
            break;
        }

        block.isMain = YES;
        prev = block;
    }
    if (valid) {
        if (rollbackBlockNo > 0)
            [self rollbackBlock:rollbackBlockNo];
        [self addBlocks:blocks];
        for (BTBlock *block in blocks) {
            [[BTTxProvider instance] confirmTx:block.txHashes withBlockNo:block.blockNo];
        }
        _lastBlock = blocks[blocks.count - 1];
        return blocks.count;
    } else {
        return 0;
    }
}

- (NSArray *)blockLocatorArray {
    // append 10 most recent block hashes, descending, then continue appending, doubling the step back each time,
    // finishing with the genesis block (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0)
    NSMutableArray *locators = [NSMutableArray array];
    int32_t step = 1, start = 0;
    BTBlock *b = self.lastBlock;

    while (b && b.blockNo > 0) {
        [locators addObject:b.blockHash];
        if (++start >= 10) step *= 2;

        for (int32_t i = 0; b && i < step; i++) {
            b = [self getMainChainBlock:b.blockPrev];
        }
    }

    [locators addObject:GENESIS_BLOCK_HASH];

    return locators;
}

- (BOOL)rollbackBlock:(uint32_t)blockNo; {
    if (blockNo > self.lastBlock.blockNo)
        return NO;
    int delta = self.lastBlock.blockNo - blockNo;
    if (delta >= BLOCK_DIFFICULTY_INTERVAL || delta >= [self getBlockCount])
        return NO;

    NSMutableArray *blocks = [[BTBlockProvider instance] getBlocksFrom:blockNo];
    DDLogWarn(@"roll back block from %d to %d", self.lastBlock.blockNo, blockNo);
    for (BTBlock *blockItem in blocks) {
        [[BTBlockProvider instance] removeBlock:blockItem.blockHash];
        if (blockItem.isMain) {
            [[BTTxProvider instance] unConfirmTxByBlockNo:blockItem.blockNo];
        }
    }
    _lastBlock = [[BTBlockProvider instance] getLastBlock];
    if (_lastBlock) {
        DDLogWarn(@"there is no main block in sqlite!!");
    }
    return YES;
}

- (NSArray *)getAllBlocks {
    return [[BTBlockProvider instance] getAllBlocks];
}

- (NSArray *)getBlocksWithLimit:(NSInteger)limit {
    return [[BTBlockProvider instance] getBlocksWithLimit:limit];
}

@end
