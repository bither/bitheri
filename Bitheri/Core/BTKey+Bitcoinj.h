//
//  BTKey+Bitcoinj.h
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
#import "BTKey.h"

@interface BTKey (Bitcoinj)

+ (instancetype)keyWithBitcoinj:(NSString *)key andPassphrase:(NSString *)passphrase;

- (NSString *)bitcoinjKeyWithPassphrase:(NSString *)passphrase andSalt:(NSData *)salt andIV:(NSData *)iv flag:(uint8_t)flag;

//+(NSString *)reEncryptPrivKeyWithOldPassphrase:(NSString * )encryptPrivKey oldPassphrase:(NSString *)oldPassphrase andNewPassphrase:(NSString *)newPassphrase;
//
//+ (NSData *)saltWithBitcoinj:(NSString *)key;
//+ (NSData *)ivWithBitcoinj:(NSString *)key;

+ (BOOL)isXRandom:(NSString *)encryptPrivKey;

@end