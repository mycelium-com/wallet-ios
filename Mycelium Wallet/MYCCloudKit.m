//
//  MYCCloudKit.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 23.04.2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import "MYCCloudKit.h"
#import "MYCWallet.h"
#import <CloudKit/CloudKit.h>

@interface MYCCloudKit ()
@end

@implementation MYCCloudKit

- (NSString*) walletBackupRecordType {
    return @"WalletDataBackup";
}

- (CKRecordID*) recordIDForWalletID:(NSString*)walletID {
    return [[CKRecordID alloc] initWithRecordName:walletID];
}

- (void) uploadDataBackup:(NSData*)encryptedData walletID:(NSString*)walletID completionHandler:(void(^)(BOOL result, NSError* error))completionHandler {
    MYC_ASSERT_MAIN_THREAD;
    if (!encryptedData) [NSException raise:@"No encryptedData" format:@""];
    if (!walletID) [NSException raise:@"No walletID" format:@""];
    if (!completionHandler) [NSException raise:@"No completionHandler" format:@""];

    CKRecordID* recordID = [self recordIDForWalletID:walletID];

    [[CKContainer defaultContainer].privateCloudDatabase fetchRecordWithID:recordID completionHandler:^(CKRecord *fetchedRecord, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // If record exists, update it.
            // If it does not, create one.
            if (fetchedRecord || (!fetchedRecord && [error.domain isEqualToString:CKErrorDomain] && error.code == CKErrorUnknownItem)) {

                CKRecord* record = fetchedRecord;
                if (!record) {
                    record = [[CKRecord alloc] initWithRecordType:[self walletBackupRecordType] recordID:recordID];
                }
                record[@"WalletID"] = walletID;
                record[@"EncryptedData"] = encryptedData;

                [[CKContainer defaultContainer].privateCloudDatabase saveRecord:record completionHandler:^(CKRecord *record, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!record) {
                            MYCError(@"MYCCloudKit: CloudKit error while saving wallet backup: %@", error);
                            completionHandler(NO, [self wrappedErrorForCKError:error]);
                        } else {
                            MYCLog(@"MYCCloudKit: CloudKit stored encrypted wallet backup %@", record[@"WalletID"]);
                            completionHandler(YES, nil);
                        }
                    });
                }];

            } else {
                MYCError(@"MYCCloudKit: CloudKit error while fetching the existing record: %@", error);
                completionHandler(NO, [self wrappedErrorForCKError:error]);
            }
        });
    }];
}

// Attempts to fetch encrypted backup. Returns YES if there is none stored or there is one and it is downloaded successfully.
// Error contains human-readable explanation ("Please sign in to iCloud and enable Cloud Drive", "Please connect to the network", "Please clean up some data on iCloud")
- (void) downloadDataBackupForWalletID:(NSString*)walletID completionHandler:(void(^)(NSData* data, NSError* error))completionHandler {
    MYC_ASSERT_MAIN_THREAD;
    if (!walletID) [NSException raise:@"No walletID" format:@""];
    if (!completionHandler) [NSException raise:@"No completionHandler" format:@""];

    CKRecordID* recordID = [self recordIDForWalletID:walletID];

    [[CKContainer defaultContainer].privateCloudDatabase fetchRecordWithID:recordID completionHandler:^(CKRecord *record, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{

            if (record) {
                NSData* data = record[@"EncryptedData"];
                MYCLog(@"MYCCloudKit: CloudKit returned record for WalletID: %@ (encrypted data: %@ bytes)",
                       record[@"WalletID"], @(data.length));
                completionHandler(data, nil);
                return;
            }

            if ([error.domain isEqual:CKErrorDomain] && error.code == CKErrorUnknownItem) {
                MYCError(@"MYCCloudKit: CloudKit did not find WalletDataBackup record: %@", error);
                completionHandler(nil, nil);
                return;
            }
            MYCError(@"MYCCloudKit: CloudKit returned error when fetching record for WalletID: %@", error);
            completionHandler(nil, [self wrappedErrorForCKError:error]);
        });
    }];
}


- (NSError*) wrappedErrorForCKError:(NSError*)error {

    if ([error.domain isEqual:CKErrorDomain]) {
        if (error.code == CKErrorNotAuthenticated) {

            MYCError(@"MYCCloudKit: CloudKit failed to fetch WalletBackup record: %@", error);
            MYCError(@"MYCCloudKit: THIS MEANS: User must be logged-in AND upgraded to iCloud Drive.");

            NSString* msg = NSLocalizedString(@"Please sign in to iCloud and make sure iCloud Drive is turned on.", @"");
            NSError* error2 = [NSError errorWithDomain:error.domain
                                                  code:error.code
                                              userInfo:@{
                                                         NSLocalizedDescriptionKey: msg,
                                                         NSUnderlyingErrorKey: error,
                                                         }];
            return error2;

        } else if (error.code == CKErrorQuotaExceeded) {

            MYCError(@"MYCCloudKit: iCloud quota exceeded: %@", error);

            NSString* msg = NSLocalizedString(@"Not enough space on your iCloud account. Please remove some documents or apps to leave room for wallet backup.", @"");
            NSError* error2 = [NSError errorWithDomain:error.domain
                                                  code:error.code
                                              userInfo:@{
                                                         NSLocalizedDescriptionKey: msg,
                                                         NSUnderlyingErrorKey: error,
                                                         }];
            return error2;

        } else if (error.code == CKErrorNetworkFailure || error.code == CKErrorNetworkUnavailable) {

            MYCError(@"MYCCloudKit: network failure or network not available. %@", error);

            NSString* msg = NSLocalizedString(@"Cannot connect to iCloud. Please check your network connection.", @"");
            NSError* error2 = [NSError errorWithDomain:error.domain
                                                  code:error.code
                                              userInfo:@{
                                                         NSLocalizedDescriptionKey: msg,
                                                         NSUnderlyingErrorKey: error,
                                                         }];
            return error2;
        }
    }
    return error;
}


@end
