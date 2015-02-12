//
//  BTBloomFilterTest.m
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

#import <XCTest/XCTest.h>
#import <OpenSSL/openssl/bn.h>
#import <OpenSSL/openssl/ec.h>
#import "BTBloomFilter.h"
#import "NSString+Base58.h"
#import "BTSettings.h"
#import "BTTestHelper.h"
#import <OpenSSL/ossl_typ.h>
#import "BTKey.h"
#import "obj_mac.h"

@interface BTKeyTest : XCTestCase

@end

@implementation BTKeyTest

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [BTTestHelper setup];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSignMessage; {
    BTKey *key = [BTKey keyWithSecret:[@"0000000000000000000000000000000000000000000000000000000000000001" hexToData] compressed:YES];
    NSString *message = @"1";
    NSString *expectSignedMessage = @"IJbxSEQOQOySFCJJEAnUSOnvzTNEX0i4ENVwYrSVBCYuHvTNil+wYDwQhRtV2msKkHZMW5GiRXeDFbXIYzn1KXw=";

    NSString *signedMessage = [key signMessage:message];
    XCTAssertTrue([signedMessage isEqualToString:expectSignedMessage]);
    XCTAssertTrue([key verifyMessage:message andSignatureBase64:signedMessage]);

    message = @"1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890";
    expectSignedMessage = @"IFllaRcUZyAe3nXNWbOlKbP4BZ3dMLZ6somOreoZPOK1YTgjgFrHdczTWarKtjsdoRbP70u3C+D57yU+SOleoGI=";

    signedMessage = [key signMessage:message];
    XCTAssertTrue([signedMessage isEqualToString:expectSignedMessage]);
    XCTAssertTrue([key verifyMessage:message andSignatureBase64:signedMessage]);

    message = @"比太钱包";
    expectSignedMessage = @"Hw6ZIXQwLovmlCijSAuQs1JeVqIS2OB0hL74q0E5x2PAW0LCUIUM0nyjuasSKaYfmFlFWO0Btyx+r+MohYHirbA=";

    signedMessage = [key signMessage:message];
    XCTAssertTrue([signedMessage isEqualToString:expectSignedMessage]);
    XCTAssertTrue([key verifyMessage:message andSignatureBase64:signedMessage]);
}

- (void)testOpenSSLPointInfinity; {
    EC_POINT *key0 = [self getPubKey:[@"0000000000000000000000000000000000000000000000000000000000000000" hexToData]];
    XCTAssertEqual(1, EC_POINT_is_at_infinity(EC_GROUP_new_by_curve_name(NID_secp256k1), key0));
    EC_POINT *key1 = [self getPubKey:[@"0000000000000000000000000000000000000000000000000000000000000001" hexToData]];
    XCTAssertEqual(0, EC_POINT_is_at_infinity(EC_GROUP_new_by_curve_name(NID_secp256k1), key1));
}

- (void)testOpenSSLBN; {
    BN_CTX *ctx = BN_CTX_new();
    BN_CTX_start(ctx);

    BIGNUM *order = BN_CTX_get(ctx), *i = BN_CTX_get(ctx), *k = BN_CTX_get(ctx);
    EC_GROUP *group = EC_GROUP_new_by_curve_name(NID_secp256k1);
    EC_GROUP_get_order(group, order, ctx);

    BN_bin2bn([@"00" hexToData].bytes, 0, k);
    BN_bin2bn([@"00" hexToData].bytes, 0, i);
    BN_mod_add(k, i, k, order, ctx);

    NSMutableData *r = [NSMutableData new];
    r.length = 32;
    [r resetBytesInRange:NSMakeRange(0, 32)];
    BN_bn2bin(k, (unsigned char *)r.mutableBytes + 32 - BN_num_bytes(k));
    XCTAssertTrue([r isEqualToData:[@"0000000000000000000000000000000000000000000000000000000000000000" hexToData]]);

    BN_mod_add(k, order, k, order, ctx);
    r.length = 32;
    [r resetBytesInRange:NSMakeRange(0, 32)];
    BN_bn2bin(k, (unsigned char *)r.mutableBytes + 32 - BN_num_bytes(k));
    XCTAssertTrue([r isEqualToData:[@"0000000000000000000000000000000000000000000000000000000000000000" hexToData]]);
}

- (EC_POINT *)getPubKey:(NSData *)secret; {
    EC_KEY *_key = EC_KEY_new_by_curve_name(NID_secp256k1);
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM priv;
    const EC_GROUP *group = EC_KEY_get0_group(_key);
    EC_POINT *pub = EC_POINT_new(group);

    if (ctx) BN_CTX_start(ctx);
    BN_init(&priv);

    if (pub && ctx) {
        BN_bin2bn(secret.bytes, 32, &priv);
        if (EC_POINT_mul(group, pub, &priv, NULL, NULL, ctx)) {
            EC_KEY_set_private_key(_key, &priv);
            EC_KEY_set_public_key(_key, pub);
            EC_KEY_set_conv_form(_key, POINT_CONVERSION_COMPRESSED );
        }
    }
    BN_clear_free(&priv);
    if (ctx) BN_CTX_end(ctx);
    if (ctx) BN_CTX_free(ctx);
    return pub;
}
@end
