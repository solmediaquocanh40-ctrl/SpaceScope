#import "SSDupsVC.h"
#import "SSUtil.h"
#import "SSLog.h"

@implementation SSDupsVC

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Trùng lặp";
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    SSScanResult *r = [SSStore sharedStore].result;
    return MAX((NSInteger)(r ? r.dupGroups.count : 0), 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    SSScanResult *r = [SSStore sharedStore].result;
    if (!r) return @"Chưa có dữ liệu — sang tab Tổng quan và quét trước";
    return [NSString stringWithFormat:@"%lu nhóm trùng 100%% nội dung — xoá bản sao được %@, file gốc luôn giữ lại",
            (unsigned long)r.dupGroups.count, [SSUtil formatBytes:[r dupWastedBytes]]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    SSScanResult *r = [SSStore sharedStore].result;
    if (!r || r.dupGroups.count == 0) {
        cell.textLabel.text = @"Chưa phát hiện nhóm trùng nào";
        cell.detailTextLabel.text = @"Chỉ tính file từ ngưỡng đã đặt trong Cài đặt, đối chiếu bằng hash nội dung.";
        cell.detailTextLabel.numberOfLines = 2;
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    SSDupGroup *g = r.dupGroups[indexPath.row];
    cell.textLabel.text = g.original ? g.original.name : (g.items.firstObject.name ?: @"");
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu bản giống hệt • mỗi bản %@ • xoá bản sao được %@",
                                 (unsigned long)g.items.count, [SSUtil formatBytes:g.fileSize], [SSUtil formatBytes:[g wastedBytes]]];
    cell.detailTextLabel.numberOfLines = 2;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SSScanResult *r = [SSStore sharedStore].result;
    if (!r || r.dupGroups.count == 0) return;
    SSDupDetailVC *detail = [[SSDupDetailVC alloc] initWithGroup:r.dupGroups[indexPath.row]];
    [self.navigationController pushViewController:detail animated:YES];
}

@end

@implementation SSDupDetailVC

- (instancetype)initWithGroup:(SSDupGroup *)group {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _group = group;
        _selectedPaths = [NSMutableSet set];
        for (SSFileItem *it in [group deletableCopies]) [_selectedPaths addObject:it.path];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Nhóm trùng";
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(16, 12, self.view.bounds.size.width - 32, 48);
    [btn setTitle:@"Chuyển các bản sao đã chọn vào thùng rác" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [btn addTarget:self action:@selector(trashSelectedTapped) forControlEvents:UIControlEventTouchUpInside];
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 76)];
    [footer addSubview:btn];
    self.tableView.tableFooterView = footer;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.group.items.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [NSString stringWithFormat:@"%lu bản giống hệt nhau 100%% — mỗi bản %@", (unsigned long)self.group.items.count, [SSUtil formatBytes:self.group.fileSize]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    SSFileItem *it = self.group.items[indexPath.row];
    cell.textLabel.text = it.name;
    cell.textLabel.numberOfLines = 2;
    if (it == self.group.original) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"🔒 FILE GỐC — GIỮ LẠI (không xoá được)\n%@", it.path];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = [UIColor systemGreenColor];
    } else if (it.inLibrary) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Trong thư viện Ảnh — xoá bằng app Ảnh để không hỏng thư viện\n%@", it.path];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = [UIColor labelColor];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Bản sao — %@\n%@", it.appName.length > 0 ? it.appName : @"File rời", it.path];
        cell.accessoryType = [self.selectedPaths containsObject:it.path] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        cell.textLabel.textColor = [UIColor labelColor];
    }
    cell.detailTextLabel.numberOfLines = 3;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SSFileItem *it = self.group.items[indexPath.row];
    if (it == self.group.original || it.inLibrary) return;
    if ([self.selectedPaths containsObject:it.path]) [self.selectedPaths removeObject:it.path];
    else [self.selectedPaths addObject:it.path];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)trashSelectedTapped {
    NSMutableArray<SSFileItem *> *targets = [NSMutableArray array];
    for (SSFileItem *it in [self.group deletableCopies]) {
        if ([self.selectedPaths containsObject:it.path]) [targets addObject:it];
    }
    if (targets.count == 0) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Chưa chọn bản sao nào" message:@"Chạm vào từng bản sao để chọn/bỏ chọn. File gốc luôn bị khoá, không chọn được." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    int64_t total = 0;
    for (SSFileItem *it in targets) total += it.size;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chuyển bản sao vào thùng rác?"
        message:[NSString stringWithFormat:@"%lu bản sao (%@) sẽ vào thùng rác tạm, giữ %ld ngày. FILE GỐC vẫn ở nguyên vị trí.", (unsigned long)targets.count, [SSUtil formatBytes:total], (long)[SSUtil trashKeepDays]]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Chuyển" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSInteger ok = 0;
        NSString *firstError = nil;
        for (SSFileItem *it in targets) {
            NSString *err = [SSUtil moveToTrash:it.path];
            if (err) { if (!firstError) firstError = err; }
            else { ok++; [self.group.items removeObject:it]; }
        }
        SSLog(@"Nhom trung: chuyen %ld/%lu ban sao vao thung rac", (long)ok, (unsigned long)targets.count);
        if (self.group.items.count <= 1) {
            [[[SSStore sharedStore].result dupGroups] removeObject:self.group];
            [self.navigationController popViewControllerAnimated:YES];
        } else {
            [self.tableView reloadData];
        }
        if (firstError) {
            UIAlertController *e = [UIAlertController alertControllerWithTitle:@"Có bản sao không chuyển được" message:firstError preferredStyle:UIAlertControllerStyleAlert];
            [e addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:e animated:YES completion:nil];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
