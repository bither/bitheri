//
//  BTAddress.m
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

#import "BTAddress.h"
#import "BTTxProvider.h"
#import "BTOutItem.h"
#import "BTUtils.h"
#import "BTBlockChain.h"
#import "BTTxBuilder.h"

static double saveTime;
NSComparator const txComparator = ^NSComparisonResult(id obj1, id obj2) {
    if ([obj1 blockHeight] > [obj2 blockHeight]) return NSOrderedAscending;
    if ([obj1 blockHeight] < [obj2 blockHeight]) return NSOrderedDescending;
    if ([[obj1 inputHashes] containsObject:[obj2 txHash]]) return NSOrderedDescending;
    if ([[obj2 inputHashes] containsObject:[obj1 txHash]]) return NSOrderedAscending;
    if ([obj1 txTime] > [obj2 txTime]) return NSOrderedAscending;
    if ([obj1 txTime] < [obj2 txTime]) return NSOrderedDescending;
    return NSOrderedSame;
};

static NSData *txOutput(NSData *txHash, uint32_t n) {
    NSMutableData *d = [NSMutableData dataWithCapacity:CC_SHA256_DIGEST_LENGTH + sizeof(uint32_t)];

    [d appendData:txHash];
    [d appendUInt32:n];
    return d;
}

@implementation BTAddress {
    NSString *_address;
}

- (instancetype)initWithPassphrase:(NSString *)passphrase {
    BTKey *key = [BTKey keyWithSecret:[NSData randomWithSize:32] compressed:YES];
    NSString *encryptPrivKey = [key bitcoinjKeyWithPassphrase:passphrase andSalt:[NSData randomWithSize:8] andIV:[NSData randomWithSize:16]];
    return [self initWithKey:key encryptPrivKey:encryptPrivKey];

}

- (instancetype)initWithBitcoinjKey:(NSString *)encryptPrivKey withPassphrase:(NSString *)passphrase {
    BTKey *key = [BTKey keyWithBitcoinj:encryptPrivKey andPassphrase:passphrase];
    return key ? [self initWithKey:key encryptPrivKey:encryptPrivKey] : nil;
}

- (instancetype)initWithKey:(BTKey *)key encryptPrivKey:(NSString *)encryptPrivKey; {
    if (!(self = [super init])) return nil;

    _hasPrivKey = encryptPrivKey != nil;
    _encryptPrivKey = encryptPrivKey;
    _address = key.address;
    _pubKey = key.publicKey;
    _isSyncComplete = NO;
    return self;
}

- (instancetype)initWithAddress:(NSString *)address pubKey:(NSData *)pubKey hasPrivKey:(BOOL)hasPrivKey {

    if (!(self = [super init])) return nil;

    _hasPrivKey = hasPrivKey;
    _encryptPrivKey = nil;
    _address = address;
    _pubKey = pubKey;
    _isSyncComplete = NO;
    [self updateBalance];

    return self;

}

- (uint32_t)txCount {
    return [[BTTxProvider instance] txCount:self.address];
}

- (NSString *)address {
    return _address;
}

- (NSArray *)unspentOuts {
    NSMutableArray *result = [NSMutableArray new];
    for (BTOutItem *outItem in [[BTTxProvider instance] getUnSpendOutCanSpendWithAddress:self.address]) {
        [result addObject:txOutput(outItem.txHash, outItem.outSn)];
    }
    return result;
}

- (NSArray *)txs {
    NSMutableArray *txs = [NSMutableArray new];
    for (BTTxItem *txItem in [[BTTxProvider instance] getTxAndDetailByAddress:self.address]) {
        BTTx *tx = [BTTx txWithTxItem:txItem];
        [txs addObject:tx];
    }
    [txs sortUsingComparator:txComparator];
    return txs;
}


- (void)removeTx:(NSData *)txHash {
    [[BTTxProvider instance] remove:txHash];
}

- (BOOL)containsTransaction:(BTTx *)transaction {
    if ([[NSSet setWithArray:transaction.outputAddresses] containsObject:self.address]) return YES;
    return [[BTTxProvider instance] isAddress:self.address containsTx:[transaction formatToTxItem]];
}

- (void)registerTx:(BTTx *)tx withTxNotificationType:(TxNotificationType)txNotificationType; {
    uint64_t oldBalance = _balance;
    [self updateBalance];
    if (_balance != oldBalance) {
        int deltaBalance = (int) (_balance - oldBalance);
        DDLogWarn(@"[notification]%@ recieve tx[%@], delta balance is %d", _address, [NSString hexWithHash:tx.txHash], deltaBalance);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:BitherBalanceChangedNotification
                                                                object:@[_address, @(_balance - oldBalance), tx, @(txNotificationType)]];
        });
    }
}

- (BOOL)initTxs:(NSArray *)txs {
    NSMutableArray *txItemList = [NSMutableArray new];
    for (BTTx *tx  in txs) {
        [txItemList addObject:[tx formatToTxItem]];
    }
    [[BTTxProvider instance] addTxs:txItemList];

    if ([txs count] > 0) {
        uint64_t oldBalance = _balance;
        [self updateBalance];
        int deltaBalance = (int) (_balance - oldBalance);
        dispatch_async(dispatch_get_main_queue(), ^{
            DDLogWarn(@"[notification]%@ recieve some tx, delta balance is %d", _address, deltaBalance);
            [[NSNotificationCenter defaultCenter] postNotificationName:BitherBalanceChangedNotification object:@[_address, @(deltaBalance), [NSNull null], @(txFromApi)]];
        });
    }
    return YES;
}

- (void)setBlockHeight:(uint)height forTxHashes:(NSArray *)txHashes {
    NSMutableArray *needUpdateTxHash = [NSMutableArray new];
    for (NSData *hash in txHashes) {
        BTTx *tx = [BTTx txWithTxItem:[[BTTxProvider instance] getTxDetailByTxHash:hash]];
        if (!tx || tx.blockHeight == height) continue;
        tx.blockHeight = height;
        [needUpdateTxHash addObject:tx.txHash];
    }

    if (needUpdateTxHash.count > 0) {
        uint64_t oldBalance = _balance;
        [self updateBalance];
        if (_balance != oldBalance) {
            dispatch_async(dispatch_get_main_queue(), ^{
                int deltaBalance = (int) (_balance - oldBalance);
                DDLogWarn(@"[notification]%@ remove some double spend tx, delta balance is %d", _address, deltaBalance);
                [[NSNotificationCenter defaultCenter] postNotificationName:BitherBalanceChangedNotification
                                                                    object:@[_address, @(_balance - oldBalance), [NSNull null], @(txDoubleSpend)]];
            });
        }
    }
}

- (void)updateBalance {
    uint64_t balance = 0;
    NSMutableOrderedSet *utxos = [NSMutableOrderedSet orderedSet];
    NSMutableSet *spentOutputs = [NSMutableSet set], *invalidTx = [NSMutableSet set];

    for (BTTx *tx in [self.txs reverseObjectEnumerator]) {
        NSMutableSet *spent = [NSMutableSet set];
        uint32_t i = 0, n = 0;

        for (NSData *hash in tx.inputHashes) {
            n = [tx.inputIndexes[i++] unsignedIntValue];
            [spent addObject:txOutput(hash, n)];
        }

        // check if any inputs are invalid or already spent
        if (tx.blockHeight == TX_UNCONFIRMED &&
                ([spent intersectsSet:spentOutputs] || [[NSSet setWithArray:tx.inputHashes] intersectsSet:invalidTx])) {
            [invalidTx addObject:tx.txHash];
            continue;
        }

        [spentOutputs unionSet:spent]; // add inputs to spent output set
        n = 0;

        for (NSString *address in tx.outputAddresses) { // add outputs to UTXO set
            if ([self containsAddress:address]) {
                [utxos addObject:txOutput(tx.txHash, n)];
                balance += [tx.outputAmounts[n] unsignedLongLongValue];
            }
            n++;
        }

        // transaction ordering is not guaranteed, so check the entire UTXO set against the entire spent output set
        [spent setSet:[utxos set]];
        [spent intersectSet:spentOutputs];

        for (NSData *o in spent) { // remove any spent outputs from UTXO set
            BTTx *transaction = [BTTx txWithTxItem:[[BTTxProvider instance] getTxDetailByTxHash:[o hashAtOffset:0]]];
            n = [o UInt32AtOffset:CC_SHA256_DIGEST_LENGTH];

            [utxos removeObject:o];
            balance -= [transaction.outputAmounts[n] unsignedLongLongValue];
        }
    }

    if (balance != _balance) {
        _balance = balance;

//        dispatch_async(dispatch_get_main_queue(), ^{
//            [[NSNotificationCenter defaultCenter] postNotificationName:BitherBalanceChangedNotification object:nil];
//        });
    }
}

- (BOOL)containsAddress:(NSString *)address {
    return [self.address isEqualToString:address];
}


#pragma mark - transactions

// sign any inputs in the given transaction that can be signed using private keys from the wallet
- (BOOL)signTransaction:(BTTx *)transaction withPassphrase:(NSString *)passphrase; {
    [transaction signWithPrivateKeys:@[[BTKey keyWithBitcoinj:self.encryptPrivKey andPassphrase:passphrase].privateKey]];
    return [transaction isSigned];
}

// true if the given transaction has been added to the wallet
- (BOOL)transactionIsRegistered:(NSData *)txHash {
    return [[BTTxProvider instance] isExist:txHash];
}

// returns the amount received to the wallet by the transaction (total outputs to change and/or recieve addresses)
- (uint64_t)amountReceivedFromTransaction:(BTTx *)transaction {
    uint64_t amount = 0;
    NSUInteger n = 0;

    for (NSString *address in transaction.outputAddresses) {
        if ([self containsAddress:address]) amount += [transaction.outputAmounts[n] unsignedLongLongValue];
        n++;
    }

    return amount;
}

// returns the amount sent from the wallet by the transaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(BTTx *)transaction {
    uint64_t amount = 0;
    NSUInteger i = 0;

    for (NSData *hash in transaction.inputHashes) {
        BTTx *tx = [BTTx txWithTxItem:[[BTTxProvider instance] getTxDetailByTxHash:hash]];
        uint32_t n = [transaction.inputIndexes[i++] unsignedIntValue];

        if (n < tx.outputAddresses.count && [self containsAddress:tx.outputAddresses[n]]) {
            amount += [tx.outputAmounts[n] unsignedLongLongValue];
        }
    }

    return amount;
}

// returns the fee for the given transaction if all its inputs are from wallet transactions, UINT64_MAX otherwise
- (uint64_t)feeForTransaction:(BTTx *)transaction {
    uint64_t amount = 0;
    NSUInteger i = 0;

    for (NSData *hash in transaction.inputHashes) {
        BTTx *tx = [BTTx txWithTxItem:[[BTTxProvider instance] getTxDetailByTxHash:hash]];
        uint32_t n = [transaction.inputIndexes[i++] unsignedIntValue];

        if (n >= tx.outputAmounts.count) return UINT64_MAX;
        amount += [tx.outputAmounts[n] unsignedLongLongValue];
    }

    for (NSNumber *amt in transaction.outputAmounts) {
        amount -= amt.unsignedLongLongValue;
    }

    return amount;
}

// returns the first non-change transaction output address, or nil if there aren't any
- (NSString *)addressForTransaction:(BTTx *)transaction {
    uint64_t sent = [self amountSentByTransaction:transaction];

    for (NSString *address in transaction.outputAddresses) {
        // first non-wallet address if it's a send transaction, first wallet address if it's a receive transaction
        if ((sent > 0) != [self containsAddress:address]) return address;
    }

    return nil;
}

// Returns the block height after which the transaction is likely to be processed without including a fee. This is based
// on the default satoshi client settings, but on the real network it's way off. In testing, a 0.01btc transaction that
// was expected to take an additional 90 days worth of blocks to confirm was confirmed in under an hour by Eligius pool.
- (uint32_t)blockHeightUntilFree:(BTTx *)transaction {
    // TODO: calculate estimated time based on the median priority of free transactions in last 144 blocks (24hrs)
    NSMutableArray *amounts = [NSMutableArray array], *heights = [NSMutableArray array];
    NSUInteger i = 0;

    for (NSData *hash in transaction.inputHashes) { // get the amounts and block heights of all the transaction inputs
        BTTx *tx = [BTTx txWithTxItem:[[BTTxProvider instance] getTxDetailByTxHash:hash]];
        uint32_t n = [transaction.inputIndexes[i++] unsignedIntValue];

        if (n >= tx.outputAmounts.count) break;
        [amounts addObject:tx.outputAmounts[n]];
        [heights addObject:@(tx.blockHeight)];
    };

    return [transaction blockHeightUntilFreeForAmounts:amounts withBlockHeights:heights];
}

- (void)savePrivate:(NSString *)privateDir {
    NSString *privateKeyFullFileName = [NSString stringWithFormat:PRIVATE_KEY_FILE_NAME, privateDir, self.address];
    [BTUtils writeFile:privateKeyFullFileName content:self.encryptPrivKey];

    [self savePrivateWithPubKey:privateDir];
}

- (void)savePrivateWithPubKey:(NSString *)privateDir {
    NSString *watchOnlyFullFileName = [NSString stringWithFormat:WATCH_ONLY_FILE_NAME, privateDir, self.address];
    NSString *watchOnlyContent = [NSString stringWithFormat:@"%@:%@", [NSString hexWithData:self.pubKey], [self getSyncCompleteString]];
    [BTUtils writeFile:watchOnlyFullFileName content:watchOnlyContent];
    double time = [[NSDate new] timeIntervalSince1970] + saveTime;
    saveTime = saveTime + 1;
    [BTUtils setModifyDateToFile:[NSDate dateWithTimeIntervalSince1970:time] forFile:watchOnlyFullFileName];

}

- (void)saveWatchOnly:(NSString *)publicDir {
    NSString *content = [NSString stringWithFormat:@"%@:%@", [NSString hexWithData:self.pubKey], [self getSyncCompleteString]];
    NSString *dir = [NSString stringWithFormat:WATCH_ONLY_FILE_NAME, publicDir, self.address];
    [BTUtils writeFile:dir content:content];
    double time = [[NSDate new] timeIntervalSince1970] + saveTime;
    saveTime = saveTime + 1;
    [BTUtils setModifyDateToFile:[NSDate dateWithTimeIntervalSince1970:time] forFile:dir];

}

- (void)removeWatchOnly:(NSString *)publicDir {
    NSString *dir = [NSString stringWithFormat:WATCH_ONLY_FILE_NAME, publicDir, self.address];
    [BTUtils removeFile:dir];

}

- (NSString *)getSyncCompleteString {
    return _isSyncComplete ? @"1" : @"0";
}

- (NSString *)reEncryptPrivKeyWithOldPassphrase:(NSString *)oldPassphrase andNewPassphrase:(NSString *)newPassphrase; {
    BTKey *key = [BTKey keyWithBitcoinj:self.encryptPrivKey andPassphrase:oldPassphrase];
    NSData *salt = [BTKey saltWithBitcoinj:self.encryptPrivKey];
    NSData *iv = [BTKey ivWithBitcoinj:self.encryptPrivKey];
    if (key != nil) {
        return [key bitcoinjKeyWithPassphrase:newPassphrase andSalt:salt andIV:iv];
    } else {
        return nil;
    }
}

#pragma mark - calculate fee and out

- (BTTx *)txForAmounts:(NSArray *)amounts andAddress:(NSArray *)addresses andError:(NSError **)error; {
    return [[BTTxBuilder instance] buildTxForAddress:self.address andAmount:amounts andAddress:addresses andError:error];
}

//- (NSArray *)selectOuts:(uint64_t)amount andOuts:(NSArray *)outs; {
//    NSMutableArray *result = [NSMutableArray new];
//    uint64_t sum = 0;
//    for (BTOutItem *outItem in outs) {
//        sum += outItem.outValue;
//        [result addObject:outItem];
//        if (sum >= amount) break;
//    }
//    return result;
//}

- (NSArray *)getRecentlyTxsWithConfirmationCntLessThan:(int)confirmationCnt andLimit:(int)limit; {
    NSMutableArray *txs = [NSMutableArray new];
    int blockNo = [BTBlockChain instance].lastBlock.height - confirmationCnt + 1;
    for (BTTxItem *txItem in [[BTTxProvider instance] getRecentlyTxsByAddress:self.address
                                                        andGreaterThanBlockNo:blockNo andLimit:limit]) {
        [txs addObject:[BTTx txWithTxItem:txItem]];
    }
    return txs;
}

//- (uint64_t)getAmount:(NSArray *)outs; {
//    uint64_t amount = 0;
//    for (BTOutItem *outItem in outs) {
//        amount += outItem.outValue;
//    }
//    return amount;
//}

//- (uint64_t)getCoinDepth:(NSArray *)outs; {
//    uint64_t coinDepth = 0;
//    for (BTOutItem *outItem in outs) {
//        coinDepth += outItem.coinDepth;
//    }
//    return coinDepth;
//}

- (NSString *)encryptPrivKey {
    if (self.hasPrivKey) {
        if (_encryptPrivKey) {
            return _encryptPrivKey;
        } else {
            NSString *privateKeyFullFileName = [NSString stringWithFormat:PRIVATE_KEY_FILE_NAME, [BTUtils getPrivDir], self.address];
            _encryptPrivKey = [BTUtils readFile:privateKeyFullFileName];
            return _encryptPrivKey;
        }
    }
    return nil;
}

- (NSArray *)signHashes:(NSArray *)unsignedInHashes withPassphrase:(NSString *)passphrase; {
    BTKey *key = [BTKey keyWithBitcoinj:self.encryptPrivKey andPassphrase:passphrase];
    NSMutableArray *result = [NSMutableArray new];
    for (NSData *hash in unsignedInHashes) {
        NSMutableData *sig = [NSMutableData data];
        NSMutableData *s = [NSMutableData dataWithData:[key sign:hash]];

        [s appendUInt8:SIG_HASH_ALL];
        [sig appendScriptPushData:s];
        [sig appendScriptPushData:[key publicKey]];
        [result addObject:sig];
    }
    return result;
}

- (BOOL)isEqual:(id)object {
    if ([object isMemberOfClass:[BTAddress class]]) {
        BTAddress *other = object;
        return [self.address isEqualToString:other.address];
    } else {
        return NO;
    }
}
//- (uint64_t)getMinNonDustValue:(uint64_t)feeBase;{
//    return feeBase * 3 * (34 + 148) / 1000;
//}

@end