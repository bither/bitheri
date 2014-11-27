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

NSString *const DB_VERSION = @"db_version";
NSString *const BITHER_DB_NAME = @"bitheri.sqlite";
const int CURRENT_DB_VERSION = 1;

static BOOL canOpenDb;

@interface BTDatabaseManager ()
@property(nonatomic, strong) FMDatabaseQueue *queue;
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

- (BOOL)initDatabase {
    // init sql
    self.createTableBlocksSql = @"create table if not exists blocks "
            "(block_no integer not null"
            ", block_hash text not null primary key"
            ", block_root text not null"
            ", block_ver integer not null"
            ", block_bits integer not null"
            ", block_nonce integer not null"
            ", block_time integer not null"
            ", block_prev text"
            ", is_main integer not null);";
    self.createIndexBlocksBlockNoSql = @"create index idx_blocks_block_no on blocks (block_no);";
    self.createIndexBlocksBlockPrevSql = @"create index idx_blocks_block_prev on blocks (block_prev);";
    self.createTableTxsSql = @"create table if not exists txs "
            "(tx_hash text primary key"
            ", tx_ver integer"
            ", tx_locktime integer"
            ", tx_time integer"
            ", block_no integer"
            ", source integer);";
    self.createTableAddressesTxsSql = @"create table if not exists addresses_txs "
            "(address text not null"
            ", tx_hash text not null"
            ", primary key (address, tx_hash));";
    self.createTableInsSql = @"create table if not exists ins "
            "(tx_hash text not null"
            ", in_sn integer not null"
            ", prev_tx_hash text"
            ", prev_out_sn integer"
            ", in_signature text"
            ", in_sequence integer"
            ", primary key (tx_hash, in_sn));";
    self.createTableOutsSql = @"create table if not exists outs "
            "(tx_hash text not null"
            ", out_sn integer not null"
            ", out_script text not null"
            ", out_value integer not null"
            ", out_status integer not null"
            ", out_address text"
            ", primary key (tx_hash, out_sn));";
    self.createTablePeersSql = @"create table if not exists peers "
            "(peer_address integer primary key"
            ", peer_port integer not null"
            ", peer_services integer not null"
            ", peer_timestamp integer not null"
            ", peer_connected_cnt integer not null);";

    NSUserDefaults *userDefaultUtil = [NSUserDefaults standardUserDefaults];
    int dbVersion = (int) [userDefaultUtil integerForKey:DB_VERSION];
    canOpenDb = NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths && paths.count > 0) {
        NSString *documentsDirectory = paths[0];
        NSString *writableDBPath = [documentsDirectory stringByAppendingPathComponent:BITHER_DB_NAME];
        canOpenDb = [fm fileExistsAtPath:writableDBPath];
        if (!canOpenDb) {
            dbVersion = 0;
        } else {
            if (dbVersion == 0) {
                dbVersion = 1;
            }
        }
        self.queue = [FMDatabaseQueue databaseQueueWithPath:writableDBPath];
        [self.queue inDatabase:^(FMDatabase *db) {
            BOOL success = NO;
            if (dbVersion < CURRENT_DB_VERSION) {
                switch (dbVersion) {
                    case 0:
                        success = [self v1:db];
                        break;
                    default:
                        break;
                }
            }
            if (success) {
                canOpenDb = YES;
                [userDefaultUtil setInteger:CURRENT_DB_VERSION forKey:DB_VERSION];
            }
        }];
    } else {
        canOpenDb = NO;
    }
    return canOpenDb;
}

- (BOOL)dbIsOpen {
    return canOpenDb;
}

- (BOOL)v1:(FMDatabase *)db {
    if ([db open]) {
        [db beginTransaction];
        [db executeUpdate:self.createTableBlocksSql];
        [db executeUpdate:self.createIndexBlocksBlockNoSql];
        [db executeUpdate:self.createIndexBlocksBlockPrevSql];
        [db executeUpdate:self.createTableTxsSql];
        [db executeUpdate:self.createTableAddressesTxsSql];
        [db executeUpdate:self.createTableInsSql];
        [db executeUpdate:self.createTableOutsSql];
        [db executeUpdate:self.createTablePeersSql];
        [db commit];
        return YES;
    } else {
        return NO;
    }
}

- (FMDatabaseQueue *)getDbQueue {
    return self.queue;
}

- (void)closeDatabase {
    [self.queue close];
}


@end
