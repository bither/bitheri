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
#import "BTTx.h"
#import "BTOut.h"
#import "BTIn.h"
#import "BTTxHelper.h"


#define PATH_TYPE @"path_type"
#define ADDRESS_INDEX @"address_index"
#define IS_ISSUED @"is_issued"
#define HD_ACCOUNT_ADDRESS @"address"
#define PUB @"pub"
#define IS_SYNCED @"is_synced"

#define IN_QUERY_TX_HDACCOUNT  @" (select  distinct txs.tx_hash from addresses_txs txs ,hd_account_addresses hd where txs.address=hd.address)"

static BTHDAccountProvider *accountProvider;

@implementation BTHDAccountProvider {

}

+(instancetype)instance {
    @synchronized (self) {
        if (accountProvider == nil) {
            accountProvider = [[self alloc] init];
        }
    }
    return accountProvider;
}
- (void)addAddress:(NSArray *)array {
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        [db beginTransaction];
        for (BTHDAccountAddress *address in array) {
            [self addHDAccountAddress:db hdAccountAddress:address];
        }
        [db commit];
    }];

}

- (int)issuedIndex:(PathType)path {
    __block int issuedIndex = -1;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select ifnull(max(address_index),-1) address_index from hd_account_addresses where path_type=? and is_issued=? ";
        FMResultSet *resultSet = [db executeQuery:sql, @(path), @(YES)];
        if ([resultSet next]) {
            issuedIndex = [resultSet intForColumnIndex:0];
        }
        [resultSet close];
    }];

    return issuedIndex;
}

- (int)allGeneratedAddressCount:(PathType)pathType {
    __block int count = 0;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select ifnull(count(address),0) count  from hd_account_addresses where path_type=?  ";
        FMResultSet *resultSet = [db executeQuery:sql, @(pathType)];
        if ([resultSet next]) {
            count = [resultSet intForColumnIndex:0];
        }
        [resultSet close];
    }];

    return count;
}

- (void)updateIssuedIndex:(PathType)pathType index:(int)index {
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update hd_account_addresses set is_issued=? where path_type=? and address_index<=? ";
        [db executeUpdate:sql, @(YES), @(pathType), @(index)];

    }];
}

- (NSString *)externalAddress {
    __block NSString *address;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select address from hd_account_addresses"
                " where path_type=? and is_issued=? order by address_index asc limit 1  ";
        FMResultSet *resultSet = [db executeQuery:sql, @(EXTERNAL_ROOT_PATH), @(NO)];
        if ([resultSet next]) {
            address = [resultSet stringForColumnIndex:0];
        }
        [resultSet close];
    }];

    return address;
}

- (BTHDAccountAddress *)addressForPath:(PathType)type index:(int)index {
    __block BTHDAccountAddress *address;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select address,pub,path_type,address_index,is_issued,is_synced "
                " from hd_account_addresses where path_type=? and address_index=? ";
        FMResultSet *rs = [db executeQuery:sql, @(type), @(index)];
        if ([rs next]) {
            address = [self formatAddress:rs];
        }
        [rs close];
    }];

    return address;
}

- (NSArray *)getPubs:(PathType)pathType {
    __block NSMutableArray *array = [NSMutableArray new];
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select pub from hd_account_addresses where path_type=? ";
        FMResultSet *rs = [db executeQuery:sql, @(pathType)];
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

- (NSSet *)belongAccount:(NSArray *)addresses {

    __block NSMutableSet *mutableSet = [NSMutableSet new];
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSMutableArray *temp = [NSMutableArray new];
        for (NSString *str in addresses) {
            [temp addObject:[NSString stringWithFormat:@"'%@'", str]];
        }
        NSString *sql = @"select address,pub,path_type,address_index,is_issued,is_synced "
                "from hd_account_addresses  where address in (%@)";
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:sql, [temp componentsJoinedByString:@","]]];
        while ([rs next]) {
            int columnIndex = [rs columnIndexForName:@"pub"];
            if (columnIndex != -1) {
                NSString *str = [rs stringForColumnIndex:columnIndex];
                [mutableSet addObject:[str base58ToData]];

            }

        }
        [rs close];
    }];

    return mutableSet;
}

- (void)updateSyncdComplete:(BTHDAccountAddress *)address {
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update hd_account_addresses set is_synced=? where address=? ";
        [db executeUpdate:sql, @(address.isSyncedComplete), address.address];

    }];
}

- (void)setSyncdNotComplete {
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update hd_account_addresses set is_synced=? ";
        [db executeUpdate:sql, @(NO)];

    }];
}

- (int)unSyncedAddressCount {
    __block int count = 0;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count(address) cnt from hd_account_addresses where is_synced=? ";
        FMResultSet *resultSet = [db executeQuery:sql, @(NO)];
        if ([resultSet next]) {
            count = [resultSet intForColumnIndex:0];
        }
        [resultSet close];
    }];

    return count;
}

- (void)updateSyncdForIndex:(PathType)pathType index:(int)index {
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update hd_account_addresses set is_synced=? where path_type=? and address_index>? ";
        [db executeUpdate:sql, @(YES),@(pathType),@(index)];

    }];
}

- (NSArray *)getSigningAddressesForInputs:(NSArray *)inList {

    __block NSMutableArray *array = [NSMutableArray new];
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select a.address,a.path_type,a.address_index,a.is_synced"
                " from hd_account_addresses a ,outs b"
                " where a.address=b.out_address"
                " and b.tx_hash=? and b.out_sn=? ";

        for(BTIn * btIn in  inList) {
            FMResultSet *rs = [db executeQuery:sql,[NSString base58WithData:btIn.prevTxHash],@(btIn.prevOutSn)];
            while ([rs next]) {
                [array addObject:[self formatAddress:rs]];

            }
            [rs close];
        }
    }];

    return array;
}

- (int)hdAccountTxCount {
    __block int count = 0;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count( distinct a.tx_hash) cnt from addresses_txs a ,hd_account_addresses b where a.address=b.address  ";
        FMResultSet *resultSet = [db executeQuery:sql];
        if ([resultSet next]) {
            count = [resultSet intForColumnIndex:0];
        }
        [resultSet close];
    }];

    return count;
}


- (long long)getHDAccountConfirmedBanlance:(int)hdAccountId {

    __block long long banlance = 0;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @" select ifnull(sum(a.out_value),0) sum from outs a,txs b where a.tx_hash=b.tx_hash "
            "  and a.out_status=? and a.hd_account_id=? and b.block_no is not null";
        FMResultSet *resultSet = [db executeQuery:sql,@(unspent),@(hdAccountId)];
        if ([resultSet next]) {
            banlance = [resultSet longLongIntForColumnIndex:0];
        }
        [resultSet close];
    }];

    return banlance;
}
- (long long)sentFromAccount:(int)hdAccountId txHash:(NSData *)txHash {
    __block long long sum = 0;
    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select  sum(o.out_value) out_value from ins i,outs o where"
            " i.tx_hash=? and o.tx_hash=i.prev_tx_hash and i.prev_out_sn=o.out_sn and o.hd_account_id=?";
        FMResultSet *resultSet = [db executeQuery:sql,[NSString base58WithData:txHash],@(hdAccountId)];
        if ([resultSet next]) {
            sum = [resultSet longLongIntForColumnIndex:0];
        }
        [resultSet close];
    }];

    return sum;
}


- (NSArray *)getHDAccountUnconfirmedTx {
    __block NSMutableArray *txList = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSMutableDictionary *txDict = [NSMutableDictionary new];
        NSString *sql = [NSString stringWithFormat:
        @"select * from txs where tx_hash in %@"
                " and  block_no is null "
                " order by block_no desc",IN_QUERY_TX_HDACCOUNT];
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            BTTx *tx = [BTTxHelper format:rs];
            tx.ins = [NSMutableArray new];
            tx.outs = [NSMutableArray new];
            [txList addObject:tx];
            txDict[tx.txHash] = tx;
        }
        [rs close];

        sql = [NSString stringWithFormat:
        @"select b.tx_hash,b.in_sn,b.prev_tx_hash,b.prev_out_sn "
                " from ins b, txs c "
                " where c.tx_hash in %@ and b.tx_hash=c.tx_hash and c.block_no is null  "
                " order by b.tx_hash ,b.in_sn",IN_QUERY_TX_HDACCOUNT];
        rs = [db executeQuery:sql];
        while ([rs next]) {
            BTIn *in = [BTTxHelper formatIn:rs];
            BTTx *tx = txDict[in.txHash];
            if (tx != nil) {
                [tx.ins addObject:in];
            }
        }
        [rs close];

        sql = [NSString stringWithFormat:
        @"select b.tx_hash,b.out_sn,b.out_value,b.out_address "
                " from  outs b, txs c "
                " where c.tx_hash in %@ and b.tx_hash=c.tx_hash and c.block_no is null  "
                " order by b.tx_hash,b.out_sn",IN_QUERY_TX_HDACCOUNT];
        rs = [db executeQuery:sql];
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


- (NSArray *)getTxAndDetailByHDAccount:(int)page {
    __block NSMutableArray *txs = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSMutableDictionary *txDict = [NSMutableDictionary new];
        int start = (page - 1) * TX_PAGE_SIZE;
        NSString *sql = [NSString stringWithFormat:
        @" select * from txs where tx_hash in %@ order by"
                " ifnull(block_no,4294967295) desc limit ?,? ",IN_QUERY_TX_HDACCOUNT];
        FMResultSet *rs = [db executeQuery:sql,  @(start), @(TX_PAGE_SIZE)];
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

- (NSArray *)getUnspendOutByHDAccount:(int)hdAccountId {
    __block NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *unspendOutSql = @"select a.* from outs a,txs b where a.tx_hash=b.tx_hash "
                " and a.out_status=? and a.hd_account_id=?";
        FMResultSet *rs = [db executeQuery:unspendOutSql,  @(unspent),@(hdAccountId)];
        while ([rs next]) {
            [result addObject:[BTTxHelper formatOut:rs]];
        }
        [rs close];
    }];
    return result;
}

- (NSArray *)getRecentlyTxsByAccount:(int)greateThanBlockNo limit:(int)limit {
    __block NSMutableArray *txs = nil;
    [[[BTDatabaseManager instance] getTxDbQueue] inDatabase:^(FMDatabase *db) {
        txs = [NSMutableArray new];
        NSMutableDictionary *txDict = [NSMutableDictionary new];
        NSString *sql = [NSString stringWithFormat:
        @"select * from txs  where  tx_hash in %@ "
                "and ((block_no is null) or (block_no is not null and block_no>?)) "
                " order by ifnull(block_no,4294967295) desc, tx_time desc "
                " limit ? ",IN_QUERY_TX_HDACCOUNT];
        FMResultSet *rs = [db executeQuery:sql, @(greateThanBlockNo), @(limit)];
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


-(NSSet *)getBelongAccountAddressesFromAdresses:(NSArray *)addressList{
    NSMutableArray * temp= [NSMutableArray new];
    for(NSString * address in addressList){
        [temp addObject:[NSString stringWithFormat:@"'%@'",address]];
    }
    __block NSMutableSet * set=[NSMutableSet new];

    [[[BTDatabaseManager instance] getAddressDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select address from hd_account_addresses where address in (%s) ";
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:sql, [temp componentsJoinedByString:@","]]];
        while ([rs next]) {
            int columnIndex = [rs columnIndexForName:@"address"];
            if (columnIndex != -1) {
                NSString *str = [rs stringForColumnIndex:columnIndex];
                [set addObject:str];

            }
        }
        [rs close];
    }];
    return  set;

}

- (void)addHDAccountAddress:(FMDatabase *)db hdAccountAddress:(BTHDAccountAddress *)address {
    NSString *sql = @"insert into hd_account_addresses(path_type,address_index"
            ",is_issued,address,pub,is_synced) "
            " values(?,?,?,?,?,?)";
    [db executeUpdate:sql, address.pathType, @(address.index), @(address.isIssued), address.address
            , [NSString base58WithData:address.pub], @(address.isSyncedComplete)];

}


- (BTHDAccountAddress *)formatAddress:(FMResultSet *)rs {
    BTHDAccountAddress *address = [[BTHDAccountAddress alloc] init];
    int columnIndex = [rs columnIndexForName:PATH_TYPE];
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