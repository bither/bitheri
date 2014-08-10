//
//  BTBlockItem.m
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

#import "BTBlockItem.h"


@implementation BTBlockItem {

}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[BTBlockItem class]]) {
        return NO;
    }
    BTBlockItem *item = (BTBlockItem *) object;
    return (self.blockNo == item.blockNo) && [self.blockHash isEqualToData:item.blockHash]
            && (self.blockVer == item.blockVer) && (self.blockBits == item.blockBits)
            && (self.blockNonce == item.blockNonce) && (self.blockTime == item.blockTime)
            && self.isMain == item.isMain;
}
@end
































