//
//  BTHDMKeychainRecover.m
//  Bitheri
//
//  Created by 宋辰文 on 15/1/26.
//  Copyright (c) 2015年 Bither. All rights reserved.
//

#import "BTHDMKeychainRecover.h"
#import "BTAddressProvider.h"

@implementation BTHDMKeychainRecover

+ (NSString *)RecoverPlaceHolder {
    return @"RECOVER";
}

- (instancetype)initWithColdExternalRootPub:(NSData *)coldExternalRootPub password:(NSString *)password andFetchBlock:(NSArray *(^)(NSString *password))fetchBlock {
    self = [super initWithSeedId:[[BTAddressProvider instance] addHDSeedWithMnemonicEncryptSeed:[BTHDMKeychainRecover RecoverPlaceHolder] andEncryptHDSeed:[BTHDMKeychainRecover RecoverPlaceHolder] andFirstAddress:[BTHDMKeychainRecover RecoverPlaceHolder] andIsXRandom:NO andAddressOfPs:nil]];
    if (self) {
        BTBIP32Key *coldRoot = [[BTBIP32Key alloc] initWithMasterPubKey:[NSData dataWithBytes:coldExternalRootPub.bytes length:coldExternalRootPub.length]];
        NSMutableArray *as = [[NSMutableArray alloc] init];
        NSMutableArray *uncompPubs = [[NSMutableArray alloc] init];
        if (fetchBlock) {
            NSArray *pubs = fetchBlock(password);
            if (pubs.count > 0) {
                NSData *pubFetched = ((BTHDMPubs *) pubs[0]).cold;
                NSData *pubDerived = [coldRoot deriveSoftened:((BTHDMPubs *) pubs[0]).index].pubKey;
                [coldRoot wipe];
                if (![pubFetched isEqualToData:pubDerived]) {
                    [NSException raise:@"HDM Bither ID Not Match" format:nil];
                }
            }
            for (BTHDMPubs *p in pubs) {
                if (p.isCompleted) {
                    [as addObject:[[BTHDMAddress alloc] initWithPubs:p andKeychain:self syncCompleted:NO]];
                } else {
                    [uncompPubs addObject:p];
                }
            }
        }
        if (as.count > 0) {
            [[BTAddressProvider instance] recoverHDMAddressesWithHDSeedId:self.hdSeedId andHDMAddresses:as];
            [self.allCompletedAddresses addObjectsFromArray:as];
            if (uncompPubs.count > 0) {
                [[BTAddressProvider instance] prepareHDMAddressesWithHDSeedId:self.hdSeedId andPubs:uncompPubs];
                for (BTHDMPubs *p in uncompPubs) {
                    [[BTAddressProvider instance] setHDMPubsRemoteWithHDSeedId:self.hdSeedId andIndex:p.index andPubKeyRemote:p.remote];
                }
            }
        }
    }
    return self;
}

- (BOOL)isInRecovery {
    return YES;
}
@end
