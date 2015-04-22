//
//  BTScriptChunk.m
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

#import "BTScriptChunk.h"
#import "BTScriptOpCodes.h"
#import "NSMutableData+Bitcoin.h"
#import "NSString+Base58.h"

@interface BTScriptChunk ()

@end

@implementation BTScriptChunk {
    int _startLocationInProgram;
}

- (instancetype)initWithOpCode:(int)opCode andData:(NSData *)data; {
    if (!(self = [super init])) return nil;
    _opCode = opCode;
    _data = data;
    _startLocationInProgram = -1;
    return self;
}

- (instancetype)initWithOpCode:(int)opCode andData:(NSData *)data andStartLocationInProgram:(int)startLocationInProgram; {
    if (!(self = [super init])) return nil;
    _opCode = opCode;
    _data = data;
    _startLocationInProgram = startLocationInProgram;
    return self;
}

- (BOOL)isEqualOpCode:(int)opCode; {
    return opCode == self.opCode;
}

- (BOOL)isOpCode; {
    return self.opCode > OP_PUSHDATA4;
}

- (BOOL)isPushData; {
    return self.opCode <= OP_16;
}

- (int)startLocationInProgram; {
    return _startLocationInProgram;
}

- (BOOL)isShortestPossiblePushData; {

    if (self.data.length == 0)
        return self.opCode == OP_0;
    if (self.data.length == 1) {
        int b = *((const uint8_t *) self.data.bytes);
        if (b >= 0x01 && b <= 0x10)
            return self.opCode == OP_1 + b - 1;
        if (b == 0x81)
            return self.opCode == OP_1NEGATE;
    }
    if (self.data.length < OP_PUSHDATA1)
        return self.opCode == self.data.length;
    if (self.data.length < 256)
        return self.opCode == OP_PUSHDATA1;
    if (self.data.length < 65536)
        return self.opCode == OP_PUSHDATA2;

    // can never be used, but implemented for completeness
    return self.opCode == OP_PUSHDATA4;
}

- (NSData *)toData; {
    NSMutableData *result = [NSMutableData secureData];
    if ([self isOpCode]) {
        [result appendUInt8:(uint8_t) self.opCode];
    } else if (self.data != nil) {
        if (self.opCode < OP_PUSHDATA1) {
            [result appendUInt8:(uint8_t) self.opCode];
        } else if (self.opCode == OP_PUSHDATA1) {
            [result appendUInt8:(uint8_t) self.opCode];
            [result appendVarInt:self.data.length];
        } else if (self.opCode == OP_PUSHDATA2) {
            [result appendUInt8:(uint8_t) self.opCode];
            [result appendVarInt:self.data.length];
        } else if (self.opCode == OP_PUSHDATA4) {
            [result appendUInt8:(uint8_t) self.opCode];
            [result appendVarInt:self.data.length];
        }
        [result appendData:self.data];

    } else {
        [result appendUInt8:(uint8_t) self.opCode];
    }
    return result;
}

- (NSString *)description; {
    NSMutableString *result = [NSMutableString new];
    if ([self isOpCode]) {
        [result appendString:[BTScriptOpCodes getOpCodeName:self.opCode]];
    } else if (self.data != nil) {
        [result appendString:[BTScriptOpCodes getPushDataName:self.opCode]];
        [result appendString:@"["];
        [result appendString:[NSString hexWithData:self.data]];
        [result appendString:@"]"];
    } else {
        // Small num
//        buf.append(Script.decodeFromOpN(opcode));
//        [result appendString:<#(NSString *)aString#>];
    }
    return result;
}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[BTScriptChunk class]]) {
        return NO;
    }
    BTScriptChunk *scriptChunk = (BTScriptChunk *) object;
    if (self.opCode != scriptChunk.opCode) return NO;
    if (_startLocationInProgram != scriptChunk.startLocationInProgram) return NO;
    return [self.data isEqualToData:scriptChunk.data];
}

- (NSUInteger)hash {
    int result = self.opCode;
    result = 31 * result + (self.data != nil ? (int) [self.data hash] : 0);
    result = 31 * result + _startLocationInProgram;
    return (NSUInteger) result;
}

@end