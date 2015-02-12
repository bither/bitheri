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
#import "BTEncryptData.h"
#import "BTQRCodeUtil.h"

static BTAddressProvider *provider;

@implementation BTAddressProvider {

}

+ (instancetype)instance; {
    @synchronized (self) {
        if (provider == nil) {
            provider = [[self alloc] init];
        }
    }
    return provider;
}

#pragma mark - password
- (BOOL)changePasswordWithOldPassword:(NSString *)oldPassword andNewPassword:(NSString *)newPassword;{
    __block NSMutableDictionary *addressesPrivKeyDict = [NSMutableDictionary new];
    __block NSString *hdmEncryptPassword = nil;
    __block NSMutableDictionary *encryptSeedDict = [NSMutableDictionary new];
    __block NSMutableDictionary *encryptHDSeedDict = [NSMutableDictionary new];
    __block BTPasswordSeed *passwordSeed = nil;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select address,encrypt_private_key from addresses where encrypt_private_key is not null";
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            NSString *address = [rs stringForColumnIndex:0];
            NSString *encryptPrivKey = [rs stringForColumnIndex:1];
            addressesPrivKeyDict[address] = encryptPrivKey;
        }
        [rs close];

        sql = @"select encrypt_bither_password from hdm_bid limit 1";
        rs = [db executeQuery:sql];
        if ([rs next]) {
            hdmEncryptPassword = [rs stringForColumnIndex:0];
        }
        [rs close];

        sql = @"select hd_seed_id,encrypt_seed,encrypt_hd_seed from hd_seeds where encrypt_seed!='RECOVER'";
        rs = [db executeQuery:sql];
        while ([rs next]) {
            NSNumber *hdSeedId = @([rs intForColumnIndex:0]);
            NSString *encryptSeed = [rs stringForColumnIndex:1];
            if (![rs columnIndexIsNull:2]) {
                NSString *encryptHDSeed = [rs stringForColumnIndex:2];
                encryptHDSeedDict[hdSeedId] = encryptHDSeed;
            }
            encryptSeedDict[hdSeedId] = encryptSeed;
        }
        [rs close];

        sql = @"select password_seed from password_seed limit 1";
        rs = [db executeQuery:sql];
        if ([rs next]) {
            passwordSeed = [[BTPasswordSeed alloc] initWithString:[rs stringForColumnIndex:0]];
        }
        [rs close];
    }];

    NSArray *keys = [addressesPrivKeyDict allKeys];
    for (NSString *key in keys) {
        addressesPrivKeyDict[key] = [self changePwdWithEncryptStr:addressesPrivKeyDict[key]
                                                   andOldPassword:oldPassword andNewPassword:newPassword];
    }
    if (hdmEncryptPassword != nil) {
        hdmEncryptPassword = [self changePwdWithEncryptStr:hdmEncryptPassword
                                            andOldPassword:oldPassword andNewPassword:newPassword];
    }
    keys = [encryptSeedDict allKeys];
    for (NSString *key in keys) {
        encryptSeedDict[key] = [self changePwdWithEncryptStr:encryptSeedDict[key]
                                              andOldPassword:oldPassword andNewPassword:newPassword];
    }
    keys = [encryptHDSeedDict allKeys];
    for (NSString *key in keys) {
        encryptHDSeedDict[key] = [self changePwdWithEncryptStr:encryptHDSeedDict[key]
                                                andOldPassword:oldPassword andNewPassword:newPassword];
    }
    if (passwordSeed != nil) {
        if (![passwordSeed changePasswordWithOldPassword:oldPassword andNewPassword:newPassword])
            return NO;
    }

    __block BOOL success = YES;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        [db beginTransaction];
        NSString *sql = @"update addresses set encrypt_private_key=? where address=? and encrypt_private_key is not null";
        for (NSString *key in addressesPrivKeyDict.keyEnumerator) {
            success &= [db executeUpdate:sql, addressesPrivKeyDict[key], key];
        }
        if (hdmEncryptPassword != nil) {
            sql = @"update hdm_bid set encrypt_bither_password=?";
            success &= [db executeUpdate:sql, hdmEncryptPassword];
        }
        for (NSNumber *hdSeedId in encryptSeedDict.keyEnumerator) {
            if (encryptHDSeedDict[hdSeedId] != nil) {
                sql = @"update hd_seeds set encrypt_seed=?,encrypt_hd_seed=? where hd_seed_id=?";
                success &= [db executeUpdate:sql, encryptSeedDict[hdSeedId], encryptHDSeedDict[hdSeedId], hdSeedId];
            } else {
                sql = @"update hd_seeds set encrypt_seed=? where hd_seed_id=?";
                success &= [db executeUpdate:sql, encryptSeedDict[hdSeedId], hdSeedId];
            }
        }
        if (passwordSeed != nil) {
            sql = @"update password_seed set password_seed=?";
            success &= [db executeUpdate:sql, [passwordSeed toPasswordSeedString]];
        }
        if (success) {
            [db commit];
        } else {
            [db rollback];
        }

    }];

    return success;
}

- (NSString *)changePwdWithEncryptStr:(NSString *)encryptStr andOldPassword:(NSString *)oldPassword andNewPassword:(NSString *)newPassword;{
    BTEncryptData *encryptedData = [[BTEncryptData alloc] initWithStr:encryptStr];
    return [[[BTEncryptData alloc] initWithData:[encryptedData decrypt:oldPassword] andPassowrd:newPassword] toEncryptedString];
}

- (BTPasswordSeed *)getPasswordSeed;{
    __block BTPasswordSeed *passwordSeed = nil;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select password_seed from password_seed limit 1";
        FMResultSet *rs = [db executeQuery:sql];
        if ([rs next]) {
            NSString *str = [rs stringForColumnIndex:0];
            passwordSeed = [[BTPasswordSeed alloc] initWithString:str];
        }
        [rs close];
    }];
    return passwordSeed;
}

-(BOOL)hasPasswordSeed{
    __block BOOL  hasPasswordSeed= NO;
    NSString *sql = @"select ifnull(count(0),0) cnt from password_seed";
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:sql];
        if ([rs next]) {
            hasPasswordSeed = [rs intForColumn:@"cnt"] > 0;
        }
        [rs close];
    }];

    return hasPasswordSeed;
}
- (BOOL)addPasswordSeedWithPasswordSeed:(BTPasswordSeed *)passwordSeed andDB:(FMDatabase *)db {
    NSString *sql = @"select ifnull(count(0),0) from password_seed";
    FMResultSet *rs = [db executeQuery:sql];
    BOOL isExist = YES;
    if ([rs next]) {
        isExist = [rs boolForColumnIndex:0];
    }
    [rs close];
    BOOL result = YES;
    if (!isExist) {
        NSString * passwordSeedStr=[BTQRCodeUtil replaceNewQRCode:[passwordSeed  toPasswordSeedString]];
        sql = @"insert into password_seed(password_seed) values(?)";
        result = [db executeUpdate:sql,passwordSeedStr];
    }
    return result;
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

- (int)addHDSeedWithEncryptSeed:(NSString *)encryptSeed andEncryptHDSeed:(NSString *)encryptHDSeed
                andFirstAddress:(NSString *)firstAddress andIsXRandom:(BOOL)isXRandom
                andPasswordSeed:(NSString *)passwordSeed;{
    __block int hdSeedId = -1;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"insert into hd_seeds(encrypt_seed,encrypt_hd_seed,hdm_address,is_xrandom) values(?,?,?,?)";
        [db beginTransaction];
        BOOL success = [db executeUpdate:sql, encryptSeed, encryptHDSeed, firstAddress, (isXRandom ? @1: @0)];
        if (passwordSeed != nil) {
            success &= [self addPasswordSeedWithPasswordSeed:[[BTPasswordSeed alloc] initWithAddress:passwordSeed andEncryptStr:encryptSeed] andDB:db];
        }
        sql = @"select hd_seed_id from hd_seeds order by hd_seed_id desc limit 1";
        FMResultSet *rs = [db executeQuery:sql, @(hdSeedId)];
        if ([rs next]) {
            hdSeedId = [rs intForColumnIndex:0];
        }
        [rs close];
        if (success) {
            [db commit];
        } else {
            [db rollback];
        }

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

- (BOOL)addHDMBid:(BTHDMBid *)hdmBid andPasswordSeed:(NSString *)passwordSeed;{
    __block BOOL success = YES;
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
            [db beginTransaction];
            success &= [db executeUpdate:sql, hdmBid.address, hdmBid.encryptedBitherPassword];
            success &= [self addPasswordSeedWithPasswordSeed:[[BTPasswordSeed alloc] initWithAddress:passwordSeed
                                                                            andEncryptStr:hdmBid.encryptedBitherPassword]
                                            andDB:db];
            if (success) {
                [db commit];
            } else {
                [db rollback];
            }
        } else {
            sql = @"update hdm_bid set encrypt_bither_password=? where hdm_bid=?";
            [db executeUpdate:sql, hdmBid.encryptedBitherPassword, hdmBid.address];
        }
    }];
    return success;
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
            [addresses addObject:[self formatHDMAddress:rs withKeyChain:keychain]];
        }
        [rs close];
    }];
    return addresses;
}

- (BOOL)prepareHDMAddressesWithHDSeedId:(int)hdSeedId andPubs:(NSArray *)pubs;{
    __block BOOL success = YES;
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
                success &= [db executeUpdate:sql, @(hdSeedId), @(pub.index), [NSString base58WithData:pub.hot]
                        , [NSString base58WithData:pub.cold], [NSNull null], [NSNull null], @(0)];
            }
            if (success) {
                [db commit];
            } else {
                [db rollback];
            }
        }
    }];
    return success;
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

- (BOOL)recoverHDMAddressesWithHDSeedId:(int)hdSeedId andHDMAddresses:(NSArray *)addresses;{
    __block BOOL success = YES;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"insert into hdm_addresses(hd_seed_id,hd_seed_index,pub_key_hot,pub_key_cold,pub_key_remote,address,is_synced) values(?,?,?,?,?,?,?)";
        [db beginTransaction];
        for (BTHDMAddress *address in addresses) {
            success &= [db executeUpdate:sql, @(hdSeedId), @(address.pubs.index), [NSString base58WithData:address.pubs.hot]
                    , [NSString base58WithData:address.pubs.cold], [NSString base58WithData:address.pubs.remote]
                    , address.address, @(0)];
        }
        if (success) {
            [db commit];
        } else {
            [db rollback];
        }
    }];
    return success;
}

- (BOOL)completeHDMAddressesWithHDSeedId:(int)hdSeedId andHDMAddresses:(NSArray *)addresses;{
    __block BOOL success = YES;
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
                success &= [db executeUpdate:sql, [NSString base58WithData:address.pubs.remote], address.address, @(hdSeedId), @(address.pubs.index)];
            }
            if (success) {
                [db commit];
            } else {
                [db rollback];
            }
        }
    }];
    return success;
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

- (void)updateSyncCompleteHDSeedId:(int)hdSeedId hdSeedIndex:(uint)hdSeedIndex syncComplete:(BOOL)syncComplete{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update hdm_addresses set is_synced=? where hd_seed_id=? and hd_seed_index=?";
        [db executeUpdate:sql, (syncComplete ? @1 : @0), @(hdSeedId), @(hdSeedIndex)];
    }];
}

- (BTHDMAddress *)formatHDMAddress:(FMResultSet *)rs withKeyChain:(BTHDMKeychain *)keychain; {
    BTHDMPubs *pubs = [self formatHDMPubs:rs];
    NSString *address = nil;
    if (![rs columnIsNull:@"address"]) {
        address = [rs stringForColumn:@"address"];
    }
    BOOL isSynced = [rs boolForColumn:@"is_synced"];
    return [[BTHDMAddress alloc] initWithPubs:pubs address:address syncCompleted:isSynced andKeychain:keychain];
}

- (BTHDMPubs *)formatHDMPubs:(FMResultSet *)rs; {
    BTHDMPubs *pubs = [BTHDMPubs new];
    pubs.index = (UInt32) [rs intForColumn:@"hd_seed_index"];
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
        NSString *sql = @"select address,ifnull(length(encrypt_private_key)>0,0) has_priv_key,pub_key,is_xrandom,is_trash,is_synced,sort_time "
                " from addresses order by sort_time desc";
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            [addresses addObject:[self formatAddress:rs]];
        }
        [rs close];
    }];
    return addresses;
}

- (BOOL)addAddress:(BTAddress *)address;{
    __block BOOL success = YES;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"insert into addresses(address,encrypt_private_key,pub_key,is_xrandom,is_trash,is_synced,sort_time) "
                " values(?,?,?,?,?,?,?)";
        [db beginTransaction];
        success &= [db executeUpdate:sql, address.address, address.encryptPrivKeyForCreate == nil ? [NSNull null] : address.encryptPrivKeyForCreate
                , [NSString base58WithData:address.pubKey], @(address.isFromXRandom), @(address.isTrashed)
                , @(address.isSyncComplete), @(address.sortTime)];
        if (address.encryptPrivKeyForCreate != nil) {
            NSString *str = [BTEncryptData encryptedString:address.encryptPrivKeyForCreate
                                           addIsCompressed:address.pubKey.length < 65
                                              andIsXRandom:address.isFromXRandom];
            success &= [self addPasswordSeedWithPasswordSeed:[[BTPasswordSeed alloc] initWithAddress:address.address andEncryptStr:str] andDB:db];
        }
        if (success) {
            [db commit];
        } else {
            [db rollback];
        }
    }];
    return success;
}

- (BOOL)addAddresses:(NSArray *)addresses andPasswordSeed:(BTPasswordSeed *)passwordSeed; {
    __block BOOL result = YES;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"insert into addresses(address,encrypt_private_key,pub_key,is_xrandom,is_trash,is_synced,sort_time) "
                " values(?,?,?,?,?,?,?)";
        BOOL success = YES;
        [db beginTransaction];
        for (BTAddress *address in addresses) {
            success &= [db executeUpdate:sql, address.address, address.encryptPrivKeyForCreate == nil ? [NSNull null] : address.encryptPrivKeyForCreate
                    , [NSString base58WithData:address.pubKey], @(address.isFromXRandom), @(address.isTrashed)
                    , @(address.isSyncComplete), @(address.sortTime)];
        }
        if (passwordSeed != nil) {
            success &= [self addPasswordSeedWithPasswordSeed:passwordSeed andDB:db];
        }

        if (success) {
            [db commit];
        } else {
            [db rollback];
        }
        result = success;
    }];
    return result;
}

- (NSString *)getEncryptPrivKeyWith:(NSString *)address;{
    __block NSString *encryptPrivKey = nil;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select encrypt_private_key from addresses where address=?";
        FMResultSet *rs = [db executeQuery:sql, address];
        if ([rs next]) {
            encryptPrivKey = [rs stringForColumnIndex:0];
        }
        [rs close];
    }];
    return encryptPrivKey;
}

- (void)updatePrivateKey:(BTAddress *)address;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update addresses set encrypt_private_key=? where address=?";
        [db executeUpdate:sql, address.encryptPrivKey, address.address];
    }];
}

- (void)removeWatchOnlyAddress:(BTAddress *)address;{
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"delete from addresses where address=? and encrypt_private_key is null";
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
        NSString *sql = @"update addresses set is_synced=? where address=?";
        [db executeUpdate:sql, address.isSyncComplete ? @1 : @0, address.address];
    }];
}

- (BTAddress *)formatAddress:(FMResultSet *)rs;{
    NSString *address = [rs stringForColumn:@"address"];
    BOOL hasPrivKey = [rs boolForColumn:@"has_priv_key"];
    NSData *pubKey = [[rs stringForColumn:@"pub_key"] base58ToData];
    BOOL isFromXRandom = [rs boolForColumn:@"is_xrandom"];
    BOOL isTrashed = [rs boolForColumn:@"is_trash"];
    BOOL isSyncComplete = [rs boolForColumn:@"is_synced"];
    long long int sortTime = [rs longLongIntForColumn:@"sort_time"];
    BTAddress *btAddress = [[BTAddress alloc] initWithAddress:address encryptPrivKey:nil pubKey:pubKey hasPrivKey:hasPrivKey isXRandom:isFromXRandom];
    btAddress.isTrashed = isTrashed;
    btAddress.isSyncComplete = isSyncComplete;
    btAddress.sortTime = sortTime;
    return btAddress;
}
@end