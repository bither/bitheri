//
//  BitheriTests.m
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
#import "BTBech32.h"
#import "BTSegwitAddrCoder.h"
#import "BTScript.h"


@interface BitheriTests : XCTestCase

@end

@implementation BitheriTests

- (void)testBech32RejectsOutOfRangeDataValue
{
    uint8_t invalidValue = 32;
    NSData *values = [NSData dataWithBytes:&invalidValue length:sizeof(invalidValue)];

    XCTAssertNil([[[BTBech32 alloc] init] encode:@"bc" values:values]);
}

- (void)testSegwitEncoderRejectsOpcodeAsVersion
{
    NSData *program = [NSData dataWithLength:20];

    XCTAssertNil([[[BTSegwitAddrCoder alloc] init] encode:@"bc" version:0x51 program:program]);
}

- (void)testSegwitEncoderStillEncodesVersionZeroProgram
{
    NSData *program = [NSData dataWithLength:20];

    XCTAssertEqualObjects([[[BTSegwitAddrCoder alloc] init] encode:@"bc" version:0 program:program],
                          @"bc1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq9e75rs");
}

- (void)testTaprootOutputIsNotMisidentifiedAsP2WSH
{
    uint8_t taprootScript[34] = {0x51, 0x20};
    BTScript *script = [[BTScript alloc] initWithProgram:[NSData dataWithBytes:taprootScript length:sizeof(taprootScript)]];

    XCTAssertNil([script getToAddress]);
}

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

@end
