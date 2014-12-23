//
//  BTBloomFilterTest.m
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
#import <OpenSSL/openssl/bn.h>
#import "BTBloomFilter.h"
#import "NSString+Base58.h"
#import "BTSettings.h"
#import "BTTestHelper.h"
#import "ossl_typ.h"
#import "BTKey.h"

@interface BTKeyTest : XCTestCase

@end

@implementation BTKeyTest

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [BTTestHelper setup];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNormal; {
    BTKey *key = [BTKey keyWithSecret:[@"0000000000000000000000000000000000000000000000000000000000000001" hexToData] compressed:YES];
    NSString *message = @"1";
    NSString *expectSignedMessage = @"H0zWA4TC71RRt8WZo/h5Kium1lPMxgxNKKm+W8OLZ/2lGTQb7iLe2tnM3P7IJX+R5K+HhDgedZElqDyV33aln0o=";

    NSString *signedMessage = [key signMessage:message];
    XCTAssertTrue([signedMessage isEqualToString:expectSignedMessage]);
    XCTAssertTrue([key verifyMessage:message andSignatureBase64:signedMessage]);

    message = @"1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890";
    expectSignedMessage = @"H5xZUmZQzxP5eDnhsDUeEEpyutiPUfDEJ1rABSOWwsfJZxItKaVWIe6V9U7GnjnuNAcLMP6hwWXhGc25V7DN0B4=";

    signedMessage = [key signMessage:message];
    XCTAssertTrue([signedMessage isEqualToString:expectSignedMessage]);
    XCTAssertTrue([key verifyMessage:message andSignatureBase64:signedMessage]);

    message = @"比太钱包";
    expectSignedMessage = @"IBkXZi4cd0pAeyBJv5qUg7s8ggGqjSiRhVmvb5H+KR5uSZdj5lhgCFVnii5W3TUJCxGe4WiHRXgNPTtbjJk4myk=";

    signedMessage = [key signMessage:message];
    XCTAssertTrue([signedMessage isEqualToString:expectSignedMessage]);
    XCTAssertTrue([key verifyMessage:message andSignatureBase64:signedMessage]);
}
@end
