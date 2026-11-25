#import <UIKit/UIKit.h>
#import "SSModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface SSCleanVC : UITableViewController
- (void)storeUpdated:(NSNotification *)note;
- (NSArray<SSJunkItem *> *)itemsForTier:(SSJunkTier)tier;
- (void)runJunkItem:(SSJunkItem *)item;
- (void)showTrashEntryActions:(NSDictionary *)entry;
@end

NS_ASSUME_NONNULL_END
