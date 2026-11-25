#import <UIKit/UIKit.h>
#import "SSModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface SSFilesVC : UITableViewController
@property (nonatomic, strong) UISegmentedControl *filterControl;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedPaths;
@property (nonatomic, assign) BOOL selecting;
- (void)storeUpdated:(NSNotification *)note;
- (void)filterChanged;
- (NSArray *)visibleItems;
- (void)confirmTrashItem:(SSFileItem *)item;
- (void)toggleSelectMode;
- (void)selectAllTapped;
- (void)deleteSelectedTapped;
- (void)backupSelectedTapped;
- (void)trashItems:(NSArray<SSFileItem *> *)items;
- (void)backupItems:(NSArray<SSFileItem *> *)items;
- (void)showFileActions:(SSFileItem *)item;
@end

NS_ASSUME_NONNULL_END
