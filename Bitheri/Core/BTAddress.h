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
//#import "BTKey+BIP38.h"
#import "BTKey+Bitcoinj.h"
#import "BTTx.h"
#import "BTSettings.h"


//#define BitherBalanceChangedNotification @"BitherBalanceChangedNotification"
//
//#define PRIVATE_KEY_FILE_NAME @"%@/%@.key"
//#define WATCH_ONLY_FILE_NAME @"%@/%@.pub"



@interface BTAddress : NSObject

@property (nonatomic, copy) NSString *encryptPrivKey;
@property (nonatomic, copy) NSData *pubKey;
@property (nonatomic, readwrite) BOOL isSyncComplete;
@property (nonatomic, readonly) NSString *address;
@property bool hasPrivKey;

@property (nonatomic, readonly) uint64_t balance;
@property (nonatomic, readonly) NSArray *txs;
@property (nonatomic, readonly) NSArray *unspentOuts;
@property long long sortTime;
@property BOOL isFromXRandom;

@property (nonatomic, readonly) uint32_t txCount;


//-(instancetype) initWithPassphrase:(NSString *)passphrase isXRandom:(BOOL)isXRandom;
//
-(instancetype) initWithBitcoinjKey:(NSString *)encryptPrivKey withPassphrase:(NSString *)passphrase ;

- (instancetype)initWithKey:(BTKey *) key encryptPrivKey:(NSString *) encryptPrivKey isXRandom:(BOOL)isXRandom;
- (instancetype)initWithAddress:(NSString *) address pubKey:(NSData *) pubKey hasPrivKey:(BOOL)hasPrivKey isXRandom:(BOOL) isXRandom;

- (NSString *)reEncryptPrivKeyWithOldPassphrase:(NSString *)oldPassphrase andNewPassphrase:(NSString *)newPassphrase;

- (void)setBlockHeight:(u_int32_t)height forTxHashes:(NSArray *)txHashes;

- (void)removeTx:(NSData *)txHash;

// adds a transaction to the address, or returns false if it isn't associated with the address
//- (BOOL)registerTx:(BTTx *)tx;

- (BOOL)initTxs:(NSArray *)txs;
- (void)registerTx:(BTTx *)tx withTxNotificationType:(TxNotificationType) txNotificationType;

//- (BOOL)initTxs:(NSArray *)txs;

//- (BTTx *)txForAmounts:(NSArray *)amounts andAddress:(NSArray *)addresses;
- (BTTx *)txForAmounts:(NSArray *)amounts andAddress:(NSArray *)addresses andError:(NSError **)error;

// returns an unsigned transaction that sends the specified amount from the wallet to the given address
//- (BTTx *)transactionFor:(uint64_t)amount to:(NSString *)address withFee:(BOOL)fee;
//
//// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
//- (BTTx *)transactionForAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee;

// sign any inputs in the given transaction that can be signed using private keys from the wallet
- (BOOL)signTransaction:(BTTx *)transaction withPassphrase:(NSString *) passphrase;

// true if the given transaction is associated with the wallet, false otherwise
//- (BOOL)containsTransaction:(BTTx *)transaction;

// note: no need valid transaction, because the transaction in sqlite is consider to be valid.
// true if no previous wallet transaction spends any of the given transaction's inputs, and no input tx is invalid
//- (BOOL)transactionIsValid:(BTTx *)transaction;

// true if the given transaction has been added to the wallet
- (BOOL)transactionIsRegistered:(NSData *)txHash;

// returns the amount received to the wallet by the transaction (total outputs to change and/or recieve addresses)
- (uint64_t)amountReceivedFromTransaction:(BTTx *)transaction;

// retuns the amount sent from the wallet by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(BTTx *)transaction;

// returns the fee for the given transaction if all its inputs are from wallet transactions, UINT64_MAX otherwise
- (uint64_t)feeForTransaction:(BTTx *)transaction;

// returns the first non-change transaction output address, or nil if there aren't any
- (NSString *)addressForTransaction:(BTTx *)transaction;

// returns the block height after which the transaction is likely to be processed without including a fee
- (uint32_t)blockHeightUntilFree:(BTTx *)transaction;


-(void)saveNewAddress:(long long)sortTime;
-(void)updateAddressWithPub;
-(void)savePrivate;
-(void)removeWatchOnly;

- (NSArray *)signHashes:(NSArray *)unsignedInHashes withPassphrase:(NSString *)passphrase;

- (NSArray *)getRecentlyTxsWithConfirmationCntLessThan:(int)confirmationCnt andLimit:(int)limit;

@end