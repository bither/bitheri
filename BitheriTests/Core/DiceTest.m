//
//  DiceTest.m
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

#import <XCTest/XCTest.h>
#import "NSString+Base58.h"
#import <openssl/bn.h>

@interface DiceTest : XCTestCase
@end

@implementation DiceTest {

}

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testExample {
//    NSString *from = @"0000000414122353535343413140134235013434331434323245442323431314313402353431043235343114323535431134";
//    NSData *expect = [@"F174540CEAF827967DE514E28160481ADB58A47BB99A134706EB057A9082" hexToData];
    NSString *from = @"5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555";
    NSData *expect = [@"A4653CA673768565B41F775D6947D5634E16EC8E9394DED540E4273FEEF0B9BA" hexToData];


    NSData* PN = [@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141" hexToData];
    NSMutableData *d = [NSMutableData dataWithCapacity:33];

    BN_CTX *ctx = BN_CTX_new();
    BIGNUM num, base, digit, prev;
    BIGNUM *n = BN_bin2bn(PN.bytes, 32, NULL);
    BN_CTX_start(ctx);
    BN_init(&num);
    BN_init(&base);
    BN_init(&digit);
    BN_init(&prev);
    BN_set_word(&base, 6);
    BN_zero(&num);

    for (NSUInteger i = 0; i < from.length; i++) {
        BN_set_word(&digit, [from characterAtIndex:i] - '0');
        BN_mul(&prev, &num, &base, ctx);
        BN_add(&num, &prev, &digit);
    }
    BN_mod(&num, &num, n, ctx);

    d.length += BN_num_bytes(&num);
    BN_bn2bin(&num, (unsigned char *) d.mutableBytes + d.length - BN_num_bytes(&num));

    BN_clear_free(&num);
    BN_clear_free(&prev);
    BN_free(&base);
    BN_free(&digit);
    BN_free(n);
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);

    NSLog(@"output %@", [NSString hexWithData:d]);
    NSAssert([expect isEqualToData:d], @"not same, got %@\n expect %@", [NSString hexWithData:d], [NSString hexWithData:expect]);
}

@end