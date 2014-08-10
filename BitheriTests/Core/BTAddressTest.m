//
//  BTAddressTest.m
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
#import "BTAddressManager.h"
#import "BTTestHelper.h"

@interface BTAddressTest : XCTestCase

@end

@implementation BTAddressTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [BTTestHelper setup];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
//    NSString *documentsPath = paths[0];

//    NSString * privDir=[documentsPath stringByAppendingPathComponent:@"hot"];
//    NSString * watchOnly=[documentsPath stringByAppendingPathComponent:@"watchonly"];

    //  NSArray *array = [[BTAddressProvider instance] getAllAddresses];
//    BTAddressManager *addressManager = [BTAddressManager sharedInstance];
//[addressManager setPrivateKeyDir:privDir];
    //  [addressManager setWatchOnlyDir:watchOnly];
    //5KYZdUEo39z3FPrtuX2QbbwGnNP5zTd7yyr2SC1j299sBCnWjss private key
    BTKey *key = [BTKey keyWithPublicKey:[@"04a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd5b8dec5235a0fa8722476c7709c02559e3aa73aa03918ba2d492eea75abea235" hexToData]];
    BTAddress *btAddress = [[BTAddress alloc] initWithKey:key encryptPrivKey:nil];


    DDLogDebug(@"address ,%@", btAddress.address);

    XCTAssertTrue([btAddress.address isEqualToString:@"1HZwkjkeaoZfTSaJxDw6aKkxp45agDiEzN"], @"add address");
    //[[BTAddressManager sharedInstance] addPrivKeyByRandomWithPassphrase:@"123456"];
    //[[BTAddressManager sharedInstance] allAddresses];
    //NSArray * privats= [[BTAddressManager sharedInstance] privKeyAddresses];
    //XCTAssertTrue(privats.count>0, @"add private key success");

}

@end
