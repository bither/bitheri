//
//  BTTxProviderTest.m
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
#import "BTTxProvider.h"
#import "BTTxTestData.h"
#import "BTOutItem.h"
#import "BTSettings.h"
#import "BTTestHelper.h"
#import "BTAddressTestData.h"

@interface BTTxProviderTest : XCTestCase{
    BTTxProvider *provider;
//    NSString *address;
    int txCount;
//    NSString *satoshiAddress;
}

@end

@implementation BTTxProviderTest

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [BTTestHelper setup];
    provider = [BTTxProvider instance];
//    address = @"1BsTwoMaX3aYx9Nc8GdgHZzzAGmG669bC3";
    txCount = 47;
//    satoshiAddress = @"1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa";
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAdd;{
    BTTxItem *tx0 = [BTTxTestData getTx:0];

    XCTAssert(![provider isExist:tx0.txHash]);
    [provider add:tx0];
    XCTAssert([tx0 isEqual:[provider getTxDetailByTxHash:tx0.txHash]]);
    XCTAssert([provider isExist:tx0.txHash]);

    XCTAssert(![provider isAddress:satoshiAddress containsTx:tx0]);
    XCTAssert([provider isAddress:bitheriAddress containsTx:tx0]);
    XCTAssert(![provider isAddress:bitheriAddress containsTx:[BTTxTestData getTx:txCount - 1]]);

    for (int i = 1; i < txCount - 1; i++) {
        [provider add:[BTTxTestData getTx:i]];
    }

    XCTAssert([provider isAddress:bitheriAddress containsTx:[BTTxTestData getTx:txCount - 1]]);

    [provider add:[BTTxTestData getTx:txCount - 1]];

    XCTAssertEqual(txCount, [provider getTxAndDetailByAddress:bitheriAddress].count);
    XCTAssertEqual(0, [provider getTxAndDetailByAddress:satoshiAddress].count);

    NSMutableArray *allTx = [NSMutableArray new];
    for (int i = 0; i < txCount; i++) {
        BTTxItem *item = [BTTxTestData getTx:i];
        if (i != txCount - 1) {
            for (BTOutItem *outItem in item.outs) {
                if (outItem.outAddress == bitheriAddress) {
                    outItem.outStatus = spent;
                }
                if (i == 26 || i == 32) {
                    outItem.outStatus = spent;
                }
            }
        }
        [allTx addObject:item];
    }

    NSArray *txs = [provider getTxAndDetailByAddress:bitheriAddress];
    for (int i = 0; i < txCount; i++) {
        XCTAssert([allTx[i] isEqual:txs[i]], @"%d", i);
    }

}

- (void)testConfirmTx;{
    NSMutableArray *allTx = [NSMutableArray new];
    NSMutableArray *unconfirmTx = [NSMutableArray new];
    for (int i = 0; i < txCount; i++) {
        BTTxItem *item = [BTTxTestData getTx:i];
        BTTxItem *unconfirmItem = [BTTxTestData getTx:i];
        unconfirmItem.blockNo = TX_UNCONFIRMED;
        [unconfirmTx addObject:unconfirmItem];
        [allTx addObject:item];
    }

    XCTAssertEqual(0, [provider getTxAndDetailByAddress:bitheriAddress].count);
    [provider add:unconfirmTx[0]];
    XCTAssertEqual(1, [provider getTxAndDetailByAddress:bitheriAddress].count);
    [provider confirmTx:@[((BTTxItem *)allTx[0]).txHash] withBlockNo:((BTTxItem *)allTx[0]).blockNo];
    XCTAssert([allTx[0] isEqual:[provider getTxDetailByTxHash:((BTTxItem *)allTx[0]).txHash]]);

    [provider unConfirmTxByBlockNo:((BTTxItem *)allTx[0]).blockNo];
    XCTAssert([unconfirmTx[0] isEqual:[provider getTxDetailByTxHash:((BTTxItem *)allTx[0]).txHash]]);

}
@end
