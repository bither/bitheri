//
//  BTHDMAddress.m
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
#import "BTHDMAddress.h"
#import "BTScriptBuilder.h"
#import "BTUtils.h"
#import "NSData+Hash.h"

@implementation BTHDMPubs
static NSData* EMPTYBYTES;

+(NSData*)EmptyBytes{
    if(!EMPTYBYTES){
        Byte b = 0;
        EMPTYBYTES = [NSData dataWithBytes:b length:sizeof(b)];
    }
    return EMPTYBYTES;
}

-(instancetype)initWithHot:(NSData*)hot cold:(NSData*)cold remote:(NSData*)remote andIndex:(NSUInteger)index{
    self.hot = hot;
    self.cold = cold;
    self.remote = remote;
    self.index = index;
}

-(BOOL)hasHot{
    return self.hot && ![self.hot isEqualToData:[BTHDMPubs EmptyBytes]];
}

-(BOOL)hasCold{
    return self.cold && ![self.cold isEqualToData:[BTHDMPubs EmptyBytes]];
}

-(BOOL)hasRemote{
    return self.remote && ![self.remote isEqualToData:[BTHDMPubs EmptyBytes]];
}

-(BOOL)isCompleted{
    return self.hasHot && self.hasCold && self.hasRemote;
}

-(BTScript*)multisigScript{
    if(!self.isCompleted){
        [NSException raise:@"BTHDMPubs not completed" format:@"Can not get multisig script when pubs are not completed"];
    }
    return [BTScriptBuilder createMultisigScriptWithThreshold:2 andPubKeys:@[self.hot, self.cold, self.remote]];
}

-(NSString*)address{
    return [self p2shAddressFromHash:self.multisigScript.program.hash160];
}

- (NSString *)p2shAddressFromHash:(NSData *)hash; {
    if (!hash.length) return nil;
    NSMutableData *d = [NSMutableData secureDataWithCapacity:hash.length + 1];
#if BITCOIN_TESTNET
    uint8_t version = BITCOIN_SCRIPT_ADDRESS_TEST;
#else
    uint8_t version = BITCOIN_SCRIPT_ADDRESS;
#endif
    [d appendBytes:&version length:1];
    [d appendData:hash];
    return [NSString base58checkWithData:d];
}

@end

@implementation BTHDMAddress

-(instancetype)initWithPubs:(BTHDMPubs*)pubs andKeychain:(BTHDMKeychain*)keychain{
    
}

-(instancetype)initWithPubs:(BTHDMPubs *)pubs address:(NSString*)address syncCompleted:(BOOL)isSyncCompleted andKeychain:(BTHDMKeychain *)keychain{

}
@end