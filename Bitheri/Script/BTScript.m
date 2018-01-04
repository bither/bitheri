//
//  BTScript.m
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

#import <CocoaLumberjack/DDLog.h>
#import "BTScript.h"
#import "BTScriptChunk.h"
#import "BTScriptOpCodes.h"
#import "BTSettings.h"
#import "BTKey.h"
#import "BTIn.h"
#import "BTOut.h"
#import "BTTxProvider.h"

#define UINT24_MAX 8388607
#define SIG_SIZE 75

static NSArray *STANDARD_TRANSACTION_SCRIPT_CHUNKS = nil;

@interface BTScript ()


@property uint32_t creationTimeSeconds;

@end

@implementation BTScript {

}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    _chunks = [NSMutableArray new];
    return self;
}

- (instancetype)initWithChunks:(NSArray *)chunks; {
    if (!(self = [super init])) return nil;
//    NSMutableArray *chunks = [NSMutableArray new];
//    for (BTScriptChunk *chunk in chunks) {
//        [chunks addObject:chunk];
//    }
    _chunks = chunks;
    _creationTimeSeconds = (uint32_t) [[NSDate new] timeIntervalSince1970];
    return self;
}

- (instancetype)initWithProgram:(NSData *)program; {
    if (!(self = [super init])) return nil;
    _program = program;
    if (![self parse:program])
        return nil;
    _creationTimeSeconds = (uint32_t) [[NSDate new] timeIntervalSince1970];
    return self;
}

- (instancetype)initWithProgram:(NSData *)program andCreationTimeSeconds:(uint32_t)creationTimeSeconds; {
    if (!(self = [super init])) return nil;
    _program = program;
    if (![self parse:program])
        return nil;
    _creationTimeSeconds = creationTimeSeconds;
    return self;
}

- (NSArray *)getStandardTransactionScriptChunks; {
    if (STANDARD_TRANSACTION_SCRIPT_CHUNKS == nil) {
        STANDARD_TRANSACTION_SCRIPT_CHUNKS = @[
                [[BTScriptChunk alloc] initWithOpCode:OP_DUP andData:nil andStartLocationInProgram:0],
                [[BTScriptChunk alloc] initWithOpCode:OP_HASH160 andData:nil andStartLocationInProgram:1],
                [[BTScriptChunk alloc] initWithOpCode:OP_EQUALVERIFY andData:nil andStartLocationInProgram:23],
                [[BTScriptChunk alloc] initWithOpCode:OP_CHECKSIG andData:nil andStartLocationInProgram:24],
        ];
        return STANDARD_TRANSACTION_SCRIPT_CHUNKS;
    } else {
        return STANDARD_TRANSACTION_SCRIPT_CHUNKS;
    }

}

- (BOOL)parse:(NSData *)program {
    NSMutableArray *chunks = [NSMutableArray new];
    NSUInteger pos = 0;

    while (pos < program.length) {
        int startLocationInProgram = (int) pos;
        int opCode = [program UInt8AtOffset:pos++];

        int dataToRead = -1;
        if (opCode >= 0 && opCode < OP_PUSHDATA1) {
            dataToRead = (uint32_t) opCode;
        } else if (opCode == OP_PUSHDATA1) {
            if (program.length < pos + 1)
                return NO;
            dataToRead = [program UInt8AtOffset:pos++];
        } else if (opCode == OP_PUSHDATA2) {
            if (program.length < pos + 2)
                return NO;
            dataToRead = [program UInt16AtOffset:pos];
            pos += 2;
        } else if (opCode == OP_PUSHDATA4) {
            if (program.length < pos + 4)
                return NO;
            dataToRead = [program UInt32AtOffset:pos];
            pos += 4;
        }
        BTScriptChunk *chunk = nil;
        if (dataToRead == -1) {
            chunk = [[BTScriptChunk alloc] initWithOpCode:opCode andData:nil andStartLocationInProgram:startLocationInProgram];
        } else {
            if (program.length < pos + dataToRead)
                return NO;
            NSData *data = [program subdataWithRange:NSMakeRange(pos, (NSUInteger) dataToRead)];
//            NSData *data = [program dataAtOffset:pos length:(NSUInteger *) dataToRead];
            pos += dataToRead;
            chunk = [[BTScriptChunk alloc] initWithOpCode:opCode andData:data andStartLocationInProgram:startLocationInProgram];
        }
        for (BTScriptChunk *c in [self getStandardTransactionScriptChunks]) {
            if ([c isEqual:chunk])
                chunk = c;
        }
        [chunks addObject:chunk];
    }
    self.chunks = chunks;
    return YES;
}

- (NSString *)description; {
    NSMutableString *result = [NSMutableString new];
    for (BTScriptChunk *chunk in self.chunks) {
        [result appendString:[chunk description]];
        [result appendString:@" "];
    }
    if ([result length] > 0)
        [result deleteCharactersInRange:NSMakeRange(result.length - 1, 1)];
    return result;
}

- (NSData *)program {
    if (_program != nil) {
        return [NSData dataWithData:_program];
    }
    NSMutableData *result = [NSMutableData secureData];
    for (BTScriptChunk *chunk in self.chunks) {
        [result appendData:[chunk toData]];
    }
    _program = [NSData dataWithData:result];
    return _program;
}

- (BOOL)isSentToRawPubKey; {
    return self.chunks.count == 2 && [((BTScriptChunk *) self.chunks[1]) isEqualOpCode:OP_CHECKSIG]
            && ![((BTScriptChunk *) self.chunks[0]) isOpCode] && ((BTScriptChunk *) self.chunks[0]).data.length > 1;
}

- (BOOL)isSentToAddress; {
    return self.chunks.count == 5 &&
            [((BTScriptChunk *) self.chunks[0]) isEqualOpCode:OP_DUP] &&
            [((BTScriptChunk *) self.chunks[1]) isEqualOpCode:OP_HASH160] &&
            ((BTScriptChunk *) self.chunks[2]).data.length == 20 &&
            [((BTScriptChunk *) self.chunks[3]) isEqualOpCode:OP_EQUALVERIFY] &&
            [((BTScriptChunk *) self.chunks[4]) isEqualOpCode:OP_CHECKSIG];
}

- (BOOL)isSentToP2SH; {
    NSData *program = [self program];
    return program.length == 23 &&
            ([program UInt8AtOffset:0] & 0xff) == OP_HASH160 &&
            ([program UInt8AtOffset:1] & 0xff) == 0x14 &&
            ([program UInt8AtOffset:22] & 0xff) == OP_EQUAL;
}

- (BOOL)isSentToOldMultiSig; {
    if (self.chunks.count < 4) return NO;
    BTScriptChunk *chunk = self.chunks[self.chunks.count - 1];
    // Must end in OP_CHECKMULTISIG[VERIFY].
    if (![chunk isOpCode]) return NO;
    if (!(chunk.opCode == OP_CHECKMULTISIG || chunk.opCode == OP_CHECKMULTISIGVERIFY)) return NO;

    // Second to last chunk must be an OP_N opcode and there should be that many data chunks (keys).
    BTScriptChunk *m = self.chunks[self.chunks.count - 2];
    if (![m isOpCode]) return NO;
    long long numKeys = [BTScript decodeFromOpN:(uint8_t) m.opCode];
    if (numKeys < 1 || self.chunks.count != 3 + numKeys) return NO;
    for (int i = 1; i < self.chunks.count - 2; i++) {
        if ([((BTScriptChunk *) self.chunks[i]) isOpCode]) return NO;
    }
    // First chunk must be an OP_N opcode too.
    if ([BTScript decodeFromOpN:(uint8_t) ((BTScriptChunk *) self.chunks[0]).opCode] < 1) return NO;

    return YES;
}

- (BOOL)isSendFromMultiSig; {
    BOOL result = ((BTScriptChunk *) self.chunks.firstObject).opCode == OP_0;
    for (NSUInteger i = 1; i < self.chunks.count; i++) {
        BTScriptChunk *chunk = self.chunks[i];
        result &= (chunk.data != nil && chunk.data.length > 2);
    }
    if (result) {
        BTScript *multiSigRedeem = [[BTScript alloc] initWithProgram:((BTScriptChunk *) self.chunks.lastObject).data];
        result &= multiSigRedeem != nil;
        if (result) {
            result &= [multiSigRedeem isMultiSigRedeem];
        }
    }
    return result;
}

- (BOOL)isMultiSigRedeem; {
    BOOL result = OP_1 <= ((BTScriptChunk *) self.chunks.firstObject).opCode <= OP_16;
    for (NSUInteger i = 1; i < self.chunks.count - 2; i++) {
        BTScriptChunk *chunk = self.chunks[i];
        result &= (chunk.data != nil && chunk.data.length > 2);
    }
    result &= OP_1 <= ((BTScriptChunk *) self.chunks[self.chunks.count - 2]).opCode <= OP_16;
    result &= ((BTScriptChunk *) self.chunks[self.chunks.count - 1]).opCode == OP_CHECKMULTISIG;
    return result;
}

- (NSData *)getPubKeyHash; {
    if ([self isSentToAddress])
        return ((BTScriptChunk *) self.chunks[2]).data;
    else if ([self isSentToP2SH])
        return ((BTScriptChunk *) self.chunks[1]).data;
    else
        return nil;
}

- (NSData *)getPubKey; {
    if ([self.chunks count] != 2)
        return nil;
    BTScriptChunk *chunk0 = self.chunks[0];
    NSData *chunk0Data = chunk0.data;
    BTScriptChunk *chunk1 = self.chunks[1];
    NSData *chunk1Data = chunk1.data;
    if (chunk0Data != nil && [chunk0Data length] > 2 && chunk1Data != nil && [chunk1Data length] > 2)
        return chunk1Data;
    else if ([chunk1 isEqualOpCode:OP_CHECKSIG] && chunk0Data != nil && [chunk0Data length] > 2)
        return chunk0Data;
    else
        return nil;
}

- (NSData *)getSig; {
    if (self.chunks.count == 1 && [((BTScriptChunk *) self.chunks[0]) isPushData]) {
        return ((BTScriptChunk *) self.chunks[0]).data;
    } else if (self.chunks.count == 2 && [((BTScriptChunk *) self.chunks[0]) isPushData]
            && [((BTScriptChunk *) self.chunks[1]) isPushData]
            && ((BTScriptChunk *) self.chunks[0]).data.length > 2
            && ((BTScriptChunk *) self.chunks[1]).data.length > 2) {
        return ((BTScriptChunk *) self.chunks[0]).data;
    } else {
        return nil;
    }
}

- (NSArray *)getSigs; {
    NSMutableArray *result = [NSMutableArray new];
    if (self.chunks.count == 1 && [((BTScriptChunk *) self.chunks[0]) isPushData]) {
        [result addObject:((BTScriptChunk *) self.chunks[0]).data];
    } else if (self.chunks.count == 2 && [((BTScriptChunk *) self.chunks[0]) isPushData]
            && [((BTScriptChunk *) self.chunks[1]) isPushData]
            && ((BTScriptChunk *) self.chunks[0]).data != nil
            && ((BTScriptChunk *) self.chunks[0]).data.length > 2
            && ((BTScriptChunk *) self.chunks[1]).data != nil
            && ((BTScriptChunk *) self.chunks[1]).data.length > 2) {
        [result addObject:((BTScriptChunk *) self.chunks[0]).data];
    } else if (self.chunks.count >= 3 && ((BTScriptChunk *) self.chunks[0]).opCode == OP_0) {
        BOOL isPay2SHScript = YES;
        for (NSUInteger i = 1; i < self.chunks.count; i++) {
            isPay2SHScript &= (((BTScriptChunk *) self.chunks[i]).data != nil && ((BTScriptChunk *) self.chunks[i]).data.length > 2);
        }
        if (isPay2SHScript) {
            for (NSUInteger i = 1; i < self.chunks.count - 1; i++) {
                BTScriptChunk *chunk = (BTScriptChunk *) self.chunks[i];
                if ([chunk isPushData] && chunk.data != nil
                        && chunk.data.length > 0
                        && [chunk.data UInt8AtOffset:0] == 48) {
                    [result addObject:chunk.data];
                }
            }
        }
    }
    return result;
}

- (NSString *)getFromAddress; {
    if (self.chunks.count == 2
            && ((BTScriptChunk *) self.chunks[0]).data != nil && ((BTScriptChunk *) self.chunks[0]).data.length > 2
            && ((BTScriptChunk *) self.chunks[1]).data != nil && ((BTScriptChunk *) self.chunks[1]).data.length > 2) {
        return [self addressFromHash:[((BTScriptChunk *) self.chunks[1]).data hash160]];
    } else if (self.chunks.count >= 3 && ((BTScriptChunk *) self.chunks[0]).opCode == OP_0) {
        BOOL isP2SHScript = YES;
        for (NSUInteger i = 1; i < self.chunks.count; i++) {
            isP2SHScript &= ((BTScriptChunk *) self.chunks[i]).data != nil && ((BTScriptChunk *) self.chunks[i]).data.length > 2;
        }
        if (isP2SHScript) {
            return [self p2shAddressFromHash:[((BTScriptChunk *) self.chunks[self.chunks.count - 1]).data hash160]];
        }
    }
    return nil;
}

- (NSString *)getToAddress; {
    if ([self isSentToAddress])
        return [self addressFromHash:[self getPubKeyHash]];
    else if ([self isSentToP2SH])
        return [self p2shAddressFromHash:[self getPubKeyHash]];
    else
        return nil;
}

- (NSString *)addressFromHash:(NSData *)hash; {
    if (!hash.length) return nil;
    NSMutableData *d = [NSMutableData secureDataWithCapacity:hash.length + 1];
#if BITCOIN_TESTNET
    uint8_t version = BITCOIN_PUBKEY_ADDRESS_TEST;
#else
    uint8_t version = BITCOIN_PUBKEY_ADDRESS;
#endif

    [d appendBytes:&version length:1];
    [d appendData:hash];

    return [NSString base58checkWithData:d];
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

- (BOOL)correctlySpends:(BTScript *)scriptPubKey and:(BOOL)enforceP2SH; {

    if ([self program].length > 10000 || scriptPubKey.program.length > 10000) {
        DDLogWarn(@"[Script Error] Script larger than 10,000 bytes");
        return NO;
    }
    NSMutableArray *stack = [NSMutableArray new];
    NSMutableArray *p2shStack = nil;
    if (![self executeScript:self withStack:stack])
        return NO;
    if (enforceP2SH)
        p2shStack = [NSMutableArray arrayWithArray:stack];
    if (![self executeScript:scriptPubKey withStack:stack])
        return NO;
    if ([stack count] == 0) {
        DDLogWarn(@"[Script Error] Stack empty at end of script execution.");
        return NO;
    }


    if (!self.tx.isDetectBcc) {
        if (![BTScript castToBool:stack.lastObject]) {
            DDLogWarn(@"[Script Error] Script resulted in a non-true stack: %@", stack);
            return NO;
        }
    }

    [stack removeLastObject];

    if (enforceP2SH && [scriptPubKey isSentToP2SH]) {
        for (BTScriptChunk *chunk in self.chunks) {
            if ([chunk isOpCode] && chunk.opCode > OP_16) {
                DDLogWarn(@"[Script Error] Attempted to spend a P2SH scriptPubKey with a script that contained script ops");
                return NO;
            }
        }


        NSData *scriptPubKeyBytes = p2shStack.lastObject;
        [p2shStack removeLastObject];
        BTScript *scriptPubKeyP2SH = [[BTScript alloc] initWithProgram:scriptPubKeyBytes];

        [self executeScript:scriptPubKeyP2SH withStack:p2shStack];


        if ([p2shStack count] == 0) {
            DDLogWarn(@"[Script Error] P2SH stack empty at end of script execution.");
            return NO;
        }

        if (![BTScript castToBool:p2shStack.lastObject]) {
            DDLogWarn(@"[Script Error] P2SH script execution resulted in a non-true stack");
            return NO;
        }
        [p2shStack removeLastObject];

    }

    return YES;
}

- (NSArray *)getP2SHPubKeys; {
    if (![self isSendFromMultiSig]) {
        return nil;
    }
    BTScript *scriptPubKey = [[BTScript alloc] initWithProgram:((BTScriptChunk *) self.chunks.lastObject).data];
    int pubKeyCount = ((BTScriptChunk *) scriptPubKey.chunks[scriptPubKey.chunks.count - 2]).opCode - 80;
    int sigCount = ((BTScriptChunk *) scriptPubKey.chunks[0]).opCode - 80;
    if (pubKeyCount < 0 || pubKeyCount > 20) {
        DDLogWarn(@"[Script Error] OP_CHECKMULTISIG(VERIFY) with pubkey count out of range");
        return nil;
    }
    NSMutableArray *pubKeys = [NSMutableArray new];
    for (NSUInteger i = 0; i < pubKeyCount; i++) {
        BTScriptChunk *chunk = scriptPubKey.chunks[i + 1];
        [pubKeys addObject:chunk.data];
    }

    if (sigCount < 0 || sigCount > pubKeyCount) {
        DDLogWarn(@"[Script Error] OP_CHECKMULTISIG(VERIFY) with sig count out of range");
        return nil;
    }

    NSMutableArray *sigs = [NSMutableArray new];
    for (NSUInteger i = 1; i < sigCount + 1; i++) {
        [sigs addObject:((BTScriptChunk *) self.chunks[i]).data];
    }

    NSMutableArray *result = [NSMutableArray new];
    while ([sigs count] > 0) {
        NSData *pubKey = pubKeys.lastObject;
        [pubKeys removeLastObject];

        BTKey *key = [BTKey keyWithPublicKey:pubKey];
        NSData *sig = sigs.lastObject;
        if (sig.length > 0) {
            NSData *hash = [self.tx hashForSignature:self.index connectedScript:scriptPubKey.program
                                     sigHashType:[sig UInt8AtOffset:sig.length - 1]];
            if ([key verify:hash signature:sig]) {
                [result addObject:pubKey];
                [sigs removeLastObject];
            }
        }
        if ([sigs count] > [pubKeys count]) {
            break;
        }
    }

    return result;
}

- (uint)getSizeRequiredToSpendWithRedeemScript:(BTScript *)redeemScript andIsCompressed:(BOOL)isCompressed; {
    if ([self isSentToP2SH]) {
        BTScriptChunk *chunk = redeemScript.chunks[0];
        int n = (int) [BTScript decodeFromOpN:(uint8_t) chunk.opCode];
        return n * SIG_SIZE + redeemScript.program.length;
    } else if ([self isSentToOldMultiSig]) {
        BTScriptChunk *chunk = self.chunks[0];
        uint n = (uint) [BTScript decodeFromOpN:(uint8_t) chunk.opCode];
        return n * SIG_SIZE + 1;
    } else if ([self isSentToRawPubKey]) {
        return SIG_SIZE;
    } else if ([self isSentToAddress]) {
        uint compressedPubKeySize = 33;
        uint uncompressPubKeySize = 65;
        if (isCompressed) {
            return SIG_SIZE + compressedPubKeySize;
        } else {
            return SIG_SIZE + uncompressPubKeySize;
        }

    }
    return 1000;
}

- (BOOL)executeScript:(BTScript *)script withStack:(NSMutableArray *)stack; {
    int opCount = 0;
    int lastCodeSepLocation = 0;

    NSMutableArray *altStack = [NSMutableArray new];
    NSMutableArray *ifStack = [NSMutableArray new];

    for (BTScriptChunk *chunk in script.chunks) {
        BOOL shouldExecute = ![ifStack containsObject:@NO];
        if (![chunk isOpCode]) {
            if (chunk.data.length > MAX_SCRIPT_ELEMENT_SIZE) {
                DDLogWarn(@"[Script Error] Attempted to push a data string larger than 520 bytes");
                return NO;
            }
            if (!shouldExecute)
                continue;

            [stack addObject:chunk.data];
        } else {
            int opCode = chunk.opCode;
            if (opCode > OP_16) {
                opCount++;
                if (opCount > 201) {
                    DDLogWarn(@"[Script Error] More script operations than is allowed");
                    return NO;
                }
            }
            if (opCode == OP_VERIF || opCode == OP_VERNOTIF) {
                DDLogWarn(@"[Script Error] Script included OP_VERIF or OP_VERNOTIF");
                return NO;
            }
            if (opCode == OP_CAT || opCode == OP_SUBSTR || opCode == OP_LEFT || opCode == OP_RIGHT ||
                    opCode == OP_INVERT || opCode == OP_AND || opCode == OP_OR || opCode == OP_XOR ||
                    opCode == OP_2MUL || opCode == OP_2DIV || opCode == OP_MUL || opCode == OP_DIV ||
                    opCode == OP_MOD || opCode == OP_LSHIFT || opCode == OP_RSHIFT) {
                DDLogWarn(@"[Script Error] Script included OP_VERIF or OP_VERNOTIF");
                return NO;
            }

            switch (opCode) {
                case OP_IF: {
                    if (!shouldExecute) {
                        [ifStack addObject:@NO];
                        continue;
                    }
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_IF on an empty stack");
                        return NO;
                    }
                    [ifStack addObject:@([BTScript castToBool:stack.lastObject])];
                    [stack removeLastObject];
                    continue;
                }
                case OP_NOTIF: {
                    if (!shouldExecute) {
                        [ifStack addObject:@NO];
                        continue;
                    }
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_IF on an empty stack");
                        return NO;
                    }
                    [ifStack addObject:@(![BTScript castToBool:stack.lastObject])];
                    [stack removeLastObject];
                    continue;
                }
                case OP_ELSE: {
                    if ([ifStack count] == 0) {
                        DDLogWarn(@"[Script Error] Attempted OP_ELSE without OP_IF/NOTIF");
                        return NO;
                    }
                    BOOL tmp = [ifStack.lastObject boolValue];
                    [ifStack removeLastObject];
                    [ifStack addObject:@(!tmp)];
                    continue;
                }
                case OP_ENDIF: {
                    if ([ifStack count] == 0) {
                        DDLogWarn(@"[Script Error] Attempted OP_ENDIF without OP_IF/NOTIF");
                        return NO;
                    }
                    [ifStack removeLastObject];
                    continue;
                }
            }

            if (!shouldExecute)
                continue;

            switch (opCode) {
                case OP_1NEGATE:
                case OP_1:
                case OP_2:
                case OP_3:
                case OP_4:
                case OP_5:
                case OP_6:
                case OP_7:
                case OP_8:
                case OP_9:
                case OP_10:
                case OP_11:
                case OP_12:
                case OP_13:
                case OP_14:
                case OP_15:
                case OP_16: {
                    [stack addObject:[BTScript castInt64ToData:[BTScript decodeFromOpN:(uint8_t) opCode]]];
                    break;
                }
                case OP_NOP:
                    break;
                case OP_VERIFY: {
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_VERIFY on an empty stack");
                        return NO;
                    }
                    if (![BTScript castToBool:stack.lastObject]) {
                        DDLogWarn(@"[Script Error] OP_VERIFY failed");
                        return NO;
                    }
                    [stack removeLastObject];
                    break;
                }
                case OP_RETURN: {
                    DDLogWarn(@"[Script Error] Script called OP_RETURN");
                    return NO;
                }
                case OP_TOALTSTACK: {
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_TOALTSTACK on an empty stack");
                        return NO;
                    }
                    [altStack addObject:stack.lastObject];
                    [stack removeLastObject];
                    break;
                }
                case OP_FROMALTSTACK: {
                    if ([altStack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_TOALTSTACK on an empty altstack");
                        return NO;
                    }
                    [stack addObject:altStack.lastObject];
                    [altStack removeLastObject];
                    break;
                }
                case OP_2DROP: {
                    if ([stack count] < 2) {
                        DDLogWarn(@"[Script Error] Attempted OP_2DROP on a stack with size < 2");
                        return NO;
                    }
                    [stack removeLastObject];
                    [stack removeLastObject];
                    break;
                }
                case OP_2DUP: {
                    if ([stack count] < 2) {
                        DDLogWarn(@"[Script Error] Attempted OP_2DUP on a stack with size < 2");
                        return NO;
                    }
                    NSData *chunk1 = stack[stack.count - 2];
                    NSData *chunk2 = stack.lastObject;
                    [stack addObject:chunk1];
                    [stack addObject:chunk2];
                    break;
                }
                case OP_3DUP: {
                    if ([stack count] < 3) {
                        DDLogWarn(@"[Script Error] Attempted OP_3DUP on a stack with size < 3");
                        return NO;
                    }
                    NSData *chunk1 = stack[stack.count - 3];
                    NSData *chunk2 = stack[stack.count - 2];
                    NSData *chunk3 = stack.lastObject;
                    [stack addObject:chunk1];
                    [stack addObject:chunk2];
                    [stack addObject:chunk3];
                    break;
                }
                case OP_2OVER: {
                    if ([stack count] < 4) {
                        DDLogWarn(@"[Script Error] Attempted OP_2OVER on a stack with size < 4");
                        return NO;
                    }
                    NSData *chunk1 = stack[stack.count - 4];
                    NSData *chunk2 = stack[stack.count - 3];
                    [stack addObject:chunk1];
                    [stack addObject:chunk2];
                    break;
                }
                case OP_2ROT: {
                    if ([stack count] < 6) {
                        DDLogWarn(@"[Script Error] Attempted OP_2ROT on a stack with size < 6");
                        return NO;
                    }
                    NSData *chunk6 = stack.lastObject;
                    [stack removeLastObject];
                    NSData *chunk5 = stack.lastObject;
                    [stack removeLastObject];
                    NSData *chunk4 = stack.lastObject;
                    [stack removeLastObject];
                    NSData *chunk3 = stack.lastObject;
                    [stack removeLastObject];
                    NSData *chunk2 = stack.lastObject;
                    [stack removeLastObject];
                    NSData *chunk1 = stack.lastObject;
                    [stack removeLastObject];
                    [stack addObject:chunk3];
                    [stack addObject:chunk4];
                    [stack addObject:chunk5];
                    [stack addObject:chunk6];
                    [stack addObject:chunk1];
                    [stack addObject:chunk2];
                    break;
                }
                case OP_2SWAP: {
                    if ([stack count] < 4) {
                        DDLogWarn(@"[Script Error] Attempted OP_2SWAP on a stack with size < 4");
                        return NO;
                    }
                    NSData *chunk4 = stack.lastObject;
                    [stack removeLastObject];
                    NSData *chunk3 = stack.lastObject;
                    [stack removeLastObject];
                    NSData *chunk2 = stack.lastObject;
                    [stack removeLastObject];
                    NSData *chunk1 = stack.lastObject;
                    [stack addObject:chunk3];
                    [stack addObject:chunk4];
                    [stack addObject:chunk1];
                    [stack addObject:chunk2];
                    break;
                }
                case OP_IFDUP: {
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_IFDUP on an empty stack");
                        return NO;
                    }
                    if ([BTScript castToBool:stack.lastObject])
                        [stack addObject:stack.lastObject];
                    break;
                }
                case OP_DEPTH: {
                    [stack addObject:[BTScript castInt64ToData:stack.count]];
                    break;
                }
                case OP_DROP: {
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_DROP on an empty stack");
                        return NO;
                    }
                    [stack removeLastObject];
                    break;
                }
                case OP_DUP: {
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_DUP on an empty stack");
                        return NO;
                    }
                    [stack addObject:stack.lastObject];
                    break;
                }
                case OP_NIP: {
                    if ([stack count] < 2) {
                        DDLogWarn(@"[Script Error] Attempted OP_NIP on a stack with size < 2");
                        return NO;
                    }
                    NSData *chunk1 = stack.lastObject;
                    [stack removeLastObject];
                    [stack removeLastObject];
                    [stack addObject:chunk1];
                    break;
                }
                case OP_OVER: {
                    if ([stack count] < 2) {
                        DDLogWarn(@"[Script Error] Attempted OP_OVER on a stack with size < 2");
                        return NO;
                    }
                    NSData *chunk1 = stack[stack.count - 2];
                    [stack addObject:chunk1];
                    break;
                }
                case OP_PICK:
                case OP_ROLL: {
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_PICK/OP_ROLL on an empty stack");
                        return NO;
                    }
                    if (![self checkCastToInt:stack.lastObject])
                        return NO;
                    long long val = [BTScript castToInt64:stack.lastObject];
                    [stack removeLastObject];
                    if (val < 0 || val >= [stack count]) {
                        DDLogWarn(@"[Script Error] OP_PICK/OP_ROLL attempted to get data deeper than stack size");
                        return NO;
                    }
                    NSData *chunk1 = stack[(NSUInteger) (stack.count - val - 1)];
                    if (opCode == OP_ROLL)
                        [stack removeObjectAtIndex:(NSUInteger) (stack.count - val - 1)];
                    [stack addObject:chunk1];
                    break;
                }
                case OP_ROT: {
                    if ([stack count] < 3) {
                        DDLogWarn(@"[Script Error] Attempted OP_ROT on a stack with size < 3");
                        return NO;
                    }
                    NSData *chunk3 = stack.lastObject;
                    [stack removeLastObject];
                    NSData *chunk2 = stack.lastObject;
                    [stack removeLastObject];
                    NSData *chunk1 = stack.lastObject;
                    [stack removeLastObject];
                    [stack addObject:chunk2];
                    [stack addObject:chunk3];
                    [stack addObject:chunk1];
                    break;
                }
                case OP_SWAP:
                case OP_TUCK: {
                    if ([stack count] < 2) {
                        DDLogWarn(@"[Script Error] Attempted OP_SWAP on a stack with size < 2");
                        return NO;
                    }
                    NSData *chunk2 = stack.lastObject;
                    [stack removeLastObject];
                    NSData *chunk1 = stack.lastObject;
                    [stack removeLastObject];
                    [stack addObject:chunk2];
                    [stack addObject:chunk1];
                    if (opCode == OP_TUCK)
                        [stack addObject:chunk2];
                    break;
                }
                case OP_CAT:
                case OP_SUBSTR:
                case OP_LEFT:
                case OP_RIGHT: {
                    DDLogWarn(@"[Script Error] Attempted to use disabled Script Op.");
                    return NO;
                }
                case OP_SIZE: {
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_SIZE on an empty stack");
                        return NO;
                    }
                    [stack addObject:[BTScript castInt64ToData:((NSData *) stack.lastObject).length]];
                    break;
                }
                case OP_INVERT:
                case OP_AND:
                case OP_OR:
                case OP_XOR: {
                    DDLogWarn(@"[Script Error] Attempted to use disabled Script Op.");
                    return NO;
                }
                case OP_EQUAL: {
                    if ([stack count] < 2) {
                        DDLogWarn(@"[Script Error] Attempted OP_EQUALVERIFY on a stack with size < 2");
                        return NO;
                    }
                    NSData *chunk2 = stack.lastObject;
                    [stack removeLastObject];
                    NSData *chunk1 = stack.lastObject;
                    [stack removeLastObject];
                    if ([chunk1 isEqualToData:chunk2])
                        [stack addObject:[BTScript castInt64ToData:1]];
                    else
                        [stack addObject:[BTScript castInt64ToData:0]];
                    break;
                }
                case OP_EQUALVERIFY: {
                    if ([stack count] < 2) {
                        DDLogWarn(@"[Script Error] Attempted OP_EQUALVERIFY on a stack with size < 2");
                        return NO;
                    }
                    NSData *chunk2 = stack.lastObject;
                    [stack removeLastObject];
                    NSData *chunk1 = stack.lastObject;
                    [stack removeLastObject];
                    if (![chunk1 isEqualToData:chunk2]) {
                        DDLogWarn(@"[Script Error] OP_EQUALVERIFY: non-equal data");
                        return NO;
                    }
                    break;
                }
                case OP_1ADD:
                case OP_1SUB:
                case OP_NEGATE:
                case OP_ABS:
                case OP_NOT:
                case OP_0NOTEQUAL: {
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted a numeric op on an empty stack");
                        return NO;
                    }
                    if (![self checkCastToInt:stack.lastObject])
                        return NO;
                    long long numericOPnum = [BTScript castToInt64:stack.lastObject];
                    [stack removeLastObject];
                    switch (opCode) {
                        case OP_1ADD:
                            numericOPnum += 1;
                            break;
                        case OP_1SUB:
                            numericOPnum -= 1;
                            break;
                        case OP_NEGATE:
                            numericOPnum = -numericOPnum;
                            break;
                        case OP_ABS:
                            if (numericOPnum < 0)
                                numericOPnum = -numericOPnum;
                            break;
                        case OP_NOT:
                            if (numericOPnum == 0)
                                numericOPnum = 1;
                            else
                                numericOPnum = 0;
                            break;
                        case OP_0NOTEQUAL:
                            if (numericOPnum == 0)
                                numericOPnum = 0;
                            else
                                numericOPnum = 1;
                            break;
                        default: {
                            DDLogWarn(@"[Script Error] Unreachable");
                            return NO;
                        }
                    }
                    [stack addObject:[BTScript castInt64ToData:numericOPnum]];
                    break;
                }
                case OP_2MUL:
                case OP_2DIV: {
                    DDLogWarn(@"[Script Error] Attempted to use disabled Script Op.");
                    return NO;
                }
                case OP_ADD:
                case OP_SUB:
                case OP_BOOLAND:
                case OP_BOOLOR:
                case OP_NUMEQUAL:
                case OP_NUMNOTEQUAL:
                case OP_LESSTHAN:
                case OP_GREATERTHAN:
                case OP_LESSTHANOREQUAL:
                case OP_GREATERTHANOREQUAL:
                case OP_MIN:
                case OP_MAX: {
                    if ([stack count] < 2) {
                        DDLogWarn(@"[Script Error] Attempted a numeric op on a stack with size < 2");
                        return NO;
                    }
                    if (![self checkCastToInt:stack.lastObject])
                        return NO;
                    long long numericOPnum2 = [BTScript castToInt64:stack.lastObject];
                    [stack removeLastObject];
                    if (![self checkCastToInt:stack.lastObject])
                        return NO;
                    long long numericOPnum1 = [BTScript castToInt64:stack.lastObject];
                    [stack removeLastObject];

                    long long numericOPresult;
                    switch (opCode) {
                        case OP_ADD:
                            numericOPresult = numericOPnum1 + numericOPnum2;
                            break;
                        case OP_SUB:
                            numericOPresult = numericOPnum1 - numericOPnum2;
                            break;
                        case OP_BOOLAND:
                            if (!numericOPnum1 == 0 && !numericOPnum2 == 0)
                                numericOPresult = 1;
                            else
                                numericOPresult = 0;
                            break;
                        case OP_BOOLOR:
                            if (!numericOPnum1 == 0 || !numericOPnum2 == 0)
                                numericOPresult = 1;
                            else
                                numericOPresult = 0;
                            break;
                        case OP_NUMEQUAL:
                            if (numericOPnum1 == numericOPnum2)
                                numericOPresult = 1;
                            else
                                numericOPresult = 0;
                            break;
                        case OP_NUMNOTEQUAL:
                            if (numericOPnum1 != numericOPnum2)
                                numericOPresult = 1;
                            else
                                numericOPresult = 0;
                            break;
                        case OP_LESSTHAN:
                            if (numericOPnum1 < numericOPnum2)
                                numericOPresult = 1;
                            else
                                numericOPresult = 0;
                            break;
                        case OP_GREATERTHAN:
                            if (numericOPnum1 > numericOPnum2)
                                numericOPresult = 1;
                            else
                                numericOPresult = 0;
                            break;
                        case OP_LESSTHANOREQUAL:
                            if (numericOPnum1 <= numericOPnum2)
                                numericOPresult = 1;
                            else
                                numericOPresult = 0;
                            break;
                        case OP_GREATERTHANOREQUAL:
                            if (numericOPnum1 >= numericOPnum2)
                                numericOPresult = 1;
                            else
                                numericOPresult = 0;
                            break;
                        case OP_MIN:
                            if (numericOPnum1 < numericOPnum2)
                                numericOPresult = numericOPnum1;
                            else
                                numericOPresult = numericOPnum2;
                            break;
                        case OP_MAX:
                            if (numericOPnum1 > numericOPnum2)
                                numericOPresult = numericOPnum1;
                            else
                                numericOPresult = numericOPnum2;
                            break;
                        default: {
                            DDLogWarn(@"[Script Error] Opcode switched at runtime?");
                            return NO;
                        }
                    }
                    [stack addObject:[BTScript castInt64ToData:numericOPresult]];
                    break;
                }
                case OP_MUL:
                case OP_DIV:
                case OP_MOD:
                case OP_LSHIFT:
                case OP_RSHIFT: {
                    DDLogWarn(@"[Script Error] Attempted to use disabled Script Op.");
                    return NO;
                }
                case OP_NUMEQUALVERIFY: {
                    if ([stack count] < 2) {
                        DDLogWarn(@"[Script Error] Attempted OP_NUMEQUALVERIFY on a stack with size < 2");
                        return NO;
                    }

                    if (![self checkCastToInt:stack.lastObject])
                        return NO;
                    long long OPNUMEQUALVERIFYnum2 = [BTScript castToInt64:stack.lastObject];
                    [stack removeLastObject];
                    if (![self checkCastToInt:stack.lastObject])
                        return NO;
                    long long OPNUMEQUALVERIFYnum1 = [BTScript castToInt64:stack.lastObject];
                    [stack removeLastObject];

                    if (!OPNUMEQUALVERIFYnum1 == OPNUMEQUALVERIFYnum2) {
                        DDLogWarn(@"[Script Error] OP_NUMEQUALVERIFY failed");
                        return NO;
                    }

                    break;
                }
                case OP_WITHIN:
                    if ([stack count] < 3) {
                        DDLogWarn(@"[Script Error] Attempted OP_WITHIN on a stack with size < 3");
                        return NO;
                    }
                    if (![self checkCastToInt:stack.lastObject])
                        return NO;
                    long long OPWITHINnum3 = [BTScript castToInt64:stack.lastObject];
                    [stack removeLastObject];
                    if (![self checkCastToInt:stack.lastObject])
                        return NO;
                    long long OPWITHINnum2 = [BTScript castToInt64:stack.lastObject];
                    [stack removeLastObject];
                    if (![self checkCastToInt:stack.lastObject])
                        return NO;
                    long long OPWITHINnum1 = [BTScript castToInt64:stack.lastObject];
                    [stack removeLastObject];
                    if (OPWITHINnum2 <= OPWITHINnum1 && OPWITHINnum1 < OPWITHINnum3)
                        [stack addObject:[BTScript castInt64ToData:1]];
                    else
                        [stack addObject:[BTScript castInt64ToData:0]];
                    break;
                case OP_RIPEMD160: {
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_RIPEMD160 on an empty stack");
                        return NO;
                    }
                    NSData *chunk1 = stack.lastObject;
                    [stack removeLastObject];
                    [stack addObject:chunk1.RMD160];
                    break;
                }
                case OP_SHA1: {
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_SHA1 on an empty stack");
                        return NO;
                    }
                    NSData *chunk1 = stack.lastObject;
                    [stack removeLastObject];
                    [stack addObject:chunk1.SHA1];
                    break;
                }
                case OP_SHA256: {
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_SHA256 on an empty stack");
                        return NO;
                    }
                    NSData *chunk1 = stack.lastObject;
                    [stack removeLastObject];
                    [stack addObject:chunk1.SHA256];
                    break;
                }
                case OP_HASH160: {
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_HASH160 on an empty stack");
                        return NO;
                    }
                    NSData *chunk1 = stack.lastObject;
                    [stack removeLastObject];
                    [stack addObject:chunk1.hash160];
                    break;
                }
                case OP_HASH256: {
                    if ([stack count] < 1) {
                        DDLogWarn(@"[Script Error] Attempted OP_SHA256 on an empty stack");
                        return NO;
                    }
                    NSData *chunk1 = stack.lastObject;
                    [stack removeLastObject];
                    [stack addObject:chunk1.SHA256_2];
                    break;
                }
                case OP_CODESEPARATOR:
                    lastCodeSepLocation = chunk.startLocationInProgram + 1;
                    break;
                case OP_CHECKSIG:
                case OP_CHECKSIGVERIFY: {
                    if (![self executeCheckSig:stack opCode:opCode script:script lastCodeSepLocation:lastCodeSepLocation])
                        return NO;
                    break;
                }
                case OP_CHECKMULTISIG:
                case OP_CHECKMULTISIGVERIFY: {
                    long long pubKeyCount = 0;
                    if (stack.count > 1)
                        pubKeyCount = [BTScript castToInt64:stack.lastObject];
                    if (![self executeMultiSig:stack opCode:opCode opCount:opCount script:script lastCodeSepLocation:lastCodeSepLocation])
                        return NO;
                    opCount += pubKeyCount;
                    break;
                }
                case OP_NOP1:
                case OP_NOP2:
                case OP_NOP3:
                case OP_NOP4:
                case OP_NOP5:
                case OP_NOP6:
                case OP_NOP7:
                case OP_NOP8:
                case OP_NOP9:
                case OP_NOP10:
                    break;
                default: {
                    DDLogWarn(@"[Script Error] Script used a reserved opcode %d", opCode);
                    return NO;
                }
            }

            if ([stack count] + [altStack count] > 1000) {
                DDLogWarn(@"[Script Error] Stack size exceeded range");
                return NO;
            }
        }
    }
    if (![ifStack count] == 0) {
        DDLogWarn(@"[Script Error] OP_IF/OP_NOTIF without OP_ENDIF");
        return NO;
    }

    return YES;
}

- (BOOL)executeCheckSig:(NSMutableArray *)stack opCode:(int)opCode script:(BTScript *)script
    lastCodeSepLocation:(int)lastCodeSepLocation; {
    if ([stack count] < 2) {
        DDLogWarn(@"[Script Error] Attempted OP_CHECKSIG(VERIFY) on a stack with size < 2");
        return NO;
    }
    NSData *pubKey = stack.lastObject;
    [stack removeLastObject];
    NSData *sigBytes = stack.lastObject;
    [stack removeLastObject];

    NSData *prog = script.program;
    NSData *connectedScript = [[NSData dataWithData:prog] subdataWithRange:NSMakeRange((NSUInteger)
            lastCodeSepLocation, prog.length)];

    NSMutableData *out = [NSMutableData secureData];
    [out appendScriptPushData:sigBytes];

    connectedScript = [BTScript removeAllInstancesOf:connectedScript and:out];

    BOOL sigValid = NO;

    BTKey *key = [BTKey keyWithPublicKey:pubKey];
    if (sigBytes.length > 0) {
        NSData *hash;
        if (self.tx.coin != BTC) {
            BTIn *btIn = self.tx.ins[self.index];
            if (self.tx.isDetectBcc) {
                u_int64_t preOutValues[] = {};
                for (int idx = 0; idx<self.tx.outs.count; idx ++) {
                    preOutValues[idx] = [self.tx.outs[idx]outValue];
                }
                hash = [self.tx hashForSignatureWitness:self.index connectedScript:connectedScript type:[self.tx getSigHashType] prevValue:preOutValues[self.index] anyoneCanPay:false coin:self.tx.coin];
            }else if(self.tx.coin == SBTC) {
                hash = [self.tx sbtcHashForSignature:self.index connectedScript:connectedScript
                                         sigHashType:[sigBytes UInt8AtOffset:sigBytes.length - 1]];
            }else if(self.tx.coin == BCD) {
                hash = [self.tx bcdHashForSignature:self.index connectedScript:connectedScript
                                        sigHashType:[sigBytes UInt8AtOffset:sigBytes.length - 1]];
            } else {
                BTOut *btOut = [[BTTxProvider instance] getOutByTxHash:btIn.prevTxHash andOutSn:btIn.prevOutSn];
                hash = [self.tx hashForSignatureWitness:self.index connectedScript:connectedScript type:[self.tx getSigHashType] prevValue:btOut.outValue anyoneCanPay:false coin:self.tx.coin];
            }
        } else {
            hash = [self.tx hashForSignature:self.index connectedScript:connectedScript
                                 sigHashType:[sigBytes UInt8AtOffset:sigBytes.length - 1]];
        }
        sigValid = [key verify:hash signature:sigBytes];
    }

    if (opCode == OP_CHECKSIG) {
        NSMutableData *data = [NSMutableData secureData];
        if (sigValid) {
            [data appendUInt8:1];
        } else {
            [data appendUInt8:0];
        }
        [stack addObject:data];
    } else if (opCode == OP_CHECKSIGVERIFY) {
        if (!sigValid) {
            DDLogWarn(@"[Script Error] Script failed OP_CHECKSIGVERIFY");
            return NO;
        }
    }
    return YES;
}

- (BOOL)executeMultiSig:(NSMutableArray *)stack opCode:(int)opCode opCount:(int)opCount script:(BTScript *)script
    lastCodeSepLocation:(int)lastCodeSepLocation; {
    if ([stack count] < 2) {
        DDLogWarn(@"[Script Error] Attempted OP_CHECKMULTISIG(VERIFY) on a stack with size < 2");
        return NO;
    }
    if (![self checkCastToInt:stack.lastObject])
        return NO;
    long long pubKeyCount = [BTScript castToInt64:stack.lastObject];
    [stack removeLastObject];
    if (pubKeyCount < 0 || pubKeyCount > 20) {
        DDLogWarn(@"[Script Error] OP_CHECKMULTISIG(VERIFY) with pubkey count out of range");
        return NO;
    }
    opCount += pubKeyCount;
    if (opCount > 201) {
        DDLogWarn(@"[Script Error] Total op count > 201 during OP_CHECKMULTISIG(VERIFY)");
        return NO;
    }
    if ([stack count] < pubKeyCount + 1) {
        DDLogWarn(@"[Script Error] Attempted OP_CHECKMULTISIG(VERIFY) on a stack with size < num_of_pubkeys + 2");
        return NO;
    }

    NSMutableArray *pubkeys = [NSMutableArray new];
    for (int i = 0; i < pubKeyCount; i++) {
        NSData *pubKey = stack.lastObject;
        [stack removeLastObject];
        [pubkeys addObject:pubKey];
    }

    if (![self checkCastToInt:stack.lastObject])
        return NO;
    long long sigCount = [BTScript castToInt64:stack.lastObject];
    [stack removeLastObject];
    if (sigCount < 0 || sigCount > pubKeyCount) {
        DDLogWarn(@"[Script Error] OP_CHECKMULTISIG(VERIFY) with sig count out of range");
        return NO;
    }
    if ([stack count] < sigCount + 1) {
        DDLogWarn(@"[Script Error] Attempted OP_CHECKMULTISIG(VERIFY) on a stack with size < num_of_pubkeys + num_of_signatures + 3");
        return NO;
    }

    NSMutableArray *sigs = [NSMutableArray new];
    for (int i = 0; i < sigCount; i++) {
        NSData *sig = stack.lastObject;
        [stack removeLastObject];
        [sigs addObject:sig];
    }

    NSData *prog = script.program;
    NSData *connectedScript = [[NSData dataWithData:prog] subdataWithRange:NSMakeRange((NSUInteger) lastCodeSepLocation, prog.length)];

    for (NSData *sig in sigs) {
        NSMutableData *out = [NSMutableData secureData];
        [out appendScriptPushData:sig];

        connectedScript = [BTScript removeAllInstancesOf:connectedScript and:out];
    }

    BOOL valid = YES;
    while ([sigs count] > 0) {
        NSData *pubKey = pubkeys.firstObject;
        [pubkeys removeObjectAtIndex:0];

        BTKey *key = [BTKey keyWithPublicKey:pubKey];
        NSData *sig = sigs.firstObject;
        if (sig.length > 0) {
            NSData *hash;
            if(self.tx.coin == SBTC) {
                hash = [self.tx sbtcHashForSignature:self.index connectedScript:connectedScript
                                         sigHashType:[sig UInt8AtOffset:sig.length - 1]];
            }else  if (self.tx.coin != BTC) {
                BTIn *btIn = self.tx.ins[self.index];
                BTOut *btOut = [[BTTxProvider instance] getOutByTxHash:btIn.prevTxHash andOutSn:btIn.prevOutSn];
                hash = [self.tx hashForSignatureWitness:self.index connectedScript:script.program type:[self.tx getSigHashType] prevValue:btOut.outValue anyoneCanPay:false coin:self.tx.coin];
            } else {
                hash = [self.tx hashForSignature:self.index connectedScript:script.program
                                     sigHashType:[sig UInt8AtOffset:sig.length - 1]];
            }
            if ([key verify:hash signature:sig])
                [sigs removeObjectAtIndex:0];
        }
        if ([sigs count] > [pubkeys count]) {
            valid = NO;
            break;
        }
    }

    // We uselessly remove a stack object to emulate a reference client bug.
    [stack removeLastObject];

    if (opCode == OP_CHECKMULTISIG) {
        NSMutableData *data = [NSMutableData secureData];
        if (valid) {
            [data appendUInt8:1];
        } else {
            [data appendUInt8:0];
        }
        [stack addObject:data];
    } else if (opCode == OP_CHECKMULTISIGVERIFY) {
        if (!valid) {
            DDLogWarn(@"[Script Error] Script failed OP_CHECKMULTISIGVERIFY");
            return NO;
        }
    }
    return YES;
}

+ (NSData *)removeAllInstancesOf:(NSData *)inputScript and:(NSData *)chunkToRemove; {
    // We usually don't end up removing anything
    NSMutableData *bos = [NSMutableData secureData];
    NSUInteger cursor = 0;
    while (cursor < inputScript.length) {
        BOOL skip = [chunkToRemove isEqualToData:[inputScript subdataWithRange:NSMakeRange(cursor, inputScript.length - cursor)]];

        uint8_t opcode = (uint8_t) ([inputScript UInt8AtOffset:cursor++] & 0xFF);
        int additionalBytes = 0;
        if (opcode >= 0 && opcode < OP_PUSHDATA1) {
            additionalBytes = opcode;
        } else if (opcode == OP_PUSHDATA1) {
            additionalBytes = (0xFF & [inputScript UInt8AtOffset:cursor]) + 1;
        } else if (opcode == OP_PUSHDATA2) {
            additionalBytes = ((0xFF & [inputScript UInt8AtOffset:cursor]) |
                    ((0xFF & [inputScript UInt8AtOffset:cursor + 1]) << 8)) + 2;
        } else if (opcode == OP_PUSHDATA4) {
            additionalBytes = ((0xFF & [inputScript UInt8AtOffset:cursor]) |
                    ((0xFF & [inputScript UInt8AtOffset:cursor + 1]) << 8) |
                    ((0xFF & [inputScript UInt8AtOffset:cursor + 2]) << 16) |
                    ((0xFF & [inputScript UInt8AtOffset:cursor + 3]) << 24)) + 4;
        }
        if (!skip) {
            [bos appendUInt8:opcode];
            [bos appendData:[inputScript subdataWithRange:NSMakeRange(cursor, (NSUInteger) additionalBytes)]];
        }
        cursor += additionalBytes;
    }
    return bos;
}

+ (uint8_t)encodeToOpN:(long long)value; {
//    checkArgument(value >= -1 && value <= 16, "encodeToOpN called for " + value + " which we cannot encode in an opcode.");
    if (value == 0)
        return OP_0;
    else if (value == -1)
        return OP_1NEGATE;
    else
        return (uint8_t) (value - 1 + OP_1);
}

+ (long long)decodeFromOpN:(uint8_t)opCode; {
    if (opCode == OP_0)
        return 0;
    else if (opCode == OP_1NEGATE)
        return -1;
    else
        return opCode + 1 - OP_1;
}

+ (long long)castToInt64:(NSData *)data; {
//    if ([data length] > 4) {
//        DDLogWarn(@"[Script Error] Script attempted to use an integer larger than 4 bytes");
//    }
    data = [data reverse];
    if ([data length] == 0)
        return 0;
    BOOL isNegative = (*((const uint8_t *) data.bytes) & 0x80) == 0x80;
    BOOL isFirstEmpty = *((const uint8_t *) data.bytes) == 0x00 || *((const uint8_t *) data.bytes) == 0x80;
    if (isFirstEmpty) {
        NSMutableData *data2 = [NSMutableData dataWithData:data];
        data2 = [NSMutableData dataWithData:[data2 subdataWithRange:NSMakeRange(1, data2.length - 1)]];
        data = data2;
    } else {
        if (isNegative) {
            NSMutableData *data2 = [NSMutableData dataWithData:data];
            uint8_t i = (uint8_t) (*((const uint8_t *) data.bytes) & 0x7f);
            [data2 replaceBytesInRange:NSMakeRange(0, 1) withBytes:&i];
            data = data2;
        }
    }
    data = [data reverse];
    long long result = 0;
    if (data.length == 1)
        result = [data UInt8AtOffset:0];
    else if (data.length == 2)
        result = [data UInt16AtOffset:0];
    else if (data.length == 3) {
        NSMutableData *tmp = [NSMutableData dataWithData:data];
        [tmp appendUInt8:0];
        result = [tmp UInt32AtOffset:0];
    }
    else if (data.length == 4)
        result = [data UInt32AtOffset:0];
    else if (data.length == 8)
        result = [data UInt64AtOffset:0];
    return isNegative ? -result : result;
}

- (BOOL)checkCastToInt:(NSData *)data; {
    if ([data length] > 4) {
        DDLogWarn(@"[Script Error] Script attempted to use an integer larger than 4 bytes");
        return NO;
    }
    return YES;
}

+ (NSData *)castInt64ToData:(long long)val; {
    NSMutableData *data = [NSMutableData secureData];
    if (val == 0)
        return data;
    BOOL isNegative = (val < 0);
    uint64_t v;
    if (isNegative && val > INT32_MIN) {
        v = (uint64_t) -val;
    } else if (isNegative && val <= INT32_MIN) {
        v = ((uint64_t) -(val + INT32_MAX)) + INT32_MAX;
    } else {
        v = (uint64_t) val;
    }

    if (v <= UINT8_MAX) {
        [data appendUInt8:(uint8_t) v];
    } else if (v <= UINT16_MAX) {
        [data appendUInt16:(uint16_t) v];
    } else if (v <= UINT24_MAX) {
        [data appendUInt32:(uint32_t) v];
        data = [[data subdataWithRange:NSMakeRange(0, data.length - 1)] mutableCopy];
    } else if (v <= UINT32_MAX) {
        [data appendUInt32:(uint32_t) v];
    } else if (v <= UINT64_MAX) {
        [data appendUInt64:(uint64_t) v];
    }
    data = [NSMutableData dataWithData:[data reverse]];
    if ((*((const uint8_t *) data.bytes) & 0x80) == 0x80) {
        NSMutableData *data2 = [NSMutableData secureData];
        if (isNegative)
            [data2 appendUInt8:0x80];
        else
            [data2 appendUInt8:0x00];
        [data2 appendData:data];
        data = data2;
    } else {
        if (isNegative) {
            uint8_t tmp = *((const uint8_t *) data.bytes);
            tmp |= 0x80;
            [data replaceBytesInRange:NSMakeRange(0, 1) withBytes:&tmp];
        }
    }
    return [data reverse];
}

+ (BOOL)castToBool:(NSData *)data; {
    for (NSUInteger i = 0; i < data.length; i++) {
        uint8_t val = *((const uint8_t *) data.bytes + i);
        if (val != 0)
            return !(i == data.length - 1 && (val & 0xFF) == 0x80);
    }
    return NO;
}

@end
