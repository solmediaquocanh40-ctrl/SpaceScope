#import "SSAppsVC.h"
#import "SSUtil.h"
#import "SSLog.h"

@implementation SSAppsVC

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [SSUtil applyThemeToViewController:self];
    self.title = @"Ứng dụng";
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeUpdated:) name:SSStoreDidUpdateNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)storeUpdated:(NSNotification *)note {
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    SSScanResult *r = [SSStore sharedStore].result;
    return MAX((NSInteger)(r ? r.apps.count : 0), 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    SSScanResult *r = [SSStore sharedStore].result;
    if (!r) return @"Chưa có dữ liệu — sang tab Tổng quan và quét trước";
    return @"Ứng dụng xếp theo tổng dung lượng (gói cài + dữ liệu)";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    SSScanResult *r = [SSStore sharedStore].result;
    if (!r || r.apps.count == 0) {
        cell.textLabel.text = @"Chưa có dữ liệu ứng dụng";
        cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    SSAppUsage *app = r.apps[indexPath.row];
    cell.textLabel.text = app.name;
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Tổng %@ • Gói %@ • Dữ liệu %@ • Cache %@",
                                 [SSUtil formatBytes:app.totalSize], [SSUtil formatBytes:app.bundleSize],
                                 [SSUtil formatBytes:app.dataSize], [SSUtil formatBytes:app.cacheSize]];
    cell.detailTextLabel.numberOfLines = 2;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SSScanResult *r = [SSStore sharedStore].result;
    if (!r || r.apps.count == 0) return;
    [self.navigationController pushViewController:[[SSAppDetailVC alloc] initWithApp:r.apps[indexPath.row]] animated:YES];
}

@end

@implementation SSAppDetailVC

- (instancetype)initWithApp:(SSAppUsage *)app {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) _app = app;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [SSUtil applyThemeToViewController:self];
    self.title = self.app.name;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 6;
        case 1: return MAX((NSInteger)self.app.offlineHints.count, 1);
        case 2: return MAX((NSInteger)self.app.topItems.count, 1);
        default: return 2;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Dung lượng chi tiết";
        case 1: return @"Dấu vết nội dung tải offline / tải về trong app";
        case 2: return @"File lớn nhất trong app này (từ 5 MB)";
        default: return @"Thao tác";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    if (indexPath.section == 0) {
        NSArray *labels = @[@"Tổng cộng", @"Gói cài đặt (.app)", @"Dữ liệu trong máy", @"Trong đó: Tài liệu (Documents)", @"Trong đó: Cache", @"Trong đó: File tạm (tmp)"];
        int64_t vals[6] = {self.app.totalSize, self.app.bundleSize, self.app.dataSize, self.app.docsSize, self.app.cacheSize, self.app.tmpSize};
        cell.textLabel.text = labels[indexPath.row];
        cell.textLabel.numberOfLines = 2;
        cell.detailTextLabel.text = [SSUtil formatBytes:vals[indexPath.row]];
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else if (indexPath.section == 1) {
        if (self.app.offlineHints.count == 0) {
            cell.textLabel.text = @"Không thấy thư mục offline/download lớn";
            cell.detailTextLabel.text = @"";
        } else {
            cell.textLabel.text = self.app.offlineHints[indexPath.row];
            cell.textLabel.numberOfLines = 2;
            cell.detailTextLabel.text = @"";
        }
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else if (indexPath.section == 2) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"filecell"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"filecell"];
        if (self.app.topItems.count == 0) {
            cell.textLabel.text = @"Không có file nào từ 5 MB trong app này";
            cell.detailTextLabel.text = nil;
            return cell;
        }
        SSFileItem *it = self.app.topItems[indexPath.row];
        cell.textLabel.text = it.name;
        cell.textLabel.numberOfLines = 2;
        NSMutableString *sub = [NSMutableString stringWithFormat:@"%@ • %@ • %@", [SSUtil formatBytes:it.size], [it kindLabel], [it levelLabel]];
        if (it.note.length > 0) [sub appendFormat:@"\n%@", it.note];
        [sub appendFormat:@"\n%@", it.path];
        cell.detailTextLabel.text = sub;
        cell.detailTextLabel.numberOfLines = 4;
        return cell;
    } else {
        cell.textLabel.text = indexPath.row == 0 ? @"Dọn cache & file tạm của app này" : @"Sao chép đường dẫn vùng chứa";
        cell.textLabel.textColor = indexPath.row == 0 ? [UIColor systemRedColor] : [UIColor labelColor];
        cell.detailTextLabel.text = @"";
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 2) {
        if (self.app.topItems.count == 0) return;
        [self showFileActions:self.app.topItems[indexPath.row]];
        return;
    }
    if (indexPath.section != 3) return;
    if (indexPath.row == 1) {
        [UIPasteboard generalPasteboard].string = self.app.containerPath;
        return;
    }
    [self clearCacheTapped];
}

- (void)showFileActions:(SSFileItem *)item {
    NSString *msg = [NSString stringWithFormat:@"%@ • %@ • %@\n%@\n%@",
                     [SSUtil formatBytes:item.size], [item kindLabel], [item levelLabel],
                     item.note.length > 0 ? item.note : @"", item.path];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:item.name
        message:msg preferredStyle:UIAlertControllerStyleActionSheet];
    BOOL blocked = item.inLibrary || item.isProtected || [SSUtil isPathInAppBundle:item.path];
    if (!blocked) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Chuyển vào thùng rác tạm" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            [self confirmTrashItem:item];
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
        message:[NSString stringWithFormat:@"%@ (%@) sẽ vào thùng rác tạm, giữ %ld ngày, khôi phục được trong tab Dọn dẹp.",
                 item.name, [SSUtil formatBytes:item.size], (long)[SSUtil trashKeepDays]]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Chuyển" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSString *err = [SSUtil moveToTrash:item.path];
        if (err) {
            [self showMessage:@"Không chuyển được" message:err];
            return;
        }
        [self.app.topItems removeObject:item];
        [[[SSStore sharedStore].result topFiles] removeObject:item];
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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

- (void)clearCacheTapped {
    int64_t sz = self.app.cacheSize + self.app.tmpSize;
    if (sz <= 0 || self.app.containerPath.length == 0) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Không có cache để dọn" message:@"App này không có cache/file tạm đáng kể." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Dọn cache của %@?", self.app.name]
        message:[NSString stringWithFormat:@"Khoảng %@ cache và file tạm sẽ bị xoá ngay. App tự tạo lại khi cần, không mất dữ liệu chính (tin nhắn, tài khoản).", [SSUtil formatBytes:sz]]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Dọn ngay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSString *caches = [self.app.containerPath stringByAppendingPathComponent:@"Library/Caches"];
        NSString *tmp = [self.app.containerPath stringByAppendingPathComponent:@"tmp"];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            int64_t freed = [SSUtil clearContentsOfDirectory:caches] + [SSUtil clearContentsOfDirectory:tmp];
            SSLog(@"Don cache app %@: giai phong %@", self.app.bundleID, [SSUtil formatBytes:freed]);
            dispatch_async(dispatch_get_main_queue(), ^{
                self.app.cacheSize = 0;
                self.app.tmpSize = 0;
                self.app.dataSize -= freed;
                self.app.totalSize -= freed;
                [self.tableView reloadData];
            });
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
