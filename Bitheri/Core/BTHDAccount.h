//
//  BTHDAccount.h
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
#import "BTHDAccountAddress.h"
#import "BTAddress.h"
#import "BTBloomFilter.h"
#import "BTEncryptData.h"
#import "BTBIP32Key.h"
#import "BTBIP39.h"
#import "BTQRCodeUtil.h"
#import "BTHDAccountUtil.h"
#import "EncryptionException.h"

#define kHDAccountPaymentAddressChangedNotificationFirstAdding @"FirstAdding"
#define kHDAccountPaymentAddressChangedNotification @"HDAccountPaymentAddressChangedNotification"
#define kHDAccountPlaceHolder @"HDAccount"
#define kHDAccountMonitoredPlaceHolder @"HDAccountMonitored"
#define kHDAccountMaxUnusedNewAddressCount (20)

@interface BTHDAccount : BTAddress

- (instancetype)initWithMnemonicSeed:(NSData *)mnemonicSeed password:(NSString *)password fromXRandom:(BOOL)fromXRandom andGenerationCallback:(void (^)(CGFloat progres))callback;

- (instancetype)initWithMnemonicSeed:(NSData *)mnemonicSeed btBip39:(BTBIP39 *)bip39 password:(NSString *)password fromXRandom:(BOOL)fromXRandom syncedComplete:(BOOL)isSyncedComplete addMode:(AddressAddMode)addMode andGenerationCallback:(void (^)(CGFloat progres))callback;

- (instancetype)initWithEncryptedMnemonicSeed:(BTEncryptData *)encryptedMnemonicSeed btBip39:(BTBIP39 *)bip39 password:(NSString *)password syncedComplete:(BOOL)isSyncedComplete andGenerationCallback:(void (^)(CGFloat progres))callback;

- (instancetype)initWithAccountExtendedPub:(NSData *)accountExtendedPub p2shp2wpkhAccountExtentedPub:(NSData *)p2shp2wpkhAccountExtentedPub;

- (instancetype)initWithAccountExtendedPub:(NSData *)accountExtendedPub p2shp2wpkhAccountExtentedPub:(NSData *)p2shp2wpkhAccountExtentedPub andFromXRandom:(BOOL)isFromXRandom;

- (instancetype)initWithAccountExtendedPub:(NSData *)accountExtendedPub p2shp2wpkhAccountExtentedPub:(NSData *)p2shp2wpkhAccountExtentedPub fromXRandom:(BOOL)isFromXRandom syncedComplete:(BOOL)isSyncedComplete andGenerationCallback:(void (^)(CGFloat progres))callback;

- (instancetype)initWithSeedId:(int)seedId;

- (void)validFailedDelete:(NSString *)password;

- (NSSet *)getBelongAccountAddressesFromAddresses:(NSArray *)addresses;

- (NSString *)getQRCodeFullEncryptPrivKeyWithHDQrCodeFlatType:(HDQrCodeFlatType)qrCodeFlatType;

- (BOOL)isTxRelated:(BTTx *)tx;

- (void)onNewTx:(BTTx *)tx andTxNotificationType:(TxNotificationType)txNotificationType;

- (BTTx *)newTxToAddress:(NSString *)toAddress withAmount:(uint64_t)amount pathType:(PathType)pathType dynamicFeeBase:(uint64_t)dynamicFeeBase andError:(NSError **)error;

- (BTTx *)newTxToAddress:(NSString *)toAddress withAmount:(uint64_t)amount dynamicFeeBase:(uint64_t)dynamicFeeBase andError:(NSError **)error andChangeAddress:(NSString *)changeAddress coin:(Coin)coin;

- (BTTx *)newTxToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts dynamicFeeBase:(uint64_t)dynamicFeeBase andError:(NSError **)error andChangeAddress:(NSString *)changeAddress coin:(Coin)coin;

- (NSArray *)newSplitCoinTxsToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts andError:(NSError **)error andChangeAddress:(NSString *)changeAddress coin:(Coin)coin;

- (NSArray *)newBccTxsToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts andError:(NSError **)error andChangeAddress:(NSString *)changeAddress andUnspentOut:(NSArray *) outs;

- (BTTx *)newTxToAddress:(NSString *)toAddress withAmount:(uint64_t)amount pathType:(PathType)pathType dynamicFeeBase:(uint64_t)dynamicFeeBase password:(NSString *)password andError:(NSError **)error;

- (BTTx *)newTxToAddress:(NSString *)toAddress withAmount:(uint64_t)amount andChangeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase password:(NSString *)password andError:(NSError **)error coin:(Coin)coin;

- (BTTx *)newTxToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts pathType:(PathType)pathType dynamicFeeBase:(uint64_t)dynamicFeeBase password:(NSString *)password andError:(NSError **)error;

- (BTTx *)newTxToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts andChangeAddress:(NSString *)changeAddress dynamicFeeBase:(uint64_t)dynamicFeeBase password:(NSString *)password andError:(NSError **)error coin:(Coin)coin;

- (NSArray *)newSplitCoinTxsToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts andChangeAddress:(NSString *)changeAddress password:(NSString *)password andError:(NSError **)error coin:(Coin)coin blockHah:(NSString*)hash;

- (NSArray *)extractBccToAddresses:(NSArray *)toAddresses withAmounts:(NSArray *)amounts andChangeAddress:(NSString *)changeAddress andUnspentOuts:(NSArray *)outs andPathTypeIndex:(PathTypeIndex *) pathTypeIndex password:(NSString *)password andError:(NSError **)error;

- (NSArray *)getSigningAddressesForInputs:(NSArray *)inputs;

- (NSArray *)getRelatedAddressesForTx:(BTTx *)tx;

- (BTHDAccountAddress *)addressForPath:(PathType)path atIndex:(NSUInteger)index;

- (void)updateSyncComplete:(BTHDAccountAddress *)address;

- (NSArray *)seedWords:(NSString *)password;

- (BOOL)checkWithPassword:(NSString *)password;

- (NSUInteger)elementCountForBloomFilter;

- (void)addElementsForBloomFilter:(BTBloomFilter *)filter;

- (BOOL)isSendFromMe:(BTTx *)tx;

- (NSInteger)issuedInternalIndexForPathType:(PathType)pathType;

- (NSInteger)issuedExternalIndexForPathType:(PathType)pathType;

- (void)updateIssuedIndex:(int)index pathType:(PathType)pathType;

- (void)supplyEnoughKeys:(BOOL)isSyncedComplete;

- (NSInteger)getHDAccountId;

- (BOOL)requestNewReceivingAddress:(PathType)pathType;

- (BTBIP32Key *)xPub:(NSString *)password;

- (BTBIP32Key *)xPub:(NSString *)password withPurposePathLevel:(PurposePathLevel)purposeLevel;

- (BTBIP32Key *)privateKeyWithPath:(PathType)path index:(int)index password:(NSString *)password;

- (void)addSegwitPub:(NSString *)password complete:(void (^)(BOOL))complete;

- (NSData *)getExternalPub:(PathType)pathType;

- (NSData *)getInternalPub:(PathType)pathType;

@end

@interface DuplicatedHDAccountException : NSException
@end
