#import <UIKit/UIKit.h>
#import "SSModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface SSDupDetailVC : UITableViewController
@property (nonatomic, strong) SSDupGroup *group;
@property (nonatomic, strong, nullable) UIView *footerView;
@property (nonatomic, strong, nullable) UIButton *trashButton;
@property (nonatomic, strong, nullable) UIButton *backupButton;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedPaths;
- (instancetype)initWithGroup:(SSDupGroup *)group;
- (void)trashSelectedTapped;
- (void)backupSelectedTapped;
- (void)toggleAllTapped;
- (void)layoutFooterForWidth:(CGFloat)w;
- (void)backupItems:(NSArray<SSFileItem *> *)items;
- (void)shareZipAtPath:(NSString *)zipPath;
@end

@interface SSDupsVC : UITableViewController
- (void)storeUpdated:(NSNotification *)note;
@end

NS_ASSUME_NONNULL_END
