//
//  BTPeer.h
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
//
//  Copyright (c) 2013-2014 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <Foundation/Foundation.h>
//#import "BTPeerItem.h"

@class BTPeer, BTTx, BTBlock;

@protocol BTPeerDelegate <NSObject>
@required

- (void)peerConnected:(BTPeer *)peer;

- (void)peer:(BTPeer *)peer disconnectedWithError:(NSError *)error;

- (void)peer:(BTPeer *)peer relayedPeers:(NSArray *)peers;

- (void)peer:(BTPeer *)peer relayedTransaction:(BTTx *)transaction confirmed:(BOOL) confirmed;

// called when the peer relays either a merkleblock or a block header, headers will have 0 totalTransactions
- (void)peer:(BTPeer *)peer relayedBlock:(BTBlock *)block;

- (void)peer:(BTPeer *)peer relayedHeaders:(NSArray *)headers;

- (void)peer:(BTPeer *)peer relayedBlocks:(NSArray *)blocks;

- (BTTx *)peer:(BTPeer *)peer requestedTransaction:(NSData *)txHash;

- (void)requestBloomFilterRecalculate;

- (NSData *)peerBloomFilter:(BTPeer *)peer;

@end

typedef enum {
    BTPeerStatusDisconnected = 0,
    BTPeerStatusConnecting,
    BTPeerStatusConnected
} BTPeerStatus;

@interface BTPeer : NSObject <NSStreamDelegate>

@property(nonatomic, assign) id <BTPeerDelegate> delegate;
//@property (nonatomic, strong) dispatch_queue_t delegateQueue; // default is main queue

// set this to the timestamp when the wallet was created to improve initial sync time (interval since refrence date)
//@property (nonatomic, assign) NSTimeInterval earliestKeyTime;

@property(nonatomic, readonly) BTPeerStatus status;
@property(nonatomic, readonly) NSString *host;

@property(nonatomic, readonly) uint32_t peerAddress;
@property(nonatomic, assign) NSTimeInterval peerTimestamp; // peer 's time stamp not local time stamp, these only use for shown
@property(nonatomic, readonly) uint16_t peerPort;
@property(nonatomic, readonly) uint64_t peerServices;
@property(nonatomic) int peerConnectedCnt;

@property(nonatomic, readonly) uint32_t version;
@property(nonatomic, readonly) uint64_t nonce;
@property(nonatomic, readonly) NSString *userAgent;
@property(nonatomic, readonly) uint32_t versionLastBlock;
@property(nonatomic, readonly) uint32_t displayLastBlock;
@property(nonatomic, readonly) NSTimeInterval pingTime;
@property(nonatomic, assign) NSTimeInterval timestamp; // last seen time (interval since reference date)
@property(nonatomic, readonly) BOOL relayTxesBeforeFilter;
@property(nonatomic, readonly) BOOL canRelayTx;
@property BOOL synchronising;
//@property (nonatomic, assign) int16_t misbehavin;


//+ (instancetype)peerWithAddress:(uint32_t)address andPort:(uint16_t)port;
//
//- (instancetype)initWithAddress:(uint32_t)address andPort:(uint16_t)port;
- (instancetype)initWithAddress:(uint32_t)address port:(uint16_t)port timestamp:(NSTimeInterval)timestamp services:(uint64_t)services;

- (void)connectPeer;

- (void)disconnectPeer;

- (void)disconnectWithError:(NSError *)error;

//- (void)sendMessage:(NSData *)message type:(NSString *)type;
- (void)sendFilterLoadMessage:(NSData *)filter;

- (void)sendMemPoolMessage;

- (void)sendGetAddrMessage;

- (void)sendGetHeadersMessageWithLocators:(NSArray *)locators andHashStop:(NSData *)hashStop;

- (void)sendGetBlocksMessageWithLocators:(NSArray *)locators andHashStop:(NSData *)hashStop;

- (void)sendInvMessageWithTxHash:(NSData *)txHash;

- (void)refetchBlocksFrom:(NSData *)blockHash; // useful to get additional transactions after a bloom filter update
- (void)sendGetDataMessageWithTxHashes:(NSArray *)txHashes andBlockHashes:(NSArray *)blockHashes;

//- (BTPeerItem *)formatToPeerItem;
//
//- (instancetype)initWithPeerItem:(BTPeerItem *) peerItem;

//- (void)missBehaving;

// fail means error like network error, we can reconnect it when no connected cnt <= 1 peer.
- (void)connectFail;

// connected cnt will change to 1, means it is connecting right now or last time.
- (void)connectSucceed;

// error means peer relay wrong data or not sync complete yet. these peer will delete in db.
- (void)connectError;

@end
