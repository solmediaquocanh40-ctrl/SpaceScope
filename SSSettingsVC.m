#import "SSSettingsVC.h"
#import "SSUtil.h"
#import "SSLog.h"
#import "SSModels.h"

@implementation SSLogVC

- (void)viewDidLoad {
    [super viewDidLoad];
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
    self.title = @"Cài đặt";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1;
        case 1: return 1;
        case 2: return 1;
        default: return 4;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Cảnh báo dung lượng";
        case 1: return @"Thùng rác tạm";
        case 2: return @"Tìm file trùng";
        default: return @"Nhật ký & thông tin";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Khi dung lượng trống tụt dưới mức này, tab Tổng quan sẽ báo MỨC NGUY HIỂM (dễ lag).";
        case 1: return @"Mọi file dọn qua SpaceScope đều vào thùng rác trước, quá số ngày này sẽ tự xoá hẳn.";
        case 2: return @"Chỉ đối chiếu các file từ kích thước này trở lên (áp dụng từ lần quét sau).";
        default: return @"SpaceScope 1.0.0 — com.anhdang.spacescope. Nguyên tắc an toàn: file gốc của nhóm trùng không bao giờ bị xoá qua app; file trong thư viện Ảnh chỉ xem, xoá bằng app Ảnh; cache xoá thẳng vì app tự tạo lại.";
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
    if (indexPath.section != 3) return;
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
