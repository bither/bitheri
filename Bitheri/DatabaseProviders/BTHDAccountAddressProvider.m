//
//  BTHDAccountAddressProvider.m
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


#import "BTHDAccountAddressProvider.h"
#import "BTOut.h"
#import "BTIn.h"
#import "BTTxHelper.h"
#import "BTHDAccount.h"

#define HD_ACCOUNT_ID @"hd_account_id"
#define PATH_TYPE @"path_type"
#define ADDRESS_INDEX @"address_index"
#define IS_ISSUED @"is_issued"
#define HD_ACCOUNT_ADDRESS @"address"
#define PUB @"pub"
#define IS_SYNCED @"is_synced"

//#define IN_QUERY_TX_HDACCOUNT  @" (select  distinct txs.tx_hash from addresses_txs txs ,hd_account_addresses hd where txs.address=hd.address)"

@implementation BTHDAccountAddressProvider {

}

+ (instancetype)instance {
    static BTHDAccountAddressProvider *accountProvider = nil;
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        accountProvider = [[BTHDAccountAddressProvider alloc] init];
    });
    return accountProvider;
}

- (void)addAddress:(NSArray *)array {
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        [db beginTransaction];
        for (BTHDAccountAddress *address in array) {
            [self addHDAccountAddress:db hdAccountAddress:address];
        }
        [db commit];
    }];

}

- (int)getIssuedIndexByHDAccountId:(int)hdAccountId pathType:(PathType)path; {
    __block int issuedIndex = -1;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select ifnull(max(address_index),-1) address_index from hd_account_addresses where path_type=? and is_issued=? and hd_account_id=? ";
        FMResultSet *resultSet = [db executeQuery:sql, @(path), @(YES), @(hdAccountId)];
        if ([resultSet next]) {
            issuedIndex = [resultSet intForColumnIndex:0];
        }
        [resultSet close];
    }];

    return issuedIndex;
}

- (int)getGeneratedAddressCountByHDAccountId:(int)hdAccountId pathType:(PathType)pathType;{
    __block int count = 0;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select ifnull(count(address),0) count  from hd_account_addresses where path_type=? and hd_account_id=? ";
        FMResultSet *resultSet = [db executeQuery:sql, @(pathType), @(hdAccountId)];
        if ([resultSet next]) {
            count = [resultSet intForColumnIndex:0];
        }
        [resultSet close];
    }];

    return count;
}

- (void)updateIssuedByHDAccountId:(int)hdAccountId pathType:(PathType)pathType index:(int)index;{
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update hd_account_addresses set is_issued=? where path_type=? and address_index<=? and hd_account_id=?";
        [db executeUpdate:sql, @(YES), @(pathType), @(index), @(hdAccountId)];
    }];
}

- (NSString *)getExternalAddress:(int)hdAccountId; {
    __block NSString *address;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select address from hd_account_addresses"
                " where path_type=? and is_issued=? and hd_account_id=? order by address_index asc limit 1  ";
        FMResultSet *resultSet = [db executeQuery:sql, @(EXTERNAL_ROOT_PATH), @(NO), @(hdAccountId)];
        if ([resultSet next]) {
            address = [resultSet stringForColumnIndex:0];
        }
        [resultSet close];
    }];

    return address;
}

- (BTHDAccountAddress *)getAddressByHDAccountId:(int)hdAccountId path:(PathType)type index:(int)index;{
    __block BTHDAccountAddress *address;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select hd_account_id,address,pub,path_type,address_index,is_issued,is_synced "
                " from hd_account_addresses where path_type=? and address_index=? and hd_account_id=? ";
        FMResultSet *rs = [db executeQuery:sql, @(type), @(index), @(hdAccountId)];
        if ([rs next]) {
            address = [self formatAddress:rs];
        }
        [rs close];
    }];

    return address;
}

- (NSArray *)getPubsByHDAccountId:(int)hdAccountId pathType:(PathType)pathType; {
    __block NSMutableArray *array = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select pub from hd_account_addresses where path_type=? and hd_account_id=? ";
        FMResultSet *rs = [db executeQuery:sql, @(pathType), @(hdAccountId)];
        while ([rs next]) {
            int columnIndex = [rs columnIndexForName:@"pub"];

            if (columnIndex != -1) {
                NSString *str = [rs stringForColumnIndex:columnIndex];
                [array addObject:[str base58ToData]];

            }

        }
        [rs close];
    }];
    return array;
}

- (NSArray *)getBelongHDAccount:(int)hdAccountId fromAddresses:(NSArray *)addresses; {
    __block NSMutableArray *mutableArray = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSMutableArray *temp = [NSMutableArray new];
        for (NSString *str in addresses) {
            [temp addObject:[NSString stringWithFormat:@"'%@'", str]];
        }
        NSString *sql = @"select hd_account_id,address,pub,path_type,address_index,is_issued,is_synced "
                "from hd_account_addresses  where address in (%@) and hd_account_id=?";
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:sql, [temp componentsJoinedByString:@","]], @(hdAccountId)];
        while ([rs next]) {
            [mutableArray addObject:[self formatAddress:rs]];
        }
        [rs close];
    }];

    return mutableArray;
}

- (NSArray *)getBelongHDAccountFrom:(NSArray *)addresses; {
    __block NSMutableArray *mutableArray = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSMutableArray *temp = [NSMutableArray new];
        for (NSString *str in addresses) {
            [temp addObject:[NSString stringWithFormat:@"'%@'", str]];
        }
        NSString *sql = @"select hd_account_id,address,pub,path_type,address_index,is_issued,is_synced "
                "from hd_account_addresses  where address in (%@)";
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:sql, [temp componentsJoinedByString:@","]]];
        while ([rs next]) {
            [mutableArray addObject:[self formatAddress:rs]];

        }
        [rs close];
    }];

    return mutableArray;
}

- (void)updateSyncedCompleteByHDAccountId:(int)hdAccountId address:(BTHDAccountAddress *)address; {
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update hd_account_addresses set is_synced=? where address=? and hd_account_id=? ";
        [db executeUpdate:sql, @(address.isSyncedComplete), address.address, @(hdAccountId)];

    }];
}

- (void)setSyncedAllNotComplete; {
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update hd_account_addresses set is_synced=? ";
        [db executeUpdate:sql, @(NO)];
    }];
}

- (int)getUnSyncedAddressCount:(int)hdAccountId; {
    __block int count = 0;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count(address) cnt from hd_account_addresses where is_synced=? and hd_account_id=? ";
        FMResultSet *resultSet = [db executeQuery:sql, @(NO), @(hdAccountId)];
        if ([resultSet next]) {
            count = [resultSet intForColumnIndex:0];
        }
        [resultSet close];
    }];
    return count;
}

- (int)getUnSyncedAddressCountByHDAccountId:(int)hdAccountId pathType:(PathType)pathType; {
    __block int count = 0;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count(address) cnt from hd_account_addresses where is_synced=? and hd_account_id=? and path_type=? ";
        FMResultSet *resultSet = [db executeQuery:sql, @(NO), @(hdAccountId), @(pathType)];
        if ([resultSet next]) {
            count = [resultSet intForColumnIndex:0];
        }
        [resultSet close];
    }];
    return count;
}

- (int)unSyncedCountOfPath:(PathType)pathType {
    __block int count = 0;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count(address) cnt from hd_account_addresses where is_synced=? and  path_type=?";
        FMResultSet *resultSet = [db executeQuery:sql, @(NO), @(pathType)];
        if ([resultSet next]) {
            count = [resultSet intForColumnIndex:0];
        }
        [resultSet close];
    }];

    return count;
}


- (void)updateSyncedByHDAccountId:(int)hdAccountId pathType:(PathType)pathType index:(int)index;{
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update hd_account_addresses set is_synced=? where path_type=? and address_index>? and hd_account_id=? ";
        [db executeUpdate:sql, @(YES), @(pathType), @(index), @(hdAccountId)];
    }];
}

- (NSArray *)getSigningAddressesByHDAccountId:(int)hdAccountId fromInputs:(NSArray *)inList; {

    __block NSMutableArray *array = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select a.hd_account_id,a.address,a.path_type,a.address_index,a.is_synced"
                " from hd_account_addresses a ,outs b"
                " where a.address=b.out_address"
                " and b.tx_hash=? and b.out_sn=? and a.hd_account_id=?";

        for (BTIn *btIn in  inList) {
            FMResultSet *rs = [db executeQuery:sql, [NSString base58WithData:btIn.prevTxHash], @(btIn.prevOutSn), @(hdAccountId)];
            while ([rs next]) {
                [array addObject:[self formatAddress:rs]];

            }
            [rs close];
        }
    }];

    return array;
}

- (int)getHDAccountTxCount:(int)hdAccountId; {
    __block int count = 0;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count( distinct a.tx_hash) cnt from addresses_txs a ,hd_account_addresses b where a.address=b.address and b.hd_account_id=? ";
        FMResultSet *resultSet = [db executeQuery:sql, @(hdAccountId)];
        if ([resultSet next]) {
            count = [resultSet intForColumnIndex:0];
        }
        [resultSet close];
    }];

    return count;
}


- (uint64_t)getHDAccountConfirmedBalance:(int)hdAccountId; {

    __block long long balance = 0;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @" select ifnull(sum(a.out_value),0) sum from outs a,txs b where a.tx_hash=b.tx_hash "
                "  and a.out_status=? and a.hd_account_id=? and b.block_no is not null";
        FMResultSet *resultSet = [db executeQuery:sql, @(unspent), @(hdAccountId)];
        if ([resultSet next]) {
            balance = [resultSet longLongIntForColumnIndex:0];
        }
        [resultSet close];
    }];
    return (uint64_t) balance;
}

- (uint64_t)getAmountSentFromHDAccount:(int)hdAccountId txHash:(NSData *)txHash; {
    __block uint64_t sum = 0;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select  sum(o.out_value) out_value from ins i,outs o where"
                " i.tx_hash=? and o.tx_hash=i.prev_tx_hash and i.prev_out_sn=o.out_sn and o.hd_account_id=?";
        FMResultSet *resultSet = [db executeQuery:sql, [NSString base58WithData:txHash], @(hdAccountId)];
        if ([resultSet next]) {
            if ([resultSet columnIndexForName:@"out_value"] >= 0) {
                sum = (uint64_t) [resultSet longLongIntForColumn:@"out_value"];
            }
        }
        [resultSet close];
    }];

    return sum;
}


- (NSArray *)getHDAccountUnconfirmedTx:(int)hdAccountId; {
    __block NSMutableArray *txList = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSMutableDictionary *txDict = [NSMutableDictionary new];
        NSString *sql = @"select distinct a.* "
                " from txs a,addresses_txs b,hd_account_addresses c"
                " where a.tx_hash=b.tx_hash and b.address=c.address and c.hd_account_id=? and a.block_no is null"
                " order by a.tx_hash";
        FMResultSet *rs = [db executeQuery:sql, @(hdAccountId)];
        while ([rs next]) {
            BTTx *tx = [BTTxHelper format:rs];
            tx.ins = [NSMutableArray new];
            tx.outs = [NSMutableArray new];
            [txList addObject:tx];
            txDict[tx.txHash] = tx;
        }
        [rs close];

        sql = @"select distinct a.* "
                " from ins a, txs b,addresses_txs c,hd_account_addresses d"
                " where a.tx_hash=b.tx_hash and b.tx_hash=c.tx_hash and c.address=d.address"
                "   and b.block_no is null and d.hd_account_id=?"
                " order by a.tx_hash,a.in_sn";
        rs = [db executeQuery:sql, @(hdAccountId)];
        while ([rs next]) {
            BTIn *in = [BTTxHelper formatIn:rs];
            BTTx *tx = txDict[in.txHash];
            if (tx != nil) {
                [tx.ins addObject:in];
            }
        }
        [rs close];

        sql = @"select distinct a.* "
                " from outs a, txs b,addresses_txs c,hd_account_addresses d"
                " where a.tx_hash=b.tx_hash and b.tx_hash=c.tx_hash and c.address=d.address"
                "   and b.block_no is null and d.hd_account_id=?"
                " order by a.tx_hash,a.out_sn";
        rs = [db executeQuery:sql, @(hdAccountId)];
        while ([rs next]) {
            BTOut *out = [BTTxHelper formatOut:rs];
            BTTx *tx = txDict[out.txHash];
            if (tx != nil) {
                [tx.outs addObject:out];
            }
        }
        [rs close];
    }];
    return txList;
}

- (NSArray *)getTxAndDetailByHDAccount:(int)hdAccountId; {
    __block NSMutableArray *txs = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSMutableDictionary *txDict = [NSMutableDictionary new];
        NSString *sql = @"select distinct a.* "
                " from txs a,addresses_txs b,hd_account_addresses c"
                " where a.tx_hash=b.tx_hash and b.address=c.address and c.hd_account_id=?"
                " order by ifnull(block_no,4294967295) desc,a.tx_hash";
        FMResultSet *rs = [db executeQuery:sql, @(hdAccountId)];
        NSMutableString *txsStrBuilder = [NSMutableString new];
        while ([rs next]) {
            BTTx *txItem = [BTTxHelper format:rs];
            txItem.ins = [NSMutableArray new];
            txItem.outs = [NSMutableArray new];
            [txs addObject:txItem];
            txDict[txItem.txHash] = txItem;
            [txsStrBuilder appendFormat:@"'%@',", [NSString base58WithData:txItem.txHash]];
        }
        [rs close];

        if (txsStrBuilder.length > 1) {
            NSString *txsStr = [txsStrBuilder substringToIndex:txsStrBuilder.length - 1];
            sql = [NSString stringWithFormat:@"select b.* from ins b where b.tx_hash in (%@)"
                                                     " order by b.tx_hash ,b.in_sn", txsStr];
            rs = [db executeQuery:sql];
            while ([rs next]) {
                BTIn *inItem = [BTTxHelper formatIn:rs];
                BTTx *txItem = txDict[inItem.txHash];
                [txItem.ins addObject:inItem];
                inItem.tx = txItem;
            }
            [rs close];

            sql = [NSString stringWithFormat:@"select b.* from outs b where b.tx_hash in (%@)"
                                                     " order by b.tx_hash,b.out_sn", txsStr];
            rs = [db executeQuery:sql];
            while ([rs next]) {
                BTOut *outItem = [BTTxHelper formatOut:rs];
                BTTx *txItem = txDict[outItem.txHash];
                [txItem.outs addObject:outItem];
                outItem.tx = txItem;
            }
            [rs close];
        }
    }];
    return txs;
}

- (NSArray *)getTxAndDetailByHDAccount:(int)hdAccountId page:(int)page; {
    __block NSMutableArray *txs = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSMutableDictionary *txDict = [NSMutableDictionary new];
        int start = (page - 1) * TX_PAGE_SIZE;
        NSString *sql = @"select distinct a.* "
                " from txs a,addresses_txs b,hd_account_addresses c"
                " where a.tx_hash=b.tx_hash and b.address=c.address and c.hd_account_id=?"
                " order by ifnull(block_no,4294967295) desc,a.tx_hash"
                " limit ?,?";
        FMResultSet *rs = [db executeQuery:sql, @(hdAccountId), @(start), @(TX_PAGE_SIZE)];
        NSMutableString *txsStrBuilder = [NSMutableString new];
        while ([rs next]) {
            BTTx *txItem = [BTTxHelper format:rs];
            txItem.ins = [NSMutableArray new];
            txItem.outs = [NSMutableArray new];
            [txs addObject:txItem];
            txDict[txItem.txHash] = txItem;
            [txsStrBuilder appendFormat:@"'%@',", [NSString base58WithData:txItem.txHash]];
        }
        [rs close];

        if (txsStrBuilder.length > 1) {
            NSString *txsStr = [txsStrBuilder substringToIndex:txsStrBuilder.length - 1];
            sql = [NSString stringWithFormat:@"select b.* from ins b where b.tx_hash in (%@)"
                                                     " order by b.tx_hash ,b.in_sn", txsStr];
            rs = [db executeQuery:sql];
            while ([rs next]) {
                BTIn *inItem = [BTTxHelper formatIn:rs];
                BTTx *txItem = txDict[inItem.txHash];
                [txItem.ins addObject:inItem];
                inItem.tx = txItem;
            }
            [rs close];

            sql = [NSString stringWithFormat:@"select b.* from outs b where b.tx_hash in (%@)"
                                                     " order by b.tx_hash,b.out_sn", txsStr];
            rs = [db executeQuery:sql];
            while ([rs next]) {
                BTOut *outItem = [BTTxHelper formatOut:rs];
                BTTx *txItem = txDict[outItem.txHash];
                [txItem.outs addObject:outItem];
                outItem.tx = txItem;
            }
            [rs close];
        }
    }];
    return txs;
}

- (NSArray *)getUnspendOutByHDAccount:(int)hdAccountId; {
    __block NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *unspendOutSql = @"select a.* from outs a,txs b where a.tx_hash=b.tx_hash "
                " and a.out_status=? and a.hd_account_id=?";
        FMResultSet *rs = [db executeQuery:unspendOutSql, @(unspent), @(hdAccountId)];
        while ([rs next]) {
            [result addObject:[BTTxHelper formatOut:rs]];
        }
        [rs close];
    }];
    return result;
}

- (BTOut *)getPrevOutByTxHash:(NSData *)txHash outSn:(uint)outSn {
    __block BTOut *btOut;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select a.* from outs a where a.tx_hash=? and a.out_sn=?";
        FMResultSet *rs = [db executeQuery:sql, [NSString base58WithData:txHash], @(outSn)];
        while ([rs next]) {
            btOut = [BTTxHelper formatOut:rs];
        }
        [rs close];
    }];
    return btOut;
}

- (NSArray *)getPrevCanSplitOutsByHDAccount:(int)hdAccountId coin:(Coin)coin {
    NSMutableArray *outs = [NSMutableArray new];
    [outs addObjectsFromArray:[self getPrevUnSpentOutsByHDAccount:hdAccountId coin:coin]];
    [outs addObjectsFromArray:[self getPostSpentOutsByHDAccount:hdAccountId coin:coin]];
    return outs;
}

- (NSArray *)getPrevUnSpentOutsByHDAccount:(int)hdAccountId coin:(Coin)coin {
    __block NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select a.* from outs a, txs b where a.tx_hash=b.tx_hash and a.hd_account_id=? and a.out_status=? and b.block_no is not null and b.block_no<?";
        FMResultSet *rs = [db executeQuery:sql, @(hdAccountId), @(unspent), @([BTTx getForkBlockHeightForCoin:coin])];
        while ([rs next]) {
            [result addObject:[BTTxHelper formatOut:rs]];
        }
        [rs close];
    }];
    return result;
}

- (NSArray *)getPostSpentOutsByHDAccount:(int)hdAccountId coin:(Coin)coin {
    __block NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select a.* from outs a, txs out_b, ins i, txs b where a.tx_hash=out_b.tx_hash and a.out_sn=i.prev_out_sn and a.tx_hash=i.prev_tx_hash and a.hd_account_id=? and b.tx_hash=i.tx_hash and a.out_status=? and out_b.block_no is not null and out_b.block_no<? and (b.block_no>=? or b.block_no is null)";
        uint64_t forkBlockHeight = [BTTx getForkBlockHeightForCoin:coin];
        FMResultSet *rs = [db executeQuery:sql,  @(hdAccountId), @(spent), @(forkBlockHeight), @(forkBlockHeight)];
        while ([rs next]) {
            [result addObject:[BTTxHelper formatOut:rs]];
        }
        [rs close];
    }];
    return result;
}

- (NSArray *)getRecentlyTxsByHDAccount:(int)hdAccountId blockNo:(int)greaterThanBlockNo limit:(int)limit; {
    __block NSMutableArray *txs = nil;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        txs = [NSMutableArray new];
        NSMutableDictionary *txDict = [NSMutableDictionary new];
        NSString *sql = @"select distinct a.* "
                " from txs a, addresses_txs b, hd_account_addresses c"
                " where a.tx_hash=b.tx_hash and b.address=c.address "
                "   and ((a.block_no is null) or (a.block_no is not null and a.block_no>?)) "
                "   and c.hd_account_id=?"
                " order by ifnull(a.block_no,4294967295) desc, a.tx_time desc"
                " limit ?";
        FMResultSet *rs = [db executeQuery:sql, @(greaterThanBlockNo), @(hdAccountId), @(limit)];
        while ([rs next]) {
            BTTx *txItem = [BTTxHelper format:rs];
            txItem.ins = [NSMutableArray new];
            txItem.outs = [NSMutableArray new];
            [txs addObject:txItem];
            txDict[txItem.txHash] = txItem;
        }
        [rs close];

        for (BTTx *txItem in txs) {
            sql = @"select * from ins where tx_hash=? order by in_sn";
            rs = [db executeQuery:sql, [NSString base58WithData:txItem.txHash]];
            while ([rs next]) {
                BTIn *inItem = [BTTxHelper formatIn:rs];
                [txItem.ins addObject:inItem];
                inItem.tx = txItem;
            }
            [rs close];

            sql = @"select * from outs where tx_hash=? order by out_sn";
            rs = [db executeQuery:sql, [NSString base58WithData:txItem.txHash]];
            while ([rs next]) {
                BTOut *outItem = [BTTxHelper formatOut:rs];
                [txItem.outs addObject:outItem];
                outItem.tx = txItem;
            }
            [rs close];
        }
    }];
    return txs;
}


- (NSSet *)getBelongHDAccountAddressesFromDb:(FMDatabase *)db addressList:(NSArray *)addressList {
    NSMutableArray *temp = [NSMutableArray new];

    NSMutableSet *set = [NSMutableSet new];
    if (addressList.count == 0) {
        return set;
    }
    for (NSString *address in addressList) {
        [temp addObject:[NSString stringWithFormat:@"'%@'", address]];
    }
    NSString *sql = @"select address from hd_account_addresses where address in (%@) ";
    FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:sql, [temp componentsJoinedByString:@","]]];
    while ([rs next]) {
        int columnIndex = [rs columnIndexForName:@"address"];
        if (columnIndex != -1) {
            NSString *str = [rs stringForColumnIndex:columnIndex];
            [set addObject:str];

        }
    }
    [rs close];

    return set;

}

- (NSSet *)getBelongHDAccountAddressesFromAddresses:(NSArray *)addressList; {
    __block NSMutableSet *set = [NSMutableSet new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        set = [[self getBelongHDAccountAddressesFromDb:db addressList:addressList] mutableCopy];
    }];
    return set;
}

- (NSSet *)getAddressesByHDAccount:(int)hdAccountId fromAddresses:(NSArray *)addressList; {
    __block NSMutableSet *result = [NSMutableSet new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        if (addressList.count == 0) {
            return;
        }
        NSMutableArray *temp = [NSMutableArray new];
        for (NSString *address in addressList) {
            [temp addObject:[NSString stringWithFormat:@"'%@'", address]];
        }
        NSString *sql = @"select address from hd_account_addresses where address in (%@) and hd_account_id=? ";
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:sql, [temp componentsJoinedByString:@","]], @(hdAccountId)];
        while ([rs next]) {
            int columnIndex = [rs columnIndexForName:@"address"];
            if (columnIndex != -1) {
                NSString *str = [rs stringForColumnIndex:columnIndex];
                [result addObject:str];
            }
        }
        [rs close];
    }];
    return result;
}

- (int)getUnspendOutCountByHDAccountId:(int)hdAccountId pathType:(PathType)pathType {
    __block int result = 0;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count(tx_hash) cnt from outs where out_address in "
                "(select address from hd_account_addresses where path_type =? and out_status=?) "
                "and hd_account_id=?";
        FMResultSet *rs = [db executeQuery:sql, @(pathType), @(unspent), @(hdAccountId)];
        if ([rs next]) {
            int columnIndex = [rs columnIndexForName:@"cnt"];
            if (columnIndex != -1) {
                result = [rs intForColumnIndex:columnIndex];
            }
        }
        [rs close];
    }];
    return result;
}

- (NSArray *)getUnspendOutByHDAccountId:(int)hdAccountId pathType:(PathType)pathType {
    NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select * from outs where out_address in "
                "(select address from hd_account_addresses where path_type =? and out_status=?) "
                "and hd_account_id=?";
        FMResultSet *rs = [db executeQuery:sql, @(pathType), @(unspent), @(hdAccountId)];
        while ([rs next]) {
            [result addObject:[BTTxHelper formatOut:rs]];
        }
        [rs close];
    }];
    return result;
}

- (int)getUnconfirmedSpentOutCountByHDAccountId:(int)hdAccountId pathType:(PathType)pathType {
    __block int result = 0;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count(0) cnt from outs o, ins i, txs t, hd_account_addresses a "
        "  where o.tx_hash=i.prev_tx_hash and o.out_sn=i.prev_out_sn and t.tx_hash=i.tx_hash and o.out_address=a.address and a.path_type=? "
        "    and o.out_status=? and t.block_no is null and a.hd_account_id=?";
        FMResultSet *rs = [db executeQuery:sql, @(pathType), @(spent), @(hdAccountId)];
        if ([rs next]) {
            int columnIndex = [rs columnIndexForName:@"cnt"];
            if (columnIndex != -1) {
                result = [rs intForColumnIndex:columnIndex];
            }
        }
        [rs close];
    }];
    return result;
}

- (NSArray *)getUnconfirmedSpentOutByHDAccountId:(int)hdAccountId pathType:(PathType)pathType {
    NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select o.* from outs o, ins i, txs t,hd_account_addresses a "
        "  where o.tx_hash=i.prev_tx_hash and o.out_sn=i.prev_out_sn and t.tx_hash=i.tx_hash and o.out_address=a.address and a.path_type=? "
        "    and o.out_status=? and t.block_no is null and a.hd_account_id=?";
        FMResultSet *rs = [db executeQuery:sql, @(pathType), @(spent), @(hdAccountId)];
        while ([rs next]) {
            [result addObject:[BTTxHelper formatOut:rs]];
        }
        [rs close];
    }];
    return result;
}

- (void)addHDAccountAddress:(FMDatabase *)db hdAccountAddress:(BTHDAccountAddress *)address {
    NSString *sql = @"insert into hd_account_addresses(hd_account_id,path_type,address_index"
            ",is_issued,address,pub,is_synced) "
            " values(?,?,?,?,?,?,?)";
    [db executeUpdate:sql, @(address.hdAccountId), @(address.pathType), @(address.index), @(address.isIssued), address.address
            , [NSString base58WithData:address.pub], @(address.isSyncedComplete)];
}

- (BTTx *)updateOutHDAccountId:(BTTx *) tx; {
    NSArray *addressList = [tx getOutAddressList];
    if ([addressList count] > 0) {
        NSMutableSet *set = [NSMutableSet new];
        [set addObjectsFromArray:addressList];

        NSMutableArray *temp = [NSMutableArray new];
        for (NSString *address in set) {
            [temp addObject:[NSString stringWithFormat:@"'%@'", address]];
        }

        NSString *sql = [NSString stringWithFormat:@"select address,hd_account_id from hd_account_addresses where address in (%@)", [temp componentsJoinedByString:@","]];
        __block BTTx *blockTx = tx;
        [[BTDatabaseManager instance].getTxDbQueue inDatabase:^(FMDatabase *db) {
            FMResultSet *rs = [db executeQuery:sql];
            while ([rs next]) {
                NSString *address = [rs stringForColumnIndex:0];
                int hdAccountId = [rs intForColumnIndex:1];
                for (BTOut *out in [blockTx outs]) {
                    if ([out.outAddress isEqualToString:address]) {
                        out.hdAccountId = hdAccountId;
                    }
                }
            }
            [rs close];
        }];

    }
    return tx;
}

- (NSArray *)getRelatedHDAccountIdListFromAddresses:(NSArray *)addresses; {
    __block NSMutableArray *hdAccountIdList = [NSMutableArray new];
    if ([addresses count] > 0) {
        NSMutableSet *set = [NSMutableSet new];
        [set addObjectsFromArray:addresses];

        NSMutableArray *temp = [NSMutableArray new];
        for (NSString *address in set) {
            [temp addObject:[NSString stringWithFormat:@"'%@'", address]];
        }

        NSString *sql = [NSString stringWithFormat:@"select distinct hd_account_id from hd_account_addresses where address in (%@) ", [temp componentsJoinedByString:@","]];

        [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
            FMResultSet *rs = [db executeQuery:sql];
            while ([rs next]) {
                [hdAccountIdList addObject:@([rs intForColumnIndex:0])];
            }
            [rs close];
        }];
    }
    return hdAccountIdList;
}

- (BOOL)requestNewReceivingAddress:(int)hdAccountId;{
    int issuedIndex = [self getIssuedIndexByHDAccountId:hdAccountId pathType:EXTERNAL_ROOT_PATH];
    __block BOOL result = NO;
    if (issuedIndex >= kHDAccountMaxUnusedNewAddressCount - 2) {
        NSString *sql = @"select count(0) from hd_account_addresses a,outs b "
                " where a.address=b.out_address and a.hd_account_id=? and a.address_index>? and a.is_issued=? and a.path_type=?";
        [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
            FMResultSet *rs = [db executeQuery:sql, @(hdAccountId), @(issuedIndex - kHDAccountMaxUnusedNewAddressCount + 1), @"1", @(EXTERNAL_ROOT_PATH)];
            if ([rs next]) {
                result = [rs intForColumnIndex:0] > 0;
            }
            [rs close];
        }];
    } else {
        result = YES;
    }
    if (result) {
        [self updateIssuedByHDAccountId:hdAccountId pathType:EXTERNAL_ROOT_PATH index:issuedIndex + 1];
    }
    return result;
}

- (BOOL)hasHDAccount:(int)hdAccountId pathType:(PathType) pathType receiveTxInAddressCount:(int) addressCount; {
    __block BOOL result = NO;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select ifnull(max(address_index),-1) address_index from hd_account_addresses "
                " where path_type=? and is_synced=? and hd_account_id=? ";
        FMResultSet *rs = [db executeQuery:sql, @(pathType), @(YES), @(hdAccountId)];
        int syncedIndex = -1;
        if ([rs next]) {
            syncedIndex = [rs intForColumnIndex:0];
        }
        [rs close];
        if (syncedIndex >= addressCount) {
            sql = @"select count(0) from hd_account_addresses a,outs b "
                    " where a.address=b.out_address and a.hd_account_id=? and a.address_index>=? and a.is_synced=? and a.path_type=?";
            rs = [db executeQuery:sql, @(hdAccountId), @(syncedIndex - addressCount), @(YES), @(pathType)];
            if ([rs next]) {
                result = [rs intForColumnIndex:0] > 0;
            }
            [rs close];

        } else {
            result = YES;
        }
    }];
    return result;
}

- (BTHDAccountAddress *)formatAddress:(FMResultSet *)rs {
    BTHDAccountAddress *address = [[BTHDAccountAddress alloc] init];
    int columnIndex = [rs columnIndexForName:HD_ACCOUNT_ID];
    if (columnIndex >= 0) {
        int hdAccountId = [rs intForColumnIndex:columnIndex];
        address.hdAccountId = hdAccountId;
    }
    columnIndex = [rs columnIndexForName:PATH_TYPE];
    if (columnIndex >= 0) {
        int type = [rs intForColumnIndex:columnIndex];
        address.pathType = [BTHDAccountAddress getPathType:type];
    }
    columnIndex = [rs columnIndexForName:IS_SYNCED];
    if (columnIndex >= 0) {
        address.isSyncedComplete = [rs boolForColumnIndex:columnIndex];
    }
    columnIndex = [rs columnIndexForName:PUB];
    if (columnIndex >= 0) {
        address.pub = [[rs stringForColumnIndex:columnIndex] base58ToData];
    }
    columnIndex = [rs columnIndexForName:HD_ACCOUNT_ADDRESS];
    if (columnIndex >= 0) {
        address.address = [rs stringForColumnIndex:columnIndex];
    }
    columnIndex = [rs columnIndexForName:ADDRESS_INDEX];
    if (columnIndex >= 0) {
        address.index = [rs intForColumnIndex:columnIndex];
    }
    columnIndex = [rs columnIndexForName:IS_ISSUED];
    if (columnIndex >= 0) {
        address.isIssued = [rs boolForColumnIndex:columnIndex];
    }
    return address;
}
@end
