//
//  QRCodeEncodeUtil.h
//  bither-ios
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

#define XRANDOM_FLAG @"+"
#define HDM_QR_CODE_FLAG  @"-"
#define QR_CODE_SECONDARY_SPLIT (@"$")
#define HD_MONITOR_QR_PREFIX (@"BitherHD:")

typedef enum {
    NORMAL,
    LOW
} QRQuality;

typedef enum {
    EN, ZHCN, ZHTW
} HDQrCodeFlatType;

@interface BTQRCodeUtil : NSObject

+ (BOOL)isOldQRCodeVerion:(NSString *)content;

+ (NSString *)replaceNewQRCode:(NSString *)content;

+ (NSArray *)splitQRCode:(NSString *)content;

+ (NSString *)oldJoinedQRCode:(NSArray *)array;

+ (NSString *)joinedQRCode:(NSArray *)array;

+ (NSString *)oldEncodeQrCodeString:(NSString *)text;

+ (NSString *)encodeQrCodeString:(NSString *)text;

+ (NSString *)decodeQrCodeString:(NSString *)text;

+ (BOOL)verifyQrcodeTransport:(NSString *)text;

+ (NSInteger)getNumOfQrCodeString:(NSInteger)length;

+ (QRQuality)qrQuality;

+ (void)setQrQuality:(QRQuality)quality;

+ (NSUInteger)maxSize;

+ (NSString *)getHDQrCodeFlat:(HDQrCodeFlatType)qrCodeFlatType;

+ (HDQrCodeFlatType)getHDQrCodeFlatForWordsTypeValue:(NSString *)value;

@end
