//
//  BTSegwitAddrCoder.m
//  Bitheri
//
//  Created by hanzhenzhen on 2019/12/19.
//  Copyright © 2019 Bither. All rights reserved.
//

/// Segregated Witness Address encoder/decoder

#import "BTSegwitAddrCoder.h"
#import "BTBech32.h"
#import "NSMutableData+Bitcoin.h"
#import "BTBech32Data.h"

@interface BTSegwitAddrCoder ()

@property(nonatomic, strong) BTBech32 *bech32;

@end

@implementation BTSegwitAddrCoder

- (instancetype)init {
    self = [super init];
    if (self) {
        _bech32 = [[BTBech32 alloc] init];
    }
    return self;
}

+ (int)getWitnessVersion:(NSData *)program {
    const char *bytes = [program bytes];
    int version = bytes[0] & 0xff;
    return version;
}

+ (NSData *)getWitnessProgram:(NSData *)program {
    return [BTSegwitAddrCoder convertBits:program inStart:1 inLen:program.length - 1 from:5 to:8 pad:false];
}

+ (NSData *)convertBits:(NSData *)idata inStart:(int)inStart inLen:(NSUInteger)inLen from:(int)from to:(int)to pad:(BOOL)pad {
    int acc = 0;
    int bits = 0;
    int maxv = (1 << to) - 1;
    int maxAcc = (1 << (from + to - 1)) - 1;
    NSMutableData *odata = [NSMutableData secureData];
    const char *bytes = [idata bytes];
    for (int i = 0; i < inLen; i++) {
        int ibyte = bytes[i + inStart] & 0xff;
        if ((ibyte >> from) != 0) {
            NSLog(@"Input value '%d' exceeds '%d' bit size", ibyte, from);
            return nil;
        }
        acc = ((acc << from) | ibyte) & maxAcc;
        bits += from;
        while (bits >= to) {
            bits -= to;
            [odata appendUInt8:(acc >> bits) & maxv];
        }
    }
    if (pad) {
        if (bits > 0) {
            [odata appendUInt8:(acc << (to - bits)) & maxv];
        }
    } else if (bits >= from || ((acc << (to - bits)) & maxv) != 0) {
        NSLog(@"Failed to perform bits conversion");
        return nil;
    }
    return odata;
}

/// Convert from one power-of-2 number base to another
- (NSData *)convertBits:(int)from to:(int)to pad:(BOOL)pad idata:(NSData *)idata {
    int acc = 0;
    int bits = 0;
    int maxv = (1 << to) - 1;
    int maxAcc = (1 << (from + to - 1)) - 1;
    NSMutableData *odata = [NSMutableData secureData];
    const char *bytes = [idata bytes];
    for (int i = 0; i < idata.length; i++) {
        int ibyte = bytes[i] & 0xff;
        acc = ((acc << from) | ibyte) & maxAcc;
        bits += from;
        while (bits >= to) {
            bits -= to;
            [odata appendUInt8:(acc >> bits) & maxv];
        }
    }
    if (pad) {
        if (bits > 0) {
            [odata appendUInt8:(acc << (to - bits)) & maxv];
        }
    } else if (bits >= from || ((acc << (to - bits)) & maxv) != 0) {
        NSLog(@"Failed to perform bits conversion");
        return nil;
    }
    return odata;
}

/// Decode segwit address
- (BTSegwitAddrData *)decode:(NSString *)hrp addr:(NSString *)addr {
    BTBech32Data *dec = [_bech32 decode:addr];
    if (!dec) {
        return nil;
    }
    if (![dec.hrp isEqualToString:hrp]) {
        NSLog(@"Human-readable-part %@ does not match requested %@", dec.hrp, hrp);
        return nil;
    }
    if (![dec.hrp isEqualToString:@"bc"] && ![dec.hrp isEqualToString:@"tb"]) {
        NSLog(@"invalid segwit human readable part");
        return nil;
    }
    NSData *data = dec.checksum;
    if (data.length < 1) {
        NSLog(@"Checksum size is too low");
        return nil;
    }
    NSData *conv = [self convertBits:5 to:8 pad:false idata:[data subdataWithRange:NSMakeRange(1, data.length - 1)]];
    if (conv.length < 2 || conv.length > 40) {
        NSLog(@"Program size %lu does not meet required range 2...40", (unsigned long)conv.length);
        return nil;
    }
    const char *bytes = [data bytes];
    int version = bytes[0];
    if (version > 16) {
        NSLog(@"Segwit version %d is not supported by this decoder", version);
        return nil;
    }
    if (version == 0 && conv.length != 20 && conv.length != 32) {
        NSLog(@"Segwit program size %lu does not meet version 0 requirments", (unsigned long)conv.length);
        return nil;
    }
    return [[BTSegwitAddrData alloc] initWithVersion:version program:conv];
}

/// Encode segwit address
- (NSString *)encode:(NSString *)hrp version:(int)version program:(NSData *)program {
    NSData *data = [self convertBits:8 to:5 pad:true idata:program];
    if (!data) {
        return nil;
    }
    NSMutableData *enc = [NSMutableData secureData];
    [enc appendUInt8:version];
    [enc appendData:data];
    NSString *result = [_bech32 encode:hrp values:enc];
    if ([self decode:hrp addr:result] == nil) {
        NSLog(@"Failed to check result after encoding");
        return nil;
    }
    return result;
}

@end
