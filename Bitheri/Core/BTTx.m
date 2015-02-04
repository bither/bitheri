//
//  BTTx.m
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

#import "BTTx.h"
#import "BTKey.h"
#import "BTSettings.h"
#import "BTTxProvider.h"
#import "BTBlockChain.h"
#import "BTAddress.h"
#import "BTScript.h"
#import "BTScriptChunk.h"
#import "BTScriptOpCodes.h"
#import "BTIn.h"
#import "BTOut.h"
#import "BTTxProvider.h"

@implementation BTTx

+ (instancetype)transactionWithMessage:(NSData *)message
{
    return [[self alloc] initWithMessage:message];
}

- (instancetype)init
{
    if (! (self = [super init])) return nil;
    
    _txVer = TX_VERSION;
    _ins = [NSMutableArray new];
    _outs = [NSMutableArray new];

    _txLockTime = TX_LOCKTIME;
    _blockNo = TX_UNCONFIRMED;
    _txTime = (uint) [[NSDate date] timeIntervalSince1970];

    return self;
}

- (instancetype)initWithMessage:(NSData *)message
{
    if (! (self = [self init])) return nil;

    _ins = [NSMutableArray new];
    _outs = [NSMutableArray new];

    NSString *address = nil;
    NSUInteger l = 0, off = 0;
    uint64_t count = 0;
    NSData *d = nil;

    _txHash = message.SHA256_2;
    _txVer = [message UInt32AtOffset:off]; // tx version
    off += sizeof(uint32_t);
    count = [message varIntAtOffset:off length:&l]; // input count
    if (count == 0) return nil; // at least one input is required
    off += l;

    for (NSUInteger i = 0; i < count; i++) { // inputs
        BTIn *in = [BTIn new];
        d = [message hashAtOffset:off]; // input tx hash
        if (! d) return nil; // required
        in.prevTxHash = d;
        off += CC_SHA256_DIGEST_LENGTH;
        in.prevOutSn = [message UInt32AtOffset:off];
        off += sizeof(uint32_t);
        in.inScript = nil;
        d = [message dataAtOffset:off length:&l];
        in.inSignature = d ?: nil;
        off += l;
        in.inSequence = [message UInt32AtOffset:off];
        in.tx = self;
        in.inSn = self.ins.count;
        [self.ins addObject:in];
        off += sizeof(uint32_t);
    }

    count = [message varIntAtOffset:off length:&l]; // output count
    off += l;
    
    for (NSUInteger i = 0; i < count; i++) { // outputs
        BTOut *out = [BTOut new];
        out.outValue = [message UInt64AtOffset:off];
        off += sizeof(uint64_t);
        d = [message dataAtOffset:off length:&l];
        out.outScript = d ?: nil;
        off += l;
        address = [[[BTScript alloc] initWithProgram:d] getToAddress];
        out.outAddress = address ?: nil;
        out.tx = self;
        out.outSn = self.outs.count;
        [self.outs addObject:out];
    }
    
    _txLockTime = [message UInt32AtOffset:off]; // tx locktime
    
    return self;
}

- (void)addInputHash:(NSData *)hash index:(NSUInteger)index script:(NSData *)script
{
    [self addInputHash:hash index:index script:script signature:nil sequence:TX_IN_SEQUENCE];
}

- (void)addInputHash:(NSData *)hash index:(NSUInteger)index script:(NSData *)script signature:(NSData *)signature
sequence:(uint32_t)sequence
{
    BTIn *in = [BTIn new];
    in.prevTxHash = hash;
    in.prevOutSn = index;
    in.inScript = script;
    in.inSignature = signature;
    in.inSequence = sequence;
    in.tx = self;
    in.inSn = self.ins.count;
    [self.ins addObject:in];
}

- (void)clearIns;{
    [self.ins removeAllObjects];
}

- (void)addOutputAddress:(NSString *)address amount:(uint64_t)amount
{
    BTOut *out = [BTOut new];
    out.outValue = amount;
    out.outAddress = address;
    NSMutableData *scriptPubKey = [NSMutableData data];
    [scriptPubKey appendScriptPubKeyForAddress:address];
    out.outScript = scriptPubKey;
    out.tx = self;
    out.outSn = self.outs.count;
    [self.outs addObject:out];
}

- (void)addOutputScript:(NSData *)script amount:(uint64_t)amount;
{
    BTOut *out = [BTOut new];
    NSString *address = [NSString addressWithScript:script];
    out.outValue = amount;
    out.outScript = script;
    out.outAddress = address ?: nil;
    out.tx = self;
    out.outSn = self.outs.count;
    [self.outs addObject:out];
}

- (void)setInputAddress:(NSString *)address atIndex:(NSUInteger)index;
{
    BTIn *in = self.ins[index];
    NSMutableData *d = [NSMutableData data];
    [d appendScriptPubKeyForAddress:address];
    in.inScript = d;
}

- (NSArray *)inputAddresses
{
    NSMutableArray *addresses = [NSMutableArray arrayWithCapacity:self.ins.count];

    for (NSUInteger i = 0; i < self.ins.count; i++) {
        BTIn *in = self.ins[i];
        NSString *addr = [NSString addressWithScript:in.inScript];

        if (addr) {
            [addresses addObject:addr];
        } else {
            NSData *signature = in.inSignature;
            if (signature != (id) [NSNull null]){
                BTScript *script = [[BTScript alloc] initWithProgram:signature];
                if (script != nil) {
                    NSString *address = script.getFromAddress;
                    if (address != nil){
                        [addresses addObject:address];
                        continue;
                    }
                }
            }
            [addresses addObject:[NSNull null]];
        }
    }

    return addresses;
}

- (NSArray *)inputHashes
{
    NSMutableArray *result = [NSMutableArray new];
    for (BTIn *in in self.ins) {
        [result addObject:in.prevTxHash];
    }
    return result;
}

- (NSArray *)inputIndexes
{
    NSMutableArray *result = [NSMutableArray new];
    for (BTIn *in in self.ins) {
        [result addObject:@(in.prevOutSn)];
    }
    return result;
}

- (NSArray *)inputScripts
{
    NSMutableArray *result = [NSMutableArray new];
    for (BTIn *in in self.ins) {
        [result addObject:in.inScript ?: [NSNull null]];
    }
    return result;
}

- (NSArray *)inputSignatures
{
    NSMutableArray *result = [NSMutableArray new];
    for (BTIn *in in self.ins) {
        [result addObject:in.inSignature ?: [NSNull null]];
    }
    return result;
}

- (NSArray *)inputSequences
{
    NSMutableArray *result = [NSMutableArray new];
    for (BTIn *in in self.ins) {
        [result addObject:@(in.inSequence)];
    }
    return result;
}

- (NSArray *)outputAmounts
{
    NSMutableArray *result = [NSMutableArray new];
    for (BTOut *out in self.outs) {
        [result addObject:@(out.outValue)];
    }
    return result;
}

- (NSArray *)outputAddresses
{
    NSMutableArray *result = [NSMutableArray new];
    for (BTOut *out in self.outs) {
        [result addObject:out.outAddress ?: [NSNull null]];
    }
    return result;
}

- (NSArray *)outputScripts
{
    NSMutableArray *result = [NSMutableArray new];
    for (BTOut *out in self.outs) {
        [result addObject:out.outScript];
    }
    return result;
}

- (NSArray *)inValues {
    return [[BTTxProvider instance] txInValues:self.txHash];
}

//TODO: support signing pay2pubkey outputs (typically used for coinbase outputs)
- (BOOL)signWithPrivateKeys:(NSArray *)privateKeys
{
    NSMutableArray *addresses = [NSMutableArray arrayWithCapacity:privateKeys.count],
                   *keys = [NSMutableArray arrayWithCapacity:privateKeys.count];
    
    for (NSString *pk in privateKeys) {
        BTKey *key = [BTKey keyWithPrivateKey:pk];

        if (! key) continue;
 
        [keys addObject:key];
        [addresses addObject:key.hash160];
    }

    for (NSUInteger i = 0; i < self.ins.count; i++) {
        BTIn *in = self.ins[i];
        NSUInteger keyIdx = [addresses indexOfObject:[in.inScript
                             subdataWithRange:NSMakeRange([in.inScript length] - 22, 20)]];

        if (keyIdx == NSNotFound) continue;
    
        NSMutableData *sig = [NSMutableData data];
        NSData *hash = [self toDataWithSubscriptIndex:i].SHA256_2;
        NSMutableData *s = [NSMutableData dataWithData:[keys[keyIdx] sign:hash]];

        [s appendUInt8:SIG_HASH_ALL];
        [sig appendScriptPushData:s];
        [sig appendScriptPushData:[keys[keyIdx] publicKey]];

        in.inSignature = sig;
    }
    
    if (! [self isSigned]) return NO;
    
    _txHash = self.data.SHA256_2;
    // update in & out 's tx hash
    for (BTIn *in in self.ins) {
        in.txHash = _txHash;
    }
    for (BTOut *out in self.outs) {
        out.txHash = _txHash;
    }
        
    return YES;
}

// checks if all signatures exist, but does not verify them
- (BOOL)isSigned
{
    if (self.ins.count > 0) {
        for (BTIn *in in self.ins) {
            if (in.inSignature == nil) {
                return NO;
            }
        }
        return YES;
    }
    return NO;
//    return (self.signatures.count > 0 && self.signatures.count == self.ins.count &&
//            ! [self.signatures containsObject:[NSNull null]]);
}

- (BOOL)verifySignatures;{
    if ([self isSigned]) {
        NSMutableArray *inScripts = [NSMutableArray new];
        NSMutableArray *keys = [NSMutableArray new];
        NSMutableArray *scripts = [NSMutableArray new];
        for (BTIn *in in self.ins) {
            BTScript *script = [[BTScript alloc] initWithProgram:in.inSignature];
            if (script == nil)
                return NO;
            NSString *address = script.getFromAddress;
            if (address == nil)
                return NO;
            NSMutableData *d = [NSMutableData data];
            [d appendScriptPubKeyForAddress:address];
            [inScripts addObject:d];
            [keys addObject:[BTKey keyWithPublicKey:[script getPubKey]]];
            in.inScript = d;
            [scripts addObject:script];
        }
        for (NSUInteger i = 0; i < self.ins.count; i++) {
            NSData *unSignHash = [self toDataWithSubscriptIndex:i withInScripts:inScripts].SHA256_2;
//            NSData *unSignHash2 = [self toDataWithSubscriptIndex:i].SHA256_2;
            BTKey *key = keys[i];
            NSData *signedHash = ((BTScriptChunk *)((BTScript *)scripts[i]).chunks[0]).data;
            if (![key verify:unSignHash signature:signedHash])
                return NO;
        }
        return YES;
    } else {
        return NO;
    }
}

// Returns the binary transaction data that needs to be hashed and signed with the private key for the tx input at
// subscriptIndex. A subscriptIndex of NSNotFound will return the entire signed transaction
- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex
{
    NSMutableData *d = [NSMutableData dataWithCapacity:self.size];

    [d appendUInt32:self.txVer];
    [d appendVarInt:self.ins.count];

    NSUInteger i = 0;
    for (BTIn *in in self.ins) {
        [d appendData:in.prevTxHash];
        [d appendUInt32:in.prevOutSn];

        if ([self isSigned] && subscriptIndex == NSNotFound) {
            [d appendVarInt:[in.inSignature length]];
            [d appendData:in.inSignature];
        }
        else if (i == subscriptIndex) {
            //TODO: to fully match the reference implementation, OP_CODESEPARATOR related checksig logic should go here
            [d appendVarInt:[in.inScript length]];
            [d appendData:in.inScript];
        }
        else [d appendVarInt:0];
        
        [d appendUInt32:in.inSequence];
        i++;
    }
    
    [d appendVarInt:self.outs.count];
    
    for (BTOut *out in self.outs) {
        [d appendUInt64:out.outValue];
        [d appendVarInt:out.outScript.length];
        [d appendData:out.outScript];
    }

    [d appendUInt32:self.txLockTime];
    
    if (subscriptIndex != NSNotFound) {
        [d appendUInt32:SIG_HASH_ALL];
    }
    
    return d;
}

- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex withInScripts:(NSArray *)inScripts;
{
    NSMutableData *d = [NSMutableData dataWithCapacity:self.size];

    [d appendUInt32:self.txVer];
    [d appendVarInt:self.ins.count];

    NSUInteger i = 0;
    for (BTIn *in in self.ins) {
        [d appendData:in.prevTxHash];
        [d appendUInt32:in.prevOutSn];

        if ([self isSigned] && subscriptIndex == NSNotFound) {
            [d appendVarInt:in.inSignature.length];
            [d appendData:in.inSignature];
        }
        else if (i == subscriptIndex) {
            //TODO: to fully match the reference implementation, OP_CODESEPARATOR related checksig logic should go here
            [d appendVarInt:[inScripts[i] length]];
            [d appendData:inScripts[i]];
        }
        else [d appendVarInt:0];

        [d appendUInt32:in.inSequence];
        i++;
    }

    [d appendVarInt:self.outs.count];

    for (BTOut *out in self.outs) {
        [d appendUInt64:out.outValue];
        [d appendVarInt:out.outScript.length];
        [d appendData:out.outScript];
    }

    [d appendUInt32:self.txLockTime];

    if (subscriptIndex != NSNotFound) {
        [d appendUInt32:SIG_HASH_ALL];
    }

    return d;
}

- (NSData *)toData
{
    return [self toDataWithSubscriptIndex:NSNotFound];
}

- (size_t)size
{
    //TODO: not all keys come from this wallet (private keys can be swept), might cause a lower than standard tx fee
    size_t sigSize = 149; // electrum seeds generate uncompressed keys, bip32 uses compressed
//    size_t sigSize = 181;

    return (size_t) (8 + [NSMutableData sizeOfVarInt:self.ins.count] + [NSMutableData sizeOfVarInt:self.outs.count] +
               sigSize*self.ins.count + 34*self.outs.count);
}

// priority = sum(input_amount_in_satoshis*input_age_in_blocks)/size_in_bytes
- (uint64_t)priorityForAmounts:(NSArray *)amounts withAges:(NSArray *)ages
{
    uint64_t p = 0;
    
    if (amounts.count != self.ins.count || ages.count != self.ins.count || [ages containsObject:@(0)]) return 0;
    
    for (NSUInteger i = 0; i < amounts.count; i++) {    
        p += [amounts[i] unsignedLongLongValue]*[ages[i] unsignedLongLongValue];
    }
    
    return p/self.size;
}

// the block height after which the transaction can be confirmed without a fee, or TX_UNCONFIRMRED for never
- (uint32_t)blockHeightUntilFreeForAmounts:(NSArray *)amounts withBlockHeights:(NSArray *)heights
{
    if (amounts.count != self.ins.count || heights.count != self.ins.count ||
        self.size > TX_FREE_MAX_SIZE || [heights containsObject:@(TX_UNCONFIRMED)]) {
        return TX_UNCONFIRMED;
    }

    for (BTOut *out in self.outs) {
        if (out.outValue < TX_MIN_OUTPUT_AMOUNT) return TX_UNCONFIRMED;
    }

    uint64_t amountTotal = 0, amountsByHeights = 0;
    
    for (NSUInteger i = 0; i < amounts.count; i++) {
        amountTotal += [amounts[i] unsignedLongLongValue];
        amountsByHeights += [amounts[i] unsignedLongLongValue]*[heights[i] unsignedLongLongValue];
    }
    
    if (amountTotal == 0) return TX_UNCONFIRMED;
    
    // this could possibly overflow a uint64 for very large input amounts and far in the future block heights,
    // however we should be okay up to the largest current bitcoin balance in existence for the next 40 years or so,
    // and the worst case is paying a transaction fee when it's not needed
    return (uint32_t)((TX_FREE_MIN_PRIORITY*(uint64_t)self.size + amountsByHeights + amountTotal - 1llu)/amountTotal);
}

- (uint64_t)standardFee
{
    return ((self.size + 999) / 1000) * TX_FEE_PER_KB;
}

- (void)sawByPeer;{
    [[BTTxProvider instance] txSentBySelfHasSaw:self.txHash];
    self.sawByPeerCnt += 1;
}

// returns the fee for the given transaction if all its inputs are from wallet transactions, UINT64_MAX otherwise
- (uint64_t)feeForTransaction;{
    uint64_t amount = 0;
    NSUInteger i = 0;

    for (NSData *hash in self.inputHashes) {
        BTTx *tx = [[BTTxProvider instance] getTxDetailByTxHash:hash];
        uint32_t n = [self.inputIndexes[i++] unsignedIntValue];

        if (n >= tx.outputAmounts.count) return UINT64_MAX;
        amount += [tx.outputAmounts[n] unsignedLongLongValue];
    }

    for (NSNumber *amt in self.outputAmounts) {
        amount -= amt.unsignedLongLongValue;
    }

    return amount;
}

// Returns the block height after which the transaction is likely to be processed without including a fee. This is based
// on the default satoshi client settings, but on the real network it's way off. In testing, a 0.01btc transaction that
// was expected to take an additional 90 days worth of blocks to confirm was confirmed in under an hour by Eligius pool.
- (uint32_t)blockHeightUntilFree; {
    // TODO: calculate estimated time based on the median priority of free transactions in last 144 blocks (24hrs)
    NSMutableArray *amounts = [NSMutableArray array], *heights = [NSMutableArray array];
    NSUInteger i = 0;

    for (NSData *hash in self.inputHashes) { // get the amounts and block heights of all the transaction inputs
        BTTx *tx = [[BTTxProvider instance] getTxDetailByTxHash:hash];
        uint32_t n = [self.inputIndexes[i++] unsignedIntValue];

        if (n >= tx.outputAmounts.count) break;
        [amounts addObject:tx.outputAmounts[n]];
        [heights addObject:@(tx.blockNo)];
    };

    return [self blockHeightUntilFreeForAmounts:amounts withBlockHeights:heights];
}

// returns the amount received to the wallet by the transaction (total outputs to change and/or recieve addresses)
- (uint64_t)amountReceivedFrom:(BTAddress *)addr;{
    uint64_t amount = 0;
    NSUInteger n = 0;

    for (NSString *address in self.outputAddresses) {
        if ([addr.address isEqualToString:address])
            amount += [self.outputAmounts[n] unsignedLongLongValue];
        n++;
    }

    return amount;
}

// returns the amount sent from the wallet by the transaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentFrom:(BTAddress *)addr;{
    uint64_t amount = 0;
    NSUInteger i = 0;

    for (NSData *hash in self.inputHashes) {
        BTTx *tx = [[BTTxProvider instance] getTxDetailByTxHash:hash];
        uint32_t n = [self.inputIndexes[i++] unsignedIntValue];

        if (n < tx.outputAddresses.count && [addr.address isEqualToString:tx.outputAddresses[n]]) {
            amount += [tx.outputAmounts[n] unsignedLongLongValue];
        }
    }

    return amount;
}

- (uint64_t)amountSentTo:(NSString *)addr;{
    uint64_t amount = 0;
    NSUInteger n = 0;

    for (NSString *address in self.outputAddresses) {
        if ([addr isEqualToString:address])
            amount += [self.outputAmounts[n] unsignedLongLongValue];
        n++;
    }

    return amount;
}

- (int64_t)deltaAmountFrom:(BTAddress *)addr;{
    uint64_t receive = 0;
    uint64_t sent = 0;
    NSUInteger i = 0;

    for (NSString *address in self.outputAddresses) {
        if ([addr.address isEqualToString:address])
            receive += [self.outputAmounts[i] unsignedLongLongValue];
        i++;
    }
    sent=[[BTTxProvider instance] sentFromAddress:self.txHash address:addr.address];
    return receive - sent;
}

- (uint)confirmationCnt;{
    if (self.blockNo == TX_UNCONFIRMED){
        return 0;
    } else {
        return [[BTBlockChain instance] lastBlock].blockNo - self.blockNo + 1;
    }
}

- (NSArray *)unsignedInHashes;{
    NSMutableArray *result = [NSMutableArray new];
    for (NSUInteger i = 0; i < self.ins.count; i++) {
        [result addObject:[self toDataWithSubscriptIndex:i].SHA256_2];
    }
    return result;
}

- (BOOL)signWithSignatures:(NSArray *)signatures;{
    for (NSUInteger i = 0; i < signatures.count; i++) {
        BTIn *in = self.ins[i];
        in.inSignature = signatures[i];
    }
    if (![self isSigned])
        return NO;

    _txHash = self.data.SHA256_2;
    // update in & out 's tx hash
    for (BTIn *in in self.ins) {
        in.txHash = _txHash;
    }
    for (BTOut *out in self.outs) {
        out.txHash = _txHash;
    }

    return YES;
}

- (NSUInteger)hash
{
    if (self.txHash.length < sizeof(NSUInteger)) return [super hash];
    return *(const NSUInteger *)self.txHash.bytes;
}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[BTTx class]]) {
        DDLogVerbose(@"object is not instance of BTTxItem");
        return NO;
    }
    BTTx *item = (BTTx *) object;
    if ((self.blockNo == item.blockNo) && [self.txHash isEqualToData:item.txHash] && self.source == item.source
            && self.sawByPeerCnt == item.sawByPeerCnt && self.txTime == item.txTime && self.txVer == item.txVer
            && self.txLockTime == item.txLockTime) {
        if (self.ins.count != item.ins.count){
            DDLogVerbose(@"ins count is not match");
            return NO;
        }
        if (self.outs.count != item.outs.count){
            DDLogVerbose(@"outs count is not match");
            return NO;
        }
        for (NSUInteger i = 0; i < self.ins.count; i++) {
            if (![self.ins[i] isEqual:item.ins[i]]){
                DDLogVerbose(@"ins[%lu] is not match", i);
                return NO;
            }
        }
        for (NSUInteger i = 0; i < self.outs.count; i++) {
            if (![self.outs[i] isEqual:item.outs[i]]){
                DDLogVerbose(@"outs[%lu] is not match", (unsigned long)i);
                return NO;
            }
        }
        return YES;
    } else {
//        DDLogVerbose(@"tx base info is not match");
        return NO;
    }
}

- (NSData *) hashForSignature:(NSUInteger) inputIndex connectedScript:(NSData *) connectedScript sigHashType:(uint8_t) sigHashType; {
    NSMutableArray *inputHashes = [NSMutableArray arrayWithArray:self.inputHashes];
    NSMutableArray *inputIndexes = [NSMutableArray arrayWithArray:self.inputIndexes];
    NSMutableArray *inputScripts = [NSMutableArray arrayWithArray:self.inputScripts];
    NSMutableArray *inputSignatures = [NSMutableArray arrayWithArray:self.inputSignatures];
    NSMutableArray *inputSequences = [NSMutableArray arrayWithArray:self.inputSequences];
    NSMutableArray *outputScripts = [NSMutableArray arrayWithArray:self.outputScripts];
    NSMutableArray *outputAmounts = [NSMutableArray arrayWithArray:self.outputAmounts];
    for (NSUInteger i = 0; i < inputHashes.count; i++){
        inputScripts[i] = [NSData data];
    }
    if (connectedScript != nil) {
        NSMutableData *codeSeparator = [NSMutableData secureData];
        [codeSeparator appendUInt8:OP_CODESEPARATOR];
        connectedScript = [BTScript removeAllInstancesOf:connectedScript and:codeSeparator];
        inputScripts[inputIndex] = connectedScript;
    } else {
        inputScripts[inputIndex] = self.inputScripts[inputIndex];
    }


    if ((sigHashType & 0x1f) == 2) {
        outputScripts = [NSMutableArray new];
        for (NSUInteger i = 0; i < inputHashes.count; i++) {
            if (i != inputIndex) {
                inputSequences[i] = @0;
            }
        }
    } else if ((sigHashType & 0x1f) == 3) {
        if (inputIndex >= outputScripts.count) {
            // Satoshis bug is that SignatureHash was supposed to return a hash and on this codepath it
            // actually returns the constant "1" to indicate an error, which is never checked for. Oops.
            return [@"0100000000000000000000000000000000000000000000000000000000000000" hexToData];
        }
        outputAmounts = [NSMutableArray arrayWithArray:[outputAmounts subarrayWithRange:NSMakeRange(0, inputIndex + 1)]];
        outputScripts = [NSMutableArray arrayWithArray:[outputScripts subarrayWithRange:NSMakeRange(0, inputIndex + 1)]];

        for (NSUInteger i = 0; i < inputIndex; i++) {
            outputAmounts[i] = @0xffffffffffffffff;
            outputScripts[i] = [NSData data];
        }
        for (NSUInteger i = 0; i < inputHashes.count; i++){
            if (i != inputIndex) {
                inputSequences[i] = @0;
            }
        }
    }

    if ((sigHashType & 0x80) == 0x80) {
        // SIGHASH_ANYONECANPAY means the signature in the input is not broken by changes/additions/removals
        // of other inputs. For example, this is useful for building assurance contracts.
        inputHashes = [NSMutableArray arrayWithArray:@[inputHashes[inputIndex]]];
        inputIndexes = [NSMutableArray arrayWithArray:@[inputIndexes[inputIndex]]];
        inputScripts = [NSMutableArray arrayWithArray:@[inputScripts[inputIndex]]];
        inputSignatures = [NSMutableArray arrayWithArray:@[inputSignatures[inputIndex]]];
        inputSequences = [NSMutableArray arrayWithArray:@[inputSequences[inputIndex]]];
    }

    NSMutableData *d = [NSMutableData secureData];

    [d appendUInt32:self.txVer];
    [d appendVarInt:inputHashes.count];

    for (NSUInteger i = 0; i < inputHashes.count; i++) {
        [d appendData:inputHashes[i]];
        [d appendUInt32:[inputIndexes[i] unsignedIntValue]];
        [d appendVarInt:[inputScripts[i] length]];
        [d appendData:inputScripts[i]];
        [d appendUInt32:[inputSequences[i] unsignedIntValue]];
    }

    [d appendVarInt:outputAmounts.count];

    for (NSUInteger i = 0; i < outputAmounts.count; i++) {
        [d appendUInt64:[outputAmounts[i] unsignedLongLongValue]];
        [d appendVarInt:[outputScripts[i] length]];
        [d appendData:outputScripts[i]];
    }

    [d appendUInt32:self.txLockTime];

    if (inputIndex != NSNotFound) {
        [d appendUInt32:sigHashType];
    }

    return [d SHA256_2];
}

- (BOOL)verify; {
    if (self.inputHashes.count == 0 || self.outputAmounts.count == 0)
        return NO;

//    if (this.getMessageSize() > Block.MAX_BLOCK_SIZE)
//        throw new VerificationException("Transaction larger than MAX_BLOCK_SIZE");
    uint64_t valueOut = 0;
    for (NSNumber *outAmount in self.outputAmounts) {
        // amount < 0
        uint64_t outAmountValue = [outAmount unsignedLongLongValue];
        if (outAmountValue > 2100000000000000)
            return NO;
        valueOut += outAmountValue;
    }
    BOOL isCoinBase = NO;
    BTIn *firstIn = self.ins[0];
    if (self.inputHashes.count == 1 && [self.inputHashes[0] isEqualToData:[@"0000000000000000000000000000000000000000000000000000000000000000" hexToData]]
            && firstIn.prevOutSn == 0xFFFFFFFFL) {
        isCoinBase = YES;
    }

    if (isCoinBase) {
        if ( ((NSData *)self.inputSignatures[0]).length < 2 || ((NSData *)self.inputSignatures[0]).length > 100)
            return NO;
    } else {
        for (NSData *inputHash in self.inputHashes) {
            if ([inputHash isEqualToData:[@"0000000000000000000000000000000000000000000000000000000000000000" hexToData]]
                    && firstIn.prevOutSn == 0xFFFFFFFFL)
                return NO;
        }
    }
    NSMutableSet *prevOutSet = [NSMutableSet new];
    for (NSUInteger i = 0; i < self.inputIndexes.count; i++) {
        NSMutableData *d = [NSMutableData dataWithCapacity:CC_SHA256_DIGEST_LENGTH + sizeof(uint32_t)];
        [d appendData:self.inputHashes[i]];
        [d appendUInt32:[self.inputIndexes[i] unsignedIntValue]];
        if ([prevOutSet containsObject:d]) {
            return NO;
        } else {
            [prevOutSet addObject:d];
        }
    }

    return YES;
}

- (void)setInScript:(NSData *)script forInHash:(NSData *)inHash andInIndex:(NSUInteger) inIndex;{
    for (BTIn *in in self.ins) {
        if ([in.prevTxHash isEqualToData:inHash] && in.prevOutSn == inIndex) {
            in.inScript = script;
        }
    }
}

- (BOOL)hasDustOut; {
    for (BTOut *out in self.outs) {
        if (out.outValue <= TX_MIN_OUTPUT_AMOUNT) {
            return YES;
        }
    }
    return NO;
}
@end
