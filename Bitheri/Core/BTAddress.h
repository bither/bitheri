//
//  BTAddress.h
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
#import "BTKey+Bitcoinj.h"
#import "BTTx.h"
#import "BTSettings.h"

@interface BTAddress : NSObject

@property(nonatomic, copy, readonly) NSString *fullEncryptPrivKey;
@property(nonatomic, copy) NSString *encryptPrivKeyForCreate;
@property(nonatomic, copy) NSData *pubKey;
@property(nonatomic, readwrite) BOOL isSyncComplete;
@property(nonatomic, readonly) NSString *address;
@property(nonatomic, readonly) NSData *scriptPubKey;
@property bool hasPrivKey;

@property(nonatomic, readonly) uint64_t balance;
@property(nonatomic, readonly) NSArray *unspentOuts;
@property long long sortTime;
@property BOOL isFromXRandom;
@property BOOL isTrashed;
@property(nonatomic, readonly) BOOL isHDM;
@property(nonatomic, readonly) BOOL isHDAccount;
@property(nonatomic, strong) NSString *alias;
@property(nonatomic, readwrite) int vanityLen;

@property(nonatomic, readonly) uint32_t txCount;
@property(nonatomic, strong, readonly) BTTx *recentlyTx;

@property(nonatomic, readonly) BOOL isCompressed;

- (instancetype)initWithBitcoinjKey:(NSString *)encryptPrivKey withPassphrase:(NSString *)passphrase isSyncComplete:(BOOL)isSyncComplete;

- (instancetype)initWithKey:(BTKey *)key encryptPrivKey:(NSString *)encryptPrivKey isSyncComplete:(BOOL)isSyncComplete isXRandom:(BOOL)isXRandom;

- (instancetype)initWithAddress:(NSString *)address encryptPrivKey:(NSString *)encryptPrivKey pubKey:(NSData *)pubKey hasPrivKey:(BOOL)hasPrivKey isSyncComplete:(BOOL)isSyncComplete isXRandom:(BOOL)isXRandom;

- (instancetype)initWithWithPubKey:(NSString *)pubKey encryptPrivKey:(NSString *)encryptPrivKey isSyncComplete:(BOOL)isSyncComplete;

#pragma mark - manage tx

- (BOOL)initTxs:(NSArray *)txs;

- (void)registerTx:(BTTx *)tx withTxNotificationType:(TxNotificationType)txNotificationType;

- (void)removeTx:(NSData *)txHash;

- (void)setBlockHeight:(u_int32_t)height forTxHashes:(NSArray *)txHashes;

#pragma mark - update status

- (void)updateCache;

- (void)updateSyncComplete;

#pragma mark - send tx

- (BTTx *)txForAmounts:(NSArray *)amounts andAddress:(NSArray *)addresses andError:(NSError **)error;

- (BTTx *)txForAmounts:(NSArray *)amounts andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andError:(NSError **)error;

- (BTTx *)txForAmounts:(NSArray *)amounts andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andError:(NSError **)error coin:(Coin)coin;

- (NSArray *)splitCoinTxsForAmounts:(NSArray *)amounts andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andError:(NSError **)error coin:(Coin)coin;

- (NSArray *)bccTxsForAmounts:(NSArray *)amounts andAddress:(NSArray *)addresses andChangeAddress:(NSString *)changeAddress andUnspentOuts:(NSArray *)unspentOuts andError:(NSError **)error;

- (BOOL)signTransaction:(BTTx *)transaction withPassphrase:(NSString *)passphrase;

- (BOOL)signTransaction:(BTTx *)transaction withPassphrase:(NSString *)passphrase andUnspentOuts:(NSArray*) unspentOuts;

- (NSArray *)signHashes:(NSArray *)unsignedInHashes withPassphrase:(NSString *)passphrase;

- (NSString *)signMessage:(NSString *)message withPassphrase:(NSString *)passphrase;

#pragma mark - query tx

- (NSArray *)txs:(int)page;

- (uint64_t)amountReceivedFromTransaction:(BTTx *)transaction;

- (uint64_t)amountSentByTransaction:(BTTx *)transaction;

- (uint64_t)feeForTransaction:(BTTx *)transaction;

- (NSString *)addressForTransaction:(BTTx *)transaction;

- (uint32_t)blockHeightUntilFree:(BTTx *)transaction;

- (NSArray *)getRecentlyTxsWithConfirmationCntLessThan:(int)confirmationCnt andLimit:(int)limit;

#pragma mark - r check

- (void)completeInSignature:(NSArray *)ins;

- (uint32_t)needCompleteInSignature;

#pragma  mark - alias

- (void)updateAlias:(NSString *)alias;

- (void)removeAlias;

#pragma  mark- vanity address

- (void)updateVanityLen:(int)len;

- (void)removeVanity;

- (BOOL)exsitsVanityLen;

@end
