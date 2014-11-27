//
//  NSData+HashTest.m
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
#import "BTTestHelper.h"
#import "NSData+Hash.h"


@interface NSDataHashTest : XCTestCase

@end

@implementation NSDataHashTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [BTTestHelper setup];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNormal {
    XCTAssertEqual([[@"0" hexToData] compare:[@"00" hexToData]], 0);
    XCTAssertEqual([[@"00" hexToData] compare:[@"00" hexToData]], 0);
    XCTAssertTrue([[@"00" hexToData] compare:[@"01" hexToData]] < 0);
    XCTAssertEqual([[@"01" hexToData] compare:[@"01" hexToData]], 0);
    XCTAssertTrue([[@"01" hexToData] compare:[@"00" hexToData]] > 0);

    XCTAssertEqual([[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141" hexToData] compare:[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141" hexToData]], 0);
    XCTAssertTrue([[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141" hexToData] compare:[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142" hexToData]] < 0);
    XCTAssertEqual([[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142" hexToData] compare:[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142" hexToData]], 0);
    XCTAssertTrue([[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142" hexToData] compare:[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141" hexToData]] > 0);
    XCTAssertEqual([[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140" hexToData] compare:[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140" hexToData]], 0);
    XCTAssertTrue([[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141" hexToData] compare:[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140" hexToData]] > 0);
    XCTAssertTrue([[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140" hexToData] compare:[@"fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141" hexToData]] < 0);
}

@end