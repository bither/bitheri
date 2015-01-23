//
//  BTBIP32Key.m
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
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
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

#import "BTBIP32Key.h"
#import "BTKey.h"
#import "NSString+Base58.h"
#import "NSMutableData+Bitcoin.h"
#import "NSData+Hash.h"
#import <CommonCrypto/CommonHMAC.h>
#import <openssl/ecdsa.h>
#import <openssl/obj_mac.h>

#define BIP32_HARDEN    0x80000000
#define BIP32_SEED_KEY "Bitcoin seed"
#define BIP32_XPRV     "\x04\x88\xAD\xE4"
#define BIP32_XPUB     "\x04\x88\xB2\x1E"

// BIP32 is a scheme for deriving chains of addresses from a seed value
// https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki

// Private child key derivation:
//
// To define CKD((kpar, cpar), i) -> (ki, ci):
//
// - Check whether the highest bit (0x80000000) of i is set:
//     - If 1, private derivation is used: let I = HMAC-SHA512(Key = cpar, Data = 0x00 || kpar || i)
//       [Note: The 0x00 pads the private key to make it 33 bytes long.]
//     - If 0, public derivation is used: let I = HMAC-SHA512(Key = cpar, Data = X(kpar*G) || i)
// - Split I = Il || Ir into two 32-byte sequences, Il and Ir.
// - ki = Il + kpar (mod n).
// - ci = Ir.
//
static void CKD(NSMutableData *k, NSMutableData *c, uint32_t i)
{
    BN_CTX *ctx = BN_CTX_new();

    BN_CTX_start(ctx);

    NSMutableData *I = [NSMutableData secureDataWithLength:CC_SHA512_DIGEST_LENGTH];
    NSMutableData *data = [NSMutableData secureDataWithCapacity:33 + sizeof(i)];
    BIGNUM *order = BN_CTX_get(ctx), *Ilbn = BN_CTX_get(ctx), *kbn = BN_CTX_get(ctx);
    EC_GROUP *group = EC_GROUP_new_by_curve_name(NID_secp256k1);

    if (i & BIP32_HARDEN) {
        data.length = 33 - k.length;
        [data appendData:k];
    }
    else [data setData:[[BTKey keyWithSecret:k compressed:YES] publicKey]];

    i = CFSwapInt32HostToBig(i);
    [data appendBytes:&i length:sizeof(i)];

    CCHmac(kCCHmacAlgSHA512, c.bytes, c.length, data.bytes, data.length, I.mutableBytes);

    BN_bin2bn(I.bytes, 32, Ilbn);
    BN_bin2bn(k.bytes, (int)k.length, kbn);
    EC_GROUP_get_order(group, order, ctx);

    BN_mod_add(kbn, Ilbn, kbn, order, ctx);

    k.length = 32;
    [k resetBytesInRange:NSMakeRange(0, 32)];
    BN_bn2bin(kbn, (unsigned char *)k.mutableBytes + 32 - BN_num_bytes(kbn));
    [c replaceBytesInRange:NSMakeRange(0, c.length) withBytes:(const unsigned char *)I.bytes + 32 length:32];

    EC_GROUP_free(group);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);
}

// Public child key derivation:
//
// To define CKD'((Kpar, cpar), i) -> (Ki, ci):
//
// - Check whether the highest bit (0x80000000) of i is set:
//     - If 1, return error
//     - If 0, let I = HMAC-SHA512(Key = cpar, Data = X(Kpar) || i)
// - Split I = Il || Ir into two 32-byte sequences, Il and Ir.
// - Ki = (Il + kpar)*G = Il*G + Kpar
// - ci = Ir.
//
static void CKDPrime(NSMutableData *K, NSMutableData *c, uint32_t i)
{
    if (i & BIP32_HARDEN) {
        @throw [NSException exceptionWithName:@"BTPrivateCKDException"
                                       reason:@"can't derive private child key from public parent key" userInfo:nil];
    }

    BN_CTX *ctx = BN_CTX_new();

    BN_CTX_start(ctx);

    NSMutableData *I = [NSMutableData secureDataWithLength:CC_SHA512_DIGEST_LENGTH];
    NSMutableData *data = [NSMutableData secureDataWithData:K];
    uint8_t form = POINT_CONVERSION_COMPRESSED;
    BIGNUM *Ilbn = BN_CTX_get(ctx);
    EC_GROUP *group = EC_GROUP_new_by_curve_name(NID_secp256k1);
    EC_POINT *pubKeyPoint = EC_POINT_new(group), *IlPoint = EC_POINT_new(group);

    i = CFSwapInt32HostToBig(i);
    [data appendBytes:&i length:sizeof(i)];

    CCHmac(kCCHmacAlgSHA512, c.bytes, c.length, data.bytes, data.length, I.mutableBytes);

    BN_bin2bn(I.bytes, 32, Ilbn);
    EC_GROUP_set_point_conversion_form(group, form);
    EC_POINT_oct2point(group, pubKeyPoint, K.bytes, K.length, ctx);

    EC_POINT_mul(group, IlPoint, Ilbn, NULL, NULL, ctx);
    EC_POINT_add(group, pubKeyPoint, IlPoint, pubKeyPoint, ctx);

    K.length = EC_POINT_point2oct(group, pubKeyPoint, form, NULL, 0, ctx);
    EC_POINT_point2oct(group, pubKeyPoint, form, K.mutableBytes, K.length, ctx);
    [c replaceBytesInRange:NSMakeRange(0, c.length) withBytes:(const unsigned char *)I.bytes + 32 length:32];

    EC_POINT_clear_free(IlPoint);
    EC_POINT_clear_free(pubKeyPoint);
    EC_GROUP_free(group);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);
}

// helper function for serializing BIP32 master public/private keys to standard export format
static NSString *serialize(uint8_t depth, uint32_t fingerprint, uint32_t child, NSData *chain, NSData *key)
{
    NSMutableData *d = [NSMutableData secureDataWithCapacity:14 + key.length + chain.length];

    fingerprint = CFSwapInt32HostToBig(fingerprint);
    child = CFSwapInt32HostToBig(child);

    [d appendBytes:key.length < 33 ? BIP32_XPRV : BIP32_XPUB length:4];
    [d appendBytes:&depth length:1];
    [d appendBytes:&fingerprint length:sizeof(fingerprint)];
    [d appendBytes:&child length:sizeof(child)];
    [d appendData:chain];
    if (key.length < 33) [d appendBytes:"\0" length:1];
    [d appendData:key];

    return [NSString base58checkWithData:d];
}

@interface BTBIP32Key()

@property (nonatomic, copy) NSData *chain;

@end

@implementation BTBIP32Key

- (BOOL)isPubKeyOnly {
    return _secret == nil;
}

+ (BTBIP32Key *)deriveChildKey:(uint) childNumber fromParent:(BTBIP32Key *)parent;{
    if (parent.isPubKeyOnly) {
        NSMutableData *pubKey = [NSMutableData dataWithData:[parent pubKey]];
        NSMutableData *chain = [NSMutableData dataWithData:[parent chain]];
        CKDPrime(pubKey, chain, childNumber);
        NSArray *path = [BTBIP32Key path:parent.path extend:childNumber];
        return [[BTBIP32Key alloc] initWithSecret:nil andPubKey:pubKey andChain:chain andPath:path];
    } else {
        NSMutableData *secret = [NSMutableData dataWithData:[parent secret]];
        NSMutableData *chain = [NSMutableData dataWithData:[parent chain]];
        CKD(secret, chain, childNumber);
        NSArray *path = [BTBIP32Key path:parent.path extend:childNumber];
        return [[BTBIP32Key alloc] initWithSecret:secret andPubKey:nil andChain:chain andPath:path];
    }
}

- (instancetype)initWithSeed:(NSData *)seed; {
    if (! (self = [super init])) return nil;

    NSMutableData *I = [NSMutableData secureDataWithLength:CC_SHA512_DIGEST_LENGTH];
    NSMutableData *secret = [NSMutableData secureDataWithCapacity:32];
    NSMutableData *chain = [NSMutableData secureDataWithCapacity:32];

    CCHmac(kCCHmacAlgSHA512, BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length, I.mutableBytes);

    [secret appendBytes:I.bytes length:32];
    [chain appendBytes:(const unsigned char *)I.bytes + 32 length:32];

    self.secret = secret;
    self.chain = chain;
    self.path = @[];

    return self;
}

- (instancetype)initWithMasterPubKey:(NSData *)masterPubKey; {
    if (! (self = [super init])) return nil;

    NSMutableData *pubKey = [NSMutableData secureDataWithCapacity:33];
    NSMutableData *chain = [NSMutableData secureDataWithCapacity:32];

    [pubKey appendBytes:masterPubKey.bytes length:33];
    [chain appendBytes:(const unsigned char *)masterPubKey.bytes + 33 length:32];

    self.pubKey = pubKey;
    self.chain = chain;
    self.path = @[];

    return self;
}

- (instancetype)initWithSecret:(NSData *)secret andPubKey:(NSData *)pubKey andChain:(NSData *)chain
                       andPath:(NSArray *)path; {
    if (! (self = [super init])) return nil;

    self.secret = secret;
    self.pubKey = pubKey;
    self.chain = chain;
    self.path = path;

    return self;
}

- (BTBIP32Key *)deriveSoftened:(uint)child; {
    return [BTBIP32Key deriveChildKey:child fromParent:self];
}

- (BTBIP32Key *)deriveHardened:(uint)child; {
    return [BTBIP32Key deriveChildKey:child | BIP32_HARDEN fromParent:self];
}

- (void)clearPrivateKey;{
    if (self.pubKey == nil) {
        self.pubKey = [BTKey keyWithSecret:self.secret compressed:YES].publicKey;
    }
    self.secret = nil;
}

- (NSData *)pubKey {
    if (_pubKey == nil) {
        _pubKey = [BTKey keyWithSecret:self.secret compressed:YES].publicKey;
    }
    return _pubKey;
}

- (NSString *)address
{
    NSData *hash = [self.pubKey hash160];

    if (! hash.length) return nil;

    NSMutableData *d = [NSMutableData secureDataWithCapacity:hash.length + 1];
#if BITCOIN_TESTNET
    uint8_t version = BITCOIN_PUBKEY_ADDRESS_TEST;
#else
    uint8_t version = BITCOIN_PUBKEY_ADDRESS;
#endif

    [d appendBytes:&version length:1];
    [d appendData:hash];

    return [NSString base58checkWithData:d];
}

+ (NSArray *)path:(NSArray *)path extend:(uint) child; {
    NSMutableArray *array = [NSMutableArray arrayWithArray:path];
    [array addObject:@(child)];
    return [NSArray arrayWithArray:array];
}

@end