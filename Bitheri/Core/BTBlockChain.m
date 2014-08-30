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

static BTBlockChain *blockChain;

@interface BTBlockChain ()

@property (nonatomic, strong) BTBlock *lastOrphan;

@end

@implementation BTBlockChain

+ (instancetype)instance {
    @synchronized (self) {
        if (blockChain == nil) {
            blockChain = [[self alloc] init];
        }
    }
    return blockChain;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;

    [[BTBlockProvider instance] cleanOldBlock];
    _singleBlocks = [NSMutableDictionary new];

    BTBlockItem *blockItem = [[BTBlockProvider instance] getLastBlock];
    if (blockItem) {
        _lastBlock = [[BTBlock alloc] initWithBlockItem:blockItem];
    }
    BTBlockItem *orphanBlockItem = [[BTBlockProvider instance] getLastOrphanBlock];
    if (orphanBlockItem) {
        _lastOrphan = [[BTBlock alloc] initWithBlockItem:orphanBlockItem];
    }

    return self;
}

- (NSDictionary *)getMainChainFromBlocks:(NSArray *)blocks; {
    // this method can re compute the main chain which not need now.
    NSMutableDictionary *prevDict = [NSMutableDictionary new];
    NSMutableDictionary *blockDict = [NSMutableDictionary new];
    for (BTBlock *block in blocks) {
        prevDict[block.prevBlock] = block;
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
            b = blockDict[b.prevBlock];
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
    [[BTBlockProvider instance] addBlock:[block formatToBlockItem]];
}

- (BOOL)isExist:(NSData *)blockHash; {
    return [[BTBlockProvider instance] isExist:blockHash];
}

- (BTBlock *)getBlock:(NSData *)blockHash; {
    BTBlockItem *blockItem = [[BTBlockProvider instance] getBlock:blockHash];
    if (blockItem == nil) {
        return nil;
    } else {
        return [BTBlock blockWithBlockItem:blockItem];
    }
}

- (BTBlock *)getMainChainBlock:(NSData *)blockHash; {
    BTBlockItem *blockItem = [[BTBlockProvider instance] getMainChainBlock:blockHash];
    if (blockItem == nil) {
        return nil;
    } else {
        return [BTBlock blockWithBlockItem:blockItem];
    }
}

- (BTBlock *)getOrphanBlockByPrevHash:(NSData *)prevHash; {
    BTBlockItem *blockItem = [[BTBlockProvider instance] getOrphanBlockByPrevHash:prevHash];
    if (blockItem == nil) {
        return nil;
    } else {
        return [BTBlock blockWithBlockItem:blockItem];
    }
}

- (int)getBlockCount {
    return [[BTBlockProvider instance] getBlockCount];
}

- (NSTimeInterval)getTransactionTime:(BTBlock *)block; {
    NSTimeInterval transitionTime = 0;
    // hit a difficulty transition, find previous transition time
    if ((block.height % BLOCK_DIFFICULTY_INTERVAL) == 0) {
        BTBlock *b = block;
        for (uint32_t i = 0; b && i < BLOCK_DIFFICULTY_INTERVAL; i++) {
            b = [self getBlock:b.prevBlock];
        }
        transitionTime = b.blockTime;
    }
    return transitionTime;
}

- (BOOL)inMainChain:(BTBlock *)block; {
    BTBlock *b = [self lastBlock];
    while (b && b.height > block.height) {
        b = [self getBlock:b.prevBlock];
    }
    return [b.blockHash isEqual:block.blockHash];
}

- (BTBlock *)getSameParent:(BTBlock *)block1 with:(BTBlock *)block2; {
    BTBlock *b = block1, *b2 = block2;

    // walk back to where the fork joins the main chain
    while (b && b2 && ![b.blockHash isEqual:b2.blockHash]) {
        b = [self getBlock:b.prevBlock];
        if (b.height < b2.height)
            b2 = [self getBlock:b2.prevBlock];
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
    if ([block.prevBlock isEqualToData:self.lastBlock.blockHash]) {
        block.isMain = YES;
        [self addBlock:block];
        _lastBlock = block;
    }
}

- (void)forkMainChainFrom:(BTBlock *)forkStartBlock andLast:(BTBlock *)lastBlock; {
    BTBlock *b = self.lastBlock;
    BTBlock *next = lastBlock;
    while (![b.blockHash isEqualToData:forkStartBlock.blockHash]) {
        next = [self getOrphanBlockByPrevHash:b.prevBlock];

        [[BTBlockProvider instance] updateBlock:b.blockHash withIsMain:NO];
        b = [self getMainChainBlock:b.prevBlock];
        _lastBlock = b;
    }
    b = next;
    [[BTBlockProvider instance] updateBlock:next.blockHash withIsMain:YES];
    _lastBlock = next;
    while (![b.blockHash isEqualToData:lastBlock.prevBlock]) {
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

- (void)relayedBlock:(BTBlock *)block withPeer:(BTPeer *)peer andCallback:(void (^)(BTBlock *b, BOOL isConfirm))callback; {
    BTBlock *prev = [self getBlock:block.prevBlock];

    if (!prev) {
        // block is an orphan
        DDLogDebug(@"%@:%d relayed orphan block %@, previous %@, last block is %@, height %d", peer.host, peer.port,
                        block.blockHash, block.prevBlock, self.lastBlock.blockHash, self.lastBlock.height);

        // ignore orphans older than one week ago
        if (block.blockTime - NSTimeIntervalSince1970 < [NSDate timeIntervalSinceReferenceDate] - ONE_WEEK) return;
        self.singleBlocks[block.prevBlock] = block;
        // call get blocks, unless we already did with the previous block, or we're still downloading the chain
        if (self.lastBlock.height >= peer.lastBlock && ![self.lastOrphan.blockHash isEqual:block.prevBlock]) {
            DDLogDebug(@"%@:%d calling getblocks", peer.host, peer.port);
            [peer sendGetBlocksMessageWithLocators:[self blockLocatorArray] andHashStop:nil];
        }
        return;
    }

    block.height = prev.height + 1;
    NSTimeInterval transitionTime = [self getTransactionTime:block];

    // verify block difficulty
    if (![block verifyDifficultyFromPreviousBlock:prev andTransitionTime:transitionTime]) {
        callback(block, NO);
        return;
    }

    if ([block.prevBlock isEqual:self.lastBlock.blockHash]) {
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
        if (block.height <= BITCOIN_REFERENCE_BLOCK_HEIGHT) { // fork is older than the most recent checkpoint
            DDLogDebug(@"ignoring block on fork older than most recent checkpoint, fork height: %d, blockHash: %@",
                            block.height, block.blockHash);
            return;
        }

        // special case, if a new block is mined while we're rescaning the chain, mark as orphan til we're caught up
        if (block.height <= self.lastBlock.height) {
            [self addOrphan:block];
            return;
        }

        DDLogDebug(@"chain fork to height %d", block.height);
        // if fork is shorter than main chain, ingore it for now
        if (block.height > self.lastBlock.height) {
            BTBlock *b = [self getSameParent:block with:self.lastBlock];
            DDLogDebug(@"reorganizing chain from height %d, new height is %d", b.height, block.height);
            [self rollbackBlock:b.height];
        }
    }
}

- (NSArray *)blockLocatorArray {
    // append 10 most recent block hashes, descending, then continue appending, doubling the step back each time,
    // finishing with the genesis block (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0)
    NSMutableArray *locators = [NSMutableArray array];
    int32_t step = 1, start = 0;
    BTBlock *b = self.lastBlock;

    while (b && b.height > 0) {
        [locators addObject:b.blockHash];
        if (++start >= 10) step *= 2;

        for (int32_t i = 0; b && i < step; i++) {
            b = [self getMainChainBlock:b.prevBlock];
        }
    }

    [locators addObject:GENESIS_BLOCK_HASH];

    return locators;
}

- (BOOL)rollbackBlock:(uint32_t)blockNo; {
    if (blockNo > self.lastBlock.height)
        return NO;
    int delta = self.lastBlock.height - blockNo;
    if (delta >= BLOCK_DIFFICULTY_INTERVAL || delta >= [self getBlockCount])
        return NO;

    NSMutableArray *blocks = [[BTBlockProvider instance] getBlocksFrom:blockNo];
    DDLogWarn(@"roll back block from %d to %d", self.lastBlock.height, blockNo);
    for (BTBlockItem *blockItem in blocks) {
        [[BTBlockProvider instance] removeBlock:blockItem.blockHash];
        if (blockItem.isMain) {
            [[BTTxProvider instance] unConfirmTxByBlockNo:blockItem.blockNo];
        }
    }
    BTBlockItem *blockItem = [[BTBlockProvider instance] getLastBlock];
    if (blockItem) {
        _lastBlock = [[BTBlock alloc] initWithBlockItem:blockItem];
    } else {
        DDLogWarn(@"there is no main block in sqlite!!");
        _lastBlock = nil;
    }
    return YES;
}

@end
