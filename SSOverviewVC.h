#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSGaugeView : UIView
@property (nonatomic, assign) double usedFraction;
@property (nonatomic, strong) UIColor *fillColor;
@end

@interface SSOverviewVC : UITableViewController
- (void)storeUpdated:(NSNotification *)note;
- (void)scanTapped;
- (void)settingsTapped;
- (UIView *)buildHeaderView;
- (void)refreshHeader;
@end

NS_ASSUME_NONNULL_END
