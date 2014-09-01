//
//  BTBlockProviderTest.m
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
#import "BTBlockProvider.h"
#import "BTBlockTestData.h"
#import "BTTestHelper.h"


@interface BTBlockProviderTest : XCTestCase

@end

@implementation BTBlockProviderTest{
    BTBlockProvider *provider;
}

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [BTTestHelper setup];
    provider = [BTBlockProvider instance];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testGetBlockCount;{
    XCTAssertEqual(0, [provider getBlockCount]);

}

- (void)testAddBlock;{
    XCTAssertEqual(0, [provider getBlockCount]);
    BTBlock *blockItem = [BTBlockTestData getBlock:0];
    [provider addBlock:blockItem];
    XCTAssert([blockItem isEqual:[provider getAllBlocks][0]]);
    XCTAssertEqual(1, [provider getBlockCount]);
}

//- (void)testAddBlocks;{
//    XCTAssertEqual(0, [provider getBlockCount]);
//    NSMutableArray *array = [NSMutableArray arrayWithArray:[BTBlockTestData blocks]];
//    [provider addBlocks:array];
//    XCTAssertEqual(array.count, [provider getBlockCount]);
//    NSArray *array3 = [[array reverseObjectEnumerator] allObjects];
//    NSArray *array2 = [provider getAllBlocks];
//    for (int i = 0; i < array.count; i++){
//        XCTAssert([array3[i] isEqual:array2[i]]);
//    }
//}

- (void)testIsExist;{
    XCTAssertEqual(0, [provider getBlockCount]);
    BTBlock *blockItem = [BTBlockTestData getBlock:0];
    XCTAssertEqualObjects(nil, [provider getBlock:blockItem.blockHash]);
    [provider addBlock:blockItem];
    XCTAssert([blockItem isEqual:[provider getAllBlocks][0]]);
    XCTAssert([blockItem isEqual:[provider getBlock:blockItem.blockHash]]);
    XCTAssertEqual(1, [provider getBlockCount]);
}

@end
