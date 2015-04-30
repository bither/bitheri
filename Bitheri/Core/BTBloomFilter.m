//
//  BTBloomFilter.m
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

#import "BTBloomFilter.h"
#import "BTTx.h"
#import "BTOut.h"

#define BLOOM_MAX_HASH_FUNCS 50

// murmurHash3 (x86_32): http://code.google.com/p/smhasher/source/browse/trunk/MurmurHash3.cpp
static uint32_t murmurHash3(NSData *data, uint32_t seed) {
    static const uint32_t c1 = 0xcc9e2d51, c2 = 0x1b873593;
    uint32_t h1 = seed, k1 = 0, k2 = 0, blocks = ((uint32_t) data.length / 4) * 4;
    const uint8_t *b = data.bytes;

    for (NSUInteger i = 0; i < blocks; i += 4) {
        k1 = ((uint32_t) b[i] | ((uint32_t) b[i + 1] << 8) | ((uint32_t) b[i + 2] << 16) | ((uint32_t) b[i + 3] << 24)) * c1;
        k1 = ((k1 << 15) | (k1 >> 17)) * c2;
        h1 ^= k1;
        h1 = ((h1 << 13) | (h1 >> 19)) * 5 + 0xe6546b64;
    }

    switch (data.length & 3) {
        case 3:
            k2 ^= b[blocks + 2] << 16; // fall through
        case 2:
            k2 ^= b[blocks + 1] << 8; // fall through
        case 1:
            k2 = (k2 ^ b[blocks]) * c1;
            h1 ^= ((k2 << 15) | (k2 >> 17)) * c2;
    }

    h1 ^= data.length;
    h1 = (h1 ^ (h1 >> 16)) * 0x85ebca6b;
    h1 = (h1 ^ (h1 >> 13)) * 0xc2b2ae35;
    h1 ^= h1 >> 16;

    return h1;
}

// bloom filters are explained in BIP37: https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki
@interface BTBloomFilter ()

@property(nonatomic, strong) NSMutableData *filter;
@property(nonatomic, assign) uint32_t hashFuncs;

@end

@implementation BTBloomFilter

+ (instancetype)filterWithMessage:(NSData *)message {
    return [[self alloc] initWithMessage:message];
}

// a bloom filter that matches everything is useful if a full node wants to use the filtered block protocol, which
// doesn't send transactions with blocks if the receiving node already received the tx prior to its inclusion in the
// block, allowing a full node to operate while using about half the network traffic.
+ (instancetype)filterWithFullMatch {
    return [[self alloc] initWithFullMatch];
}

- (instancetype)initWithMessage:(NSData *)message {
    if (!(self = [self init])) return nil;

    NSUInteger off = 0;

    _filter = [NSMutableData dataWithData:[message dataAtOffset:0 length:&off]];
    _hashFuncs = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _tweak = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _flags = [message UInt8AtOffset:off];

    return self;
}

- (instancetype)initWithFullMatch {
    if (!(self = [self init])) return nil;

    _filter = [NSMutableData dataWithBytes:"\xFF" length:1];
    _hashFuncs = 0;
    _tweak = 0;
    _flags = BLOOM_UPDATE_NONE;

    return self;
}

- (instancetype)initWithFalsePositiveRate:(double)fpRate forElementCount:(NSUInteger)count tweak:(uint32_t)tweak
                                    flags:(uint8_t)flags {
    if (!(self = [self init])) return nil;

    NSUInteger length = (NSUInteger) ((-1.0 / pow(M_LN2, 2)) * count * log(fpRate) / 8.0);

    if (length > BLOOM_MAX_FILTER_LENGTH) length = BLOOM_MAX_FILTER_LENGTH;
    _filter = [NSMutableData dataWithLength:length < 1 ? 1 : length];
    _hashFuncs = (uint32_t) (((self.filter.length * 8.0) / count) * M_LN2);
    if (self.hashFuncs > BLOOM_MAX_HASH_FUNCS) _hashFuncs = BLOOM_MAX_HASH_FUNCS;
    _tweak = tweak;
    _flags = flags;

    return self;
}

- (uint32_t)hash:(NSData *)data hashNum:(uint32_t)hashNum {
    return murmurHash3(data, hashNum * 0xfba4c795 + self.tweak) % (self.filter.length * 8);
}

- (BOOL)containsData:(NSData *)data {
    const uint8_t *b = self.filter.bytes;

    for (uint32_t i = 0; i < self.hashFuncs; i++) {
        uint32_t idx = [self hash:data hashNum:i];

        if (!(b[idx >> 3] & (1 << (7 & idx)))) return NO;
    }

    return YES;
}

- (void)insertData:(NSData *)data {
    uint8_t *b = self.filter.mutableBytes;

    for (uint32_t i = 0; i < self.hashFuncs; i++) {
        uint32_t idx = [self hash:data hashNum:i];

        b[idx >> 3] |= (1 << (7 & idx));
    }

    _elementCount++;
}

- (void)updateWithTransaction:(BTTx *)tx {
    NSMutableData *d = [NSMutableData data];

    for (BTOut *out in tx.outs) {
        NSData *script = out.outScript;
        for (NSData *elem in [script scriptDataElements]) {
            if (![self containsData:elem]) continue;
            [d setData:tx.txHash];
            [d appendUInt32:out.outSn];
            [self insertData:d]; // update bloom filter with matched txout
            break;
        }
    }
}

- (double)falsePositiveRate {
    return pow(1 - pow(M_E, -1.0 * self.hashFuncs * self.elementCount / (self.filter.length * 8.0)), self.hashFuncs);
}

- (NSData *)toData {
    NSMutableData *d = [NSMutableData data];

    [d appendVarInt:self.length];
    [d appendData:self.filter];
    [d appendUInt32:self.hashFuncs];
    [d appendUInt32:self.tweak];
    [d appendUInt8:self.flags];

    return d;
}

- (NSUInteger)length {
    return self.filter.length;
}

@end
