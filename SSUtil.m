#import "SSUtil.h"
#import "SSModels.h"
#import "SSLog.h"

@interface SSUtil ()
+ (nullable NSString *)moveToTrashImpl:(NSString *)path allowProtected:(BOOL)allowProtected;
@end

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

+ (NSString *)backupDir {
    NSString *dir = [[self workDir] stringByAppendingPathComponent:@"Backup"];
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

+ (BOOL)isPhotoThumbnailPath:(NSString *)path {
    // Anh thu nho do he thong tu tao trong PhotoData — khac anh goc o DCIM:
    // xoa duoc, may tu tao lai. Cac duong con lai cua thu vien Anh van bi khoa cung.
    return [path hasPrefix:@"/var/mobile/Media/PhotoData/Thumbnails"] ||
           [path hasPrefix:@"/var/mobile/Media/PhotoData/Caches"] ||
           [path hasPrefix:@"/private/var/mobile/Media/PhotoData/Thumbnails"] ||
           [path hasPrefix:@"/private/var/mobile/Media/PhotoData/Caches"];
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
    return [self moveToTrashImpl:path allowProtected:NO];
}

+ (nullable NSString *)moveToTrashProtectedOverride:(NSString *)path {
    return [self moveToTrashImpl:path allowProtected:YES];
}

+ (nullable NSString *)moveToTrashImpl:(NSString *)path allowProtected:(BOOL)allowProtected {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) return @"File không còn tồn tại.";
    // CHOT CUNG 3: vung duoc bao ve (ghi am cuoc goi, thu muc anh chon bao ve)
    // khong bi xoa qua duong thong thuong — chi thao tac xoa le co canh bao rieng moi qua duoc.
    if (!allowProtected && [self isProtectedPath:path]) {
        return @"File nằm trong vùng được bảo vệ — hãy mở đúng mục của nó và xoá từng file sau khi đã cân nhắc.";
    }
    // CHOT CUNG 1: file GOC cua nhom trung khong bao gio bi xoa qua app.
    if ([[SSStore sharedStore] isOriginalProtected:path]) {
        return @"Đây là FILE GỐC của nhóm trùng — SpaceScope luôn giữ lại file gốc.";
    }
    // CHOT CUNG 2: khong dung vao thu vien Anh va goi ung dung bang cach xoa file tho.
    if ([self isPathInPhotoLibrary:path] && ![self isPhotoThumbnailPath:path]) {
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




#pragma mark - Nen ung dung

+ (NSArray<NSString *> *)backgroundNames {
    return @[@"Mặc định (theo hệ thống)", @"Trắng tinh", @"Xám nhạt", @"Kem ấm", @"Xanh biển nhạt",
             @"Xanh lá nhạt", @"Hồng nhạt", @"Tím nhạt", @"Vàng nhạt", @"Xanh đậm", @"Đen tuyền"];
}

+ (NSInteger)backgroundChoice {
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"SSBackgroundChoice"];
}

+ (void)setBackgroundChoice:(NSInteger)choice {
    [[NSUserDefaults standardUserDefaults] setInteger:choice forKey:@"SSBackgroundChoice"];
}

+ (nullable UIColor *)backgroundColorForChoice:(NSInteger)choice {
    switch (choice) {
        case 1: return [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:1.0];
        case 2: return [UIColor colorWithRed:0.93 green:0.93 blue:0.96 alpha:1.0];
        case 3: return [UIColor colorWithRed:0.98 green:0.95 blue:0.88 alpha:1.0];
        case 4: return [UIColor colorWithRed:0.88 green:0.93 blue:1.00 alpha:1.0];
        case 5: return [UIColor colorWithRed:0.89 green:0.97 blue:0.90 alpha:1.0];
        case 6: return [UIColor colorWithRed:1.00 green:0.91 blue:0.93 alpha:1.0];
        case 7: return [UIColor colorWithRed:0.93 green:0.90 blue:1.00 alpha:1.0];
        case 8: return [UIColor colorWithRed:1.00 green:0.97 blue:0.85 alpha:1.0];
        case 9: return [UIColor colorWithRed:0.07 green:0.10 blue:0.18 alpha:1.0];
        case 10: return [UIColor blackColor];
        default: return nil;
    }
}

+ (void)applyThemeToViewController:(UIViewController *)vc {
    NSInteger choice = [self backgroundChoice];
    UIColor *bg = [self backgroundColorForChoice:choice];
    // Mau nen toi thi ep chu sang (dark style), mau sang thi ep chu toi — tranh chu chim trong nen.
    if (choice == 9 || choice == 10) vc.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    else if (choice >= 1) vc.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    else vc.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
    if ([vc isKindOfClass:[UITableViewController class]]) {
        UITableView *tv = [(UITableViewController *)vc tableView];
        tv.backgroundColor = bg ?: [UIColor systemGroupedBackgroundColor];
    } else {
        vc.view.backgroundColor = bg ?: [UIColor systemBackgroundColor];
        for (UIView *sub in vc.view.subviews) {
            if ([sub isKindOfClass:[UITextView class]]) sub.backgroundColor = bg ?: [UIColor systemBackgroundColor];
        }
    }
}

#pragma mark - Danh sach bao ve & phan loai duyet noi dung

+ (NSSet<NSString *> *)protectedAppIDs {
    NSArray *stored = [[NSUserDefaults standardUserDefaults] objectForKey:@"SSProtectedAppIDs"];
    if ([stored isKindOfClass:[NSArray class]]) return [NSSet setWithArray:stored];
    // Mac dinh: bao ve du lieu chat Zalo (anh yeu cau rieng).
    return [NSSet setWithObject:@"vn.com.vng.zingalo"];
}

+ (void)setAppID:(NSString *)bundleID protected:(BOOL)isProtected {
    NSMutableSet *set = [[self protectedAppIDs] mutableCopy];
    if (isProtected) [set addObject:bundleID];
    else [set removeObject:bundleID];
    [[NSUserDefaults standardUserDefaults] setObject:[set allObjects] forKey:@"SSProtectedAppIDs"];
}

+ (NSArray<NSString *> *)protectedFolderPaths {
    NSArray *stored = [[NSUserDefaults standardUserDefaults] objectForKey:@"SSProtectedFolders"];
    if ([stored isKindOfClass:[NSArray class]]) return stored;
    return @[];
}

+ (void)addProtectedFolderPath:(NSString *)path {
    NSMutableArray *arr = [[self protectedFolderPaths] mutableCopy];
    if (![arr containsObject:path]) [arr addObject:path];
    [[NSUserDefaults standardUserDefaults] setObject:[arr copy] forKey:@"SSProtectedFolders"];
}

+ (void)removeProtectedFolderPath:(NSString *)path {
    NSMutableArray *arr = [[self protectedFolderPaths] mutableCopy];
    [arr removeObject:path];
    [[NSUserDefaults standardUserDefaults] setObject:[arr copy] forKey:@"SSProtectedFolders"];
}

+ (BOOL)isProtectedPath:(NSString *)path {
    NSString *low = [path lowercaseString];
    // Vung ghi am cuoc goi cua cac tweak (AudioRecorder va tuong tu): du lieu cua nguoi dung.
    if ([low containsString:@"audiorecorder"] || [low containsString:@"callrecorder"] ||
        [low containsString:@"call recorder"]) return YES;
    for (NSString *folder in [self protectedFolderPaths]) {
        if (folder.length > 0 && [path hasPrefix:folder]) return YES;
    }
    return NO;
}

+ (SSItemKind)kindForPath:(NSString *)path {
    NSString *ext = [[path pathExtension] lowercaseString];
    static NSSet *photos, *videos, *audios, *docs;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        photos = [NSSet setWithObjects:@"jpg", @"jpeg", @"heic", @"heif", @"png", @"gif", @"webp", @"bmp", @"tiff", @"raw", @"dng", nil];
        videos = [NSSet setWithObjects:@"mp4", @"mov", @"m4v", @"mkv", @"avi", @"webm", @"3gp", nil];
        audios = [NSSet setWithObjects:@"mp3", @"m4a", @"wav", @"flac", @"aac", @"ogg", @"caf", @"aiff", @"aif", @"amr", @"opus", @"m4b", @"oga", nil];
        docs = [NSSet setWithObjects:@"pdf", @"doc", @"docx", @"xls", @"xlsx", @"ppt", @"pptx", @"txt", @"rtf", nil];
    });
    if ([photos containsObject:ext]) return SSItemKindPhoto;
    if ([videos containsObject:ext]) return SSItemKindVideo;
    if ([audios containsObject:ext]) return SSItemKindAudio;
    if ([docs containsObject:ext]) return SSItemKindDocument;
    if ([ext isEqualToString:@"zip"] || [ext isEqualToString:@"rar"] || [ext isEqualToString:@"7z"] ||
        [ext isEqualToString:@"tar"] || [ext isEqualToString:@"gz"]) return SSItemKindArchive;
    return SSItemKindOther;
}

+ (void)classifyBrowsedItem:(SSFileItem *)item {
    NSString *path = item.path;
    NSString *ext = [[path pathExtension] lowercaseString];
    item.kind = [self kindForPath:path];
    if ([self isPhotoThumbnailPath:path]) {
        item.inLibrary = NO;
        item.level = SSFileLevelCaution;
        item.note = @"Ảnh thu nhỏ do hệ thống tự tạo — xoá được, máy sẽ tạo lại khi mở app Ảnh (không phải ảnh gốc).";
        return;
    }
    if (item.inLibrary) {
        item.isProtected = YES;
        item.level = SSFileLevelDanger;
        item.note = @"Nằm trong thư viện Ảnh — chỉ xem, xoá bằng app Ảnh để không hỏng thư viện.";
        return;
    }
    if ([self isPathInAppBundle:path]) {
        item.level = SSFileLevelDanger;
        item.note = @"Nằm trong gói ứng dụng — không xoá file trực tiếp.";
        return;
    }
    if ([self isProtectedPath:path]) {
        item.isProtected = YES;
        item.level = SSFileLevelDanger;
        item.note = @"Nằm trong vùng được bảo vệ (ghi âm/dữ liệu quan trọng) — chỉ xoá từng file khi thật chắc chắn, nên backup trước.";
        return;
    }
    if ([ext isEqualToString:@"sqlite"] || [ext isEqualToString:@"sqlite3"] || [ext isEqualToString:@"db"] ||
        [ext isEqualToString:@"realm"] || [ext isEqualToString:@"db-wal"] || [ext isEqualToString:@"db-shm"]) {
        item.isProtected = YES;
        item.level = SSFileLevelDanger;
        item.note = @"Cơ sở dữ liệu — có thể chứa tin nhắn/tài khoản của app, không xoá nếu không chắc chắn.";
        return;
    }
    if ([path containsString:@"/Caches/"] || [path containsString:@"/tmp/"] || [path hasPrefix:@"/var/tmp/"]) {
        item.level = SSFileLevelSafe;
        item.note = @"Cache/file tạm — xoá an toàn, tự tạo lại khi cần.";
        return;
    }
    if ([path containsString:@"/Logs/"] || [path containsString:@"CrashReporter"] ||
        [ext isEqualToString:@"log"] || [ext isEqualToString:@"ips"]) {
        item.level = SSFileLevelSafe;
        item.note = @"File log/báo cáo lỗi — xoá an toàn.";
        return;
    }
    if ([path containsString:@"/Documents/"]) {
        item.level = SSFileLevelCaution;
        item.note = @"Dữ liệu người dùng trong app — kiểm tra kỹ trước khi xoá.";
        return;
    }
    item.level = SSFileLevelCaution;
    item.note = @"Kiểm tra trước khi xoá.";
}

#pragma mark - Backup zip (ZIP stored, ghi dang luong, kem MANIFEST.txt)

// Bang CRC32 chuan cua dinh dang ZIP.
static uint32_t SSCRC32Table[256];
static BOOL SSCRC32Ready = NO;
static void SSInitCRC32(void) {
    if (SSCRC32Ready) return;
    for (uint32_t i = 0; i < 256; i++) {
        uint32_t c = i;
        for (int k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320U ^ (c >> 1)) : (c >> 1);
        SSCRC32Table[i] = c;
    }
    SSCRC32Ready = YES;
}
static uint32_t SSUpdateCRC(uint32_t crc, const unsigned char *buf, NSUInteger len) {
    uint32_t c = crc ^ 0xFFFFFFFFU;
    for (NSUInteger i = 0; i < len; i++) c = SSCRC32Table[(c ^ buf[i]) & 0xFF] ^ (c >> 8);
    return c ^ 0xFFFFFFFFU;
}
static void SSWrite16(NSFileHandle *fh, uint16_t v) {
    unsigned char b[2] = {(unsigned char)(v & 0xFF), (unsigned char)((v >> 8) & 0xFF)};
    [fh writeData:[NSData dataWithBytes:b length:2]];
}
static void SSWrite32(NSFileHandle *fh, uint32_t v) {
    unsigned char b[4] = {(unsigned char)(v & 0xFF), (unsigned char)((v >> 8) & 0xFF),
                          (unsigned char)((v >> 16) & 0xFF), (unsigned char)((v >> 24) & 0xFF)};
    [fh writeData:[NSData dataWithBytes:b length:4]];
}
static void SSDOSDateTime(NSDate *date, uint16_t *outTime, uint16_t *outDate) {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *c = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                                           NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
                                 fromDate:date ?: [NSDate date]];
    NSInteger year = c.year < 1980 ? 1980 : c.year;
    *outTime = (uint16_t)((c.hour << 11) | (c.minute << 5) | (c.second >> 1));
    *outDate = (uint16_t)(((year - 1980) << 9) | (c.month << 5) | c.day);
}

// Ghi 1 muc (entry) dang stored vao zip dang mo. Nguon du lieu la 1 file tren dia.
// Tra ve YES neu ghi xong (ke ca khi file rong).
static BOOL SSZipWriteFileEntry(NSFileHandle *out, NSString *entryName, NSString *sourcePath,
                                NSMutableArray<NSDictionary *> *central) {
    NSFileHandle *src = [NSFileHandle fileHandleForReadingAtPath:sourcePath];
    if (!src) return NO;
    // Vong 1: tinh CRC32 truoc (tieu de local cua ZIP stored can CRC + kich thuoc ngay tu dau).
    uint32_t crc = 0;
    uint64_t total = 0;
    BOOL readOK = YES;
    @try {
        while (YES) {
            NSData *chunk = nil;
            @autoreleasepool { chunk = [src readDataOfLength:1024 * 1024]; }
            if (chunk.length == 0) break;
            crc = SSUpdateCRC(crc, chunk.bytes, chunk.length);
            total += chunk.length;
        }
    } @catch (NSException *e) { readOK = NO; }
    if (!readOK || total > 0xFFFFFFFFULL) { [src closeFile]; return NO; }
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:sourcePath error:nil];
    uint16_t dtime, ddate;
    SSDOSDateTime(attrs[NSFileModificationDate], &dtime, &ddate);
    NSData *nameData = [entryName dataUsingEncoding:NSUTF8StringEncoding];
    unsigned long long offset = [out offsetInFile];
    SSWrite32(out, 0x04034b50);
    SSWrite16(out, 20);
    SSWrite16(out, 0x0800); // co UTF-8 cho ten file
    SSWrite16(out, 0);      // stored, khong nen
    SSWrite16(out, dtime);
    SSWrite16(out, ddate);
    SSWrite32(out, crc);
    SSWrite32(out, (uint32_t)total);
    SSWrite32(out, (uint32_t)total);
    SSWrite16(out, (uint16_t)nameData.length);
    SSWrite16(out, 0);
    [out writeData:nameData];
    // Vong 2: chep noi dung file.
    [src seekToFileOffset:0];
    uint64_t copied = 0;
    @try {
        while (copied < total) {
            NSData *chunk = nil;
            @autoreleasepool { chunk = [src readDataOfLength:1024 * 1024]; }
            if (chunk.length == 0) break;
            [out writeData:chunk];
            copied += chunk.length;
        }
    } @catch (NSException *e) { }
    [src closeFile];
    [central addObject:@{@"name": nameData, @"crc": @(crc), @"size": @(total),
                         @"time": @(dtime), @"date": @(ddate), @"offset": @(offset)}];
    return YES;
}

static void SSZipWriteDataEntry(NSFileHandle *out, NSString *entryName, NSData *data,
                                NSMutableArray<NSDictionary *> *central) {
    uint32_t crc = SSUpdateCRC(0, data.bytes, data.length);
    uint16_t dtime, ddate;
    SSDOSDateTime([NSDate date], &dtime, &ddate);
    NSData *nameData = [entryName dataUsingEncoding:NSUTF8StringEncoding];
    unsigned long long offset = [out offsetInFile];
    SSWrite32(out, 0x04034b50);
    SSWrite16(out, 20);
    SSWrite16(out, 0x0800);
    SSWrite16(out, 0);
    SSWrite16(out, dtime);
    SSWrite16(out, ddate);
    SSWrite32(out, crc);
    SSWrite32(out, (uint32_t)data.length);
    SSWrite32(out, (uint32_t)data.length);
    SSWrite16(out, (uint16_t)nameData.length);
    SSWrite16(out, 0);
    [out writeData:nameData];
    if (data.length > 0) [out writeData:data];
    [central addObject:@{@"name": nameData, @"crc": @(crc), @"size": @(data.length),
                         @"time": @(dtime), @"date": @(ddate), @"offset": @(offset)}];
}

+ (nullable NSString *)createBackupZipForItems:(NSArray<SSFileItem *> *)items outPath:(NSString *_Nullable *_Nullable)outPath {
    SSInitCRC32();
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *stamp = [fmt stringFromDate:[NSDate date]];
    NSString *zipPath = [[self backupDir] stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"SpaceScope-Backup-%@.zip", stamp]];
    if (![fm createFileAtPath:zipPath contents:nil attributes:nil]) return @"Không tạo được file backup.";
    NSFileHandle *out = [NSFileHandle fileHandleForWritingAtPath:zipPath];
    if (!out) return @"Không mở được file backup để ghi.";
    NSMutableArray<NSDictionary *> *central = [NSMutableArray array];
    NSMutableSet<NSString *> *usedNames = [NSMutableSet set];
    NSMutableString *manifest = [NSMutableString stringWithFormat:@"SpaceScope — bản backup ngày %@\nTổng cộng %lu file được chọn.\nMỗi dòng dưới đây là đường dẫn gốc của file trong zip.\n\n",
                                 stamp, (unsigned long)items.count];
    NSInteger written = 0;
    int64_t writtenBytes = 0;
    for (SSFileItem *it in items) {
        if (![fm fileExistsAtPath:it.path]) {
            [manifest appendFormat:@"(BỎ QUA — file không còn tồn tại) %@\n", it.path];
            continue;
        }
        NSString *entryName = [it.path lastPathComponent];
        NSString *baseName = [entryName stringByDeletingPathExtension];
        NSString *ext = [entryName pathExtension];
        NSInteger dupN = 1;
        while ([usedNames containsObject:entryName]) {
            dupN++;
            entryName = ext.length > 0 ? [NSString stringWithFormat:@"%@ (%ld).%@", baseName, (long)dupN, ext]
                                       : [NSString stringWithFormat:@"%@ (%ld)", baseName, (long)dupN];
        }
        [usedNames addObject:entryName];
        if (SSZipWriteFileEntry(out, entryName, it.path, central)) {
            written++;
            writtenBytes += it.size;
            [manifest appendFormat:@"%@  <=  %@ (%@)\n", entryName, it.path, [self formatBytes:it.size]];
        } else {
            [manifest appendFormat:@"(BỎ QUA — không đọc được) %@\n", it.path];
        }
    }
    if (written == 0) {
        [out closeFile];
        [fm removeItemAtPath:zipPath error:nil];
        return @"Không backup được file nào (file đã biến mất hoặc không đọc được).";
    }
    // MANIFEST.txt ghi cuoi nhung van nam trong muc luc trung tam nhu binh thuong.
    NSData *manifestData = [[manifest copy] dataUsingEncoding:NSUTF8StringEncoding];
    SSZipWriteDataEntry(out, @"MANIFEST.txt", manifestData, central);
    unsigned long long centralStart = [out offsetInFile];
    for (NSDictionary *e in central) {
        NSData *nameData = e[@"name"];
        SSWrite32(out, 0x02014b50);
        SSWrite16(out, 20);
        SSWrite16(out, 20);
        SSWrite16(out, 0x0800);
        SSWrite16(out, 0);
        SSWrite16(out, [e[@"time"] unsignedShortValue]);
        SSWrite16(out, [e[@"date"] unsignedShortValue]);
        SSWrite32(out, [e[@"crc"] unsignedIntValue]);
        SSWrite32(out, [e[@"size"] unsignedIntValue]);
        SSWrite32(out, [e[@"size"] unsignedIntValue]);
        SSWrite16(out, (uint16_t)nameData.length);
        SSWrite16(out, 0);
        SSWrite16(out, 0);
        SSWrite16(out, 0);
        SSWrite16(out, 0);
        SSWrite32(out, 0);
        SSWrite32(out, (uint32_t)[e[@"offset"] unsignedLongLongValue]);
        [out writeData:nameData];
    }
    unsigned long long centralSize = [out offsetInFile] - centralStart;
    SSWrite32(out, 0x06054b50);
    SSWrite16(out, 0);
    SSWrite16(out, 0);
    SSWrite16(out, (uint16_t)central.count);
    SSWrite16(out, (uint16_t)central.count);
    SSWrite32(out, (uint32_t)centralSize);
    SSWrite32(out, (uint32_t)centralStart);
    SSWrite16(out, 0);
    [out synchronizeFile];
    [out closeFile];
    SSLog(@"Backup zip: %ld file, %@ -> %@", (long)written, [self formatBytes:writtenBytes], zipPath);
    if (outPath) *outPath = zipPath;
    return nil;
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
