//
//  MYCSettingsViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCSettingsViewController.h"
#import "PTableViewSource.h"
#import "PColor.h"

@interface MYCSettingsViewController ()<UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, weak) IBOutlet UITableView* tableView;
@property(nonatomic) PTableViewSource* tableViewSource;
@end

@implementation MYCSettingsViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Settings", @"");
        self.tintColor = [UIColor colorWithHue:130.0f/360.0f saturation:1.0f brightness:0.77f alpha:1.0];
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings", @"") image:[UIImage imageNamed:@"TabSettings"] selectedImage:[UIImage imageNamed:@"TabSettingsSelected"]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self updateSections];
}

- (BOOL) prefersStatusBarHidden
{
    return NO;
}

- (void) updateSections
{
    self.tableViewSource = [[PTableViewSource alloc] init];

    __typeof(self) __weak weakself = self;

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Units", @"");
        section.rowHeight = 52.0;
        section.cellStyle = UITableViewCellStyleSubtitle;
        section.detailFont = [UIFont systemFontOfSize:15.0];
        section.detailTextColor = [UIColor grayColor];
        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"BTC", @"");
            item.detailTitle = NSLocalizedString(@"1.2345 btc", @"");
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                [weakself.tableView deselectRowAtIndexPath:indexPath animated:YES];
                [weakself.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            };
        }];
        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"mBTC", @"");
            item.detailTitle = NSLocalizedString(@"1234.5 mbtc", @"");
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                [weakself.tableView deselectRowAtIndexPath:indexPath animated:YES];
                [weakself.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            };
        }];
        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Bits", @"");
            item.detailTitle = NSLocalizedString(@"1 234 500 bits", @"");
            item.accessoryType = UITableViewCellAccessoryCheckmark;
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                [weakself.tableView deselectRowAtIndexPath:indexPath animated:YES];
                [weakself.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            };
        }];
    }];

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Cold Storage", @"");

        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Import Private Key", @"");
            item.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }];
    }];

    [self.tableViewSource section:^(PTableViewSourceSection *section) {

        section.headerTitle = [NSString stringWithFormat:@"%@ v%@",
                               [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleNameKey],
                               [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey]
                               ];

        section.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Credits", @"");
        }];
        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Legal Mentions", @"");
        }];
    }];

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Developer Build", @"");

        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Use Testnet", @"");
            item.selectionStyle = UITableViewCellSelectionStyleNone;
            item.setupAction =  ^(PTableViewSourceItem* item_, NSIndexPath* indexPath, UITableViewCell* cell) {
                [item_ setupCell:cell atIndexPath:indexPath];
                UISwitch* switchControl = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
                switchControl.on = YES;
                cell.accessoryView = switchControl;
            };
        }];
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

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.tableViewSource tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [self.tableViewSource tableView:tableView titleForHeaderInSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return [self.tableViewSource tableView:tableView titleForFooterInSection:section];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.tableViewSource tableView:tableView willSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableViewSource tableView:tableView didSelectRowAtIndexPath:indexPath];
}

@end
