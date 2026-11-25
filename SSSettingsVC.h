#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSLogVC : UIViewController
- (void)shareTapped;
@end

@interface SSProtectVC : UITableViewController
@property (nonatomic, strong) NSArray *apps;
- (void)toggleAppProtection:(UISwitch *)sender;
- (void)addFolderTapped;
@end

@interface SSBackgroundVC : UITableViewController
@end

@interface SSSettingsVC : UITableViewController
- (void)stepperChanged:(UIStepper *)sender;
@end

NS_ASSUME_NONNULL_END
