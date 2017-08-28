//
//  BTSettings.h
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
#import "CocoaLumberjack/DDLog.h"
#import "Bitheri.h"

// tx
#define CENT 1000000

#define TX_FREE_MAX_SIZE     1000llu     // tx must not be larger than this size in bytes without a fee
#define TX_FREE_MIN_PRIORITY 57600000llu // tx must not have a priority below this value without a fee
#define TX_MAX_SIZE          100000llu   // no tx can be larger than this size in bytes
#define TX_MIN_OUTPUT_AMOUNT 5460llu     // no tx output can be below this amount (or it won't be relayed)
#define TX_UNCONFIRMED       UINT32_MAX   // block height indicating transaction is unconfirmed

#define TX_VERSION    0x00000001u
#define TX_LOCKTIME   0x00000000u
#define TX_IN_SEQUENCE UINT32_MAX
#define COMPRESS_OUT_NUM 5
#define TX_PAGE_SIZE 20

#define SIG_HASH_ALL    0x00000001u
#define SIG_HASH_NONE   0x00000002u
#define SIG_HASH_SINGLE 0x00000003u
#define SIG_HASH_ANYONECANPAY   0x00000080u

// peer manager

#define NODE_BITCOIN_CASH     1 << 5
#define MAX_PEERS_COUNT       100
#define NODE_NETWORK          1  // services value indicating a node offers full blocks, not just headers
#define PROTOCOL_TIMEOUT      30.0
#define MAX_CONNECT_FAILURE_COUNT 20 // notify user of network problems after this many connect failures in a row

#define ONE_WEEK            604800

// peer
#if BITCOIN_TESTNET
    #define BITCOIN_STANDARD_PORT          18333
    #define BITCOIN_REFERENCE_BLOCK_HEIGHT 150000
    #define BITCOIN_REFERENCE_BLOCK_TIME   (1386098130.0 - NSTimeIntervalSince1970)
#else
#define BITCOIN_STANDARD_PORT          8333
#define BITCOIN_REFERENCE_BLOCK_HEIGHT 250000
#define BITCOIN_REFERENCE_BLOCK_TIME   (1375533383.0 - NSTimeIntervalSince1970)
#endif

// error
#define ERR_PEER_TIMEOUT_CODE            1001
#define ERR_PEER_DISCONNECT_CODE         500
#define ERR_PEER_RELAY_TO_MUCH_UNRELAY_TX         501
#define ERR_TX_DUST_OUT_CODE                 2001
#define ERR_TX_NOT_ENOUGH_MONEY_CODE                 2002
#define ERR_TX_WAIT_CONFIRM_CODE                 2003
#define ERR_TX_CAN_NOT_CALCULATE_CODE                 2004
#define ERR_TX_MAX_SIZE_CODE    2005

#define ERR_TX_WAIT_CONFIRM_AMOUNT @"ERR_TX_WAIT_CONFIRM_AMOUNT"
#define ERR_TX_NOT_ENOUGH_MONEY_LACK @"ERR_TX_NOT_ENOUGH_MONEY_LACK"

#pragma mark - message header
// explanation of message types at: https://en.bitcoin.it/wiki/Protocol_specification
#define MSG_VERSION     @"version"
#define MSG_VERACK      @"verack"
#define MSG_ADDR        @"addr"
#define MSG_INV         @"inv"
#define MSG_GETDATA     @"getdata"
#define MSG_NOTFOUND    @"notfound"
#define MSG_GETBLOCKS   @"getblocks"
#define MSG_GETHEADERS  @"getheaders"
#define MSG_TX          @"tx"
#define MSG_BLOCK       @"block"
#define MSG_HEADERS     @"headers"
#define MSG_GETADDR     @"getaddr"
#define MSG_MEMPOOL     @"mempool"
#define MSG_CHECKORDER  @"checkorder"
#define MSG_SUBMITORDER @"submitorder"
#define MSG_REPLY       @"reply"
#define MSG_PING        @"ping"
#define MSG_PONG        @"pong"
#define MSG_FILTERLOAD  @"filterload"
#define MSG_FILTERADD   @"filteradd"
#define MSG_FILTERCLEAR @"filterclear"
#define MSG_MERKLEBLOCK @"merkleblock"
#define MSG_ALERT       @"alert"
#define MSG_REJECT      @"reject" // described in BIP61: https://gist.github.com/gavinandresen/7079034

#define BITHERI_VERSION @"1.6.5"
#define BITHERI_NAME @"Bitheri"
#define USERAGENT [NSString stringWithFormat:@"/Bither:%@/", BITHERI_VERSION]

#define HEADER_LENGTH      24
#define MAX_MSG_LENGTH     0x02000000
#define MAX_GETDATA_HASHES 50000
#define ENABLED_SERVICES   0     // we don't provide full blocks to remote nodes
#define PROTOCOL_VERSION   70002
#define MIN_PROTO_VERSION  70001 // peers earlier than this protocol version not supported (SPV mode required)

#define LOCAL_HOST         0x7f000001
#define ZERO_HASH          @"0000000000000000000000000000000000000000000000000000000000000000".hexToData
#define CONNECT_TIMEOUT    5.0

// block chain
#if BITCOIN_TESTNET
    #define GENESIS_BLOCK_HASH @"000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943".hexToData.reverse
#else // main net
#define GENESIS_BLOCK_HASH @"000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f".hexToData.reverse
// blockchain checkpoints, these are also used as starting points for partial chain downloads, so they need to be at
// difficulty transition boundaries in order to verify the block difficulty at the immediately following transition
#endif

// block
#define BLOCK_DIFFICULTY_INTERVAL 2016      // number of blocks between difficulty target adjustments
#define BLOCK_UNKNOWN_HEIGHT       INT32_MAX

#define MAX_TIME_DRIFT    (2*60*60)     // the furthest in the future a block is allowed to be timestamped
#define MAX_PROOF_OF_WORK 0x1d00ffffu   // highest value for difficulty target (higher values are less difficult)
#define TARGET_TIMESPAN   (14*24*60*60) // the targeted timespan between difficulty target adjustments
#define MAX_UNRELATED_TX_RELAY_COUNT 1000
#define RELAY_BLOCK_COUNT_WHEN_SYNC (5)
// address
#define PRIVATE_KEY_FILE_NAME @"%@/%@.key"
#define WATCH_ONLY_FILE_NAME @"%@/%@.pub"

// notification
#define BitherBalanceChangedNotification @"BitherBalanceChangedNotification"

//address
#define VANITY_LEN_NO_EXSITS  -1

#define BTPeerManagerSyncStartedNotification  @"BTPeerManagerSyncStartedNotification"
#define BTPeerManagerSyncFinishedNotification @"BTPeerManagerSyncFinishedNotification"
#define BTPeerManagerSyncFromSPVFinishedNotification @"BTPeerManagerSyncFromSPVFinishedNotification"
#define BTPeerManagerSyncFailedNotification   @"BTPeerManagerSyncFailedNotification"
#define BTPeerManagerPeerStateNotification @"BTPeerManagerPeerStateNotification"
#define BTPeerManagerConnectedChangedNotification @"BTPeerManagerConnectedChangedNotification"
#define BTPeerManagerSyncProgressNotification @"BTPeerManagerSyncProgressNotification"

typedef enum {
    txSend = 0,
    txReceive = 2,
    txDoubleSpend = 3,
    txFromApi = 4,
} TxNotificationType;

#define BTPeerManagerLastBlockChangedNotification     @"BTPeerManagerLastBlockChangedNotification"

//key's dir
#define WATCHONLY_DIR @"watchonly"
#define HOT_DIR @"hot"
#define COLD_DIR @"cold"
#define TRASH_DIR @"trash"

#define BITCOIN_SIGNED_MESSAGE_HEADER @"Bitcoin Signed Message:\n"
#define BITCOIN_SIGNED_MESSAGE_HEADER_BYTES [BITCOIN_SIGNED_MESSAGE_HEADER dataUsingEncoding:NSUTF8StringEncoding]

typedef enum {
    NoChoose = 0,
    COLD = 1,
    HOT = 2
} AppMode;


typedef void (^IdResponseBlock)(id response);

typedef void (^VoidResponseBlock)(void);

typedef void (^ArrayResponseBlock)(NSArray *array);


#define BITHERI_LOG_FLAG NO

#if BITHERI_LOG_FLAG
#define btLog(...) NSLog(__VA_ARGS__)
#else
#define btLog(...)
#endif

#define ERROR_DOMAIN @"bitheri"

static int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface BTSettings : NSObject
+ (instancetype)instance;

@property(atomic) BOOL ensureMinRequiredFee;
@property(atomic) uint64_t feeBase;
@property(atomic) int maxPeerConnections;
@property(atomic) int maxBackgroundPeerConnections;

- (BOOL)needChooseMode;

- (AppMode)getAppMode;

- (void)setAppMode:(AppMode)appMode;

- (void)openBitheriConsole;

@end
