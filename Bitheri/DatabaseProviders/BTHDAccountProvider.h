//
//  BTHDAccountProvider.h
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

@interface BTHDAccountProvider : NSObject

+ (instancetype)instance;

- (int)addHDAccountWithEncryptedMnemonicSeed:(NSString *)encryptedMnemonicSeed encryptSeed:(NSString *)encryptSeed
                                firstAddress:(NSString *)firstAddress isXRandom:(BOOL)isXRandom
                             encryptSeedOfPS:(NSString *)encryptSeedOfPs addressOfPS:(NSString *)addressOfPS
                                 externalPub:(NSData *)externalPub internalPub:(NSData *)internalPub;

- (int)addMonitoredHDAccount:(NSString *)firstAddress isXRandom:(int)isXRandom externalPub:(NSData *)externalPub
                 internalPub:(NSData *)internalPub;

- (void)addHDAccountSegwitPubForHDAccountId:(int)hdAccountId segwitExternalPub:(NSData *)segwitExternalPub
            segwitInternalPub:(NSData *)segwitInternalPub;

- (BOOL)hasMnemonicSeed:(int)hdAccountId;

- (NSString *)getHDFirstAddress:(int)hdAccountId;

- (NSData *)getExternalPub:(int)hdAccountId;

- (NSData *)getInternalPub:(int)hdAccountId;

- (NSData *)getSegwitExternalPub:(int)hdAccountId;

- (NSData *)getSegwitInternalPub:(int)hdAccountId;

- (NSString *)getHDAccountEncryptSeed:(int)hdAccountId;

- (NSString *)getHDAccountEncryptMnemonicSeed:(int)hdAccountId;

- (BOOL)hdAccountIsXRandom:(int)hdAccountId;

- (NSArray *)getHDAccountSeeds;

- (void)deleteHDAccount:(int)hdAccountId;

@end
