//
//  BTScriptOpCodes.m
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

#import "BTScriptOpCodes.h"

@interface BTScriptOpCodes ()

@property(nonatomic, strong) NSMutableDictionary *opCodeDict;
@property(nonatomic, strong) NSMutableDictionary *opCodeNameDict;
@end

@implementation BTScriptOpCodes {

}

- (instancetype)init {
    if (!(self = [super init])) return nil;

    _opCodeDict = [NSMutableDictionary new];
    self.opCodeDict[@(OP_0)] = @"0";
    self.opCodeDict[@(OP_PUSHDATA1)] = @"PUSHDATA1";
    self.opCodeDict[@(OP_PUSHDATA2)] = @"PUSHDATA2";
    self.opCodeDict[@(OP_PUSHDATA4)] = @"PUSHDATA4";
    self.opCodeDict[@(OP_1NEGATE)] = @"1NEGATE";
    self.opCodeDict[@(OP_RESERVED)] = @"RESERVED";
    self.opCodeDict[@(OP_1)] = @"1";
    self.opCodeDict[@(OP_2)] = @"2";
    self.opCodeDict[@(OP_3)] = @"3";
    self.opCodeDict[@(OP_4)] = @"4";
    self.opCodeDict[@(OP_5)] = @"5";
    self.opCodeDict[@(OP_6)] = @"6";
    self.opCodeDict[@(OP_7)] = @"7";
    self.opCodeDict[@(OP_8)] = @"8";
    self.opCodeDict[@(OP_9)] = @"9";
    self.opCodeDict[@(OP_10)] = @"10";
    self.opCodeDict[@(OP_11)] = @"11";
    self.opCodeDict[@(OP_12)] = @"12";
    self.opCodeDict[@(OP_13)] = @"13";
    self.opCodeDict[@(OP_14)] = @"14";
    self.opCodeDict[@(OP_15)] = @"15";
    self.opCodeDict[@(OP_16)] = @"16";
    self.opCodeDict[@(OP_NOP)] = @"NOP";
    self.opCodeDict[@(OP_VER)] = @"VER";
    self.opCodeDict[@(OP_IF)] = @"IF";
    self.opCodeDict[@(OP_NOTIF)] = @"NOTIF";
    self.opCodeDict[@(OP_VERIF)] = @"VERIF";
    self.opCodeDict[@(OP_VERNOTIF)] = @"VERNOTIF";
    self.opCodeDict[@(OP_ELSE)] = @"ELSE";
    self.opCodeDict[@(OP_ENDIF)] = @"ENDIF";
    self.opCodeDict[@(OP_VERIFY)] = @"VERIFY";
    self.opCodeDict[@(OP_RETURN)] = @"RETURN";
    self.opCodeDict[@(OP_TOALTSTACK)] = @"TOALTSTACK";
    self.opCodeDict[@(OP_FROMALTSTACK)] = @"FROMALTSTACK";
    self.opCodeDict[@(OP_2DROP)] = @"2DROP";
    self.opCodeDict[@(OP_2DUP)] = @"2DUP";
    self.opCodeDict[@(OP_3DUP)] = @"3DUP";
    self.opCodeDict[@(OP_2OVER)] = @"2OVER";
    self.opCodeDict[@(OP_2ROT)] = @"2ROT";
    self.opCodeDict[@(OP_2SWAP)] = @"2SWAP";
    self.opCodeDict[@(OP_IFDUP)] = @"IFDUP";
    self.opCodeDict[@(OP_DEPTH)] = @"DEPTH";
    self.opCodeDict[@(OP_DROP)] = @"DROP";
    self.opCodeDict[@(OP_DUP)] = @"DUP";
    self.opCodeDict[@(OP_NIP)] = @"NIP";
    self.opCodeDict[@(OP_OVER)] = @"OVER";
    self.opCodeDict[@(OP_PICK)] = @"PICK";
    self.opCodeDict[@(OP_ROLL)] = @"ROLL";
    self.opCodeDict[@(OP_ROT)] = @"ROT";
    self.opCodeDict[@(OP_SWAP)] = @"SWAP";
    self.opCodeDict[@(OP_TUCK)] = @"TUCK";
    self.opCodeDict[@(OP_CAT)] = @"CAT";
    self.opCodeDict[@(OP_SUBSTR)] = @"SUBSTR";
    self.opCodeDict[@(OP_LEFT)] = @"LEFT";
    self.opCodeDict[@(OP_RIGHT)] = @"RIGHT";
    self.opCodeDict[@(OP_SIZE)] = @"SIZE";
    self.opCodeDict[@(OP_INVERT)] = @"INVERT";
    self.opCodeDict[@(OP_AND)] = @"AND";
    self.opCodeDict[@(OP_OR)] = @"OR";
    self.opCodeDict[@(OP_XOR)] = @"XOR";
    self.opCodeDict[@(OP_EQUAL)] = @"EQUAL";
    self.opCodeDict[@(OP_EQUALVERIFY)] = @"EQUALVERIFY";
    self.opCodeDict[@(OP_RESERVED1)] = @"RESERVED1";
    self.opCodeDict[@(OP_RESERVED2)] = @"RESERVED2";
    self.opCodeDict[@(OP_1ADD)] = @"1ADD";
    self.opCodeDict[@(OP_1SUB)] = @"1SUB";
    self.opCodeDict[@(OP_2MUL)] = @"2MUL";
    self.opCodeDict[@(OP_2DIV)] = @"2DIV";
    self.opCodeDict[@(OP_NEGATE)] = @"NEGATE";
    self.opCodeDict[@(OP_ABS)] = @"ABS";
    self.opCodeDict[@(OP_NOT)] = @"NOT";
    self.opCodeDict[@(OP_0NOTEQUAL)] = @"0NOTEQUAL";
    self.opCodeDict[@(OP_ADD)] = @"ADD";
    self.opCodeDict[@(OP_SUB)] = @"SUB";
    self.opCodeDict[@(OP_MUL)] = @"MUL";
    self.opCodeDict[@(OP_DIV)] = @"DIV";
    self.opCodeDict[@(OP_MOD)] = @"MOD";
    self.opCodeDict[@(OP_LSHIFT)] = @"LSHIFT";
    self.opCodeDict[@(OP_RSHIFT)] = @"RSHIFT";
    self.opCodeDict[@(OP_BOOLAND)] = @"BOOLAND";
    self.opCodeDict[@(OP_BOOLOR)] = @"BOOLOR";
    self.opCodeDict[@(OP_NUMEQUAL)] = @"NUMEQUAL";
    self.opCodeDict[@(OP_NUMEQUALVERIFY)] = @"NUMEQUALVERIFY";
    self.opCodeDict[@(OP_NUMNOTEQUAL)] = @"NUMNOTEQUAL";
    self.opCodeDict[@(OP_LESSTHAN)] = @"LESSTHAN";
    self.opCodeDict[@(OP_GREATERTHAN)] = @"GREATERTHAN";
    self.opCodeDict[@(OP_LESSTHANOREQUAL)] = @"LESSTHANOREQUAL";
    self.opCodeDict[@(OP_GREATERTHANOREQUAL)] = @"GREATERTHANOREQUAL";
    self.opCodeDict[@(OP_MIN)] = @"MIN";
    self.opCodeDict[@(OP_MAX)] = @"MAX";
    self.opCodeDict[@(OP_WITHIN)] = @"WITHIN";
    self.opCodeDict[@(OP_RIPEMD160)] = @"RIPEMD160";
    self.opCodeDict[@(OP_SHA1)] = @"SHA1";
    self.opCodeDict[@(OP_SHA256)] = @"SHA256";
    self.opCodeDict[@(OP_HASH160)] = @"HASH160";
    self.opCodeDict[@(OP_HASH256)] = @"HASH256";
    self.opCodeDict[@(OP_CODESEPARATOR)] = @"CODESEPARATOR";
    self.opCodeDict[@(OP_CHECKSIG)] = @"CHECKSIG";
    self.opCodeDict[@(OP_CHECKSIGVERIFY)] = @"CHECKSIGVERIFY";
    self.opCodeDict[@(OP_CHECKMULTISIG)] = @"CHECKMULTISIG";
    self.opCodeDict[@(OP_CHECKMULTISIGVERIFY)] = @"CHECKMULTISIGVERIFY";
    self.opCodeDict[@(OP_NOP1)] = @"NOP1";
    self.opCodeDict[@(OP_NOP2)] = @"NOP2";
    self.opCodeDict[@(OP_NOP3)] = @"NOP3";
    self.opCodeDict[@(OP_NOP4)] = @"NOP4";
    self.opCodeDict[@(OP_NOP5)] = @"NOP5";
    self.opCodeDict[@(OP_NOP6)] = @"NOP6";
    self.opCodeDict[@(OP_NOP7)] = @"NOP7";
    self.opCodeDict[@(OP_NOP8)] = @"NOP8";
    self.opCodeDict[@(OP_NOP9)] = @"NOP9";
    self.opCodeDict[@(OP_NOP10)] = @"NOP10";

    _opCodeNameDict = [NSMutableDictionary new];
    self.opCodeNameDict[@"0"] = @(OP_0);
    self.opCodeNameDict[@"PUSHDATA1"] = @(OP_PUSHDATA1);
    self.opCodeNameDict[@"PUSHDATA2"] = @(OP_PUSHDATA2);
    self.opCodeNameDict[@"PUSHDATA4"] = @(OP_PUSHDATA4);
    self.opCodeNameDict[@"1NEGATE"] = @(OP_1NEGATE);
    self.opCodeNameDict[@"RESERVED"] = @(OP_RESERVED);
    self.opCodeNameDict[@"1"] = @(OP_1);
    self.opCodeNameDict[@"2"] = @(OP_2);
    self.opCodeNameDict[@"3"] = @(OP_3);
    self.opCodeNameDict[@"4"] = @(OP_4);
    self.opCodeNameDict[@"5"] = @(OP_5);
    self.opCodeNameDict[@"6"] = @(OP_6);
    self.opCodeNameDict[@"7"] = @(OP_7);
    self.opCodeNameDict[@"8"] = @(OP_8);
    self.opCodeNameDict[@"9"] = @(OP_9);
    self.opCodeNameDict[@"10"] = @(OP_10);
    self.opCodeNameDict[@"11"] = @(OP_11);
    self.opCodeNameDict[@"12"] = @(OP_12);
    self.opCodeNameDict[@"13"] = @(OP_13);
    self.opCodeNameDict[@"14"] = @(OP_14);
    self.opCodeNameDict[@"15"] = @(OP_15);
    self.opCodeNameDict[@"16"] = @(OP_16);
    self.opCodeNameDict[@"NOP"] = @(OP_NOP);
    self.opCodeNameDict[@"VER"] = @(OP_VER);
    self.opCodeNameDict[@"IF"] = @(OP_IF);
    self.opCodeNameDict[@"NOTIF"] = @(OP_NOTIF);
    self.opCodeNameDict[@"VERIF"] = @(OP_VERIF);
    self.opCodeNameDict[@"VERNOTIF"] = @(OP_VERNOTIF);
    self.opCodeNameDict[@"ELSE"] = @(OP_ELSE);
    self.opCodeNameDict[@"ENDIF"] = @(OP_ENDIF);
    self.opCodeNameDict[@"VERIFY"] = @(OP_VERIFY);
    self.opCodeNameDict[@"RETURN"] = @(OP_RETURN);
    self.opCodeNameDict[@"TOALTSTACK"] = @(OP_TOALTSTACK);
    self.opCodeNameDict[@"FROMALTSTACK"] = @(OP_FROMALTSTACK);
    self.opCodeNameDict[@"2DROP"] = @(OP_2DROP);
    self.opCodeNameDict[@"2DUP"] = @(OP_2DUP);
    self.opCodeNameDict[@"3DUP"] = @(OP_3DUP);
    self.opCodeNameDict[@"2OVER"] = @(OP_2OVER);
    self.opCodeNameDict[@"2ROT"] = @(OP_2ROT);
    self.opCodeNameDict[@"2SWAP"] = @(OP_2SWAP);
    self.opCodeNameDict[@"IFDUP"] = @(OP_IFDUP);
    self.opCodeNameDict[@"DEPTH"] = @(OP_DEPTH);
    self.opCodeNameDict[@"DROP"] = @(OP_DROP);
    self.opCodeNameDict[@"DUP"] = @(OP_DUP);
    self.opCodeNameDict[@"NIP"] = @(OP_NIP);
    self.opCodeNameDict[@"OVER"] = @(OP_OVER);
    self.opCodeNameDict[@"PICK"] = @(OP_PICK);
    self.opCodeNameDict[@"ROLL"] = @(OP_ROLL);
    self.opCodeNameDict[@"ROT"] = @(OP_ROT);
    self.opCodeNameDict[@"SWAP"] = @(OP_SWAP);
    self.opCodeNameDict[@"TUCK"] = @(OP_TUCK);
    self.opCodeNameDict[@"CAT"] = @(OP_CAT);
    self.opCodeNameDict[@"SUBSTR"] = @(OP_SUBSTR);
    self.opCodeNameDict[@"LEFT"] = @(OP_LEFT);
    self.opCodeNameDict[@"RIGHT"] = @(OP_RIGHT);
    self.opCodeNameDict[@"SIZE"] = @(OP_SIZE);
    self.opCodeNameDict[@"INVERT"] = @(OP_INVERT);
    self.opCodeNameDict[@"AND"] = @(OP_AND);
    self.opCodeNameDict[@"OR"] = @(OP_OR);
    self.opCodeNameDict[@"XOR"] = @(OP_XOR);
    self.opCodeNameDict[@"EQUAL"] = @(OP_EQUAL);
    self.opCodeNameDict[@"EQUALVERIFY"] = @(OP_EQUALVERIFY);
    self.opCodeNameDict[@"RESERVED1"] = @(OP_RESERVED1);
    self.opCodeNameDict[@"RESERVED2"] = @(OP_RESERVED2);
    self.opCodeNameDict[@"1ADD"] = @(OP_1ADD);
    self.opCodeNameDict[@"1SUB"] = @(OP_1SUB);
    self.opCodeNameDict[@"2MUL"] = @(OP_2MUL);
    self.opCodeNameDict[@"2DIV"] = @(OP_2DIV);
    self.opCodeNameDict[@"NEGATE"] = @(OP_NEGATE);
    self.opCodeNameDict[@"ABS"] = @(OP_ABS);
    self.opCodeNameDict[@"NOT"] = @(OP_NOT);
    self.opCodeNameDict[@"0NOTEQUAL"] = @(OP_0NOTEQUAL);
    self.opCodeNameDict[@"ADD"] = @(OP_ADD);
    self.opCodeNameDict[@"SUB"] = @(OP_SUB);
    self.opCodeNameDict[@"MUL"] = @(OP_MUL);
    self.opCodeNameDict[@"DIV"] = @(OP_DIV);
    self.opCodeNameDict[@"MOD"] = @(OP_MOD);
    self.opCodeNameDict[@"LSHIFT"] = @(OP_LSHIFT);
    self.opCodeNameDict[@"RSHIFT"] = @(OP_RSHIFT);
    self.opCodeNameDict[@"BOOLAND"] = @(OP_BOOLAND);
    self.opCodeNameDict[@"BOOLOR"] = @(OP_BOOLOR);
    self.opCodeNameDict[@"NUMEQUAL"] = @(OP_NUMEQUAL);
    self.opCodeNameDict[@"NUMEQUALVERIFY"] = @(OP_NUMEQUALVERIFY);
    self.opCodeNameDict[@"NUMNOTEQUAL"] = @(OP_NUMNOTEQUAL);
    self.opCodeNameDict[@"LESSTHAN"] = @(OP_LESSTHAN);
    self.opCodeNameDict[@"GREATERTHAN"] = @(OP_GREATERTHAN);
    self.opCodeNameDict[@"LESSTHANOREQUAL"] = @(OP_LESSTHANOREQUAL);
    self.opCodeNameDict[@"GREATERTHANOREQUAL"] = @(OP_GREATERTHANOREQUAL);
    self.opCodeNameDict[@"MIN"] = @(OP_MIN);
    self.opCodeNameDict[@"MAX"] = @(OP_MAX);
    self.opCodeNameDict[@"WITHIN"] = @(OP_WITHIN);
    self.opCodeNameDict[@"RIPEMD160"] = @(OP_RIPEMD160);
    self.opCodeNameDict[@"SHA1"] = @(OP_SHA1);
    self.opCodeNameDict[@"SHA256"] = @(OP_SHA256);
    self.opCodeNameDict[@"HASH160"] = @(OP_HASH160);
    self.opCodeNameDict[@"HASH256"] = @(OP_HASH256);
    self.opCodeNameDict[@"CODESEPARATOR"] = @(OP_CODESEPARATOR);
    self.opCodeNameDict[@"CHECKSIG"] = @(OP_CHECKSIG);
    self.opCodeNameDict[@"CHECKSIGVERIFY"] = @(OP_CHECKSIGVERIFY);
    self.opCodeNameDict[@"CHECKMULTISIG"] = @(OP_CHECKMULTISIG);
    self.opCodeNameDict[@"CHECKMULTISIGVERIFY"] = @(OP_CHECKMULTISIGVERIFY);
    self.opCodeNameDict[@"NOP1"] = @(OP_NOP1);
    self.opCodeNameDict[@"NOP2"] = @(OP_NOP2);
    self.opCodeNameDict[@"NOP3"] = @(OP_NOP3);
    self.opCodeNameDict[@"NOP4"] = @(OP_NOP4);
    self.opCodeNameDict[@"NOP5"] = @(OP_NOP5);
    self.opCodeNameDict[@"NOP6"] = @(OP_NOP6);
    self.opCodeNameDict[@"NOP7"] = @(OP_NOP7);
    self.opCodeNameDict[@"NOP8"] = @(OP_NOP8);
    self.opCodeNameDict[@"NOP9"] = @(OP_NOP9);
    self.opCodeNameDict[@"NOP10"] = @(OP_NOP10);

    return self;
}

+ (instancetype)instance; {
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });

    return singleton;
}

+ (NSString *)getOpCodeName:(int)opCode; {
    NSString *opCodeName = [BTScriptOpCodes instance].opCodeDict[@(opCode)];
    if (opCodeName == nil) {
        return [NSString stringWithFormat:@"NON_NO(%d)", opCode];
    } else {
        return opCodeName;
    }
}

+ (NSString *)getPushDataName:(int)opCode; {
    NSString *opCodeName = [BTScriptOpCodes instance].opCodeDict[@(opCode)];
    if (opCodeName == nil) {
        return [NSString stringWithFormat:@"PUSHDATA(%d)", opCode];
    } else {
        return opCodeName;
    }
}

+ (int)getOpCode:(NSString *)opCodeName; {
    NSNumber *opCode = [BTScriptOpCodes instance].opCodeNameDict[opCodeName];
    if (opCode == nil) {
        return OP_INVALIDOPCODE;
    } else {
        return [opCode intValue];
    }
}
@end