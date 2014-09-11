//
//  BTBlockTests.m
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
#import "BTBlock.h"
#import "NSData+Hash.h"
#import "NSString+Base58.h"
#import "BTBlockProvider.h"
#import <CocoaLumberjack/DDLog.h>
#import "BTSettings.h"
#import "BTTestHelper.h"

@interface BTBlockTests : XCTestCase

@end

@implementation BTBlockTests

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
    /*
    0000000000000000472132c4daaf358acaf461ff1c3e96577a74e5ebf91bb170: {"nonce": 4079278699, "block_no": 302400, "ver": 2, "prev_block": "00000000000000000ee9b585e0a707347d7c80f3a905f48fa32d448917335366", "mrkl_root": "4d60e37c7086096e85c11324d70112e61e74fc38a5c5153587a0271fd22b65c5", "time": 1400928750, "bits": 409544770}
     */
    char *prevhash="00000000000000000ee9b585e0a707347d7c80f3a905f48fa32d448917335366";
    char * merkleHash="4d60e37c7086096e85c11324d70112e61e74fc38a5c5153587a0271fd22b65c5";
    NSData * prevBlock= [NSString stringWithUTF8String:prevhash].hexToData.reverse;
    NSData * merkle=[NSString stringWithUTF8String:merkleHash].hexToData.reverse;
    BTBlock * block=[[BTBlock alloc] initWithVersion:2 prevBlock:prevBlock merkleRoot:merkle timestamp:1400928750 target:409544770 nonce:4079278699 height:302400];
    NSString * str=[NSString hexWithData:block.blockHash.reverse];
    DDLogInfo(@"block %s",[str UTF8String]);
    XCTAssertTrue([str isEqualToString:@"0000000000000000472132c4daaf358acaf461ff1c3e96577a74e5ebf91bb170"], @"hash is error");
    /**
     @"00000000000000000ead30f2a70f979a6b07f841ca05302497a92b3c9a9488a3:{\"nonce\": 3837102513, \"prev_block\": \"00000000000000000401800189014bad6a3ca1af029e19b362d6ef3c5425a8dc\", \"ver\": 2, \"block_no\": 304416, \"mrkl_root\": \"4785b428de83e1462c5e57556a44849344a1341f70220f1720b51d483d748701\", \"time\": 1402004993, \"bits\": 408782234}"
     **/
    
    prevhash="00000000000000000401800189014bad6a3ca1af029e19b362d6ef3c5425a8dc";
    merkleHash="4785b428de83e1462c5e57556a44849344a1341f70220f1720b51d483d748701";
    prevBlock= [NSString stringWithUTF8String:prevhash].hexToData.reverse;
    merkle=[NSString stringWithUTF8String:merkleHash].hexToData.reverse;
    block=[[BTBlock alloc] initWithVersion:2 prevBlock:prevBlock merkleRoot:merkle timestamp:1402004993 target:408782234 nonce:3837102513 height:304416];
    
    str=[NSString hexWithData:block.blockHash.reverse];
    DDLogInfo(@"block %s",[str UTF8String]);
    XCTAssertTrue([str isEqualToString:@"00000000000000000ead30f2a70f979a6b07f841ca05302497a92b3c9a9488a3"], @"hash is error");
    
    
    //insert  block
    NSMutableSet * set =[NSMutableSet set];
    [set addObject:block.blockHash];
//    [[BTBlockProvider instance] deleteBlocksNotInHashes:set];
    [[BTBlockProvider instance] addBlock:block];
    BTBlock * blockItem=  [[BTBlockProvider instance] getBlock:block.blockHash];
    XCTAssertTrue(blockItem, @"insert block success");
//    [[BTBlockProvider instance] deleteBlocksNotInHashes:set];
    XCTAssertTrue([[NSString base58WithData:blockItem.blockHash] isEqualToString:[NSString base58WithData:block.blockHash]], @"delete block success ");
    
    
}

@end
