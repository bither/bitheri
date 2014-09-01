//
//  BTTxProvider.m
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

#import "BTTxProvider.h"
#import "BTInItem.h"
#import "BTOutItem.h"
#import "NSString+Base58.h"
#import "BTTx.h"
#import "BTSettings.h"

static BTTxProvider *provider;

@implementation BTTxProvider {

}


+ (instancetype)instance; {
    @synchronized (self) {
        if (provider == nil) {
            provider = [[self alloc] init];
        }
    }
    return provider;
}

- (void)getTxByAddress:(NSString *)address callback:(ArrayResponseBlock)callback; {
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSMutableArray *txs = [NSMutableArray new];
        NSString *sql = @"select b.* from addresses_txs a, txs b where a.tx_hash=b.tx_hash and a.address=? "
                "order by b.block_no";
        FMResultSet *rs = [db executeQuery:sql, address];
        while ([rs next]) {
            [txs addObject:[self format:rs]];
        }
        [rs close];
        callback(txs);
    }];
}

- (NSArray *)getTxByAddress:(NSString *)address; {
    __block NSMutableArray *txs = nil;
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        txs = [NSMutableArray new];
        NSString *sql = @"select b.* from addresses_txs a, txs b where a.tx_hash=b.tx_hash and a.address=? "
                "order by b.block_no";
        FMResultSet *rs = [db executeQuery:sql, address];
        while ([rs next]) {
            [txs addObject:[self format:rs]];
        }
        [rs close];
    }];
    return txs;
}

- (void)getTxAndDetailByAddress:(NSString *)address callback:(ArrayResponseBlock)callback; {
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSMutableArray *txs = [NSMutableArray new];
        NSMutableDictionary *txDict = [NSMutableDictionary new];
        NSString *sql = @"select b.* from addresses_txs a, txs b where a.tx_hash=b.tx_hash and a.address=? "
                "order by b.block_no";
        FMResultSet *rs = [db executeQuery:sql, address];
        while ([rs next]) {
            BTTxItem *txItem = [self format:rs];
            txItem.ins = [NSMutableArray new];
            txItem.outs = [NSMutableArray new];
            [txs addObject:txItem];
            txDict[txItem.txHash] = txItem;
        }
        [rs close];

        sql = @"select b.* from addresses_txs a, ins b where a.tx_hash=b.tx_hash and a.address=? "
                "order by b.tx_hash ,b.in_sn";
        rs = [db executeQuery:sql, address];
        while ([rs next]) {
            BTInItem *inItem = [self formatIn:rs];
            BTTxItem *txItem = txDict[inItem.txHash];
            [txItem.ins addObject:inItem];
            inItem.tx = txItem;
        }
        [rs close];

        sql = @"select b.* from addresses_txs a, outs b where a.tx_hash=b.tx_hash and a.address=? "
                "order by b.tx_hash,b.out_sn";
        rs = [db executeQuery:sql, address];
        while ([rs next]) {
            BTOutItem *outItem = [self formatOut:rs];
            BTTxItem *txItem = txDict[outItem.txHash];
            [txItem.outs addObject:outItem];
            outItem.tx = txItem;
        }
        [rs close];

        callback(txs);
    }];
}

- (NSArray *)getTxAndDetailByAddress:(NSString *)address; {
    __block NSMutableArray *txs = nil;
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        txs = [NSMutableArray new];
        NSMutableDictionary *txDict = [NSMutableDictionary new];
        NSString *sql = @"select b.* from addresses_txs a, txs b where a.tx_hash=b.tx_hash and a.address=? "
                "order by b.block_no";
        FMResultSet *rs = [db executeQuery:sql, address];
        while ([rs next]) {
            BTTxItem *txItem = [self format:rs];
            txItem.ins = [NSMutableArray new];
            txItem.outs = [NSMutableArray new];
            [txs addObject:txItem];
            txDict[txItem.txHash] = txItem;
        }
        [rs close];

        sql = @"select b.* from addresses_txs a, ins b where a.tx_hash=b.tx_hash and a.address=? "
                "order by b.tx_hash ,b.in_sn";
        rs = [db executeQuery:sql, address];
        while ([rs next]) {
            BTInItem *inItem = [self formatIn:rs];
            BTTxItem *txItem = txDict[inItem.txHash];
            [txItem.ins addObject:inItem];
            inItem.tx = txItem;
        }
        [rs close];

        sql = @"select b.* from addresses_txs a, outs b where a.tx_hash=b.tx_hash and a.address=? "
                "order by b.tx_hash,b.out_sn";
        rs = [db executeQuery:sql, address];
        while ([rs next]) {
            BTOutItem *outItem = [self formatOut:rs];
            BTTxItem *txItem = txDict[outItem.txHash];
            [txItem.outs addObject:outItem];
            outItem.tx = txItem;
        }
        [rs close];
    }];
    return txs;
}

- (NSArray *)getPublishedTxs {
    __block NSMutableArray *txs = nil;
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        txs = [NSMutableArray new];
        NSMutableDictionary *txDict = [NSMutableDictionary new];
        NSString *sql = @"select a.* from txs a where a.block_no is null order by a.tx_hash";
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            BTTxItem *txItem = [self format:rs];
            txItem.ins = [NSMutableArray new];
            txItem.outs = [NSMutableArray new];
            [txs addObject:txItem];
            txDict[txItem.txHash] = txItem;
        }
        [rs close];

        sql = @"select b.* from txs a, ins b where a.tx_hash=b.tx_hash and a.block_no is null order by b.tx_hash,b.in_sn";
        rs = [db executeQuery:sql];
        while ([rs next]) {
            BTInItem *inItem = [self formatIn:rs];
            BTTxItem *txItem = txDict[inItem.txHash];
            [txItem.ins addObject:inItem];
            inItem.tx = txItem;
        }
        [rs close];

        sql = @"select b.* from txs a, outs b where a.tx_hash=b.tx_hash and a.block_no is null order by b.tx_hash,b.out_sn";
        rs = [db executeQuery:sql];
        while ([rs next]) {
            BTOutItem *outItem = [self formatOut:rs];
            BTTxItem *txItem = txDict[outItem.txHash];
            [txItem.outs addObject:outItem];
            outItem.tx = txItem;
        }
        [rs close];
    }];
    return txs;
}

- (BTTxItem *)getTxDetailByTxHash:(NSData *)txHash; {
    __block BTTxItem *txItem = nil;
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *txHashStr = [NSString base58WithData:txHash];
        NSString *sql = @"select * from txs where tx_hash=?";
        FMResultSet *rs = [db executeQuery:sql, txHashStr];
        if ([rs next]) {
            txItem = [self format:rs];
            [rs close];
        } else {
            [rs close];
            return;
        }
        txItem.ins = [NSMutableArray new];
        txItem.outs = [NSMutableArray new];
        sql = @"select * from ins where tx_hash=? order by in_sn";
        rs = [db executeQuery:sql, txHashStr];
        while ([rs next]) {
            BTInItem *inItem = [self formatIn:rs];
            [txItem.ins addObject:inItem];
            inItem.tx = txItem;
        }
        [rs close];

        sql = @"select * from outs where tx_hash=? order by out_sn";
        rs = [db executeQuery:sql, txHashStr];
        while ([rs next]) {
            BTOutItem *outItem = [self formatOut:rs];
            [txItem.outs addObject:outItem];
            outItem.tx = txItem;
        }
        [rs close];
    }];
    return txItem;
}

- (BOOL)isExist:(NSData *)txHash; {
    __block BOOL result = NO;
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count(0) from txs where tx_hash=?";
        FMResultSet *rs = [db executeQuery:sql, [NSString base58WithData:txHash]];
        if ([rs next]) {
            result = [rs intForColumnIndex:0] > 0;
        }
        [rs close];
    }];
    return result;
}

- (void)add:(BTTxItem *)txItem; {
    // need update out\'s status in this.
    // need maintain relation table addresses_txs
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        // insert tx record
        [db beginTransaction];
        NSNumber *blockNo = nil;
        if (txItem.blockNo != TX_UNCONFIRMED) {
            blockNo = @(txItem.blockNo);
        }
        NSString *sql = @"insert into txs(block_no, tx_hash, source, tx_ver, tx_locktime, tx_time) values(?,?,?,?,?,?)";
        bool success = [db executeUpdate:sql, blockNo, [NSString base58WithData:txItem.txHash]
                , @(txItem.source), @(txItem.txVer), @(txItem.txLockTime), @(txItem.txTime)];
        // query in's prev out, get addresses and txs.
        // update prev out\'s status to spend
        // todo: need consider the coin base's condition in later
        NSMutableArray *addressesTxsRels = [NSMutableArray new];
        for (BTInItem *inItem in txItem.ins) {
            sql = @"select out_address from outs where tx_hash=? and out_sn=?";
            FMResultSet *rs = [db executeQuery:sql, [NSString base58WithData:inItem.prevTxHash]
                    , @(inItem.prevOutSn)];
            while ([rs next]) {
                if (![rs columnIsNull:@"out_address"]) {
                    [addressesTxsRels addObject:@[[rs stringForColumn:@"out_address"], txItem.txHash]];
                }
            }
            [rs close];
            sql = @"insert into ins(tx_hash,in_sn,prev_tx_hash,prev_out_sn,in_signature,in_sequence) values(?,?,?,?,?,?)";
            NSString *inSignature = nil;
            if (inItem.inSignature != (id) [NSNull null]) {
                inSignature = [NSString base58WithData:inItem.inSignature];
            }
            success = [db executeUpdate:sql, [NSString base58WithData:inItem.txHash]
                    , @(inItem.inSn), [NSString base58WithData:inItem.prevTxHash]
                    , @(inItem.prevOutSn), inSignature, @(inItem.inSequence)];
            sql = @"update outs set out_status=? where tx_hash=? and out_sn=?";
            success = [db executeUpdate:sql, @(spent)
                    , [NSString base58WithData:inItem.prevTxHash], @(inItem.prevOutSn)];
        }

        // insert outs and get the out\'s addresses
        for (BTOutItem *outItem in txItem.outs) {
            sql = @"insert into outs(tx_hash,out_sn,out_script,out_value,out_status,out_address) values(?,?,?,?,?,?)";
            success = [db executeUpdate:sql, [NSString base58WithData:outItem.txHash]
                    , @(outItem.outSn), [NSString base58WithData:outItem.outScript]
                    , @(outItem.outValue), @(outItem.outStatus)
                    , outItem.outAddress];
            if (outItem.outAddress != nil) {
                [addressesTxsRels addObject:@[outItem.outAddress, txItem.txHash]];
            }

            sql = @"select tx_hash from ins where prev_tx_hash=? and prev_out_sn=?";
            FMResultSet *rs = [db executeQuery:sql, [NSString base58WithData:txItem.txHash]
                    , @(outItem.outSn)];
            if ([rs next]) {
                [addressesTxsRels addObject:@[outItem.outAddress, [[rs stringForColumn:@"tx_hash"] base58ToData]]];
                sql = @"update outs set out_status=? where tx_hash=? and out_sn=?";
                success = [db executeUpdate:sql, @(spent), [NSString base58WithData:txItem.txHash], @(outItem.outSn)];
            }
            [rs close];
        }

        for (NSArray *array in addressesTxsRels) {
            sql = @"insert or ignore into addresses_txs(address, tx_hash) values(?,?)";
            [db executeUpdate:sql, array[0], [NSString base58WithData:array[1]]];
        }

        [db commit];
    }];
}

- (void)addTxs:(NSArray *)txs;{
    // need update out\'s status in this.
    // need maintain relation table addresses_txs
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        // filter tx that not exist
        NSMutableArray *addList = [NSMutableArray new];
        for (BTTxItem *txItem in txs) {
            NSString *existSql = @"select count(0) cnt from txs where tx_hash=?";
            FMResultSet *existRs = [db executeQuery:existSql, [NSString base58WithData:txItem.txHash]];
            if ([existRs next]) {
                if ([existRs intForColumn:@"cnt"] == 0) {
                    [addList addObject:txItem];
                }
            }
            [existRs close];
        }

        // insert tx record
        [db beginTransaction];
        for (BTTxItem *txItem in addList){
            NSNumber *blockNo = nil;
            if (txItem.blockNo != TX_UNCONFIRMED) {
                blockNo = @(txItem.blockNo);
            }
            NSString *sql = @"insert into txs(block_no, tx_hash, source, tx_ver, tx_locktime, tx_time) values(?,?,?,?,?,?)";
            bool success = [db executeUpdate:sql, blockNo, [NSString base58WithData:txItem.txHash]
                    , @(txItem.source), @(txItem.txVer), @(txItem.txLockTime), @(txItem.txTime)];
            // query in's prev out, get addresses and txs.
            // update prev out\'s status to spend
            // todo: need consider the coin base's condition in later
            NSMutableArray *addressesTxsRels = [NSMutableArray new];
            for (BTInItem *inItem in txItem.ins) {
                sql = @"select out_address from outs where tx_hash=? and out_sn=?";
                FMResultSet *rs = [db executeQuery:sql, [NSString base58WithData:inItem.prevTxHash]
                        , @(inItem.prevOutSn)];
                while ([rs next]) {
                    if (![rs columnIsNull:@"out_address"]) {
                        [addressesTxsRels addObject:@[[rs stringForColumn:@"out_address"], txItem.txHash]];
                    }
                }
                [rs close];
                sql = @"insert into ins(tx_hash,in_sn,prev_tx_hash,prev_out_sn,in_signature,in_sequence) values(?,?,?,?,?,?)";
                NSString *inSignature = nil;
                if (inItem.inSignature != (id) [NSNull null]) {
                    inSignature = [NSString base58WithData:inItem.inSignature];
                }
                success = [db executeUpdate:sql, [NSString base58WithData:inItem.txHash]
                        , @(inItem.inSn), [NSString base58WithData:inItem.prevTxHash]
                        , @(inItem.prevOutSn), inSignature, @(inItem.inSequence)];
                sql = @"update outs set out_status=? where tx_hash=? and out_sn=?";
                success = [db executeUpdate:sql, @(spent)
                        , [NSString base58WithData:inItem.prevTxHash], @(inItem.prevOutSn)];
            }

            // insert outs and get the out\'s addresses
            for (BTOutItem *outItem in txItem.outs) {
                sql = @"insert into outs(tx_hash,out_sn,out_script,out_value,out_status,out_address) values(?,?,?,?,?,?)";
                success = [db executeUpdate:sql, [NSString base58WithData:outItem.txHash]
                        , @(outItem.outSn), [NSString base58WithData:outItem.outScript]
                        , @(outItem.outValue), @(outItem.outStatus)
                        , outItem.outAddress];
                if (outItem.outAddress != nil) {
                    [addressesTxsRels addObject:@[outItem.outAddress, txItem.txHash]];
                }

                sql = @"select tx_hash from ins where prev_tx_hash=? and prev_out_sn=?";
                FMResultSet *rs = [db executeQuery:sql, [NSString base58WithData:txItem.txHash]
                        , @(outItem.outSn)];
                if ([rs next]) {
                    [addressesTxsRels addObject:@[outItem.outAddress, [[rs stringForColumn:@"tx_hash"] base58ToData]]];
                    sql = @"update outs set out_status=? where tx_hash=? and out_sn=?";
                    success = [db executeUpdate:sql, @(spent), [NSString base58WithData:txItem.txHash], @(outItem.outSn)];
                }
                [rs close];
            }

            for (NSArray *array in addressesTxsRels) {
                sql = @"insert or ignore into addresses_txs(address, tx_hash) values(?,?)";
                [db executeUpdate:sql, array[0], [NSString base58WithData:array[1]]];
            }
        }
        [db commit];
    }];
}

- (void)remove:(NSData *)txHash; {
    // need remove txs that relay to this tx
    NSString *tx = [NSString base58WithData:txHash];
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSMutableArray *txHashes = [NSMutableArray new];
        NSMutableSet *needRemoveTxHashes = [NSMutableSet new];
        [txHashes addObject:tx];
        while ([txHashes count] > 0) {
            NSString *thisHash = (NSString *) txHashes[0];
            [txHashes removeObjectAtIndex:0];
            [needRemoveTxHashes addObject:thisHash];
            [txHashes addObjectsFromArray:[self _getRelayTx:thisHash andDb:db]];
        }

        [db beginTransaction];
        for (NSString *each in needRemoveTxHashes) {
            [self _removeSingleTx:each andDb:db];
        }
        [db commit];
    }];
}

- (NSArray *)_getRelayTx:(NSString *)txHash andDb:(FMDatabase *)db; {
    NSString *relayTx = @"select distinct tx_hash from ins where prev_tx_hash=?";
    FMResultSet *rs = [db executeQuery:relayTx, txHash];
    NSMutableArray *relayTxHashes = [NSMutableArray new];
    while ([rs next]) {
        [relayTxHashes addObject:[rs stringForColumn:@"tx_hash"]];
    }
    return relayTxHashes;
}

- (void)_removeSingleTx:(NSString *)tx andDb:(FMDatabase *)db; {
    NSString *deleteTx = @"delete from txs where tx_hash=?";
    NSString *deleteIn = @"delete from ins where tx_hash=?";
    NSString *deleteOut = @"delete from outs where tx_hash=?";
    NSString *deleteAddressesTx = @"delete from addresses_txs where tx_hash=?";
    NSString *inSql = @"select prev_tx_hash,prev_out_sn from ins where tx_hash=?";
    // may be two in use the same out when double spent and both of two tx are not confirmed.
    NSString *existOtherIn = @"select count(0) cnt from ins where prev_tx_hash=? and prev_out_sn=?";
    NSString *updatePrevOut = @"update outs set out_status=? where tx_hash=? and out_sn=?";
    FMResultSet *rs = [db executeQuery:inSql, tx];
    NSMutableArray *needUpdateOuts = [NSMutableArray new];
    while ([rs next]) {
        NSString *prev_tx_hash = [rs stringForColumn:@"prev_tx_hash"];
        NSNumber *prev_out_sn = @([rs intForColumn:@"prev_out_sn"]);
        [needUpdateOuts addObject:@[prev_tx_hash, prev_out_sn]];
    }
    [rs close];

    [db executeUpdate:deleteAddressesTx, tx];
    [db executeUpdate:deleteOut, tx];
    [db executeUpdate:deleteIn, tx];
    [db executeUpdate:deleteTx, tx];
    for (NSArray *array in needUpdateOuts) {
        rs = [db executeQuery:existOtherIn, array[0], array[1]];
        while ([rs next]) {
            if ([rs intForColumn:@"cnt"] == 0) {
                [db executeUpdate:updatePrevOut, @(unspent), array[0], array[1]];
            }
        }
        [rs close];
    }
}

- (bool)isAddress:(NSString *)address containsTx:(BTTxItem *)txItem; {
    __block bool result = NO;
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        // check if double spend with confirmed tx
        NSString *sql = @"select count(0) from ins a, txs b where a.tx_hash=b.tx_hash"
                " and b.block_no is not null"
                " and a.prev_tx_hash=? and a.prev_out_sn=?";
        FMResultSet *rs = nil;
        for (BTInItem *inItem in txItem.ins) {
            rs = [db executeQuery:sql, inItem.prevTxHash, @(inItem.prevOutSn)];
            if ([rs next] && [rs intForColumnIndex:0] > 0) {
                result = NO;
                [rs close];
                return;
            }
            [rs close];
        }

        sql = @"select count(0) from addresses_txs where tx_hash=? and address=?";
        rs = [db executeQuery:sql, [NSString base58WithData:txItem.txHash], address];
        int count = 0;
        if ([rs next]) {
            count = [rs intForColumnIndex:0];
        }
        [rs close];
        if (count) {
            result = YES;
            return;
        }
        sql = @"select count(0) from outs where tx_hash=? and out_sn=? and out_address=?";
        for (BTInItem *inItem in txItem.ins) {
            rs = [db executeQuery:sql, [NSString base58WithData:inItem.prevTxHash], @(inItem.prevOutSn), address];
            count = 0;
            if ([rs next]) {
                count = [rs intForColumnIndex:0];
            }
            [rs close];
            if (count) {
                result = YES;
                return;
            }
        }

    }];
    return result;
}

- (void)confirmTx:(NSArray *)txHashes withBlockNo:(int)blockNo; {
    if (blockNo == TX_UNCONFIRMED)
        return;

    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        [db beginTransaction];
        NSString *sql = @"update txs set block_no=? where tx_hash=?";
        NSString *existSql = @"select count(0) from txs where block_no=? and tx_hash=?";
        NSString *doubleSpendSql = @"select a.tx_hash from ins a, ins b where a.prev_tx_hash=b.prev_tx_hash "
                "and a.prev_out_sn=b.prev_out_sn and a.tx_hash<>b.tx_hash and b.tx_hash=?";
        NSString *blockTimeSql = @"select block_time from blocks where block_no=?";
        NSString *updateTxTimeThatMoreThanBlockTime = @"update txs set tx_time=? where block_no=? and tx_time>?";
        for (NSData *txHash in txHashes) {
            FMResultSet *rs = [db executeQuery:existSql
                    , @(blockNo), [NSString base58WithData:txHash]];
            if ([rs next]) {
                int cnt = [rs intForColumnIndex:0];
                [rs close];
                if (cnt > 0) {
                    // tx 's block no do not need change.
                    continue;
                }
            } else {
                [rs close];
            }
            [db executeUpdate:sql, @(blockNo), [NSString base58WithData:txHash]];
            // deal with double spend tx
            rs = [db executeQuery:doubleSpendSql, [NSString base58WithData:txHash]];
            NSMutableArray *txHashes1 = [NSMutableArray new];
            while ([rs next]) {
                [txHashes1 addObject:[rs stringForColumn:@"tx_hash"]];
            }
            [rs close];

            NSMutableSet *needRemoveTxHashes = [NSMutableSet new];
            while ([txHashes1 count] > 0) {
                NSString *thisHash = (NSString *) txHashes1[0];
                [txHashes1 removeObjectAtIndex:0];
                [needRemoveTxHashes addObject:thisHash];
                [txHashes1 addObjectsFromArray:[self _getRelayTx:thisHash andDb:db]];
            }
            for (NSString *each in needRemoveTxHashes) {
                [self _removeSingleTx:each andDb:db];
            }
        }
        FMResultSet *blockTimeRS = [db executeQuery:blockTimeSql, @(blockNo)];
        if ([blockTimeRS next]) {
            uint blockTime = (uint) [blockTimeRS intForColumn:@"block_time"];
            [blockTimeRS close];
            [db executeUpdate:updateTxTimeThatMoreThanBlockTime, @(blockTime), @(blockNo), @(blockTime)];
        } else {
            [blockTimeRS close];
        }

        [db commit];
    }];
}

- (void)unConfirmTxByBlockNo:(int)blockNo; {
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        [db beginTransaction];
        NSString *sql = @"update txs set block_no=null where block_no>=?";
        [db executeUpdate:sql, @(blockNo)];
        [db commit];
    }];
}

- (NSArray *)getUnspendTxWithAddress:(NSString *)address;{
    __block NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *unspendOutSql = @"select a.*,b.tx_ver,b.tx_locktime,b.tx_time,b.block_no,b.source,ifnull(b.block_no,0)*a.out_value coin_depth "
                "from outs a,txs b where a.tx_hash=b.tx_hash"
                " and a.out_address=? and a.out_status=?";
        FMResultSet *rs = [db executeQuery:unspendOutSql, address, @(unspent)];
        while ([rs next]) {
            BTTxItem *txItem = [self format:rs];
            BTOutItem *outItem = [self formatOut:rs];
            outItem.coinDepth = [rs unsignedLongLongIntForColumn:@"coin_depth"];
            txItem.outs = [NSMutableArray new];
            [txItem.outs addObject:outItem];
            outItem.tx = txItem;
            [result addObject:txItem];
        }
        [rs close];
    }];
    return result;
}

- (NSArray *)getUnspendOutWithAddress:(NSString *)address;{
    __block NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *unspendOutSql = @"select a.* from outs a,txs b where a.tx_hash=b.tx_hash and b.block_no is null"
                " and a.out_address=? and a.out_status=?";
        FMResultSet *rs = [db executeQuery:unspendOutSql, address, @(unspent)];
        while ([rs next]) {
            [result addObject:[self formatOut:rs]];
        }
        [rs close];
    }];
    return result;
}

- (NSArray *)getUnSpendOutCanSpendWithAddress:(NSString *)address; {
    __block NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *confirmedOutSql = @"select a.*,b.block_no*a.out_value coin_depth from outs a,txs b where a.tx_hash=b.tx_hash and b.block_no is not null"
                " and a.out_address=? and a.out_status=?";
        NSString *selfOutSql = @"select a.* from outs a,txs b where a.tx_hash=b.tx_hash and b.block_no is null"
                " and a.out_address=? and a.out_status=? and b.source>=?";
        FMResultSet *rs = [db executeQuery:confirmedOutSql, address, @(unspent)];
        while ([rs next]) {
            BTOutItem *outItem = [self formatOut:rs];
            outItem.coinDepth = [rs unsignedLongLongIntForColumn:@"coin_depth"];
            [result addObject:outItem];
        }
        [rs close];
        rs = [db executeQuery:selfOutSql, address, @(unspent), @1];
        while ([rs next]) {
            [result addObject:[self formatOut:rs]];
        }
        [rs close];
    }];
    return result;
}

- (NSArray *)getUnSpendOutButNotConfirmWithAddress:(NSString *)address;{
    __block NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *selfOutSql = @"select a.* from outs a,txs b where a.tx_hash=b.tx_hash and b.block_no is null"
                " and a.out_address=? and a.out_status=? and b.source=?";
        FMResultSet *rs = [db executeQuery:selfOutSql, address, @(unspent), @0];
        while ([rs next]) {
            [result addObject:[self formatOut:rs]];
        }
        [rs close];
    }];
    return result;
}

- (uint32_t)txCount:(NSString *)address {
    __block uint32_t result = 0;
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select count(*) from addresses_txs  where address=? ";
        FMResultSet *rs = [db executeQuery:sql, address];
        if ([rs next]) {
            result = (uint32_t) [rs intForColumnIndex:0];
        }
        [rs close];

    }];
    return result;
}

- (void)txSentBySelfHasSaw:(NSData *)txHash; {
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"update txs set source=source+1 where tx_hash=? and source>=?";
        [db executeUpdate:sql, [NSString base58WithData:txHash], @(1)];
    }];
}

- (NSArray *)getOuts;{
    __block NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select a.* from outs a";
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            [result addObject:[self formatOut:rs]];
        }
        [rs close];
    }];
    return result;
}

- (NSArray *)getRecentlyTxsByAddress:(NSString *)address andGreaterThanBlockNo:(int)blockNo andLimit:(int)limit;{
    __block NSMutableArray *txs = nil;
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        txs = [NSMutableArray new];
        NSMutableDictionary *txDict = [NSMutableDictionary new];
        NSString *sql = @"select b.* from addresses_txs a, txs b where a.tx_hash=b.tx_hash and a.address=? "
                "and ((b.block_no is null) or (b.block_no is not null and b.block_no>?)) "
                "order by ifnull(b.block_no,4294967295) desc, b.tx_time desc "
                "limit %d ";
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:sql, limit], address, @(blockNo)];
        while ([rs next]) {
            BTTxItem *txItem = [self format:rs];
            txItem.ins = [NSMutableArray new];
            txItem.outs = [NSMutableArray new];
            [txs addObject:txItem];
            txDict[txItem.txHash] = txItem;
        }
        [rs close];

        for (BTTxItem *txItem in txs) {
            sql = @"select * from ins where tx_hash=? order by in_sn";
            rs = [db executeQuery:sql, [NSString base58WithData:txItem.txHash]];
            while ([rs next]) {
                BTInItem *inItem = [self formatIn:rs];
                [txItem.ins addObject:inItem];
                inItem.tx = txItem;
            }
            [rs close];

            sql = @"select * from outs where tx_hash=? order by out_sn";
            rs = [db executeQuery:sql, [NSString base58WithData:txItem.txHash]];
            while ([rs next]) {
                BTOutItem *outItem = [self formatOut:rs];
                [txItem.outs addObject:outItem];
                outItem.tx = txItem;
            }
            [rs close];
        }
    }];
    return txs;
}

- (NSArray *)txInValues:(NSData *)txHash;{
    __block NSMutableArray *result = [NSMutableArray new];
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = @"select b.out_value "
                "from ins a left outer join outs b on a.prev_tx_hash=b.tx_hash and a.prev_out_sn=b.out_sn "
                "where a.tx_hash=?";
        FMResultSet *rs = [db executeQuery:sql, [NSString base58WithData:txHash]];
        while ([rs next]) {
            if ([rs columnIsNull:@"out_value"]) {
                [result addObject:[NSNull null]];
            } else {
                [result addObject:@([rs unsignedLongLongIntForColumn:@"out_value"])];
            }
        }
        [rs close];
    }];
    return result;
}

- (NSDictionary *)getTxDependencies:(BTTxItem *)txItem;{
    __block NSMutableDictionary *result = [NSMutableDictionary new];
    [[[BTDatabaseManager instance] getDbQueue] inDatabase:^(FMDatabase *db) {
        for (BTInItem *in in txItem.ins) {
            BTTxItem *tx;
            NSString *txHashStr = [NSString base58WithData:in.txHash];
            NSString *sql = @"select * from txs where tx_hash=?";
            FMResultSet *rs = [db executeQuery:sql, txHashStr];
            if ([rs next]) {
                tx = [self format:rs];
                [rs close];
            } else {
                [rs close];
                continue;
            }
            tx.ins = [NSMutableArray new];
            tx.outs = [NSMutableArray new];
            sql = @"select * from ins where tx_hash=? order by in_sn";
            rs = [db executeQuery:sql, txHashStr];
            while ([rs next]) {
                BTInItem *inItem = [self formatIn:rs];
                [tx.ins addObject:inItem];
                inItem.tx = tx;
            }
            [rs close];

            sql = @"select * from outs where tx_hash=? order by out_sn";
            rs = [db executeQuery:sql, txHashStr];
            while ([rs next]) {
                BTOutItem *outItem = [self formatOut:rs];
                [tx.outs addObject:outItem];
                outItem.tx = tx;
            }
            [rs close];
            result[tx.txHash] = tx;
        }
    }];
    return result;
}

- (BTTxItem *)format:(FMResultSet *)rs {
    BTTxItem *txItem = [BTTxItem new];
    if ([rs columnIsNull:@"block_no"]) {
        txItem.blockNo = TX_UNCONFIRMED;
    } else {
        txItem.blockNo = (uint) [rs intForColumn:@"block_no"];
    }
    txItem.txHash = [[rs stringForColumn:@"tx_hash"] base58ToData];
    txItem.source = [rs intForColumn:@"source"];
    if (txItem.source >= 1) {
        txItem.sawByPeerCnt = txItem.source - 1;
        txItem.source = 1;
    } else {
        txItem.sawByPeerCnt = 0;
        txItem.source = 0;
    }
    txItem.txTime = (uint) [rs intForColumn:@"tx_time"];
    txItem.txVer = (uint) [rs intForColumn:@"tx_ver"];
    txItem.txLockTime = (uint) [rs intForColumn:@"tx_locktime"];
    return txItem;
}

- (BTInItem *)formatIn:(FMResultSet *)rs {
    BTInItem *inItem = [BTInItem new];
    inItem.txHash = [[rs stringForColumn:@"tx_hash"] base58ToData];
    inItem.inSn = (uint) [rs intForColumn:@"in_sn"];
//    inItem.inScript = [[rs stringForColumn:@"in_script"] base58ToData];
    inItem.prevTxHash = [[rs stringForColumn:@"prev_tx_hash"] base58ToData];
    inItem.prevOutSn = (uint) [rs intForColumn:@"prev_out_sn"];
    if ([rs columnIsNull:@"in_signature"]) {
        inItem.inSignature = (id) [NSNull null];
    } else {
        inItem.inSignature = [[rs stringForColumn:@"in_signature"] base58ToData];
    }
    inItem.inSequence = (uint) [rs intForColumn:@"in_sequence"];
    return inItem;
}

- (BTOutItem *)formatOut:(FMResultSet *)rs {
    BTOutItem *outItem = [BTOutItem new];
    outItem.txHash = [[rs stringForColumn:@"tx_hash"] base58ToData];
    outItem.outSn = (uint) [rs intForColumn:@"out_sn"];
    outItem.outScript = [[rs stringForColumn:@"out_script"] base58ToData];
    outItem.outValue = [rs unsignedLongLongIntForColumn:@"out_value"];
    outItem.outStatus = [rs intForColumn:@"out_status"];
    if ([rs columnIsNull:@"out_address"]) {
        outItem.outAddress = nil;
    } else {
        outItem.outAddress = [rs stringForColumn:@"out_address"];
    }
    outItem.coinDepth = 0;
    return outItem;
}
@end