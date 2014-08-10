//
//  Bitheri.h
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

#define BASE58_ALPHABET @"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
#define BITCOIN_ADDRESS_VAILD @"[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{20,40}"

#define BITCOIN_TESTNET    0
#define SATOSHIS           100000000
#define PARALAX_RATIO      0.25
#define SEGUE_DURATION     0.3

#if BITCOIN_TESTNET
#warning testnet build
#endif

#if ! DEBUG
#define NSLog(...)
#endif

// defines for building third party libs

#define OPENSSL_NO_HW
#define OPENSSL_NO_GOST
#define OPENSSL_NO_INLINE_ASM "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
