//
//  BTScriptTest.m
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

#import <XCTest/XCTest.h>
#import "BTScript.h"
#import "NSMutableData+Bitcoin.h"
#import "BTTestHelper.h"
#import "BTScriptOpCodes.h"
#import "BTKey.h"
#import "BTIn.h"

@interface BTScriptTest : XCTestCase

@end

@implementation BTScriptTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [BTTestHelper setup];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testValid; {
    NSError *error;
    NSArray *array = [NSJSONSerialization JSONObjectWithData:[BTTestHelper readFileToData:@"Script/script_valid.json"]
                                                     options:NSJSONReadingMutableContainers error:&error];

    for (NSArray *sub in array) {
        BTScript *scriptSig = [BTScriptTest parseScriptString:sub[0]];
        BTScript *scriptPubKey = [BTScriptTest parseScriptString:sub[1]];
        BOOL result = [scriptSig correctlySpends:scriptPubKey and:YES];
        XCTAssert(result);

        if (!result) {
            scriptSig = [BTScriptTest parseScriptString:sub[0]];
            scriptPubKey = [BTScriptTest parseScriptString:sub[1]];
            [scriptSig correctlySpends:scriptPubKey and:YES];
        }
    }
}

- (void)testInvalid; {
    NSError *error;
    NSArray *array = [NSJSONSerialization JSONObjectWithData:[BTTestHelper readFileToData:@"Script/script_invalid.json"]
                                                     options:NSJSONReadingMutableContainers error:&error];

    for (NSArray *sub in array) {
        BTScript *scriptSig = [BTScriptTest parseScriptString:sub[0]];
        BTScript *scriptPubKey = [BTScriptTest parseScriptString:sub[1]];
        BOOL result = [scriptSig correctlySpends:scriptPubKey and:YES];
        XCTAssert(!result);

        if (result) {
            scriptSig = [BTScriptTest parseScriptString:sub[0]];
            scriptPubKey = [BTScriptTest parseScriptString:sub[1]];
            [scriptSig correctlySpends:scriptPubKey and:YES];
        }
    }
}

- (void)testTxValid; {
    NSError *error;
    NSArray *array = [NSJSONSerialization JSONObjectWithData:[BTTestHelper readFileToData:@"Script/tx_valid.json"]
                                                     options:NSJSONReadingMutableContainers error:&error];

    for (NSArray *sub in array) {
        if (sub.count != 3) {
            // comment
            continue;
        }

        NSMutableDictionary *scriptPubKeys = [NSMutableDictionary new];
        BTTx *tx = [BTTx transactionWithMessage:[(NSString *) sub[1] hexToData]];

        XCTAssert([tx verify]);
        if (![tx verify]) {
            [tx verify];
        }

        for (NSArray *scripts in sub[0]) {
            NSData *hash = [[(NSString *) scripts[0] hexToData] reverse];
            NSUInteger index = [scripts[1] unsignedIntValue];
            BTScript *script = [BTScriptTest parseScriptString:scripts[2]];

            scriptPubKeys[hash] = script;
            [tx setInScript:script.program forInHash:hash andInIndex:index];
        }

        BOOL enforceP2SH = [sub[2] boolValue];

        BOOL result = YES;
        for (NSUInteger i = 0; i < tx.inputIndexes.count; i++) {
            BTScript *scriptSig = [[BTScript alloc] initWithProgram:tx.inputSignatures[i]];
            BTScript *scriptPubKey = scriptPubKeys[((BTIn *)tx.ins[i]).prevTxHash];
            scriptSig.tx = tx;
            scriptPubKey.tx = tx;
            scriptSig.index = i;
            scriptPubKey.index = i;

            result &= [scriptSig correctlySpends:scriptPubKey and:enforceP2SH];

            if (!result)
                [scriptSig correctlySpends:scriptPubKey and:enforceP2SH];
        }
        XCTAssert(result);
    }
}

- (void)testTxInvalid; {
    NSError *error;
    NSArray *array = [NSJSONSerialization JSONObjectWithData:[BTTestHelper readFileToData:@"Script/tx_invalid.json"]
                                                     options:NSJSONReadingMutableContainers error:&error];

    for (NSArray *sub in array) {
        if (sub.count != 3)
            continue;

        NSMutableDictionary *scriptPubKeys = [NSMutableDictionary new];
        BTTx *tx = [BTTx transactionWithMessage:[(NSString *) sub[1] hexToData]];
        if ([tx verify]) {

            for (NSArray *scripts in sub[0]) {
                NSData *hash = [[(NSString *) scripts[0] hexToData] reverse];
                NSUInteger index = [scripts[1] unsignedIntValue];
                BTScript *script = [BTScriptTest parseScriptString:scripts[2]];

                scriptPubKeys[hash] = script;
                [tx setInScript:script.program forInHash:hash andInIndex:index];
            }

            BOOL enforceP2SH = [sub[2] boolValue];

            BOOL result = YES;
            for (NSUInteger i = 0; i < tx.inputIndexes.count; i++) {
                BTScript *scriptSig = [[BTScript alloc] initWithProgram:tx.inputSignatures[i]];
                BTScript *scriptPubKey = scriptPubKeys[((BTIn *)tx.ins[i]).prevTxHash];//scriptPubKeys[@""];
                scriptSig.tx = tx;
                scriptSig.index = i;

                result &= [scriptSig correctlySpends:scriptPubKey and:enforceP2SH];

                if (result) {
                    [scriptSig correctlySpends:scriptPubKey and:enforceP2SH];
                    [tx verify];
                }
            }
            XCTAssert(!result);
        }
    }
}

+ (BTScript *)parseScriptString:(NSString *)string; {
    NSArray *words = [string componentsSeparatedByString:@" "];
    NSMutableData *out = [NSMutableData secureData];

    for (NSString *w in words) {
        if ([w isEqualToString:@""])
            continue;

        if ([[NSPredicate predicateWithFormat:@"SELF matches %@", @"^-?[0-9]*$"] evaluateWithObject:w]) {
            // Number
            long long val = [w longLongValue];

            if (val >= -1 && val <= 16)
                [out appendUInt8:[BTScript encodeToOpN:val]];
            else
                [out appendScriptPushData:[BTScript castInt64ToData:val]];
        } else if ([[NSPredicate predicateWithFormat:@"SELF matches %@", @"^0x[0-9a-fA-F]*$"] evaluateWithObject:w]) {
            // Raw hex data, inserted NOT pushed onto stack:
            [out appendData:[[w substringFromIndex:2] hexToData]];
        } else if (w.length >= 2 && [[w substringToIndex:1] isEqualToString:@"'"]
                && [[w substringFromIndex:w.length - 1] isEqualToString:@"'"]) {
            // Single-quoted string, pushed as data. NOTE: this is poor-man's
            // parsing, spaces/tabs/newlines in single-quoted strings won't work.
            if (w.length == 2) {
                [out appendUInt8:0];
            } else {
                [out appendScriptPushData:[[w substringWithRange:NSMakeRange(1, w.length - 2)] dataUsingEncoding:NSUTF8StringEncoding]];
            }
        } else if ([BTScriptOpCodes getOpCode:w] != OP_INVALIDOPCODE) {
            // opcode, e.g. OP_ADD or OP_1:
            [out appendUInt8:(uint8_t) [BTScriptOpCodes getOpCode:w]];
        } else if ([[w substringToIndex:3] isEqualToString:@"OP_"] && [BTScriptOpCodes getOpCode:[w substringFromIndex:3]] != OP_INVALIDOPCODE) {
            // opcode, e.g. OP_ADD or OP_1:
            [out appendUInt8:(uint8_t) [BTScriptOpCodes getOpCode:[w substringFromIndex:3]]];
        } else {
//            throw new RuntimeException("Invalid Data");
        }
    }
    return [[BTScript alloc] initWithProgram:out];
}

@end
