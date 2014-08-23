//
//  BTPeerProvider.m
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

#import "BTPeerProvider.h"
#import "BTDatabaseManager.h"

static BTPeerProvider *provider;

@implementation BTPeerProvider {

}

+ (instancetype)instance; {
    @synchronized (self) {
        if (provider == nil) {
            provider = [[self alloc] init];
        }
    }
    return provider;
}

- (NSMutableArray *)getAllPeers;{
    __block NSMutableArray *peers = [NSMutableArray new];
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select * from peers";
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]){
            [peers addObject:[self format:rs]];
        }
        [rs close];
    }];
    return peers;
}

- (void)deletePeersNotInAddresses:(NSSet *) peerAddresses;{
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select peer_address from peers";
        FMResultSet *rs = [db executeQuery:sql];
        NSMutableArray *needDeletePeer = [NSMutableArray new];
        while ([rs next]){
            NSNumber *peerAddress = @([rs intForColumn:@"peer_address"]);
            if (![peerAddresses containsObject:peerAddress]){
                [needDeletePeer addObject:peerAddress];
            }
        }
        [rs close];
        [db beginTransaction];
        NSString *delSql = @"delete from peers where peer_address=?";
        for (NSNumber *peerAddress in needDeletePeer){
            [db executeUpdate:delSql, peerAddress];
        }
        [db commit];
    }];
}

- (NSArray *)exists:(NSSet *) peerAddresses;{
    __block NSMutableArray *exists = [NSMutableArray new];
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count(0) cnt from peers where peer_address=?";
        for (NSNumber *peerAddress in peerAddresses){
            FMResultSet *rs = [db executeQuery:sql, peerAddress];
            while ([rs next]){
                int cnt = [rs intForColumn:@"cnt"];
                if (cnt == 1){
                    [exists addObject:peerAddress];
                }
            }
        }
    }];
    return exists;
}

- (void)addPeers:(NSArray *) peers;{
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *existSql = @"select count(0) cnt from peers where peer_address=?";
        NSString *sql = @"insert into peers(peer_address,peer_port,peer_services,peer_timestamp,peer_connected_cnt)"
                " values(?,?,?,?,?)";
        [db beginTransaction];
        for (BTPeerItem *peer in peers){
            FMResultSet *rs = [db executeQuery:existSql, @(peer.peerAddress)];
            int cnt = 0;
            if ([rs next])
                cnt = [rs intForColumn:@"cnt"];
            [rs close];
            if (cnt == 0) {
                [db executeUpdate:sql, @(peer.peerAddress), @(peer.peerPort), @(peer.peerServices)
                        , @(peer.peerTimestamp), @(peer.peerConnectedCnt)];
            }
        }
        [db commit];
    }];
}

- (void)updatePeersTimestamp:(NSArray *)peerAddresses;{
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update peers set peer_timestamp=? where peer_address=?";
        [db beginTransaction];
        int timestamp = (int) [[NSDate new] timeIntervalSinceReferenceDate];
        for (NSNumber *address in peerAddresses){
            [db executeUpdate:sql, @(timestamp), address];
        }
        [db commit];
    }];
}

- (void)removePeer:(uint)address;{
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"delete from peers where peer_address=?";
        [db executeUpdate:sql, @(address)];
    }];
}

- (void)connectFail:(uint)address;{
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count(0) cnt from peers where peer_address=? and peer_connected_cnt=?";
        FMResultSet *rs = [db executeQuery:sql, @(address), @0];
        int cnt = 0;
        while ([rs next]){
            cnt = [rs intForColumn:@"cnt"];
        }
        [rs close];
        if (cnt == 0) {
            sql = @"update peers set peer_connected_cnt=? where peer_address=?";
            [db executeUpdate:sql, @2, @(address)];
        } else {
            sql = @"update peers set peer_connected_cnt=peer_connected_cnt+1 where peer_address=?";
            [db executeUpdate:sql, @(address)];
        }

    }];
}

- (void)connectSucceed:(uint)address;{
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update peers set peer_connected_cnt=?,peer_timestamp=?  where peer_address=?";
        [db executeUpdate:sql, @1, @([NSDate new].timeIntervalSinceReferenceDate), @(address)];
    }];
}

- (NSArray *)getPeersWithLimit:(int)limit;{
    __block NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select * from peers where peer_connected_cnt=? order by peer_timestamp desc limit %d";
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:sql, limit], @1];
        while ([rs next]){
            [result addObject:[self format:rs]];
        }
        [rs close];
        if (result.count < limit) {
            rs = [db executeQuery:[NSString stringWithFormat:sql, limit - result.count], @0];
            while ([rs next]){
                [result addObject:[self format:rs]];
            }
            [rs close];
        }
        if (result.count < limit) {
            sql = @"select * from peers where peer_connected_cnt>? order by peer_connected_cnt asc, peer_timestamp desc limit %d";
            rs = [db executeQuery:[NSString stringWithFormat:sql, limit - result.count], @1];
            while ([rs next]){
                [result addObject:[self format:rs]];
            }
            [rs close];
        }
    }];
    return result;
}

- (void)cleanPeers;{
    int maxPeerSaveCnt = 1000;
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *disconnectingPeerCntSql = @"select count(0) cnt from peers where peer_connected_cnt<>1";
        int disconnectingPeerCnt = 0;
        FMResultSet *rs = [db executeQuery:disconnectingPeerCntSql];
        if ([rs next]) {
            disconnectingPeerCnt = [rs intForColumn:@"cnt"];
        }
        [rs close];
        if (disconnectingPeerCnt > maxPeerSaveCnt){
            NSString *sql = @"select peer_timestamp from peers where peer_connected_cnt<>1 "
                    "order by peer_timestamp desc limit 1 offset %d";
            rs = [db executeQuery:[NSString stringWithFormat:sql, maxPeerSaveCnt]];
            int timestamp = 0;
            if ([rs next]) {
                timestamp = [rs intForColumn:@"peer_timestamp"];
            }
            [rs close];
            if (timestamp > 0){
                NSString *delPeersSql = @"delete from peers where peer_connected_cnt<>1 and peer_timestamp<=?";
                [db executeUpdate:delPeersSql, @(timestamp)];
            }
        }
    }];
}

-(BTPeerItem *)format:(FMResultSet * )rs{
    BTPeerItem *peerItem =[[BTPeerItem alloc] init];
    peerItem.peerAddress = (uint32_t)[rs intForColumn:@"peer_address"];
    peerItem.peerPort = (uint16_t)[rs intForColumn:@"peer_port"];
    peerItem.peerServices = [rs unsignedLongLongIntForColumn:@"peer_services"];
    peerItem.peerTimestamp = (uint32_t)[rs intForColumn:@"peer_timestamp"];
//    peerItem.peerMisbehavin = (int16_t)[rs intForColumn:@"peer_misbehavin"];
    peerItem.peerConnectedCnt = [rs intForColumn:@"peer_connected_cnt"];
    return peerItem;
}

@end