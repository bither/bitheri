//
//  NSMutableData+Bitcoin.m
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
//
//  Copyright (c) 2013-2014 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "NSMutableData+Bitcoin.h"
#import "NSString+Base58.h"
#import "NSData+Hash.h"
#import "BTScriptOpCodes.h"

#define VAR_INT16_HEADER 0xfd
#define VAR_INT32_HEADER 0xfe
#define VAR_INT64_HEADER 0xff

#define OP_PUSHDATA1   0x4c
#define OP_PUSHDATA2   0x4d
#define OP_PUSHDATA4   0x4e
#define OP_DUP         0x76
#define OP_EQUALVERIFY 0x88
#define OP_HASH160     0xa9
#define OP_CHECKSIG    0xac

@implementation NSMutableData (Bitcoin)

+ (NSMutableData *)secureData {
    return [self secureDataWithCapacity:0];
}

+ (NSMutableData *)secureDataWithCapacity:(NSUInteger)aNumItems {
    return CFBridgingRelease(CFDataCreateMutable(SecureAllocator(), aNumItems));
}

+ (NSMutableData *)secureDataWithLength:(NSUInteger)length {
    NSMutableData *d = [self secureDataWithCapacity:length];

    d.length = length;
    return d;
}

+ (NSMutableData *)secureDataWithData:(NSData *)data {
    return CFBridgingRelease(CFDataCreateMutableCopy(SecureAllocator(), 0, (__bridge CFDataRef) data));
}

+ (size_t)sizeOfVarInt:(uint64_t)i {
    if (i < VAR_INT16_HEADER) return sizeof(uint8_t);
    else if (i <= UINT16_MAX) return sizeof(uint8_t) + sizeof(uint16_t);
    else if (i <= UINT32_MAX) return sizeof(uint8_t) + sizeof(uint32_t);
    else return sizeof(uint8_t) + sizeof(uint64_t);
}

- (void)appendUInt8:(uint8_t)i {
    [self appendBytes:&i length:sizeof(i)];
}

- (void)appendUInt16:(uint16_t)i {
    i = CFSwapInt16HostToLittle(i);
    [self appendBytes:&i length:sizeof(i)];
}

- (void)appendUInt32:(uint32_t)i {
    i = CFSwapInt32HostToLittle(i);
    [self appendBytes:&i length:sizeof(i)];
}

- (void)appendUInt64:(uint64_t)i {
    i = CFSwapInt64HostToLittle(i);
    [self appendBytes:&i length:sizeof(i)];
}

- (void)appendVarInt:(uint64_t)i {
    if (i < VAR_INT16_HEADER) {
        uint8_t payload = (uint8_t) i;

        [self appendBytes:&payload length:sizeof(payload)];
    }
    else if (i <= UINT16_MAX) {
        uint8_t header = VAR_INT16_HEADER;
        uint16_t payload = CFSwapInt16HostToLittle((uint16_t) i);

        [self appendBytes:&header length:sizeof(header)];
        [self appendBytes:&payload length:sizeof(payload)];
    }
    else if (i <= UINT32_MAX) {
        uint8_t header = VAR_INT32_HEADER;
        uint32_t payload = CFSwapInt32HostToLittle((uint32_t) i);

        [self appendBytes:&header length:sizeof(header)];
        [self appendBytes:&payload length:sizeof(payload)];
    }
    else {
        uint8_t header = VAR_INT64_HEADER;
        uint64_t payload = CFSwapInt64HostToLittle(i);

        [self appendBytes:&header length:sizeof(header)];
        [self appendBytes:&payload length:sizeof(payload)];
    }
}

- (void)appendString:(NSString *)s {
    NSUInteger l = [s lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

    [self appendVarInt:l];
    [self appendBytes:s.UTF8String length:l];
}

#pragma mark - bitcoin script

- (void)appendScriptPushData:(NSData *)d {
    if (d.length == 0) {
        return;
    }
    else if (d.length < OP_PUSHDATA1) {
        [self appendUInt8:d.length];
    }
    else if (d.length < UINT8_MAX) {
        [self appendUInt8:OP_PUSHDATA1];
        [self appendUInt8:d.length];
    }
    else if (d.length < UINT16_MAX) {
        [self appendUInt8:OP_PUSHDATA2];
        [self appendUInt16:d.length];
    }
    else {
        [self appendUInt8:OP_PUSHDATA4];
        [self appendUInt32:(uint32_t) d.length];
    }

    [self appendData:d];
}

- (void)appendScriptPubKeyForHash:(NSData *)hash {
    [self appendUInt8:OP_DUP];
    [self appendUInt8:OP_HASH160];
    [self appendScriptPushData:hash]; // script is big endian
    [self appendUInt8:OP_EQUALVERIFY];
    [self appendUInt8:OP_CHECKSIG];
}

- (void)appendScriptPubKeyForP2SH:(NSData *)hash {
    [self appendUInt8:OP_HASH160];
    [self appendScriptPushData:hash];
    [self appendUInt8:OP_EQUAL];
}

- (void)appendScriptPubKeyForAddress:(NSString *)address {
    NSData *d = address.base58checkToData;
    if (d.length != 21) return;

    uint8_t version = *(const uint8_t *) d.bytes;

    if ([NSString validAddressPubkey:version]) {
        [self appendScriptPubKeyForHash:address.addressToHash160];
    } else if ([NSString validAddressScript:version]) {
        [self appendScriptPubKeyForP2SH:address.addressToHash160];
    }
}

#pragma mark - bitcoin protocol

- (void)appendMessage:(NSData *)message type:(NSString *)type; {
    [self appendUInt32:BITCOIN_MAGIC_NUMBER];
    [self appendNullPaddedString:type length:12];
    [self appendUInt32:(uint32_t) message.length];
    [self appendBytes:message.SHA256_2.bytes length:4];
    [self appendBytes:message.bytes length:message.length];
}

- (void)appendNullPaddedString:(NSString *)s length:(NSUInteger)length {
    NSUInteger l = [s lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

    [self appendBytes:s.UTF8String length:l];

    while (l++ < length) {
        [self appendBytes:"\0" length:1];
    }
}

- (void)appendNetAddress:(uint32_t)address port:(uint16_t)port services:(uint64_t)services {
    address = CFSwapInt32HostToBig(address);
    port = CFSwapInt16HostToBig(port);

    [self appendUInt64:services];
    [self appendBytes:"\0\0\0\0\0\0\0\0\0\0\xFF\xFF" length:12]; // IPv4 mapped IPv6 header
    [self appendBytes:&address length:sizeof(address)];
    [self appendBytes:&port length:sizeof(port)];
}

@end
