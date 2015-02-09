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
#import "BTBloomFilter.h"
#import "NSString+Base58.h"
#import "BTSettings.h"
#import "BTTestHelper.h"

@interface BTBloomFilterTest : XCTestCase

@end

@implementation BTBloomFilterTest

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

- (void)testExample
{
    BTBloomFilter * filter=[[BTBloomFilter alloc] initWithFalsePositiveRate:0.01 forElementCount:3 tweak:0 flags:BLOOM_UPDATE_ALL];
    
    [filter insertData:[@"99108ad8ed9bb6274d3980bab5a85c048f0950c8" hexToData]];
    [filter insertData:[@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee" hexToData]];
    [filter insertData:[@"b9300670b4c5366e95b2699e8b18bc75e5f729c5" hexToData]];
   
    DDLogInfo(@"str %s",[[NSString hexWithData:filter.data] UTF8String]);
    XCTAssertTrue([@"03614E9B050000000000000001" isEqualToString:[NSString hexWithData:filter.data]]," bloomFilter");
    
    
    filter=[[BTBloomFilter alloc] initWithFalsePositiveRate:0.01 forElementCount:3 tweak:2147483649 flags:BLOOM_UPDATE_P2PUBKEY_ONLY];
    
    [filter insertData:[@"99108ad8ed9bb6274d3980bab5a85c048f0950c8" hexToData]];
    [filter insertData:[@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee" hexToData]];
    [filter insertData:[@"b9300670b4c5366e95b2699e8b18bc75e5f729c5" hexToData]];

    DDLogInfo(@"str %s",[[NSString hexWithData:filter.data] UTF8String]);
    XCTAssertTrue([@"03CE4299050000000100008002" isEqualToString:[NSString hexWithData:filter.data]]," bloomFilter");
  //  XCTAssertTrue(1==1, [NSString hexWithData:filter.data]);
    //XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

- (void)testBloomFilter
{
    BTBloomFilter *f = [[BTBloomFilter alloc] initWithFalsePositiveRate:.01 forElementCount:3 tweak:0
                                                                  flags:BLOOM_UPDATE_ALL];

    [f insertData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData];

    XCTAssertTrue([f containsData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData],
                    @"[BRBloomFilter containsData:]");

    // one bit difference
    XCTAssertFalse([f containsData:@"19108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData],
                    @"[BRBloomFilter containsData:]");

    [f insertData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".hexToData];

    XCTAssertTrue([f containsData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".hexToData],
                    @"[BRBloomFilter containsData:]");

    [f insertData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".hexToData];

    XCTAssertTrue([f containsData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".hexToData],
                    @"[BRBloomFilter containsData:]");

    // check against satoshi client output
    XCTAssertEqualObjects(@"03614e9b050000000000000001".hexToData, f.data, @"[BRBloomFilter data:]");
}

- (void)testBloomFilterWithTweak
{
    BTBloomFilter *f = [[BTBloomFilter alloc] initWithFalsePositiveRate:.01 forElementCount:3 tweak:2147483649
                                                                  flags:BLOOM_UPDATE_P2PUBKEY_ONLY];

    [f insertData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData];

    XCTAssertTrue([f containsData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData],
                    @"[BRBloomFilter containsData:]");

    // one bit difference
    XCTAssertFalse([f containsData:@"19108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData],
                    @"[BRBloomFilter containsData:]");

    [f insertData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".hexToData];

    XCTAssertTrue([f containsData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".hexToData],
                    @"[BRBloomFilter containsData:]");

    [f insertData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".hexToData];

    XCTAssertTrue([f containsData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".hexToData],
                    @"[BRBloomFilter containsData:]");

    // check against satoshi client output
    XCTAssertEqualObjects(@"03ce4299050000000100008002".hexToData, f.data, @"[BRBloomFilter data:]");
}

@end
