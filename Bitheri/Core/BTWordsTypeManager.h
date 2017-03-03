//
//  BTWordsTypeManager.h
//  Bitheri
//
//  Created by 韩珍 on 2017/3/3.
//  Copyright © 2017年 Bither. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    EN_WORDS, ZHCN_WORDS, ZHTW_WORDS
} WordsType;

@interface BTWordsTypeManager : NSObject

+ (instancetype)instance;

- (void)saveWordsTypeValue:(NSString *)value;

- (NSString *)getWordsTypeValueForUserDefaults;

+ (WordsType)getWordsTypeForValue:(NSString *)value;

+ (NSString *)getWordsTypeValue:(WordsType)wordsType;

+ (NSArray *)getAllWordsType;

@end
