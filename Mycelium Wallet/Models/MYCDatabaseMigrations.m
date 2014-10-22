//
//  MYCDatabaseMigrations.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 21.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCDatabaseMigrations.h"
#import "MYCWalletAccount.h"
#import "MYCWallet.h"

@implementation MYCDatabaseMigrations

+ (void) registerMigrations:(MYCDatabase *)mycdatabase
{
    [mycdatabase registerMigration:@"Create MYCWalletAccounts" withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {
        return [db executeUpdate:
                @"CREATE TABLE MYCWalletAccounts("
                "accountIndex          INT PRIMARY KEY NOT NULL,"
                "label                 TEXT            NOT NULL,"
                "extendedPublicKey     TEXT            NOT NULL,"
                "confirmedAmount       INT             NOT NULL," // The sum of the unspent outputs which are confirmed and currently not spent in pending transactions.
                "pendingChangeAmount   INT             NOT NULL," // pending funds in our own change outputs
                "pendingReceivedAmount INT             NOT NULL," // pending funds from someone that are not confirmed yet
                "pendingSentAmount     INT             NOT NULL," // pending funds that we are sending
                "archived              INT             NOT NULL,"
                "current               INT             NOT NULL,"
                "externalKeyIndex      INT             NOT NULL,"
                "internalKeyIndex      INT             NOT NULL,"
                "internalKeyStartingIndex  INT         NOT NULL,"
                "syncTimestamp         DATETIME                 "
                ")"];
    }];

    for (NSString* tableName in @[@"MYCUnspentOutputs", @"MYCParentOutputs"])
    {
        [mycdatabase registerMigration:[NSString stringWithFormat:@"Create %@", tableName] withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {
            return [db executeUpdate:[NSString stringWithFormat:
                    @"CREATE TABLE %@("
                    "outpointHash      BLOB NOT NULL,"
#if MYCDebugHexDatabaseFields
                    "outpointTxID      TEXT NOT NULL,"
#endif
                    "outpointIndex     INT  NOT NULL,"
                    "blockHeight       INT  NOT NULL," // equals -1 if tx is not confirmed yet.
                    "scriptData        BLOB NOT NULL," // binary script
#if MYCDebugHexDatabaseFields
                    "addressBase58     TEXT,"
#endif
                    "value             INT  NOT NULL,"
                    "coinbase          INT  NOT NULL,"
                    "accountIndex      INT  NOT NULL," // -1 if this output is not spendable by any account.
                    "change            INT  NOT NULL," // 0 for external chain, 1 for change chain
                    "keyIndex          INT  NOT NULL," // index of the address used in the keychain.
                    "PRIMARY KEY (outpointHash, outpointIndex, accountIndex) ON CONFLICT REPLACE"
                    ")", tableName]] &&
            [db executeUpdate:[NSString stringWithFormat:@"CREATE INDEX %@_accountIndex ON %@ (accountIndex)", tableName, tableName]];
        }];
    }

    [mycdatabase registerMigration:@"Create MYCTransactions" withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {
        return [db executeUpdate:
                @"CREATE TABLE MYCTransactions("
                "transactionHash   BLOB NOT NULL," // note: we allow duplicate txs if they happen to pay from one account to another.
#if MYCDebugHexDatabaseFields
                "transactionID     TEXT NOT NULL,"
#endif
                "data              BLOB NOT NULL," // raw transaction in binary
#if MYCDebugHexDatabaseFields
                "dataHex           TEXT NOT NULL,"
#endif
                "blockHeight       INT  NOT NULL," // equals -1 if not confirmed yet.
                "timestamp         INT  NOT NULL," // timestamp.
                "accountIndex      INT  NOT NULL," // index of an account to which this tx belongs.
                "PRIMARY KEY (transactionHash, accountIndex) ON CONFLICT REPLACE"  // note: we allow duplicate txs if they happen to pay from one account to another.
                ")"]  &&
        [db executeUpdate:@"CREATE INDEX MYCTransactions_accountIndex ON MYCTransactions (blockHeight, accountIndex, timestamp)"];
    }];

}

@end
