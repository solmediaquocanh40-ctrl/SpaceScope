#import "SSOverviewVC.h"
#import "SSModels.h"
#import "SSUtil.h"
#import "SSSettingsVC.h"

@implementation SSGaugeView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _fillColor = [UIColor systemGreenColor];
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGFloat radius = rect.size.height / 2.0;
    UIBezierPath *bg = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
    [[UIColor systemGray5Color] setFill];
    [bg fill];
    CGFloat w = rect.size.width * (CGFloat)MIN(MAX(self.usedFraction, 0.0), 1.0);
    if (w > 1) {
        CGRect fr = CGRectMake(rect.origin.x, rect.origin.y, w, rect.size.height);
        UIBezierPath *fg = [UIBezierPath bezierPathWithRoundedRect:fr cornerRadius:radius];
        [self.fillColor setFill];
        [fg fill];
    }
}
@end

@interface SSOverviewVC ()
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) SSGaugeView *gauge;
@property (nonatomic, strong) UILabel *scanLabel;
@end

@implementation SSOverviewVC

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Tổng quan";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.clockwise"]
                                                                              style:UIBarButtonItemStylePlain target:self action:@selector(scanTapped)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"]
                                                                             style:UIBarButtonItemStylePlain target:self action:@selector(settingsTapped)];
    self.tableView.tableHeaderView = [self buildHeaderView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeUpdated:) name:SSStoreDidUpdateNotification object:nil];
    [self refreshHeader];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UIView *)buildHeaderView {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 168)];
    self.summaryLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 14, header.bounds.size.width - 40, 26)];
    self.summaryLabel.font = [UIFont boldSystemFontOfSize:19];
    self.summaryLabel.adjustsFontSizeToFitWidth = YES;
    [header addSubview:self.summaryLabel];
    self.gauge = [[SSGaugeView alloc] initWithFrame:CGRectMake(20, 48, header.bounds.size.width - 40, 18)];
    [header addSubview:self.gauge];
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 74, header.bounds.size.width - 40, 52)];
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.numberOfLines = 3;
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    [header addSubview:self.statusLabel];
    self.scanLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 128, header.bounds.size.width - 40, 30)];
    self.scanLabel.font = [UIFont systemFontOfSize:12];
    self.scanLabel.textColor = [UIColor tertiaryLabelColor];
    [header addSubview:self.scanLabel];
    return header;
}

- (void)refreshHeader {
    SSStore *store = [SSStore sharedStore];
    SSScanResult *r = store.result;
    if (store.scanning) {
        self.summaryLabel.text = @"Đang quét toàn máy…";
        self.statusLabel.text = store.progressText;
        self.scanLabel.text = @"Lần đầu quét có thể mất vài phút tuỳ lượng file.";
        return;
    }
    if (!r) {
        self.summaryLabel.text = @"Chưa có dữ liệu quét";
        self.statusLabel.text = @"Bấm nút quét lại ở góc phải để bắt đầu phân tích dung lượng.";
        self.scanLabel.text = @"";
        return;
    }
    int64_t used = r.diskTotal - r.diskFree;
    double frac = r.diskTotal > 0 ? (double)used / (double)r.diskTotal : 0;
    self.gauge.usedFraction = frac;
    double freeFrac = 1.0 - frac;
    self.gauge.fillColor = freeFrac < 0.05 ? [UIColor systemRedColor] : (freeFrac < 0.10 ? [UIColor systemOrangeColor] : [UIColor systemGreenColor]);
    [self.gauge setNeedsDisplay];
    self.summaryLabel.text = [NSString stringWithFormat:@"Còn trống %@ / %@", [SSUtil formatBytes:r.diskFree], [SSUtil formatBytes:r.diskTotal]];
    int64_t safeTarget = (int64_t)(r.diskTotal * 0.10);
    NSInteger warnBytes = [SSUtil warnFreeGB] * 1024LL * 1024 * 1024;
    if (r.diskFree < warnBytes) {
        int64_t need = safeTarget - r.diskFree;
        self.statusLabel.text = [NSString stringWithFormat:@"⚠️ MỨC NGUY HIỂM: trống dưới %ld GB — iOS không còn chỗ cho cache và file tạm nên máy lag, app dễ văng.\nCần giải phóng thêm khoảng %@ để về mức an toàn (trống 10%%).",
                                 (long)[SSUtil warnFreeGB], [SSUtil formatBytes:MAX(need, (int64_t)0)]];
    } else if (r.diskFree < safeTarget) {
        self.statusLabel.text = [NSString stringWithFormat:@"Mức thấp: nên dọn thêm khoảng %@ để trống đạt 10%% cho máy mượt.", [SSUtil formatBytes:safeTarget - r.diskFree]];
    } else {
        self.statusLabel.text = @"Mức an toàn: dung lượng trống đang khoẻ (từ 10% trở lên).";
    }
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm dd/MM/yyyy";
    self.scanLabel.text = [NSString stringWithFormat:@"Quét lúc %@ — %ld file, đã phân tích %@", [fmt stringFromDate:r.scannedAt], (long)r.fileCount, [SSUtil formatBytes:r.scannedBytes]];
}

- (void)storeUpdated:(NSNotification *)note {
    [self refreshHeader];
    [self.tableView reloadData];
}

- (void)scanTapped {
    [[SSStore sharedStore] startScan];
}

- (void)settingsTapped {
    [self.navigationController pushViewController:[[SSSettingsVC alloc] init] animated:YES];
}

#pragma mark - Bang

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    SSScanResult *r = [SSStore sharedStore].result;
    if (!r) return 1;
    switch (section) {
        case 0: return MAX((NSInteger)[r topCauses].count, 1);
        case 1: return 3;
        case 2: return MAX((NSInteger)r.growthLeaders.count, 1);
        default: return 3;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Vì sao máy đầy — 3 nguyên nhân lớn nhất";
        case 1: return @"File mới sinh ra gần đây (theo ngày sửa)";
        case 2: return @"Phình nhanh nhất từ lần quét trước";
        default: return @"Dọn được ngay";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    SSScanResult *r = [SSStore sharedStore].result;
    if (!r) {
        cell.textLabel.text = [SSStore sharedStore].scanning ? @"Đang quét…" : @"Chưa quét";
        cell.detailTextLabel.text = @"";
        return cell;
    }
    if (indexPath.section == 0) {
        NSArray *causes = [r topCauses];
        if (causes.count == 0) {
            cell.textLabel.text = @"Chưa rõ nguyên nhân";
            cell.detailTextLabel.text = @"";
        } else {
            NSDictionary *c = causes[indexPath.row];
            cell.textLabel.text = c[@"title"];
            cell.textLabel.numberOfLines = 2;
            int64_t b = [c[@"bytes"] longLongValue];
            double pct = r.diskTotal > 0 ? (double)b / (double)r.diskTotal * 100.0 : 0;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%.0f%%)", [SSUtil formatBytes:b], pct];
        }
    } else if (indexPath.section == 1) {
        NSArray *labels = @[@"7 ngày qua", @"30 ngày qua", @"90 ngày qua"];
        int64_t vals[3] = {r.growth7, r.growth30, r.growth90};
        cell.textLabel.text = labels[indexPath.row];
        cell.detailTextLabel.text = [SSUtil formatBytes:vals[indexPath.row]];
    } else if (indexPath.section == 2) {
        if (r.growthLeaders.count == 0) {
            cell.textLabel.text = r.previousSnapshot ? @"Không app nào phình trên 50 MB" : @"Chưa có lần quét trước để so sánh";
            cell.detailTextLabel.text = @"";
        } else {
            NSDictionary *g = r.growthLeaders[indexPath.row];
            cell.textLabel.text = g[@"name"];
            cell.textLabel.numberOfLines = 2;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"+%@", [SSUtil formatBytes:[g[@"delta"] longLongValue]]];
        }
    } else {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Bản sao trùng lặp xoá được";
            cell.detailTextLabel.text = [SSUtil formatBytes:[r dupWastedBytes]];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Rác & file thừa dọn được";
            cell.detailTextLabel.text = [SSUtil formatBytes:[r junkTotalBytes]];
        } else {
            cell.textLabel.text = @"Thùng rác tạm đang giữ";
            cell.detailTextLabel.text = [SSUtil formatBytes:[SSUtil trashTotalSize]];
        }
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 3) return;
    NSInteger tab = indexPath.row == 0 ? 2 : 3;
    self.tabBarController.selectedIndex = tab;
}

@end
