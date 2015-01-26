//
//  BTDatabaseManager.m
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

#import "BTDatabaseManager.h"

NSString *const TX_DB_VERSION = @"db_version";
NSString *const TX_DB_NAME = @"bitheri.sqlite";
const int CURRENT_TX_DB_VERSION = 1;

NSString *const ADDRESS_DB_VERSION = @"address_db_version";
NSString *const ADDRESS_DB_NAME = @"address.sqlite";
const int CURRENT_ADDRESS_DB_VERSION = 1;

static BOOL canOpenTxDb;
static BOOL canOpenAddressDb;

@interface BTDatabaseManager ()
@property(nonatomic, strong) FMDatabaseQueue *txQueue;
@property(nonatomic, strong) FMDatabaseQueue *addressQueue;
@end

static BTDatabaseManager *databaseProvide;

@implementation BTDatabaseManager : NSObject

+ (instancetype)instance {
    @synchronized (self) {
        if (databaseProvide == nil) {
            databaseProvide = [[self alloc] init];
            [databaseProvide initDatabase];
        }
    }
    return databaseProvide;
}

- (instancetype)init {
    if (! (self = [super init])) return nil;

    // init sql
    _createTableBlocksSql = @"create table if not exists blocks "
            "(block_no integer not null"
            ", block_hash text not null primary key"
            ", block_root text not null"
            ", block_ver integer not null"
            ", block_bits integer not null"
            ", block_nonce integer not null"
            ", block_time integer not null"
            ", block_prev text"
            ", is_main integer not null);";
    _createIndexBlocksBlockNoSql = @"create index idx_blocks_block_no on blocks (block_no);";
    _createIndexBlocksBlockPrevSql = @"create index idx_blocks_block_prev on blocks (block_prev);";
    _createTableTxsSql = @"create table if not exists txs "
            "(tx_hash text primary key"
            ", tx_ver integer"
            ", tx_locktime integer"
            ", tx_time integer"
            ", block_no integer"
            ", source integer);";
    _createIndexTxsBlockNoSql = @"create index idx_tx_block_no on txs (block_no);";
    _createTableAddressesTxsSql = @"create table if not exists addresses_txs "
            "(address text not null"
            ", tx_hash text not null"
            ", primary key (address, tx_hash));";
    _createTableInsSql = @"create table if not exists ins "
            "(tx_hash text not null"
            ", in_sn integer not null"
            ", prev_tx_hash text"
            ", prev_out_sn integer"
            ", in_signature text"
            ", in_sequence integer"
            ", primary key (tx_hash, in_sn));";
    _createIndexInsPrevTxHashSql = @"create index idx_in_prev_tx_hash on ins (prev_tx_hash);";
    _createTableOutsSql = @"create table if not exists outs "
            "(tx_hash text not null"
            ", out_sn integer not null"
            ", out_script text not null"
            ", out_value integer not null"
            ", out_status integer not null"
            ", out_address text"
            ", primary key (tx_hash, out_sn));";
    _createIndexOutsOutAddressSql = @"create index idx_out_out_address on outs (out_address);";
    _createTablePeersSql = @"create table if not exists peers "
            "(peer_address integer primary key"
            ", peer_port integer not null"
            ", peer_services integer not null"
            ", peer_timestamp integer not null"
            ", peer_connected_cnt integer not null);";

    _createTablePasswordSeedSql = @"create table if not exists password_seed "
            "(address text not null primary key"
            ", encrypt_str text not null);";
    _createTableAddressesSql = @"create table if not exists addresses "
            "(address text not null primary key"
            ", encrypt_private_key text"
            ", pub_key text not null"
            ", is_xrandom integer not null"
            ", is_trash integer not null"
            ", is_synced integer not null"
            ", sort_time integer not null);";
    _createTableHDSeedsSql = @"create table if not exists hd_seeds "
            "(hd_seed_id integer not null primary key autoincrement"
            ", encrypt_seed text not null"
            ", encrypt_hd_seed text"
            ", hdm_address text not null"
            ", is_xrandom integer not null);";
    _createTableHDMAddressesSql = @"create table if not exists hdm_addresses "
            "(hd_seed_id integer not null"
            ", hd_seed_index integer not null"
            ", pub_key_hot text not null"
            ", pub_key_cold text not null"
            ", pub_key_remote text"
            ", address text"
            ", is_synced integer not null"
            ", primary key (hd_seed_id, hd_seed_index));";
    _createTableHDMBidSql = @"create table if not exists hdm_bid "
            "(hdm_bid text not null primary key"
            ", encrypt_bither_password text not null);";
    return self;
}

- (BOOL)initDatabase {
    BOOL result = YES;
    result &= [self initTxDb];
    result &= [self initAddressDb];
    return result;
}

- (BOOL)initTxDb {
    NSUserDefaults *userDefaultUtil = [NSUserDefaults standardUserDefaults];
    int txDbVersion = (int) [userDefaultUtil integerForKey:TX_DB_VERSION];
    canOpenTxDb = NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths && paths.count > 0) {
        NSString *documentsDirectory = paths[0];
        NSString *writableDBPath = [documentsDirectory stringByAppendingPathComponent:TX_DB_NAME];
        canOpenTxDb = [fm fileExistsAtPath:writableDBPath];
        if (!canOpenTxDb) {
            txDbVersion = 0;
        } else {
            if (txDbVersion == 0) {
                txDbVersion = 1;
            }
        }
        self.txQueue = [FMDatabaseQueue databaseQueueWithPath:writableDBPath];
        [self.txQueue inDatabase:^(FMDatabase *db) {
            BOOL success = NO;
            if (txDbVersion < CURRENT_TX_DB_VERSION) {
                switch (txDbVersion) {
                    case 0:
                        success = [self txV1:db];
                        break;
                    default:
                        break;
                }
            }
            if (success) {
                canOpenTxDb = YES;
                [userDefaultUtil setInteger:CURRENT_TX_DB_VERSION forKey:TX_DB_VERSION];
            }
        }];
    } else {
        canOpenTxDb = NO;
    }
    return canOpenTxDb;
}

- (BOOL)initAddressDb {
    NSUserDefaults *userDefaultUtil = [NSUserDefaults standardUserDefaults];
    int addressDbVersion = (int) [userDefaultUtil integerForKey:ADDRESS_DB_VERSION];
    canOpenAddressDb = NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths && paths.count > 0) {
        NSString *documentsDirectory = paths[0];
        NSString *writableDBPath = [documentsDirectory stringByAppendingPathComponent:ADDRESS_DB_NAME];
        canOpenAddressDb = [fm fileExistsAtPath:writableDBPath];
        if (!canOpenAddressDb) {
            addressDbVersion = 0;
        } else {
            if (addressDbVersion == 0) {
                addressDbVersion = 1;
            }
        }
        self.addressQueue = [FMDatabaseQueue databaseQueueWithPath:writableDBPath];
        [self.addressQueue inDatabase:^(FMDatabase *db) {
            BOOL success = NO;
            if (addressDbVersion < CURRENT_ADDRESS_DB_VERSION) {
                switch (addressDbVersion) {
                    case 0:
                        success = [self addressV1:db];
                        break;
                    default:
                        break;
                }
            }
            if (success) {
                canOpenAddressDb = YES;
                [userDefaultUtil setInteger:CURRENT_ADDRESS_DB_VERSION forKey:ADDRESS_DB_VERSION];
            }
        }];
    } else {
        canOpenAddressDb = NO;
    }
    return canOpenAddressDb;
}

//- (BOOL)dbIsOpen {
//    return canOpenDb;
//}

- (BOOL)txV1:(FMDatabase *)db {
    if ([db open]) {
        [db beginTransaction];
        [db executeUpdate:self.createTableBlocksSql];
        [db executeUpdate:self.createIndexBlocksBlockNoSql];
        [db executeUpdate:self.createIndexBlocksBlockPrevSql];
        [db executeUpdate:self.createTableTxsSql];
        [db executeUpdate:self.createIndexTxsBlockNoSql];
        [db executeUpdate:self.createTableAddressesTxsSql];
        [db executeUpdate:self.createTableInsSql];
        [db executeUpdate:self.createIndexInsPrevTxHashSql];
        [db executeUpdate:self.createTableOutsSql];
        [db executeUpdate:self.createIndexInsPrevTxHashSql];
        [db executeUpdate:self.createTablePeersSql];
        [db commit];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)addressV1:(FMDatabase *)db {
    if ([db open]) {
        [db beginTransaction];
        [db executeUpdate:self.createTablePasswordSeedSql];
        [db executeUpdate:self.createTableAddressesSql];
        [db executeUpdate:self.createTableHDSeedsSql];
        [db executeUpdate:self.createTableHDMAddressesSql];
        [db executeUpdate:self.createTableHDMBidSql];
        [db commit];
        return YES;
    } else {
        return NO;
    }
}

- (FMDatabaseQueue *)getTxDbQueue {
    return self.txQueue;
}

- (FMDatabaseQueue *)getAddressDbQueue {
    return self.addressQueue;
}

- (void)closeDatabase {
    [self.txQueue close];
    [self.addressQueue close];
}


@end
