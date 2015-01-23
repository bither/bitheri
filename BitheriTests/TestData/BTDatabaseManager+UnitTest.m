//
//  BTDatabaseManager+UnitTest.m
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

#import "BTDatabaseManager+UnitTest.h"
#import "BTSettings.h"


@implementation BTDatabaseManager (UnitTest)

- (void)reInitDataBase;{
    [[self getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *delBlockSql = @"drop table blocks";
        NSString *delTxSql = @"drop table txs";
        NSString *delAddressTxSql = @"drop table addresses_txs";
        NSString *delInSql = @"drop table ins";
        NSString *delOutSql = @"drop table outs";
        NSString *delPeerSql = @"drop table peers";
        [db beginTransaction];
        for (NSString *sql in @[delBlockSql, delTxSql, delAddressTxSql, delInSql, delOutSql, delPeerSql]){
            if (![db executeUpdate:sql]){
                DDLogDebug(@"sql[%@] error", sql);
            }
        }
        [db commit];
    }];
    NSUserDefaults *userDefaultUtil = [NSUserDefaults standardUserDefaults];
    [userDefaultUtil removeObjectForKey:@"db_version"];
    [self initDatabase];
}

- (void)clear {
    [[self getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *delBlockSql = @"delete from blocks";
        NSString *delTxSql = @"delete from txs";
        NSString *delAddressTxSql = @"delete from addresses_txs";
        NSString *delInSql = @"delete from ins";
        NSString *delOutSql = @"delete from outs";
        NSString *delPeerSql = @"delete from peers";
        [db beginTransaction];
        for (NSString *sql in @[delBlockSql, delTxSql, delAddressTxSql, delInSql, delOutSql, delPeerSql]){
            if (![db executeUpdate:sql]){
                DDLogDebug(@"sql[%@] error", sql);
            }
        }
        [db commit];
    }];
}

@end