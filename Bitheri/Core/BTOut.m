//
//  BTOut.m
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
//  limitations under the License.#import "BTOut.h"


#import "BTTx.h"
#import "BTOut.h"
#import "NSDictionary+Fromat.h"
#import "BTScript.h"

@implementation BTOut {


}

- (instancetype)initWithTx:(BTTx *)tx outDict:(NSDictionary *)outDict unspentOutAddress:(NSString *)unspentOutAddress {
    if (!(self = [self init])) return nil;
    
    _outValue = [outDict getLongFromDict:@"value"];
    _outScript = [[outDict getStringFromDict:@"script_hex"] hexToData];
    _tx = tx;
    _txHash = tx.txHash;
    _outAddress = [[[BTScript alloc] initWithProgram:_outScript] getToAddress];
    if (_outAddress != NULL && ![_outAddress isEqualToString:unspentOutAddress]) {
        _outStatus = reloadSpent;
    } else {
        _outStatus = reloadUnspent;
    }
    return self;
}

- (instancetype)initWithTx:(BTTx *)tx blockchairJsonObject:(NSDictionary *)blockchairJsonObject {
    if (!(self = [self init])) return nil;
    
    _outValue = [blockchairJsonObject getLongFromDict:@"value"];
    _outScript = [[blockchairJsonObject getStringFromDict:@"script_hex"] hexToData];
    _tx = tx;
    _txHash = tx.txHash;
    _outAddress = [[[BTScript alloc] initWithProgram:_outScript] getToAddress];
    if ([blockchairJsonObject getBoolFromDict:@"is_spent"]) {
        _outStatus = reloadSpent;
    } else {
        _outStatus = reloadUnspent;
    }
    return self;
}

- (BOOL)isReload {
    switch (_outStatus) {
        case reloadSpent:
        case reloadUnspent:
            return true;
        default:
            return false;
    }
}

- (void)setTx:(BTTx *)tx {
    _tx = tx;
    _txHash = tx.txHash;
}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[BTOut class]]) {
        return NO;
    }
    BTOut *item = (BTOut *) object;
    return (self.outSn == item.outSn) && [self.outScript isEqualToData:item.outScript]
            && (self.outValue == item.outValue) && [self.outAddress isEqualToString:item.outAddress]
            && (self.outStatus == item.outStatus) && [self.txHash isEqualToData:item.txHash];
}
@end
