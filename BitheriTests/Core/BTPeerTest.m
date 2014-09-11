//
//  BTPeerTest.m
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
#import "BTPeer.h"

@interface BTPeerTest : XCTestCase

@end

@implementation BTPeerTest

- (void)setUp
{
    [super setUp];
    [BTTestHelper setup];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
    BTPeer *peer = [[BTPeer alloc] initWithAddress:0x7f000001 port:8333 timestamp:0 services:0];
    [peer connectPeer];

    BTPeer *peer1 = [[BTPeer alloc] initWithAddress:0x7f000001 port:8333 timestamp:0 services:0];
    BTPeer *peer2 = [[BTPeer alloc] initWithAddress:0x7f000001 port:8333 timestamp:0 services:0];
    XCTAssert([peer1 isEqual:peer2]);
}

@end
