#import "SSModels.h"
#import "SSScanner.h"
#import "SSLog.h"

NSString * const SSStoreDidUpdateNotification = @"SSStoreDidUpdateNotification";

@implementation SSFileItem
- (instancetype)initWithPath:(NSString *)path size:(int64_t)size created:(NSDate *)created modified:(NSDate *)modified {
    self = [super init];
    if (self) {
        _path = [path copy];
        _name = [[path lastPathComponent] copy];
        _size = size;
        _created = created;
        _modified = modified;
        _appName = @"";
        _kind = SSItemKindOther;
        _level = SSFileLevelCaution;
        _note = @"";
        _ownerName = @"";
        _ownerPackage = @"";
    }
    return self;
}
- (NSString *)kindLabel {
    switch (self.kind) {
        case SSItemKindPhoto: return @"Ảnh";
        case SSItemKindVideo: return @"Video";
        case SSItemKindAudio: return @"Âm thanh";
        case SSItemKindArchive: return @"File nén";
        case SSItemKindDocument: return @"Tài liệu";
        default: return @"File";
    }
}
- (NSString *)levelLabel {
    switch (self.level) {
        case SSFileLevelSafe: return @"🟢 Xoá an toàn";
        case SSFileLevelDanger: return @"🔴 Không nên xoá";
        default: return @"🟡 Cân nhắc";
    }
}
@end

@implementation SSDupGroup
- (instancetype)init {
    self = [super init];
    if (self) {
        _items = [NSMutableArray array];
        _fullHash = @"";
    }
    return self;
}
- (NSArray<SSFileItem *> *)deletableCopies {
    NSMutableArray<SSFileItem *> *out = [NSMutableArray array];
    for (SSFileItem *it in self.items) {
        if (it != self.original && !it.inLibrary && !it.isProtected) [out addObject:it];
    }
    return out;
}
- (int64_t)wastedBytes {
    int64_t total = 0;
    for (SSFileItem *it in [self deletableCopies]) total += it.size;
    return total;
}
@end

@implementation SSAppUsage
- (instancetype)init {
    self = [super init];
    if (self) {
        _bundleID = @"";
        _name = @"";
        _containerPath = @"";
        _offlineHints = [NSMutableArray array];
        _topItems = [NSMutableArray array];
    }
    return self;
}
@end

@implementation SSJunkItem
- (instancetype)init {
    self = [super init];
    if (self) {
        _title = @"";
        _detail = @"";
        _path = @"";
        _extraPaths = [NSMutableArray array];
    }
    return self;
}
@end

@implementation SSScanResult
- (instancetype)init {
    self = [super init];
    if (self) {
        _scannedAt = [NSDate date];
        _categoryBytes = [NSMutableDictionary dictionary];
        _topFiles = [NSMutableArray array];
        _apps = [NSMutableArray array];
        _dupGroups = [NSMutableArray array];
        _junkItems = [NSMutableArray array];
        _growthLeaders = [NSMutableArray array];
    }
    return self;
}
- (int64_t)dupWastedBytes {
    int64_t total = 0;
    for (SSDupGroup *g in self.dupGroups) total += [g wastedBytes];
    return total;
}
- (int64_t)junkTotalBytes {
    int64_t total = 0;
    for (SSJunkItem *j in self.junkItems) {
        if (j.action != SSJunkActionInfoOnly) total += j.size;
    }
    return total;
}
- (NSArray<NSDictionary *> *)topCauses {
    NSMutableArray<NSDictionary *> *causes = [NSMutableArray array];
    int64_t photoVideo = [self.categoryBytes[@"photo"] longLongValue] + [self.categoryBytes[@"video"] longLongValue];
    if (photoVideo > 0) [causes addObject:@{@"title": @"Ảnh & video", @"bytes": @(photoVideo), @"note": @"Trong thư viện, các app và thư mục tải về"}];
    if (self.apps.count > 0) {
        SSAppUsage *top = self.apps.firstObject;
        if (top.totalSize > 0) [causes addObject:@{@"title": [NSString stringWithFormat:@"Ứng dụng nặng nhất: %@", top.name], @"bytes": @(top.totalSize), @"note": top.bundleID}];
    }
    int64_t dup = [self dupWastedBytes];
    if (dup > 0) [causes addObject:@{@"title": @"File trùng lặp (bản sao xoá được)", @"bytes": @(dup), @"note": @"File gốc luôn được giữ lại"}];
    int64_t junk = [self junkTotalBytes];
    if (junk > 0) [causes addObject:@{@"title": @"Rác & file thừa dọn được", @"bytes": @(junk), @"note": @"Cache, log, file cài đặt cũ, tàn dư jailbreak"}];
    if (self.cacheBytesTotal > 0) [causes addObject:@{@"title": @"Bộ nhớ đệm (cache) của các app", @"bytes": @(self.cacheBytesTotal), @"note": @"Xoá an toàn, app tự tạo lại khi cần"}];
    if (self.jbBytes > 0) [causes addObject:@{@"title": @"Khu vực jailbreak (/var/jb)", @"bytes": @(self.jbBytes), @"note": @"Tweak, app jailbreak và dữ liệu của chúng"}];
    [causes sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"bytes"] compare:a[@"bytes"]];
    }];
    if (causes.count > 3) return [causes subarrayWithRange:NSMakeRange(0, 3)];
    return causes;
}
@end

@implementation SSStore
+ (instancetype)sharedStore {
    static SSStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[SSStore alloc] init];
    });
    return store;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        _progressText = @"";
        _protectedOriginals = [NSMutableSet set];
    }
    return self;
}
- (void)startScanIfNeeded {
    if (!self.result && !self.scanning) [self startScan];
}
- (void)startScan {
    if (self.scanning) return;
    self.scanning = YES;
    self.progressText = @"Đang chuẩn bị quét…";
    [[NSNotificationCenter defaultCenter] postNotificationName:SSStoreDidUpdateNotification object:nil];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        SSScanner *scanner = [[SSScanner alloc] init];
        SSScanResult *res = [scanner runScanWithProgress:^(NSString *text) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.progressText = text;
                [[NSNotificationCenter defaultCenter] postNotificationName:SSStoreDidUpdateNotification object:nil];
            });
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.result = res;
            self.scanning = NO;
            self.progressText = @"";
            [self.protectedOriginals removeAllObjects];
            for (SSDupGroup *g in res.dupGroups) {
                if (g.original) [self.protectedOriginals addObject:g.original.path];
            }
            SSLog(@"Quet xong: %ld file, %@ da quet, %lu nhom trung, %lu app",
                  (long)res.fileCount, @((long long)res.scannedBytes), (unsigned long)res.dupGroups.count, (unsigned long)res.apps.count);
            [[NSNotificationCenter defaultCenter] postNotificationName:SSStoreDidUpdateNotification object:nil];
        });
    });
}
- (BOOL)isOriginalProtected:(NSString *)path {
    return [self.protectedOriginals containsObject:path];
}
@end
