//
//  NSString+Base58.m
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

#import "NSString+Base58.h"
#import "NSData+Hash.h"
#import "NSMutableData+Bitcoin.h"
#import <openssl/bn.h>

#define SCRIPT_SUFFIX "\x88\xAC" // OP_EQUALVERIFY OP_CHECKSIG

static const char base58chars[] = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
static const char encodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static void *secureAllocate(CFIndex allocSize, CFOptionFlags hint, void *info) {
    void *ptr = CFAllocatorAllocate(kCFAllocatorDefault, sizeof(CFIndex) + allocSize, hint);

    if (ptr) { // we need to keep track of the size of the allocation so it can be cleansed before deallocation
        *(CFIndex *) ptr = allocSize;
        return (CFIndex *) ptr + 1;
    }
    else return NULL;
}

static void secureDeallocate(void *ptr, void *info) {
    CFIndex size = *((CFIndex *) ptr - 1);

    if (size) {
        OPENSSL_cleanse(ptr, size);
        CFAllocatorDeallocate(kCFAllocatorDefault, (CFIndex *) ptr - 1);
    }
}

static void *secureReallocate(void *ptr, CFIndex newsize, CFOptionFlags hint, void *info) {
    // There's no way to tell ahead of time if the original memory will be deallocted even if the new size is smaller
    // than the old size, so just cleanse and deallocate every time.
    void *newptr = secureAllocate(newsize, hint, info);
    CFIndex size = *((CFIndex *) ptr - 1);

    if (newptr) {
        if (size) {
            memcpy(newptr, ptr, size < newsize ? size : newsize);
            secureDeallocate(ptr, info);
        }

        return newptr;
    }
    else return NULL;
}

// Since iOS does not page memory to storage, all we need to do is cleanse allocated memory prior to deallocation.
CFAllocatorRef SecureAllocator() {
    static CFAllocatorRef alloc = NULL;
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^{
        CFAllocatorContext context;

        context.version = 0;
        CFAllocatorGetContext(kCFAllocatorDefault, &context);
        context.allocate = secureAllocate;
        context.reallocate = secureReallocate;
        context.deallocate = secureDeallocate;

        alloc = CFAllocatorCreate(kCFAllocatorDefault, &context);
    });

    return alloc;
}

@implementation NSString (Base58)

+ (NSString *)base58WithData:(NSData *)d {
    NSUInteger i = d.length * 138 / 100 + 2;
    char s[i];
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM base, x, r;

    BN_CTX_start(ctx);
    BN_init(&base);
    BN_init(&x);
    BN_init(&r);
    BN_set_word(&base, 58);
    BN_bin2bn(d.bytes, (int) d.length, &x);
    s[--i] = '\0';

    while (!BN_is_zero(&x)) {
        BN_div(&x, &r, &x, &base, ctx);
        s[--i] = base58chars[BN_get_word(&r)];
    }

    for (NSUInteger j = 0; j < d.length && *((const uint8_t *) d.bytes + j) == 0; j++) {
        s[--i] = base58chars[0];
    }

    BN_clear_free(&r);
    BN_clear_free(&x);
    BN_free(&base);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);

    NSString *ret = CFBridgingRelease(CFStringCreateWithCString(SecureAllocator(), &s[i], kCFStringEncodingUTF8));

    OPENSSL_cleanse(&s[0], d.length * 138 / 100 + 2);
    return ret;
}

+ (NSString *)base58checkWithData:(NSData *)d {
    NSMutableData *data = [NSMutableData secureDataWithData:d];

    [data appendBytes:d.SHA256_2.bytes length:4];

    return [self base58WithData:data];
}

+(BOOL)validAddressPubkey:(u_int8_t)pubkey {
    if(pubkey == BITCOIN_PUBKEY_ADDRESS || pubkey == BITCOIN_GOLD_PUBKEY_ADDRESS ||
       pubkey == BITCOIN_WORLD_PUBKEY_ADDRESS || pubkey == BITCOIN_FAITH_PUBKEY_ADDRESS ||
       pubkey == BITCOIN_PAY_PUBKEY_ADDRESS) {
        return true;
    }
    return false;
}

+(BOOL)validAddressScript:(u_int8_t)script {
    if(script == BITCOIN_SCRIPT_ADDRESS || script == BITCOIN_GOLD_SCRIPT_ADDRESS ||
       script == BITCOIN_WORLD_SCRIPT_ADDRESS || script == BITCOIN_FAITH_SCRIPT_ADDRESS ||
       script == BITCOIN_PAY_SCRIPT_ADDRESS) {
        return true;
    }
    return false;
}

- (NSData *)base58ToData {
    NSMutableData *d = [NSMutableData secureDataWithCapacity:self.length * 138 / 100 + 1];
    unsigned int b;
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM base, x, y;

    BN_CTX_start(ctx);
    BN_init(&base);
    BN_init(&x);
    BN_init(&y);
    BN_set_word(&base, 58);
    BN_zero(&x);

    for (NSUInteger i = 0; i < self.length && [self characterAtIndex:i] == base58chars[0]; i++) {
        [d appendBytes:"\0" length:1];
    }

    for (NSUInteger i = 0; i < self.length; i++) {
        b = [self characterAtIndex:i];

        switch (b) {
            case '1':
            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
                b -= '1';
                break;
            case 'A':
            case 'B':
            case 'C':
            case 'D':
            case 'E':
            case 'F':
            case 'G':
            case 'H':
                b += 9 - 'A';
                break;
            case 'J':
            case 'K':
            case 'L':
            case 'M':
            case 'N':
                b += 17 - 'J';
                break;
            case 'P':
            case 'Q':
            case 'R':
            case 'S':
            case 'T':
            case 'U':
            case 'V':
            case 'W':
            case 'X':
            case 'Y':
            case 'Z':
                b += 22 - 'P';
                break;
            case 'a':
            case 'b':
            case 'c':
            case 'd':
            case 'e':
            case 'f':
            case 'g':
            case 'h':
            case 'i':
            case 'j':
            case 'k':
                b += 33 - 'a';
                break;
            case 'm':
            case 'n':
            case 'o':
            case 'p':
            case 'q':
            case 'r':
            case 's':
            case 't':
            case 'u':
            case 'v':
            case 'w':
            case 'x':
            case 'y':
            case 'z':
                b += 44 - 'm';
                break;
            case ' ':
                continue;
            default:
                goto breakout;
        }

        BN_mul(&x, &x, &base, ctx);
        BN_set_word(&y, b);
        BN_add(&x, &x, &y);
    }

    breakout:
    d.length += BN_num_bytes(&x);
    BN_bn2bin(&x, (unsigned char *) d.mutableBytes + d.length - BN_num_bytes(&x));

    OPENSSL_cleanse(&b, sizeof(b));
    BN_clear_free(&y);
    BN_clear_free(&x);
    BN_free(&base);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);

    return d;
}

+ (NSString *)hexWithData:(NSData *)d {
    const uint8_t *bytes = d.bytes;
    NSMutableString *hex = CFBridgingRelease(CFStringCreateMutable(SecureAllocator(), d.length * 2));

    for (NSUInteger i = 0; i < d.length; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }

    return [hex toUppercaseStringWithEn];
}

+ (NSString *)addressWithScript:(NSData *)script {
    static NSData *suffix = nil;
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^{
        suffix = [NSData dataWithBytes:SCRIPT_SUFFIX length:strlen(SCRIPT_SUFFIX)];
    });

    if (script == (id) [NSNull null] || script.length < suffix.length + 20 ||
            ![[script subdataWithRange:NSMakeRange(script.length - suffix.length, suffix.length)] isEqualToData:suffix]) {
        return nil;
    }

#if BITCOIN_TESTNET
    uint8_t x = BITCOIN_PUBKEY_ADDRESS_TEST;
#else
    uint8_t x = BITCOIN_PUBKEY_ADDRESS;
#endif
    NSMutableData *d = [NSMutableData dataWithBytes:&x length:1];

    [d appendBytes:(const uint8_t *) script.bytes + script.length - suffix.length - 20 length:20];

    return [self base58checkWithData:d];
}

+ (NSString *)addressWithPubKey:(NSData *)pubKey; {
    if (pubKey == (id) [NSNull null] || pubKey.length < 33) {
        return nil;
    }
    uint8_t x = BITCOIN_PUBKEY_ADDRESS;
    NSMutableData *d = [NSMutableData dataWithBytes:&x length:1];
    NSData *hash = [pubKey hash160];
    [d appendBytes:(const uint8_t *) hash.bytes length:20];
    return [self base58checkWithData:d];
}


- (NSString *)hexToBase58 {
    return [[self class] base58WithData:self.hexToData];
}

- (NSString *)base58ToHex {
    return [NSString hexWithData:self.base58ToData];
}

- (NSData *)base58checkToData {
    NSData *d = self.base58ToData;

    if (d.length < 4) return nil;

    NSData *data = CFBridgingRelease(CFDataCreate(SecureAllocator(), d.bytes, d.length - 4));

    // verify checksum
    if (*(uint32_t *) ((const uint8_t *) d.bytes + d.length - 4) != *(uint32_t *) data.SHA256_2.bytes) return nil;

    return data;
}

- (NSString *)hexToBase58check {
    return [NSString base58checkWithData:self.hexToData];
}

- (NSString *)base58checkToHex {
    return [NSString hexWithData:self.base58checkToData];
}

- (NSData *)hexToData {
    if (self.length % 2) return nil;

    NSMutableData *d = [NSMutableData secureDataWithCapacity:self.length / 2];
    uint8_t b = 0;

    for (NSUInteger i = 0; i < self.length; i++) {
        unichar c = [self characterAtIndex:i];

        switch (c) {
            case '0':
            case '1':
            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
                b += c - '0';
                break;
            case 'A':
            case 'B':
            case 'C':
            case 'D':
            case 'E':
            case 'F':
                b += c + 10 - 'A';
                break;
            case 'a':
            case 'b':
            case 'c':
            case 'd':
            case 'e':
            case 'f':
                b += c + 10 - 'a';
                break;
            default:
                return d;
        }

        if (i % 2) {
            [d appendBytes:&b length:1];
            b = 0;
        }
        else b *= 16;
    }

    return d;
}

+ (NSString *)hexWithHash:(NSData *)d; {
    return [NSString hexWithData:[d reverse]];
}

- (NSData *)addressToHash160 {
    NSData *d = self.base58checkToData;

    return (d.length == 160 / 8 + 1) ? [d subdataWithRange:NSMakeRange(1, d.length - 1)] : nil;
}

- (BOOL)isValidBitcoinAddress {
    NSData *d = self.base58checkToData;

    if (d.length != 21) return NO;

    uint8_t version = *(const uint8_t *) d.bytes;

#if BITCOIN_TESTNET
    return (version == BITCOIN_PUBKEY_ADDRESS_TEST || version == BITCOIN_SCRIPT_ADDRESS_TEST) ? YES : NO;
#else
   return ([NSString validAddressPubkey:version] || [NSString validAddressScript:version]) ? YES : NO;
#endif
}

+ (NSString *)hexStringFromString:(NSString *)string{
    NSData *myD = [string dataUsingEncoding:NSUTF8StringEncoding];
    Byte *bytes = (Byte *)[myD bytes];
    NSString *hexStr=@"";
    for(int i=0;i<[myD length];i++)
    {
        NSString *newHexStr = [NSString stringWithFormat:@"%x",bytes[i]&0xff];
        if ([newHexStr length]==1)
            hexStr = [NSString stringWithFormat:@"%@0%@",hexStr,newHexStr];
        else
            hexStr = [NSString stringWithFormat:@"%@%@",hexStr,newHexStr];
    }
    return hexStr;
}

- (BOOL)isValidBitcoinGoldAddress {
    NSData *d = self.base58checkToData;
    
    if (d.length != 21) return NO;
    
    uint8_t version = *(const uint8_t *) d.bytes;
    
#if BITCOIN_TESTNET
    return (version == BITCOIN_PUBKEY_ADDRESS_TEST || version == BITCOIN_SCRIPT_ADDRESS_TEST) ? YES : NO;
#else
    return (version == BITCOIN_GOLD_PUBKEY_ADDRESS || version == BITCOIN_GOLD_SCRIPT_ADDRESS) ? YES : NO;
#endif
}

- (BOOL)isValidBitcoinPrivateKey {
    NSData *d = self.base58checkToData;

    if (d.length == 33 || d.length == 34) { // wallet import format: https://en.bitcoin.it/wiki/Wallet_import_format
#if BITCOIN_TESNET
        return (*(const uint8_t *)d.bytes == BITCOIN_PRIVKEY_TEST) ? YES : NO;
#else
        return (*(const uint8_t *) d.bytes == BITCOIN_PRIVKEY) ? YES : NO;
#endif
    }
    else if ((self.length == 30 || self.length == 22) && [self characterAtIndex:0] == 'S') { // mini private key format
        NSMutableData *d = [NSMutableData secureDataWithCapacity:self.length + 1];

        d.length = self.length;
        [self getBytes:d.mutableBytes maxLength:d.length usedLength:NULL encoding:NSUTF8StringEncoding options:0
                 range:NSMakeRange(0, self.length) remainingRange:NULL];
        [d appendBytes:"?" length:1];
        return (*(const uint8_t *) d.SHA256.bytes == 0) ? YES : NO;
    }
    else return (self.hexToData.length == 32) ? YES : NO; // hex encoded key
}

// BIP38 encrypted keys: https://github.com/bitcoin/bips/blob/master/bip-0038.mediawiki
- (BOOL)isValidBitcoinBIP38Key {
    NSData *d = self.base58checkToData;

    if (d.length != 39) return NO; // invalid length

    uint16_t prefix = CFSwapInt16BigToHost(*(const uint16_t *) d.bytes);
    uint8_t flag = ((const uint8_t *) d.bytes)[2];

    if (prefix == BIP38_NOEC_PREFIX) { // non EC multiplied key
        return ((flag & BIP38_NOEC_FLAG) == BIP38_NOEC_FLAG && (flag & BIP38_LOTSEQUENCE_FLAG) == 0 &&
                (flag & BIP38_INVALID_FLAG) == 0) ? YES : NO;
    }
    else if (prefix == BIP38_EC_PREFIX) { // EC multiplied key
        return ((flag & BIP38_NOEC_FLAG) == 0 && (flag & BIP38_INVALID_FLAG) == 0) ? YES : NO;
    }
    else return NO; // invalid prefix
}

- (NSString *)toUppercaseStringWithEn {
    return [self uppercaseStringWithLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
}

- (NSString *)toLowercaseStringWithEn {
    return [self lowercaseStringWithLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
}
@end
