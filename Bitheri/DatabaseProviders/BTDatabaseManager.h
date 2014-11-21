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

typedef void (^IdResponseBlock)(id response);

typedef void (^ArrayResponseBlock)(NSArray *array);

@interface BTDatabaseManager : NSObject

@property (nonatomic, copy) NSString *createTableBlocksSql;
@property (nonatomic, copy) NSString *createIndexBlocksBlockNoSql;
@property (nonatomic, copy) NSString *createIndexBlocksBlockPrevSql;
@property (nonatomic, copy) NSString *createTableTxsSql;
@property (nonatomic, copy) NSString *createTableAddressesTxsSql;
@property (nonatomic, copy) NSString *createTableInsSql;
@property (nonatomic, copy) NSString *createTableOutsSql;
@property (nonatomic, copy) NSString *createTablePeersSql;
+ (instancetype)instance;

- (void)closeDatabase;

- (FMDatabaseQueue *)getDbQueue;

-(BOOL)initDatabase;

- (BOOL)dbIsOpen;

@end

