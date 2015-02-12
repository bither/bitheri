//
//  BTBip32Test.m
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
#import <CommonCrypto/CommonHMAC.h>
#import "BTTestHelper.h"
#import "BTBIP32Key.h"
#import "BTKey.h"

@interface BTBip32Test : XCTestCase
@end

@implementation BTBip32Test {

}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [BTTestHelper setup];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBIP44Derivation; {
    NSArray *testCase = @[
            @[@"000102030405060708090a0b0c0d0e0f",
                    @[@"1NQpH6Nf8QtR2HphLRcvuVqfhXBXsiWn8r",
                            @"16qTdEma9YHFPCZ8sB51nNrbfVg8Nkzy6P",
                            @"1JbFSv4FnJ6ykAmAAMSsfb17xPDRxa3mcd",
                            @"1LUMqSxParVVQd6JJUFz4hkyw2RRg5kd9p",
                            @"1ABrPtQMVG2HXeTFdBxFMnFZGXDfBxX6W",
                            @"1BAe3RWgFyYSYinqMgcYeSn6KhMQiVcq5J",
                            @"1G4oGpkb8CSaieD42RWDAvdQXSvTyGb3FA",
                            @"1NfeW33XrsfpbT9kX8bC7drvM15LEowY1f",
                            @"1NYGvtvJhfz3rYmgvZfnseage7HVniLRwK",
                            @"14cC65dm9D13VezMRramp1EjT5Y8DCjj5R",
                            @"1DsTjmQobAy5fDbpwmdX32U7vLRJpBevXx",
                            @"135CAdKgYEH4sL2VHjDZc833L29WeyUgmk",
                            @"1DbvjkgJkcJF9km7ki1uvGPRu7ETCqBnad",
                            @"1Jk3CjrCatH65zcP2ni8UW2GS2UWZZ46kG",
                            @"181bA8aBHBZ7NhvPCqAYCrgC5K8BwJ3XpS",
                            @"1JhwVsrRsJadq7i3bAdYpQS1bjNb7GRmQW",
                            @"1F7B49jJJ7X6mX6XCtaydNq6LMzTmtuE72",
                            @"13G7g5H6T9zMbuTqutkRem9oAcPRRGkiQo",
                            @"19sPx9DVWzNjzMzPiAKfYZDHjwF5XKH7WU",
                            @"1M7kvm32Ph3jWzqn3pQZ9bVJdQHjcV3tJA"]],
            @[@"fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542",
                    @[@"148CGtv7bwcC933EHtcDfzDQVneur1R8Y1",
                            @"1FQEcNEtCxvwonGfPkhPqtV2VvjTjVUPv4",
                            @"1Nb924nRs93gWVeFnaKH1EE8uLqWGfdkXE",
                            @"1FUrDVP9aAZnefDnRXv8hTpf19azZXpaeP",
                            @"1EMeFCRSGDWPsj6tbAhNDA4hPYojQTTt6j",
                            @"16a3wuHwxQE9bxQGqnDcq2Yt6S38ytJjXS",
                            @"1L1cztrRabU7cZXJ9sNy2Qp6kyuKRtmShY",
                            @"1ABce5juqXU9kMcXB28nBX8YiVX4QDfc5M",
                            @"19cTzpjQhLREgLhdJ6SUVkvq7YM6qe1ztu",
                            @"1PRyyd3arghaUujUDQMJLT98kQ2rA51jnX",
                            @"1AatH1T4wHYLLMMZ5qezGL45x2DZVRSyS2",
                            @"1D3JYnnzyr9WkfGDTiaAyauDg6jtXafzuo",
                            @"1B1oizv2k7LSAvqJV7uJo7nwADG4p1QFEH",
                            @"1LbVR7961aM17TxQ8YGCBXCGrVU3hXKwkt",
                            @"1HmPuSrsY9EiiYSo1FwsR2y8ioTjS7dumX",
                            @"1NkxysTqFUCJpmsSHMY2fV2L4HKBRdV22",
                            @"15PRP8A78kGKs4zqRiwemmEFdnpFuMN3Sq",
                            @"1LMMyBTYfeWsPENV3q8YcE33WAsmhAhsqL",
                            @"14prWPkDNZDEfzd45wMQjcgKC237Fpijcy",
                            @"16JjGehJxXNXzwyCsUdu8TFFAh91yio3UU"]]];

    for (uint i = 0; i < testCase.count; i++) {
        NSData *seed = [testCase[i][0] hexToData];
        BTBIP32Key *master = [[BTBIP32Key alloc] initWithSeed:seed];
        BTBIP32Key *purpose = [master deriveHardened:44];
        BTBIP32Key *coinType = [purpose deriveHardened:0];
        BTBIP32Key *account = [coinType deriveHardened:0];
        BTBIP32Key *externalPriv = [account deriveSoftened:0];
        BTBIP32Key *externalPub = [account deriveSoftened:0];
        [externalPub clearPrivateKey];

        NSArray *addresses = testCase[i][1];
        for (uint j = 0; i < addresses.count; i++) {
            NSString *addressFromPriv = [externalPriv deriveSoftened:j].address;
            NSString *addressFromPub = [externalPub deriveSoftened:j].address;
            XCTAssertTrue([addresses[j] isEqualToString:addressFromPriv]);
            XCTAssertTrue([addresses[j] isEqualToString:addressFromPub]);
        }
    }
}

- (void)testDerivationFromPubExtended; {
    NSArray *testCase = @[
            @[@"02eb41548e5e08da531ff2e6feffeb59055231920d3a87cc49e2dffd095644d9296b3e950f9630d5cd6f671ec5e1e45486df9b1688b75650e97596a1ec181de8a8",
                    @[@"1NQpH6Nf8QtR2HphLRcvuVqfhXBXsiWn8r",
                            @"16qTdEma9YHFPCZ8sB51nNrbfVg8Nkzy6P",
                            @"1JbFSv4FnJ6ykAmAAMSsfb17xPDRxa3mcd",
                            @"1LUMqSxParVVQd6JJUFz4hkyw2RRg5kd9p",
                            @"1ABrPtQMVG2HXeTFdBxFMnFZGXDfBxX6W",
                            @"1BAe3RWgFyYSYinqMgcYeSn6KhMQiVcq5J",
                            @"1G4oGpkb8CSaieD42RWDAvdQXSvTyGb3FA",
                            @"1NfeW33XrsfpbT9kX8bC7drvM15LEowY1f",
                            @"1NYGvtvJhfz3rYmgvZfnseage7HVniLRwK",
                            @"14cC65dm9D13VezMRramp1EjT5Y8DCjj5R",
                            @"1DsTjmQobAy5fDbpwmdX32U7vLRJpBevXx",
                            @"135CAdKgYEH4sL2VHjDZc833L29WeyUgmk",
                            @"1DbvjkgJkcJF9km7ki1uvGPRu7ETCqBnad",
                            @"1Jk3CjrCatH65zcP2ni8UW2GS2UWZZ46kG",
                            @"181bA8aBHBZ7NhvPCqAYCrgC5K8BwJ3XpS",
                            @"1JhwVsrRsJadq7i3bAdYpQS1bjNb7GRmQW",
                            @"1F7B49jJJ7X6mX6XCtaydNq6LMzTmtuE72",
                            @"13G7g5H6T9zMbuTqutkRem9oAcPRRGkiQo",
                            @"19sPx9DVWzNjzMzPiAKfYZDHjwF5XKH7WU",
                            @"1M7kvm32Ph3jWzqn3pQZ9bVJdQHjcV3tJA"]],
            @[@"02bee19a4c2f6f5f783eac772fff603effee27a65554727ed8cc5a1b94912d2231940e149c2a81e8a7bf266e616ff9c3384ec67dc5ac9fc21ac38217ee8603d30b",
                    @[@"148CGtv7bwcC933EHtcDfzDQVneur1R8Y1",
                            @"1FQEcNEtCxvwonGfPkhPqtV2VvjTjVUPv4",
                            @"1Nb924nRs93gWVeFnaKH1EE8uLqWGfdkXE",
                            @"1FUrDVP9aAZnefDnRXv8hTpf19azZXpaeP",
                            @"1EMeFCRSGDWPsj6tbAhNDA4hPYojQTTt6j",
                            @"16a3wuHwxQE9bxQGqnDcq2Yt6S38ytJjXS",
                            @"1L1cztrRabU7cZXJ9sNy2Qp6kyuKRtmShY",
                            @"1ABce5juqXU9kMcXB28nBX8YiVX4QDfc5M",
                            @"19cTzpjQhLREgLhdJ6SUVkvq7YM6qe1ztu",
                            @"1PRyyd3arghaUujUDQMJLT98kQ2rA51jnX",
                            @"1AatH1T4wHYLLMMZ5qezGL45x2DZVRSyS2",
                            @"1D3JYnnzyr9WkfGDTiaAyauDg6jtXafzuo",
                            @"1B1oizv2k7LSAvqJV7uJo7nwADG4p1QFEH",
                            @"1LbVR7961aM17TxQ8YGCBXCGrVU3hXKwkt",
                            @"1HmPuSrsY9EiiYSo1FwsR2y8ioTjS7dumX",
                            @"1NkxysTqFUCJpmsSHMY2fV2L4HKBRdV22",
                            @"15PRP8A78kGKs4zqRiwemmEFdnpFuMN3Sq",
                            @"1LMMyBTYfeWsPENV3q8YcE33WAsmhAhsqL",
                            @"14prWPkDNZDEfzd45wMQjcgKC237Fpijcy",
                            @"16JjGehJxXNXzwyCsUdu8TFFAh91yio3UU"]]];

    for (uint i = 0; i < testCase.count; i++) {
        NSData *masterPubKey = [testCase[i][0] hexToData];
        BTBIP32Key *externalPub = [[BTBIP32Key alloc] initWithMasterPubKey:masterPubKey];

        NSArray *addresses = testCase[i][1];
        for (uint j = 0; i < addresses.count; i++) {
            NSString *addressFromPub = [externalPub deriveSoftened:j].address;
            XCTAssertTrue([addresses[j] isEqualToString:addressFromPub]);
        }
    }
}
@end