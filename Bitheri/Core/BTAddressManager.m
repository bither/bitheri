//
//  BTAddressManager.m
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

#import "BTAddressManager.h"
#import "BTUtils.h"
#import "BTTxProvider.h"
#import "BTIn.h"
#import "BTQRCodeUtil.h"
#import "BTAddressProvider.h"

@interface BTAddressManager () <BTHDMAddressChangeDelegate> {
    BTHDMKeychain *_hdmKeychain;
    BTHDAccount *_hdAccount;
}

@end

@implementation BTAddressManager {
    NSCondition *tc;
}

+ (instancetype)instance; {
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });

    return singleton;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    tc = [NSCondition new];
    self.isReady = NO;
    _privKeyAddresses = [NSMutableArray new];
    _watchOnlyAddresses = [NSMutableArray new];
    _trashAddresses = [NSMutableArray new];
    _addressesSet = [NSMutableSet new];
    _creationTime = [[NSDate new] timeIntervalSince1970];
    return self;
}

- (void)initAddress {
    if (self.isReady) {
        return;
    }
    [tc lock];
    NSArray *allAddresses = [[BTAddressProvider instance] getAddresses];
    for (BTAddress *address in allAddresses) {
        if (address.hasPrivKey && !address.isTrashed) {
            [_privKeyAddresses addObject:address];
            [_addressesSet addObject:address.address];
        } else if (address.hasPrivKey && address.isTrashed) {
            [_trashAddresses addObject:address];
        } else {
            [_watchOnlyAddresses addObject:address];
            [_addressesSet addObject:address.address];
        }
    }
    [_privKeyAddresses sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        if ([obj1 sortTime] > [obj2 sortTime]) return NSOrderedAscending;
        if ([obj1 sortTime] < [obj2 sortTime]) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    [_watchOnlyAddresses sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        if ([obj1 sortTime] > [obj2 sortTime]) return NSOrderedAscending;
        if ([obj1 sortTime] < [obj2 sortTime]) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    [_trashAddresses sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        if ([obj1 sortTime] > [obj2 sortTime]) return NSOrderedAscending;
        if ([obj1 sortTime] < [obj2 sortTime]) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    [self initHDMKeychain];
    [self initHDAccount];
    [self initAliasAndVanity];
    self.isReady = YES;
    [tc signal];
    [tc unlock];
    dispatch_sync(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:BTAddressManagerIsReady
                                                            object:nil userInfo:nil];
    });
}

- (void)initHDAccount {
    NSArray *seeds = [[BTAddressProvider instance] getHDAccountSeeds];
    if (seeds && seeds.count > 0) {
        _hdAccount = [[BTHDAccount alloc] initWithSeedId:((NSNumber *) seeds[0]).intValue];
    }
}

- (void)initHDMKeychain {
    NSArray *seeds = [[BTAddressProvider instance] getHDSeedIds];
    if (seeds.count > 0) {
        self.hdmKeychain = [[BTHDMKeychain alloc] initWithSeedId:((NSNumber *) seeds[0]).intValue];
    }
}

- (void)initAliasAndVanity {
    NSDictionary *aliases = [[BTAddressProvider instance] getAliases];
    NSDictionary *vanityAddresses=[[BTAddressProvider instance] getVanityAddresses];
    if(aliases.count==0&&vanityAddresses.count==0){
        return;
    }
    if (_privKeyAddresses && _privKeyAddresses.count > 0) {
        for (BTAddress *address in _privKeyAddresses) {
            NSString * addressStr=address.address;
            if ([[aliases allKeys] containsObject:addressStr]) {
                address.alias = [aliases objectForKey:addressStr];
            }
            if([[vanityAddresses allKeys] containsObject:addressStr]){
                address.vanityLen=[[vanityAddresses objectForKey:addressStr] integerValue];
            }
        }
    }
    if (_watchOnlyAddresses && _watchOnlyAddresses.count > 0) {
        for (BTAddress *address in _watchOnlyAddresses) {
            NSString * addressStr=address.address;
            if ([[aliases allKeys] containsObject:addressStr]) {
                address.alias = [aliases objectForKey:addressStr];
            }
            if ([[vanityAddresses allKeys] containsObject:addressStr]){
                address.vanityLen=[[vanityAddresses objectForKey:addressStr] integerValue];
            }
        }
    }

    if (_trashAddresses && _trashAddresses.count > 0) {
        for (BTAddress *address in _trashAddresses) {
            NSString * addressStr=address.address;
            if ([[aliases allKeys] containsObject:addressStr]) {
                address.alias = [aliases objectForKey:addressStr];
            }
            if ([[vanityAddresses allKeys] containsObject:addressStr]){
                address.vanityLen=[[vanityAddresses objectForKey:addressStr] integerValue];
            }
        }
    }

    if (_hdmKeychain && _hdmKeychain.allCompletedAddresses.count > 0) {
        for (BTAddress *address in _hdmKeychain.allCompletedAddresses) {
            if ([[aliases allKeys] containsObject:address.address]) {
                address.alias = [aliases objectForKey:address.address];
            }
        }
    }

}

- (NSInteger)addressCount {
    return [[self privKeyAddresses] count] + [[self watchOnlyAddresses] count] + (self.hasHDMKeychain ? self.hdmKeychain.addresses.count : 0);
}

- (NSMutableArray *)privKeyAddresses {
    if (self.isReady) {
        return _privKeyAddresses;
    }
    [tc lock];
    if (!self.isReady) {
        [tc wait];
    }
    [tc unlock];
    return _privKeyAddresses;
}

- (NSMutableArray *)watchOnlyAddresses {
    if (self.isReady) {
        return _watchOnlyAddresses;
    }
    [tc lock];
    if (!self.isReady) {
        [tc wait];
    }
    [tc unlock];
    return _watchOnlyAddresses;
}

- (NSMutableArray *)trashAddresses {
    if (self.isReady) {
        return _trashAddresses;
    }
    [tc lock];
    if (!self.isReady) {
        [tc wait];
    }
    [tc unlock];
    return _trashAddresses;

}

- (NSMutableSet *)addressesSet {
    if (self.isReady) {
        return _addressesSet;
    }
    [tc lock];
    if (!self.isReady) {
        [tc wait];
    }
    [tc unlock];
    return _addressesSet;
}

- (void)addAddress:(BTAddress *)address {
    DDLogDebug(@"addAddress %@ ,hasPrivKey %d", address.address, address.hasPrivKey);

    if (address.hasPrivKey) {
        address.sortTime = [self getPrivKeySortTime];
        [[BTAddressProvider instance] addAddress:address];
        [self.privKeyAddresses insertObject:address atIndex:0];
        [self.addressesSet addObject:address.address];
    } else {
        address.sortTime = [self getWatchOnlySortTime];
        [[BTAddressProvider instance] addAddress:address];
        [self.watchOnlyAddresses insertObject:address atIndex:0];
        [self.addressesSet addObject:address.address];
    }

}

- (void)stopMonitor:(BTAddress *)address {
    DDLogDebug(@"stopMonitor %@ ,hasPrivKey %d", address.address, address.hasPrivKey);
    [[BTAddressProvider instance] removeWatchOnlyAddress:address];
//    [address removeWatchOnly];
    [self.watchOnlyAddresses removeObject:address];
    [self.addressesSet removeObject:address.address];
}

- (void)trashPrivKey:(BTAddress *)address; {
    if (address.hasPrivKey && address.balance == 0) {
        DDLogDebug(@"trash priv key %@", address.address);
        [[BTAddressProvider instance] trashPrivKeyAddress:address];
        [self.privKeyAddresses removeObject:address];
        [self.addressesSet removeObject:address.address];
        [self.trashAddresses addObject:address];
    }
}

- (void)restorePrivKey:(BTAddress *)address; {
    if (address.hasPrivKey) {
        DDLogDebug(@"restore priv key %@", address.address);
        address.sortTime = [self getPrivKeySortTime];
        address.isTrashed = NO;
        address.isSyncComplete = NO;
        [address updateCache];
        [[BTAddressProvider instance] restorePrivKeyAddress:address];
        [self.privKeyAddresses insertObject:address atIndex:0];
        [self.addressesSet addObject:address.address];
        [self.trashAddresses removeObject:address];
    }
}

- (NSMutableArray *)allAddresses {
    NSMutableArray *allAddresses = [NSMutableArray new];
    [allAddresses addObjectsFromArray:self.privKeyAddresses];
    [allAddresses addObjectsFromArray:self.watchOnlyAddresses];
    if (self.hasHDMKeychain) {
        [allAddresses addObjectsFromArray:self.hdmKeychain.addresses];
    }
    return allAddresses;
}

- (long long)getPrivKeySortTime; {
    long long sortTime = (long long int) ([[NSDate new] timeIntervalSince1970] * 1000);
    if (self.privKeyAddresses.count > 0) {
        BTAddress *address = (self.privKeyAddresses)[0];
        if (sortTime < address.sortTime) {
            sortTime = address.sortTime + self.privKeyAddresses.count;
        }
    }
    return sortTime;
}

- (long long)getWatchOnlySortTime; {
    long long sortTime = (long long int) ([[NSDate new] timeIntervalSince1970] * 1000);
    if (self.watchOnlyAddresses.count > 0) {
        BTAddress *address = (self.watchOnlyAddresses)[0];
        if (sortTime < address.sortTime) {
            sortTime = address.sortTime + self.watchOnlyAddresses.count;
        }
    }
    return sortTime;
}


- (BOOL)allSyncComplete {
    BOOL allSync = YES;
    for (BTAddress *address in [self allAddresses]) {
        if (!address.isSyncComplete) {
            allSync = NO;
            break;
        }
    }
    if (allSync && self.hasHDAccount && !self.hdAccount.isSyncComplete) {
        allSync = NO;
    }
    return allSync;
}

- (BOOL)changePassphraseWithOldPassphrase:(NSString *)oldPassphrase andNewPassphrase:(NSString *)newPassphrase; {
    return [[BTAddressProvider instance] changePasswordWithOldPassword:oldPassphrase andNewPassword:newPassphrase];
}

- (BOOL)isTxRelated:(BTTx *)tx; {
    for (BTAddress *address in self.allAddresses) {
        if ([self isAddress:address.address containsTransaction:tx]) {
            return true;
        }
    }
    if (self.hasHDAccount) {
        return [self.hdAccount isTxRelated:tx];
    }
    return false;
}

- (BOOL)isAddress:(NSString *)address containsTransaction:(BTTx *)transaction {
    for (BTOut *out in transaction.outs) {
        if ([out.outAddress isEqualToString:address]) {
            return YES;
        }
    }
    return [[BTTxProvider instance] isAddress:address containsTx:transaction];
}

- (BOOL)registerTx:(BTTx *)tx withTxNotificationType:(TxNotificationType)txNotificationType; {
    if ([[BTTxProvider instance] isTxDoubleSpendWithConfirmedTx:tx]) {
        // double spend with confirmed tx
        return false;
    }

    BOOL isRegister = NO;
    BTTx *compressedTx = [self compressTx:tx];
    NSMutableSet *needNotifyAddressHashSet = [NSMutableSet new];
    NSMutableSet *needNotifyHDAccountHS = [NSMutableSet new];
    NSMutableArray *relatedAddresses = [NSMutableArray new];
    NSMutableSet *relatedAddressesHS = [NSMutableSet new];

    if (self.hasHDAccount) {
        [relatedAddresses addObjectsFromArray:[self.hdAccount getRelatedAddressesForTx:compressedTx]];
    }

    for (BTHDAccountAddress *hdAccountAddress in relatedAddresses) {
        [relatedAddressesHS addObject:hdAccountAddress.address];
    }

    for (BTOut *out in compressedTx.outs) {
        NSString *outAddress = out.outAddress;
        if ([self.addressesSet containsObject:outAddress]) {
            [needNotifyAddressHashSet addObject:outAddress];
        }

        if ([relatedAddressesHS containsObject:outAddress]) {
            [needNotifyHDAccountHS addObject:outAddress];
        }
    }

    BTTx *txInDb = [[BTTxProvider instance] getTxDetailByTxHash:tx.txHash];
    if (txInDb != nil) {
        for (BTOut *out in txInDb.outs) {
            NSString *outAddress = out.outAddress;
            if ([needNotifyAddressHashSet containsObject:outAddress]) {
                [needNotifyAddressHashSet removeObject:outAddress];
            }

            if ([needNotifyHDAccountHS containsObject:outAddress]) {
                [needNotifyHDAccountHS removeObject:outAddress];
            }
        }
        isRegister = YES;
    } else {
        NSArray *inAddresses = [[BTTxProvider instance] getInAddresses:compressedTx];
        for (NSString *address in inAddresses) {
            if ([self.addressesSet containsObject:address]) {
                [needNotifyAddressHashSet addObject:address];
            }

            if ([relatedAddressesHS containsObject:address]) {
                [needNotifyHDAccountHS addObject:address];
            }
        }
        isRegister = needNotifyAddressHashSet.count > 0 || needNotifyHDAccountHS.count > 0;
    }
    if (needNotifyAddressHashSet.count > 0 || needNotifyHDAccountHS.count > 0) {
        [[BTTxProvider instance] add:compressedTx];
        DDLogDebug(@"register tx %@", [NSString hexWithHash:compressedTx.txHash]);
    }
    for (BTAddress *address in [BTAddressManager instance].allAddresses) {
        if ([needNotifyAddressHashSet containsObject:address.address]) {
            [address registerTx:compressedTx withTxNotificationType:txNotificationType];
        }
    }

    NSMutableArray *needNotifyHDAddressList = [NSMutableArray new];
    for (BTHDAccountAddress *a in relatedAddresses) {
        if ([needNotifyHDAccountHS containsObject:a.address]) {
            [needNotifyHDAddressList addObject:a];
        }
    }

    if (needNotifyHDAddressList.count > 0) {
        [self.hdAccount onNewTx:compressedTx withRelatedAddresses:needNotifyHDAddressList andTxNotificationType:txNotificationType];
    }

    return isRegister;
}

- (NSArray *)outs; {
    NSMutableArray *result = [NSMutableArray new];
    for (BTOut *out in [[BTTxProvider instance] getOuts]) {
        if ([[BTAddressManager instance].addressesSet containsObject:out.outAddress]) {
            [result addObject:getOutPoint(out.txHash, out.outSn)];
        }
    }
    return result;
}

- (NSArray *)unSpentOuts {
    NSMutableArray *result = [NSMutableArray new];
    for (BTOut *outItem in [[BTTxProvider instance] getUnSpentOuts]) {
        [result addObject:getOutPoint(outItem.txHash, outItem.outSn)];
    }
    return result;
}

- (void)hdmAddressAdded:(BTHDMAddress *)address {
    [_addressesSet addObject:address.address];
}

- (void)setHdmKeychain:(BTHDMKeychain *)hdmKeychain {
    if (!hdmKeychain) {
        _hdmKeychain = nil;
        return;
    }
    _hdmKeychain = hdmKeychain;
    hdmKeychain.addressChangeDelegate = self;
    NSArray *addresses = hdmKeychain.addresses;
    for (BTHDMAddress *a in addresses) {
        [_addressesSet addObject:a.address];
    }
}

- (BOOL)hasHDMKeychain {
    if ([[BTSettings instance] getAppMode] == COLD) {
        return _hdmKeychain != nil;
    } else {
        return _hdmKeychain && _hdmKeychain.addresses.count > 0;
    }
}

- (BTHDMKeychain *)hdmKeychain {
    return _hdmKeychain;
}

- (BOOL)hasHDAccount {
    return _hdAccount != nil;
}

- (BTHDAccount *)hdAccount {
    return _hdAccount;
}

- (void)setHdAccount:(BTHDAccount *)hdAccount {
    _hdAccount = hdAccount;
}

- (void)blockChainChanged; {
    for (BTAddress *address in self.allAddresses) {
        [address updateCache];
    }
}

- (NSArray *)compressTxsForApi:(NSArray *)txList andAddress:(NSString *)address; {
    NSMutableDictionary *txDict = [NSMutableDictionary new];
    for (BTTx *tx in txList) {
        txDict[tx.txHash] = tx;
    }
    for (BTTx *tx in txList) {
        if (![self isSendFromMe:tx andTxHashDict:txDict andAddress:address] && tx.outs.count > COMPRESS_OUT_NUM) {
            NSMutableArray *outList = [NSMutableArray new];
            for (BTOut *out in tx.outs) {
                if ([out.outAddress isEqualToString:address]) {
                    [outList addObject:out];
                }
            }
            tx.outs = outList;
        }
    }
    return txList;
}

- (BOOL)isSendFromMe:(BTTx *)tx andTxHashDict:(NSDictionary *)txDict andAddress:(NSString *)address; {
    for (BTIn *btIn in tx.ins) {
        if (txDict[btIn.prevTxHash] != nil) {
            BTTx *prevTx = txDict[btIn.prevTxHash];
            for (BTOut *out in prevTx.outs) {
                if (out.outSn == btIn.prevOutSn) {
                    if ([out.outAddress isEqualToString:address]) {
                        return YES;
                    }
                }
            }
        }
    }
    return NO;
}

- (BTTx *)compressTx:(BTTx *)tx {
    if (![self isSendFromMe:tx] && (!self.hasHDAccount || ![self.hdAccount isSendFromMe:tx]) && tx.outs.count > COMPRESS_OUT_NUM) {
        NSMutableArray *outList = [NSMutableArray new];
        NSMutableArray *hdAddresses = [NSMutableArray new];
        if (self.hasHDAccount) {
            [hdAddresses addObjectsFromArray:[self.hdAccount getBelongAccountAddressesFromAdresses:tx.getOutAddressList].allObjects];
        }
        for (BTOut *out in tx.outs) {
            NSString *outAddress = out.outAddress;
            if ([self.addressesSet containsObject:outAddress] || [hdAddresses containsObject:outAddress]) {
                [outList addObject:out];
            }
        }
        tx.outs = outList;
    }
    return tx;
}

- (BOOL)isSendFromMe:(BTTx *)tx; {
    NSArray *fromAddresses = [tx getInAddresses];
    return [self.addressesSet intersectsSet:[NSSet setWithArray:fromAddresses]];
}

#pragma mark - for old version

+ (BOOL)updateKeyStoreFromFileToDbWithPasswordSeed:(BTPasswordSeed *)passwordSeed; {
    NSMutableArray *addresses = [NSMutableArray new];
    [addresses addObjectsFromArray:[BTAddressManager getPrivKeyAddressFromFile]];
    [addresses addObjectsFromArray:[BTAddressManager getTrashAddressFromFile]];
    [addresses addObjectsFromArray:[BTAddressManager getWatchOnlyAddressFromFile]];
    for (BTAddress *address in addresses) {
        [address setIsSyncComplete:NO];
    }
    BOOL result = [[BTAddressProvider instance] addAddresses:addresses andPasswordSeed:passwordSeed];
    for (int i = addresses.count - 1; i >= 0; i--) {
        BTAddress *address = addresses[i];
        if (address.hasPrivKey) {
            if (address.isTrashed) {
                [[BTAddressManager instance].trashAddresses insertObject:address atIndex:0];
            } else {
                [[BTAddressManager instance].privKeyAddresses insertObject:address atIndex:0];
                [[BTAddressManager instance].addressesSet addObject:address.address];
            }
        } else {
            [[BTAddressManager instance].watchOnlyAddresses insertObject:address atIndex:0];
            [[BTAddressManager instance].addressesSet addObject:address.address];
        }
    }
    return result;
}

+ (NSArray *)getPrivKeyAddressFromFile; {
    BOOL isSort = NO;
    NSMutableArray *privKeyAddresses = [NSMutableArray new];
    for (NSString *str in [BTUtils filesByModDate:[BTUtils getPrivDir]]) {
        NSInteger length = str.length;
        if ([str rangeOfString:@".pub"].length > 0) {
            NSString *note = [BTUtils readFile:[[BTUtils getPrivDir] stringByAppendingPathComponent:str]];
            NSArray *array = [note componentsSeparatedByString:@":"];
            long long sortTime = 0;
            BOOL isFromXRandom = NO;
            if (array.count > 3) {
                sortTime = [array[2] longLongValue];
                if (sortTime > 0) {
                    isSort = YES;
                }
                isFromXRandom = [BTUtils compareString:XRANDOM_FLAG compare:array[3]];

            }
            NSString *addressStr = [str substringToIndex:(NSUInteger) (length - 4)];
            NSString *privateKeyFullFileName = [NSString stringWithFormat:PRIVATE_KEY_FILE_NAME, [BTUtils getPrivDir], addressStr];
            NSString *encryptString = [BTUtils readFile:privateKeyFullFileName];
            BTAddress *btAddress = [[BTAddress alloc] initWithAddress:addressStr encryptPrivKey:encryptString pubKey:[array[0] hexToData] hasPrivKey:YES isXRandom:isFromXRandom];
            [btAddress setIsSyncComplete:[array[1] integerValue] == 1];
            [btAddress setSortTime:sortTime];
            [privKeyAddresses addObject:btAddress];
        }
    }
    if (isSort) {
        [privKeyAddresses sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            if ([obj1 sortTime] > [obj2 sortTime]) return NSOrderedAscending;
            if ([obj1 sortTime] < [obj2 sortTime]) return NSOrderedDescending;
            return NSOrderedSame;
        }];
    }
    return privKeyAddresses;
}

+ (NSArray *)getWatchOnlyAddressFromFile; {
    BOOL isSort = NO;
    NSMutableArray *watchOnlyAddresses = [NSMutableArray new];
    for (NSString *str in [BTUtils filesByModDate:[BTUtils getWatchOnlyDir]]) {
        NSInteger length = str.length;
        if ([str rangeOfString:@".pub"].length > 0) {
            NSString *note = [BTUtils readFile:[[BTUtils getWatchOnlyDir] stringByAppendingPathComponent:str]];
            NSArray *array = [note componentsSeparatedByString:@":"];
            long long sortTime = 0;
            BOOL isFromXrandm = NO;
            if (array.count > 3) {
                sortTime = [array[2] longLongValue];
                if (sortTime > 0) {
                    isSort = YES;
                }
                isFromXrandm = [BTUtils compareString:XRANDOM_FLAG compare:array[3]];

            }
            BTAddress *btAddress = [[BTAddress alloc] initWithAddress:[str substringToIndex:(NSUInteger) (length - 4)] encryptPrivKey:nil pubKey:[array[0] hexToData] hasPrivKey:NO isXRandom:isFromXrandm];
            [btAddress setIsSyncComplete:[array[1] integerValue] == 1];
            [btAddress setSortTime:sortTime];
            [watchOnlyAddresses addObject:btAddress];
        }
    }
    if (isSort) {
        [watchOnlyAddresses sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            if ([obj1 sortTime] > [obj2 sortTime]) return NSOrderedAscending;
            if ([obj1 sortTime] < [obj2 sortTime]) return NSOrderedDescending;
            return NSOrderedSame;
        }];
    }
    return watchOnlyAddresses;
}

+ (NSArray *)getTrashAddressFromFile; {
    BOOL isSort = NO;
    NSMutableArray *trashAddresses = [NSMutableArray new];
    for (NSString *str in [BTUtils filesByModDate:[BTUtils getTrashDir]]) {
        NSInteger length = str.length;
        if ([str rangeOfString:@".pub"].length > 0) {
            NSString *note = [BTUtils readFile:[[BTUtils getTrashDir] stringByAppendingPathComponent:str]];
            NSArray *array = [note componentsSeparatedByString:@":"];
            long long sortTime = 0;
            BOOL isFromXRandom = NO;
            if (array.count > 3) {
                sortTime = [array[2] longLongValue];
                if (sortTime > 0) {
                    isSort = YES;
                }
                isFromXRandom = [BTUtils compareString:XRANDOM_FLAG compare:array[3]];

            }

            NSString *addressStr = [str substringToIndex:(NSUInteger) (length - 4)];
            NSString *privateKeyFullFileName = [NSString stringWithFormat:PRIVATE_KEY_FILE_NAME, [BTUtils getTrashDir], addressStr];
            NSString *encryptString = [BTUtils readFile:privateKeyFullFileName];
            BTAddress *btAddress = [[BTAddress alloc] initWithAddress:addressStr encryptPrivKey:encryptString pubKey:[array[0] hexToData] hasPrivKey:YES isXRandom:isFromXRandom];
            [btAddress setIsSyncComplete:[array[1] integerValue] == 1];
            [btAddress setSortTime:sortTime];
            btAddress.isTrashed = YES;
            [trashAddresses addObject:btAddress];
        }
    }
    if (isSort) {
        [trashAddresses sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            if ([obj1 sortTime] > [obj2 sortTime]) return NSOrderedAscending;
            if ([obj1 sortTime] < [obj2 sortTime]) return NSOrderedDescending;
            return NSOrderedSame;
        }];
    }
    return trashAddresses;
}
@end