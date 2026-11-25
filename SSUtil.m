#import "SSUtil.h"
#import "SSModels.h"
#import "SSLog.h"

@implementation SSUtil

+ (NSString *)formatBytes:(int64_t)bytes {
    if (bytes < 0) bytes = 0;
    if (bytes < 1024) return [NSString stringWithFormat:@"%lld B", (long long)bytes];
    double kb = bytes / 1024.0;
    if (kb < 1024) return [NSString stringWithFormat:@"%.1f KB", kb];
    double mb = kb / 1024.0;
    if (mb < 1024) return [NSString stringWithFormat:@"%.1f MB", mb];
    double gb = mb / 1024.0;
    if (gb < 1024) return [NSString stringWithFormat:@"%.2f GB", gb];
    return [NSString stringWithFormat:@"%.2f TB", gb / 1024.0];
}

+ (NSString *)jbPrefix {
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/Library"]) return @"/var/jb";
    return @"";
}

+ (NSString *)workDir {
    NSString *base = @"/var/mobile/Documents/SpaceScope";
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:@"/var/mobile/Documents"]) {
        base = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"SpaceScope"];
    }
    [fm createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:nil];
    return base;
}

+ (NSString *)trashDir {
    NSString *dir = [[self workDir] stringByAppendingPathComponent:@"Trash"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

+ (NSString *)snapshotsDir {
    NSString *dir = [[self workDir] stringByAppendingPathComponent:@"Snapshots"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

+ (BOOL)isPathInPhotoLibrary:(NSString *)path {
    return [path hasPrefix:@"/var/mobile/Media/DCIM"] ||
           [path hasPrefix:@"/var/mobile/Media/PhotoData"] ||
           [path hasPrefix:@"/private/var/mobile/Media/DCIM"] ||
           [path hasPrefix:@"/private/var/mobile/Media/PhotoData"];
}

+ (BOOL)isPathInAppBundle:(NSString *)path {
    return [path containsString:@".app/"] || [path hasSuffix:@".app"];
}

#pragma mark - Do kich thuoc

+ (int64_t)sizeOfPath:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    if (!attrs) return 0;
    if (![[attrs fileType] isEqualToString:NSFileTypeDirectory]) {
        return (int64_t)[attrs fileSize];
    }
    int64_t total = 0;
    NSDirectoryEnumerator *en = [fm enumeratorAtPath:path];
    NSString *sub = nil;
    while ((sub = [en nextObject]) != nil) {
        NSDictionary *a = [en fileAttributes];
        if ([[a fileType] isEqualToString:NSFileTypeRegular]) total += (int64_t)[a fileSize];
    }
    return total;
}

+ (int64_t)clearContentsOfDirectory:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    int64_t freed = 0;
    for (NSString *child in [fm contentsOfDirectoryAtPath:path error:nil]) {
        NSString *full = [path stringByAppendingPathComponent:child];
        int64_t sz = [self sizeOfPath:full];
        NSError *err = nil;
        if ([fm removeItemAtPath:full error:&err]) {
            freed += sz;
        } else {
            SSLog(@"Khong xoa duoc %@ (%@)", full, err.localizedDescription ?: @"?");
        }
    }
    return freed;
}

#pragma mark - Thung rac

+ (NSString *)manifestPath {
    return [[self trashDir] stringByAppendingPathComponent:@"manifest.json"];
}

+ (NSMutableArray<NSDictionary *> *)manifestMutable {
    NSData *data = [NSData dataWithContentsOfFile:[self manifestPath]];
    if (data) {
        NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([arr isKindOfClass:[NSArray class]]) return [arr mutableCopy];
    }
    return [NSMutableArray array];
}

+ (void)saveManifest:(NSArray<NSDictionary *> *)entries {
    NSData *data = [NSJSONSerialization dataWithJSONObject:entries options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:[self manifestPath] atomically:YES];
}

+ (NSArray<NSDictionary *> *)trashManifestEntries {
    return [[self manifestMutable] copy];
}

+ (nullable NSString *)moveToTrash:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) return @"File không còn tồn tại.";
    // CHOT CUNG 1: file GOC cua nhom trung khong bao gio bi xoa qua app.
    if ([[SSStore sharedStore] isOriginalProtected:path]) {
        return @"Đây là FILE GỐC của nhóm trùng — SpaceScope luôn giữ lại file gốc.";
    }
    // CHOT CUNG 2: khong dung vao thu vien Anh va goi ung dung bang cach xoa file tho.
    if ([self isPathInPhotoLibrary:path]) {
        return @"File nằm trong thư viện Ảnh — hãy xoá trong app Ảnh để không hỏng thư viện.";
    }
    if ([self isPathInAppBundle:path]) {
        return @"File nằm trong gói ứng dụng — không xoá trực tiếp được.";
    }
    if ([path hasPrefix:[self workDir]]) {
        return @"Đây là dữ liệu làm việc của SpaceScope.";
    }
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *stamp = [fmt stringFromDate:[NSDate date]];
    NSString *base = [path lastPathComponent];
    NSString *trashName = [NSString stringWithFormat:@"%@-%@", stamp, base];
    NSString *dest = [[self trashDir] stringByAppendingPathComponent:trashName];
    NSInteger n = 1;
    while ([fm fileExistsAtPath:dest]) {
        n++;
        dest = [[self trashDir] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%ld-%@", stamp, (long)n, base]];
        trashName = [dest lastPathComponent];
    }
    int64_t sz = [self sizeOfPath:path];
    NSError *err = nil;
    if (![fm moveItemAtPath:path toPath:dest error:&err]) {
        return [NSString stringWithFormat:@"Không chuyển được vào thùng rác: %@", err.localizedDescription ?: @"lỗi không rõ"];
    }
    NSMutableArray *entries = [self manifestMutable];
    [entries addObject:@{
        @"id": trashName,
        @"orig": path,
        @"trash": trashName,
        @"name": base,
        @"size": @(sz),
        @"date": @([[NSDate date] timeIntervalSince1970])
    }];
    [self saveManifest:entries];
    SSLog(@"Vao thung rac: %@ (%@)", path, [self formatBytes:sz]);
    return nil;
}

+ (nullable NSString *)restoreTrashEntry:(NSDictionary *)entry {
    NSString *trashPath = [[self trashDir] stringByAppendingPathComponent:entry[@"trash"] ?: @""];
    NSString *orig = entry[@"orig"] ?: @"";
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:trashPath]) return @"File trong thùng rác không còn.";
    if ([fm fileExistsAtPath:orig]) return @"Đường dẫn gốc đã có file khác — không khôi phục đè được.";
    [fm createDirectoryAtPath:[orig stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    NSError *err = nil;
    if (![fm moveItemAtPath:trashPath toPath:orig error:&err]) {
        return [NSString stringWithFormat:@"Không khôi phục được: %@", err.localizedDescription ?: @"lỗi không rõ"];
    }
    NSMutableArray *entries = [self manifestMutable];
    [entries removeObject:entry];
    [self saveManifest:entries];
    SSLog(@"Khoi phuc tu thung rac: %@", orig);
    return nil;
}

+ (nullable NSString *)purgeTrashEntry:(NSDictionary *)entry {
    NSString *trashPath = [[self trashDir] stringByAppendingPathComponent:entry[@"trash"] ?: @""];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    if ([fm fileExistsAtPath:trashPath] && ![fm removeItemAtPath:trashPath error:&err]) {
        return [NSString stringWithFormat:@"Không xoá hẳn được: %@", err.localizedDescription ?: @"lỗi không rõ"];
    }
    NSMutableArray *entries = [self manifestMutable];
    [entries removeObject:entry];
    [self saveManifest:entries];
    SSLog(@"Xoa han khoi thung rac: %@", entry[@"orig"] ?: @"");
    return nil;
}

+ (int64_t)trashTotalSize {
    int64_t total = 0;
    for (NSDictionary *e in [self trashManifestEntries]) total += [e[@"size"] longLongValue];
    return total;
}

+ (void)purgeExpiredTrash {
    NSTimeInterval limit = (NSTimeInterval)[self trashKeepDays] * 86400.0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    for (NSDictionary *e in [self trashManifestEntries]) {
        if (now - [e[@"date"] doubleValue] > limit) {
            NSString *err = [self purgeTrashEntry:e];
            if (!err) SSLog(@"Thung rac tu don (qua %ld ngay): %@", (long)[self trashKeepDays], e[@"name"] ?: @"");
        }
    }
}

#pragma mark - Cai dat

+ (NSInteger)warnFreeGB {
    NSNumber *v = [[NSUserDefaults standardUserDefaults] objectForKey:@"SSWarnFreeGB"];
    return v ? [v integerValue] : 5;
}
+ (void)setWarnFreeGB:(NSInteger)value {
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:@"SSWarnFreeGB"];
}
+ (NSInteger)trashKeepDays {
    NSNumber *v = [[NSUserDefaults standardUserDefaults] objectForKey:@"SSTrashKeepDays"];
    return v ? [v integerValue] : 7;
}
+ (void)setTrashKeepDays:(NSInteger)value {
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:@"SSTrashKeepDays"];
}
+ (NSInteger)dupMinMB {
    NSNumber *v = [[NSUserDefaults standardUserDefaults] objectForKey:@"SSDupMinMB"];
    return v ? [v integerValue] : 1;
}
+ (void)setDupMinMB:(NSInteger)value {
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:@"SSDupMinMB"];
}

@end
