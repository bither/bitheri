//
//  QRCodeEncodeUtil.m
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

#import "BTQRCodeUtil.h"
#import "NSString+Base58.h"
#import "BTWordsTypeManager.h"

#define kQR_QUALITY_KEY (@"qr_quality")

#define MAX_QRCODE_SIZE_NORMAL (328)
#define MAX_QRCODE_SIZE_LOW (216)
#define QR_CODE_LETTER @"*"
#define OLD_QR_CODE_SPLIT @":"
#define QR_CODE_SPLIT @"/"


@implementation BTQRCodeUtil

+ (NSString *)replaceNewQRCode:(NSString *)content {
    return [content stringByReplacingOccurrencesOfString:OLD_QR_CODE_SPLIT withString:QR_CODE_SPLIT];
}

+ (BOOL)isOldQRCodeVerion:(NSString *)content {
    return [content rangeOfString:OLD_QR_CODE_SPLIT].location != NSNotFound;
}

+ (NSArray *)splitQRCode:(NSString *)content {
    if ([BTQRCodeUtil isOldQRCodeVerion:content]) {
        return [content componentsSeparatedByString:OLD_QR_CODE_SPLIT];
    } else {
        return [content componentsSeparatedByString:QR_CODE_SPLIT];
    }
}

+ (NSString *)joinedQRCode:(NSArray *)array {
    return [array componentsJoinedByString:QR_CODE_SPLIT];
}

+ (NSString *)oldJoinedQRCode:(NSArray *)array {
    return [array componentsJoinedByString:OLD_QR_CODE_SPLIT];
}

+ (NSString *)encodeQrCodeString:(NSString *)text {
    return [text toUppercaseStringWithEn];
}

+ (NSString *)oldEncodeQrCodeString:(NSString *)text {
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[A-Z]" options:0 error:&error];
    NSArray *matches = [regex matchesInString:text
                                      options:0
                                        range:NSMakeRange(0, [text length])];
    NSString *result = @"";
    NSInteger lastIndex = 0;
    for (NSTextCheckingResult *match in matches) {
        NSRange range = [match rangeAtIndex:0];
        if (range.location > lastIndex && lastIndex != 0) {
            result = [result stringByAppendingString:[text substringWithRange:NSMakeRange(lastIndex, range.location - lastIndex)]];
        }
        if (lastIndex == 0) {
            if (range.location != 0) {
                result = [text substringToIndex:range.location];
            }
        }

        result = [result stringByAppendingFormat:@"*%@", [text substringWithRange:[match rangeAtIndex:0]]];
        lastIndex = range.location + range.length;

    }
    if (lastIndex < text.length) {
        result = [result stringByAppendingString:[text substringWithRange:NSMakeRange(lastIndex, text.length - lastIndex)]];
    }

    return [result toUppercaseStringWithEn];
}

+ (NSString *)decodeQrCodeString:(NSString *)text {
    if ([BTQRCodeUtil oldVerifyQrcodeTransport:text]) {
        return [BTQRCodeUtil oldDecodeQrCodeString:text];
    }
    return text;
}

+ (NSString *)oldDecodeQrCodeString:(NSString *)text {
    text = [text lowercaseString];
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\*([a-z])" options:0 error:&error];
    NSArray *matches = [regex matchesInString:text
                                      options:0
                                        range:NSMakeRange(0, [text length])];
    NSString *result = @"";

    NSInteger lastIndex = 0;

    for (NSTextCheckingResult *match in matches) {
        NSRange range = [match rangeAtIndex:0];
        if (range.location > lastIndex && lastIndex != 0) {
            result = [result stringByAppendingString:[text substringWithRange:NSMakeRange(lastIndex, range.location - lastIndex)]];
        }
        if (lastIndex == 0) {
            if (range.location != 0) {
                result = [text substringToIndex:range.location];
            }
        }
        result = [result stringByAppendingFormat:@"%@", [[text substringWithRange:[match rangeAtIndex:1]] toUppercaseStringWithEn]];

        lastIndex = range.location + range.length;

    }
    if (lastIndex < text.length) {
        result = [result stringByAppendingString:[text substringWithRange:NSMakeRange(lastIndex, text.length - lastIndex)]];
    }

    return result;


}

+ (BOOL)verifyQrcodeTransport:(NSString *)text {
    BOOL verifyOldVersion = [BTQRCodeUtil oldVerifyQrcodeTransport:text];
    NSError *error;
    NSString *regexStr = @"[^0-9a-zA-Z/+-\\$%]";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexStr options:0 error:&error];
    NSArray *matches = [regex matchesInString:text
                                      options:0
                                        range:NSMakeRange(0, [text length])];
    BOOL verifyNewVersion = matches.count == 0;
    return verifyNewVersion || verifyOldVersion;

}

+ (BOOL)oldVerifyQrcodeTransport:(NSString *)text {
    NSError *error;
    NSString *regexStr = @"[^0-9A-Z\\*:]";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexStr options:0 error:&error];
    NSArray *matches = [regex matchesInString:text
                                      options:0
                                        range:NSMakeRange(0, [text length])];
    return matches.count == 0;
}

+ (NSInteger)getNumOfQrCodeString:(NSInteger)length {
    if (length < [BTQRCodeUtil maxSize]) {
        return 1;
    } else if (length <= ([BTQRCodeUtil maxSize] - 4) * 10) {
        return length / ([BTQRCodeUtil maxSize] - 4) + 1;
    } else if (length <= ([BTQRCodeUtil maxSize] - 5) * 100) {
        return (length / ([BTQRCodeUtil maxSize] - 5)) + 1;
    } else if (length <= ([BTQRCodeUtil maxSize] - 6) * 1000) {
        return length / ([BTQRCodeUtil maxSize] - 6) + 1;
    } else {
        return 1000;
    }
}

+ (QRQuality)qrQuality {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kQR_QUALITY_KEY]) {
        QRQuality q = (QRQuality) [[NSUserDefaults standardUserDefaults] integerForKey:kQR_QUALITY_KEY];
        return q;
    } else {
        return NORMAL;
    }
}

+ (void)setQrQuality:(QRQuality)quality {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:quality forKey:kQR_QUALITY_KEY];
    [defaults synchronize];
}

+ (NSUInteger)maxSize {
    switch ([BTQRCodeUtil qrQuality]) {
        case LOW:
            return MAX_QRCODE_SIZE_LOW;
        case NORMAL:
        default:
            return MAX_QRCODE_SIZE_NORMAL;
    }
}

+ (NSString *)getHDQrCodeFlat:(HDQrCodeFlatType)qrCodeFlatType {
    switch (qrCodeFlatType) {
        case ZHCN:
            return @"%1%";
        case ZHTW:
            return @"%2%";
        default:
            return @"%";
    }
}

+ (HDQrCodeFlatType)getHDQrCodeFlatForWordsTypeValue:(NSString *)value {
    if ([value isEqualToString:[BTWordsTypeManager getWordsTypeValue:ZHCN_WORDS]]) {
        return ZHCN;
    }
    if ([value isEqualToString:[BTWordsTypeManager getWordsTypeValue:ZHTW_WORDS]]) {
        return ZHTW;
    }
    return EN;
}

@end
