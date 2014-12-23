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
//#import "BTOutItem.h"
#import "BTIn.h"
#import "BTOut.h"
#import "BTQRCodeUtil.h"
#import "asn1t.h"

//static NSData *txOutput(NSData *txHash, uint32_t n) {
//    NSMutableData *d = [NSMutableData dataWithCapacity:CC_SHA256_DIGEST_LENGTH + sizeof(uint32_t)];
//
//    [d appendData:txHash];
//    [d appendUInt32:n];
//    return d;
//}

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
    tc=[NSCondition new];
    self.isReady=NO;
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
    [self initPrivKeyAddressByDesc];
    [self initWatchOnlyAddressByDesc];
    [self initTrashAddressByDesc];
    self.isReady=YES;
    [tc signal];
    [tc unlock];
    dispatch_sync(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:BTAddressManagerIsReady
                                                            object:nil userInfo:nil];
    });
   
    
}

- (NSInteger)addressCount {
    return [[self privKeyAddresses] count] + [[self watchOnlyAddresses] count];
}

-(NSMutableArray*)privKeyAddresses{
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
-(NSMutableArray *)watchOnlyAddresses{
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
-(NSMutableArray *)trashAddresses{
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
-(NSMutableSet *)addressesSet{
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

- (void)initPrivKeyAddressByDesc {
    BOOL isSort=NO;
    for (NSString *str in [BTUtils filesByModDate:[BTUtils getPrivDir]]) {
        NSInteger length = str.length;
        if ([str rangeOfString:@".pub"].length > 0) {
            NSString *note = [BTUtils readFile:[[BTUtils getPrivDir] stringByAppendingPathComponent:str]];
            NSArray *array = [note componentsSeparatedByString:@":"];
            long long sortTime=0;
            BOOL isFromXRandom =NO;
            if (array.count>3) {
                sortTime=[[array objectAtIndex:2] longLongValue];
                if (sortTime>0) {
                    isSort=YES;
                }
                isFromXRandom =[BTUtils compareString:XRANDOM_FLAG compare:[array objectAtIndex:3]];
                
            }
            BTAddress *btAddress = [[BTAddress alloc] initWithAddress:[str substringToIndex:(NSUInteger) (length - 4)] pubKey:[array[0] hexToData] hasPrivKey:YES isXRandom:isFromXRandom];
            [btAddress setIsSyncComplete:[array[1] integerValue] == 1];
            [btAddress setSortTime:sortTime];
            [_privKeyAddresses addObject:btAddress];
            [_addressesSet addObject:btAddress.address];
        }
    }
    if (isSort) {
        [_privKeyAddresses sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            if ([obj1 sortTime] > [obj2 sortTime]) return NSOrderedAscending;
            if ([obj1 sortTime] < [obj2 sortTime]) return NSOrderedDescending;
            return NSOrderedSame;
        }];
    }
}

- (void)initWatchOnlyAddressByDesc {
    BOOL isSort=NO;
    for (NSString *str in [BTUtils filesByModDate:[BTUtils getWatchOnlyDir]]) {
        NSInteger length = str.length;
        if ([str rangeOfString:@".pub"].length > 0) {
            NSString *note = [BTUtils readFile:[[BTUtils getWatchOnlyDir] stringByAppendingPathComponent:str]];
            NSArray *array = [note componentsSeparatedByString:@":"];
            long long sortTime=0;
            BOOL isFromXrandm=NO;
            if (array.count>3) {
                sortTime=[[array objectAtIndex:2] longLongValue];
                if (sortTime>0) {
                    isSort=YES;
                }
                isFromXrandm=[BTUtils compareString:XRANDOM_FLAG compare:[array objectAtIndex:3]];
                
            }
            BTAddress *btAddress = [[BTAddress alloc] initWithAddress:[str substringToIndex:(NSUInteger) (length - 4)] pubKey:[array[0] hexToData] hasPrivKey:NO isXRandom:isFromXrandm];
            [btAddress setIsSyncComplete:[array[1] integerValue] == 1];
            [btAddress setSortTime:sortTime];
            [_watchOnlyAddresses addObject:btAddress];
            [_addressesSet addObject:btAddress.address];
        }
    }
    if (isSort) {
        [_watchOnlyAddresses sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            if ([obj1 sortTime] > [obj2 sortTime]) return NSOrderedAscending;
            if ([obj1 sortTime] < [obj2 sortTime]) return NSOrderedDescending;
            return NSOrderedSame;
        }];
    }
}

- (void)initTrashAddressByDesc {
    BOOL isSort = NO;
    for (NSString *str in [BTUtils filesByModDate:[BTUtils getTrashDir]]) {
        NSInteger length = str.length;
        if ([str rangeOfString:@".pub"].length > 0) {
            NSString *note = [BTUtils readFile:[[BTUtils getTrashDir] stringByAppendingPathComponent:str]];
            NSArray *array = [note componentsSeparatedByString:@":"];
            long long sortTime = 0;
            BOOL isFromXRandom = NO;
            if (array.count > 3) {
                sortTime = [[array objectAtIndex:2] longLongValue];
                if (sortTime > 0) {
                    isSort = YES;
                }
                isFromXRandom = [BTUtils compareString:XRANDOM_FLAG compare:[array objectAtIndex:3]];

            }

            BTAddress *btAddress = [[BTAddress alloc] initWithAddress:[str substringToIndex:(NSUInteger) (length - 4)] pubKey:[array[0] hexToData] hasPrivKey:YES isXRandom:isFromXRandom];
            [btAddress setIsSyncComplete:[array[1] integerValue] == 1];
            [btAddress setSortTime:sortTime];
            btAddress.isTrashed = YES;

            [_trashAddresses addObject:btAddress];
        }
    }
    if (isSort) {
        [_trashAddresses sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            if ([obj1 sortTime] > [obj2 sortTime]) return NSOrderedAscending;
            if ([obj1 sortTime] < [obj2 sortTime]) return NSOrderedDescending;
            return NSOrderedSame;
        }];
    }
}

- (void)addAddress:(BTAddress *)address {
    DDLogDebug(@"addAddress %@ ,hasPrivKey %d", address.address, address.hasPrivKey);

    if (address.hasPrivKey) {
        [address saveNewAddress:[self getPrivKeySortTime]];
        [self.privKeyAddresses insertObject:address atIndex:0];
        [self.addressesSet addObject:address.address];
    } else {
        [address saveNewAddress:self.getWatchOnlySortTime];
        [self.watchOnlyAddresses insertObject:address atIndex:0];
        [self.addressesSet addObject:address.address];
    }
    
}

- (void)stopMonitor:(BTAddress *)address {
    DDLogDebug(@"stopMonitor %@ ,hasPrivKey %d", address.address, address.hasPrivKey);
    [address removeWatchOnly];
    [self.watchOnlyAddresses removeObject:address];
    [self.addressesSet removeObject:address.address];
}

- (void)trashPrivKey:(BTAddress *)address; {
    if (address.hasPrivKey && address.balance == 0) {
        DDLogDebug(@"trash priv key %@", address.address);
        [address trashPrivKey];
        [self.privKeyAddresses removeObject:address];
        [self.addressesSet removeObject:address.address];
        [self.trashAddresses addObject:address];
    }
}

- (void)restorePrivKey:(BTAddress *)address; {
    if (address.hasPrivKey) {
        DDLogDebug(@"restore priv key %@", address.address);
        [address restorePrivKey];
        [address saveNewAddress:[self getPrivKeySortTime]];
        [self.privKeyAddresses insertObject:address atIndex:0];
        [self.addressesSet addObject:address.address];
        [self.trashAddresses removeObject:address];
    }
}

- (NSMutableArray *)allAddresses {
    NSMutableArray *allAddresses = [NSMutableArray new];
    [allAddresses addObjectsFromArray:self.privKeyAddresses];
    [allAddresses addObjectsFromArray:self.watchOnlyAddresses];
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
    return allSync;
}

- (BOOL)changePassphraseWithOldPassphrase:(NSString *)oldPassphrase andNewPassphrase:(NSString *)newPassphrase; {
    NSMutableArray *encryptPrivKeys = [NSMutableArray new];
    NSMutableArray *privAddresses = [NSMutableArray new];
    NSMutableArray *encryptTrashKeys = [NSMutableArray new];
    NSMutableArray *trashAddresses = [NSMutableArray new];
    for (BTAddress *address in self.privKeyAddresses) {
        NSString *encryptPrivKey = [address reEncryptPrivKeyWithOldPassphrase:oldPassphrase andNewPassphrase:newPassphrase];
        if (encryptPrivKey == nil) {
            return NO;
        }
        [encryptPrivKeys addObject:encryptPrivKey];
        [privAddresses addObject:address];
    }
    for (BTAddress *address in self.trashAddresses) {
        NSString *encryptTrashKey = [address reEncryptPrivKeyWithOldPassphrase:oldPassphrase andNewPassphrase:newPassphrase];
        if (encryptTrashKey == nil) {
            return NO;
        }
        [encryptTrashKeys addObject:encryptTrashKey];
        [trashAddresses addObject:address];
    }
    for (NSUInteger i = 0; i < privAddresses.count; i++) {
        BTAddress *address = privAddresses[i];
        address.encryptPrivKey = encryptPrivKeys[i];
        [address savePrivate];
    }
    for (NSUInteger i = 0; i < trashAddresses.count; i++) {
        BTAddress *address = trashAddresses[i];
        address.encryptPrivKey = encryptTrashKeys[i];
        [address saveTrash];
    }
    return YES;
}

- (BOOL)isTxRelated:(BTTx *)tx;{
    for (BTAddress *address in self.allAddresses) {
        if([self isAddress:address.address containsTransaction:tx]){
            return true;
        }
    }
    return false;
}

- (BOOL)isAddress:(NSString *)address containsTransaction:(BTTx *)transaction {
    if ([[NSSet setWithArray:transaction.outputAddresses] containsObject:address]) return YES;
    return [[BTTxProvider instance] isAddress:address containsTx:transaction];
}

- (BOOL)registerTx:(BTTx *)tx withTxNotificationType:(TxNotificationType)txNotificationType; {
    if ([[BTTxProvider instance] isExist:tx.txHash]) {
        // already in db
        return YES;
    }

    if ([[BTTxProvider instance] isTxDoubleSpendWithConfirmedTx:tx]) {
        // double spend with confirmed tx
        return false;
    }

    NSMutableSet *needNotifyAddressHashSet = [NSMutableSet new];
    for (BTOut *out in tx.outs) {
        if ([self.addressesSet containsObject:out.outAddress])
            [needNotifyAddressHashSet addObject:out.outAddress];
    }

    NSArray *inAddresses = [[BTTxProvider instance] getInAddresses:tx];
    for (NSString *address in inAddresses) {
        if ([self.addressesSet containsObject:address])
            [needNotifyAddressHashSet addObject:address];
    }
    if (needNotifyAddressHashSet.count > 0) {
        [[BTTxProvider instance] add:tx];
        DDLogDebug(@"register tx %@", [NSString hexWithHash:tx.txHash]);
    }
    for (BTAddress *address in [BTAddressManager instance].allAddresses) {
        if ([needNotifyAddressHashSet containsObject:address.address]) {
            [address registerTx:tx withTxNotificationType:txNotificationType];
        }
    }
    return needNotifyAddressHashSet.count > 0;
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

- (void)blockChainChanged; {
    for (BTAddress *address in self.allAddresses) {
        [address updateCache];
    }
}
@end