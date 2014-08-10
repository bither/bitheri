//
//  BTScriptOpCodes.h
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

#import <Foundation/Foundation.h>

// push value
const static int OP_0 = 0x00;
const static int OP_FALSE = OP_0;
const static int OP_PUSHDATA1 = 0x4c;
const static int OP_PUSHDATA2 = 0x4d;
const static int OP_PUSHDATA4 = 0x4e;
const static int OP_1NEGATE = 0x4f;
const static int OP_RESERVED = 0x50;
const static int OP_1 = 0x51;
const static int OP_TRUE = OP_1;
const static int OP_2 = 0x52;
const static int OP_3 = 0x53;
const static int OP_4 = 0x54;
const static int OP_5 = 0x55;
const static int OP_6 = 0x56;
const static int OP_7 = 0x57;
const static int OP_8 = 0x58;
const static int OP_9 = 0x59;
const static int OP_10 = 0x5a;
const static int OP_11 = 0x5b;
const static int OP_12 = 0x5c;
const static int OP_13 = 0x5d;
const static int OP_14 = 0x5e;
const static int OP_15 = 0x5f;
const static int OP_16 = 0x60;

// control
const static int OP_NOP = 0x61;
const static int OP_VER = 0x62;
const static int OP_IF = 0x63;
const static int OP_NOTIF = 0x64;
const static int OP_VERIF = 0x65;
const static int OP_VERNOTIF = 0x66;
const static int OP_ELSE = 0x67;
const static int OP_ENDIF = 0x68;
const static int OP_VERIFY = 0x69;
const static int OP_RETURN = 0x6a;

// stack ops
const static int OP_TOALTSTACK = 0x6b;
const static int OP_FROMALTSTACK = 0x6c;
const static int OP_2DROP = 0x6d;
const static int OP_2DUP = 0x6e;
const static int OP_3DUP = 0x6f;
const static int OP_2OVER = 0x70;
const static int OP_2ROT = 0x71;
const static int OP_2SWAP = 0x72;
const static int OP_IFDUP = 0x73;
const static int OP_DEPTH = 0x74;
const static int OP_DROP = 0x75;
const static int OP_DUP = 0x76;
const static int OP_NIP = 0x77;
const static int OP_OVER = 0x78;
const static int OP_PICK = 0x79;
const static int OP_ROLL = 0x7a;
const static int OP_ROT = 0x7b;
const static int OP_SWAP = 0x7c;
const static int OP_TUCK = 0x7d;

// splice ops
const static int OP_CAT = 0x7e;
const static int OP_SUBSTR = 0x7f;
const static int OP_LEFT = 0x80;
const static int OP_RIGHT = 0x81;
const static int OP_SIZE = 0x82;

// bit logic
const static int OP_INVERT = 0x83;
const static int OP_AND = 0x84;
const static int OP_OR = 0x85;
const static int OP_XOR = 0x86;
const static int OP_EQUAL = 0x87;
const static int OP_EQUALVERIFY = 0x88;
const static int OP_RESERVED1 = 0x89;
const static int OP_RESERVED2 = 0x8a;

// numeric
const static int OP_1ADD = 0x8b;
const static int OP_1SUB = 0x8c;
const static int OP_2MUL = 0x8d;
const static int OP_2DIV = 0x8e;
const static int OP_NEGATE = 0x8f;
const static int OP_ABS = 0x90;
const static int OP_NOT = 0x91;
const static int OP_0NOTEQUAL = 0x92;
const static int OP_ADD = 0x93;
const static int OP_SUB = 0x94;
const static int OP_MUL = 0x95;
const static int OP_DIV = 0x96;
const static int OP_MOD = 0x97;
const static int OP_LSHIFT = 0x98;
const static int OP_RSHIFT = 0x99;
const static int OP_BOOLAND = 0x9a;
const static int OP_BOOLOR = 0x9b;
const static int OP_NUMEQUAL = 0x9c;
const static int OP_NUMEQUALVERIFY = 0x9d;
const static int OP_NUMNOTEQUAL = 0x9e;
const static int OP_LESSTHAN = 0x9f;
const static int OP_GREATERTHAN = 0xa0;
const static int OP_LESSTHANOREQUAL = 0xa1;
const static int OP_GREATERTHANOREQUAL = 0xa2;
const static int OP_MIN = 0xa3;
const static int OP_MAX = 0xa4;
const static int OP_WITHIN = 0xa5;

// crypto
const static int OP_RIPEMD160 = 0xa6;
const static int OP_SHA1 = 0xa7;
const static int OP_SHA256 = 0xa8;
const static int OP_HASH160 = 0xa9;
const static int OP_HASH256 = 0xaa;
const static int OP_CODESEPARATOR = 0xab;
const static int OP_CHECKSIG = 0xac;
const static int OP_CHECKSIGVERIFY = 0xad;
const static int OP_CHECKMULTISIG = 0xae;
const static int OP_CHECKMULTISIGVERIFY = 0xaf;

// expansion
const static int OP_NOP1 = 0xb0;
const static int OP_NOP2 = 0xb1;
const static int OP_NOP3 = 0xb2;
const static int OP_NOP4 = 0xb3;
const static int OP_NOP5 = 0xb4;
const static int OP_NOP6 = 0xb5;
const static int OP_NOP7 = 0xb6;
const static int OP_NOP8 = 0xb7;
const static int OP_NOP9 = 0xb8;
const static int OP_NOP10 = 0xb9;
const static int OP_INVALIDOPCODE = 0xff;

@interface BTScriptOpCodes : NSObject

+ (instancetype)instance;

+ (NSString *)getOpCodeName:(int)opCode;

+ (NSString *)getPushDataName:(int)opCode;

+ (int)getOpCode:(NSString *)opCodeName;

@end