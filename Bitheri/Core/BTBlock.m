//
//  BTBlock.m
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

#import "BTBlock.h"
#import "NSMutableData+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "NSData+Hash.h"
#import <openssl/bn.h>
#import "BTSettings.h"

//#define MAX_TIME_DRIFT    (2*60*60)     // the furthest in the future a block is allowed to be timestamped
//#define MAX_PROOF_OF_WORK 0x1d00ffffu   // highest value for difficulty target (higher values are less difficult)
//#define TARGET_TIMESPAN   (14*24*60*60) // the targeted timespan between difficulty target adjustments

// convert difficulty target format to bignum, as per: https://github.com/bitcoin/bitcoin/blob/master/src/uint256.h#L506
static void setCompact(BIGNUM *bn, uint32_t compact) {
    uint32_t size = compact >> 24, word = compact & 0x007fffff;

    if (size > 3) {
        BN_set_word(bn, word);
        BN_lshift(bn, bn, (size - 3) * 8);
    }
    else BN_set_word(bn, word >> (3 - size) * 8);

    BN_set_negative(bn, (compact & 0x00800000) != 0);
}

static uint32_t getCompact(const BIGNUM *bn) {
    uint32_t size = (uint32_t) BN_num_bytes(bn), compact = 0;
    BIGNUM x;

    if (size > 3) {
        BN_init(&x);
        BN_rshift(&x, bn, (size - 3) * 8);
        compact = BN_get_word(&x);
    }
    else compact = BN_get_word(bn) << (3 - size) * 8;

    if (compact & 0x00800000) { // if sign is already set, divide the mantissa by 256 and increment the exponent
        compact >>= 8;
        size++;
    }

    return (compact | size << 24) | (BN_is_negative(bn) ? 0x00800000 : 0);
}

// from https://en.bitcoin.it/wiki/Protocol_specification#Merkle_Trees
// Merkle trees are binary trees of hashes. Merkle trees in bitcoin use a double SHA-256, the SHA-256 hash of the
// SHA-256 hash of something. If, when forming a row in the tree (other than the root of the tree), it would have an odd
// number of elements, the final double-hash is duplicated to ensure that the row has an even number of hashes. First
// form the bottom row of the tree with the ordered double-SHA-256 hashes of the byte streams of the transactions in the
// block. Then the row above it consists of half that number of hashes. Each entry is the double-SHA-256 of the 64-byte
// concatenation of the corresponding two hashes below it in the tree. This procedure repeats recursively until we reach
// a row consisting of just a single double-hash. This is the merkle root of the tree.
//
// from https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki#Partial_Merkle_branch_format
// The encoding works as follows: we traverse the tree in depth-first order, storing a bit for each traversed node,
// signifying whether the node is the parent of at least one matched leaf txid (or a matched txid itself). In case we
// are at the leaf level, or this bit is 0, its merkle node hash is stored, and its children are not explored further.
// Otherwise, no hash is stored, but we recurse into both (or the only) child branch. During decoding, the same
// depth-first traversal is performed, consuming bits and hashes as they written during encoding.
//
// example tree with three transactions, where only tx2 is matched by the bloom filter:
//
//     merkleRoot
//      /     \
//    m1       m2
//   /  \     /  \
// tx1  tx2 tx3  tx3
//
// flag bits (little endian): 00001011 [merkleRoot = 1, m1 = 1, tx1 = 0, tx2 = 1, m2 = 0, byte padding = 000]
// hashes: [tx1, tx2, m2]

@implementation BTBlock

// message can be either a merkleblock or header message
+ (instancetype)blockWithMessage:(NSData *)message {
    return [[self alloc] initWithMessage:message];
}

- (instancetype)initWithMessage:(NSData *)message {
    if (!(self = [self init])) return nil;

    if (message.length < 80) return nil;

    NSUInteger off = 0, l = 0, len = 0;

    _blockHash = [message subdataWithRange:NSMakeRange(0, 80)].SHA256_2;
    _blockVer = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _blockPrev = [message hashAtOffset:off];
    off += CC_SHA256_DIGEST_LENGTH;
    _blockRoot = [message hashAtOffset:off];
    off += CC_SHA256_DIGEST_LENGTH;
    _blockTime = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _blockBits = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _blockNonce = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _totalTransactions = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    len = (NSUInteger) ([message varIntAtOffset:off length:&l] * CC_SHA256_DIGEST_LENGTH);
    off += l;
    _hashes = off + len > message.length ? nil : [message subdataWithRange:NSMakeRange(off, len)];
    off += len;
    _flags = [message dataAtOffset:off length:&l];
    _blockNo = BLOCK_UNKNOWN_HEIGHT;

    return self;
}

- (instancetype)initWithBlockHash:(NSData *)blockHash version:(uint32_t)version prevBlock:(NSData *)prevBlock
                       merkleRoot:(NSData *)merkleRoot timestamp:(NSTimeInterval)timestamp target:(uint32_t)target nonce:(uint32_t)nonce
                totalTransactions:(uint32_t)totalTransactions hashes:(NSData *)hashes flags:(NSData *)flags height:(uint32_t)height {
    if (!(self = [self init])) return nil;

    _blockHash = blockHash;
    _blockVer = version;
    _blockPrev = prevBlock;
    _blockRoot = merkleRoot;
    _blockTime = (uint32_t) timestamp;
    _blockBits = target;
    _blockNonce = nonce;
    _totalTransactions = totalTransactions;
    _hashes = hashes;
    _flags = flags;
    _blockNo = height;

    return self;
}

// true if merkle tree and timestamp are valid, and proof-of-work matches the stated difficulty target
// NOTE: this only checks if the block difficulty matches the difficulty target in the header, it does not check if the
// target is correct for the block's height in the chain, use verifyDifficultyFromPreviousBlock: for that
- (BOOL)isValid {
    NSMutableData *d = [NSMutableData data];
    BIGNUM target, maxTarget;
    int hashIdx = 0, flagIdx = 0;
    NSData *merkleRoot =
            [self _walk:&hashIdx :&flagIdx :0 :^id(NSData *hash, BOOL flag) {
                return hash;
            } :^id(id left, id right) {
                [d setData:left];
                [d appendData:right ?: left]; // if right branch is missing, duplicate left branch
                return d.SHA256_2;
            }];

    if (_totalTransactions > 0 && ![merkleRoot isEqual:_blockRoot]) return NO; // merkle root check failed

    //TODO: use estimated network time instead of system time (avoids timejacking attacks and misconfigured time)
    if (_blockTime - NSTimeIntervalSince1970 > [NSDate timeIntervalSinceReferenceDate] + MAX_TIME_DRIFT) return NO; // timestamp too far in future

    // check proof-of-work
    BN_init(&target);
    BN_init(&maxTarget);
    setCompact(&target, _blockBits);
    setCompact(&maxTarget, MAX_PROOF_OF_WORK);
    if (BN_cmp(&target, BN_value_one()) < 0 || BN_cmp(&target, &maxTarget) > 0) return NO; // target out of range

    BIGNUM hash;
    BN_init(&hash);
    BN_bin2bn(_blockHash.reverse.bytes, (int) _blockHash.length, &hash);
    return BN_cmp(&hash, &target) <= 0; // block not as difficult as target (smaller values are more difficult)

}

- (NSData *)toData {
    NSMutableData *d = [NSMutableData data];

    [d appendUInt32:_blockVer];
    [d appendData:_blockPrev];
    [d appendData:_blockRoot];
    [d appendUInt32:_blockTime];
    [d appendUInt32:_blockBits];
    [d appendUInt32:_blockNonce];
    [d appendUInt32:_totalTransactions];
    [d appendVarInt:_hashes.length / CC_SHA256_DIGEST_LENGTH];
    [d appendData:_hashes];
    [d appendVarInt:_flags.length];
    [d appendData:_flags];

    return d;
}

// true if the given tx hash is included in the block
- (BOOL)containsTxHash:(NSData *)txHash {
    for (NSUInteger i = 0; i < _hashes.length / CC_SHA256_DIGEST_LENGTH; i += CC_SHA256_DIGEST_LENGTH) {
        if (![txHash isEqual:[_hashes hashAtOffset:i]]) continue;
        return YES;
    }

    return NO;
}

// returns an array of the matched tx hashes
- (NSArray *)txHashes {
    int hashIdx = 0, flagIdx = 0;
    NSArray *txHashes =
            [self _walk:&hashIdx :&flagIdx :0 :^id(NSData *hash, BOOL flag) {
                return (flag && hash) ? @[hash] : @[];
            } :^id(id left, id right) {
                return [left arrayByAddingObjectsFromArray:right];
            }];

    return txHashes;
}

// Verifies the block difficulty target is correct for the block's position in the chain. Transition time may be 0 if
// height is not a multiple of BLOCK_DIFFICULTY_INTERVAL.
//
// The difficulty target algorithm works as follows:
// The target must be the same as in the previous block unless the block's height is a multiple of 2016. Every 2016
// blocks there is a difficulty transition where a new difficulty is calculated. The new target is the previous target
// multiplied by the time between the last transition block's timestamp and this one (in seconds), divided by the
// targeted time between transitions (14*24*60*60 seconds). If the new difficulty is more than 4x or less than 1/4 of
// the previous difficulty, the change is limited to either 4x or 1/4. There is also a minimum difficulty value
// intuitively named MAX_PROOF_OF_WORK... since larger values are less difficult.
- (BOOL)verifyDifficultyFromPreviousBlock:(BTBlock *)previous andTransitionTime:(NSTimeInterval)time {
    if (![_blockPrev isEqual:previous.blockHash] || _blockNo != previous.blockNo + 1) return NO;
    if ((_blockNo % BLOCK_DIFFICULTY_INTERVAL) == 0 && time == 0) return NO;

#if BITCOIN_TESTNET
    //TODO: implement testnet difficulty rule check
    return YES; // don't worry about difficulty on testnet for now
#endif

    if ((_blockNo % BLOCK_DIFFICULTY_INTERVAL) != 0) return _blockBits == previous.blockBits;

    int32_t timespan = (int32_t) ((int64_t) previous.blockTime - (int64_t) time);
    BIGNUM target, maxTarget, span, targetSpan, bn;
    BN_CTX *ctx = BN_CTX_new();

    // limit difficulty transition to -75% or +400%
    if (timespan < TARGET_TIMESPAN / 4) timespan = TARGET_TIMESPAN / 4;
    if (timespan > TARGET_TIMESPAN * 4) timespan = TARGET_TIMESPAN * 4;

    BN_CTX_start(ctx);
    BN_init(&target);
    BN_init(&maxTarget);
    BN_init(&span);
    BN_init(&targetSpan);
    BN_init(&bn);
    setCompact(&target, previous.blockBits);
    setCompact(&maxTarget, MAX_PROOF_OF_WORK);
    BN_set_word(&span, (unsigned int) timespan);
    BN_set_word(&targetSpan, TARGET_TIMESPAN);
    BN_mul(&bn, &target, &span, ctx);
    BN_div(&target, NULL, &bn, &targetSpan, ctx);
    if (BN_cmp(&target, &maxTarget) > 0) BN_copy(&target, &maxTarget); // limit to MAX_PROOF_OF_WORK
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);

    return _blockBits == getCompact(&target);
}

// recursively walks the merkle tree in depth first order, calling leaf(hash, flag) for each stored hash, and
// branch(left, right) with the result from each branch
- (id)_walk:(int *)hashIdx :(int *)flagIdx :(int)depth :(id (^)(NSData *, BOOL))leaf :(id (^)(id, id))branch {
    if ((*flagIdx) / 8 >= _flags.length || (*hashIdx + 1) * CC_SHA256_DIGEST_LENGTH > _hashes.length) return leaf(nil, NO);

    BOOL flag = (BOOL) (((const uint8_t *) _flags.bytes)[*flagIdx / 8] & (1 << (*flagIdx % 8)));

    (*flagIdx)++;

    if (!flag || depth == ceil(log2(_totalTransactions))) {
        NSData *hash = [_hashes hashAtOffset:(NSUInteger) ((*hashIdx) * CC_SHA256_DIGEST_LENGTH)];

        (*hashIdx)++;
        return leaf(hash, flag);
    }

    id left = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch];
    id right = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch];

    return branch(left, right);
}

- (NSUInteger)hash {
    if (_blockHash.length < sizeof(NSUInteger)) return [super hash];
    return *(const NSUInteger *) _blockHash.bytes;
}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[BTBlock class]]) {
        return NO;
    }
    BTBlock *item = (BTBlock *) object;
    return (self.blockNo == item.blockNo) && [self.blockHash isEqualToData:item.blockHash]
            && (self.blockVer == item.blockVer) && (self.blockBits == item.blockBits)
            && (self.blockNonce == item.blockNonce) && (self.blockTime == item.blockTime)
            && self.isMain == item.isMain;
}

- (NSData *)toDataWithHash {
    int size = (int) self.blockPrev.length + (int) self.blockRoot.length + 64 * 4 + 4;
    NSMutableData *d = [NSMutableData dataWithCapacity:(NSUInteger) size];
    [d appendUInt32:self.blockVer];
    [d appendData:self.blockPrev];
    [d appendData:self.blockRoot];
    [d appendUInt32:self.blockTime];
    [d appendUInt32:self.blockBits];
    [d appendUInt32:self.blockNonce];
    return d;
}

//- (BTBlockItem *)formatToBlockItem; {
//    BTBlockItem *blockItem = [BTBlockItem new];
//    blockItem.blockHash = self.blockHash;
//    blockItem.blockVer = self.blockVer;
//    blockItem.blockPrev = self.blockPrev;
//    blockItem.blockRoot = self.blockRoot;
//    blockItem.blockTime = self.blockTime;
//    blockItem.blockBits = self.blockBits;
//    blockItem.blockNonce = self.blockNonce;
//    blockItem.blockNo = self.blockNo;
//    blockItem.isMain = self.isMain;
//    return blockItem;
//}

//+ (instancetype)blockWithBlockItem:(BTBlockItem *)blockItem;{
//    return [[self alloc] initWithBlockItem:blockItem];
//}

//- (instancetype)initWithBlockItem:(BTBlockItem *) blockItem;{
//    if (! (self = [self init])) return nil;
//
//    _blockHash = blockItem.blockHash;
//    _blockVer = blockItem.blockVer;
//    _blockPrev = blockItem.blockPrev;
//    _blockRoot = blockItem.blockRoot;
//    _blockTime = blockItem.blockTime;
//    _blockBits = blockItem.blockBits;
//    _blockNonce = blockItem.blockNonce;
//    _blockNo = blockItem.blockNo;
//    _isMain = blockItem.isMain;
//
//    return self;
//}

- initWithBlockNo:(uint32_t)blockNo blockHash:(NSData *)blockHash blockRoot:(NSData *)blockRoot blockVer:(uint32_t)blockVer
        blockBits:(uint32_t)blockBits blockNonce:(uint32_t)blockNonce blockTime:(uint32_t)blockTime
        blockPrev:(NSData *)blockPrev isMain:(BOOL)isMain; {
    if (!(self = [self init])) return nil;

    _blockNo = blockNo;
    _blockHash = blockHash;
    _blockRoot = blockRoot;
    _blockVer = blockVer;
    _blockTime = blockTime;
    _blockBits = blockBits;
    _blockNonce = blockNonce;
    _blockPrev = blockPrev;
    _isMain = isMain;

    return self;
}

- (instancetype)initWithVersion:(uint32_t)version prevBlock:(NSData *)prevBlock merkleRoot:(NSData *)merkleRoot timestamp:(NSTimeInterval)timestamp target:(uint32_t)target nonce:(uint32_t)nonce height:(uint32_t)height {
    if (!(self = [self init])) {
        return nil;
    }
    _blockVer = version;
    _blockPrev = prevBlock;
    _blockRoot = merkleRoot;
    _blockTime = (uint32_t) timestamp;
    _blockBits = target;
    _blockNonce = nonce;
    _blockNo = height;
    _blockHash = [[self toDataWithHash] SHA256_2];

    return self;
}
@end
