#import <UIKit/UIKit.h>
#import "SSModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface SSBrowVC : UITableViewController
@property (nonatomic, copy) NSString *browseTitle;
@property (nonatomic, strong) NSArray<NSString *> *roots;
@property (nonatomic, assign) BOOL protectedMode;
@property (nonatomic, strong) NSMutableArray<SSFileItem *> *items;
@property (nonatomic, strong) NSMutableSet<SSFileItem *> *selection;
@property (nonatomic, assign) BOOL selecting;
@property (nonatomic, assign) BOOL loaded;
- (instancetype)initWithTitle:(NSString *)title roots:(NSArray<NSString *> *)roots protectedMode:(BOOL)protectedMode;
- (void)loadContents;
- (void)toggleSelectMode;
- (void)selectAllTapped;
- (void)selectHeavyTapped;
- (void)backupSelected;
- (void)trashSelected;
- (void)updateToolbar;
- (void)showItemActions:(SSFileItem *)item;
@end

@interface SSCleanVC : UITableViewController
@property (nonatomic, strong) NSMutableSet<SSJunkItem *> *selectedJunk;
@property (nonatomic, assign) BOOL selecting;
- (void)storeUpdated:(NSNotification *)note;
- (NSArray<SSJunkItem *> *)itemsForTier:(SSJunkTier)tier;
- (void)runJunkItem:(SSJunkItem *)item;
- (void)showTrashEntryActions:(NSDictionary *)entry;
- (void)toggleSelectMode;
- (void)selectAllJunkTapped;
- (void)runSelectedJunk;
- (void)updateJunkToolbar;
@end

NS_ASSUME_NONNULL_END
