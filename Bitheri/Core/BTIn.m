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
#import "NSDictionary+Fromat.h"
#import "BTScriptBuilder.h"

@implementation BTIn {

}

- (instancetype)initWithTx:(BTTx *)tx inDict:(NSDictionary *)inDict {
    if (!(self = [self init])) return nil;
    
    _prevTxHash = [[[inDict getStringFromDict:@"prev_tx_hash"] hexToData] reverse];
    _prevOutSn = [inDict getIntFromDict:@"prev_position"];
    NSString *prevType = [inDict getStringFromDict:@"prev_type"];
    if (prevType && [[prevType uppercaseString] isEqualToString: @"P2WPKH_V0"]) {
        NSArray *witness = [inDict getArrayFromDict:@"witness"];
        if (witness.count == 2 && [witness[1] isKindOfClass:[NSString class]]) {
            NSData *pubkeyHash = [[witness[1] hexToData] hash160];
            BTScriptBuilder *scriptBuilder = [[BTScriptBuilder alloc] init];
            [scriptBuilder smallNum:0];
            [scriptBuilder data:pubkeyHash];
            _inSignature = [[scriptBuilder build] program];
        }
    }
    if (!_inSignature && _inSignature.length == 0) {
        _inSignature = [[inDict getStringFromDict:@"script_hex"] hexToData];
    }
    _inSequence = [inDict getIntFromDict:@"sequence"];
    _tx = tx;
    _txHash = tx.txHash;
    
    return self;
}

- (instancetype)initWithTx:(BTTx *)tx blockchairJsonObject:(NSDictionary *)blockchairJsonObject {
    if (!(self = [self init])) return nil;
    
    _prevTxHash = [[[blockchairJsonObject getStringFromDict:@"transaction_hash"] hexToData] reverse];
    _prevOutSn = [blockchairJsonObject getIntFromDict:@"index"];
    if ([[blockchairJsonObject getStringFromDict:@"type"] isEqualToString:@"witness_v0_keyhash"]) {
        _inSignature = [[blockchairJsonObject getStringFromDict:@"script_hex"] hexToData];
    } else {
        _inSignature = [[blockchairJsonObject getStringFromDict:@"spending_signature_hex"] hexToData];
    }
    _inSequence = [blockchairJsonObject getIntFromDict:@"spending_sequence"];
    _tx = tx;
    _txHash = tx.txHash;
    return self;
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
