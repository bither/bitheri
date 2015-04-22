//
//  BTScriptBuilder.m
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

#import "BTScriptBuilder.h"
#import "BTScript.h"
#import "BTScriptOpCodes.h"


@implementation BTScriptBuilder {

}

- (instancetype)init {
    self = [super init];
    if (self) {
        _chunks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (BTScriptBuilder *)addChunk:(BTScriptChunk *)chunk {
    [_chunks addObject:chunk];
    return self;
}

- (BTScriptBuilder *)op:(int)opCode; {
    if (opCode > OP_PUSHDATA4) {
        return [self addChunk:[[BTScriptChunk alloc] initWithOpCode:opCode andData:nil]];
    } else {
        return nil;
    }
}

- (BTScriptBuilder *)data:(NSData *)data; {
    NSData *copy = [data copy];
    int opCode = 0;
    if (copy.length == 0) {
        opCode = OP_0;
    } else if (copy.length == 1) {
        uint8_t b = *((const uint8_t *) copy.bytes);
        if (b >= 1 && b <= 16) {
            opCode = [BTScript encodeToOpN:b];
        } else {
            opCode = 1;
        }
    } else if (copy.length < OP_PUSHDATA1) {
        opCode = copy.length;
    } else if (copy.length < 256) {
        opCode = OP_PUSHDATA1;
    } else if (copy.length < 65536) {
        opCode = OP_PUSHDATA2;
    } else {
        return nil;
    }
    return [self addChunk:[[BTScriptChunk alloc] initWithOpCode:opCode andData:copy]];
}

- (BTScriptBuilder *)smallNum:(int)num; {
    if (num >= 0 && num <= 16) {
        return [self addChunk:[[BTScriptChunk alloc] initWithOpCode:[BTScript encodeToOpN:num] andData:nil]];
    } else {
        return nil;
    }
}

- (BTScript *)build; {
    return [[BTScript alloc] initWithChunks:self.chunks];
}

#pragma mark - p2sh

+ (BTScript *)createMultiSigRedeemWithThreshold:(int)threshold andPubKeys:(NSArray *)pubKeys; {
    BTScriptBuilder *builder = [[[BTScriptBuilder alloc] init] smallNum:threshold];
    for (NSData *pubKey in pubKeys) {
        [builder data:pubKey];
    }
    [builder smallNum:(int) pubKeys.count];
    [builder op:OP_CHECKMULTISIG];
    return [builder build];
}

+ (BTScript *)createP2SHMultiSigInputScriptWithSignatures:(NSArray *)signatures andMultisigProgram:(NSData *)multisigProgram; {
    BTScriptBuilder *builder = [[[BTScriptBuilder alloc] init] smallNum:0];
    for (NSData *signature in signatures) {
        [builder data:signature];
    }
    [builder data:multisigProgram];
    return [builder build];
}

+ (BTScript *)createP2SHOutputScriptWithHash:(NSData *)hash; {
    return [[[[[[BTScriptBuilder alloc] init] op:OP_HASH160] data:hash] op:OP_EQUAL] build];
}

+ (BTScript *)createP2SHOutputScriptWithMultiSigRedeem:(BTScript *)script; {
    return [BTScriptBuilder createP2SHOutputScriptWithHash:[[script program] hash160]];
}

+ (BTScript *)createPubKeyHashInSignatureWithSignature:(NSData *)signature andPubKey:(NSData *)pubKey; {
    return [[[[[BTScriptBuilder alloc] init] data:signature] data:pubKey] build];
}
@end