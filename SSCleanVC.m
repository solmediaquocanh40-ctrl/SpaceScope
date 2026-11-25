#import "SSCleanVC.h"
#import "SSUtil.h"
#import "SSLog.h"

@implementation SSCleanVC

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Dọn dẹp";
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeUpdated:) name:SSStoreDidUpdateNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)storeUpdated:(NSNotification *)note {
    [self.tableView reloadData];
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
    cell.detailTextLabel.text = j.action == SSJunkActionInfoOnly ? j.detail
        : [NSString stringWithFormat:@"%@ — %@", [SSUtil formatBytes:j.size], j.detail];
    cell.detailTextLabel.numberOfLines = 3;
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
