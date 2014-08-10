//
//  BTTxItem.m
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

#import "BTTxItem.h"
#import "BTSettings.h"

@implementation BTTxItem {

}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[BTTxItem class]]) {
        DDLogVerbose(@"object is not instance of BTTxItem");
        return NO;
    }
    BTTxItem *item = (BTTxItem *) object;
    if ((self.blockNo == item.blockNo) && [self.txHash isEqualToData:item.txHash] && self.source == item.source
            && self.sawByPeerCnt == item.sawByPeerCnt && self.txTime == item.txTime && self.txVer == item.txVer
            && self.txLockTime == item.txLockTime) {
        if (self.ins.count != item.ins.count){
            DDLogVerbose(@"ins count is not match");
            return NO;
        }
        if (self.outs.count != item.outs.count){
            DDLogVerbose(@"outs count is not match");
            return NO;
        }
        for (NSUInteger i = 0; i < self.ins.count; i++) {
            if (![self.ins[i] isEqual:item.ins[i]]){
                DDLogVerbose(@"ins[%lu] is not match", i);
                return NO;
            }
        }
        for (NSUInteger i = 0; i < self.outs.count; i++) {
            if (![self.outs[i] isEqual:item.outs[i]]){
                DDLogVerbose(@"outs[%lu] is not match", (unsigned long)i);
                return NO;
            }
        }
        return YES;
    } else {
        DDLogVerbose(@"tx base info is not match");
        return NO;
    }
}
@end