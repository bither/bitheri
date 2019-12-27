//
//  BTBech32.m
//  Bitheri
//
//  Created by hanzhenzhen on 2019/12/18.
//  Copyright © 2019 Bither. All rights reserved.
//

#import "BTBech32.h"
#import "NSMutableData+Bitcoin.h"

@interface BTBech32 ()

/// Bech32 checksum delimiter
@property(nonatomic, strong) NSString *checksumMarker;
/// Bech32 character set for encoding
@property(nonatomic, copy)   NSData   *encCharset;

@end

@implementation BTBech32

- (instancetype)init {
    self = [super init];
    if (self) {
        _checksumMarker = @"1";
        _encCharset = [@"qpzry9x8gf2tvdw0s3jn54khce6mua7l" dataUsingEncoding:NSUTF8StringEncoding];
    }
    return self;
}

/// Find the polynomial with value coefficients mod the generator as 30-bit.
- (uint32_t)polymod:(NSData *)values {
    uint32_t chk = 1;
    const char *bytes = [values bytes];
    for (int i = 0; i < [values length]; i++) {
        uint32_t top = (chk >> 0x19);
        uint32_t v = (uint32_t) bytes[i];
        chk = (chk & 0x1ffffff) << 5 ^ v;
        for (int j = 0; j < 5; j++) {
            chk ^= ((top >> j) & 1) == 0 ? 0 : [self getGen:j];
        }
    }
    return chk;
}

- (uint32_t)getGen:(int)index {
    switch (index) {
        case 0:
            return 0x3b6a57b2;
        case 1:
            return 0x26508e6d;
        case 2:
            return 0x1ea119fa;
        case 3:
            return 0x3d4233dd;
        default:
            return 0x2a1462b3;
    }
}

/// Expand a HRP for use in checksum computation.
- (NSData *)expandHrp:(NSString *)hrp {
    NSData *hrpBytes = [hrp dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *result = [NSMutableData secureDataWithCapacity:hrpBytes.length * 2 + 1];
    NSMutableData *data1 = [NSMutableData secureData];
    NSMutableData *data2 = [NSMutableData secureData];
    const char *bytes = [hrpBytes bytes];
    for (int i = 0; i < hrpBytes.length; i++) {
        [data1 appendUInt8:bytes[i] >> 5];
        [data2 appendUInt8:bytes[i] & 0x1f];
    }
    [result appendData:data1];
    [result appendUInt8:0];
    [result appendData:data2];
    return result;
}

/// Verify checksum
- (BOOL)verifyChecksum:(NSString *)hrp checksum:(NSData *)checksum {
    NSMutableData *data = [NSMutableData dataWithData:[self expandHrp:hrp]];
    [data appendData:checksum];
    return [self polymod:data] == 1;
}

/// Create checksum
- (NSData *)createChecksum:(NSString *)hrp values:(NSData *)values {
    NSMutableData *enc = [NSMutableData dataWithData:[self expandHrp:hrp]];
    [enc appendData:values];
    Byte bytes[6] = {0};
    [enc appendBytes:bytes length:6];
    uint32_t mod = [self polymod:enc] ^ 1;
    Byte ret[6] = {0};
    for (int i = 0; i < 6; i++) {
        ret[i] = (mod >> 5 * (5 - i)) & 0x1f;
    }
    return [[NSData alloc] initWithBytes:ret length:6];
}

/// Encode Bech32 string
- (NSString *)encode:(NSString *)hrp values: (NSData *)values {
    if (hrp.length < 1) {
        NSLog(@"Human-readable part is too short");
        return nil;
    }
    if (hrp.length > 83) {
        NSLog(@"Human-readable part is too long");
        return nil;
    }
    NSString *hrpLower = [hrp lowercaseString];
    NSData *checksum = [self createChecksum:hrpLower values:values];
    NSMutableData *combined = [NSMutableData dataWithData:values];
    [combined appendData:checksum];
    NSMutableData *ret = [NSMutableData dataWithData:[hrpLower dataUsingEncoding:NSUTF8StringEncoding]];
    [ret appendData:[@"1" dataUsingEncoding:NSUTF8StringEncoding]];
    const char *combinedBytes = [combined bytes];
    const char *encCharsetBytes = [_encCharset bytes];
    for (int i = 0; i < combined.length; i++) {
        int c = (int) combinedBytes[i];
        [ret appendUInt8:encCharsetBytes[c]];
    }
    return [[NSString alloc] initWithData:ret encoding:NSUTF8StringEncoding];
}

/// Decode Bech32 string
- (BTBech32Data *)decode:(NSString *)str {
    NSData *strBytes = [str dataUsingEncoding:NSUTF8StringEncoding];
    if (!strBytes) {
        NSLog(@"String cannot be decoded by utf8 decoder");
        return nil;
    }
    if (strBytes.length > 90) {
        NSLog(@"Input string is too long");
        return nil;
    }
    BOOL lower = false;
    BOOL upper = false;
    const char *bytes = [strBytes bytes];
    for (int i = 0; i < strBytes.length; i++) {
        // printable range
        int c = (int) bytes[i];
        if (c < 33 || c > 126) {
            NSLog(@"Non printable character in input string");
            return nil;
        }
        // 'a' to 'z'
        if (c >= 97 && c <= 122) {
            lower = true;
        }
        // 'A' to 'Z'
        if (c >= 65 && c <= 90) {
            upper = true;
        }
    }
    if (lower && upper) {
        NSLog(@"String contains mixed case characters");
        return nil;
    }
    NSUInteger intPos = [str rangeOfString:_checksumMarker options:NSBackwardsSearch].location;
    if (intPos < 1) {
        NSLog(@"Missing human-readable part");
        return nil;
    }
    NSInteger dataPartLength = str.length - 1 - intPos;
    if (dataPartLength < 6) {
        NSLog(@"Data part too short");
        return nil;
    }
    NSMutableData *values = [NSMutableData secureData];
    for (int i = 0 ; i < dataPartLength; i++) {
        int c = (int) bytes[i + intPos + 1];
        int8_t decInt = [self getDecCharset: c];
        if (decInt == -1) {
            NSLog(@"Invalid character met on decoding");
            return nil;
        }
        [values appendUInt8:decInt];
    }
    NSString *hrp = [[str substringToIndex:intPos] lowercaseString];
    if (![self verifyChecksum:hrp checksum:values]) {
        NSLog(@"Checksum doesn't match");
        return nil;
    }
    return [[BTBech32Data alloc] initWithHrp:hrp checksum:[values subdataWithRange:NSMakeRange(0, dataPartLength - 6)]];
}

/// Bech32 character set for decoding
- (uint8_t)getDecCharset:(int)index {
    switch (index) {
        case 48:
            return 15;
        case 50:
            return 10;
        case 51:
            return 17;
        case 52:
            return 21;
        case 53:
            return 20;
        case 54:
            return 26;
        case 55:
            return 30;
        case 56:
            return 7;
        case 57:
            return 5;
        case 65:
            return 29;
        case 67:
            return 24;
        case 68:
            return 13;
        case 69:
            return 25;
        case 70:
            return 9;
        case 71:
            return 8;
        case 72:
            return 23;
        case 74:
            return 18;
        case 75:
            return 22;
        case 76:
            return 31;
        case 77:
            return 27;
        case 78:
            return 19;
        case 80:
            return 1;
        case 81:
            return 0;
        case 82:
            return 3;
        case 83:
            return 16;
        case 84:
            return 11;
        case 85:
            return 28;
        case 86:
            return 12;
        case 87:
            return 14;
        case 88:
            return 6;
        case 89:
            return 4;
        case 90:
            return 2;
        case 97:
            return 29;
        case 99:
            return 24;
        case 100:
            return 13;
        case 101:
            return 25;
        case 102:
            return 9;
        case 103:
            return 8;
        case 104:
            return 23;
        case 106:
            return 18;
        case 107:
            return 22;
        case 108:
            return 31;
        case 109:
            return 27;
        case 110:
            return 19;
        case 112:
            return 1;
        case 113:
            return 0;
        case 114:
            return 3;
        case 115:
            return 16;
        case 116:
            return 11;
        case 117:
            return 28;
        case 118:
            return 12;
        case 119:
            return 14;
        case 120:
            return 6;
        case 121:
            return 4;
        case 122:
            return 2;
        default:
            return -1;
    }
}

@end
