//
//  BTUtils.m
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

#import "BTUtils.h"

@implementation NSDate (compare)

- (NSComparisonResult)doubleCompare:(NSDate *)other {
    double myValue = [self timeIntervalSince1970];
    double otherValue = [other timeIntervalSince1970];
    if (myValue == otherValue) return NSOrderedSame;
    return (myValue > otherValue ? NSOrderedAscending : NSOrderedDescending);
}
@end

@implementation BTUtils

+ (NSString *)documentsPathForFileName:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = paths[0];
    return [documentsPath stringByAppendingPathComponent:fileName];
}


+ (NSString *)readFile:(NSString *)fileFullName {
    NSData *reader = [NSData dataWithContentsOfFile:fileFullName];
    return [[NSString alloc] initWithData:reader
                                 encoding:NSUTF8StringEncoding];

}

+ (void)writeFile:(NSString *)fileName content:(NSString *)content {
    [content writeToFile:fileName atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

+ (void)removeFile:(NSString *)fileName {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:fileName error:nil];
}

+ (BOOL)setModifyDateToFile:(NSDate *)date forFile:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        return NO;
    }
    else {
        NSDictionary *attr = @{NSFileModificationDate : date};
        [[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:path error:NULL];
    }
    return YES;

}

+ (NSArray *)filesByModDate:(NSString *)fullPath {
    NSError *error = nil;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:fullPath
                                                                         error:&error];
    if (error == nil) {
        NSMutableDictionary *filesAndProperties = [NSMutableDictionary dictionaryWithCapacity:[files count]];
        for (NSString *path in files) {
            NSDictionary *properties = [[NSFileManager defaultManager]
                    attributesOfItemAtPath:[fullPath stringByAppendingPathComponent:path]
                                     error:&error];
            NSDate *modDate = properties[NSFileModificationDate];
            if (error == nil) {
                [filesAndProperties setValue:modDate forKey:path];
            }
        }
        return [filesAndProperties keysSortedByValueUsingSelector:@selector(doubleCompare:)];
    }
    return [NSArray new];
}

+ (void)createDir:(NSString *)dir {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:dir]) {
        [fileManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];

    }
}

+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL {
    NSError *error;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[URL path]]) {
        NSNumber *excluded = nil;
        [URL getResourceValue:&excluded forKey:NSURLIsExcludedFromBackupKey error:&error];
        if (excluded) {
            return YES;
        } else {
            BOOL success = [URL setResourceValue:@YES
                                          forKey:NSURLIsExcludedFromBackupKey error:&error];
            if (!success) {
                NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
            }
            return success;
        }
    } else {
        return NO;
    }
}

+ (NSString *)getPrivDir {
    NSString *privDir;
    if ([[BTSettings instance] getAppMode] == COLD) {
        privDir = [self documentsPathForFileName:COLD_DIR];
    } else {
        privDir = [self documentsPathForFileName:HOT_DIR];
    }
    [self createDir:privDir];
    [self addSkipBackupAttributeToItemAtURL:[NSURL fileURLWithPath:privDir]];
    return privDir;

}

+ (NSString *)getWatchOnlyDir {
    NSString *watchOnlyDir = [self documentsPathForFileName:WATCHONLY_DIR];
    [self createDir:watchOnlyDir];
    return watchOnlyDir;
}

@end
