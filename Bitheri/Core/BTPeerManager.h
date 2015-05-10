//
//  BTPeerManager.h
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
#import "BTBlockChain.h"
#import "BTPeer.h"

@interface BTPeerManager : NSObject <BTPeerDelegate>

@property(nonatomic, readonly) BOOL connected;
@property(nonatomic, readonly) uint32_t lastBlockHeight;
@property(nonatomic, readonly) double syncProgress;
@property(nonatomic, strong) BTBlockChain *blockChain;
@property(nonatomic, strong) BTPeer *downloadPeer;
@property BOOL synchronizing;
@property BOOL running;

@property(readonly) BOOL doneSyncFromSPV;

+ (instancetype)instance;

- (void)initAddress;

- (void)start;

- (void)stop;

- (void)clearPeerAndRestart;

- (void)publishTransaction:(BTTx *)transaction completion:(void (^)(NSError *error))completion;

// transaction is considered verified when all peers have relayed it
- (BOOL)transactionIsVerified:(NSData *)txHash;

@property(nonatomic, strong) NSMutableSet *connectedPeers;

- (int)waitingTaskCount;

@end
