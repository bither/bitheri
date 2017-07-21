//
//  BTHDAccountAddress.h
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


typedef enum {
    EXTERNAL_ROOT_PATH = 0, INTERNAL_ROOT_PATH = 1,

} PathType;

@interface PathTypeIndex : NSObject
@property PathType pathType;
@property NSUInteger index;
@end

@interface BTHDAccountAddress : NSObject

@property (nonatomic, readwrite) int hdAccountId;
@property(nonatomic, strong) NSString *address;
@property(nonatomic, strong) NSData *pub;
@property(nonatomic, readwrite) PathType pathType;
@property(nonatomic, readwrite) int index;
@property(nonatomic, readwrite) BOOL isSyncedComplete;
@property(nonatomic, readwrite) BOOL isIssued;
@property(nonatomic, readonly) uint64_t balance;

+ (PathType)getPathType:(int)type;

- (instancetype)initWithPub:(NSData *)pub path:(PathType)path index:(int)index andSyncedComplete:(BOOL)isSyncedComplete;
- (instancetype)initWithAddress:(NSString *)address pub:(NSData *)pub path:(PathType)path index:(int)index issued:(BOOL)issued andSyncedComplete:(BOOL)isSyncedComplete;
- (instancetype)initWithHDAccountId:(int)hdAccountId address:(NSString *)address pub:(NSData *)pub path:(PathType)path index:(int)index issued:(BOOL)issued andSyncedComplete:(BOOL)isSyncedComplete;

@end
