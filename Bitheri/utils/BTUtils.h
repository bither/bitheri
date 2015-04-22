//
//  BTUtils.h
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
#import "BTSettings.h"

@interface BTUtils : NSObject

+ (NSString *)documentsPathForFileName:(NSString *)fileName;

+ (NSString *)readFile:(NSString *)fileFullName;

+ (void)writeFile:(NSString *)fileName content:(NSString *)content;

+ (void)removeFile:(NSString *)fileName;

+ (void)moveFile:(NSString *)oldFileName to:(NSString *)newFileName;

+ (NSArray *)filesByModDate:(NSString *)fullPath;

+ (BOOL)setModifyDateToFile:(NSDate *)date forFile:(NSString *)path;

+ (NSString *)getPrivDir;

+ (NSString *)getWatchOnlyDir;

+ (NSString *)getTrashDir;

+ (NSArray *)getFileList:(NSString *)dir;

+ (BOOL)compareString:(NSString *)original compare:(NSString *)compare;

+ (BOOL)isEmpty:(NSString *)str;

+ (NSData *)formatMessageForSigning:(NSString *)message;

@end
