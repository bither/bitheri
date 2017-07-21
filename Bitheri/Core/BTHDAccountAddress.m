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
#import "BTTxProvider.h"
#import "BTIn.h"

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
    [self updateBalance];

    return self;
}

+ (PathType)getPathType:(int)type {
    if (type == 0) {
        return EXTERNAL_ROOT_PATH;
    } else {
        return INTERNAL_ROOT_PATH;
    }
}

- (void)updateBalance {
    _balance = [[BTTxProvider instance] getConfirmedBalanceWithAddress:self.address] + [self calculateUnconfirmedBalance];
}

- (uint64_t)calculateUnconfirmedBalance {
    uint64_t balance = 0;
    NSMutableOrderedSet *utxos = [NSMutableOrderedSet orderedSet];
    NSMutableSet *spentOutputs = [NSMutableSet set], *invalidTx = [NSMutableSet set];
    NSMutableArray *txs = [NSMutableArray arrayWithArray:[[BTTxProvider instance] getUnconfirmedTxWithAddress:_address]];
    
    [txs sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        BTTx *tx1 = (BTTx *) obj1;
        BTTx *tx2 = (BTTx *) obj2;
        if ([obj1 blockNo] > [obj2 blockNo]) return NSOrderedAscending;
        if ([obj1 blockNo] < [obj2 blockNo]) return NSOrderedDescending;
        NSMutableSet *inputHashSet1 = [NSMutableSet new];
        for (BTIn *in in tx1.ins) {
            [inputHashSet1 addObject:in.prevTxHash];
        }
        NSMutableSet *inputHashSet2 = [NSMutableSet new];
        for (BTIn *in in tx2.ins) {
            [inputHashSet2 addObject:in.prevTxHash];
        }
        if ([inputHashSet1 containsObject:[obj2 txHash]]) return NSOrderedAscending;
        if ([inputHashSet2 containsObject:[obj1 txHash]]) return NSOrderedDescending;
        if ([obj1 txTime] > [obj2 txTime]) return NSOrderedAscending;
        if ([obj1 txTime] < [obj2 txTime]) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    for (BTTx *tx in [txs reverseObjectEnumerator]) {
        NSMutableSet *spent = [NSMutableSet set];
        
        for (BTIn *btIn in tx.ins) {
            [spent addObject:getOutPoint(btIn.prevTxHash, btIn.prevOutSn)];
        }
        
        // check if any inputs are invalid or already spent
        NSMutableSet *inputHashSet = [NSMutableSet new];
        for (BTIn *in in tx.ins) {
            [inputHashSet addObject:in.prevTxHash];
        }
        if (tx.blockNo == TX_UNCONFIRMED &&
            ([spent intersectsSet:spentOutputs] || [inputHashSet intersectsSet:invalidTx])) {
            [invalidTx addObject:tx.txHash];
            continue;
        }
        
        [spentOutputs unionSet:spent]; // add inputs to spent output set
        
        for (BTOut *out in tx.outs) { // add outputs to UTXO set
            if ([self.address isEqualToString:out.outAddress]) {
                [utxos addObject:getOutPoint(tx.txHash, out.outSn)];
                balance += out.outValue;
            }
        }
        
        // transaction ordering is not guaranteed, so check the entire UTXO set against the entire spent output set
        [spent setSet:[utxos set]];
        [spent intersectSet:spentOutputs];
        
        for (NSData *o in spent) { // remove any spent outputs from UTXO set
            BTTx *transaction = [[BTTxProvider instance] getTxDetailByTxHash:[o hashAtOffset:0]];
            uint n = [o UInt32AtOffset:CC_SHA256_DIGEST_LENGTH];
            
            [utxos removeObject:o];
            balance -= [transaction getOut:n].outValue;
        }
    }
    return balance;
}

@end
