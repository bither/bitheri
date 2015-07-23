//
//  BTHDMAddress.h
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
#import "BTAddress.h"
#import "BTTx.h"
#import "BTScript.h"

@class BTHDMKeychain;

@interface BTHDMPubs : NSObject
+ (NSData *)EmptyBytes;

@property(nonatomic, copy) NSData *hot;
@property(nonatomic, copy) NSData *cold;
@property(nonatomic, copy) NSData *remote;
@property(nonatomic) UInt32 index;

@property(nonatomic, readonly) BTScript *multisigScript;

@property(nonatomic, readonly) BOOL hasHot;
@property(nonatomic, readonly) BOOL hasCold;
@property(nonatomic, readonly) BOOL hasRemote;
@property(nonatomic, readonly) BOOL isCompleted;
@property(nonatomic, readonly) NSString *address;

- (instancetype)initWithHot:(NSData *)hot cold:(NSData *)cold remote:(NSData *)remote andIndex:(UInt32)index;

@end

@interface BTHDMAddress : BTAddress

@property(nonatomic, strong) BTHDMPubs *pubs;
@property(nonatomic, weak) BTHDMKeychain *keychain;
@property(nonatomic, readonly) UInt32 index;

@property(nonatomic, readonly) NSData *pubCold;
@property(nonatomic, readonly) NSData *pubHot;
@property(nonatomic, readonly) NSData *pubRemote;
@property(nonatomic, readonly) NSArray *pubKeys;

@property(nonatomic, readonly) BOOL isInRecovery;

- (instancetype)initWithPubs:(BTHDMPubs *)pubs andKeychain:(BTHDMKeychain *)keychain syncCompleted:(BOOL)isSyncCompleted;

- (instancetype)initWithPubs:(BTHDMPubs *)pubs address:(NSString *)address syncCompleted:(BOOL)isSyncCompleted andKeychain:(BTHDMKeychain *)keychain;

- (BOOL)signTx:(BTTx *)tx withPassword:(NSString *)password andFetchBlock:(NSArray *(^)(UInt32 index, NSString *password, NSArray *unsignHashes, BTTx *tx))fetchBlock;

- (BOOL)signTx:(BTTx *)tx withPassword:(NSString *)password coldBlock:(NSArray *(^)(UInt32 index, NSString *password, NSArray *unsignHashes, BTTx *tx))fetchBlockCold andRemoteBlock:(NSArray *(^)(UInt32 index, NSString *password, NSArray *unsignHashes, BTTx *tx))fetchBlockRemote;

- (NSArray *)signUnsginedHashes:(NSArray *)unsignedHashes withPassword:(NSString *)password tx:(BTTx *)tx andOtherBlock:(NSArray *(^)(UInt32 index, NSString *password, NSArray *unsignHashes, BTTx *tx))block;

- (NSArray *)signMyPartUnsignedHashes:(NSArray *)unsignedHashes withPassword:(NSString *)password;

@end

@interface BTHDMColdPubNotSameException : NSException
@end

@interface BTHDMPasswordWrongException : NSException
@end
