//
//  MYCTransactionDetailsViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 28.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCTransactionDetailsViewController.h"
#import "MYCTransactionsViewController.h"
#import "MYCWebViewController.h"

#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "MYCTransaction.h"
#import "MYCTransactionDetails.h"
#import "MYCCurrencyFormatter.h"

#import "PTableViewSource.h"

@interface MYCTransactionDetailsViewController ()
@property(nonatomic) PTableViewSource* tableViewSource;
@property(nonatomic, weak) IBOutlet UITableView* tableView;
@property(nonatomic) NSDictionary* cellHeightsById;
@end

@implementation MYCTransactionDetailsViewController

- (void) viewDidLoad
{
    [super viewDidLoad];

    self.title = NSLocalizedString(@"Transaction Details", @"");
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateTableViewSource];
}

- (BOOL) shouldOverrideTintColor
{
    NSArray* vcs = [self.navigationController viewControllers];

    NSUInteger idx = [vcs indexOfObject:self];
    if (idx != NSNotFound && idx > 0 && [vcs[idx] isKindOfClass:[MYCTransactionsViewController class]])
    {
        return [vcs[idx] shouldOverrideTintColor];
    }
    return NO;
}


- (void) updateTableViewSource
{
    self.tableViewSource = [[PTableViewSource alloc] init];

    BTCNumberFormatter* btcfmt = [[MYCWallet currentWallet].btcCurrencyFormatter.btcFormatter copy];
    btcfmt.minimumFractionDigits = btcfmt.maximumFractionDigits;

    // Fill in data for every cell.
    __typeof(self) __weak weakself = self;
    self.tableViewSource.setupAction = ^(PTableViewSourceItem* item, NSIndexPath* indexPath, UITableViewCell* cell) {
        UILabel* keyLabel = (id)[cell viewWithTag:1];
        UILabel* valueLabel = (id)[cell viewWithTag:2];
        keyLabel.text = item.key ?: @"";
        valueLabel.text = item.value ?: @"";
        //keyLabel.textColor = weakself.tintColor;
        if ([item.userInfo[@"myinput"] boolValue])
        {
            keyLabel.textColor = weakself.redColor;
        }
        else if ([item.userInfo[@"myoutput"] boolValue])
        {
            keyLabel.textColor = weakself.greenColor;
        }
    };

    self.cellHeightsById = @{
                             @"txid": @(86),
                             @"keyvalue": @(44),
                             @"keyvalue2": @(67),
                             @"memo": @(104),
                             };

    // General info about transaction
    [self.tableViewSource section:^(PTableViewSourceSection *section) {

        [section item:^(PTableViewSourceItem *item) {
            item.cellIdentifier = @"txid";
            item.key = [NSLocalizedString(@"Transaction ID", @"") uppercaseString];
            item.value = self.transaction.transactionID;
            item.userInfo = @{
                              @"path": [@"/tx/" stringByAppendingString:self.transaction.transactionID],
                              @"pathtestnet": [@"/transactions/" stringByAppendingString:self.transaction.transactionID],
                              };
        }];

        [section item:^(PTableViewSourceItem *item) {
            item.cellIdentifier = @"keyvalue";
            item.key = [NSLocalizedString(@"Date", @"") uppercaseString];

            NSDateFormatter* df = [[NSDateFormatter alloc] init];
            df.dateStyle = NSDateFormatterLongStyle;
            df.timeStyle = NSDateFormatterLongStyle;
            item.value = self.transaction.date ? [df stringFromDate:self.transaction.date] : @"—";
        }];

        // If received money, show Sender.
        if (self.transaction.amountTransferred > 0) {

            [section item:^(PTableViewSourceItem *item) {
                item.cellIdentifier = @"keyvalue";
                item.key = [NSLocalizedString(@"Sender", @"") uppercaseString];
                item.value = self.transaction.transactionDetails.sender ?: @"";
                item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                    [weakself editSender];
                };
            }];

        // If spent money, show Recipient.
        } else {
            [section item:^(PTableViewSourceItem *item) {
                item.cellIdentifier = @"keyvalue";
                item.key = [NSLocalizedString(@"Recipient", @"") uppercaseString];
                item.value = self.transaction.transactionDetails.recipient ?: @"";
                item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                    [weakself editRecipient];
                };
            }];
        }

        [section item:^(PTableViewSourceItem *item) {
            item.cellIdentifier = @"memo";
            item.key = [NSLocalizedString(@"Memo", @"") uppercaseString];
            item.value = self.transaction.transactionDetails.memo ?: @"";
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                [weakself editMemo];
            };
        }];

        NSString* paymentReceiptMemo = self.transaction.transactionDetails.receiptMemo;
        if (paymentReceiptMemo) {
            [section item:^(PTableViewSourceItem *item) {
                item.cellIdentifier = @"memo";
                item.key = [NSLocalizedString(@"Receipt", @"") uppercaseString];
                item.value = paymentReceiptMemo;
                item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                    [weakself viewReceipt];
                };
            }];
        }
    }];


    [self.tableViewSource section:^(PTableViewSourceSection *section) {

        section.headerTitle = NSLocalizedString(@"Status", @"");

        [section item:^(PTableViewSourceItem *item) {
            item.cellIdentifier = @"keyvalue";
            item.key = [NSLocalizedString(@"Block", @"") uppercaseString];
            if (self.transaction.blockHeight > -1) {
                item.value = @(self.transaction.blockHeight).stringValue;
                item.userInfo = @{
                                  @"path": [@"/block-height/" stringByAppendingString:@(self.transaction.blockHeight).stringValue],
                                  @"pathtestnet": [@"/blocks/" stringByAppendingString:@(self.transaction.blockHeight).stringValue],
                                  };
            } else {
                item.value = @"—";
            }
        }];

        [section item:^(PTableViewSourceItem *item) {
            item.cellIdentifier = @"keyvalue";
            item.key = [NSLocalizedString(@"Confirmations", @"") uppercaseString];
            if (self.transaction.blockHeight > -1) {
                item.value = @([MYCWallet currentWallet].blockchainHeight - self.transaction.blockHeight + 1).stringValue;
            } else {
                item.value = NSLocalizedString(@"Not confirmed yet", @"");
            }
        }];

        [section item:^(PTableViewSourceItem *item) {
            item.cellIdentifier = @"keyvalue";
            item.key = [NSLocalizedString(@"Size", @"") uppercaseString];
            NSByteCountFormatter* bf = [[NSByteCountFormatter alloc] init];
            bf.allowedUnits = NSByteCountFormatterUseBytes;
            bf.countStyle = NSByteCountFormatterCountStyleDecimal;
            bf.allowsNonnumericFormatting = NO;
            item.value = [bf stringFromByteCount:self.transaction.data.length];
        }];

        [section item:^(PTableViewSourceItem *item) {
            item.cellIdentifier = @"keyvalue";
            item.key = [NSLocalizedString(@"Fee", @"") uppercaseString];
            item.value = [btcfmt stringFromAmount:self.transaction.fee];
        }];
    }];


    // Inputs

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Inputs", @"");

        for (BTCTransactionInput* txin in self.transaction.transactionInputs)
        {
            [section item:^(PTableViewSourceItem *item) {
                item.cellIdentifier = @"keyvalue2";
                item.key = [btcfmt stringFromAmount:BTCAmountFromDecimalNumber(txin.userInfo[@"value"])];
                item.value = [txin.userInfo[@"address"] base58String];
                if (item.value)
                {
                    item.userInfo = @{@"path": [@"/address/" stringByAppendingString:item.value],
                                      @"pathtestnet": [@"/addresses/" stringByAppendingString:item.value],
                                      @"myinput": @([self.transaction.account matchesScriptData:[(BTCScript*)txin.userInfo[@"script"] data] change:NULL keyIndex:NULL])};
                }
            }];
        }
    }];


    // Outputs

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Outputs", @"");

        for (BTCTransactionOutput* txout in self.transaction.transactionOutputs)
        {
            [section item:^(PTableViewSourceItem *item) {
                item.cellIdentifier = @"keyvalue2";
                item.key = [btcfmt stringFromAmount:txout.value];
                item.value = [[MYCWallet currentWallet] addressForAddress:txout.script.standardAddress].string;
                item.userInfo = @{@"path": [@"/address/" stringByAppendingString:item.value],
                                  @"pathtestnet": [@"/addresses/" stringByAppendingString:item.value],
                                  @"myoutput": @([self.transaction.account matchesScriptData:txout.script.data change:NULL keyIndex:NULL])};
            }];
        }
    }];

}








#pragma mark - Actions





- (void) editSender {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Sender", @"")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = self.transaction.transactionDetails.sender ?: @"";
    }];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",@"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {}]];

    __typeof(alert) __weak weakalert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Save", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.transaction.transactionDetails.sender = [weakalert.textFields.firstObject text];
        [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
            NSError* dberror = nil;
            if (![self.transaction.transactionDetails saveInDatabase:db error:&dberror]) {
                MYCError(@"Failed to update tx details in DB: %@", dberror);
            }
        }];
        [self updateTableViewSource];
        [self.tableView reloadData];
        [self updateBackup];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void) editRecipient {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Recipient", @"")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = self.transaction.transactionDetails.recipient ?: @"";
    }];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",@"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {}]];

    __typeof(alert) __weak weakalert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Save", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.transaction.transactionDetails.recipient = [weakalert.textFields.firstObject text];
        [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
            NSError* dberror = nil;
            if (![self.transaction.transactionDetails saveInDatabase:db error:&dberror]) {
                MYCError(@"Failed to update tx details in DB: %@", dberror);
            }
        }];
        [self updateTableViewSource];
        [self.tableView reloadData];
        [self updateBackup];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void) editMemo {
#warning TODO: show editing view controller with space for full text.
}

- (void) viewReceipt {
    MYCWebViewController* vc = [[MYCWebViewController alloc] initWithNibName:nil bundle:nil];
    vc.title = NSLocalizedString(@"Payment Receipt", @"");
    vc.plainText = self.transaction.transactionDetails.receiptMemo ?: @"";
    vc.allowShare = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void) updateBackup {
    [[MYCWallet currentWallet] uploadAutomaticBackup:^(BOOL result, NSError *error) {
        if (!result) {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot back up changes", @"")
                                        message:error.localizedDescription ?: @""
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                              otherButtonTitles:nil] show];
        }
    }];
}





#pragma mark - UITableView




- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.tableViewSource numberOfSectionsInTableView:tableView];
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.tableViewSource tableView:tableView numberOfRowsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.tableViewSource tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableViewSource tableView:tableView didSelectRowAtIndexPath:indexPath];

    PTableViewSourceItem* item = [self.tableViewSource itemAtIndexPath:indexPath];
    if (!item.action)
    {
        NSString* pathKey = [MYCWallet currentWallet].isTestnet ? @"pathtestnet" : @"path";
        NSString* path = item.userInfo[pathKey];
        if (path)
        {
            NSURL* url = nil;
            if ([MYCWallet currentWallet].isTestnet)
            {
                url = [NSURL URLWithString:[[@"http://explorer.chain.com" stringByAppendingString:path] stringByAppendingString:@"?block_chain=testnet3"]];
            }
            else
            {
                url = [NSURL URLWithString:[@"https://blockchain.info" stringByAppendingString:path]];
            }
            [[UIApplication sharedApplication] openURL:url];
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PTableViewSourceItem* item = [self.tableViewSource itemAtIndexPath:indexPath];
    return ((NSNumber*)self.cellHeightsById[item.cellIdentifier] ?: @(44)).floatValue;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [self.tableViewSource tableView:tableView titleForHeaderInSection:section];
}


//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    UITableViewCell *cell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
//    return cell.frame.size.height;
//}

//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    NSString *cellIdentifier = [self.tableViewSource itemAtIndexPath:indexPath].cellIdentifier;
//    static NSMutableDictionary *heightCache;
//    if (!heightCache) heightCache = [[NSMutableDictionary alloc] init];
//    NSNumber *cachedHeight = heightCache[cellIdentifier];
//    if (!cachedHeight)
//    {
//        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
//        cachedHeight = @(cell.bounds.size.height);
//        heightCache[cellIdentifier] = cachedHeight;
//    }
//    return cachedHeight.floatValue;
//}


// Menu

- (NSString*) copyableTextForIndexPath:(NSIndexPath*)ip
{
    PTableViewSourceItem* item = [self.tableViewSource itemAtIndexPath:ip];
    NSString* t = item.userInfo[@"textToCopy"] ?: item.value;
    return t;
}

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self copyableTextForIndexPath:indexPath].length > 0) return YES;
    return NO;
}

-(BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    return action == @selector(copy:);
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if (action == @selector(copy:))
    {
        // do stuff
        NSString* t = [self copyableTextForIndexPath:indexPath];
        if (t.length > 0)
        {
            [[UIPasteboard generalPasteboard] setValue:t forPasteboardType:(id)kUTTypeUTF8PlainText];
        }
    }
}

@end
