#import "SSCleanVC.h"
#import "SSUtil.h"
#import "SSLog.h"

@implementation SSCleanVC

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [SSUtil applyThemeToViewController:self];
    self.title = @"Dọn dẹp";
    self.selectedJunk = [NSMutableSet set];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Chọn"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self action:@selector(toggleSelectMode)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeUpdated:) name:SSStoreDidUpdateNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
    if (self.selecting) {
        [self updateJunkToolbar];
        self.navigationController.toolbarHidden = NO;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.toolbarHidden = YES;
}

- (void)storeUpdated:(NSNotification *)note {
    if ([SSStore sharedStore].scanning) {
        [self.selectedJunk removeAllObjects];
        if (self.selecting) [self toggleSelectMode];
    }
    [self.tableView reloadData];
}

#pragma mark - Che do chon nhieu muc rac

- (void)toggleSelectMode {
    self.selecting = !self.selecting;
    if (!self.selecting) [self.selectedJunk removeAllObjects];
    self.navigationItem.rightBarButtonItem.title = self.selecting ? @"Xong" : @"Chọn";
    if (self.selecting) {
        [self updateJunkToolbar];
        self.navigationController.toolbarHidden = NO;
    } else {
        self.navigationController.toolbarHidden = YES;
    }
    [self.tableView reloadData];
}

- (void)updateJunkToolbar {
    int64_t total = 0;
    for (SSJunkItem *j in self.selectedJunk) total += j.size;
    UIBarButtonItem *all = [[UIBarButtonItem alloc] initWithTitle:@"Chọn hết" style:UIBarButtonItemStylePlain target:self action:@selector(selectAllJunkTapped)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *run = [[UIBarButtonItem alloc] initWithTitle:[NSString stringWithFormat:@"Dọn (%lu • %@)", (unsigned long)self.selectedJunk.count, [SSUtil formatBytes:total]]
                                                            style:UIBarButtonItemStylePlain target:self action:@selector(runSelectedJunk)];
    run.enabled = self.selectedJunk.count > 0;
    self.toolbarItems = @[all, flex, run];
}

- (void)selectAllJunkTapped {
    NSMutableArray<SSJunkItem *> *all = [NSMutableArray array];
    for (SSJunkItem *j in [self itemsForTier:SSJunkTierSafe]) {
        if (j.action == SSJunkActionClearContents || j.action == SSJunkActionTrashItem) [all addObject:j];
    }
    for (SSJunkItem *j in [self itemsForTier:SSJunkTierCaution]) {
        if (j.action == SSJunkActionClearContents || j.action == SSJunkActionTrashItem) [all addObject:j];
    }
    BOOL allSelected = all.count > 0;
    for (SSJunkItem *j in all) {
        if (![self.selectedJunk containsObject:j]) { allSelected = NO; break; }
    }
    if (allSelected) [self.selectedJunk removeAllObjects];
    else [self.selectedJunk addObjectsFromArray:all];
    [self.tableView reloadData];
    [self updateJunkToolbar];
}

- (void)runSelectedJunk {
    if (self.selectedJunk.count == 0) return;
    NSArray<SSJunkItem *> *targets = [self.selectedJunk allObjects];
    int64_t total = 0;
    for (SSJunkItem *j in targets) total += j.size;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Dọn các mục đã chọn?"
        message:[NSString stringWithFormat:@"%lu mục (khoảng %@). Mục xanh xoá nội dung ngay (tự sinh lại), mục vàng chuyển vào thùng rác tạm khôi phục được.", (unsigned long)targets.count, [SSUtil formatBytes:total]]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Dọn tất cả" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            int64_t freed = 0;
            NSString *firstError = nil;
            for (SSJunkItem *j in targets) {
                if (j.action == SSJunkActionClearContents) {
                    freed += [SSUtil clearContentsOfDirectory:j.path];
                    for (NSString *extra in j.extraPaths) freed += [SSUtil clearContentsOfDirectory:extra];
                } else if (j.action == SSJunkActionTrashItem) {
                    NSString *err = [SSUtil moveToTrash:j.path];
                    if (err) { if (!firstError) firstError = err; }
                    else freed += j.size;
                }
            }
            SSLog(@"Don nhieu muc rac: %lu muc, giai phong %@", (unsigned long)targets.count, [SSUtil formatBytes:freed]);
            dispatch_async(dispatch_get_main_queue(), ^{
                for (SSJunkItem *j in targets) [[[SSStore sharedStore].result junkItems] removeObject:j];
                [self.selectedJunk removeAllObjects];
                if (self.selecting) [self toggleSelectMode];
                [self.tableView reloadData];
                NSString *msg = [NSString stringWithFormat:@"Đã xử lý khoảng %@. Quét lại ở tab Tổng quan để thấy số liệu mới.", [SSUtil formatBytes:freed]];
                if (firstError) msg = [msg stringByAppendingFormat:@"\nCó mục không dọn được: %@", firstError];
                UIAlertController *done = [UIAlertController alertControllerWithTitle:@"Đã dọn" message:msg preferredStyle:UIAlertControllerStyleAlert];
                [done addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:done animated:YES completion:nil];
            });
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSArray<SSJunkItem *> *)itemsForTier:(SSJunkTier)tier {
    SSScanResult *r = [SSStore sharedStore].result;
    NSMutableArray *out = [NSMutableArray array];
    if (!r) return out;
    for (SSJunkItem *j in r.junkItems) if (j.tier == tier) [out addObject:j];
    return out;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 3) {
        NSInteger n = (NSInteger)[SSUtil trashManifestEntries].count;
        return n + 1; // them dong tong + nut xoa han tat ca o cuoi danh sach
    }
    return MAX((NSInteger)[self itemsForTier:(SSJunkTier)section].count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"🟢 Xanh — dọn an toàn";
        case 1: return @"🟡 Vàng — kiểm tra trước khi dọn";
        case 2: return @"ℹ️ Thông tin — tự xử lý theo hướng dẫn";
        default: return [NSString stringWithFormat:@"Thùng rác tạm — đang giữ %@ (giữ %ld ngày)", [SSUtil formatBytes:[SSUtil trashTotalSize]], (long)[SSUtil trashKeepDays]];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    if (indexPath.section == 3) {
        NSArray *entries = [SSUtil trashManifestEntries];
        if (indexPath.row < (NSInteger)entries.count) {
            NSDictionary *e = entries[indexPath.row];
            cell.textLabel.text = e[@"name"];
            NSDate *d = [NSDate dateWithTimeIntervalSince1970:[e[@"date"] doubleValue]];
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            fmt.dateFormat = @"dd/MM HH:mm";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@\nGốc: %@", [SSUtil formatBytes:[e[@"size"] longLongValue]], [fmt stringFromDate:d], e[@"orig"]];
            cell.detailTextLabel.numberOfLines = 3;
        } else {
            cell.textLabel.text = entries.count == 0 ? @"Thùng rác đang trống" : @"Xoá hẳn toàn bộ thùng rác";
            cell.textLabel.textColor = entries.count == 0 ? [UIColor labelColor] : [UIColor systemRedColor];
            cell.detailTextLabel.text = entries.count == 0 ? @"Mọi thứ anh dọn qua SpaceScope đều nằm ở đây trước khi xoá hẳn." : @"Giải phóng ngay toàn bộ dung lượng thùng rác đang giữ.";
            cell.detailTextLabel.numberOfLines = 2;
            return cell;
        }
        cell.textLabel.textColor = [UIColor labelColor];
        return cell;
    }
    NSArray<SSJunkItem *> *items = [self itemsForTier:(SSJunkTier)indexPath.section];
    if (items.count == 0) {
        cell.textLabel.text = @"Chưa có mục nào (hoặc chưa quét)";
        cell.detailTextLabel.text = nil;
        return cell;
    }
    SSJunkItem *j = items[indexPath.row];
    cell.textLabel.text = j.title;
    cell.textLabel.numberOfLines = 2;
    NSMutableString *sub = [NSMutableString string];
    if (j.action != SSJunkActionInfoOnly) [sub appendFormat:@"%@ — ", [SSUtil formatBytes:j.size]];
    [sub appendString:j.detail];
    if (j.path.length > 0) [sub appendFormat:@"\n%@", j.path];
    cell.detailTextLabel.text = sub;
    cell.detailTextLabel.numberOfLines = 4;
    if (self.selecting && indexPath.section < 2 && (j.action == SSJunkActionClearContents || j.action == SSJunkActionTrashItem)) {
        cell.accessoryType = [self.selectedJunk containsObject:j] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 3) {
        NSArray *entries = [SSUtil trashManifestEntries];
        if (indexPath.row < (NSInteger)entries.count) {
            [self showTrashEntryActions:entries[indexPath.row]];
        } else if (entries.count > 0) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Xoá hẳn toàn bộ thùng rác?"
                message:[NSString stringWithFormat:@"%@ sẽ được giải phóng ngay và KHÔNG khôi phục được nữa.", [SSUtil formatBytes:[SSUtil trashTotalSize]]]
                preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Xoá hẳn" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
                for (NSDictionary *e in [SSUtil trashManifestEntries]) [SSUtil purgeTrashEntry:e];
                [self.tableView reloadData];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
        return;
    }
    NSArray<SSJunkItem *> *items = [self itemsForTier:(SSJunkTier)indexPath.section];
    if (items.count == 0) return;
    SSJunkItem *j = items[indexPath.row];
    if (self.selecting && indexPath.section < 2 && (j.action == SSJunkActionClearContents || j.action == SSJunkActionTrashItem)) {
        if ([self.selectedJunk containsObject:j]) [self.selectedJunk removeObject:j];
        else [self.selectedJunk addObject:j];
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        [self updateJunkToolbar];
        return;
    }
    if (j.action == SSJunkActionBrowse) {
        if (self.selecting) return;
        NSMutableArray<NSString *> *roots = [NSMutableArray array];
        if (j.path.length > 0) [roots addObject:j.path];
        [roots addObjectsFromArray:j.extraPaths];
        SSBrowVC *vc = [[SSBrowVC alloc] initWithTitle:j.title roots:roots protectedMode:j.protectedZone];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if (j.action == SSJunkActionInfoOnly) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:j.title message:j.detail preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Đã hiểu" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    [self runJunkItem:j];
}

- (void)runJunkItem:(SSJunkItem *)item {
    NSString *actionText = item.action == SSJunkActionClearContents
        ? @"Toàn bộ nội dung bên trong sẽ bị xoá ngay (cache/log tự sinh lại được)."
        : @"Mục này sẽ chuyển vào thùng rác tạm, khôi phục được.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:item.title
        message:[NSString stringWithFormat:@"%@ (%@)\n%@", item.detail, [SSUtil formatBytes:item.size], actionText]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Dọn ngay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSString *errorText = nil;
            int64_t freed = 0;
            if (item.action == SSJunkActionClearContents) {
                freed += [SSUtil clearContentsOfDirectory:item.path];
                for (NSString *extra in item.extraPaths) freed += [SSUtil clearContentsOfDirectory:extra];
                SSLog(@"Don muc '%@': giai phong %@", item.title, [SSUtil formatBytes:freed]);
            } else {
                errorText = [SSUtil moveToTrash:item.path];
                if (!errorText) freed = item.size;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (errorText) {
                    UIAlertController *e = [UIAlertController alertControllerWithTitle:@"Không dọn được" message:errorText preferredStyle:UIAlertControllerStyleAlert];
                    [e addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:e animated:YES completion:nil];
                    return;
                }
                [[[SSStore sharedStore].result junkItems] removeObject:item];
                [self.tableView reloadData];
                UIAlertController *done = [UIAlertController alertControllerWithTitle:@"Đã dọn"
                    message:[NSString stringWithFormat:@"Đã xử lý %@. Quét lại ở tab Tổng quan để thấy số liệu mới.", [SSUtil formatBytes:freed]]
                    preferredStyle:UIAlertControllerStyleAlert];
                [done addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:done animated:YES completion:nil];
            });
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showTrashEntryActions:(NSDictionary *)entry {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:entry[@"name"]
        message:[NSString stringWithFormat:@"%@\nGốc: %@", [SSUtil formatBytes:[entry[@"size"] longLongValue]], entry[@"orig"]]
        preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Khôi phục về chỗ cũ" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *err = [SSUtil restoreTrashEntry:entry];
        if (err) {
            UIAlertController *e = [UIAlertController alertControllerWithTitle:@"Không khôi phục được" message:err preferredStyle:UIAlertControllerStyleAlert];
            [e addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:e animated:YES completion:nil];
            return;
        }
        [self.tableView reloadData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Xoá hẳn (không khôi phục được)" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [SSUtil purgeTrashEntry:entry];
        [self.tableView reloadData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

@end

#pragma mark - SSBrowVC: duyet toan bo noi dung cua mot nhom truoc khi xoa

@implementation SSBrowVC

- (instancetype)initWithTitle:(NSString *)title roots:(NSArray<NSString *> *)roots protectedMode:(BOOL)protectedMode {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _browseTitle = [title copy];
        _roots = roots;
        _protectedMode = protectedMode;
        _items = [NSMutableArray array];
        _selection = [NSMutableSet set];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [SSUtil applyThemeToViewController:self];
    self.title = self.browseTitle;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 78;
    if (!self.protectedMode) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Chọn" style:UIBarButtonItemStylePlain target:self action:@selector(toggleSelectMode)];
    }
    [self loadContents];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:!self.selecting animated:NO];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.selecting) [self.navigationController setToolbarHidden:YES animated:NO];
}

- (void)loadContents {
    self.loaded = NO;
    NSArray<NSString *> *roots = self.roots;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSMutableArray<SSFileItem *> *found = [NSMutableArray array];
        for (NSString *root in roots) {
            NSDirectoryEnumerator *en = [fm enumeratorAtPath:root];
            NSString *sub = nil;
            while ((sub = [en nextObject]) != nil) {
                NSString *full = [root stringByAppendingPathComponent:sub];
                if ([full containsString:@".app/"]) { [en skipDescendants]; continue; }
                NSDictionary *a = [en fileAttributes];
                if (![[a fileType] isEqualToString:NSFileTypeRegular]) continue;
                int64_t sz = (int64_t)[a fileSize];
                if (sz < 10 * 1024) continue;
                SSFileItem *it = [[SSFileItem alloc] init];
                it.path = full;
                it.name = [sub lastPathComponent];
                it.size = sz;
                it.created = [a fileCreationDate];
                it.modified = [a fileModificationDate];
                it.inLibrary = [SSUtil isPathInPhotoLibrary:full];
                [SSUtil classifyBrowsedItem:it];
                [found addObject:it];
                if (found.count >= 2000) break;
            }
        }
        [found sortUsingComparator:^NSComparisonResult(SSFileItem *a, SSFileItem *b) {
            return a.size > b.size ? NSOrderedAscending : (a.size < b.size ? NSOrderedDescending : NSOrderedSame);
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.items = found;
            self.loaded = YES;
            [self.tableView reloadData];
        });
    });
}

- (BOOL)isBlockedItem:(SSFileItem *)item {
    return item.inLibrary || [SSUtil isPathInAppBundle:item.path];
}

- (NSInteger)selectableCount {
    NSInteger n = 0;
    for (SSFileItem *i in self.items) if (![self isBlockedItem:i]) n++;
    return n;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!self.loaded) return 1;
    return MAX((NSInteger)self.items.count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (!self.loaded) return @"Đang đọc nội dung…";
    int64_t total = 0;
    for (SSFileItem *i in self.items) total += i.size;
    NSString *base = [NSString stringWithFormat:@"%ld file (từ 10 KB, nặng nhất trước) • %@", (long)self.items.count, [SSUtil formatBytes:total]];
    if (self.protectedMode) return [base stringByAppendingString:@"\n🛡️ Vùng được bảo vệ — chỉ xem/backup, xoá từng file khi thật chắc chắn."];
    return base;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (self.loaded && self.items.count == 0) return @"Không thấy file nào từ 10 KB trở lên trong mục này (thư mục trống, chỉ còn file rất nhỏ, hoặc không đọc được).";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (!self.loaded) {
        cell.textLabel.text = @"Đang đọc…";
        cell.detailTextLabel.text = nil;
        return cell;
    }
    if (self.items.count == 0) {
        cell.textLabel.text = @"(Trống)";
        cell.detailTextLabel.text = nil;
        return cell;
    }
    SSFileItem *item = self.items[indexPath.row];
    cell.textLabel.text = item.name;
    cell.textLabel.numberOfLines = 2;
    NSMutableString *sub = [NSMutableString stringWithFormat:@"%@ • %@ • %@", [SSUtil formatBytes:item.size], item.kindLabel, item.levelLabel];
    if (item.note.length > 0) [sub appendFormat:@"\n%@", item.note];
    [sub appendFormat:@"\n%@", item.path];
    cell.detailTextLabel.text = sub;
    cell.detailTextLabel.numberOfLines = 5;
    if (self.selecting) {
        cell.accessoryType = [self.selection containsObject:item] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.loaded || self.items.count == 0) return;
    SSFileItem *item = self.items[indexPath.row];
    if (self.selecting) {
        if ([self isBlockedItem:item]) {
            UIAlertController *a = [UIAlertController alertControllerWithTitle:item.name message:item.note preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"Đã hiểu" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
            return;
        }
        if ([self.selection containsObject:item]) [self.selection removeObject:item];
        else [self.selection addObject:item];
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        [self updateToolbar];
        return;
    }
    [self showItemActions:item];
}

- (void)toggleSelectMode {
    self.selecting = !self.selecting;
    if (!self.selecting) [self.selection removeAllObjects];
    self.navigationItem.rightBarButtonItem.title = self.selecting ? @"Xong" : @"Chọn";
    [self.navigationController setToolbarHidden:!self.selecting animated:YES];
    if (self.selecting) [self updateToolbar];
    [self.tableView reloadData];
}

- (void)updateToolbar {
    int64_t total = 0;
    for (SSFileItem *i in self.selection) total += i.size;
    BOOL allSelected = self.selection.count > 0 && (NSInteger)self.selection.count == [self selectableCount];
    UIBarButtonItem *all = [[UIBarButtonItem alloc] initWithTitle:allSelected ? @"Bỏ chọn hết" : @"Chọn hết"
                                                            style:UIBarButtonItemStylePlain target:self action:@selector(selectAllTapped)];
    UIBarButtonItem *heavy = [[UIBarButtonItem alloc] initWithTitle:@"File nặng" style:UIBarButtonItemStylePlain target:self action:@selector(selectHeavyTapped)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *backup = [[UIBarButtonItem alloc] initWithTitle:[NSString stringWithFormat:@"Backup (%lu)", (unsigned long)self.selection.count]
                                                               style:UIBarButtonItemStylePlain target:self action:@selector(backupSelected)];
    UIBarButtonItem *trash = [[UIBarButtonItem alloc] initWithTitle:[NSString stringWithFormat:@"Xoá (%lu • %@)", (unsigned long)self.selection.count, [SSUtil formatBytes:total]]
                                                              style:UIBarButtonItemStylePlain target:self action:@selector(trashSelected)];
    backup.enabled = self.selection.count > 0;
    trash.enabled = self.selection.count > 0;
    self.toolbarItems = @[all, heavy, flex, backup, trash];
}

- (void)selectAllTapped {
    if ((NSInteger)self.selection.count == [self selectableCount]) {
        [self.selection removeAllObjects];
    } else {
        for (SSFileItem *i in self.items) if (![self isBlockedItem:i]) [self.selection addObject:i];
    }
    [self.tableView reloadData];
    [self updateToolbar];
}

- (void)selectHeavyTapped {
    [self.selection removeAllObjects];
    for (SSFileItem *i in self.items) {
        if (![self isBlockedItem:i] && i.size >= 10LL * 1024 * 1024) [self.selection addObject:i];
    }
    if (self.selection.count == 0) {
        NSInteger added = 0;
        for (SSFileItem *i in self.items) {
            if ([self isBlockedItem:i]) continue;
            [self.selection addObject:i];
            if (++added >= 20) break;
        }
    }
    [self.tableView reloadData];
    [self updateToolbar];
}

- (void)backupSelected {
    if (self.selection.count == 0) return;
    NSArray<SSFileItem *> *targets = [self.selection allObjects];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *outPath = nil;
        NSString *err = [SSUtil createBackupZipForItems:targets outPath:&outPath];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err) {
                UIAlertController *e = [UIAlertController alertControllerWithTitle:@"Backup không thành công" message:err preferredStyle:UIAlertControllerStyleAlert];
                [e addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:e animated:YES completion:nil];
                return;
            }
            NSURL *url = [NSURL fileURLWithPath:outPath];
            UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
            [self presentViewController:av animated:YES completion:nil];
        });
    });
}

- (void)trashSelected {
    if (self.selection.count == 0) return;
    NSArray<SSFileItem *> *targets = [self.selection allObjects];
    int64_t total = 0;
    BOOL risky = NO;
    for (SSFileItem *i in targets) { total += i.size; if (i.level != SSFileLevelSafe) risky = YES; }
    if (!risky) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chuyển vào thùng rác tạm?"
            message:[NSString stringWithFormat:@"%lu file • %@ — đều là mục an toàn, vẫn khôi phục được từ thùng rác tạm.", (unsigned long)targets.count, [SSUtil formatBytes:total]]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Xoá" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { [self trashItems:targets backupFirst:NO]; }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ Có file cần cân nhắc trong danh sách chọn"
        message:[NSString stringWithFormat:@"%lu file • %@ — trong đó có file 🟡/🔴 (dữ liệu người dùng hoặc vùng bảo vệ). Nên backup trước khi xoá.", (unsigned long)targets.count, [SSUtil formatBytes:total]]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Backup rồi xoá" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self trashItems:targets backupFirst:YES]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Xoá luôn (không backup)" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { [self trashItems:targets backupFirst:NO]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)trashItems:(NSArray<SSFileItem *> *)targets backupFirst:(BOOL)backupFirst {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if (backupFirst) {
            NSString *outPath = nil;
            NSString *berr = [SSUtil createBackupZipForItems:targets outPath:&outPath];
            if (berr) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *e = [UIAlertController alertControllerWithTitle:@"Backup không thành công — đã huỷ xoá" message:berr preferredStyle:UIAlertControllerStyleAlert];
                    [e addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:e animated:YES completion:nil];
                });
                return;
            }
        }
        NSMutableArray<SSFileItem *> *done = [NSMutableArray array];
        NSString *firstError = nil;
        int64_t freed = 0;
        for (SSFileItem *item in targets) {
            NSString *err = item.isProtected ? [SSUtil moveToTrashProtectedOverride:item.path] : [SSUtil moveToTrash:item.path];
            if (!err) { [done addObject:item]; freed += item.size; }
            else if (!firstError) firstError = err;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            for (SSFileItem *item in done) {
                [self.items removeObject:item];
                [self.selection removeObject:item];
            }
            [self.tableView reloadData];
            if (self.selecting) [self updateToolbar];
            NSString *msg = [NSString stringWithFormat:@"Đã chuyển %lu file (%@) vào thùng rác tạm.", (unsigned long)done.count, [SSUtil formatBytes:freed]];
            if (firstError) msg = [msg stringByAppendingFormat:@"\nCó file không xoá được: %@", firstError];
            UIAlertController *doneAlert = [UIAlertController alertControllerWithTitle:@"Đã xử lý" message:msg preferredStyle:UIAlertControllerStyleAlert];
            [doneAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:doneAlert animated:YES completion:nil];
        });
    });
}

- (void)showItemActions:(SSFileItem *)item {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"dd/MM/yyyy";
    NSString *msg = [NSString stringWithFormat:@"%@ • %@ • %@", [SSUtil formatBytes:item.size], item.kindLabel, item.levelLabel];
    if (item.modified) msg = [msg stringByAppendingFormat:@"\nSửa đổi: %@", [fmt stringFromDate:item.modified]];
    if (item.note.length > 0) msg = [msg stringByAppendingFormat:@"\n%@", item.note];
    msg = [msg stringByAppendingFormat:@"\n%@", item.path];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:item.name message:msg preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Sao chép đường dẫn" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string = item.path;
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Backup file này (file zip)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSString *outPath = nil;
            NSString *err = [SSUtil createBackupZipForItems:@[item] outPath:&outPath];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (err) {
                    UIAlertController *e = [UIAlertController alertControllerWithTitle:@"Backup không thành công" message:err preferredStyle:UIAlertControllerStyleAlert];
                    [e addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:e animated:YES completion:nil];
                    return;
                }
                NSURL *url = [NSURL fileURLWithPath:outPath];
                UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
                [self presentViewController:av animated:YES completion:nil];
            });
        });
    }]];
    BOOL blocked = [self isBlockedItem:item];
    if (!blocked && item.isProtected) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Xoá file này vào thùng rác (đã cân nhắc kỹ)" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"⚠️ File thuộc vùng được bảo vệ"
                message:[NSString stringWithFormat:@"%@\n%@\nChỉ xoá khi anh thật chắc chắn — file sẽ vào thùng rác tạm, khôi phục được trong %ld ngày.", item.note, item.path, (long)[SSUtil trashKeepDays]]
                preferredStyle:UIAlertControllerStyleAlert];
            [confirm addAction:[UIAlertAction actionWithTitle:@"Vẫn xoá file này" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
                NSString *err = [SSUtil moveToTrashProtectedOverride:item.path];
                if (err) {
                    UIAlertController *e = [UIAlertController alertControllerWithTitle:@"Không xoá được" message:err preferredStyle:UIAlertControllerStyleAlert];
                    [e addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:e animated:YES completion:nil];
                    return;
                }
                [self.items removeObject:item];
                [self.tableView reloadData];
            }]];
            [confirm addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:confirm animated:YES completion:nil];
        }]];
    } else if (!blocked) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Chuyển vào thùng rác tạm" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            NSString *err = [SSUtil moveToTrash:item.path];
            if (err) {
                UIAlertController *e = [UIAlertController alertControllerWithTitle:@"Không xoá được" message:err preferredStyle:UIAlertControllerStyleAlert];
                [e addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:e animated:YES completion:nil];
                return;
            }
            [self.items removeObject:item];
            [self.selection removeObject:item];
            [self.tableView reloadData];
            if (self.selecting) [self updateToolbar];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
