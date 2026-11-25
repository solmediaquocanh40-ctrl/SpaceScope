#import <UIKit/UIKit.h>
#import "SSModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface SSDupDetailVC : UITableViewController
@property (nonatomic, strong) SSDupGroup *group;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedPaths;
- (instancetype)initWithGroup:(SSDupGroup *)group;
- (void)trashSelectedTapped;
@end

@interface SSDupsVC : UITableViewController
- (void)storeUpdated:(NSNotification *)note;
@end

NS_ASSUME_NONNULL_END
