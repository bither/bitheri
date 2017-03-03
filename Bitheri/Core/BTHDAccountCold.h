//
//  BTHDAccountCold.h
//  Bitheri
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
//  Created by songchenwen on 15/7/13.
//

#import <Foundation/Foundation.h>
#import "BTBIP32Key.h"
#import "BTBIP39.h"
#import "BTQRCodeUtil.h"

@class BTEncryptData;


@interface BTHDAccountCold : NSObject
@property BOOL isFromXRandom;

- (instancetype)initWithMnemonicSeed:(NSData *)mnemonicSeed btBip39:(BTBIP39 *)bip39 password:(NSString *)password andFromXRandom:(BOOL)isFromXRandom;

- (instancetype)initWithMnemonicSeed:(NSData *)mnemonicSeed btBip39:(BTBIP39 *)bip39 andPassword:(NSString *)password;

- (instancetype)initWithEncryptedMnemonicSeed:(BTEncryptData *)encryptedMnemonicSeed btBip39:(BTBIP39 *)bip39 andPassword:(NSString *)password;

- (instancetype)initWithSeedId:(int)seedId;

- (NSArray *)signHashHexes:(NSArray *)hashes paths:(NSArray *)paths andPassword:(NSString *)password;

- (NSArray *)signHashes:(NSArray *)hashes paths:(NSArray *)paths andPassword:(NSString *)password;

- (NSData *)accountPubExtended:(NSString *)password;

- (NSString *)accountPubExtendedString:(NSString *)password;

- (NSString *)getQRCodeFullEncryptPrivKeyWithHDQrCodeFlatType:(HDQrCodeFlatType)qrCodeFlatType;

- (NSArray *)seedWords:(NSString *)password;

- (BOOL)checkWithPassword:(NSString *)password;

- (NSInteger)getHDAccountId;

- (BTBIP32Key *) xPub:(NSString *)password;

@end
