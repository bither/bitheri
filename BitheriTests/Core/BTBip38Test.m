//
//  BTBip38Test.m
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


#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "BTKey.h"
#import "BTKey+BIP38.h"
#import "NSString+Base58.h"

@interface BTBip38Test : XCTestCase

@end

@implementation BTBip38Test

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    
    NSString *intercode, *confcode, *privkey;
    BTKey *key;
    
    // non EC multiplied, uncompressed
    key = [BTKey keyWithBIP38Key:@"6PRVWUbkzzsbcVac2qwfssoUJAN1Xhrg6bNk8J7Nzm5H7kxEbn2Nh2ZoGg"
                   andPassphrase:@"TestingOneTwoThree"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5KN7MzqK5wt2TP1fQCYyHBtDrXdJuXbUzm4A9rKAteGu3Qi5CVR", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    XCTAssertEqualObjects([key BIP38KeyWithPassphrase:@"TestingOneTwoThree"],
                          @"6PRVWUbkzzsbcVac2qwfssoUJAN1Xhrg6bNk8J7Nzm5H7kxEbn2Nh2ZoGg",
                          @"[BRKey BIP38KeyWithPassphrase:]");
    
    key = [BTKey keyWithBIP38Key:@"6PRNFFkZc2NZ6dJqFfhRoFNMR9Lnyj7dYGrzdgXXVMXcxoKTePPX1dWByq"
                   andPassphrase:@"Satoshi"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5HtasZ6ofTHP6HCwTqTkLDuLQisYPah7aUnSKfC7h4hMUVw2gi5", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    XCTAssertEqualObjects([key BIP38KeyWithPassphrase:@"Satoshi"],
                          @"6PRNFFkZc2NZ6dJqFfhRoFNMR9Lnyj7dYGrzdgXXVMXcxoKTePPX1dWByq",
                          @"[BRKey BIP38KeyWithPassphrase:]");
    
    // non EC multiplied, compressed
    key = [BTKey keyWithBIP38Key:@"6PYNKZ1EAgYgmQfmNVamxyXVWHzK5s6DGhwP4J5o44cvXdoY7sRzhtpUeo"
                   andPassphrase:@"TestingOneTwoThree"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"L44B5gGEpqEDRS9vVPz7QT35jcBG2r3CZwSwQ4fCewXAhAhqGVpP", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    XCTAssertEqualObjects([key BIP38KeyWithPassphrase:@"TestingOneTwoThree"],
                          @"6PYNKZ1EAgYgmQfmNVamxyXVWHzK5s6DGhwP4J5o44cvXdoY7sRzhtpUeo",
                          @"[BRKey BIP38KeyWithPassphrase:]");
    
    key = [BTKey keyWithBIP38Key:@"6PYLtMnXvfG3oJde97zRyLYFZCYizPU5T3LwgdYJz1fRhh16bU7u6PPmY7"
                   andPassphrase:@"Satoshi"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"KwYgW8gcxj1JWJXhPSu4Fqwzfhp5Yfi42mdYmMa4XqK7NJxXUSK7", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    XCTAssertEqualObjects([key BIP38KeyWithPassphrase:@"Satoshi"],
                          @"6PYLtMnXvfG3oJde97zRyLYFZCYizPU5T3LwgdYJz1fRhh16bU7u6PPmY7",
                          @"[BRKey BIP38KeyWithPassphrase:]");
    
    // EC multiplied, uncompressed, no lot/sequence number
    key = [BTKey keyWithBIP38Key:@"6PfQu77ygVyJLZjfvMLyhLMQbYnu5uguoJJ4kMCLqWwPEdfpwANVS76gTX"
                   andPassphrase:@"TestingOneTwoThree"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5K4caxezwjGCGfnoPTZ8tMcJBLB7Jvyjv4xxeacadhq8nLisLR2", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    intercode = [BTKey BIP38IntermediateCodeWithSalt:0xa50dba6772cb9383ULL andPassphrase:@"TestingOneTwoThree"];
    NSLog(@"intercode = %@", intercode);
    privkey = [BTKey BIP38KeyWithIntermediateCode:intercode
                                            seedb:@"99241d58245c883896f80843d2846672d7312e6195ca1a6c".hexToData compressed:NO
                                 confirmationCode:&confcode];
    NSLog(@"confcode = %@", confcode);
    XCTAssertEqualObjects(@"6PfQu77ygVyJLZjfvMLyhLMQbYnu5uguoJJ4kMCLqWwPEdfpwANVS76gTX", privkey,
                          @"[BRKey BIP38KeyWithIntermediateCode:]");
    XCTAssertTrue([BTKey confirmWithBIP38ConfirmationCode:confcode address:@"1PE6TQi6HTVNz5DLwB1LcpMBALubfuN2z2"
                                               passphrase:@"TestingOneTwoThree"], @"[BRKey confirmWithBIP38ConfirmationCode:]");
    
    key = [BTKey keyWithBIP38Key:@"6PfLGnQs6VZnrNpmVKfjotbnQuaJK4KZoPFrAjx1JMJUa1Ft8gnf5WxfKd"
                   andPassphrase:@"Satoshi"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5KJ51SgxWaAYR13zd9ReMhJpwrcX47xTJh2D3fGPG9CM8vkv5sH", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    intercode = [BTKey BIP38IntermediateCodeWithSalt:0x67010a9573418906ULL andPassphrase:@"Satoshi"];
    NSLog(@"intercode = %@", intercode);
    privkey = [BTKey BIP38KeyWithIntermediateCode:intercode
                                            seedb:@"49111e301d94eab339ff9f6822ee99d9f49606db3b47a497".hexToData compressed:NO
                                 confirmationCode:&confcode];
    NSLog(@"confcode = %@", confcode);
    XCTAssertEqualObjects(@"6PfLGnQs6VZnrNpmVKfjotbnQuaJK4KZoPFrAjx1JMJUa1Ft8gnf5WxfKd", privkey,
                          @"[BRKey BIP38KeyWithIntermediateCode:]");
    XCTAssertTrue([BTKey confirmWithBIP38ConfirmationCode:confcode address:@"1CqzrtZC6mXSAhoxtFwVjz8LtwLJjDYU3V"
                                               passphrase:@"Satoshi"], @"[BRKey confirmWithBIP38ConfirmationCode:]");
    
    // EC multiplied, uncompressed, with lot/sequence number
    key = [BTKey keyWithBIP38Key:@"6PgNBNNzDkKdhkT6uJntUXwwzQV8Rr2tZcbkDcuC9DZRsS6AtHts4Ypo1j"
                   andPassphrase:@"MOLON LABE"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5JLdxTtcTHcfYcmJsNVy1v2PMDx432JPoYcBTVVRHpPaxUrdtf8", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    intercode = [BTKey BIP38IntermediateCodeWithLot:263183 sequence:1 salt:0x4fca5a97u passphrase:@"MOLON LABE"];
    NSLog(@"intercode = %@", intercode);
    privkey = [BTKey BIP38KeyWithIntermediateCode:intercode
                                            seedb:@"87a13b07858fa753cd3ab3f1c5eafb5f12579b6c33c9a53f".hexToData compressed:NO
                                 confirmationCode:&confcode];
    NSLog(@"confcode = %@", confcode);
    XCTAssertEqualObjects(@"6PgNBNNzDkKdhkT6uJntUXwwzQV8Rr2tZcbkDcuC9DZRsS6AtHts4Ypo1j", privkey,
                          @"[BRKey BIP38KeyWithIntermediateCode:]");
    XCTAssertTrue([BTKey confirmWithBIP38ConfirmationCode:confcode address:@"1Jscj8ALrYu2y9TD8NrpvDBugPedmbj4Yh"
                                               passphrase:@"MOLON LABE"], @"[BRKey confirmWithBIP38ConfirmationCode:]");
    
    key = [BTKey keyWithBIP38Key:@"6PgGWtx25kUg8QWvwuJAgorN6k9FbE25rv5dMRwu5SKMnfpfVe5mar2ngH"
                   andPassphrase:@"\u039c\u039f\u039b\u03a9\u039d \u039b\u0391\u0392\u0395"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5KMKKuUmAkiNbA3DazMQiLfDq47qs8MAEThm4yL8R2PhV1ov33D", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    intercode = [BTKey BIP38IntermediateCodeWithLot:806938 sequence:1 salt:0xc40ea76fu
                                         passphrase:@"\u039c\u039f\u039b\u03a9\u039d \u039b\u0391\u0392\u0395"];
    NSLog(@"intercode = %@", intercode);
    privkey = [BTKey BIP38KeyWithIntermediateCode:intercode
                                            seedb:@"03b06a1ea7f9219ae364560d7b985ab1fa27025aaa7e427a".hexToData compressed:NO
                                 confirmationCode:&confcode];
    NSLog(@"confcode = %@", confcode);
    XCTAssertEqualObjects(@"6PgGWtx25kUg8QWvwuJAgorN6k9FbE25rv5dMRwu5SKMnfpfVe5mar2ngH", privkey,
                          @"[BRKey BIP38KeyWithIntermediateCode:]");
    XCTAssertTrue([BTKey confirmWithBIP38ConfirmationCode:confcode address:@"1Lurmih3KruL4xDB5FmHof38yawNtP9oGf"
                                               passphrase:@"\u039c\u039f\u039b\u03a9\u039d \u039b\u0391\u0392\u0395"],
                  @"[BRKey confirmWithBIP38ConfirmationCode:]");
    
    // password NFC unicode normalization test
    key = [BTKey keyWithBIP38Key:@"6PRW5o9FLp4gJDDVqJQKJFTpMvdsSGJxMYHtHaQBF3ooa8mwD69bapcDQn"
                   andPassphrase:@"\u03D2\u0301\0\U00010400\U0001F4A9"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertEqualObjects(@"5Jajm8eQ22H3pGWLEVCXyvND8dQZhiQhoLJNKjYXk9roUFTMSZ4", key.privateKey,
                          @"[BRKey keyWithBIP38Key:andPassphrase:]");
    
    // incorrect password test
    key = [BTKey keyWithBIP38Key:@"6PRW5o9FLp4gJDDVqJQKJFTpMvdsSGJxMYHtHaQBF3ooa8mwD69bapcDQn" andPassphrase:@"foobar"];
    NSLog(@"privKey = %@", key.privateKey);
    XCTAssertNil(key, @"[BRKey keyWithBIP38Key:andPassphrase:]");
    XCTAssert(YES, @"Pass");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
