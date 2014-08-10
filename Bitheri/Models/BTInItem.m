//
//  BTInItem.m
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

#import "BTInItem.h"


@implementation BTInItem {

}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[BTInItem class]]) {
        return NO;
    }
    BTInItem *item = (BTInItem *) object;
    if ((self.inSignature == nil && item.inSignature != nil) || (self.inSignature != nil && item.inSignature == nil)
            || (self.inSignature == nil && item.inSignature != nil && ![self.inSignature isEqualToData:item.inSignature])) {
        return NO;
    }
    return (self.inSn == item.inSn) && [self.prevTxHash isEqualToData:item.prevTxHash]
            && (self.prevOutSn == item.prevOutSn) && [self.txHash isEqualToData:item.txHash]
            && (self.inSequence == item.inSequence);
}
@end