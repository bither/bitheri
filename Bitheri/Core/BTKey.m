//
//  BTKey.m
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

#import "BTKey.h"
#import "NSString+Base58.h"
#import "NSData+Hash.h"
#import "NSMutableData+Bitcoin.h"
#import <CommonCrypto/CommonHMAC.h>
#import <openssl/ecdsa.h>
#import <openssl/obj_mac.h>
#import "BTSettings.h"
#import <openssl/evp.h>
#import "BTKeyParameter.h"
#import "NSData+Bitcoin.h"
#import "BTUtils.h"

// HMAC-SHA256 DRBG, using no prediction resistance or personalization string and outputing 256bits
static NSData *hmac_drbg(NSData *entropy, NSData *nonce) {
    NSMutableData *V = [NSMutableData
            secureDataWithCapacity:CC_SHA256_DIGEST_LENGTH + 1 + entropy.length + nonce.length],
            *K = [NSMutableData secureDataWithCapacity:CC_SHA256_DIGEST_LENGTH],
            *T = [NSMutableData secureDataWithLength:CC_SHA256_DIGEST_LENGTH];

    V.length = CC_SHA256_DIGEST_LENGTH;
    memset(V.mutableBytes, 0x01, V.length); // V = 0x01 0x01 0x01 ... 0x01
    K.length = CC_SHA256_DIGEST_LENGTH;     // K = 0x00 0x00 0x00 ... 0x00
    [V appendBytes:"\0" length:1];
    [V appendBytes:entropy.bytes length:entropy.length];
    [V appendBytes:nonce.bytes length:nonce.length];
    CCHmac(kCCHmacAlgSHA256, K.bytes, K.length, V.bytes, V.length, K.mutableBytes); // K = HMAC_K(V || 0x00 || seed)
    V.length = CC_SHA256_DIGEST_LENGTH;
    CCHmac(kCCHmacAlgSHA256, K.bytes, K.length, V.bytes, V.length, V.mutableBytes); // V = HMAC_K(V)
    [V appendBytes:"\x01" length:1];
    [V appendBytes:entropy.bytes length:entropy.length];
    [V appendBytes:nonce.bytes length:nonce.length];
    CCHmac(kCCHmacAlgSHA256, K.bytes, K.length, V.bytes, V.length, K.mutableBytes); // K = HMAC_K(V || 0x01 || seed)
    V.length = CC_SHA256_DIGEST_LENGTH;
    CCHmac(kCCHmacAlgSHA256, K.bytes, K.length, V.bytes, V.length, V.mutableBytes); // V = HMAC_K(V)
    BN_CTX *ctx = BN_CTX_new();
    BN_CTX_start(ctx);
    BIGNUM n;
    BN_init(&n);
    while (YES) {
        CCHmac(kCCHmacAlgSHA256, K.bytes, K.length, V.bytes, V.length, T.mutableBytes); // T = HMAC_K(V)
        BN_clear(&n);
        BN_bin2bn(T.bytes, CC_SHA256_DIGEST_LENGTH, &n);
        if (BN_cmp([BTKeyParameter minN], &n) < 0 && BN_cmp([BTKeyParameter maxN], &n) > 0) {
            BN_clear_free(&n);
            if (ctx) BN_CTX_end(ctx);
            if (ctx) BN_CTX_free(ctx);
            return [T subdataWithRange:NSMakeRange(0, CC_SHA256_DIGEST_LENGTH)];
        }

        if ([T length] <= CC_SHA256_DIGEST_LENGTH) {
            [T appendBytes:"\x00" length:1];
        }

        CCHmac(kCCHmacAlgSHA256, K.bytes, K.length, T.bytes, T.length, K.mutableBytes);
        CCHmac(kCCHmacAlgSHA256, K.bytes, K.length, T.bytes, T.length - 1, V.mutableBytes);
    }
    return nil;
}

// Perform ECDSA key recovery (see SEC1 4.1.6) for curves over (mod p)-fields
// recid selects which key is recovered
// if check is non-zero, additional checks are performed
int ECDSA_SIG_recover_key_GFp(EC_KEY *eckey, ECDSA_SIG *ecsig, const unsigned char *msg,
        int msglen, int recid, int check) {
    if (!eckey) return 0;

    int ret = 0;
    BN_CTX *ctx = NULL;

    BIGNUM *x = NULL;
    BIGNUM *e = NULL;
    BIGNUM *order = NULL;
    BIGNUM *sor = NULL;
    BIGNUM *eor = NULL;
    BIGNUM *field = NULL;
    EC_POINT *R = NULL;
    EC_POINT *O = NULL;
    EC_POINT *Q = NULL;
    BIGNUM *rr = NULL;
    BIGNUM *zero = NULL;
    int n = 0;
    int i = recid / 2;

    const EC_GROUP *group = EC_KEY_get0_group(eckey);
    if ((ctx = BN_CTX_new()) == NULL) {
        ret = -1;
        goto err;
    }
    BN_CTX_start(ctx);
    order = BN_CTX_get(ctx);
    if (!EC_GROUP_get_order(group, order, ctx)) {
        ret = -2;
        goto err;
    }
    x = BN_CTX_get(ctx);
    if (!BN_copy(x, order)) {
        ret = -1;
        goto err;
    }
    if (!BN_mul_word(x, i)) {
        ret = -1;
        goto err;
    }
    if (!BN_add(x, x, ecsig->r)) {
        ret = -1;
        goto err;
    }
    field = BN_CTX_get(ctx);
    if (!EC_GROUP_get_curve_GFp(group, field, NULL, NULL, ctx)) {
        ret = -2;
        goto err;
    }
    if (BN_cmp(x, field) >= 0) {
        ret = 0;
        goto err;
    }
    if ((R = EC_POINT_new(group)) == NULL) {
        ret = -2;
        goto err;
    }
    if (!EC_POINT_set_compressed_coordinates_GFp(group, R, x, recid % 2, ctx)) {
        ret = 0;
        goto err;
    }
    if (check) {
        if ((O = EC_POINT_new(group)) == NULL) {
            ret = -2;
            goto err;
        }
        if (!EC_POINT_mul(group, O, NULL, R, order, ctx)) {
            ret = -2;
            goto err;
        }
        if (!EC_POINT_is_at_infinity(group, O)) {
            ret = 0;
            goto err;
        }
    }
    if ((Q = EC_POINT_new(group)) == NULL) {
        ret = -2;
        goto err;
    }
    n = EC_GROUP_get_degree(group);
    e = BN_CTX_get(ctx);
    if (!BN_bin2bn(msg, msglen, e)) {
        ret = -1;
        goto err;
    }
    if (8 * msglen > n) BN_rshift(e, e, 8 - (n & 7));
    zero = BN_CTX_get(ctx);
    if (!BN_zero(zero)) {
        ret = -1;
        goto err;
    }
    if (!BN_mod_sub(e, zero, e, order, ctx)) {
        ret = -1;
        goto err;
    }
    rr = BN_CTX_get(ctx);
    if (!BN_mod_inverse(rr, ecsig->r, order, ctx)) {
        ret = -1;
        goto err;
    }
    sor = BN_CTX_get(ctx);
    if (!BN_mod_mul(sor, ecsig->s, rr, order, ctx)) {
        ret = -1;
        goto err;
    }
    eor = BN_CTX_get(ctx);
    if (!BN_mod_mul(eor, e, rr, order, ctx)) {
        ret = -1;
        goto err;
    }
    if (!EC_POINT_mul(group, Q, eor, R, sor, ctx)) {
        ret = -2;
        goto err;
    }
    if (!EC_KEY_set_public_key(eckey, Q)) {
        ret = -2;
        goto err;
    }

    ret = 1;

    err:
    if (ctx) {
        BN_CTX_end(ctx);
        BN_CTX_free(ctx);
    }
    if (R != NULL) EC_POINT_free(R);
    if (O != NULL) EC_POINT_free(O);
    if (Q != NULL) EC_POINT_free(Q);
    return ret;
}

@interface BTKey ()

@property(nonatomic, assign) EC_KEY *key;
@property(nonatomic, copy) NSData *secret;


@end

@implementation BTKey

+ (instancetype)keyWithPrivateKey:(NSString *)privateKey {
    return [[self alloc] initWithPrivateKey:privateKey];
}

+ (instancetype)keyWithSecret:(NSData *)secret compressed:(BOOL)compressed {
    return [[self alloc] initWithSecret:secret compressed:compressed];
}

+ (instancetype)keyWithPublicKey:(NSData *)publicKey {
    return [[self alloc] initWithPublicKey:publicKey];
}

- (instancetype)init {
    if (!(self = [super init])) return nil;

    _key = EC_KEY_new_by_curve_name(NID_secp256k1);

    return _key ? self : nil;
}

- (void)dealloc {
    NSMutableData *emptySecret = [NSMutableData new];
    for (NSUInteger i = 0; i < 32; i++) {
        [emptySecret appendUInt8:0];
    }
    [self setSecret:emptySecret compressed:YES];
    _secret = nil;
    self.privateKey = nil;
    self.publicKey = nil;
    if (_key) EC_KEY_free(_key);
}

- (instancetype)initWithSecret:(NSData *)secret compressed:(BOOL)compressed {
    if (secret.length != 32) return nil;
    BIGNUM *n = BN_bin2bn(secret.bytes, 32, NULL);
    if (BN_cmp([BTKeyParameter minN], n) >= 0 || BN_cmp([BTKeyParameter maxN], n) <= 0) {
        BN_clear_free(n);
        return nil;
    } else {
        BN_clear_free(n);
    }

    if (!(self = [self init])) return nil;

    [self setSecret:secret compressed:compressed];

    return self;
}

- (instancetype)initWithPrivateKey:(NSString *)privateKey {
    if (!(self = [self init])) return nil;

    self.privateKey = privateKey;

    return self;
}

- (instancetype)initWithPublicKey:(NSData *)publicKey {
    if (!(self = [self init])) return nil;

    self.publicKey = publicKey;

    return self;
}

- (void)setSecret:(NSData *)secret compressed:(BOOL)compressed {
    if (secret.length != 32 || !_key) return;

    BN_CTX *ctx = BN_CTX_new();
    BIGNUM priv;
    const EC_GROUP *group = EC_KEY_get0_group(_key);
    EC_POINT *pub = EC_POINT_new(group);

    if (ctx) BN_CTX_start(ctx);
    BN_init(&priv);

    if (pub && ctx) {
        BN_bin2bn(secret.bytes, 32, &priv);

        if (EC_POINT_mul(group, pub, &priv, NULL, NULL, ctx)) {
            EC_KEY_set_private_key(_key, &priv);
            EC_KEY_set_public_key(_key, pub);
            EC_KEY_set_conv_form(_key, compressed ? POINT_CONVERSION_COMPRESSED : POINT_CONVERSION_UNCOMPRESSED);
        }
    }

    if (pub) EC_POINT_free(pub);
    BN_clear_free(&priv);
    if (ctx) BN_CTX_end(ctx);
    if (ctx) BN_CTX_free(ctx);
    self.secret = secret;
    self.compressed = compressed;
}

- (void)setPrivateKey:(NSString *)privateKey {
    // mini private key format
    if ((privateKey.length == 30 || privateKey.length == 22) && [privateKey characterAtIndex:0] == 'S') {
        if (![privateKey isValidBitcoinPrivateKey]) return;

        [self setSecret:[CFBridgingRelease(CFStringCreateExternalRepresentation(SecureAllocator(),
                (__bridge CFStringRef) privateKey, kCFStringEncodingUTF8, 0)) SHA256] compressed:NO];
        return;
    }

    NSData *d = privateKey.base58checkToData;
#if BITCOIN_TESTNET
    uint8_t version = BITCOIN_PRIVKEY_TEST;
#else
    uint8_t version = BITCOIN_PRIVKEY;
#endif

    if (!d || d.length == 28) d = privateKey.base58ToData;
    if (!d) d = privateKey.hexToData;

    if ((d.length == 33 || d.length == 34) && *(const unsigned char *) d.bytes == version) {
        [self setSecret:[NSData dataWithBytesNoCopy:(unsigned char *) d.bytes + 1 length:32 freeWhenDone:NO]
             compressed:d.length == 34];
    }
    else if (d.length == 32) [self setSecret:d compressed:NO];
}

- (NSString *)privateKey {
    if (!EC_KEY_check_key(_key)) return nil;

    const BIGNUM *priv = EC_KEY_get0_private_key(_key);
    NSMutableData *d = [NSMutableData secureDataWithCapacity:34];
#if BITCOIN_TESTNET
    uint8_t version = BITCOIN_PRIVKEY_TEST;
#else
    uint8_t version = BITCOIN_PRIVKEY;
#endif

    [d appendBytes:&version length:1];
    d.length = 33;
    BN_bn2bin(priv, (unsigned char *) d.mutableBytes + d.length - BN_num_bytes(priv));
    if (EC_KEY_get_conv_form(_key) == POINT_CONVERSION_COMPRESSED) [d appendBytes:"\x01" length:1];

    return [NSString base58checkWithData:d];
}

- (void)setPublicKey:(NSData *)publicKey {
    const unsigned char *bytes = publicKey.bytes;

    o2i_ECPublicKey(&_key, &bytes, publicKey.length);
}

- (NSData *)publicKey {
    if (!EC_KEY_check_key(_key)) return nil;

    size_t l = (size_t) i2o_ECPublicKey(_key, NULL);
    NSMutableData *pubKey = [NSMutableData secureDataWithLength:l];
    unsigned char *bytes = pubKey.mutableBytes;

    if (i2o_ECPublicKey(_key, &bytes) != l) return nil;

    return pubKey;
}

- (NSData *)hash160 {
    return [[self publicKey] hash160];
}

- (NSString *)address {
    NSData *hash = [self hash160];

    if (!hash.length) return nil;

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

- (NSData *)sign:(NSData *)d {
    if (d.length != CC_SHA256_DIGEST_LENGTH) {
        DDLogDebug(@"%s:%d: %s: Only 256 bit hashes can be signed", __FILE__, __LINE__, __func__);
        return nil;
    }

    BN_CTX *ctx = BN_CTX_new();
    BIGNUM order, halforder, k, r;
    const BIGNUM *priv = EC_KEY_get0_private_key(_key);
    const EC_GROUP *group = EC_KEY_get0_group(_key);
    EC_POINT *p = EC_POINT_new(group);
    NSMutableData *sig = nil, *entropy = [NSMutableData secureDataWithLength:32];
    unsigned char *b;

    BN_CTX_start(ctx);
    BN_init(&order);
    BN_init(&halforder);
    BN_init(&k);
    BN_init(&r);
    EC_GROUP_get_order(group, &order, ctx);
    BN_rshift1(&halforder, &order);

    // generate k deterministicly per RFC6979: https://tools.ietf.org/html/rfc6979
    BN_bn2bin(priv, (unsigned char *) entropy.mutableBytes + entropy.length - BN_num_bytes(priv));
    BN_bin2bn(hmac_drbg(entropy, d).bytes, CC_SHA256_DIGEST_LENGTH, &k);

    EC_POINT_mul(group, p, &k, NULL, NULL, ctx); // compute r, the x-coordinate of generator*k
    EC_POINT_get_affine_coordinates_GFp(group, p, &r, NULL, ctx);

    BN_mod_inverse(&k, &k, &order, ctx); // compute the inverse of k

    ECDSA_SIG *s = ECDSA_do_sign_ex(d.bytes, (int) d.length, &k, &r, _key);

    if (s) {
        // enforce low s values, negate the value (modulo the order) if above order/2.
        if (BN_cmp(s->s, &halforder) > 0) BN_sub(s->s, &order, s->s);

        sig = [NSMutableData dataWithLength:(NSUInteger) ECDSA_size(_key)];
        b = sig.mutableBytes;
        sig.length = (NSUInteger) i2d_ECDSA_SIG(s, &b);
        ECDSA_SIG_free(s);
    }

    EC_POINT_clear_free(p);
    BN_clear_free(&r);
    BN_clear_free(&k);
    BN_free(&halforder);
    BN_free(&order);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);

    return sig;
}

- (BOOL)verify:(NSData *)d signature:(NSData *)sig {
    // -1 = error, 0 = bad sig, 1 = good
    return ECDSA_verify(0, d.bytes, (int) d.length, sig.bytes, (int) sig.length, _key) == 1;
}

- (uint8_t)getKeyFlag {
    uint8_t flag = 0;
    if (self.compressed) {
        flag = flag + IS_COMPRESSED_FLAG;
    }
    if (self.isFromXRandom) {
        flag = flag + IS_FROMXRANDOM_FLAG;
    }
    return flag;
}

+ (NSData *)getRFromSignature:(NSData *)sig; {
    NSMutableData *data = [NSMutableData dataWithData:sig];
    unsigned char *b;
    b = data.mutableBytes;
    const unsigned char **pp = &b;
    ECDSA_SIG *s = d2i_ECDSA_SIG(NULL, pp, data.length);
    NSMutableData *d = [NSMutableData secureDataWithLength:200];
    unsigned char *b2 = d.mutableBytes;
    int len = BN_bn2bin(s->r, b2);
    ECDSA_SIG_free(s);
    return [d subdataWithRange:NSMakeRange(0, len)];
}

+ (NSData *)bn2bin:(BIGNUM)num andLength:(int)length; {
    NSMutableData *data = [NSMutableData new];
    data.length = (NSUInteger) length;
    BN_bn2bin(&num, (unsigned char *) data.mutableBytes + data.length - BN_num_bytes(&num));
    return data;
}

+ (NSData *)pubKey:(EC_KEY *)key; {
    if (!EC_KEY_check_key(key)) return nil;

    size_t l = (size_t) i2o_ECPublicKey(key, NULL);
    NSMutableData *pubKey = [NSMutableData secureDataWithLength:l];
    unsigned char *bytes = pubKey.mutableBytes;

    if (i2o_ECPublicKey(key, &bytes) != l) return nil;
    return pubKey;
}

- (NSString *)signMessage:(NSString *)message; {
    NSData *d = [[BTUtils formatMessageForSigning:message] SHA256_2];
    return [[self signHash:d] base64EncodedStringWithOptions:0];
}

- (NSData *)signHash:(NSData *)hash {
    ECDSA_SIG *sig = [self _sign:hash];
    int recId = -1;
    for (int i = 0; i < 4; i++) {
        EC_KEY *k = EC_KEY_new_by_curve_name(NID_secp256k1);
        int res = ECDSA_SIG_recover_key_GFp(k, sig, hash.bytes, hash.length, i, 1);
        if (res == 0)
            continue;
        EC_KEY_set_conv_form(k, self.compressed ? POINT_CONVERSION_COMPRESSED : POINT_CONVERSION_UNCOMPRESSED);
        BOOL isEqual = [self.publicKey isEqualToData:[BTKey pubKey:k]];
        EC_KEY_free(k);
        if (isEqual) {
            recId = i;
            break;
        }
    }
    if (recId == -1)
        return nil;
    uint8_t headerByte = (uint8_t) (recId + 27 + (self.compressed ? 4 : 0));
    NSMutableData *sigData = [NSMutableData secureDataWithCapacity:65];
    [sigData appendUInt8:headerByte];
    NSData *r = [BTKey bn2bin:*(sig->r) andLength:32];
    [sigData appendBytes:r.bytes length:r.length];
    NSData *s = [BTKey bn2bin:*(sig->s) andLength:32];
    [sigData appendBytes:s.bytes length:s.length];
    ECDSA_SIG_free(sig);
    return sigData;
}

- (BOOL)verifyMessage:(NSString *)message andSignatureBase64:(NSString *)signatureBase64; {
    BTKey *key = [BTKey signedMessageToKey:message andSignatureBase64:signatureBase64];
    if (key != nil && [self publicKey] != nil && [key publicKey] != nil) {
        return [[self publicKey] isEqualToData:[key publicKey]];
    } else {
        return NO;
    }
}

+ (BTKey *)signedMessageToKey:(NSString *)message andSignatureBase64:(NSString *)signatureBase64; {
    NSData *sigData = [[NSData alloc] initWithBase64EncodedString:signatureBase64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if ([sigData length] < 65) {
        return nil;
    }
    int header = [sigData UInt8AtOffset:0] & 0xFF;
    if (header < 27 || header > 34) {
        return nil;
    }
    ECDSA_SIG *sig = ECDSA_SIG_new();
    BN_bin2bn(sigData.bytes + 1, 32, sig->r);
    BN_bin2bn(sigData.bytes + 33, 32, sig->s);
    NSData *messageHash = [[BTUtils formatMessageForSigning:message] SHA256_2];
    BOOL compressed = false;
    if (header >= 31) {
        compressed = true;
        header -= 4;
    }
    int recId = header - 27;
    BTKey *key = [BTKey recoverFromSignatureWith:recId andSig:sig andMessageHash:messageHash andCompressed:compressed];
    ECDSA_SIG_free(sig);
    return key;
}

+ (BTKey *)recoverFromSignatureWith:(int)recId andSig:(ECDSA_SIG *)sig andMessageHash:(NSData *)messageHash andCompressed:(BOOL)compressed; {
    EC_KEY *eckey = EC_KEY_new_by_curve_name(NID_secp256k1);
    int res = ECDSA_SIG_recover_key_GFp(eckey, sig, messageHash.bytes, messageHash.length, recId, 1);
    if (res != 0) {
        EC_KEY_set_conv_form(eckey, compressed ? POINT_CONVERSION_COMPRESSED : POINT_CONVERSION_UNCOMPRESSED);
        BTKey *key = [[BTKey alloc] initWithPublicKey:[BTKey pubKey:eckey]];
        if (eckey != nil)
            EC_KEY_free(eckey);
        return key;
    } else {
        if (eckey != nil)
            EC_KEY_free(eckey);
        return nil;
    }
}

- (ECDSA_SIG *)_sign:(NSData *)d; {
    if (d.length != CC_SHA256_DIGEST_LENGTH) {
        DDLogDebug(@"%s:%d: %s: Only 256 bit hashes can be signed", __FILE__, __LINE__, __func__);
        return nil;
    }

    BN_CTX *ctx = BN_CTX_new();
    BIGNUM order, halforder, k, r;
    const BIGNUM *priv = EC_KEY_get0_private_key(_key);
    const EC_GROUP *group = EC_KEY_get0_group(_key);
    EC_POINT *p = EC_POINT_new(group);
    NSMutableData *sig = nil, *entropy = [NSMutableData secureDataWithLength:32];
    unsigned char *b;

    BN_CTX_start(ctx);
    BN_init(&order);
    BN_init(&halforder);
    BN_init(&k);
    BN_init(&r);
    EC_GROUP_get_order(group, &order, ctx);
    BN_rshift1(&halforder, &order);

    // generate k deterministicly per RFC6979: https://tools.ietf.org/html/rfc6979
    BN_bn2bin(priv, (unsigned char *) entropy.mutableBytes + entropy.length - BN_num_bytes(priv));
    BN_bin2bn(hmac_drbg(entropy, d).bytes, CC_SHA256_DIGEST_LENGTH, &k);

    EC_POINT_mul(group, p, &k, NULL, NULL, ctx); // compute r, the x-coordinate of generator*k
    EC_POINT_get_affine_coordinates_GFp(group, p, &r, NULL, ctx);

    BN_mod_inverse(&k, &k, &order, ctx); // compute the inverse of k

    ECDSA_SIG *s = ECDSA_do_sign_ex(d.bytes, (int) d.length, &k, &r, _key);

    if (s) {
        // enforce low s values, negate the value (modulo the order) if above order/2.
        if (BN_cmp(s->s, &halforder) > 0) BN_sub(s->s, &order, s->s);

//        sig = [NSMutableData dataWithLength:(NSUInteger) ECDSA_size(_key)];
//        b = sig.mutableBytes;
//        sig.length = (NSUInteger) i2d_ECDSA_SIG(s, &b);
//        ECDSA_SIG_free(s);
    }

    EC_POINT_clear_free(p);
    BN_clear_free(&r);
    BN_clear_free(&k);
    BN_free(&halforder);
    BN_free(&order);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);

    return s;
}


@end
