//
//  BackupInfoVC.m
//  Mycelium Wallet
//
//  Created by Almir A on 05.05.2023.
//  Copyright © 2023 Mycelium. All rights reserved.
//

#import "BackupInfoVC.h"

@interface BackupInfoVC ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UIButton *backupButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) UIScrollView *scrollView;
@end

@implementation BackupInfoVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor whiteColor];
    [self setupLogoImageView];
    [self setupTitleLabel];
    [self setupInfoLabel];
    if (self.hideBackupButton == NO) {
        [self setupBackupButton];
    }
    [self setupCloseButton];
}

- (void)setupLogoImageView {
    self.logoImageView = [[UIImageView alloc] init];
    self.logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoImageView.image = [UIImage imageNamed:@"Logo"];
    [self.view addSubview:self.logoImageView];
    [NSLayoutConstraint activateConstraints:@[
        [self.logoImageView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:16],
        [self.logoImageView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.logoImageView.heightAnchor constraintEqualToConstant:64],
        [self.logoImageView.widthAnchor constraintEqualToConstant:64]
    ]];
}

- (void)setupTitleLabel {
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.textColor = [UIColor blackColor];
    self.titleLabel.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.text = @"Dear Mycelium users";
    [self.view addSubview:self.titleLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.logoImageView.bottomAnchor constant:16],
    ]];
}

- (void)setupInfoLabel {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.alwaysBounceHorizontal = NO;
    [self.view addSubview:self.scrollView];
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],
        [self.scrollView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:16],
    ]];
    
    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.alignment = UIStackViewAlignmentLeading;
    stackView.distribution = UIStackViewDistributionFill;
    stackView.spacing = 0;
    [self.scrollView addSubview:stackView];
    [NSLayoutConstraint activateConstraints:@[
        [stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [stackView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [stackView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-64]
    ]];
    
    self.infoLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.infoLabel.textColor = [UIColor blackColor];
    self.infoLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    self.infoLabel.numberOfLines = 0;
    self.infoLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.infoLabel.text = @"We would like to draw your attention to a critical matter regarding the Mycelium iOS Wallet. We have identified certain technical issues within the application and, as a result, we advise you to refrain from sending and receiving BTC on it.\n\nHowever, we want to assure you that these issues are not related to the security of your funds. They remain safe and secure within the wallet. Please make sure you have made a backup. If not, please take the time to make it right now to secure your funds.\n\nOur team is diligently working on a new and improved version of the Mycelium iOS Wallet, which we anticipate will be released soon. In the meantime, we apologize for any inconvenience caused and thank you for your cooperation and patience.";
    [stackView addArrangedSubview:self.infoLabel];
}

- (void)setupBackupButton {
    self.backupButton = [[UIButton alloc] initWithFrame:CGRectZero];
    self.backupButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.backupButton addTarget:self action:@selector(didTapBackupButton) forControlEvents:UIControlEventTouchUpInside];
    [self.backupButton setTitle:@"Make backup" forState:UIControlStateNormal];
    [self.backupButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.backupButton.backgroundColor = [UIColor colorWithRed:0.0 green:122/255.0 blue:1 alpha:1];
    self.backupButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.backupButton.layer.cornerRadius = 14;
    [self.view addSubview:self.backupButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.backupButton.topAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:16],
        [self.backupButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [self.backupButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],
        [self.backupButton.heightAnchor constraintEqualToConstant:52]
    ]];
}

- (void)setupCloseButton {
    self.closeButton = [[UIButton alloc] initWithFrame:CGRectZero];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.closeButton addTarget:self action:@selector(didTapCloseButton) forControlEvents:UIControlEventTouchUpInside];
    [self.closeButton setTitle:@"Close" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor colorWithRed:0.0 green:122/255.0 blue:1 alpha:1] forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [self.view addSubview:self.closeButton];
    NSArray *constraints = @[
        [self.closeButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [self.closeButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],
        [self.closeButton.heightAnchor constraintEqualToConstant:52],
        [self.closeButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
    ];
    if (self.hideBackupButton) {
        constraints = [constraints arrayByAddingObject:[self.closeButton.topAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:16]];
    } else {
        constraints = [constraints arrayByAddingObject:[self.closeButton.topAnchor constraintEqualToAnchor:self.backupButton.bottomAnchor constant:16]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)didTapBackupButton {
    __weak typeof(self) weakSelf = self;
    [self dismissViewControllerAnimated:NO completion:^{
        weakSelf.makeBackupAction();
    }];
}

- (void)didTapCloseButton {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
