//
//  BTIn.m
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
//  limitations under the License.#import "BTIn.h"


#import "BTTx.h"
#import "BTIn.h"
#import "BTScript.h"

@implementation BTIn {

}

- (void)setTx:(BTTx *)tx {
    _tx = tx;
    _txHash = tx.txHash;
}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[BTIn class]]) {
        return NO;
    }
    BTIn *item = (BTIn *) object;
    if ((self.inSignature == nil && item.inSignature != nil) || (self.inSignature != nil && item.inSignature == nil)
            || (self.inSignature == nil && item.inSignature != nil && ![self.inSignature isEqualToData:item.inSignature])) {
        return NO;
    }
    return (self.inSn == item.inSn) && [self.prevTxHash isEqualToData:item.prevTxHash]
            && (self.prevOutSn == item.prevOutSn) && [self.txHash isEqualToData:item.txHash]
            && (self.inSequence == item.inSequence);
}

- (NSArray *)getP2SHPubKeys; {
    BTScript *script = [[BTScript alloc] initWithProgram:self.inSignature];
    script.tx = self.tx;
    script.index = self.inSn;
    return [script getP2SHPubKeys];
}

- (BOOL)isCoinBase {
    return [self.prevTxHash isEqualToData:[NSMutableData secureDataWithLength:32]] && (self.prevOutSn & 0xFFFFFFFFL) == 0xFFFFFFFFL;
}
@end