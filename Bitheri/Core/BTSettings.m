//
//  BTSettings.m
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

#import "BTSettings.h"
#import "BTCompressingLogFileManager.h"
#import <CocoaLumberjack/DDTTYLogger.h>

#define APP_MODE @"app_mode"

@implementation BTSettings {

}

+ (instancetype)instance {
    static BTSettings *settings = nil;
    static dispatch_once_t one;

    dispatch_once(&one, ^{
        settings = [[BTSettings alloc] init];
    });
    return settings;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;

    _feeBase = 10000;
    _ensureMinRequiredFee = YES;
    _maxPeerConnections = 6;
    _maxBackgroundPeerConnections = 2;

    BTCompressingLogFileManager *logFileManager = [[BTCompressingLogFileManager alloc] init];
    DDFileLogger *fileLogger = [[DDFileLogger alloc] initWithLogFileManager:logFileManager];
    fileLogger.maximumFileSize = 0;
    fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
    fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
    [DDLog addLogger:fileLogger];

    [[DDTTYLogger sharedInstance] setForegroundColor:[UIColor blackColor] backgroundColor:nil forFlag:LOG_FLAG_VERBOSE];
    [[DDTTYLogger sharedInstance] setForegroundColor:[UIColor colorWithRed:104 / 255.0 green:130 / 255.0 blue:228 / 255.0 alpha:1.0] backgroundColor:nil forFlag:LOG_FLAG_INFO];
    [[DDTTYLogger sharedInstance] setForegroundColor:[UIColor colorWithRed:111 / 255.0 green:188 / 255.0 blue:80 / 255.0 alpha:1.0] backgroundColor:nil forFlag:LOG_FLAG_DEBUG];
    [[DDTTYLogger sharedInstance] setForegroundColor:[UIColor colorWithRed:241 / 255.0 green:201 / 255.0 blue:9 / 255.0 alpha:1.0] backgroundColor:nil forFlag:LOG_FLAG_WARN];
    [[DDTTYLogger sharedInstance] setForegroundColor:[UIColor colorWithRed:223 / 255.0 green:108 / 255.0 blue:108 / 255.0 alpha:1.0] backgroundColor:nil forFlag:LOG_FLAG_ERROR];
    [[DDTTYLogger sharedInstance] setColorsEnabled:YES];

    return self;
}


- (BOOL)needChooseMode {
    return [[NSUserDefaults standardUserDefaults] objectForKey:APP_MODE] == nil;
}

- (AppMode)getAppMode {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:APP_MODE] == nil) {
        return NoChoose;
    }
    return (AppMode) [[NSUserDefaults standardUserDefaults] integerForKey:APP_MODE];
}

- (void)setAppMode:(AppMode)appMode {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setInteger:appMode forKey:APP_MODE];
    [userDefaults synchronize];
}

- (void)openBitheriConsole; {
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
}

@end