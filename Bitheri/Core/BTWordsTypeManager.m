//
//  BTWordsTypeManager.m
//  Bitheri
//
//  Created by 韩珍 on 2017/3/3.
//  Copyright © 2017年 Bither. All rights reserved.
//

#import "BTWordsTypeManager.h"

#define BTUserDefaultsWordsType @"BTUserDefaultsWordsType"

@implementation BTWordsTypeManager

+ (instancetype)instance {
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [BTWordsTypeManager new];
    });
    
    return singleton;
}

- (void)saveWordsTypeValue:(NSString *)value {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:value forKey:BTUserDefaultsWordsType];
    [userDefaults synchronize];
}

- (NSString *)getWordsTypeValueForUserDefaults {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *wordsTypeStr = [userDefaults objectForKey:BTUserDefaultsWordsType];
    return !wordsTypeStr ? [BTWordsTypeManager getWordsTypeValue:EN_WORDS] : wordsTypeStr;
}

+ (WordsType)getWordsTypeForValue:(NSString *)value {
    if ([value isEqualToString:[BTWordsTypeManager getWordsTypeValue:ZHCN_WORDS]]) {
        return ZHCN_WORDS;
    }
    if ([value isEqualToString:[BTWordsTypeManager getWordsTypeValue:ZHTW_WORDS]]) {
        return ZHTW_WORDS;
    }
    return EN_WORDS;
}

+ (NSString *)getWordsTypeValue:(WordsType)wordsType {
    switch (wordsType) {
        case ZHCN_WORDS:
            return @"BIP39ZhCNWords";
        case ZHTW_WORDS:
            return @"BIP39ZhTWWords";
        default:
            return @"BIP39EnglishWords";
    }
}

+ (NSArray *)getAllWordsType {
    return @[[BTWordsTypeManager getWordsTypeValue:EN_WORDS], [BTWordsTypeManager getWordsTypeValue:ZHCN_WORDS], [BTWordsTypeManager getWordsTypeValue:ZHTW_WORDS]];
}


@end
