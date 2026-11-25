#import "SSFilesVC.h"
#import "SSModels.h"
#import "SSUtil.h"
#import "SSLog.h"

@interface SSFilesVC ()
@property (nonatomic, strong) UIView *headerView;
- (void)layoutHeaderForWidth:(CGFloat)w;
- (BOOL)isBlockedItem:(SSFileItem *)item;
- (void)confirmTrashProtectedItem:(SSFileItem *)item;
- (NSArray<SSFileItem *> *)selectedItems;
- (void)updateToolbar;
- (void)doTrashItems:(NSArray<SSFileItem *> *)items;
- (void)shareZipAtPath:(NSString *)zipPath;
- (void)showMessage:(NSString *)title message:(NSString *)message;
@end

@implementation SSFilesVC

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [SSUtil applyThemeToViewController:self];
    self.title = @"File nặng";
    self.selectedPaths = [NSMutableSet set];
    self.filterControl = [[UISegmentedControl alloc] initWithItems:@[@"Tất cả", @"Ảnh", @"Video", @"Ghi âm", @"Tải về", @"Cài đặt"]];
    self.filterControl.selectedSegmentIndex = 0;
    [self.filterControl addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 52)];
    [header addSubview:self.filterControl];
    self.headerView = header;
    [self layoutHeaderForWidth:header.bounds.size.width];
    self.tableView.tableHeaderView = header;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Chọn"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self action:@selector(toggleSelectMode)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeUpdated:) name:SSStoreDidUpdateNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [SSUtil applyThemeToViewController:self];
    if (self.selecting) {
        [self updateToolbar];
        self.navigationController.toolbarHidden = NO;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.toolbarHidden = YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// Dung lai khung header theo chieu rong that khi layout (sua loi 1.0.0).
- (void)layoutHeaderForWidth:(CGFloat)w {
    if (w <= 0) return;
    self.headerView.frame = CGRectMake(0, 0, w, 52);
    self.filterControl.frame = CGRectMake(16, 10, w - 32, 32);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.tableView.bounds.size.width;
    if (w > 0 && fabs(self.headerView.frame.size.width - w) > 0.5) {
        [self layoutHeaderForWidth:w];
        self.tableView.tableHeaderView = self.headerView;
    }
}

- (void)storeUpdated:(NSNotification *)note {
    if ([SSStore sharedStore].scanning) {
        [self.selectedPaths removeAllObjects];
        if (self.selecting) [self toggleSelectMode];
    }
    [self.tableView reloadData];
    if (self.selecting) [self updateToolbar];
}

- (void)filterChanged {
    [self.tableView reloadData];
}

- (NSArray *)visibleItems {
    SSScanResult *r = [SSStore sharedStore].result;
    if (!r) return @[];
    NSMutableArray *out = [NSMutableArray array];
    NSInteger f = self.filterControl.selectedSegmentIndex;
    for (SSFileItem *it in r.topFiles) {
        BOOL keep = NO;
        switch (f) {
            case 0: keep = YES; break;
            case 1: keep = it.kind == SSItemKindPhoto; break;
            case 2: keep = it.kind == SSItemKindVideo; break;
            case 3: keep = it.kind == SSItemKindAudio; break;
            case 4: keep = it.downloaded; break;
            default: {
                NSString *ext = [[it.path pathExtension] lowercaseString];
                keep = [ext isEqualToString:@"deb"] || [ext isEqualToString:@"ipa"] || [ext isEqualToString:@"zip"];
                break;
            }
        }
        if (keep) [out addObject:it];
    }
    return out;
}

#pragma mark - Che do chon

- (BOOL)isBlockedItem:(SSFileItem *)item {
    return item.inLibrary || item.isProtected || [SSUtil isPathInAppBundle:item.path];
}

- (NSArray<SSFileItem *> *)selectedItems {
    SSScanResult *r = [SSStore sharedStore].result;
    NSMutableArray<SSFileItem *> *out = [NSMutableArray array];
    if (!r) return out;
    for (SSFileItem *it in r.topFiles) {
        if ([self.selectedPaths containsObject:it.path]) [out addObject:it];
    }
    return out;
}

- (void)toggleSelectMode {
    self.selecting = !self.selecting;
    if (!self.selecting) [self.selectedPaths removeAllObjects];
    self.navigationItem.rightBarButtonItem.title = self.selecting ? @"Xong" : @"Chọn";
    if (self.selecting) {
        [self updateToolbar];
        self.navigationController.toolbarHidden = NO;
    } else {
        self.navigationController.toolbarHidden = YES;
    }
    [self.tableView reloadData];
}

- (void)updateToolbar {
    NSArray<SSFileItem *> *sel = [self selectedItems];
    int64_t total = 0;
    for (SSFileItem *it in sel) total += it.size;
    UIBarButtonItem *all = [[UIBarButtonItem alloc] initWithTitle:@"Chọn hết" style:UIBarButtonItemStylePlain target:self action:@selector(selectAllTapped)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *backup = [[UIBarButtonItem alloc] initWithTitle:[NSString stringWithFormat:@"Backup (%lu)", (unsigned long)sel.count]
                                                               style:UIBarButtonItemStylePlain target:self action:@selector(backupSelectedTapped)];
    UIBarButtonItem *del = [[UIBarButtonItem alloc] initWithTitle:[NSString stringWithFormat:@"Xoá (%lu • %@)", (unsigned long)sel.count, [SSUtil formatBytes:total]]
                                                            style:UIBarButtonItemStylePlain target:self action:@selector(deleteSelectedTapped)];
    backup.enabled = sel.count > 0;
    del.enabled = sel.count > 0;
    self.toolbarItems = @[all, flex, backup, flex, del];
}

- (void)selectAllTapped {
    NSArray *items = [self visibleItems];
    BOOL allSelected = items.count > 0;
    for (SSFileItem *it in items) {
        if (![self.selectedPaths containsObject:it.path]) { allSelected = NO; break; }
    }
    if (allSelected) {
        for (SSFileItem *it in items) [self.selectedPaths removeObject:it.path];
    } else {
        for (SSFileItem *it in items) [self.selectedPaths addObject:it.path];
    }
    [self.tableView reloadData];
    [self updateToolbar];
}

#pragma mark - Bang

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MAX((NSInteger)[self visibleItems].count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    SSScanResult *r = [SSStore sharedStore].result;
    if (!r) return @"Chưa có dữ liệu — sang tab Tổng quan và quét trước";
    return [NSString stringWithFormat:@"%lu file lớn nhất (từ 5 MB) — bấm Chọn để tick xoá nhiều file hoặc xoá hết",
            (unsigned long)[self visibleItems].count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    NSArray *items = [self visibleItems];
    if (items.count == 0) {
        cell.textLabel.text = @"Không có file nào ở mục này";
        cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    SSFileItem *it = items[indexPath.row];
    cell.textLabel.text = it.name;
    cell.textLabel.numberOfLines = 2;
    NSMutableString *sub = [NSMutableString stringWithFormat:@"%@ • %@ • %@", [SSUtil formatBytes:it.size], [it kindLabel], [it levelLabel]];
    if (it.ownerName.length > 0) [sub appendFormat:@"\nThuộc: %@", it.ownerName];
    else if (it.appName.length > 0) [sub appendFormat:@"\nThuộc: %@", it.appName];
    if (it.note.length > 0) [sub appendFormat:@"\n%@", it.note];
    [sub appendFormat:@"\n%@", it.path];
    cell.detailTextLabel.text = sub;
    cell.detailTextLabel.numberOfLines = 5;
    if (self.selecting) {
        if ([self isBlockedItem:it]) {
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.textColor = [UIColor secondaryLabelColor];
        } else {
            cell.accessoryType = [self.selectedPaths containsObject:it.path] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            cell.textLabel.textColor = [UIColor labelColor];
        }
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = [UIColor labelColor];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *items = [self visibleItems];
    if (items.count == 0) return;
    SSFileItem *it = items[indexPath.row];
    if (self.selecting) {
        if ([self isBlockedItem:it]) {
            [self showMessage:@"File này chỉ xem"
                      message:@"File nằm trong thư viện Ảnh hoặc trong gói ứng dụng — SpaceScope không xoá trực tiếp để tránh hỏng dữ liệu. Xoá ảnh bằng app Ảnh; gỡ app nếu không dùng nữa."];
            return;
        }
        if ([self.selectedPaths containsObject:it.path]) [self.selectedPaths removeObject:it.path];
        else [self.selectedPaths addObject:it.path];
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        [self updateToolbar];
        return;
    }
    [self showFileActions:it];
}

#pragma mark - Thao tac 1 file


- (void)confirmTrashProtectedItem:(SSFileItem *)item {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ File thuộc vùng được bảo vệ"
        message:[NSString stringWithFormat:@"%@\n%@\nChỉ xoá khi anh thật chắc chắn — file sẽ vào thùng rác tạm, khôi phục được trong %ld ngày.", item.note, item.path, (long)[SSUtil trashKeepDays]]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Vẫn xoá file này" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSString *err = [SSUtil moveToTrashProtectedOverride:item.path];
        if (err) {
            [self showMessage:@"Không xoá được" message:err];
            return;
        }
        [[[SSStore sharedStore].result topFiles] removeObject:item];
        [self.selectedPaths removeObject:item.path];
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showFileActions:(SSFileItem *)item {
    NSString *msg = [NSString stringWithFormat:@"%@ • %@ • %@\n%@\n%@",
                     [SSUtil formatBytes:item.size], [item kindLabel], [item levelLabel],
                     item.note.length > 0 ? item.note : @"", item.path];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:item.name
        message:msg preferredStyle:UIAlertControllerStyleActionSheet];
    if (![self isBlockedItem:item]) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Chuyển vào thùng rác tạm" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            [self confirmTrashItem:item];
        }]];
    } else if (item.isProtected) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Xoá file này vào thùng rác (đã cân nhắc kỹ)" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            [self confirmTrashProtectedItem:item];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Backup file này (file zip)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self backupItems:@[item]];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Sao chép đường dẫn" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string = item.path;
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)confirmTrashItem:(SSFileItem *)item {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chuyển vào thùng rác tạm?"
        message:[NSString stringWithFormat:@"%@ (%@) sẽ vào thùng rác tạm của SpaceScope, giữ %ld ngày rồi tự xoá hẳn. Khôi phục được trong tab Dọn dẹp.",
                 item.name, [SSUtil formatBytes:item.size], (long)[SSUtil trashKeepDays]]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Chuyển" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSString *err = [SSUtil moveToTrash:item.path];
        if (err) {
            [self showMessage:@"Không chuyển được" message:err];
            return;
        }
        [[[SSStore sharedStore].result topFiles] removeObject:item];
        [self.selectedPaths removeObject:item.path];
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Xoa nhieu file / xoa het

- (void)deleteSelectedTapped {
    NSArray<SSFileItem *> *sel = [self selectedItems];
    if (sel.count == 0) {
        [self showMessage:@"Chưa chọn file nào" message:@"Tick vào từng file cần xoá, hoặc bấm \"Chọn hết\" để chọn toàn bộ danh sách đang hiện."];
        return;
    }
    [self trashItems:sel];
}

- (void)trashItems:(NSArray<SSFileItem *> *)items {
    NSMutableArray<SSFileItem *> *targets = [NSMutableArray array];
    NSInteger blocked = 0;
    int64_t total = 0;
    NSInteger risky = 0;
    for (SSFileItem *it in items) {
        if ([self isBlockedItem:it]) { blocked++; continue; }
        [targets addObject:it];
        total += it.size;
        if (it.level != SSFileLevelSafe) risky++;
    }
    if (targets.count == 0) {
        [self showMessage:@"Không xoá được" message:@"Các file đã chọn đều nằm trong thư viện Ảnh hoặc gói ứng dụng — chỉ xem, không xoá trực tiếp được."];
        return;
    }
    NSString *blockedNote = blocked > 0 ? [NSString stringWithFormat:@"\n(%ld file trong thư viện Ảnh/gói app sẽ được bỏ qua — chỉ xem.)", (long)blocked] : @"";
    if (risky == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chuyển vào thùng rác tạm?"
            message:[NSString stringWithFormat:@"%lu file (%@) đều ở mức an toàn. Tất cả sẽ vào thùng rác tạm, giữ %ld ngày, khôi phục được trong tab Dọn dẹp.%@",
                     (unsigned long)targets.count, [SSUtil formatBytes:total], (long)[SSUtil trashKeepDays], blockedNote]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Chuyển tất cả" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            [self doTrashItems:targets];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Có file cần cân nhắc"
        message:[NSString stringWithFormat:@"Trong %lu file (%@) có %ld file ở mức 🟡 Cân nhắc hoặc 🔴 Không nên xoá. Anh nên backup trước để đề phòng xoá nhầm.%@",
                 (unsigned long)targets.count, [SSUtil formatBytes:total], (long)risky, blockedNote]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Backup rồi xoá" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSString *zipPath = nil;
            NSString *err = [SSUtil createBackupZipForItems:targets outPath:&zipPath];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (err) {
                    [self showMessage:@"Backup không thành công — chưa xoá gì cả" message:err];
                    return;
                }
                SSLog(@"Da backup truoc khi xoa: %@", zipPath);
                [self doTrashItems:targets];
            });
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Xoá luôn (không backup)" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [self doTrashItems:targets];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)doTrashItems:(NSArray<SSFileItem *> *)items {
    NSInteger ok = 0;
    int64_t freed = 0;
    NSString *firstError = nil;
    for (SSFileItem *it in items) {
        NSString *err = [SSUtil moveToTrash:it.path];
        if (err) { if (!firstError) firstError = err; }
        else {
            ok++;
            freed += it.size;
            [[[SSStore sharedStore].result topFiles] removeObject:it];
            [self.selectedPaths removeObject:it.path];
        }
    }
    SSLog(@"File nang: chuyen %ld/%lu file vao thung rac (%@)", (long)ok, (unsigned long)items.count, [SSUtil formatBytes:freed]);
    if (self.selecting) [self toggleSelectMode];
    [self.tableView reloadData];
    NSString *msg = [NSString stringWithFormat:@"Đã chuyển %ld file (%@) vào thùng rác tạm. Khôi phục được trong tab Dọn dẹp.", (long)ok, [SSUtil formatBytes:freed]];
    if (firstError) msg = [msg stringByAppendingFormat:@"\nCó file không chuyển được: %@", firstError];
    [self showMessage:@"Đã dọn" message:msg];
}

#pragma mark - Backup

- (void)backupSelectedTapped {
    NSArray<SSFileItem *> *sel = [self selectedItems];
    if (sel.count == 0) {
        [self showMessage:@"Chưa chọn file nào" message:@"Tick vào các file cần backup trước."];
        return;
    }
    [self backupItems:sel];
}

- (void)backupItems:(NSArray<SSFileItem *> *)items {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *zipPath = nil;
        NSString *err = [SSUtil createBackupZipForItems:items outPath:&zipPath];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err) {
                [self showMessage:@"Backup không thành công" message:err];
                return;
            }
            [self shareZipAtPath:zipPath];
        });
    });
}

- (void)shareZipAtPath:(NSString *)zipPath {
    NSURL *url = [NSURL fileURLWithPath:zipPath];
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    av.popoverPresentationController.sourceView = self.view;
    av.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
    [self presentViewController:av animated:YES completion:nil];
}

- (void)showMessage:(NSString *)title message:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
