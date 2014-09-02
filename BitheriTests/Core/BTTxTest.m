//
//  BTTxTest.m
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
#import "BTTx.h"
#import "BTTxTestData.h"
#import "BTTxProvider.h"
#import "BTTestHelper.h"
#import "BTScript.h"

@interface BTTxTest : XCTestCase

@end

@implementation BTTxTest

- (void)setUp {
    [super setUp];
    [BTTestHelper setup];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    NSData *message = [@"0100000001aca65b5136b23c9fff015ad460a83a2f5837575392dc3ecabcb57c41e10e0fa1010000006a47304402202a6686876d07c13e9189b035e54ca91d56b89a67d86dcc012183d5b2d1e7244b02204f8ad90dd70c0f797877ad69fc543d6459be99dac9d325f3858486bf0975dd9a0121034285edc746e4c8b4e9f022ee0a561f0b9d5a29e1e44e87e77b2156ecf2c45265ffffffff0210270000000000001976a914773c8c5f0d5904d8755dfdd3207e3ed692966e7e88ac74400000000000001976a91479a7bf0bba8359561d4dab457042d7b632d5e64188ac00000000" hexToData];
    BTTx *tx = [BTTx transactionWithMessage:message];
    XCTAssert(tx != nil);

    NSArray *myPathList = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *myPath = myPathList[0];
    myPath = [myPath stringByAppendingPathComponent:@"1C6FiRktL3UPd4sywhyU5CYSeLdKhvHxhR.tx"];
    NSArray *lines2 = [[NSString stringWithContentsOfFile:myPath encoding:NSUTF8StringEncoding error:nil] componentsSeparatedByString:@"\n"];
    NSArray *lines = [rawTxs componentsSeparatedByString:@"\n"];
    XCTAssert(25 == [lines count]);
    for (NSString *each in lines2) {
        BTTx *tx1 = [BTTx transactionWithMessage:[each hexToData]];
        XCTAssert([[[tx1 toData] SHA256_2] isEqualToData:tx1.txHash]);
        XCTAssert([tx1 verifySignatures]);
        [[BTTxProvider instance] add:[tx1 formatToTxItem]];
        BTTx *tx2 = [BTTx txWithTxItem:[[BTTxProvider instance] getTxDetailByTxHash:tx1.txHash]];
        XCTAssert([[[tx2 toData] SHA256_2] isEqualToData:tx2.txHash]);
        XCTAssert([tx1 isEqual:tx2]);

        tx1.txVer += 1;
        XCTAssert(![[[tx1 toData] SHA256_2] isEqualToData:tx1.txHash]);
//    XCTAssert(tx1.isSigned);
    }

}

- (void)testSignature;{
    BTTx *tx = [BTTx transactionWithMessage:[@"0100000001bdc0141fe3e5c2223a6d26a95acbf791042d93f9d9b8b38f133bf7adb5c1e293010000006a47304402202214770c0f5a9261190337273219a108132a4bc987c745db8dd6daded34b0dcb0220573de1d973166024b8342d6b6fef2a864a06cceee6aee13a910e5d8df465ed2a01210382b259804ad8d88b96a23222e24dd5a130d39588e78960c9e9b48a5b49943649ffffffff02a0860100000000001976a91479a7bf0bba8359561d4dab457042d7b632d5e64188ac605b0300000000001976a914b036c529faeca8040232cc4bd5918e709e90c4ff88ac00000000" hexToData]];
    BTTx *prevTx = [BTTx transactionWithMessage:[@"0100000003850f7d492919b727bc5b6f4e8ff79832b21cb130cd2ba5becbeebb5b6c31f735010000006b483045022100ae7e882f7060ea95b9796e497e880bad86729dd9599dd92ddc4b2f64be9a41a502201e7c654625c7a5cee1c0180f60f28f01bba436117de81b74ab42ab29d670afb901210382b259804ad8d88b96a23222e24dd5a130d39588e78960c9e9b48a5b49943649ffffffff2047de51e68233154c9c54327b7cb529c98eaf059d163cd75d0c315f8c6d92d1000000006b483045022100d776746344d6391a6bdc125e700acdb3e4451c2cd9027fb05c836a90ebaa92f202204eaf72cc222f7453adf34fa57b86e7b8d04c6b82242168c8eaff5574c52a061601210382b259804ad8d88b96a23222e24dd5a130d39588e78960c9e9b48a5b49943649ffffffffcd2cc68259e9f826e3512a705ba76bc928c461a81eb6b50a7a78e054a393c113000000006a47304402203eaa69c740136262ee623cbd5c110b05d881bec5ffb1a52ec09fa5ed845926a402206fc655625560761fa5d5a4da1858765f9693f3d269b95e6730fa2e4b00036cb001210382b259804ad8d88b96a23222e24dd5a130d39588e78960c9e9b48a5b49943649ffffffff02a0860100000000001976a914d517e80dd73ebea6b086856974b6ca416b7a8be788ac10090500000000001976a914b036c529faeca8040232cc4bd5918e709e90c4ff88ac00000000" hexToData]];

    BOOL valid = YES;
    for (NSUInteger i = 0; i < tx.inputIndexes.count; i++) {
        if ([tx.inputHashes[i] isEqualToData:prevTx.txHash]) {
            if ([tx.inputIndexes[i] unsignedIntValue] < prevTx.outputAddresses.count) {
                NSData *outScript = prevTx.outputScripts[[tx.inputIndexes[i] unsignedIntValue]];
                BTScript *pubKeyScript = [[BTScript alloc] initWithProgram:outScript];
                BTScript *script = [[BTScript alloc] initWithProgram:tx.inputSignatures[i]];
                script.tx = tx;
                script.index = i;
                valid &= [script correctlySpends:pubKeyScript and:YES];
            } else {
                valid = NO;
            }
            if (!valid)
                break;
        }
    }
    XCTAssert(valid);

    BTTx *bip16Tx1 = [BTTx transactionWithMessage:[@"010000000189632848f99722915727c5c75da8db2dbf194342a0429828f66ff88fab2af7d6000000008b483045022100abbc8a73fe2054480bda3f3281da2d0c51e2841391abd4c09f4f908a2034c18d02205bc9e4d68eafb918f3e9662338647a4419c0de1a650ab8983f1d216e2a31d8e30141046f55d7adeff6011c7eac294fe540c57830be80e9355c83869c9260a4b8bf4767a66bacbd70b804dc63d5beeb14180292ad7f3b083372b1d02d7a37dd97ff5c9effffffff0140420f000000000017a914f815b036d9bbbce5e9f2a00abd1bf3dc91e955108700000000" hexToData]];
    BTTx *bip16Tx2 = [BTTx transactionWithMessage:[@"0100000001aca7f3b45654c230e0886a57fb988c3044ef5e8f7f39726d305c61d5e818903c00000000fd5d010048304502200187af928e9d155c4b1ac9c1c9118153239aba76774f775d7c1f9c3e106ff33c0221008822b0f658edec22274d0b6ae9de10ebf2da06b1bbdaaba4e50eb078f39e3d78014730440220795f0f4f5941a77ae032ecb9e33753788d7eb5cb0c78d805575d6b00a1d9bfed02203e1f4ad9332d1416ae01e27038e945bc9db59c732728a383a6f1ed2fb99da7a4014cc952410491bba2510912a5bd37da1fb5b1673010e43d2c6d812c514e91bfa9f2eb129e1c183329db55bd868e209aac2fbc02cb33d98fe74bf23f0c235d6126b1d8334f864104865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac09ef122b1a986818a7cb624532f062c1d1f8722084861c5c3291ccffef4ec687441048d2455d2403e08708fc1f556002f1b6cd83f992d085097f9974ab08a28838f07896fbab08f39495e15fa6fad6edbfb1e754e35fa1c7844c41f322a1863d4621353aeffffffff0140420f00000000001976a914ae56b4db13554d321c402db3961187aed1bbed5b88ac00000000" hexToData]];
    NSArray *outAddresses = bip16Tx1.outputAddresses;

    BTTx *tx1 = [BTTx transactionWithMessage:[@"0100000001936b03047a2614a2b7e3a2521aac1d98f447a878941db79fdc29cb3fe26e7cc5010000006a473044022047587eab41bad5d0adce478afdf2cab652864d5af63d56f80eb8d23cea4d74cd02202e4cff5183f0fac087bf7e8819050ad6eca1d63856b8e644c845faf3bb6f193b01210208303671d564fc8ee33a4b2328a67aa425aae5a133ebf7d681d0fa92a24024caffffffff02d3611006000000001976a914b8577a6adeaee38c2ba8b9b81f7a4217ffb4c93188acc7a98061390000001976a91416a0d00dec851b90a047742272ab450fc09deabd88ac00000000" hexToData]];
    BTTx *tx2 = [BTTx transactionWithMessage:[@"0100000001befc391d10d0b8fde93ba5df43e1a943fd919e3540c69638198c8c9b607b0009010000006a473044022007cbe723cea232d58ac3cd98146a216035ba556143c301157470d7b4f6d5751f022077520380a2471d6dc0ef43039ac4b51fd4d80e6d94037c42ec0ef167308b693601210208303671d564fc8ee33a4b2328a67aa425aae5a133ebf7d681d0fa92a24024caffffffff02a0e91105000000001976a914613fc91e20cffbcfcb0c43dcaebb97bd975d92eb88acaa329167390000001976a91416a0d00dec851b90a047742272ab450fc09deabd88ac00000000" hexToData]];

    BTScript *sigScript = [[BTScript alloc] initWithProgram:tx1.inputSignatures[0]];
    sigScript.tx = tx1;
    sigScript.index = 0;
    BTScript *pubKeyScript = [[BTScript alloc] initWithProgram:tx2.outputScripts[1]];
    BOOL result = [sigScript correctlySpends:pubKeyScript and:YES];
}

@end
