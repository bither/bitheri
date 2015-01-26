//
//  BTDatabaseManager.h
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

#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "BTSettings.h"

@interface BTDatabaseManager : NSObject

#pragma mark - tx db
@property (nonatomic, copy, readonly) NSString *createTableBlocksSql;
@property (nonatomic, copy, readonly) NSString *createIndexBlocksBlockNoSql;
@property (nonatomic, copy, readonly) NSString *createIndexBlocksBlockPrevSql;
@property (nonatomic, copy, readonly) NSString *createTableTxsSql;
@property (nonatomic, copy, readonly) NSString *createIndexTxsBlockNoSql;
@property (nonatomic, copy, readonly) NSString *createTableAddressesTxsSql;
@property (nonatomic, copy, readonly) NSString *createTableInsSql;
@property (nonatomic, copy, readonly) NSString *createIndexInsPrevTxHashSql;
@property (nonatomic, copy, readonly) NSString *createTableOutsSql;
@property (nonatomic, copy, readonly) NSString *createIndexOutsOutAddressSql;
@property (nonatomic, copy, readonly) NSString *createTablePeersSql;

#pragma mark - address db
@property (nonatomic, copy, readonly) NSString *createTablePasswordSeedSql;
@property (nonatomic, copy, readonly) NSString *createTableAddressesSql;
@property (nonatomic, copy, readonly) NSString *createTableHDSeedsSql;
@property (nonatomic, copy, readonly) NSString *createTableHDMAddressesSql;
@property (nonatomic, copy, readonly) NSString *createTableHDMBidSql;

+ (instancetype)instance;

- (FMDatabaseQueue *)getTxDbQueue;
- (FMDatabaseQueue *)getAddressDbQueue;

//-(BOOL)initDatabase;
//- (void)closeDatabase;
//- (BOOL)dbIsOpen;

@end

