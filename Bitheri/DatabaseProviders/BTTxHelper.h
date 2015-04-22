//
// Created by noname on 15/4/22.
// Copyright (c) 2015 Bither. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BTTx.h"
#import "BTIn.h"
#import "BTOut.h"
#import "BTDatabaseManager.h"


@interface BTTxHelper : NSObject

+(BTTx *)format:(FMResultSet *)rs;
+ (BTIn *)formatIn:(FMResultSet *)rs;
+ (BTOut *)formatOut:(FMResultSet *)rs;
@end