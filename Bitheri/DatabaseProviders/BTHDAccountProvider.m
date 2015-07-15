//
//  BTHDAccountProvider.m
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
#import "BTHDAccountProvider.h"
#import "BTDatabaseManager.h"
#import "NSString+Base58.h"
#import "BTPasswordSeed.h"
#import "BTAddressProvider.h"

@implementation BTHDAccountProvider {

}

+ (instancetype)instance; {
    static BTHDAccountProvider *blockProvider = nil;
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        blockProvider = [[BTHDAccountProvider alloc] init];
    });
    return blockProvider;
}

- (int)addHDAccountWithEncryptedMnemonicSeed:(NSString *)encryptedMnemonicSeed encryptSeed:(NSString *)encryptSeed
                                firstAddress:(NSString *)firstAddress isXRandom:(BOOL)isXRandom
                             encryptSeedOfPS:(NSString *)encryptSeedOfPs addressOfPS:(NSString *)addressOfPs
                                 externalPub:(NSData *)externalPub internalPub:(NSData *)internalPub;{
    __block int hdAccountId = -1;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        [db beginTransaction];
        NSString *sql = @"insert into hd_account(encrypt_mnemonic_seed,encrypt_seed"
                ",hd_address,external_pub,internal_pub,is_xrandom) "
                " values(?,?,?,?,?,?)";
        BOOL success = [db executeUpdate:sql, encryptedMnemonicSeed, encryptSeed, firstAddress
                , [NSString base58WithData:externalPub], [NSString base58WithData:internalPub]
                , @(isXRandom)];
        if (addressOfPs != nil) {
            success &= [BTAddressProvider addPasswordSeedWithPasswordSeed:[[BTPasswordSeed alloc] initWithAddress:addressOfPs andEncryptStr:encryptSeedOfPs] andDB:db];
        }
        sql = @"select hd_account_id from hd_account order by hd_account_id desc limit 1";
        FMResultSet *rs = [db executeQuery:sql, @(hdAccountId)];
        if ([rs next]) {
            hdAccountId = [rs intForColumnIndex:0];
        }
        [rs close];
        if (success) {
            [db commit];
        } else {
            [db rollback];
        }
    }];
    return hdAccountId;
}

- (int)addMonitoredHDAccount:(NSString *)firstAddress isXRandom:(int)isXRandom externalPub:(NSData *)externalPub
                 internalPub:(NSData *)internalPub; {
    __block int hdAccountId = -1;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        [db beginTransaction];
        NSString *sql = @"insert into hd_account("
                "hd_address,external_pub,internal_pub,is_xrandom) "
                " values(?,?,?,?)";
        BOOL success = [db executeUpdate:sql, firstAddress
                , [NSString base58WithData:externalPub], [NSString base58WithData:internalPub]
                , @(isXRandom)];
        sql = @"select hd_account_id from hd_account order by hd_account_id desc limit 1";
        FMResultSet *rs = [db executeQuery:sql, @(hdAccountId)];
        if ([rs next]) {
            hdAccountId = [rs intForColumnIndex:0];
        }
        [rs close];
        if (success) {
            [db commit];
        } else {
            [db rollback];
        }
    }];
    return hdAccountId;
}

- (BOOL)hasMnemonicSeed:(int)hdAccountId; {
    __block BOOL result = NO;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count(0) cnt from hd_account where encrypt_mnemonic_seed is not null and hd_account_id=?";
        FMResultSet *rs = [db executeQuery:sql, @(hdAccountId)];
        if ([rs next]) {
            result = [rs intForColumnIndex:0] > 0;
        }
        [rs close];
    }];
    return result;
}

- (NSString *)getHDFirstAddress:(int)hdAccountId; {
    __block NSString *result = nil;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select hd_address from hd_account where hd_account_id=?";
        FMResultSet *rs = [db executeQuery:sql, @(hdAccountId)];
        if ([rs next]) {
            result = [rs stringForColumnIndex:0];
        }
        [rs close];
    }];
    return result;
}

- (NSData *)getExternalPub:(int)hdAccountId; {
    __block NSData *result = nil;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select external_pub from hd_account where hd_account_id=? ";
        FMResultSet *rs = [db executeQuery:sql, @(hdAccountId)];
        if ([rs next]) {
            result = [[rs stringForColumnIndex:0] base58ToData];
        }
        [rs close];
    }];
    return result;
}

- (NSData *)getInternalPub:(int)hdAccountId; {
    __block NSData *result = nil;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select internal_pub from hd_account where hd_account_id=? ";
        FMResultSet *rs = [db executeQuery:sql, @(hdAccountId)];
        if ([rs next]) {
            result = [[rs stringForColumnIndex:0] base58ToData];
        }
        [rs close];
    }];
    return result;
}

- (NSString *)getHDAccountEncryptSeed:(int)hdAccountId; {
    __block NSString *result = nil;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select encrypt_seed from hd_account where hd_account_id=? ";
        FMResultSet *rs = [db executeQuery:sql, @(hdAccountId)];
        if ([rs next]) {
            result = [rs stringForColumnIndex:0];
        }
        [rs close];
    }];
    return result;
}

- (NSString *)getHDAccountEncryptMnemonicSeed:(int)hdAccountId; {
    __block NSString *result = nil;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select encrypt_mnemonic_seed from hd_account where hd_account_id=? ";
        FMResultSet *rs = [db executeQuery:sql, @(hdAccountId)];
        if ([rs next]) {
            result = [rs stringForColumnIndex:0];
        }
        [rs close];
    }];
    return result;
}

- (BOOL)hdAccountIsXRandom:(int)hdAccountId; {
    __block BOOL result = NO;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select is_xrandom from hd_account where hd_account_id=?";
        FMResultSet *rs = [db executeQuery:sql, @(hdAccountId)];
        if ([rs next]) {
            result = [rs intForColumnIndex:0] == 1;
        }
        [rs close];
    }];
    return result;
}

- (NSArray *)getHDAccountSeeds; {
    __block NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select hd_account_id from hd_account";
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            [result addObject:@([rs intForColumnIndex:0])];
        }
        [rs close];
    }];
    return result;
}

@end