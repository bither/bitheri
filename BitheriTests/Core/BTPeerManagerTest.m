//
//  BTPeerManagerTest.m
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
#import "BTPeerManager.h"
#import "BTTestHelper.h"


@interface BTPeerManagerTest : XCTestCase
@property (nonatomic ,strong) NSString * privDir;
@property (nonatomic ,strong) NSString * watchOnly;

@end



@implementation BTPeerManagerTest

- (void)setUp
{
    [super setUp];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [paths objectAtIndex:0];
    self.privDir=[documentsPath stringByAppendingPathComponent:@"hot"];
    self.watchOnly=[documentsPath stringByAppendingPathComponent:@"watchonly"];
    NSFileManager *fileManager= [NSFileManager defaultManager];
    [fileManager removeItemAtPath:self.privDir error:nil];
    [fileManager removeItemAtPath:self.watchOnly error:nil];
    [BTTestHelper setup];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
   
//#define MAX_CONNECTIONS       1
    NSString *bitcoinjStr = @"06ABC638E15A2E4A3224F35C45C3BF653ACB3D217E9687641B3D118CEAFC1164B3AC4114472A14185802D19AA380BEA4:A4EAEB1E0C2F877A2869BD3823245BA1:B34C4A53489A4A9B";
 
    BTAddressManager *addressManager=[BTAddressManager instance];
   // [addressManager setPrivateKeyDir:self.privDir];
    //[addressManager setWatchOnlyDir:self.watchOnly];
    [addressManager initAddress];
    if ([addressManager privKeyAddresses].count==0) {
        BTAddress * address=[[BTAddress alloc] initWithBitcoinjKey:bitcoinjStr withPassphrase:@"111111"];
        [[[BTAddressManager instance] privKeyAddresses] addObject:address];
    }
    [[BTPeerManager instance] start];

    XCTAssertTrue([[BTAddressManager instance] privKeyAddresses].count>0, @"add private key success");

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncDone) name:BTPeerManagerSyncFinishedNotification object:nil];

//    while (YES) {
//        sleep(100000);
//    }

}

- (void)syncDone{
    for (BTPeer *peer in [NSSet setWithSet:[BTPeerManager instance].connectedPeers]){
        [peer refetchBlocksFrom:[[@"00000000000000006b34a0ade7489801ab663b78147c126518ea9c499cb65953" hexToData] reverse]];
    }
}

@end
