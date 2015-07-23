//
//  BTHDAccountAddress.m
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

#import "BTHDAccountAddress.h"
#import "BTUtils.h"
#import "BTKey.h"

@implementation PathTypeIndex
@end

@implementation BTHDAccountAddress {

}

- (instancetype)initWithPub:(NSData *)pub path:(PathType)path index:(int)index andSyncedComplete:(BOOL)isSyncedComplete {
    return [self initWithAddress:[[[BTKey alloc] initWithPublicKey:pub] address] pub:pub path:path index:index issued:NO andSyncedComplete:isSyncedComplete];
}

- (instancetype)initWithAddress:(NSString *)address pub:(NSData *)pub path:(PathType)path index:(int)index issued:(BOOL)issued andSyncedComplete:(BOOL)isSyncedComplete {
    return [self initWithHDAccountId:-1 address:address pub:pub path:path index:index issued:issued andSyncedComplete:isSyncedComplete];
}

- (instancetype)initWithHDAccountId:(int)hdAccountId address:(NSString *)address pub:(NSData *)pub path:(PathType)path index:(int)index issued:(BOOL)issued andSyncedComplete:(BOOL)isSyncedComplete; {
    if (!(self = [super init])) return nil;

    self.hdAccountId = hdAccountId;
    self.address = address;
    self.pub = pub;
    self.index = index;
    self.pathType = path;
    self.isIssued = issued;
    self.isSyncedComplete = isSyncedComplete;

    return self;
}

+ (PathType)getPathType:(int)type {
    if (type == 0) {
        return EXTERNAL_ROOT_PATH;
    } else {
        return INTERNAL_ROOT_PATH;
    }
}
@end