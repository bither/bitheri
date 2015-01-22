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
    BTBIP32Key *key = [BTBIP32Key new];
    if (parent.isPubKeyOnly) {
        NSMutableData *pubKey = [NSMutableData dataWithData:[parent pubKey]];
        NSMutableData *chain = [NSMutableData dataWithData:[parent chain]];
        CKDPrime(pubKey, chain, childNumber);
        key.pubKey = pubKey;
        key.chain = chain;
    } else {
        NSMutableData *secret = [NSMutableData dataWithData:[parent secret]];
        NSMutableData *chain = [NSMutableData dataWithData:[parent chain]];
        CKD(secret, chain, childNumber);
        key.secret = secret;
        key.chain = chain;
    }
    return key;
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

//#pragma mark - BTKeySequence
//
//// master public key format is: 4 byte parent fingerprint || 32 byte chain code || 33 byte compressed public key
//// the values are taken from BIP32 account m/0'
//- (NSData *)masterPublicKeyFromSeed:(NSData *)seed
//{
//    if (! seed) return nil;
//
//    NSMutableData *mpk = [NSMutableData secureData];
//    NSMutableData *I = [NSMutableData secureDataWithLength:CC_SHA512_DIGEST_LENGTH];
//    NSMutableData *secret = [NSMutableData secureDataWithCapacity:32];
//    NSMutableData *chain = [NSMutableData secureDataWithCapacity:32];
//
//    CCHmac(kCCHmacAlgSHA512, BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length, I.mutableBytes);
//
//    [secret appendBytes:I.bytes length:32];
//    [chain appendBytes:(const unsigned char *)I.bytes + 32 length:32];
//    [mpk appendBytes:[[[BTKey keyWithSecret:secret compressed:YES] hash160] bytes] length:4];
//
//    CKD(secret, chain, 0 | BIP32_HARDEN); // account 0'
//
//    [mpk appendData:chain];
//    [mpk appendData:[[BTKey keyWithSecret:secret compressed:YES] publicKey]];
//
//    return mpk;
//}
//
//- (NSData *)publicKey:(unsigned)n internal:(BOOL)internal masterPublicKey:(NSData *)masterPublicKey
//{
//    if (masterPublicKey.length < 36) return nil;
//
//    NSMutableData *chain = [NSMutableData secureDataWithCapacity:32];
//    NSMutableData *pubKey = [NSMutableData secureDataWithCapacity:65];
//
//    [chain appendBytes:(const unsigned char *)masterPublicKey.bytes + 4 length:32];
//    [pubKey appendBytes:(const unsigned char *)masterPublicKey.bytes + 36 length:masterPublicKey.length - 36];
//
//    CKDPrime(pubKey, chain, internal ? 1 : 0); // internal or external chain
//    CKDPrime(pubKey, chain, n); // nth key in chain
//
//    return pubKey;
//}
//
//- (NSString *)privateKey:(unsigned)n internal:(BOOL)internal fromSeed:(NSData *)seed
//{
//    return seed ? [[self privateKeys:@[@(n)] internal:internal fromSeed:seed] lastObject] : nil;
//}
//
//- (NSArray *)privateKeys:(NSArray *)n internal:(BOOL)internal fromSeed:(NSData *)seed
//{
//    if (! seed || ! n) return nil;
//    if (n.count == 0) return @[];
//
//    NSMutableArray *a = [NSMutableArray arrayWithCapacity:n.count];
//    NSMutableData *I = [NSMutableData secureDataWithLength:CC_SHA512_DIGEST_LENGTH];
//    NSMutableData *secret = [NSMutableData secureDataWithCapacity:32];
//    NSMutableData *chain = [NSMutableData secureDataWithCapacity:32];
//    uint8_t version = BITCOIN_PRIVKEY;
//
//#if BITCOIN_TESTNET
//    version = BITCOIN_PRIVKEY_TEST;
//#endif
//
//    CCHmac(kCCHmacAlgSHA512, BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length, I.mutableBytes);
//
//    [secret appendBytes:I.bytes length:32];
//    [chain appendBytes:(const unsigned char *)I.bytes + 32 length:32];
//
//    CKD(secret, chain, 0 | BIP32_HARDEN); // account 0'
//    CKD(secret, chain, internal ? 1 : 0); // internal or external chain
//
//    for (NSNumber *i in n) {
//        NSMutableData *prvKey = [NSMutableData secureDataWithCapacity:34];
//        NSMutableData *s = [NSMutableData secureDataWithData:secret];
//        NSMutableData *c = [NSMutableData secureDataWithData:chain];
//
//        CKD(s, c, i.unsignedIntValue); // nth key in chain
//
//        [prvKey appendBytes:&version length:1];
//        [prvKey appendData:s];
//        [prvKey appendBytes:"\x01" length:1]; // specifies compressed pubkey format
//        [a addObject:[NSString base58checkWithData:prvKey]];
//    }
//
//    return a;
//}
//
//#pragma mark - serializations
//
//- (NSString *)serializedPrivateMasterFromSeed:(NSData *)seed
//{
//    if (! seed) return nil;
//
//    NSMutableData *I = [NSMutableData secureDataWithLength:CC_SHA512_DIGEST_LENGTH];
//
//    CCHmac(kCCHmacAlgSHA512, BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length, I.mutableBytes);
//
//    NSData *secret = [NSData dataWithBytesNoCopy:I.mutableBytes length:32 freeWhenDone:NO];
//    NSData *chain = [NSData dataWithBytesNoCopy:(unsigned char *)I.mutableBytes + 32 length:32 freeWhenDone:NO];
//
//    return serialize(0, 0, 0, chain, secret);
//}
//
//- (NSString *)serializedMasterPublicKey:(NSData *)masterPublicKey
//{
//    if (masterPublicKey.length < 36) return nil;
//
//    uint32_t fingerprint = CFSwapInt32BigToHost(*(const uint32_t *)masterPublicKey.bytes);
//    NSData *chain = [NSData dataWithBytesNoCopy:(unsigned char *)masterPublicKey.bytes + 4 length:32 freeWhenDone:NO];
//    NSData *pubKey = [NSData dataWithBytesNoCopy:(unsigned char *)masterPublicKey.bytes + 36
//                                          length:masterPublicKey.length - 36 freeWhenDone:NO];
//
//    return serialize(1, fingerprint, 0 | BIP32_HARDEN, chain, pubKey);
//}

- (NSArray *)getAddresses:(NSData *)seed;{
    NSMutableData *I = [NSMutableData secureDataWithLength:CC_SHA512_DIGEST_LENGTH];
    NSMutableData *secret = [NSMutableData secureDataWithCapacity:32];
    NSMutableData *chain = [NSMutableData secureDataWithCapacity:32];

    CCHmac(kCCHmacAlgSHA512, BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length, I.mutableBytes);

    [secret appendBytes:I.bytes length:32];
    [chain appendBytes:(const unsigned char *)I.bytes + 32 length:32];

    CKD(secret, chain, 44 | BIP32_HARDEN);
    CKD(secret, chain, 0 | BIP32_HARDEN);
    CKD(secret, chain, 0 | BIP32_HARDEN);
    CKD(secret, chain, 0);

    NSMutableArray *result = [NSMutableArray new];
    for (int i = 0; i < 20; i++) {
        NSMutableData *s = [NSMutableData dataWithData:[secret copy]];
        NSMutableData *c = [NSMutableData dataWithData:[chain copy]];
        CKD(s, c, i);
        [result addObject:[[BTKey keyWithSecret:s compressed:YES] address]];
//        XCTAssertTrue([[[BTKey keyWithSecret:s compressed:YES] address] isEqualToString:addresses[i]]);
    }
    return result;
}

@end