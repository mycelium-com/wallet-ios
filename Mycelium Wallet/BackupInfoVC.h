//
//  BackupInfoVC.h
//  Mycelium Wallet
//
//  Created by Almir A on 05.05.2023.
//  Copyright © 2023 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BackupInfoVC : UIViewController

@property (nonatomic, copy, nullable) void (^makeBackupAction)();
@property (nonatomic) BOOL hideBackupButton;

@end

NS_ASSUME_NONNULL_END
