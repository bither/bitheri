//
//  BTBlockChainTest.m
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
#import "BTBlockChain.h"
#import "BTBlockTestData.h"
#import "BTTestHelper.h"

@interface BTBlockChainTest : XCTestCase

@end

@implementation BTBlockChainTest{
    BTBlockChain *blockChain;
}

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [BTTestHelper setup];
    blockChain = [BTBlockChain instance];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

//- (void)testSyncHeader;{
//    XCTAssertEqual(0, [blockChain getBlockCount]);
//    [blockChain addSPVBlock:[BTBlock blockWithBlockItem:[BTBlockTestData getBlock:0]]];
//    XCTAssertEqual(1, [blockChain getBlockCount]);
//
//    BTPeer *peer = [BTPeer new];
//
//    [blockChain relayedBlock:[BTBlockTestData getOrphanBlock:0] withPeer:peer andCallback:^(BTBlock *b, BOOL isConfirm) {
//        XCTAssert(isConfirm);
//    }];
//
//    XCTAssert([[BTBlockTestData getOrphanBlock:0] isEqual:blockChain.lastBlock]);
//    XCTAssertEqual(2, [blockChain getBlockCount]);
//    XCTAssertEqual(2, [blockChain.mainChain count]);
//    XCTAssertEqual(0, [blockChain.orphans count]);
//
//    [blockChain relayedBlock:[BTBlockTestData getMainBlock:1] withPeer:peer andCallback:^(BTBlock *b, BOOL isConfirm) {
//        XCTAssert(isConfirm);
//    }];
//
//    XCTAssert([[BTBlockTestData getOrphanBlock:0] isEqual:blockChain.lastBlock]);
//    XCTAssertEqual(3, [blockChain getBlockCount]);
//    XCTAssertEqual(2, [blockChain.mainChain count]);
//    XCTAssertEqual(1, [blockChain.orphans count]);
//
//    [blockChain relayedBlock:[BTBlockTestData getMainBlock:2] withPeer:peer andCallback:^(BTBlock *b, BOOL isConfirm) {
//        XCTAssert(isConfirm);
//    }];
//
//    XCTAssert([[BTBlockTestData getMainBlock:2] isEqual:blockChain.lastBlock]);
//    XCTAssertEqual(4, [blockChain getBlockCount]);
//    XCTAssertEqual(3, [blockChain.mainChain count]);
//    XCTAssertEqual(1, [blockChain.orphans count]);
//
//    [blockChain relayedBlock:[BTBlockTestData getOrphanBlock:1] withPeer:peer andCallback:^(BTBlock *b, BOOL isConfirm) {
//        XCTAssert(isConfirm);
//    }];
//
//    XCTAssert([[BTBlockTestData getMainBlock:2] isEqual:blockChain.lastBlock]);
//    XCTAssertEqual(5, [blockChain getBlockCount]);
//    XCTAssertEqual(3, [blockChain.mainChain count]);
//    XCTAssertEqual(2, [blockChain.orphans count]);
//
//    [blockChain relayedBlock:[BTBlockTestData getOrphanBlock:4] withPeer:peer andCallback:^(BTBlock *b, BOOL isConfirm) {
//        XCTAssert(isConfirm);
//    }];
//
//    XCTAssert([[BTBlockTestData getMainBlock:2] isEqual:blockChain.lastBlock]);
//    XCTAssertEqual(5, [blockChain getBlockCount]);
//    XCTAssertEqual(3, [blockChain.mainChain count]);
//    XCTAssertEqual(2, [blockChain.orphans count]);
//
//    [blockChain relayedBlock:[BTBlockTestData getMainBlock:2] withPeer:peer andCallback:^(BTBlock *b, BOOL isConfirm) {
//        XCTAssert(isConfirm);
//    }];
//
//    XCTAssert([[BTBlockTestData getMainBlock:2] isEqual:blockChain.lastBlock]);
//    XCTAssertEqual(5, [blockChain getBlockCount]);
//    XCTAssertEqual(3, [blockChain.mainChain count]);
//    XCTAssertEqual(2, [blockChain.orphans count]);
//
//    [blockChain relayedBlock:[BTBlockTestData getMainBlock:3] withPeer:peer andCallback:^(BTBlock *b, BOOL isConfirm) {
//        XCTAssert(isConfirm);
//    }];
//
//    XCTAssert([[BTBlockTestData getMainBlock:3] isEqual:blockChain.lastBlock]);
//    XCTAssertEqual(6, [blockChain getBlockCount]);
//    XCTAssertEqual(4, [blockChain.mainChain count]);
//    XCTAssertEqual(2, [blockChain.orphans count]);
//
//    [blockChain relayedBlock:[BTBlockTestData getOrphanBlock:2] withPeer:peer andCallback:^(BTBlock *b, BOOL isConfirm) {
//        XCTAssert(isConfirm);
//    }];
//
//    XCTAssert([[BTBlockTestData getMainBlock:3] isEqual:blockChain.lastBlock]);
//    XCTAssertEqual(7, [blockChain getBlockCount]);
//    XCTAssertEqual(4, [blockChain.mainChain count]);
//    XCTAssertEqual(3, [blockChain.orphans count]);
//}

@end
