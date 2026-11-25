#import <UIKit/UIKit.h>
#import "SSModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface SSAppDetailVC : UITableViewController
@property (nonatomic, strong) SSAppUsage *app;
- (instancetype)initWithApp:(SSAppUsage *)app;
- (void)clearCacheTapped;
@end

@interface SSAppsVC : UITableViewController
- (void)storeUpdated:(NSNotification *)note;
@end

NS_ASSUME_NONNULL_END
