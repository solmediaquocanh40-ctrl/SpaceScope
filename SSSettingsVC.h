#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSLogVC : UIViewController
- (void)shareTapped;
@end

@interface SSSettingsVC : UITableViewController
- (void)stepperChanged:(UIStepper *)sender;
@end

NS_ASSUME_NONNULL_END
