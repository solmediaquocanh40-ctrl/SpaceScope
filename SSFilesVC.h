#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSFilesVC : UITableViewController
@property (nonatomic, strong) UISegmentedControl *filterControl;
- (void)storeUpdated:(NSNotification *)note;
- (void)filterChanged;
- (NSArray *)visibleItems;
- (void)confirmTrashItem:(SSFileItem *)item;
@end

NS_ASSUME_NONNULL_END
