//
//  BTSendTest.m
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
//#import "BTDatabaseManager.h"
#import "BTTxProvider.h"
//#import "BTInItem.h"
//#import "BTOutItem.h"
#import "NSString+Base58.h"
#import "NSData+Hash.h"
#import "BTAddress.h"
#import "BTBlockChain.h"
#import "BTBlockTestData.h"
#import "BTTestHelper.h"
#import "BTIn.h"
#import "BTOut.h"

@interface BTSendTest : XCTestCase

@end

@implementation BTSendTest{
    BTTxProvider *provider;
    NSString *bitherAddr;
    NSString *satoshiAddr;
}

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [BTTestHelper setup];
    provider = [BTTxProvider instance];
    bitherAddr = @"1BsTwoMaX3aYx9Nc8GdgHZzzAGmG669bC3";
    satoshiAddr = @"1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa";
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSendWithoutFee;{
    BTAddress *address = [[BTAddress alloc] initWithAddress:@"1BsTwoMaX3aYx9Nc8GdgHZzzAGmG669bC3" pubKey:[NSData new] hasPrivKey:YES];

    [[BTBlockChain instance] addSPVBlock:[BTBlockTestData getMainBlock:100]];

    BTTx *txItem1 = [self formatTx:@[@"00000000000000000000000000000002", @302400, @[@[@0, @"00000000000000000000000000000001", @0]], @[
            @[@0, @"1", @1000000, @"1BsTwoMaX3aYx9Nc8GdgHZzzAGmG669bC3"]
    ]
    ]];
    [provider add:txItem1];

    NSError *error;
    BTTx *tx = [address txForAmounts:@[@(1000000)] andAddress:@[@"1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"] andError:&error];
    XCTAssertEqual(1, tx.inputIndexes.count);
    XCTAssert([self isArrayEqual:tx.outputAmounts and:@[@(1000000)]]);
    XCTAssert([self isArrayEqual:tx.inputHashes and:@[[[@"00000000000000000000000000000002" hexToData] reverse]]]);
    XCTAssert([self isArrayEqual:tx.inputIndexes and:@[@(0)]]);

    // second tx 's coin depth is small than first tx, so use first tx
    BTTx *txItem2 = [self formatTx:@[@"00000000000000000000000000000004", @302402, @[@[@0, @"00000000000000000000000000000003", @0]], @[
            @[@0, @"2", @1000000, @"1BsTwoMaX3aYx9Nc8GdgHZzzAGmG669bC3"]
    ]
    ]];
    [provider add:txItem2];

    tx = [address txForAmounts:@[@(1000000)] andAddress:@[@"1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"] andError:&error];
    XCTAssertEqual(1, tx.inputIndexes.count);
    XCTAssert([self isArrayEqual:tx.outputAmounts and:@[@(1000000)]]);
    XCTAssert([self isArrayEqual:tx.inputHashes and:@[[[@"00000000000000000000000000000002" hexToData] reverse]]]);
    XCTAssert([self isArrayEqual:tx.inputIndexes and:@[@(0)]]);

    // third tx 's coin depth is more than first tx, so use third tx
    BTTx *txItem3 = [self formatTx:@[@"00000000000000000000000000000006", @302404, @[@[@0, @"00000000000000000000000000000005", @0]], @[
            @[@0, @"3", @5000000, @"1BsTwoMaX3aYx9Nc8GdgHZzzAGmG669bC3"]
    ]
    ]];
    [provider add:txItem3];

    tx = [address txForAmounts:@[@(1000000)] andAddress:@[@"1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"] andError:&error];
    XCTAssertEqual(1, tx.inputIndexes.count);
    NSArray *array = @[[NSNumber numberWithUnsignedLongLong:1000000], [NSNumber numberWithUnsignedLongLong:4000000]];
    XCTAssert([self isArrayEqual:tx.outputAmounts and:array]);
    XCTAssert([self isArrayEqual:tx.inputHashes and:@[[[@"00000000000000000000000000000006" hexToData] reverse]]]);
    XCTAssert([self isArrayEqual:tx.inputIndexes and:@[@(0)]]);

    // todo: not imp, I think should like this
//    tx = [address calculateTxWithAmounts:@[@(4950000)] andAddress:@[@"1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"]];
//    XCTAssertEqual(2, tx.inputIndexes.count);
//    array = @[[NSNumber numberWithUnsignedLongLong:4950000], [NSNumber numberWithUnsignedLongLong:150000]];
//    XCTAssert([self isArrayEqual:tx.outputAmounts and:array]);
//    array = @[[[@"00000000000000000000000000000006" hexToData] reverse], [[@"00000000000000000000000000000002" hexToData] reverse]];
//    XCTAssert([self isArrayEqual:tx.inputHashes and:array]);
//    array = @[@(0), @(0)];
//    XCTAssert([self isArrayEqual:tx.inputIndexes and:array]);
}

- (void)testSendWithFee;{
//    [BTSettings instance].feeBase = 100000;
    BTAddress *address = [[BTAddress alloc] initWithAddress:bitherAddr pubKey:[NSData new] hasPrivKey:YES];

    [[BTBlockChain instance] addSPVBlock:[BTBlockTestData getMainBlock:100]];

    BTTx *txItem1 = [self formatTx:@[@"00000000000000000000000000000002", @302400, @[@[@0, @"00000000000000000000000000000001", @0]], @[
            @[@0, @"1", @100000, bitherAddr]
    ]
    ]];
    [provider add:txItem1];

    NSError *error;
    BTTx *tx = [address txForAmounts:@[@(90000)] andAddress:@[satoshiAddr] andError:&error];
    XCTAssertEqual(1, tx.inputIndexes.count);
    NSArray *array = @[@(90000)];
    XCTAssert([self isArrayEqual:tx.outputAmounts and:array]);
    XCTAssert([self isArrayEqual:tx.outputAddresses and:@[satoshiAddr]]);
    XCTAssert([self isArrayEqual:tx.inputHashes and:@[[[@"00000000000000000000000000000002" hexToData] reverse]]]);
    XCTAssert([self isArrayEqual:tx.inputIndexes and:@[@(0)]]);

    tx = [address txForAmounts:@[@(80000)] andAddress:@[satoshiAddr] andError:&error];
    XCTAssertEqual(1, tx.inputIndexes.count);
    array = @[@(80000), @(10000)];
    XCTAssert([self isArrayEqual:tx.outputAmounts and:array]);
    array = @[satoshiAddr, bitherAddr];
    XCTAssert([self isArrayEqual:tx.outputAddresses and:array]);
    XCTAssert([self isArrayEqual:tx.inputHashes and:@[[[@"00000000000000000000000000000002" hexToData] reverse]]]);
    XCTAssert([self isArrayEqual:tx.inputIndexes and:@[@(0)]]);

    tx = [address txForAmounts:@[@(89999)] andAddress:@[satoshiAddr] andError:&error];
    XCTAssertEqual(1, tx.inputIndexes.count);
    array = @[@(89999), @(1)];
    XCTAssert([self isArrayEqual:tx.outputAmounts and:array]);
    array = @[satoshiAddr, bitherAddr];
    XCTAssert([self isArrayEqual:tx.outputAddresses and:array]);
    XCTAssert([self isArrayEqual:tx.inputHashes and:@[[[@"00000000000000000000000000000002" hexToData] reverse]]]);
    XCTAssert([self isArrayEqual:tx.inputIndexes and:@[@(0)]]);

    // when change < fee per kb, and add change will cause increase fee. so ignore change is a good option.
    NSMutableArray *amounts1 = [NSMutableArray new];
    NSMutableArray *addresses1 = [NSMutableArray new];
    for (int i = 0; i < 24; i++){
        [amounts1 addObject:@(3560)];
        [addresses1 addObject:satoshiAddr];
    }
//    tx = [address txForAmounts:amounts1 andAddress:addresses1];
//    XCTAssertEqual(1, tx.inputIndexes.count);
//    XCTAssertEqual(24, tx.outputAddresses.count);

    BTTx *txItem2 = [self formatTx:@[@"00000000000000000000000000000004", @302402, @[@[@0, @"00000000000000000000000000000003", @0]], @[
            @[@0, @"2", @100000, @"1BsTwoMaX3aYx9Nc8GdgHZzzAGmG669bC3"]
    ]
    ]];
    [provider add:txItem2];

    tx = [address txForAmounts:@[@(90000)] andAddress:@[satoshiAddr] andError:&error];
    XCTAssertEqual(1, tx.inputIndexes.count);
    array = @[@(90000)];
    XCTAssert([self isArrayEqual:tx.outputAmounts and:array]);
    XCTAssert([self isArrayEqual:tx.outputAddresses and:@[satoshiAddr]]);
    XCTAssert([self isArrayEqual:tx.inputHashes and:@[[[@"00000000000000000000000000000002" hexToData] reverse]]]);
    XCTAssert([self isArrayEqual:tx.inputIndexes and:@[@(0)]]);

    tx = [address txForAmounts:@[@(80000)] andAddress:@[satoshiAddr] andError:&error];
    XCTAssertEqual(1, tx.inputIndexes.count);
    array = @[@(80000), @(10000)];
    XCTAssert([self isArrayEqual:tx.outputAmounts and:array]);
    array = @[satoshiAddr, bitherAddr];
    XCTAssert([self isArrayEqual:tx.outputAddresses and:array]);
    XCTAssert([self isArrayEqual:tx.inputHashes and:@[[[@"00000000000000000000000000000002" hexToData] reverse]]]);
    XCTAssert([self isArrayEqual:tx.inputIndexes and:@[@(0)]]);

    tx = [address txForAmounts:@[@(89999)] andAddress:@[satoshiAddr] andError:&error];
    XCTAssertEqual(2, tx.inputIndexes.count);
    array = @[@(89999), @(100001)];
    XCTAssert([self isArrayEqual:tx.outputAmounts and:array]);
    array = @[satoshiAddr, bitherAddr];
    XCTAssert([self isArrayEqual:tx.outputAddresses and:array]);
    array = @[[[@"00000000000000000000000000000002" hexToData] reverse], [[@"00000000000000000000000000000004" hexToData] reverse]];
    XCTAssert([self isArrayEqual:tx.inputHashes and:array]);
    array = @[@(0), @(0)];
    XCTAssert([self isArrayEqual:tx.inputIndexes and:array]);

//    tx = [address txForAmounts:amounts1 andAddress:addresses1];
//    XCTAssertEqual(1, tx.inputIndexes.count);
//    XCTAssertEqual(24, tx.outputAddresses.count);

    BTTx *txItem3 = [self formatTx:@[@"00000000000000000000000000000006", @302404, @[@[@0, @"00000000000000000000000000000005", @0]], @[
            @[@0, @"3", @500000, @"1BsTwoMaX3aYx9Nc8GdgHZzzAGmG669bC3"]
    ]
    ]];
    [provider add:txItem3];

    tx = [address txForAmounts:@[@(90000)] andAddress:@[satoshiAddr] andError:&error];
    XCTAssertEqual(1, tx.inputIndexes.count);
    array = @[@(90000), @(400000)];
    XCTAssert([self isArrayEqual:tx.outputAmounts and:array]);
    array = @[satoshiAddr, bitherAddr];
    XCTAssert([self isArrayEqual:tx.outputAddresses and:array]);
    XCTAssert([self isArrayEqual:tx.inputHashes and:@[[[@"00000000000000000000000000000006" hexToData] reverse]]]);
    XCTAssert([self isArrayEqual:tx.inputIndexes and:@[@(0)]]);

    tx = [address txForAmounts:@[@(80000)] andAddress:@[satoshiAddr] andError:&error];
    XCTAssertEqual(1, tx.inputIndexes.count);
    array = @[@(80000), @(410000)];
    XCTAssert([self isArrayEqual:tx.outputAmounts and:array]);
    array = @[satoshiAddr, bitherAddr];
    XCTAssert([self isArrayEqual:tx.outputAddresses and:array]);
    XCTAssert([self isArrayEqual:tx.inputHashes and:@[[[@"00000000000000000000000000000006" hexToData] reverse]]]);
    XCTAssert([self isArrayEqual:tx.inputIndexes and:@[@(0)]]);

    tx = [address txForAmounts:@[@(89999)] andAddress:@[satoshiAddr] andError:&error];
    XCTAssertEqual(1, tx.inputIndexes.count);
    array = @[@(89999), @(400001)];
    XCTAssert([self isArrayEqual:tx.outputAmounts and:array]);
    array = @[satoshiAddr, bitherAddr];
    XCTAssert([self isArrayEqual:tx.outputAddresses and:array]);
    array = @[[[@"00000000000000000000000000000006" hexToData] reverse]];
    XCTAssert([self isArrayEqual:tx.inputHashes and:array]);
    array = @[@(0)];
    XCTAssert([self isArrayEqual:tx.inputIndexes and:array]);

    // unfortunately, it doesn't the best choice.
//    tx = [address txForAmounts:amounts1 andAddress:addresses1];
//    XCTAssertEqual(1, tx.inputIndexes.count);
//    XCTAssertEqual(25, tx.outputAddresses.count);
//    XCTAssertEqual(394560, [tx.outputAmounts[24] unsignedLongLongValue]);

}

- (BOOL)isArrayEqual:(NSArray *)array1 and:(NSArray *)array2;{
    if ([array1 count] != [array1 count]) return NO;
    for (NSUInteger i = 0; i < [array1 count]; i++) {
        if (![array1[i] isEqual:array2[i]])
            return NO;
    }
    return YES;
}

- (BTTx *)formatTx:(NSArray *)array;{
    BTTx *txItem = [BTTx new];
    txItem.txHash = [[array[0] hexToData] reverse];
    txItem.blockNo = [array[1] unsignedIntValue];
    txItem.ins = [NSMutableArray new];
    for (NSArray *sub in array[2]) {
        BTIn *inItem = [BTIn new];
        inItem.txHash = txItem.txHash;
        inItem.inSn = [sub[0] unsignedIntValue];
        inItem.prevTxHash = [[sub[1] hexToData] reverse];
        inItem.prevOutSn = [sub[2] unsignedIntValue];
        inItem.tx = txItem;
        [txItem.ins addObject:inItem];
    }
    txItem.outs = [NSMutableArray new];
    for (NSArray *sub in array[3]) {
        BTOut *outItem = [BTOut new];
        outItem.txHash = txItem.txHash;
        outItem.outSn = [sub[0] unsignedIntValue];
        outItem.outScript = [[sub[1] hexToData] reverse];
        outItem.outValue = [sub[2] unsignedLongLongValue];
        outItem.outAddress = sub[3];
        outItem.tx = txItem;
        outItem.outStatus = unspent;
        [txItem.outs addObject:outItem];
    }
    return txItem;
}

@end
