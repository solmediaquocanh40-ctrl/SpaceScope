#import "SSSettingsVC.h"
#import "SSUtil.h"
#import "SSLog.h"
#import "SSModels.h"

@implementation SSLogVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [SSUtil applyThemeToViewController:self];
    self.title = @"Nhật ký SpaceScope";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    UITextView *tv = [[UITextView alloc] initWithFrame:self.view.bounds];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.editable = NO;
    tv.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    NSString *content = [NSString stringWithContentsOfFile:SSLogFilePath() encoding:NSUTF8StringEncoding error:nil];
    tv.text = content.length > 0 ? content : @"(Log đang trống)";
    [self.view addSubview:tv];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"]
                                                                              style:UIBarButtonItemStylePlain target:self action:@selector(shareTapped)];
}

- (void)shareTapped {
    NSURL *url = [NSURL fileURLWithPath:SSLogFilePath()];
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    [self presentViewController:av animated:YES completion:nil];
}

@end

@implementation SSSettingsVC

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [SSUtil applyThemeToViewController:self];
    self.title = @"Cài đặt";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [SSUtil applyThemeToViewController:self];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 6; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1;
        case 1: return 1;
        case 2: return 1;
        case 3: return 1;
        case 5: return 1;
        default: return 4;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Cảnh báo dung lượng";
        case 1: return @"Thùng rác tạm";
        case 2: return @"Tìm file trùng";
        case 3: return @"Danh sách bảo vệ";
        case 5: return @"Giao diện";
        default: return @"Nhật ký & thông tin";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Khi dung lượng trống tụt dưới mức này, tab Tổng quan sẽ báo MỨC NGUY HIỂM (dễ lag).";
        case 1: return @"Mọi file dọn qua SpaceScope đều vào thùng rác trước, quá số ngày này sẽ tự xoá hẳn.";
        case 2: return @"Chỉ đối chiếu các file từ kích thước này trở lên (áp dụng từ lần quét sau).";
        case 3: return @"App/thư mục trong danh sách này không bao giờ bị dọn hàng loạt — chỉ xem, backup, hoặc xoá từng file sau cảnh báo riêng. Mặc định đã bảo vệ dữ liệu Zalo và thư mục ghi âm cuộc gọi.";
        case 5: return @"Đổi màu nền cho toàn bộ app. Các mẫu nền tối sẽ tự chuyển chữ sang sáng cho dễ đọc.";
        default: return @"SpaceScope 1.2.0 — com.anhdang.spacescope. Nguyên tắc an toàn: file gốc của nhóm trùng không bao giờ bị xoá qua app; file trong thư viện Ảnh chỉ xem, xoá bằng app Ảnh; app/thư mục trong Danh sách bảo vệ không bị dọn hàng loạt, chỉ xử lý từng file sau cảnh báo riêng.";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (indexPath.section <= 2) {
        NSInteger value = indexPath.section == 0 ? [SSUtil warnFreeGB] : (indexPath.section == 1 ? [SSUtil trashKeepDays] : [SSUtil dupMinMB]);
        NSString *unit = indexPath.section == 0 ? @"GB" : (indexPath.section == 1 ? @"ngày" : @"MB");
        cell.textLabel.text = indexPath.section == 0 ? @"Báo nguy hiểm khi trống dưới" : (indexPath.section == 1 ? @"Giữ file trong thùng rác" : @"Chỉ xét file trùng từ");
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld %@", (long)value, unit];
        UIStepper *st = [[UIStepper alloc] init];
        st.tag = indexPath.section;
        st.minimumValue = 1;
        st.maximumValue = indexPath.section == 0 ? 20 : (indexPath.section == 1 ? 30 : 50);
        st.value = (double)value;
        [st addTarget:self action:@selector(stepperChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = st;
        return cell;
    }
    if (indexPath.section == 5) {
        cell.textLabel.text = @"Nền ứng dụng";
        NSInteger c = [SSUtil backgroundChoice];
        NSArray<NSString *> *names = [SSUtil backgroundNames];
        cell.detailTextLabel.text = (c >= 0 && c < (NSInteger)names.count) ? names[(NSUInteger)c] : names[0];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    if (indexPath.section == 3) {
        cell.textLabel.text = @"App & thư mục được bảo vệ";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld app • %ld thư mục", (long)[SSUtil protectedAppIDs].count, (long)[SSUtil protectedFolderPaths].count];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"Xem nhật ký gỡ lỗi";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        case 1:
            cell.textLabel.text = @"Chia sẻ file log";
            break;
        case 2: {
            cell.textLabel.text = @"Đường dẫn log";
            cell.detailTextLabel.text = SSLogFilePath();
            cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
            break;
        }
        default: {
            cell.textLabel.text = @"Chẩn đoán lần quét gần nhất";
            SSScanResult *r = [SSStore sharedStore].result;
            cell.detailTextLabel.text = r ? [NSString stringWithFormat:@"%ld file, %ld lỗi đọc", (long)r.fileCount, (long)r.errorCount] : @"Chưa quét";
            break;
        }
    }
    return cell;
}

- (void)stepperChanged:(UIStepper *)sender {
    NSInteger v = (NSInteger)sender.value;
    if (sender.tag == 0) [SSUtil setWarnFreeGB:v];
    else if (sender.tag == 1) [SSUtil setTrashKeepDays:v];
    else [SSUtil setDupMinMB:v];
    [self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 5) {
        [self.navigationController pushViewController:[[SSBackgroundVC alloc] init] animated:YES];
        return;
    }
    if (indexPath.section == 3) {
        [self.navigationController pushViewController:[[SSProtectVC alloc] init] animated:YES];
        return;
    }
    if (indexPath.section != 4) return;
    if (indexPath.row == 0) {
        [self.navigationController pushViewController:[[SSLogVC alloc] init] animated:YES];
    } else if (indexPath.row == 1) {
        NSURL *url = [NSURL fileURLWithPath:SSLogFilePath()];
        UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
        [self presentViewController:av animated:YES completion:nil];
    } else if (indexPath.row == 2) {
        [UIPasteboard generalPasteboard].string = SSLogFilePath();
    }
}

@end

#pragma mark - SSProtectVC: danh sach bao ve

@implementation SSProtectVC

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [SSUtil applyThemeToViewController:self];
    self.title = @"Danh sách bảo vệ";
    SSScanResult *r = [SSStore sharedStore].result;
    NSMutableArray *apps = [NSMutableArray array];
    if (r) [apps addObjectsFromArray:r.apps];
    [apps sortUsingComparator:^NSComparisonResult(SSAppUsage *a, SSAppUsage *b) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    self.apps = apps;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return MAX((NSInteger)self.apps.count, 1);
    return (NSInteger)[SSUtil protectedFolderPaths].count + 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Ứng dụng được bảo vệ" : @"Thư mục được bảo vệ";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"Bật = SpaceScope không dọn cache/dữ liệu của app đó theo kiểu hàng loạt, file của app bị khoá chọn xoá ở các danh sách. Mặc định đã bật cho Zalo (dữ liệu chat).";
    return @"Mọi file trong các thư mục này đều bị khoá xoá hàng loạt. Thư mục ghi âm cuộc gọi (AudioRecorder…) đã được bảo vệ sẵn theo tên, không cần thêm ở đây.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (indexPath.section == 0) {
        if (self.apps.count == 0) {
            cell.textLabel.text = @"Chưa có dữ liệu — hãy quét trước ở tab Tổng quan";
            cell.detailTextLabel.text = nil;
            return cell;
        }
        SSAppUsage *app = self.apps[indexPath.row];
        cell.textLabel.text = app.name;
        cell.detailTextLabel.text = app.bundleID;
        UISwitch *sw = [[UISwitch alloc] init];
        sw.tag = indexPath.row;
        sw.on = [[SSUtil protectedAppIDs] containsObject:app.bundleID];
        [sw addTarget:self action:@selector(toggleAppProtection:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        return cell;
    }
    NSArray<NSString *> *folders = [SSUtil protectedFolderPaths];
    if (indexPath.row < (NSInteger)folders.count) {
        cell.textLabel.text = [folders[indexPath.row] lastPathComponent];
        cell.detailTextLabel.text = folders[indexPath.row];
        cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    } else {
        cell.textLabel.text = @"Thêm thư mục…";
        cell.detailTextLabel.text = @"Nhập đường dẫn đầy đủ, ví dụ /var/mobile/Documents/GhiAm";
        cell.textLabel.textColor = [UIColor systemBlueColor];
    }
    return cell;
}

- (void)toggleAppProtection:(UISwitch *)sender {
    if (sender.tag < 0 || sender.tag >= (NSInteger)self.apps.count) return;
    SSAppUsage *app = self.apps[sender.tag];
    [SSUtil setAppID:app.bundleID protected:sender.on];
    SSLog(@"Danh sach bao ve: %@ -> %@", app.bundleID, sender.on ? @"BAT" : @"TAT");
}

- (void)addFolderTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thêm thư mục bảo vệ"
        message:@"Nhập đường dẫn đầy đủ của thư mục. Mọi file bên trong sẽ bị khoá xoá hàng loạt."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"/var/mobile/...";
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Thêm" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *path = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([path hasPrefix:@"/"] && path.length > 1) {
            [SSUtil addProtectedFolderPath:path];
            [self.tableView reloadData];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 1) return;
    NSArray<NSString *> *folders = [SSUtil protectedFolderPaths];
    if (indexPath.row == (NSInteger)folders.count) {
        [self addFolderTapped];
        return;
    }
    NSString *path = folders[indexPath.row];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bỏ bảo vệ thư mục này?"
        message:path preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Bỏ bảo vệ" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [SSUtil removeProtectedFolderPath:path];
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - SSBackgroundVC: chon nen ung dung

@implementation SSBackgroundVC

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Nền ứng dụng";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[SSUtil backgroundNames].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Nền áp dụng cho mọi tab ngay khi chọn. 'Mặc định' = nền sáng/tối theo hệ thống; các mẫu tối (Xanh đậm, Đen tuyền) tự chuyển toàn bộ chữ sang sáng.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    cell.textLabel.text = [SSUtil backgroundNames][(NSUInteger)indexPath.row];
    cell.accessoryType = indexPath.row == [SSUtil backgroundChoice] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    UIColor *c = [SSUtil backgroundColorForChoice:indexPath.row] ?: [UIColor systemGroupedBackgroundColor];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(24, 24)];
    cell.imageView.image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [c setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(1, 1, 22, 22)] fill];
        [[UIColor separatorColor] setStroke];
        UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1, 1, 22, 22)];
        ring.lineWidth = 1;
        [ring stroke];
    }];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [SSUtil setBackgroundChoice:indexPath.row];
    [SSUtil applyThemeToViewController:self];
    [self.tableView reloadData];
    SSLog(@"Doi nen ung dung: %@", [SSUtil backgroundNames][(NSUInteger)indexPath.row]);
}

@end
