//
//  MYCSendViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCSendViewController.h"
#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "MYCTextFieldLiveFormatter.h"
#import "MYCErrorAnimation.h"
#import "MYCScannerView.h"
#import "MYCUnspentOutput.h"
#import "MYCCurrenciesViewController.h"
#import "MYCCurrencyFormatter.h"
#import "MYCRestoreSeedViewController.h"
#import "MYCTransaction.h"
#import "MYCTransactionDetails.h"
#import "MYCMinerFeeEstimations.h"

static const BTCAmount MYCLowPriorityFeeRate = 8000;
static const BTCAmount MYCEconomyFeeRate = 15000;
static const BTCAmount MYCNormalFeeRate = 20000;
static const BTCAmount MYCPriorityFeeRate = 100000;

@interface MYCSendViewController () <UITextFieldDelegate, BTCTransactionBuilderDataSource>

@property(nonatomic,readonly) MYCWallet* wallet;

@property(nonatomic) BTCAmount spendingAmount;
@property(nonatomic) BTCAddress* spendingAddress;
@property(nonatomic) MYCMinerFeeEstimations* minerFeeEstimations;
@property(nonatomic) BTCAmount minerFeeRate;

@property(nonatomic) BOOL addressValid;
@property(nonatomic) BOOL amountValid;

@property (weak, nonatomic) IBOutlet UILabel *accountNameLabel;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView* spinner;

@property (weak, nonatomic) IBOutlet UITextField *addressField;
@property (weak, nonatomic) IBOutlet UIButton *scanButton;

@property (weak, nonatomic) IBOutlet UIButton *currencyButton;
@property (weak, nonatomic) IBOutlet UITextField *amountField;
@property (nonatomic) MYCTextFieldLiveFormatter* liveFormatter;

@property(nonatomic) BOOL fiatInput DEPRECATED_ATTRIBUTE;

@property (weak, nonatomic) IBOutlet UILabel *feeLabel;

@property (weak, nonatomic) IBOutlet UIButton *allFundsButton;
@property (weak, nonatomic) IBOutlet UILabel *allFundsLabel;

@property (weak, nonatomic) IBOutlet UILabel *minerFeeLabel;

@property (strong, nonatomic) IBOutletCollection(NSLayoutConstraint)  NSArray*borderHeightConstraints;

@property(weak, nonatomic) MYCScannerView* scannerView;

@property(nonatomic) BTCKeychain* accountKeychain; // when wallet is unlocked.
@property(nonatomic) BTCPaymentRequest* paymentRequest;
@property(nonatomic) BOOL scanning; // while YES prevents triggering scanning multiple times.
@end

@implementation MYCSendViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Send Bitcoins", @"");
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(walletDidUpdateAccount:) name:MYCWalletDidUpdateAccountNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currencyDidUpdate:) name:MYCWalletCurrencyDidUpdateNotification object:nil];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) currencyDidUpdate:(NSNotification*)notif {
    [self updateCurrency];
}

- (IBAction) changeCurrency:(id)_ {
    MYCCurrenciesViewController* currenciesVC = [[MYCCurrenciesViewController alloc] initWithNibName:nil bundle:nil];
    currenciesVC.amount = self.spendingAmount;
    UINavigationController* navC = [[UINavigationController alloc] initWithRootViewController:currenciesVC];
    [self presentViewController:navC animated:YES completion:nil];
}

- (void) updateCurrency {
    self.amountField.placeholder = [MYCWallet currentWallet].primaryCurrencyFormatter.placeholderText;
    BTCAmount amountToPay = self.spendingAmount;
    if (amountToPay > 0) {
        self.amountField.text = [[MYCWallet currentWallet].primaryCurrencyFormatter.nakedFormatter stringFromNumber:@(amountToPay)];
    } else {
        self.amountField.text = @"";
    }
    [self.currencyButton setTitle:[MYCWallet currentWallet].primaryCurrencyFormatter.currencyCode forState:UIControlStateNormal];

    self.liveFormatter.textField = nil;
    self.liveFormatter = [[MYCTextFieldLiveFormatter alloc] initWithTextField:self.amountField numberFormatter:[MYCWallet currentWallet].primaryCurrencyFormatter.nakedFormatter];

    [self.view setNeedsLayout];

    [self updateAmounts];
    [self updateTotalBalance];
}


- (void) viewDidLoad
{
    [super viewDidLoad];
    
    [self.wallet loadMinerFeeEstimationsWithCompletion:^(MYCMinerFeeEstimations * estimations, NSError * error) {
        self.minerFeeEstimations = estimations;
        switch (self.minerFeeRate) {
            case MYCLowPriorityFeeRate:
                self.minerFeeRate = self.minerFeeEstimations.lowPriority;
                break;
            case MYCEconomyFeeRate:
                self.minerFeeRate = self.minerFeeEstimations.economy;
                break;
            case MYCNormalFeeRate:
                self.minerFeeRate = self.minerFeeEstimations.normal;
                break;
            case MYCPriorityFeeRate:
                self.minerFeeRate = self.minerFeeEstimations.priority;
                break;
        }
        [self updateAmounts];
    }];
    self.minerFeeRate = MYCNormalFeeRate;
    
    self.accountNameLabel.text = NSLocalizedString(@"Send", @"");

    [self reloadAccount];
    [self updateCurrency];

    for (NSLayoutConstraint* c in self.borderHeightConstraints)
    {
        c.constant = 1.0/[UIScreen mainScreen].nativeScale;
    }

    [self.cancelButton setTitle:NSLocalizedString(@"Cancel", @"") forState:UIControlStateNormal];
    [self.sendButton   setTitle:NSLocalizedString(@"Send", @"") forState:UIControlStateNormal];

    self.addressField.placeholder = NSLocalizedString(@"Recipient Address", @"");
    [self.scanButton setTitle:NSLocalizedString(@"Scan Address", @"") forState:UIControlStateNormal];

    [self.allFundsButton setTitle:NSLocalizedString(@"Use all funds", @"") forState:UIControlStateNormal];

    if (self.defaultAddress)
    {
        self.addressField.text = self.defaultAddressLabel ?: self.defaultAddress.string;
        self.spendingAddress = self.defaultAddress;
        [self updateAddressView];
    }

    if (self.defaultAmount > 0)
    {
        self.spendingAmount = self.defaultAmount;
        self.amountField.text = [self.wallet.primaryCurrencyFormatter.nakedFormatter stringFromNumber:@(self.defaultAmount)];
        [self didEditBtc:nil];
    }

    [self updateAmounts];
    [self updateTotalBalance];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Make sure we have the latest unspent outputs.
    if (self.account)
    {
        [self.wallet updateAccount:self.account force:YES completion:^(BOOL success, NSError *error) {

            if (!success)
            {
                // TODO: show error.
            }

            [self reloadAccount];
            [self updateAmounts];
            [self updateAddressView];
            [self updateTotalBalance];
        }];
    }
    else
    {
        [self updateAmounts];
        [self updateAddressView];
        [self updateTotalBalance];
    }

    if (self.prefillAllFunds)
    {
        [self useAllFunds:nil];
    }

}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [[MYCWallet currentWallet] updateExchangeRate:YES completion:^(BOOL success, NSError *error) {
        if (!success && error)
        {
            MYCError(@"MYCSendViewController: Automatic update of exchange rate failed: %@", error);
        }
    }];

    // If last time used QR code scanner, show it this time.
    // Do not show if we have some default address already.
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MYCSendWithScanner"])
    {
        if (!self.defaultAddress)
        {
            [self scan:nil];
        }
    }
}

- (MYCWallet*) wallet
{
    return [MYCWallet currentWallet];
}

- (void) walletDidUpdateAccount:(NSNotification*)notif
{
    if (!self.account) return;

    MYCWalletAccount* wa = notif.object;
    if ([wa isKindOfClass:[MYCWalletAccount class]] && wa.accountIndex == self.account.accountIndex)
    {
        [self reloadAccount];
    }
}

- (void) reloadAccount
{
    if (!_account) return;

    [self.wallet inDatabase:^(FMDatabase *db) {
        [_account reloadFromDatabase:db];
    }];
    self.account = _account;
}

- (void) setAccount:(MYCWalletAccount *)account
{
    _account = account;

    if (self.isViewLoaded && account)
    {
        self.accountNameLabel.text = _account.label;
        [self updateAmounts];
        [self updateTotalBalance];
    }
}

- (void) setSpendingAmount:(BTCAmount)spendingAmount
{
    MYCLog(@"Set Spending Amount: %@ btc", @(((double)spendingAmount)/BTCCoin));
    _spendingAmount = spendingAmount;
    [self updateAmounts];
}




#pragma mark - Actions




- (IBAction) cancel:(id)sender
{
    [self.view endEditing:YES];
    [self complete:NO];
}

- (IBAction) send:(id)sender
{
    [self.view endEditing:YES];

    [self updateAddressView];
    [self updateAmounts];

    if (!self.amountValid)
    {
        [MYCErrorAnimation animateError:self.amountField radius:10.0];
        [MYCErrorAnimation animateError:self.currencyButton radius:10.0];
    }

    if (!self.addressValid)
    {
        [MYCErrorAnimation animateError:self.addressField radius:10.0];
        [MYCErrorAnimation animateError:self.scanButton radius:10.0];
    }

    if (self.addressValid && self.amountValid && (self.spendingAddress || self.paymentRequest) && self.spendingAmount > 0)
    {
        [self updateAccountIfNeeded:^(BOOL success, BOOL updated, NSError *error) {

            // If actually updated account, re-check everything.
            if (updated)
            {
                [self send:sender];
                return;
            }

            if (!success)
            {
                MYCError(@"CANNOT SYNC ACCOUNT BEFORE SENDING: %@", error);
                UIAlertController* ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", @"")
                                                                            message:NSLocalizedString(@"Can't synchronize the account. Try again later.", @"")
                                                                     preferredStyle:UIAlertControllerStyleAlert];
                [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction *action) {}]];
                [self presentViewController:ac animated:YES completion:nil];
            }

            [self confirmAndSend];
        }];
    }
}


- (void) confirmAndSend {

    NSString* authString = [NSString stringWithFormat:NSLocalizedString(@"Confirm payment of %@", @""),
                            [self formatAmountInSelectedCurrency:self.spendingAmount]];

    if (self.paymentRequest.details.memo.length > 0 &&
        self.paymentRequest.details.memo.length < 100) {

        authString = [NSString stringWithFormat:NSLocalizedString(@"Confirm payment of %@. %@", @""),
                      [self formatAmountInSelectedCurrency:self.spendingAmount],
                      self.paymentRequest.details.memo];
    } else if (self.paymentRequest.signerName.length > 0) {

        authString = [NSString stringWithFormat:NSLocalizedString(@"Confirm payment of %@ to %@", @""),
                      [self formatAmountInSelectedCurrency:self.spendingAmount],
                      self.paymentRequest.signerName];
    }

    [self.wallet bestEffortAuthenticateWithTouchID:^(MYCUnlockedWallet *uw, BOOL authenticated) {
        if (!uw) {
            // User denied access. Do nothing.
            return;
        }

        BTCKeychain* kc = uw.keychain;

        if (!kc) {
            [MYCRestoreSeedViewController promptToRestoreWallet:uw.error in:self];
            return;
        }

        self.accountKeychain = [kc keychainForAccount:(uint32_t)self.account.accountIndex];

        if (authenticated) {
            [self actuallySend];
            return;
        }

        // TouchID is n/a or disabled. Ask with a simple alert.
        UIAlertController* ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Bitcoin Payment", @"")
                                                                    message:authString
                                                             preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"")
                                               style:UIAlertActionStyleCancel
                                             handler:^(UIAlertAction *action) {

                                                 [self endSpinning];

                                             }]];
        [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Send", @"")
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {

                                                 [self actuallySend];
                                                 
                                             }]];
        
        [self presentViewController:ac animated:YES completion:nil];

    } reason:authString];
}

- (NSArray*) filledInOutputs:(NSArray*)txouts amount:(BTCAmount)amount {

    if (txouts.count == 0) return txouts;

    // Fill-in the amount in the first output if all outputs are unspecified.
    if (![self someAmountsSpecified:txouts]) {
        BTCTransactionOutput* txout = txouts[0];
        txout.value = amount;
    }

    for (BTCTransactionOutput* txout in txouts) {
        if (txout.value == BTCUnspecifiedPaymentAmount) {
            txout.value = 0;
        }
    }
    return txouts;
}

- (BTCAmount) totalAmountInOutputs:(NSArray*)txouts {
    BTCAmount total = 0;
    for (BTCTransactionOutput* txout in txouts) {
        if (txout.value > 0 && txout.value != BTCUnspecifiedPaymentAmount) {
            total += txout.value;
        }
    }
    return total;
}

- (BOOL) someAmountsSpecified:(NSArray*)txouts {
    for (BTCTransactionOutput* txout in txouts) {
        if (txout.value != BTCUnspecifiedPaymentAmount) {
            return YES;
        }
    }
    return NO;
}

- (void) actuallySend {

    if (!self.accountKeychain) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Wallet is locked", @"")
                                    message:[NSString stringWithFormat:@"Wallet access was not authenticated."] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
        return;
    }

    BTCTransactionBuilder* builder = [self makeTransactionBuilder];

    NSError* berror = nil;
    BTCTransactionBuilderResult* result = nil;

    result = [builder buildTransaction:&berror];

    [self.accountKeychain clear];
    self.accountKeychain = nil;

    if (!result || result.unsignedInputsIndexes.count > 0)
    {
        // Typically user declined signing.
        MYCError(@"TX BUILDER ERROR: %@", berror);
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Payment Error", @"")
                                    message:[NSString stringWithFormat:@"Cannot compose bitcoin transaction. %@", berror.localizedDescription ?: @""] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];

        return;
    }

    [self.view endEditing:YES];

    BTCTransaction* tx = result.transaction;

    MYCLog(@"signed tx: %@", BTCHexFromData(tx.data));

    [self beginSpinning];

    if (self.paymentRequest) {
        // save payment metadata (see below for how we save the receipt)
        [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
            MYCTransactionDetails* txdet = [[MYCTransactionDetails alloc] init];
            txdet.transactionHash = tx.transactionHash;
            txdet.recipient = self.paymentRequest.signerName;
            txdet.memo = self.paymentRequest.details.memo;
            txdet.paymentRequestData = self.paymentRequest.data;

            MYCLog(@"Saving metadata for tx %@: recipient = %@, memo = %@, prdata = %@ bytes (payment url: %@)",
                   txdet.transactionID,
                   txdet.recipient,
                   txdet.memo,
                   @(txdet.paymentRequestData.length),
                   self.paymentRequest.details.paymentURL);

            NSError* dberror = nil;
            if (![txdet saveInDatabase:db error:&dberror]) {
                MYCError(@"MYCSendVC: cannot save tx details in DB: %@", dberror);
            }
        }];
    }

//#if DEBUG && 1
//#warning DEBUG: disabled broadcasting transaction
//    return;
//#else
    [self broadcastTransaction:tx];
//#endif
}

- (void) broadcastTransaction:(BTCTransaction*)tx
{
    [self.wallet broadcastTransaction:tx fromAccount:self.account completion:^(BOOL success, BOOL queued, NSError *error) {

        [self endSpinning];

        if (success)
        {
            [self updateBackup];

            if (!self.paymentRequest) {
                [self complete:YES];
                return;
            }

            if (!self.paymentRequest.details.paymentURL) {
                MYCLog(@"MYCSendVC: do not have payment URL to receive payment ACK.");
                [self complete:YES];
                return;
            }

            // Send payment ACK and get the receipt, save it in DB.
            MYCLog(@"MYCSendVC: sending payment object to URL: %@", self.paymentRequest.details.paymentURL);
            BTCPayment* payment = [self.paymentRequest paymentWithTransaction:tx];
            [BTCPaymentProtocol postPayment:payment URL:self.paymentRequest.details.paymentURL completionHandler:^(BTCPaymentACK *ack, NSError *error) {
                if (ack) {
                    [self.wallet inDatabase:^(FMDatabase *db) {
                        MYCTransactionDetails* txdet = [MYCTransactionDetails loadWithPrimaryKey:@[ tx.transactionHash ] fromDatabase:db];
                        if (!txdet) {
                            MYCError(@"MYCSendVC: Unexpectedly MYCTransactionDetails record for %@ is not retrieved", tx.transactionID);
                        } else {
                            txdet.paymentACKData = ack.data;
                        }
                        MYCLog(@"MYCSendVC: updating tx details with ACK receipt: %@ %@", txdet.transactionID, txdet.receiptMemo);
                        NSError* dberror = nil;
                        if (![txdet saveInDatabase:db error:&dberror]) {
                            MYCError(@"MYCSendVC: cannot save tx details in DB with ACK data: %@", dberror);
                        }
                    }];
                    [self updateBackup];

                } else {
                    MYCError(@"MYCSendVC: cannot receive ACK from payment: %@", error);
                }

                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Payment Completed", @"Errors")
                                            message:ack.memo ?: @"No receipt received." delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];

                [self complete:YES];
            }];
            return;
        }

        // If failed, but queued, show alert and finish.
        if (queued)
        {
            UIAlertController* ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Connection failed", @"")
                                                                        message:NSLocalizedString(@"Your payment can't be completed, please check your internet connection. Your payment will be completed automatically.", @"")
                                                                 preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction *action) {
                                                 }]];
            [self presentViewController:ac animated:YES completion:nil];

            [self complete:YES];
            return;
        }

        // Failed and not queued.

        // Force update account so we are up to date.
        if (self.account)
        {
            [self.wallet updateAccount:self.account force:YES completion:^(BOOL success, NSError *error) {
            }];
        }

        // Tell the user that transaction failed and must be re-done.
        UIAlertController* ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Payment invalid", @"")
                                                                    message:NSLocalizedString(@"Your payment was rejected. Please try to synchronize your account and try again.", @"")
                                                             preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                               style:UIAlertActionStyleCancel
                                             handler:^(UIAlertAction *action) {
                                             }]];
        [self presentViewController:ac animated:YES completion:nil];
    }];
}

- (void) updateBackup {
    [[MYCWallet currentWallet] setNeedsBackup];
//    [[MYCWallet currentWallet] uploadAutomaticBackup:^(BOOL result, NSError *error) {
//        if (!result) {
//            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot back up changes", @"")
//                                        message:error.localizedDescription ?: @""
//                                       delegate:nil
//                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
//                              otherButtonTitles:nil] show];
//        }
//    }];
}


- (void) updateAccountIfNeeded:(void(^)(BOOL success, BOOL updated, NSError* error))completion
{
    // If updated less than 5 minutes ago, keep it as is.
    if (!self.account || [self.account.syncDate timeIntervalSinceNow] > -5*60)
    {
        if (completion) completion(YES, NO, nil);
        return;
    }

    [self beginSpinning];

    [self.wallet updateAccount:self.account force:YES completion:^(BOOL success, NSError *error) {

        [self endSpinning];
        if (completion) completion(success, success, error);
    }];
}

- (void) beginSpinning
{
    self.spinner.hidden = NO;
    [self.spinner startAnimating];
    self.sendButton.hidden = YES;
    self.amountField.userInteractionEnabled = NO;
    self.allFundsButton.userInteractionEnabled = NO;
    self.addressField.userInteractionEnabled = NO;
    self.scanButton.userInteractionEnabled = NO;
}

- (void) endSpinning
{
    self.spinner.hidden = YES;
    [self.spinner stopAnimating];
    self.sendButton.hidden = NO;
    self.amountField.userInteractionEnabled = YES;
    self.allFundsButton.userInteractionEnabled = YES;
    self.addressField.userInteractionEnabled = YES;
    self.scanButton.userInteractionEnabled = YES;
}

- (void) complete:(BOOL)sent
{
    [self.amountField resignFirstResponder];
    if (self.completionBlock) self.completionBlock(sent);
    self.completionBlock = nil;
}

- (IBAction)useAllFunds:(id)sender
{
    // Compute transaction with all available unspent outputs,
    // figure the required fees and put the difference as a spending amount.

    // Address may not be entered yet, so use dummy address.
    BTCAddress* address = self.spendingAddress ?: [BTCPublicKeyAddress addressWithData:BTCZero160()];

    if (self.paymentRequest) {
        if ([self someAmountsSpecified:self.paymentRequest.details.outputs]) {
            // Cannot use all funds if payment request is specified.
            return;
        }
        address = [[self.paymentRequest.details.outputs.firstObject script] standardAddress];
        address = [[MYCWallet currentWallet] addressForAddress:address];
    }

    BTCTransactionBuilder* builder = [self makeTransactionBuilder];
    builder.outputs = @[];
    builder.changeAddress = address; // outputs is empty array, spending all to change address which must be destination address.
    builder.shouldSign = NO;

    NSError* berror = nil;
    BTCTransactionBuilderResult* result = [builder buildTransaction:&berror];
    if (result)
    {
        self.spendingAmount = result.outputsAmount;
        self.amountField.text = [self.wallet.primaryCurrencyFormatter.nakedFormatter stringFromNumber:@(self.spendingAmount)];
        [self didEditBtc:nil];
    }
}

- (IBAction)changeMinerFee:(id)sender {
    UIAlertController * actionSheet = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Set Miner Fee", nil)
                                                                          message:NSLocalizedString(@"Low Priority or Economy may result in longer confirmation time", nil)
                                                                   preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction * lowPriority = [UIAlertAction actionWithTitle:NSLocalizedString(@"Low Priority", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action) {
                                                             self.minerFeeRate = self.minerFeeEstimations ? self.minerFeeEstimations.lowPriority : MYCLowPriorityFeeRate;
                                                             [self updateAmounts];
                                                             self.minerFeeLabel.text = action.title;
    }];
    UIAlertAction * economy = [UIAlertAction actionWithTitle:NSLocalizedString(@"Economy", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * action) {
                                                         self.minerFeeRate = self.minerFeeEstimations ? self.minerFeeEstimations.economy : MYCEconomyFeeRate;
                                                         [self updateAmounts];
                                                         self.minerFeeLabel.text = action.title;
    }];
    UIAlertAction * normal = [UIAlertAction actionWithTitle:NSLocalizedString(@"Normal", nil)
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * action) {
                                                        self.minerFeeRate = self.minerFeeEstimations ? self.minerFeeEstimations.normal : MYCNormalFeeRate;
                                                        [self updateAmounts];
                                                        self.minerFeeLabel.text = action.title;
    }];
    UIAlertAction * priority = [UIAlertAction actionWithTitle:NSLocalizedString(@"Priority", nil)
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * action) {
                                                          self.minerFeeRate = self.minerFeeEstimations ? self.minerFeeEstimations.priority : MYCPriorityFeeRate;
                                                          [self updateAmounts];
                                                          self.minerFeeLabel.text = action.title;
    }];
    [actionSheet addAction:lowPriority];
    [actionSheet addAction:economy];
    [actionSheet addAction:normal];
    [actionSheet addAction:priority];
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (IBAction)scan:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"MYCSendWithScanner"];

    UIView* targetView = self.view;
    CGRect rect = [targetView convertRect:self.addressField.bounds fromView:self.addressField];

    [MYCScannerView checkPermissionToUseCamera:^(BOOL granted) {

        if (!granted)
        {
            UIAlertController* ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Camera Access", @"")
                                                                        message:NSLocalizedString(@"Please allow camera access in system settings.", @"")
                                                                 preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction *action) {}]];
            [self presentViewController:ac animated:YES completion:nil];

            return;
        }

        self.scannerView = [MYCScannerView presentFromRect:rect inView:targetView detection:^(NSString *code) {
            [self scanPaymentCode:code];
        }];
    }];
}

- (void) scanPaymentCode:(NSString*)code {

    if (!self.scannerView) return;
    if (self.scanning) return;
    self.scanning = YES;

    self.paymentRequest = nil;

    // 1. Try to read a valid address.
    BTCAddress* address = [[BTCAddress addressWithString:code] publicAddress];
    BTCAmount amount = -1;

    if (!address) {
        // 2. Try to read a valid 'bitcoin:' URL.
        NSURL* url = [NSURL URLWithString:code];

        BTCBitcoinURL* bitcoinURL = [[BTCBitcoinURL alloc] initWithURL:url];

        if (!bitcoinURL || !bitcoinURL.isValid) {
            self.scannerView.errorMessage = NSLocalizedString(@"Payment address is not valid", @"");
            self.scanning = NO;
            return;
        }

        if (bitcoinURL.paymentRequestURL) {
            [self processPaymentRequestWithURL:bitcoinURL.paymentRequestURL];
            return;
        }

        address = [bitcoinURL.address publicAddress];
        amount = bitcoinURL.amount;
    }

    if (address)
    {
        if (!!address.isTestnet == !!self.wallet.isTestnet)
        {
            self.addressField.text = address.string;
            [self updateAddressView];

            if (amount >= 0)
            {
                self.spendingAmount = amount;
                self.amountField.text = [self.wallet.primaryCurrencyFormatter.nakedFormatter stringFromNumber:@(amount)];
                [self didEditBtc:nil];
                [self updateAmounts];
            }

            // Jump in amount field.
            [self.amountField becomeFirstResponder];

            [self dismissScannerView];
        }
        else
        {
            self.scannerView.errorMessage = NSLocalizedString(@"Address does not belong to Bitcoin network", @"");
        }
    }
    else
    {
        self.scannerView.errorMessage = NSLocalizedString(@"Not a valid Bitcoin address or payment request", @"");
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.scanning = NO;
    });
}


- (void) processPaymentRequestWithURL:(NSURL*)paymentRequestURL {
    NSParameterAssert(paymentRequestURL);

    [BTCPaymentProtocol loadPaymentRequestFromURL:paymentRequestURL completionHandler:^(BTCPaymentRequest *pr, NSError *error) {

        if (!pr) {
            if ([error.domain isEqual:BTCErrorDomain]) {
                self.scannerView.errorMessage = NSLocalizedString(@"Payment request is invalid", @"Errors");
            } else {
                self.scannerView.errorMessage = NSLocalizedString(@"Connection failed", @"Errors");
            }

            return;
        }

        // Even when invalid, this may be interesting for UI to inspect and provide more details on why it is so.
        self.paymentRequest = pr;

        if (!!pr.details.network.isTestnet != !!self.wallet.isTestnet) {

            self.scannerView.errorMessage = NSLocalizedString(@"Invalid network", @"Errors");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self dismissScannerView];
            });
            return;

        } else if (pr.status == BTCPaymentRequestStatusValid) {

            [self proceedWithPaymentRequest:pr];
            return;

        } else if (pr.status == BTCPaymentRequestStatusUnknown ||
                   pr.status == BTCPaymentRequestStatusUnsigned) {

            NSString* msg = nil;
            if (pr.signerName.length > 0) {
                msg = NSLocalizedString(@"The recipient’s claimed name %@ is not signed by a trusted authority.", @"Errors");
            } else {
                msg = NSLocalizedString(@"The request for payment is not signed by a trusted authority.", @"Errors");
            }

            msg = [NSString stringWithFormat:NSLocalizedString(@"%@ Do you wish to continue?",@""), msg];

            UIAlertController* ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Cannot verify recipient", @"Errors")
                                                                        message:msg
                                                                 preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                [self dismissScannerView];
            }]];
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Continue", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self proceedWithPaymentRequest:pr];
            }]];

            [self presentViewController:ac animated:YES completion:nil];
            return;

        } else if (pr.status == BTCPaymentRequestStatusExpired) {

#if DEBUG
            UIAlertController* ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Payment request expired", @"Errors")
                                                                        message:NSLocalizedString(@"Do you wish to pay anyway?", @"")
                                                                 preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                [self dismissScannerView];
            }]];
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Continue", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self proceedWithPaymentRequest:pr];
            }]];
            [self presentViewController:ac animated:YES completion:nil];
#else
            self.scannerView.errorMessage = NSLocalizedString(@"Payment request expired", @"Errors");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self dismissScannerView];
            });
#endif
        } else {
            self.scannerView.errorMessage = NSLocalizedString(@"Payment request is invalid", @"Errors");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self dismissScannerView];
            });
        }
    }];
}


- (void) dismissScannerView {
    [self.scannerView dismiss];
    self.scannerView = nil;
    self.scanning = NO;
}

- (void) proceedWithPaymentRequest:(BTCPaymentRequest*)pr {

    self.paymentRequest = pr;

//#if DEBUG && 1
//#warning DEBUG: overriding the price
//    BTCTransactionOutput* txout = pr.details.outputs[0];
//    txout.value = 1000;
//#endif

    self.spendingAmount = [self totalAmountInOutputs:pr.details.outputs];
    self.amountField.text = [self.wallet.primaryCurrencyFormatter.nakedFormatter stringFromNumber:@(self.spendingAmount)];
    [self updateAmounts];

    [self dismissScannerView];

    MYCLog(@"MYCSendVC: Processing payment request for %@ -> %@ (%@)", [self.wallet.btcCurrencyFormatter stringFromAmount:self.spendingAmount], pr.signerName, pr.details.memo);

    if ([self someAmountsSpecified:pr.details.outputs]) {
        // Proceed with payment immediately.
        [self send:nil];
    } else {
        // Show the send view so the user can review / edit the amount.
    }
}







#pragma mark - BTCTransactionBuilderDataSource


- (NSEnumerator* /* [BTCTransactionOutput] */) unspentOutputsForTransactionBuilder:(BTCTransactionBuilder*)txbuilder
{
    if (self.account)
    {
        __block NSArray* unspents = nil;
        [self.wallet inDatabase:^(FMDatabase *db) {
            unspents = [MYCUnspentOutput loadOutputsForAccount:self.account.accountIndex database:db];
        }];

        NSMutableArray* utxos = [NSMutableArray array];

        for (MYCUnspentOutput* unspent in unspents)
        {
            //MYCLog(@"unspent: %@: %@", @(unspent.blockHeight), @(unspent.value));
            BTCTransactionOutput* utxo = unspent.transactionOutput;
            utxo.userInfo = @{@"MYCUnspentOutput": unspent };
            [utxos addObject:utxo];
        }

        return [utxos objectEnumerator];
    }
    else
    {
        return [self.unspentOutputs objectEnumerator];
    }
}

- (BTCKey*) transactionBuilder:(BTCTransactionBuilder*)txbuilder keyForUnspentOutput:(BTCTransactionOutput*)txout
{
    // This userInfo key is set in previous call when we provide unspents to the builder.
    MYCUnspentOutput* unspent = txout.userInfo[@"MYCUnspentOutput"];

    if (unspent)
    {
        NSAssert(unspent, @"sanity check");
        NSAssert(self.accountKeychain, @"should already get account keychain");
        BTCKey* key = [[self.accountKeychain derivedKeychainAtIndex:(uint32_t)unspent.change] keyAtIndex:(uint32_t)unspent.keyIndex];
        NSAssert(key, @"sanity check");
        return key; // will clear on dealloc.
    }
    else
    {
        return self.key;
    }
}








#pragma mark - Implementation



- (BTCTransactionBuilder*) makeTransactionBuilder {

    BTCTransactionBuilder* builder = [[BTCTransactionBuilder alloc] init];
    builder.dataSource = self;
    builder.feeRate = self.minerFeeRate;

    if (self.paymentRequest) {
        if (self.paymentRequest.details.outputs.count == 0) {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"Errors")
                                        message:[NSString stringWithFormat:@"Payment address is not specified."] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
            return nil;
        }
        NSMutableArray* txouts = [NSMutableArray array];
        for (BTCTransactionOutput* txout in self.paymentRequest.details.outputs) {
            [txouts addObject:[txout copyWithZone:nil]];
        }
        builder.outputs = [self filledInOutputs:txouts amount:self.spendingAmount];
    } else if (self.spendingAddress) {
        builder.outputs = @[ [[BTCTransactionOutput alloc] initWithValue:self.spendingAmount address:self.spendingAddress] ];
    } else {
        builder.outputs = @[];
    }

    builder.changeAddress = self.changeAddress ?: self.account.internalAddress;

    return builder;
}

- (NSString*) formatAmountInSelectedCurrency:(BTCAmount)amount
{
    return [self.wallet.primaryCurrencyFormatter stringFromAmount:amount];
}


- (void) updateTotalBalance
{
    BTCAmount spendableAmount = [self spendableAmount];
    self.allFundsLabel.text = [self formatAmountInSelectedCurrency:spendableAmount];
    self.allFundsButton.enabled = (spendableAmount > 0);
}

- (BTCAmount) spendableAmount
{
    if (self.account)
    {
        return self.account.spendableAmount;
    }
    else if (self.unspentOutputs)
    {
        BTCAmount balance = 0;
        for (BTCTransactionOutput* txout in self.unspentOutputs)
        {
            balance += txout.value;
        }
        return balance;
    }
    return 0;
}

- (void) updateAddressView
{
    NSString* addrString = self.addressField.text;

    if (self.paymentRequest) {
        self.addressValid = YES;
        self.addressField.text = self.paymentRequest.signerName ?: @"";
        if (self.addressField.text.length == 0) {
            self.addressField.text = [[MYCWallet currentWallet] addressForAddress:[[self.paymentRequest.details.outputs.firstObject script] standardAddress]].string ?: @"—";
        }
        self.scanButton.hidden = YES;
        return;
    }

    // Check if we have default label & address to override the address.
    if (self.defaultAddress && self.defaultAddressLabel &&
        ([addrString isEqualToString:self.defaultAddressLabel] || [addrString isEqualToString:@""]))
    {
        //
        if (!self.addressField.isFirstResponder) {
            self.scanButton.hidden = NO;
            self.addressField.text = self.defaultAddressLabel;
            self.addressField.textColor = [UIColor blackColor];
            self.addressValid = YES;
            self.spendingAddress = self.defaultAddress;
            [self updateSendButton];
            return;
        }

        // If first responder, ignore the value.
        self.addressField.text = @"";
        addrString = @"";
    }

    self.scanButton.hidden = (addrString.length > 0);

    self.addressField.textColor = [UIColor blackColor];

    self.addressValid = NO;
    self.spendingAddress = nil;

    if (addrString.length > 0)
    {
        // Check if that's the valid address.
        BTCAddress* addr = [BTCAddress addressWithString:addrString];
        if (!addr) // parse failure or checksum failure
        {
            // Show in red only when not editing or when it's surely incorrect.
            if (!self.addressField.isFirstResponder || addrString.length >= 34)
            {
                self.addressField.textColor = [UIColor redColor];
            }
        }
        else
        {
            if (!!self.wallet.isTestnet == !!addr.isTestnet)
            {
                self.addressValid = YES;
                self.spendingAddress = addr;
            }
            else
            {
                self.addressField.textColor = [UIColor redColor];
            }
        }
    }

    [self updateSendButton];
}

- (void) updateSendButton
{
    //self.sendButton.enabled = self.addressValid && self.amountValid;
    self.sendButton.enabled = YES;
    self.sendButton.alpha = (self.addressValid && self.amountValid) ? 1.0 : 0.4;
}

- (void) updateAmounts
{
    self.amountValid = NO;

    self.amountField.textColor = [UIColor blackColor];

    self.feeLabel.hidden = YES;

    if (self.spendingAmount > 0)
    {
        self.feeLabel.hidden = NO;

        // Compute transaction and figure if it's spendable or not.
        // Update fee and color amounts.
        // Set self.amountValid to YES if everything is okay.

        BTCTransactionBuilder* builder = [self makeTransactionBuilder];
        if (builder.outputs.count == 0) {
            // Address may not be entered yet, so use dummy address.
            builder.outputs = @[ [[BTCTransactionOutput alloc] initWithValue:self.spendingAmount address:[BTCPublicKeyAddress addressWithData:BTCZero160()]] ];
        }
        builder.shouldSign = NO;

        NSError* berror = nil;
        BTCTransactionBuilderResult* result = [builder buildTransaction:&berror];
        if (!result)
        {
            self.amountField.textColor = [UIColor redColor];
            self.feeLabel.text = NSLocalizedString(@"Insufficient funds", @"");
        }
        else
        {
            self.amountValid = YES;
            NSString* feeString = [self formatAmountInSelectedCurrency:result.fee];
            self.feeLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Fee: %@", @""), feeString];
        }
    }
    [self updateSendButton];
    [self updateUnits];
}

- (void) updateUnits
{
    [self.currencyButton setTitle:self.wallet.primaryCurrencyFormatter.currencyCode forState:UIControlStateNormal];
    self.amountField.placeholder = self.wallet.primaryCurrencyFormatter.placeholderText;
}


- (void) setFiatInput:(BOOL)fiatInput
{
    [self updateAmounts];
    [self updateTotalBalance];
}

- (IBAction)didBeginEditingBtc:(id)sender
{
    [self setEditing:YES animated:YES];
}

- (IBAction)didEditBtc:(id)sender
{
    self.spendingAmount = BTCAmountFromDecimalNumber([self.wallet.primaryCurrencyFormatter.nakedFormatter numberFromString:self.amountField.text]);
}

- (IBAction)didBeginEditingAddress:(id)sender
{
    self.paymentRequest = nil;
    [self updateAddressView];
}

- (IBAction)didEditAddress:(id)sender
{
    self.paymentRequest = nil;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"MYCSendWithScanner"];
    [self updateAddressView];
}

- (IBAction)didEndEditingAddress:(id)sender
{
    self.paymentRequest = nil;
    [self updateAddressView];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.addressField)
    {
        [self.amountField becomeFirstResponder];
    }
    else if (textField == self.amountField)
    {
        [self.view endEditing:YES];
    }

    return YES;
}


@end
