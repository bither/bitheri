//
//  BTPeerProvider.h
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

#import <Foundation/Foundation.h>
#import "BTPeer.h"


@interface BTPeerProvider : NSObject
+ (instancetype)instance;

- (NSMutableArray *)getAllPeers;

- (void)deletePeersNotInAddresses:(NSSet *)peerAddresses;

- (NSArray *)exists:(NSSet *)peerAddresses;

- (void)addPeers:(NSArray *)peers;

- (void)updatePeersTimestamp:(NSArray *)peerAddresses;

- (void)removePeer:(uint)address;

- (void)connectFail:(uint)address;

- (void)connectSucceed:(uint)address;

- (NSArray *)getPeersWithLimit:(int)limit;

- (void)cleanPeers;

- (void)recreate;

@end