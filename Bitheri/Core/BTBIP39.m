//
//  BTBIP39.m
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
//  Copyright (c) 2014 Aaron Voisine <voisine@gmail.com>
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

#import "BTBIP39.h"
#import "NSString+Base58.h"
#import "NSData+Hash.h"
#import "NSMutableData+Bitcoin.h"
#import "ccMemory.h"
#import <CommonCrypto/CommonKeyDerivation.h>
#import "BTWordsTypeManager.h"

// BIP39 is method for generating a deterministic wallet seed from a mnemonic code
// https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki


@implementation BTBIP39

- (instancetype)initWithWordList:(NSString *)wordList {
    if (!(self = [super init])) return nil;
    self.isUnitTest = NO;
    self.wordList = wordList;
    return self;
}

+ (instancetype)sharedInstance {
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [[BTBIP39 alloc] initWithWordList:[BTWordsTypeManager getWordsTypeValue:EN_WORDS]];
    });
    
    return singleton;
}

+ (instancetype)instanceForWord:(NSString *)word {
    NSArray *wordLists = [BTWordsTypeManager getAllWordsType];
    for (NSString *wordList in wordLists) {
        BTBIP39 *instance = [[BTBIP39 alloc] initWithWordList:wordList];
        if ([[instance getWords] indexOfObject:word] != NSNotFound) {
            return instance;
        }
    }
    return nil;
}

- (NSArray *)getWords {
    if (self.isUnitTest) {
        return [NSArray arrayWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:self.wordList ofType:@"plist"]];
    } else {
        return [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:self.wordList ofType:@"plist"]];
    }
}

- (NSArray *)toMnemonicArray:(NSData *)data {
    if ((data.length % 4) != 0 || data.length == 0) return nil; // data length must be a multiple of 32 bits

    NSArray *words = [self getWords];
    uint32_t n = (uint32_t) words.count, x;
    NSMutableArray *a =
            CFBridgingRelease(CFArrayCreateMutable(SecureAllocator(), data.length * 3 / 4, &kCFTypeArrayCallBacks));
    NSMutableData *d = [NSMutableData secureDataWithData:data];

    [d appendData:data.SHA256]; // append SHA256 checksum

    for (int i = 0; i < data.length * 3 / 4; i++) {
        x = CFSwapInt32BigToHost(*(const uint32_t *) ((const uint8_t *) d.bytes + i * 11 / 8));
        [a addObject:words[(x >> (sizeof(x) * 8 - (11 + ((i * 11) % 8)))) % n]];
    }

    CC_XZEROMEM(&x, sizeof(x));
    return a;
}

- (NSString *)toMnemonic:(NSData *)data {
    NSArray *a = [self toMnemonicArray:data];
    if (a != nil) {
        return CFBridgingRelease(CFStringCreateByCombiningStrings(SecureAllocator(), (__bridge CFArrayRef) a, CFSTR(" ")));
    } else {
        return nil;
    }
}

- (NSString *)toMnemonicWithArray:(NSArray *)a {
    if (a != nil) {
        return CFBridgingRelease(CFStringCreateByCombiningStrings(SecureAllocator(), (__bridge CFArrayRef) a, CFSTR(" ")));
    } else {
        return nil;
    }
}

- (NSData *)toEntropy:(NSString *)code {
    NSArray *words = [self getWords];
    NSArray *a = CFBridgingRelease(CFStringCreateArrayBySeparatingStrings(SecureAllocator(),
            (__bridge CFStringRef) [self normalizeCode:code], CFSTR(" ")));
    NSMutableData *d = [NSMutableData secureDataWithCapacity:(a.count * 11 + 7) / 8];
    uint32_t n = (uint32_t) words.count, x, y;
    uint8_t b;

    if ((a.count % 3) != 0 || a.count > 24) {
        NSLog(@"code has wrong number of words");
        return nil;
    }

    for (int i = 0; i < (a.count * 11 + 7) / 8; i++) {
        x = (uint32_t) [words indexOfObject:a[i * 8 / 11]];
        y = (i * 8 / 11 + 1 < a.count) ? (uint32_t) [words indexOfObject:a[i * 8 / 11 + 1]] : 0;

        if (x == (uint32_t) NSNotFound || y == (uint32_t) NSNotFound) {
            NSLog(@"code contained unknown word: %@", a[i * 8 / 11 + (x == (uint32_t) NSNotFound ? 0 : 1)]);
            return nil;
        }

        b = ((x * n + y) >> ((i * 8 / 11 + 2) * 11 - (i + 1) * 8)) & 0xff;
        [d appendBytes:&b length:1];
    }

    b = *((const uint8_t *) d.bytes + a.count * 4 / 3) >> (8 - a.count / 3);
    d.length = a.count * 4 / 3;

    if (b != (*(const uint8_t *) d.SHA256.bytes >> (8 - a.count / 3))) {
        NSLog(@"incorrect code, bad checksum");
        return nil;
    }

    CC_XZEROMEM(&x, sizeof(x));
    CC_XZEROMEM(&y, sizeof(y));
    CC_XZEROMEM(&b, sizeof(b));
    return d;
}

- (BOOL)check:(NSString *)code {
    return [self toEntropy:code] != nil;
}

- (NSString *)normalizeCode:(NSString *)code {
    NSMutableString *s = CFBridgingRelease(CFStringCreateMutableCopy(SecureAllocator(), 0, (__bridge CFStringRef) code));

    [s replaceOccurrencesOfString:@"." withString:@" " options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"," withString:@" " options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, s.length)];
    CFStringTrimWhitespace((__bridge CFMutableStringRef) s);
    CFStringLowercase((__bridge CFMutableStringRef) s, CFLocaleGetSystem());

    while ([s rangeOfString:@"  "].location != NSNotFound) {
        [s replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, s.length)];
    }

    return s;
}

- (NSData *)toSeed:(NSString *)code withPassphrase:(NSString *)passphrase {
    NSMutableData *key = [NSMutableData secureDataWithLength:CC_SHA512_DIGEST_LENGTH];
    NSData *password, *salt;
    CFMutableStringRef pw = CFStringCreateMutableCopy(SecureAllocator(), code.length, (__bridge CFStringRef) code);
    CFMutableStringRef s = CFStringCreateMutableCopy(SecureAllocator(), 8 + passphrase.length, CFSTR("mnemonic"));

    if (passphrase) CFStringAppend(s, (__bridge CFStringRef) passphrase);
    CFStringNormalize(pw, kCFStringNormalizationFormKD);
    CFStringNormalize(s, kCFStringNormalizationFormKD);
    password = CFBridgingRelease(CFStringCreateExternalRepresentation(SecureAllocator(), pw, kCFStringEncodingUTF8, 0));
    salt = CFBridgingRelease(CFStringCreateExternalRepresentation(SecureAllocator(), s, kCFStringEncodingUTF8, 0));
    CFRelease(pw);
    CFRelease(s);

    CCKeyDerivationPBKDF(kCCPBKDF2, password.bytes, password.length, salt.bytes, salt.length, kCCPRFHmacAlgSHA512, 2048,
            key.mutableBytes, key.length);
    return key;
}

@end
