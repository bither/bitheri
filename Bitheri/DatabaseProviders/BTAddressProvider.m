//
//  BTAddressProvider.m
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
#import "BTAddressProvider.h"
#import "BTDatabaseManager.h"

@implementation BTAddressProvider {

}

- (BOOL)changePasswordWithOldPassword:(NSString *)oldPassword andNewPassword:(NSString *)newPassword;{
    return NO;
}

#pragma mark - hdm
- (NSArray *)getHDSeedIds; {
    __block NSMutableArray *hdSeedIds = [NSMutableArray new];
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select hd_seed_id from hd_seeds";
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            [hdSeedIds addObject:@([rs intForColumnIndex:0])];
        }
        [rs close];
    }];
    return hdSeedIds;
}

- (NSString *)getEncryptSeed:(int)hdSeedId;{
    __block NSString *encryptSeed = nil;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select encrypt_seed from hd_seeds where hd_seed_id=?";
        FMResultSet *rs = [db executeQuery:sql, @(hdSeedId)];
        if ([rs next]) {
            encryptSeed = [rs stringForColumnIndex:0];
        }
        [rs close];
    }];
    return encryptSeed;
}

- (NSString *)getEncryptHDSeed:(int)hdSeedId;{
    __block NSString *encryptHDSeed = nil;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select encrypt_hd_seed from hd_seeds where hd_seed_id=?";
        FMResultSet *rs = [db executeQuery:sql, @(hdSeedId)];
        if ([rs next]) {
            encryptHDSeed = [rs stringForColumnIndex:0];
        }
        [rs close];
    }];
    return encryptHDSeed;
}

- (void)updateHDSeedWithHDSeedId:(int)hdSeedId andEncryptHDSeed:(NSString *)encryptHDSeed; {
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update hd_seeds set encrypt_hd_seed=? where hd_seed_id=?";
        [db executeUpdate:sql, encryptHDSeed, @(hdSeedId)];
    }];
}

- (void)updateHDSeedWithHDSeedId:(int)hdSeedId andEncryptSeed:(NSString *)encryptSeed andEncryptHDSeed:(NSString *)encryptHDSeed; {
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update hd_seeds set encrypt_seed=?, encrypt_hd_seed=? where hd_seed_id=?";
        [db executeUpdate:sql, encryptSeed, encryptHDSeed, @(hdSeedId)];
    }];
}

- (BOOL)isHDSeedFromXRandom:(int)hdSeedId; {
    __block BOOL isXRandom;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select is_xrandom from hd_seeds where hd_seed_id=?";
        FMResultSet *rs = [db executeQuery:sql, @(hdSeedId)];
        if ([rs next]) {
            isXRandom = [rs boolForColumnIndex:0];
        }
        [rs close];
    }];
    return isXRandom;
}

- (NSString *)getHDFirstAddress:(int)hdSeedId;{
    __block NSString *firstAddress = nil;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select hdm_address from hd_seeds where hd_seed_id=?";
        FMResultSet *rs = [db executeQuery:sql, @(hdSeedId)];
        if ([rs next]) {
            firstAddress = [rs stringForColumnIndex:0];
        }
        [rs close];
    }];
    return firstAddress;
}

- (int)addHDSeedWithEncryptSeed:(NSString *)encryptSeed andEncryptHDSeed:(NSString *)encryptHDSeed andFirstAddress:(NSString *)firstAddress andIsXRandom:(BOOL)isXRandom;{
    __block int hdSeedId = 0;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"insert into hd_seeds(encrypt_seed,encrypt_hd_seed,hdm_address,is_xrandom) values(?,?,?,?)";
        [db executeUpdate:sql, encryptSeed, encryptHDSeed, firstAddress, (isXRandom ? @1: @0)];
        sql = @"select hd_seed_id from hd_seeds order by hd_seed_id desc limit 1";
        FMResultSet *rs = [db executeQuery:sql, @(hdSeedId)];
        if ([rs next]) {
            hdSeedId = [rs intForColumnIndex:0];
        }
        [rs close];
    }];
    return hdSeedId;
}

- (BTHDMBid *)getHDMBid; {
    __block BTHDMBid *hdmBid = nil;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select hdm_bid,encrypt_bither_password from hdm_bid";
        FMResultSet *rs = [db executeQuery:sql];
        if ([rs next]) {
            NSString *address = [rs stringForColumnIndex:0];
            NSString *encryptBitherPassword = [rs stringForColumnIndex:1];
            hdmBid = [[BTHDMBid alloc] initWithHDMBid:address andEncryptBitherPassword:encryptBitherPassword];
        }
        [rs close];
    }];
    return hdmBid;
}

- (void)addHDMBid:(BTHDMBid *)hdmBid;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count(0) cnt from hdm_bid";
        BOOL isExist = YES;
        FMResultSet *rs = [db executeQuery:sql];
        if ([rs next]) {
            isExist = [rs intForColumnIndex:0] > 0;
        }
        [rs close];
        if (!isExist) {
            sql = @"insert into hdm_bid(hdm_bid,encrypt_bither_password) values(?,?)";
            [db executeUpdate:sql, hdmBid.address, hdmBid.encryptedBitherPassword];
        }
    }];
}

- (void)changeHDMBIdPassword:(BTHDMBid *)hdmBid;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update hdm_bid set encrypt_bither_password=? where hdm_bid=?";
        [db executeUpdate:sql, hdmBid.encryptedBitherPassword, hdmBid.address];
    }];
}



- (NSArray *)getHDMAddressInUse:(BTHDMKeychain *)keychain;{
    __block NSMutableArray *addresses = [NSMutableArray new];
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select hd_seed_index,pub_key_hot,pub_key_cold,pub_key_remote,address,is_synced "
                " from hdm_addresses "
                " where hd_seed_id=? and address is not null order by hd_seed_index";
        FMResultSet *rs = [db executeQuery:sql, @(keychain.hdSeedId)];
        while ([rs next]) {
            [addresses addObject:[self formatHDMAddress:rs]];
        }
        [rs close];
    }];
    return addresses;
}

- (void)prepareHDMAddressesWithHDSeedId:(int)hdSeedId andPubs:(NSArray *)pubs;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        BOOL isExist = NO;
        NSString *sql = @"select count(0) cnt from hdm_addresses where hd_seed_id=? and hd_seed_index=?";
        FMResultSet *rs = nil;
        for (BTHDMPubs *pub in pubs) {
            rs = [db executeQuery:sql, @(hdSeedId), @(pub.index)];
            while ([rs next]) {
                isExist &= [rs intForColumnIndex:0] > 0;
            }
            [rs close];
        }
        sql = @"insert into hdm_addresses(hd_seed_id,hd_seed_index,pub_key_hot,pub_key_cold,pub_key_remote,address,is_synced) values(?,?,?,?,?,?,?)";
        if (!isExist) {
            [db beginTransaction];
            for (BTHDMPubs *pub in pubs) {
                [db executeUpdate:sql, @(hdSeedId), @(pub.index), [NSString base58WithData:pub.hot]
                        , [NSString base58WithData:pub.cold], [NSNull null], [NSNull null], @(0)];
            }
            [db commit];
        }
    }];
}

- (NSArray *)getUncompletedHDMAddressPubs:(int) hdSeedId andCount:(int)count;{
    __block NSMutableArray *pubsList = [NSMutableArray new];
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select * from hdm_addresses where hd_seed_id=? and pub_key_remote is null limit ?";
        FMResultSet *rs = [db executeQuery:sql, @(hdSeedId), @(count)];
        while ([rs next]) {
            [pubsList addObject:[self formatHDMPubs:rs]];
        }
        [rs close];
    }];
    return pubsList;
}

- (int)maxHDMAddressPubIndex:(int)hdSeedId;{
    //including completed and uncompleted
    __block int max = -1;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select ifnull(max(hd_seed_index),-1) hd_seed_index from hdm_addresses where hd_seed_id=?";
        FMResultSet *rs = [db executeQuery:sql, @(hdSeedId)];
        if ([rs next]) {
            max = [rs intForColumnIndex:0];
        }
        [rs close];
    }];
    return max;
}

- (void)recoverHDMAddressesWithHDSeedId:(int)hdSeedId andHDMAddresses:(NSArray *)addresses;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"insert into hdm_addresses(hd_seed_id,hd_seed_index,pub_key_hot,pub_key_cold,pub_key_remote,address,is_synced) values(?,?,?,?,?,?,?)";
        [db beginTransaction];
        for (BTHDMAddress *address in addresses) {
            [db executeUpdate:sql, @(hdSeedId), @(address.pubs.index), [NSString base58WithData:address.pubs.hot]
                    , [NSString base58WithData:address.pubs.cold], [NSString base58WithData:address.pubs.remote]
                    , address.address, @(0)];
        }
        [db commit];
    }];
}

- (void)completeHDMAddressesWithHDSeedId:(int)hdSeedId andHDMAddresses:(NSArray *)addresses;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        BOOL isExist = NO;
        NSString *sql = @"select count(0) cnt from hdm_addresses where hd_seed_id=? and hd_seed_index=? and pub_key_remote is null";
        FMResultSet *rs = nil;
        for (BTHDMAddress *address in addresses) {
            rs = [db executeQuery:sql, @(hdSeedId), @(address.pubs.index)];
            while ([rs next]) {
                isExist &= [rs intForColumnIndex:0] > 0;
            }
            [rs close];
        }
        sql = @"update hdm_addresses set pub_key_remote=?,address=? where hd_seed_id=? and hd_seed_index=?";
        if (!isExist) {
            [db beginTransaction];
            for (BTHDMAddress *address in addresses) {
                [db executeUpdate:sql, [NSString base58WithData:address.pubs.remote], address, @(hdSeedId), @(address.pubs.index)];
            }
            [db commit];
        }
    }];
}

- (void)setHDMPubsRemoteWithHDSeedId:(int)hdSeedId andIndex:(int) index andPubKeyRemote:(NSData *) pubKeyRemote;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        BOOL isExist = YES;
        NSString *sql = @"select count(0) cnt from hdm_addresses where hd_seed_id=? and hd_seed_index=? and pub_key_remote is null";
        FMResultSet *rs = nil;
        rs = [db executeQuery:sql, @(hdSeedId), @(index)];
        if ([rs next]) {
            isExist = [rs intForColumnIndex:0] > 0;
        }
        [rs close];
        sql = @"update hdm_addresses set pub_key_remote=? where hd_seed_id=? and hd_seed_index=?";
        if (!isExist) {
            [db executeUpdate:sql, [NSString base58WithData:pubKeyRemote], @(hdSeedId), @(index)];
        }
    }];
}

- (int)uncompletedHDMAddressCount:(int)hdSeedId;{
    __block int cnt = 0;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count(0) cnt from hdm_addresses where hd_seed_id=?  and pub_key_remote is null";
        FMResultSet *rs = [db executeQuery:sql, @(hdSeedId)];
        if ([rs next]) {
            cnt = [rs intForColumnIndex:0];
        }
        [rs close];
    }];
    return cnt;
}

- (void)syncCompleteHDSeedId:(int)hdSeedId hdSeedIndex:(int)hdSeedIndex;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update hdm_addresses set is_synced=1 where hd_seed_id=? and hd_seed_index=?";
        [db executeUpdate:sql, @(hdSeedId), @(hdSeedIndex)];
    }];
}

- (BTHDMAddress *)formatHDMAddress:(FMResultSet *)rs; {
    BTHDMAddress *address = [BTHDMAddress new];
    address.pubs = [self formatHDMPubs:rs];
    if (![rs columnIsNull:@"address"]) {
        address.address = [rs stringForColumn:@"address"];
    } else {
        address.address = nil;
    }
    address.isSynced = [rs boolForColumn:@"is_synced"];
    return address;
}

- (BTHDMPubs *)formatHDMPubs:(FMResultSet *)rs; {
    BTHDMPubs *pubs = [BTHDMPubs new];
    pubs.index = [rs intForColumn:@"hd_seed_index"];
    pubs.hot = [[rs stringForColumn:@"pub_key_hot"] base58ToData];
    pubs.cold = [[rs stringForColumn:@"pub_key_cold"] base58ToData];
    if (![rs columnIsNull:@"pub_key_remote"]) {
        pubs.remote = [[rs stringForColumn:@"pub_key_remote"] base58ToData];
    } else {
        pubs.remote = nil;
    }
    return pubs;
}

#pragma mark - normal
- (NSArray *)getAddresses; {
    __block NSMutableArray *addresses = [NSMutableArray new];
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select address,encrypt_private_key,pub_key,is_xrandom,is_trash,is_synced,sort_time "
                " from addresses order by sort_time desc";
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            [addresses addObject:[self formatAddress:rs]];
        }
        [rs close];
    }];
    return addresses;
}

- (void)addAddress:(BTAddress *)address;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"insert into addresses(address,encrypt_private_key,pub_key,is_xrandom,is_trash,is_synced,sort_time) "
                " values(?,?,?,?,?,?,?)";
        [db executeUpdate:sql, address.address, address.encryptPrivKey, [NSString base58WithData:address.pubKey]
                , @(address.isFromXRandom), @(address.isTrashed), @(address.isSyncComplete), @(address.sortTime)];
    }];
}

- (void)updatePrivateKey:(BTAddress *)address;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update addresses set encrypt_private_key=? where address=?";
        [db executeUpdate:sql, address.encryptPrivKey, address.address];
    }];
}

- (void)removeWatchOnlyAddress:(BTAddress *)address;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update addresses set is_trash=1 where address=?";
        [db executeUpdate:sql, address.address];
    }];
}

- (void)trashPrivKeyAddress:(BTAddress *)address;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update addresses set is_trash=1 where address=?";
        [db executeUpdate:sql, address.address];
    }];
}

- (void)restorePrivKeyAddress:(BTAddress *)address;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update addresses set is_trash=0,is_synced=0,sort_time=? where address=?";
        [db executeUpdate:sql, @(address.sortTime), address.address];
    }];
}

- (void)updateSyncComplete:(BTAddress *)address;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update addresses set is_synced=1 where address=?";
        [db executeUpdate:sql, address.address];
    }];
}

- (BTAddress *)formatAddress:(FMResultSet *)rs;{
    BTAddress *address = [[BTAddress alloc] init];
    address.hasPrivKey = [rs columnIsNull:@"encrypt_private_key"];
    address.encryptPrivKey = [rs stringForColumn:@"encrypt_private_key"];
    address.pubKey = [[rs stringForColumn:@"pub_key"] base58ToData];
    address.isFromXRandom = [rs boolForColumn:@"is_xrandom"];
    address.isTrashed = [rs boolForColumn:@"is_trash"];
    address.isSyncComplete = [rs boolForColumn:@"is_synced"];
    address.sortTime = [rs longLongIntForColumn:@"sort_time"];
    return address;
}
@end