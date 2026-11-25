#import "SSFilesVC.h"
#import "SSModels.h"
#import "SSUtil.h"

@interface SSFilesVC ()
@end

@implementation SSFilesVC

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"File nặng";
    self.filterControl = [[UISegmentedControl alloc] initWithItems:@[@"Tất cả", @"Ảnh", @"Video", @"Tải về", @"Cài đặt"]];
    self.filterControl.selectedSegmentIndex = 0;
    [self.filterControl addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 52)];
    self.filterControl.frame = CGRectMake(16, 10, header.bounds.size.width - 32, 32);
    [header addSubview:self.filterControl];
    self.tableView.tableHeaderView = header;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeUpdated:) name:SSStoreDidUpdateNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)storeUpdated:(NSNotification *)note {
    [self.tableView reloadData];
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
            case 3: keep = it.downloaded; break;
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MAX((NSInteger)[self visibleItems].count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    SSScanResult *r = [SSStore sharedStore].result;
    if (!r) return @"Chưa có dữ liệu — sang tab Tổng quan và quét trước";
    return [NSString stringWithFormat:@"%lu file lớn nhất (từ 5 MB trở lên)", (unsigned long)[self visibleItems].count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    NSArray *items = [self visibleItems];
    if (items.count == 0) {
        cell.textLabel.text = @"Không có file nào ở mục này";
        cell.detailTextLabel.text = nil;
        return cell;
    }
    SSFileItem *it = items[indexPath.row];
    cell.textLabel.text = it.name;
    cell.textLabel.numberOfLines = 2;
    NSMutableString *sub = [NSMutableString stringWithString:[SSUtil formatBytes:it.size]];
    if (it.appName.length > 0) [sub appendFormat:@" • %@", it.appName];
    if (it.inLibrary) [sub appendString:@" • Trong thư viện Ảnh"];
    [sub appendFormat:@"\n%@", it.path];
    cell.detailTextLabel.text = sub;
    cell.detailTextLabel.numberOfLines = 3;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *items = [self visibleItems];
    if (items.count == 0) return;
    SSFileItem *it = items[indexPath.row];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:it.name
        message:[NSString stringWithFormat:@"%@\n%@", [SSUtil formatBytes:it.size], it.path]
        preferredStyle:UIAlertControllerStyleActionSheet];
    BOOL canTrash = !it.inLibrary && ![SSUtil isPathInAppBundle:it.path];
    if (canTrash) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Chuyển vào thùng rác tạm" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            [self confirmTrashItem:it];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Sao chép đường dẫn" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string = it.path;
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
            UIAlertController *e = [UIAlertController alertControllerWithTitle:@"Không chuyển được" message:err preferredStyle:UIAlertControllerStyleAlert];
            [e addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:e animated:YES completion:nil];
            return;
        }
        [[[SSStore sharedStore].result topFiles] removeObject:item];
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
