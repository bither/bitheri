//
//  NSData+Hash.m
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

#import "NSData+Hash.h"
#import <openssl/ripemd.h>
#import <openssl/bn.h>

@implementation NSData (Hash)

- (NSData *)SHA1 {
    NSMutableData *d = [NSMutableData dataWithLength:CC_SHA1_DIGEST_LENGTH];

    CC_SHA1(self.bytes, (CC_LONG) self.length, d.mutableBytes);

    return d;
}

- (NSData *)SHA256 {
    NSMutableData *d = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];

    CC_SHA256(self.bytes, (CC_LONG) self.length, d.mutableBytes);

    return d;
}

- (NSData *)SHA256_2 {
    NSMutableData *d = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];

    CC_SHA256(self.bytes, (CC_LONG) self.length, d.mutableBytes);
    CC_SHA256(d.bytes, (CC_LONG) d.length, d.mutableBytes);

    return d;
}

- (NSData *)RMD160 {
    NSMutableData *d = [NSMutableData dataWithLength:RIPEMD160_DIGEST_LENGTH];

    RIPEMD160(self.bytes, self.length, d.mutableBytes);

    return d;
}

- (NSData *)hash160 {
    return self.SHA256.RMD160;
}

- (NSData *)reverse {
    NSUInteger l = self.length;
    NSMutableData *d = [NSMutableData dataWithLength:l];
    uint8_t *b1 = d.mutableBytes;
    const uint8_t *b2 = self.bytes;

    for (NSUInteger i = 0; i < l; i++) {
        b1[i] = b2[l - i - 1];
    }

    return d;
}

- (NSInteger)compare:(NSData *)data {
    BIGNUM *modulus = BN_bin2bn(self.bytes, self.length, NULL);
    BIGNUM *exponent = BN_bin2bn(data.bytes, data.length, NULL);
    int result = BN_cmp(modulus, exponent);
    BN_clear_free(modulus);
    BN_clear_free(exponent);
    return result;
}


+ (NSData *)randomWithSize:(int)size; {
    OSStatus sanityCheck = noErr;
    uint8_t *bytes = NULL;
    bytes = malloc(size * sizeof(uint8_t));
    memset((void *) bytes, 0x0, size);
    sanityCheck = SecRandomCopyBytes(kSecRandomDefault, size, bytes);
    if (sanityCheck == noErr) {
        return [NSData dataWithBytes:bytes length:size];
    } else {
        return nil;
    }
}

@end
