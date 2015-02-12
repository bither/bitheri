//
//  BTHDMPubsTest.m
//  Bitheri
//
//  Created by 宋辰文 on 15/1/27.
//  Copyright (c) 2015年 Bither. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "BTHDMAddress.h"
#import "NSString+Base58.h"

@interface MultisigAddressTestCase : NSObject
@property BTHDMPubs* pubs;
@property NSString* address;
-(instancetype)initWithHot:(NSString*)hot cold:(NSString*)cold remote:(NSString*)remote andAddress:(NSString *)address;
@end

@interface BTHDMPubsTest : XCTestCase
@end

@implementation MultisigAddressTestCase
-(instancetype)initWithHot:(NSString*)hot cold:(NSString*)cold remote:(NSString*)remote andAddress:(NSString *)address{
    self = [super init];
    if(self){
        self.pubs = [[BTHDMPubs alloc]initWithHot:hot.hexToData cold:cold.hexToData remote:remote.hexToData andIndex:0];
        self.address = address;
    }
    return self;
}

@end

@implementation BTHDMPubsTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testMultisigAddress {
    NSMutableArray* tcs = [NSMutableArray new];
    [tcs addObject:[[MultisigAddressTestCase alloc] initWithHot:@"0491bba2510912a5bd37da1fb5b1673010e43d2c6d812c514e91bfa9f2eb129e1c183329db55bd868e209aac2fbc02cb33d98fe74bf23f0c235d6126b1d8334f86" cold:@"04865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac09ef122b1a986818a7cb624532f062c1d1f8722084861c5c3291ccffef4ec6874" remote:@"048d2455d2403e08708fc1f556002f1b6cd83f992d085097f9974ab08a28838f07896fbab08f39495e15fa6fad6edbfb1e754e35fa1c7844c41f322a1863d46213" andAddress:@"3QJmV3qfvL9SuYo34YihAf3sRCW3qSinyC"]];
    
    for(MultisigAddressTestCase* tc in tcs){
        NSLog(@"program: %@", [NSString hexWithData:tc.pubs.multisigScript.program]);
        NSLog(@"result: %@,   expected: %@", tc.pubs.address, tc.address);
        XCTAssertEqualObjects(tc.pubs.address, tc.address);
    }
}
@end
