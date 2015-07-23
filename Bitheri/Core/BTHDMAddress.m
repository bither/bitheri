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
#import "BTHDMKeychain.h"
#import "BTScriptBuilder.h"
#import "BTAddressProvider.h"

@implementation BTHDMPubs
static NSData *EMPTYBYTES;

+ (NSData *)EmptyBytes {
    if (!EMPTYBYTES) {
        Byte b = 0;
        EMPTYBYTES = [NSData dataWithBytes:&b length:sizeof(b)];
    }
    return EMPTYBYTES;
}

- (instancetype)initWithHot:(NSData *)hot cold:(NSData *)cold remote:(NSData *)remote andIndex:(UInt32)index {
    self = [super init];
    if (self) {
        self.hot = hot;
        self.cold = cold;
        self.remote = remote;
        self.index = index;
    }
    return self;
}

- (BOOL)hasHot {
    return self.hot && ![self.hot isEqualToData:[BTHDMPubs EmptyBytes]];
}

- (BOOL)hasCold {
    return self.cold && ![self.cold isEqualToData:[BTHDMPubs EmptyBytes]];
}

- (BOOL)hasRemote {
    return self.remote && ![self.remote isEqualToData:[BTHDMPubs EmptyBytes]];
}

- (BOOL)isCompleted {
    return self.hasHot && self.hasCold && self.hasRemote;
}

- (BTScript *)multisigScript {
    if (!self.isCompleted) {
        [NSException raise:@"BTHDMPubs not completed" format:@"Can not get multisig script when pubs are not completed"];
    }
    return [BTScriptBuilder createMultiSigRedeemWithThreshold:2 andPubKeys:@[self.hot, self.cold, self.remote]];
}

- (NSString *)address {
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

- (instancetype)initWithPubs:(BTHDMPubs *)pubs andKeychain:(BTHDMKeychain *)keychain syncCompleted:(BOOL)isSyncCompleted {
    self = [self initWithPubs:pubs address:pubs.address syncCompleted:isSyncCompleted andKeychain:keychain];
    return self;
}

- (instancetype)initWithPubs:(BTHDMPubs *)pubs address:(NSString *)address syncCompleted:(BOOL)isSyncCompleted andKeychain:(BTHDMKeychain *)keychain {
    self = [super initWithAddress:address encryptPrivKey:nil pubKey:pubs.multisigScript.program hasPrivKey:NO isSyncComplete:isSyncCompleted isXRandom:keychain.isFromXRandom];
    if (self) {
        self.pubs = pubs;
        self.keychain = keychain;
        self.isSyncComplete = isSyncCompleted;
    }
    return self;
}

- (BOOL)signTx:(BTTx *)tx withPassword:(NSString *)password andFetchBlock:(NSArray *(^)(UInt32 index, NSString *password, NSArray *unsignHashes, BTTx *tx))fetchBlock {
    return [tx signWithSignatures:[self signUnsginedHashes:tx.unsignedInHashes withPassword:password tx:tx andOtherBlock:fetchBlock]];
}

- (BOOL)signTx:(BTTx *)tx withPassword:(NSString *)password coldBlock:(NSArray *(^)(UInt32 index, NSString *password, NSArray *unsignHashes, BTTx *tx))fetchBlockCold andRemoteBlock:(NSArray *(^)(UInt32 index, NSString *password, NSArray *unsignHashes, BTTx *tx))fetchBlockRemote {
    NSArray *unsigns = tx.unsignedInHashes;
    NSArray *coldSigs = fetchBlockCold(self.index, password, unsigns, tx);
    NSArray *remoteSigs = fetchBlockRemote(self.index, password, unsigns, tx);
    if (coldSigs.count == remoteSigs.count && coldSigs.count == unsigns.count) {
        NSArray *joined = [self formatInScriptFromSigns1:coldSigs andSigns2:remoteSigs];
        return [tx signWithSignatures:joined];
    } else {
        return NO;
    }
}

- (NSArray *)signUnsginedHashes:(NSArray *)unsignedHashes withPassword:(NSString *)password tx:(BTTx *)tx andOtherBlock:(NSArray *(^)(UInt32 index, NSString *password, NSArray *unsignHashes, BTTx *tx))block {
    NSArray *hotSigs = [self signMyPartUnsignedHashes:unsignedHashes withPassword:password];
    NSArray *otherSigs = block(self.index, password, unsignedHashes, tx);
    if (hotSigs.count == otherSigs.count && hotSigs.count == unsignedHashes.count) {
        return [self formatInScriptFromSigns1:hotSigs andSigns2:otherSigs];
    }
    return [NSArray new];
}

- (NSArray *)signMyPartUnsignedHashes:(NSArray *)unsignedHashes withPassword:(NSString *)password {
    if (self.isInRecovery) {
        [NSException raise:@"recovery hdm address can not sign" format:nil];
    }
    BTBIP32Key *key = [self.keychain externalKeyWithIndex:self.index andPassword:password];
    if (!key) {
        [BTHDMPasswordWrongException raise:@"password wrong" format:nil];
    }
    NSMutableArray *sigs = [NSMutableArray new];
    for (NSData *hash in unsignedHashes) {
        NSMutableData *s = [NSMutableData dataWithData:[key.key sign:hash]];
        [s appendUInt8:SIG_HASH_ALL];
        [sigs addObject:s];
    }
    [key wipe];
    return sigs;
}

- (NSArray *)signHashes:(NSArray *)unsignedInHashes withPassphrase:(NSString *)passphrase {
    [NSException raise:@"hdm address can't sign transactions all by self" format:nil];
    return nil;
}

- (UInt32)index {
    return self.pubs.index;
}

- (NSData *)pubHot {
    return self.pubs.hot;
}

- (NSData *)pubCold {
    return self.pubs.cold;
}

- (NSData *)pubRemote {
    return self.pubs.remote;
}

- (NSArray *)pubKeys {
    NSMutableArray *keys = [NSMutableArray new];
    [keys addObject:self.pubHot];
    [keys addObject:self.pubCold];
    [keys addObject:self.pubRemote];
    return keys;
}

- (BOOL)isInRecovery {
    return self.keychain.isInRecovery;
}

- (BOOL)isFromXRandom {
    return self.keychain.isFromXRandom;
}

- (BOOL)isHDM {
    return YES;
}

- (void)updateSyncComplete; {
    [[BTAddressProvider instance] updateSyncCompleteHDSeedId:self.keychain.hdSeedId hdSeedIndex:self.index syncComplete:self.isSyncComplete];
}

- (NSArray *)formatInScriptFromSigns1:(NSArray *)signs1 andSigns2:(NSArray *)signs2 {
    NSMutableArray *result = [NSMutableArray new];
    for (UInt32 i = 0; i < signs1.count; i++) {
        NSMutableArray *signs = [NSMutableArray new];
        [signs addObject:signs1[i]];
        [signs addObject:signs2[i]];
        BTScript *script = [BTScriptBuilder createP2SHMultiSigInputScriptWithSignatures:signs andMultisigProgram:self.pubKey];
        [result addObject:[script program]];
    }
    return result;
}


- (NSData *)scriptPubKey; {
    return self.pubKey;
}

@end

@implementation BTHDMColdPubNotSameException
@end

@implementation BTHDMPasswordWrongException
@end
