#import "SSScanner.h"
#import "SSUtil.h"
#import "SSLog.h"
#import <CommonCrypto/CommonCrypto.h>
#import <objc/runtime.h>

// Khai bao toi thieu cho API rieng cua he thong, chi dung khi class ton tai luc chay.
@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray *)allInstalledApplications;
@end

@interface LSApplicationProxy : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)localizedName;
@end

@interface SSScanner ()
@property (nonatomic, strong) SSScanResult *result;
@property (nonatomic, copy) void (^progressBlock)(NSString *text);
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray<SSFileItem *> *> *bySize;
@property (nonatomic, strong) NSMutableDictionary<NSString *, SSAppUsage *> *appsByBundle;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *appNames;
@property (nonatomic, strong) NSMutableSet<NSString *> *installedIDs;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *fileOwners;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *packageNames;
@property (nonatomic, assign) int64_t dupMinBytes;
@property (nonatomic, assign) NSInteger filesSinceProgress;
@property (nonatomic, strong) NSDate *lastProgressDate;
- (void)reportProgress:(NSString *)text;
- (void)walkPath:(NSString *)root app:(nullable SSAppUsage *)app downloadedContext:(BOOL)downloadedContext;
- (SSItemKind)kindForExtension:(NSString *)ext;
- (NSString *)categoryKeyForKind:(SSItemKind)kind path:(NSString *)path;
- (void)feedFileAtPath:(NSString *)path size:(int64_t)size created:(nullable NSDate *)created modified:(nullable NSDate *)modified app:(nullable SSAppUsage *)app downloadedContext:(BOOL)downloadedContext;
- (void)scanDataContainers;
- (void)scanBundleContainers;
- (void)buildJunkItems;
- (void)addJunkTitle:(NSString *)title detail:(NSString *)detail path:(NSString *)path size:(int64_t)size
                tier:(SSJunkTier)tier action:(SSJunkAction)action extraPaths:(nullable NSArray<NSString *> *)extraPaths;
- (void)buildDupGroups;
- (NSString *)finishHash:(CC_SHA256_CTX *)ctx fh:(NSFileHandle *)fh;
- (NSInteger)originalScoreForItem:(SSFileItem *)item;
- (nullable NSString *)partialHashForItem:(SSFileItem *)item;
- (nullable NSString *)fullHashForItem:(SSFileItem *)item;
- (void)loadPreviousSnapshotAndSaveCurrent;
- (NSDictionary<NSString *, NSString *> *)installedAppNames;
- (NSSet<NSString *> *)dpkgPackageIDs;
- (void)loadDpkgOwnership;
- (void)classifyItem:(SSFileItem *)item app:(nullable SSAppUsage *)app;
@end

@implementation SSScanner

- (SSScanResult *)runScanWithProgress:(void (^)(NSString *text))progress {
    self.progressBlock = progress;
    self.result = [[SSScanResult alloc] init];
    self.bySize = [NSMutableDictionary dictionary];
    self.appsByBundle = [NSMutableDictionary dictionary];
    self.appNames = [NSMutableDictionary dictionary];
    self.installedIDs = [NSMutableSet set];
    self.fileOwners = [NSMutableDictionary dictionary];
    self.packageNames = [NSMutableDictionary dictionary];
    self.dupMinBytes = [SSUtil dupMinMB] * 1024 * 1024;
    self.lastProgressDate = [NSDate date];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSDictionary *fs = [fm attributesOfFileSystemForPath:@"/var/mobile" error:nil];
    self.result.diskTotal = [fs[NSFileSystemSize] longLongValue];
    self.result.diskFree = [fs[NSFileSystemFreeSize] longLongValue];
    SSLog(@"Bat dau quet. O dia: tong %@, trong %@", [SSUtil formatBytes:self.result.diskTotal], [SSUtil formatBytes:self.result.diskFree]);

    [self reportProgress:@"Đang đọc danh sách ứng dụng…"];
    NSDictionary<NSString *, NSString *> *names = [self installedAppNames];
    [self.appNames addEntriesFromDictionary:names];
    [self.installedIDs addObjectsFromArray:names.allKeys];
    [self.installedIDs unionSet:[self dpkgPackageIDs]];
    [self loadDpkgOwnership];

    [self reportProgress:@"Đang quét thư viện ảnh & file tải về…"];
    [self walkPath:@"/var/mobile/Media" app:nil downloadedContext:NO];
    [self walkPath:@"/var/mobile/Documents" app:nil downloadedContext:YES];
    [self walkPath:@"/var/mobile/Downloads" app:nil downloadedContext:YES];

    [self reportProgress:@"Đang quét dữ liệu từng ứng dụng…"];
    [self scanDataContainers];
    [self scanBundleContainers];

    NSString *jb = [SSUtil jbPrefix];
    if (jb.length > 0) {
        [self reportProgress:@"Đang quét khu vực jailbreak…"];
        int64_t before = self.result.scannedBytes;
        [self walkPath:[jb stringByAppendingPathComponent:@"Library"] app:nil downloadedContext:NO];
        [self walkPath:[jb stringByAppendingPathComponent:@"usr"] app:nil downloadedContext:NO];
        for (NSString *entry in [fm contentsOfDirectoryAtPath:[jb stringByAppendingPathComponent:@"Applications"] error:nil]) {
            NSString *full = [[jb stringByAppendingPathComponent:@"Applications"] stringByAppendingPathComponent:entry];
            self.result.scannedBytes += [SSUtil sizeOfPath:full];
        }
        self.result.jbBytes = self.result.scannedBytes - before;
    }

    [self reportProgress:@"Đang tổng hợp rác & file thừa…"];
    [self buildJunkItems];

    [self reportProgress:@"Đang tìm file trùng (đối chiếu nội dung)…"];
    [self buildDupGroups];

    [self loadPreviousSnapshotAndSaveCurrent];

    [self.result.topFiles sortUsingComparator:^NSComparisonResult(SSFileItem *a, SSFileItem *b) {
        if (a.size != b.size) return a.size > b.size ? NSOrderedAscending : NSOrderedDescending;
        return [a.name compare:b.name];
    }];
    if (self.result.topFiles.count > 200) {
        [self.result.topFiles removeObjectsInRange:NSMakeRange(200, self.result.topFiles.count - 200)];
    }
    NSMutableArray<SSAppUsage *> *apps = [self.appsByBundle.allValues mutableCopy];
    [apps sortUsingComparator:^NSComparisonResult(SSAppUsage *a, SSAppUsage *b) {
        return a.totalSize > b.totalSize ? NSOrderedAscending : (a.totalSize < b.totalSize ? NSOrderedDescending : NSOrderedSame);
    }];
    self.result.apps = apps;
    for (SSAppUsage *app in apps) self.result.cacheBytesTotal += app.cacheSize + app.tmpSize;

    SSLog(@"Quet xong: fileCount=%ld loi=%ld scanned=%@ topFile=%lu nhomTrung=%lu rac=%lu muc",
          (long)self.result.fileCount, (long)self.result.errorCount,
          [SSUtil formatBytes:self.result.scannedBytes], (unsigned long)self.result.topFiles.count,
          (unsigned long)self.result.dupGroups.count, (unsigned long)self.result.junkItems.count);
    return self.result;
}

- (void)reportProgress:(NSString *)text {
    self.lastProgressDate = [NSDate date];
    if (self.progressBlock) self.progressBlock(text);
}

#pragma mark - Duyet cay

- (SSItemKind)kindForExtension:(NSString *)ext {
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
    if ([ext isEqualToString:@"zip"] || [ext isEqualToString:@"rar"] || [ext isEqualToString:@"7z"] || [ext isEqualToString:@"tar"] || [ext isEqualToString:@"gz"]) return SSItemKindArchive;
    return SSItemKindOther;
}

- (NSString *)categoryKeyForKind:(SSItemKind)kind path:(NSString *)path {
    NSString *ext = [[path pathExtension] lowercaseString];
    if ([ext isEqualToString:@"deb"] || [ext isEqualToString:@"ipa"]) return @"installer";
    switch (kind) {
        case SSItemKindPhoto: return @"photo";
        case SSItemKindVideo: return @"video";
        case SSItemKindAudio: return @"audio";
        case SSItemKindArchive: return @"archive";
        case SSItemKindDocument: return @"document";
        default: return @"other";
    }
}

- (void)walkPath:(NSString *)root app:(nullable SSAppUsage *)app downloadedContext:(BOOL)downloadedContext {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:root isDirectory:&isDir] || !isDir) return;
    NSURL *rootURL = [NSURL fileURLWithPath:root];
    NSArray<NSURLResourceKey> *keys = @[NSURLIsDirectoryKey, NSURLIsRegularFileKey, NSURLIsSymbolicLinkKey,
                                        NSURLFileSizeKey, NSURLContentModificationDateKey, NSURLCreationDateKey];
    NSDirectoryEnumerator *en = [fm enumeratorAtURL:rootURL includingPropertiesForKeys:keys options:0
                                       errorHandler:^BOOL(NSURL *url, NSError *error) {
        self.result.errorCount++;
        return YES;
    }];
    NSString *workDir = [SSUtil workDir];
    NSURL *url = nil;
    while ((url = [en nextObject]) != nil) {
        NSDictionary *values = [url resourceValuesForKeys:keys error:nil];
        if ([values[NSURLIsSymbolicLinkKey] boolValue]) {
            if ([values[NSURLIsDirectoryKey] boolValue]) [en skipDescendants];
            continue;
        }
        NSString *path = [url path];
        if ([values[NSURLIsDirectoryKey] boolValue]) {
            if ([path isEqualToString:workDir] || [path hasPrefix:[workDir stringByAppendingString:@"/"]]) {
                [en skipDescendants]; // du lieu cua chinh SpaceScope
                continue;
            }
            if ([[path lastPathComponent] hasSuffix:@".app"]) {
                [en skipDescendants];
                self.result.scannedBytes += [SSUtil sizeOfPath:path];
                continue;
            }
            continue;
        }
        if (![values[NSURLIsRegularFileKey] boolValue]) continue;
        int64_t size = [values[NSURLFileSizeKey] longLongValue];
        [self feedFileAtPath:path size:size created:values[NSURLCreationDateKey] modified:values[NSURLContentModificationDateKey]
                         app:app downloadedContext:downloadedContext];
    }
}

- (void)feedFileAtPath:(NSString *)path size:(int64_t)size created:(nullable NSDate *)created modified:(nullable NSDate *)modified
                   app:(nullable SSAppUsage *)app downloadedContext:(BOOL)downloadedContext {
    SSScanResult *R = self.result;
    R.fileCount++;
    R.scannedBytes += size;
    self.filesSinceProgress++;
    if (self.filesSinceProgress >= 3000 && [[NSDate date] timeIntervalSinceDate:self.lastProgressDate] > 0.4) {
        self.filesSinceProgress = 0;
        [self reportProgress:[NSString stringWithFormat:@"Đang quét… %ld file", (long)R.fileCount]];
    }

    NSString *ext = [[path pathExtension] lowercaseString];
    SSItemKind kind = [self kindForExtension:ext];
    NSString *catKey = [self categoryKeyForKind:kind path:path];
    R.categoryBytes[catKey] = @([R.categoryBytes[catKey] longLongValue] + size);

    NSDate *refDate = modified ?: created;
    if (refDate) {
        NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:refDate];
        if (age >= 0 && age <= 7 * 86400) R.growth7 += size;
        if (age >= 0 && age <= 30 * 86400) R.growth30 += size;
        if (age >= 0 && age <= 90 * 86400) R.growth90 += size;
    }

    BOOL inLibrary = [SSUtil isPathInPhotoLibrary:path];
    if ([path hasPrefix:@"/var/mobile/Media/DCIM"]) R.dcimBytes += size;
    if ([path hasPrefix:@"/var/mobile/Media/PhotoData"]) R.photoDataBytes += size;
    BOOL downloaded = downloadedContext || [path containsString:@"/Downloads/"] || [path containsString:@"/Inbox/"];
    if (downloaded && (kind == SSItemKindPhoto || kind == SSItemKindVideo || kind == SSItemKindArchive ||
                       kind == SSItemKindDocument || [catKey isEqualToString:@"installer"])) {
        R.downloadsBytes += size;
    }

    if (app) {
        app.dataSize += size;
        NSString *rel = [path substringFromIndex:app.containerPath.length];
        NSArray<NSString *> *parts = [rel componentsSeparatedByString:@"/"];
        NSString *top = parts.count > 1 ? parts[1] : @"";
        if ([top isEqualToString:@"Documents"]) {
            app.docsSize += size;
        } else if ([top isEqualToString:@"tmp"]) {
            app.tmpSize += size;
        } else if ([top isEqualToString:@"Library"] && parts.count > 2 && [parts[2] isEqualToString:@"Caches"]) {
            app.cacheSize += size;
        }
        if (parts.count > 1 && size >= 10 * 1024 * 1024 && app.offlineHints.count < 5) {
            for (NSString *part in parts) {
                NSString *low = [part lowercaseString];
                if ([low containsString:@"offline"] || [low containsString:@"download"]) {
                    NSString *hint = [NSString stringWithFormat:@"%@ (%@)", part, [SSUtil formatBytes:size]];
                    if (![app.offlineHints containsObject:hint]) [app.offlineHints addObject:hint];
                    break;
                }
            }
        }
    }

    BOOL needItem = (size >= 5 * 1024 * 1024) || (size >= self.dupMinBytes && ![SSUtil isPathInAppBundle:path]);
    if (!needItem) return;
    SSFileItem *item = [[SSFileItem alloc] initWithPath:path size:size created:created modified:modified];
    item.kind = kind;
    item.inLibrary = inLibrary;
    item.downloaded = downloaded;
    if (app) item.appName = app.name;
    [self classifyItem:item app:app];
    if (app && size >= 5 * 1024 * 1024) {
        [app.topItems addObject:item];
        [app.topItems sortUsingComparator:^NSComparisonResult(SSFileItem *a, SSFileItem *b) {
            return a.size > b.size ? NSOrderedAscending : (a.size < b.size ? NSOrderedDescending : NSOrderedSame);
        }];
        if (app.topItems.count > 15) [app.topItems removeObjectsInRange:NSMakeRange(15, app.topItems.count - 15)];
    }
    if (size >= 5 * 1024 * 1024) [R.topFiles addObject:item];
    if (size >= self.dupMinBytes && ![SSUtil isPathInAppBundle:path]) {
        NSNumber *key = @(size);
        NSMutableArray<SSFileItem *> *arr = self.bySize[key];
        if (!arr) {
            arr = [NSMutableArray array];
            self.bySize[key] = arr;
        }
        [arr addObject:item];
    }
}

#pragma mark - Chu so huu file (dpkg) & phan loai muc canh bao

// Doc danh sach file cua tung goi tu dpkg info (*.list) + ten hien thi tu status.
// Khoa tra cuu chuan hoa ca 2 dang: co va khong co tien to /var/jb.
- (void)loadDpkgOwnership {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *statusPaths = @[@"/var/lib/dpkg/status", @"/var/jb/var/lib/dpkg/status",
                                         @"/var/jb/Library/dpkg/status", @"/Library/dpkg/status"];
    for (NSString *path in statusPaths) {
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (!content) continue;
        NSString *pkg = nil;
        for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
            if ([line hasPrefix:@"Package: "]) {
                pkg = [[line substringFromIndex:9] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            } else if (pkg.length > 0 && [line hasPrefix:@"Name: "]) {
                NSString *nm = [[line substringFromIndex:6] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (nm.length > 0 && !self.packageNames[pkg]) self.packageNames[pkg] = nm;
            }
        }
    }
    NSArray<NSString *> *infoDirs = @[@"/var/jb/Library/dpkg/info", @"/Library/dpkg/info",
                                      @"/var/jb/var/lib/dpkg/info", @"/var/lib/dpkg/info"];
    NSInteger files = 0;
    for (NSString *dir in infoDirs) {
        for (NSString *file in [fm contentsOfDirectoryAtPath:dir error:nil]) {
            if (![file hasSuffix:@".list"]) continue;
            NSString *pkg = [file stringByDeletingPathExtension];
            NSString *content = [NSString stringWithContentsOfFile:[dir stringByAppendingPathComponent:file]
                                                          encoding:NSUTF8StringEncoding error:nil];
            if (!content) continue;
            for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
                NSString *p = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (p.length == 0 || [p isEqualToString:@"/."] || [p isEqualToString:@"/"]) continue;
                if (!self.fileOwners[p]) { self.fileOwners[p] = pkg; files++; }
                if ([p hasPrefix:@"/var/jb/"]) {
                    NSString *alt = [p substringFromIndex:7];
                    if (!self.fileOwners[alt]) self.fileOwners[alt] = pkg;
                } else {
                    NSString *alt = [@"/var/jb" stringByAppendingString:p];
                    if (!self.fileOwners[alt]) self.fileOwners[alt] = pkg;
                }
            }
        }
    }
    SSLog(@"Ban do so huu dpkg: %ld file, %lu goi co ten hien thi", (long)files, (unsigned long)self.packageNames.count);
}

// Gan muc canh bao + ghi chu + chu so huu cho 1 file. Thu tu luat: chat nhat truoc.
- (void)classifyItem:(SSFileItem *)item app:(nullable SSAppUsage *)app {
    NSString *path = item.path;
    NSString *ext = [[path pathExtension] lowercaseString];
    NSString *ownerPkg = self.fileOwners[path];
    if (!ownerPkg && [path hasPrefix:@"/var/jb/"]) ownerPkg = self.fileOwners[[path substringFromIndex:7]];
    if (!ownerPkg && ![path hasPrefix:@"/var/jb/"]) ownerPkg = self.fileOwners[[@"/var/jb" stringByAppendingString:path]];
    if (ownerPkg) {
        item.ownerPackage = ownerPkg;
        item.ownerName = self.packageNames[ownerPkg] ?: ownerPkg;
    }
    if ([SSUtil isPhotoThumbnailPath:path]) {
        item.inLibrary = NO;
        item.level = SSFileLevelCaution;
        item.note = @"Ảnh thu nhỏ do hệ thống tự tạo — xoá được, máy sẽ tạo lại khi mở app Ảnh (không phải ảnh gốc).";
        return;
    }
    if (item.inLibrary) {
        item.level = SSFileLevelDanger;
        item.note = @"Nằm trong thư viện Ảnh — chỉ xem, xoá bằng app Ảnh để không hỏng thư viện.";
        return;
    }
    if ([SSUtil isPathInAppBundle:path]) {
        item.level = SSFileLevelDanger;
        item.note = @"Nằm trong gói ứng dụng — không xoá file trực tiếp, hãy gỡ app nếu không dùng.";
        return;
    }
    if (app && [[SSUtil protectedAppIDs] containsObject:app.bundleID]) {
        item.isProtected = YES;
        item.level = SSFileLevelDanger;
        item.note = [NSString stringWithFormat:@"%@ nằm trong Danh sách bảo vệ — SpaceScope không dọn hàng loạt, chỉ xem và xử lý từng file.", app.name];
        return;
    }
    if ([SSUtil isProtectedPath:path]) {
        item.isProtected = YES;
        item.level = SSFileLevelDanger;
        item.note = @"Nằm trong vùng được bảo vệ (ghi âm cuộc gọi/dữ liệu quan trọng) — chỉ xoá từng file khi thật chắc chắn, nên backup trước.";
        return;
    }
    if ([ext isEqualToString:@"sqlite"] || [ext isEqualToString:@"sqlite3"] || [ext isEqualToString:@"db"] ||
        [ext isEqualToString:@"realm"] || [ext isEqualToString:@"db-wal"] || [ext isEqualToString:@"db-shm"]) {
        item.isProtected = YES;
        item.level = SSFileLevelDanger;
        item.note = @"Cơ sở dữ liệu — có thể chứa tin nhắn/tài khoản của app, không xoá nếu không chắc chắn.";
        return;
    }
    if (ownerPkg) {
        BOOL core = [path containsString:@"/MobileSubstrate/DynamicLibraries/"] ||
                    [path containsString:@"/LaunchDaemons/"] ||
                    [path containsString:@"/PreferenceBundles/"] ||
                    [path containsString:@"/PreferenceLoader/"] ||
                    [ext isEqualToString:@"dylib"];
        if (core) {
            item.level = SSFileLevelDanger;
            item.note = [NSString stringWithFormat:@"File lõi của %@ (%@) đang còn cài — xoá là nó ngừng chạy hoặc lỗi.", item.ownerName, ownerPkg];
        } else {
            item.level = SSFileLevelCaution;
            item.note = [NSString stringWithFormat:@"Thuộc %@ (%@) đang còn cài — xoá có thể mất dữ liệu/cài đặt của nó.", item.ownerName, ownerPkg];
        }
        return;
    }
    BOOL inCache = [path containsString:@"/Caches/"] || [path containsString:@"/tmp/"] || [path hasPrefix:@"/var/tmp/"];
    if (inCache) {
        item.level = SSFileLevelSafe;
        item.note = item.appName.length > 0
            ? [NSString stringWithFormat:@"Cache/file tạm của %@ — xoá an toàn, app tự tạo lại.", item.appName]
            : @"Cache/file tạm — xoá an toàn, tự tạo lại khi cần.";
        return;
    }
    if ([path containsString:@"/Logs/"] || [path containsString:@"CrashReporter"] || [ext isEqualToString:@"log"] || [ext isEqualToString:@"ips"]) {
        item.level = SSFileLevelSafe;
        item.note = @"File log/báo cáo lỗi — xoá an toàn.";
        return;
    }
    BOOL voiceMemo = [path containsString:@"VoiceMemos"] || [path containsString:@"voicememos"] ||
                     ([path containsString:@"/Recordings"] && item.kind == SSItemKindAudio);
    if (voiceMemo) {
        item.level = SSFileLevelCaution;
        item.note = @"Bản ghi âm (app Ghi âm) — nên backup trước khi xoá.";
        return;
    }
    if ([ext isEqualToString:@"deb"] || [ext isEqualToString:@"ipa"]) {
        item.level = SSFileLevelCaution;
        item.note = @"File cài đặt — xoá được nếu đã cài xong và không cần giữ bản cài.";
        return;
    }
    if (item.kind == SSItemKindArchive) {
        item.level = SSFileLevelCaution;
        item.note = @"File nén — kiểm tra nội dung bên trong trước khi xoá (có thể là bản sao lưu source).";
        return;
    }
    if (app) {
        if ([path containsString:@"/Documents/"]) {
            item.level = SSFileLevelCaution;
            item.note = [NSString stringWithFormat:@"Dữ liệu người dùng của %@ — xoá là mất dữ liệu trong app.", item.appName];
        } else {
            item.level = SSFileLevelCaution;
            item.note = [NSString stringWithFormat:@"Dữ liệu của %@ — kiểm tra trước khi xoá.", item.appName];
        }
        return;
    }
    if (item.kind == SSItemKindAudio) {
        item.level = SSFileLevelCaution;
        item.note = @"File âm thanh — nghe thử/kiểm tra trước khi xoá, nên backup nếu là ghi âm quan trọng.";
        return;
    }
    if (item.downloaded) {
        item.level = SSFileLevelCaution;
        item.note = @"File đã tải về/lưu trong máy — kiểm tra trước khi xoá.";
        return;
    }
    if (item.kind == SSItemKindPhoto || item.kind == SSItemKindVideo) {
        item.level = SSFileLevelCaution;
        item.note = @"Ảnh/video nằm ngoài thư viện Ảnh — kiểm tra trước khi xoá.";
        return;
    }
    if ([path hasPrefix:@"/var/jb"] || [path hasPrefix:@"/var/mobile/Library"]) {
        item.level = SSFileLevelCaution;
        item.note = @"Không thuộc gói nào đang cài — có thể là tàn dư của tweak/app đã gỡ, kiểm tra đường dẫn trước khi xoá.";
        return;
    }
    item.level = SSFileLevelCaution;
    item.note = @"Chưa rõ nguồn gốc — kiểm tra đường dẫn trước khi xoá.";
}

#pragma mark - Containers

- (NSDictionary<NSString *, NSString *> *)installedAppNames {
    NSMutableDictionary<NSString *, NSString *> *out = [NSMutableDictionary dictionary];
    Class wsClass = objc_getClass("LSApplicationWorkspace");
    if (!wsClass) {
        SSLog(@"Khong thay LSApplicationWorkspace, dung ten du phong tu bundle id");
        return out;
    }
    LSApplicationWorkspace *ws = [wsClass defaultWorkspace];
    for (LSApplicationProxy *proxy in [ws allInstalledApplications]) {
        NSString *bid = [proxy bundleIdentifier];
        NSString *name = [proxy localizedName];
        if (bid.length > 0) out[bid] = name.length > 0 ? name : bid;
    }
    SSLog(@"Doc duoc %lu ung dung da cai tu LSApplicationWorkspace", (unsigned long)out.count);
    return out;
}

- (NSSet<NSString *> *)dpkgPackageIDs {
    NSMutableSet<NSString *> *ids = [NSMutableSet set];
    NSArray<NSString *> *candidates = @[@"/var/lib/dpkg/status", @"/var/jb/var/lib/dpkg/status"];
    for (NSString *path in candidates) {
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (!content) continue;
        for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
            if ([line hasPrefix:@"Package: "]) {
                [ids addObject:[[line substringFromIndex:9] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
            }
        }
    }
    return ids;
}

- (void)scanDataContainers {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = @"/var/mobile/Containers/Data/Application";
    for (NSString *entry in [fm contentsOfDirectoryAtPath:base error:nil]) {
        NSString *container = [base stringByAppendingPathComponent:entry];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:container isDirectory:&isDir] || !isDir) continue;
        NSString *metaPath = [container stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
        NSString *bid = meta[@"MCMMetadataIdentifier"];
        if (bid.length == 0) bid = entry;
        if ([bid isEqualToString:@"com.anhdang.spacescope"]) continue;
        SSAppUsage *app = self.appsByBundle[bid];
        if (!app) {
            app = [[SSAppUsage alloc] init];
            app.bundleID = bid;
            app.name = self.appNames[bid] ?: [bid lastPathComponent];
            self.appsByBundle[bid] = app;
        }
        app.containerPath = container;
        int64_t before = app.dataSize;
        [self walkPath:container app:app downloadedContext:NO];
        app.totalSize += (app.dataSize - before);
    }
    // AppGroup dung chung: chi cong tong, khong liet ke tung file.
    NSString *groups = @"/var/mobile/Containers/Shared/AppGroup";
    for (NSString *entry in [fm contentsOfDirectoryAtPath:groups error:nil]) {
        NSString *full = [groups stringByAppendingPathComponent:entry];
        int64_t sz = [SSUtil sizeOfPath:full];
        self.result.scannedBytes += sz;
        self.result.categoryBytes[@"other"] = @([self.result.categoryBytes[@"other"] longLongValue] + sz);
    }
}

- (void)scanBundleContainers {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = @"/var/mobile/Containers/Bundle/Application";
    for (NSString *entry in [fm contentsOfDirectoryAtPath:base error:nil]) {
        NSString *dir = [base stringByAppendingPathComponent:entry];
        for (NSString *sub in [fm contentsOfDirectoryAtPath:dir error:nil]) {
            if (![sub hasSuffix:@".app"]) continue;
            NSString *appPath = [dir stringByAppendingPathComponent:sub];
            NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]];
            NSString *bid = info[@"CFBundleIdentifier"];
            if (bid.length == 0 || [bid isEqualToString:@"com.anhdang.spacescope"]) continue;
            int64_t sz = [SSUtil sizeOfPath:appPath];
            SSAppUsage *app = self.appsByBundle[bid];
            if (!app) {
                app = [[SSAppUsage alloc] init];
                app.bundleID = bid;
                NSString *nm = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"];
                app.name = self.appNames[bid] ?: (nm ?: [bid lastPathComponent]);
                self.appsByBundle[bid] = app;
            }
            app.bundleSize += sz;
            app.totalSize += sz;
            self.result.scannedBytes += sz;
        }
    }
}

#pragma mark - Rac & file thua

- (void)addJunkTitle:(NSString *)title detail:(NSString *)detail path:(NSString *)path size:(int64_t)size
                tier:(SSJunkTier)tier action:(SSJunkAction)action extraPaths:(nullable NSArray<NSString *> *)extraPaths {
    if (action != SSJunkActionInfoOnly && size <= 0) return;
    SSJunkItem *j = [[SSJunkItem alloc] init];
    j.title = title;
    j.detail = detail;
    j.path = path;
    j.size = size;
    j.tier = tier;
    j.action = action;
    if (extraPaths) [j.extraPaths addObjectsFromArray:extraPaths];
    [self.result.junkItems addObject:j];
}


- (void)addOrphanDependencyInfo {
    // Goi phu thuoc mo coi kieu iCleaner: thu vien khong con goi nao phu thuoc vao,
    // khong so huu dylib tweak/app. CHI LIET KE — go bang Sileo, app khong tu go goi.
    NSArray<NSString *> *statusCandidates = @[@"/var/jb/Library/dpkg/status", @"/Library/dpkg/status",
                                              @"/var/jb/var/lib/dpkg/status", @"/var/lib/dpkg/status"];
    NSString *statusText = nil;
    for (NSString *p in statusCandidates) {
        statusText = [NSString stringWithContentsOfFile:p encoding:NSUTF8StringEncoding error:nil];
        if (statusText.length > 0) break;
    }
    if (statusText.length == 0) return;
    NSMutableDictionary<NSString *, NSString *> *sections = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *allPkgs = [NSMutableSet set];
    NSMutableSet<NSString *> *needed = [NSMutableSet set];
    NSString *cur = nil;
    for (NSString *rawLine in [statusText componentsSeparatedByString:@"\n"]) {
        if ([rawLine hasPrefix:@"Package: "]) {
            cur = [[rawLine substringFromIndex:9] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (cur.length > 0) [allPkgs addObject:cur];
        } else if (cur.length > 0 && [rawLine hasPrefix:@"Section: "]) {
            sections[cur] = [[rawLine substringFromIndex:9] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        } else if (cur.length > 0 && ([rawLine hasPrefix:@"Depends: "] || [rawLine hasPrefix:@"Pre-Depends: "])) {
            NSString *rest = [rawLine substringFromIndex:([rawLine hasPrefix:@"Pre-"] ? 13 : 9)];
            for (NSString *part in [rest componentsSeparatedByString:@","]) {
                NSString *alt = [[part componentsSeparatedByString:@"|"] firstObject] ?: @"";
                NSRange paren = [alt rangeOfString:@"("];
                if (paren.location != NSNotFound) alt = [alt substringToIndex:paren.location];
                NSRange colon = [alt rangeOfString:@":"];
                if (colon.location != NSNotFound) alt = [alt substringToIndex:colon.location];
                alt = [alt stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (alt.length > 0) [needed addObject:alt];
            }
        }
    }
    NSMutableSet<NSString *> *activePkgs = [NSMutableSet set];
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *filesOf = [NSMutableDictionary dictionary];
    [self.fileOwners enumerateKeysAndObjectsUsingBlock:^(NSString *path, NSString *pkg, BOOL *stop) {
        if (!filesOf[pkg]) filesOf[pkg] = [NSMutableArray array];
        [filesOf[pkg] addObject:path];
        if ([path containsString:@"/MobileSubstrate/DynamicLibraries/"] || [path containsString:@".app/"]) [activePkgs addObject:pkg];
    }];
    NSMutableArray<NSDictionary *> *cands = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *pkg in allPkgs) {
        if ([needed containsObject:pkg]) continue;
        if ([activePkgs containsObject:pkg]) continue;
        NSString *sec = [sections[pkg] lowercaseString] ?: @"";
        if (![sec containsString:@"librar"] && ![pkg hasPrefix:@"lib"]) continue;
        int64_t sz = 0;
        for (NSString *f in filesOf[pkg]) sz += (int64_t)[[fm attributesOfItemAtPath:f error:nil] fileSize];
        [cands addObject:@{@"pkg": pkg, @"size": @(sz)}];
    }
    if (cands.count == 0) return;
    [cands sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"size"] compare:a[@"size"]];
    }];
    int64_t total = 0;
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSDictionary *c in cands) {
        total += [c[@"size"] longLongValue];
        if (names.count < 8) {
            NSString *disp = self.packageNames[c[@"pkg"]] ?: c[@"pkg"];
            [names addObject:[NSString stringWithFormat:@"%@ (%@)", disp, [SSUtil formatBytes:[c[@"size"] longLongValue]]]];
        }
    }
    [self addJunkTitle:[NSString stringWithFormat:@"Gói phụ thuộc có thể mồ côi (%ld gói)", (long)cands.count]
                detail:[NSString stringWithFormat:@"%@. Đây là các thư viện không còn gói nào cần tới — SpaceScope chỉ liệt kê để anh kiểm tra, hãy gỡ bằng Sileo cho an toàn (app không tự gỡ gói).", [names componentsJoinedByString:@", "]]
                  path:@"" size:total tier:SSJunkTierInfo action:SSJunkActionInfoOnly extraPaths:nil];
}

- (void)buildJunkItems {
    NSFileManager *fm = [NSFileManager defaultManager];

    // Cache + tmp cua tung app (xanh: xoa thang noi dung, app tu tao lai)
    for (SSAppUsage *app in self.appsByBundle.allValues) {
        int64_t sz = app.cacheSize + app.tmpSize;
        if (sz < 1024 * 1024 || app.containerPath.length == 0) continue;
        if ([[SSUtil protectedAppIDs] containsObject:app.bundleID]) continue;
        if ([app.bundleID isEqualToString:@"com.apple.mobilesafari"]) continue;
        NSString *caches = [app.containerPath stringByAppendingPathComponent:@"Library/Caches"];
        NSString *tmp = [app.containerPath stringByAppendingPathComponent:@"tmp"];
        [self addJunkTitle:[NSString stringWithFormat:@"Cache của %@", app.name]
                    detail:@"Bấm để mở ra xem từng file trong cache + file tạm rồi chọn lọc xoá — app tự tạo lại, không mất dữ liệu chính"
                      path:caches size:sz tier:SSJunkTierSafe action:SSJunkActionBrowse
                extraPaths:@[tmp]];
    }

    // Cache toan he thong cua nguoi dung + log + crash report
    int64_t globalCache = [SSUtil sizeOfPath:@"/var/mobile/Library/Caches"];
    [self addJunkTitle:@"Cache chung của hệ thống (người dùng)" detail:@"/var/mobile/Library/Caches — xoá an toàn"
                  path:@"/var/mobile/Library/Caches" size:globalCache tier:SSJunkTierSafe action:SSJunkActionBrowse extraPaths:nil];
    NSArray<NSString *> *logDirs = @[@"/var/mobile/Library/Logs/CrashReporter", @"/Library/Logs/CrashReporter",
                                     @"/var/jb/Library/Logs/CrashReporter", @"/var/mobile/Library/Logs"];
    NSMutableSet<NSString *> *seenLog = [NSMutableSet set];
    for (NSString *dir in logDirs) {
        if ([seenLog containsObject:dir]) continue;
        [seenLog addObject:dir];
        int64_t sz = [SSUtil sizeOfPath:dir];
        if (sz < 100 * 1024) continue;
        [self addJunkTitle:@"Log & báo cáo crash" detail:dir path:dir size:sz tier:SSJunkTierSafe action:SSJunkActionBrowse extraPaths:nil];
    }
    int64_t varTmp = [SSUtil sizeOfPath:@"/var/tmp"];
    [self addJunkTitle:@"Thư mục tạm /var/tmp" detail:@"File tạm của hệ thống và các app — bấm để xem từng file" path:@"/var/tmp"
                  size:varTmp tier:SSJunkTierSafe action:SSJunkActionBrowse extraPaths:nil];

    // Ban cap nhat iOS da tai ve cho cai
    int64_t ota = [SSUtil sizeOfPath:@"/var/MobileSoftwareUpdate"];
    if (ota > 0) {
        [self addJunkTitle:@"Bản cập nhật iOS đã tải về (chờ cài)" detail:@"Xoá đi máy sẽ tải lại khi cần cập nhật — kiểm tra kỹ trước khi xoá"
                      path:@"/var/MobileSoftwareUpdate" size:ota tier:SSJunkTierCaution action:SSJunkActionClearContents extraPaths:nil];
    }

    // File cai dat thua trong cac thu muc nguoi dung hay luu
    NSArray<NSString *> *huntDirs = @[@"/var/mobile/Documents", @"/var/mobile/Downloads", @"/var/mobile/Media/Downloads", @"/var/mobile"];
    NSMutableSet<NSString *> *seenFile = [NSMutableSet set];
    for (NSString *dir in huntDirs) {
        NSDirectoryEnumerator *en = [fm enumeratorAtPath:dir];
        NSString *sub = nil;
        while ((sub = [en nextObject]) != nil) {
            NSString *full = [dir stringByAppendingPathComponent:sub];
            if ([seenFile containsObject:full]) continue;
            NSDictionary *a = [en fileAttributes];
            if (![[a fileType] isEqualToString:NSFileTypeRegular]) {
                if ([dir isEqualToString:@"/var/mobile"] && [[a fileType] isEqualToString:NSFileTypeDirectory]) {
                    [en skipDescendants]; // chi quet lop tren cung cua /var/mobile
                }
                continue;
            }
            NSString *ext = [[sub pathExtension] lowercaseString];
            BOOL isInstaller = [ext isEqualToString:@"deb"] || [ext isEqualToString:@"ipa"];
            BOOL isSourceZip = [ext isEqualToString:@"zip"] && [[sub lowercaseString] containsString:@"source"];
            if (!isInstaller && !isSourceZip) continue;
            int64_t sz = (int64_t)[a fileSize];
            if (sz < 100 * 1024) continue;
            [seenFile addObject:full];
            [self addJunkTitle:[NSString stringWithFormat:@"File cài đặt thừa: %@", [sub lastPathComponent]]
                        detail:full path:full size:sz tier:SSJunkTierCaution action:SSJunkActionTrashItem extraPaths:nil];
        }
    }

    // Backup TweakPacker
    int64_t tp = [SSUtil sizeOfPath:@"/var/mobile/Documents/TweakPacker"];
    if (tp > 0) {
        [self addJunkTitle:@"Kho backup của TweakPacker" detail:@"/var/mobile/Documents/TweakPacker — gồm các bản .deb đã xuất, kiểm tra trước khi dọn"
                      path:@"/var/mobile/Documents/TweakPacker" size:tp tier:SSJunkTierCaution action:SSJunkActionTrashItem extraPaths:nil];
    }

    // Thung rac cua Filza (neu co)
    for (SSAppUsage *app in self.appsByBundle.allValues) {
        if ([[app.bundleID lowercaseString] containsString:@"filza"] && app.containerPath.length > 0) {
            for (NSString *cand in @[@"Documents/Trash", @"Documents/.Trash"]) {
                NSString *full = [app.containerPath stringByAppendingPathComponent:cand];
                int64_t sz = [SSUtil sizeOfPath:full];
                if (sz > 0) {
                    [self addJunkTitle:@"Thùng rác của Filza chưa đổ" detail:full path:full size:sz
                                  tier:SSJunkTierSafe action:SSJunkActionClearContents extraPaths:nil];
                }
            }
        }
    }


    // Don sau kieu iCleaner — moi nhom deu mo ra xem duoc tung file truoc khi xoa.
    SSAppUsage *safari = self.appsByBundle[@"com.apple.mobilesafari"];
    if (safari.containerPath.length > 0) {
        NSString *safariDir = [safari.containerPath stringByAppendingPathComponent:@"Library/Safari"];
        NSString *safariCache = [safari.containerPath stringByAppendingPathComponent:@"Library/Caches"];
        int64_t s1 = [SSUtil sizeOfPath:safariDir];
        int64_t s2 = [SSUtil sizeOfPath:safariCache];
        if (s1 + s2 >= 5LL * 1024 * 1024) {
            [self addJunkTitle:@"Dữ liệu & cache Safari"
                        detail:@"Mở ra xem từng file trước khi xoá. Lưu ý: History.db là lịch sử duyệt web (cơ sở dữ liệu) — xoá là mất lịch sử."
                          path:safariDir size:(s1 + s2) tier:SSJunkTierCaution action:SSJunkActionBrowse
                    extraPaths:(s2 > 0 ? @[safariCache] : nil)];
        }
    }
    {
        NSString *thumbs = @"/var/mobile/Media/PhotoData/Thumbnails";
        NSString *pcaches = @"/var/mobile/Media/PhotoData/Caches";
        int64_t ts = [SSUtil sizeOfPath:thumbs];
        int64_t pcs = [SSUtil sizeOfPath:pcaches];
        if (ts + pcs >= 10LL * 1024 * 1024) {
            [self addJunkTitle:@"Ảnh thu nhỏ (thumbnail) của thư viện Ảnh"
                        detail:@"Ảnh xem trước do hệ thống tự tạo, KHÔNG phải ảnh gốc — xoá thì máy tự tạo lại khi mở app Ảnh."
                          path:thumbs size:(ts + pcs) tier:SSJunkTierCaution action:SSJunkActionBrowse
                    extraPaths:(pcs > 0 ? @[pcaches] : nil)];
        }
    }
    {
        NSString *att = @"/var/mobile/Library/SMS/Attachments";
        int64_t as = [SSUtil sizeOfPath:att];
        if (as >= 10LL * 1024 * 1024) {
            [self addJunkTitle:@"File đính kèm tin nhắn (iMessage/SMS)"
                        detail:@"Ảnh/video/file nhận qua Tin nhắn — mở xem từng file trước khi xoá; xoá là mất file trong cuộc trò chuyện."
                          path:att size:as tier:SSJunkTierCaution action:SSJunkActionBrowse extraPaths:nil];
        }
    }
    {
        NSString *kb = @"/var/mobile/Library/Keyboard";
        int64_t ks = [SSUtil sizeOfPath:kb];
        if (ks >= 5LL * 1024 * 1024) {
            [self addJunkTitle:@"Cache bàn phím & từ điển gõ"
                        detail:@"Từ điển gõ cá nhân + cache bàn phím — xoá thì máy học lại thói quen gõ từ đầu."
                          path:kb size:ks tier:SSJunkTierCaution action:SSJunkActionBrowse extraPaths:nil];
        }
    }
    // Vung bao ve: moi app nam trong Danh sach bao ve deu co muc rieng, chi xem/backup.
    for (NSString *bid in [SSUtil protectedAppIDs]) {
        SSAppUsage *app = self.appsByBundle[bid];
        if (app.containerPath.length == 0) continue;
        SSJunkItem *j = [[SSJunkItem alloc] init];
        j.title = [NSString stringWithFormat:@"🛡️ Dữ liệu %@ — vùng được bảo vệ", app.name];
        j.detail = @"SpaceScope không dọn hàng loạt mục này. Mở ra chỉ để xem/backup; xoá từng file khi thật chắc chắn.";
        j.path = app.containerPath;
        j.size = app.totalSize;
        j.tier = SSJunkTierInfo;
        j.action = SSJunkActionBrowse;
        j.protectedZone = YES;
        [self.result.junkItems addObject:j];
    }
    // Thu muc ghi am cuoc goi cua tweak (AudioRecorder va tuong tu).
    for (NSString *base in @[@"/var/mobile/Library", @"/var/mobile/Documents"]) {
        for (NSString *name in [fm contentsOfDirectoryAtPath:base error:nil]) {
            NSString *low = [name lowercaseString];
            if (![low containsString:@"audiorecorder"] && ![low containsString:@"callrecorder"]) continue;
            NSString *full = [base stringByAppendingPathComponent:name];
            BOOL isDir = NO;
            if (!([fm fileExistsAtPath:full isDirectory:&isDir] && isDir)) continue;
            SSJunkItem *j = [[SSJunkItem alloc] init];
            j.title = @"🛡️ Bản ghi âm cuộc gọi — vùng được bảo vệ";
            j.detail = [NSString stringWithFormat:@"%@ — dữ liệu của anh, SpaceScope không dọn hàng loạt.", full];
            j.path = full;
            j.size = [SSUtil sizeOfPath:full];
            j.tier = SSJunkTierInfo;
            j.action = SSJunkActionBrowse;
            j.protectedZone = YES;
            [self.result.junkItems addObject:j];
        }
    }
    [self addOrphanDependencyInfo];

    // Plist cai dat mo coi: tweak/app da go nhung file cai dat con sot lai
    NSString *prefsDir = @"/var/mobile/Library/Preferences";
    NSInteger orphanCount = 0;
    for (NSString *file in [fm contentsOfDirectoryAtPath:prefsDir error:nil]) {
        if (![file hasSuffix:@".plist"]) continue;
        NSString *base = [file stringByDeletingPathExtension];
        if ([base hasPrefix:@"com.apple"] || [base isEqualToString:@"com.anhdang.spacescope"]) continue;
        if ([self.installedIDs containsObject:base]) continue;
        NSString *full = [prefsDir stringByAppendingPathComponent:file];
        int64_t sz = [SSUtil sizeOfPath:full];
        orphanCount++;
        if (orphanCount <= 50) {
            [self addJunkTitle:[NSString stringWithFormat:@"Cài đặt mồ côi: %@", base]
                        detail:@"Không còn app/tweak nào đang cài khớp mã này — khả năng là tàn dư của app/tweak đã gỡ"
                          path:full size:MAX(sz, 1) tier:SSJunkTierCaution action:SSJunkActionTrashItem extraPaths:nil];
        }
    }
    if (orphanCount > 0) SSLog(@"Phat hien %ld plist cai dat mo coi", (long)orphanCount);

    // Muc thong tin: anh da xoa gan day (khong do duoc dung luong tu ngoai, huong dan cho anh)
    [self addJunkTitle:@"Ảnh & video đã xoá gần đây" detail:@"Vẫn chiếm chỗ tới 30 ngày. Mở app Ảnh → Album → Đã xoá gần đây → Xoá tất cả để giải phóng ngay."
                  path:@"" size:0 tier:SSJunkTierInfo action:SSJunkActionInfoOnly extraPaths:nil];

    [self.result.junkItems sortUsingComparator:^NSComparisonResult(SSJunkItem *a, SSJunkItem *b) {
        return a.size > b.size ? NSOrderedAscending : (a.size < b.size ? NSOrderedDescending : NSOrderedSame);
    }];
}

#pragma mark - Trung lap

- (nullable NSString *)partialHashForItem:(SSFileItem *)item {
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:item.path];
    if (!fh) return nil;
    const unsigned long long chunk = 64 * 1024;
    NSMutableData *buf = [NSMutableData data];
    NSData *head = [fh readDataOfLength:(NSUInteger)MIN(chunk, (unsigned long long)item.size)];
    if (head) [buf appendData:head];
    if (item.size > (int64_t)chunk) {
        [fh seekToFileOffset:(unsigned long long)item.size - chunk];
        NSData *tail = [fh readDataOfLength:(NSUInteger)chunk];
        if (tail) [buf appendData:tail];
    }
    [fh closeFile];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(buf.bytes, (CC_LONG)buf.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

- (nullable NSString *)fullHashForItem:(SSFileItem *)item {
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:item.path];
    if (!fh) return nil;
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    while (YES) {
        @autoreleasepool {
            NSData *chunk = [fh readDataOfLength:1024 * 1024];
            if (chunk.length == 0) return [self finishHash:&ctx fh:fh];
            CC_SHA256_Update(&ctx, chunk.bytes, (CC_LONG)chunk.length);
        }
    }
    return nil;
}

- (NSString *)finishHash:(CC_SHA256_CTX *)ctx fh:(NSFileHandle *)fh {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, ctx);
    [fh closeFile];
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

- (NSInteger)originalScoreForItem:(SSFileItem *)item {
    NSInteger score = 0;
    if (item.inLibrary) score += 100;
    if ([item.path containsString:@"/Documents/"]) score += 20;
    if ([item.path hasPrefix:@"/var/mobile/Media"] && ![item.path containsString:@"/Downloads/"]) score += 20;
    if ([item.path containsString:@"/Downloads/"]) score -= 30;
    if ([item.path containsString:@"/Caches/"] || [item.path containsString:@"/tmp/"]) score -= 60;
    if ([item.name containsString:@" ("]) score -= 10;
    return score;
}

- (void)buildDupGroups {
    NSMutableArray<SSDupGroup *> *groups = [NSMutableArray array];
    for (NSNumber *sizeKey in self.bySize) {
        NSMutableArray<SSFileItem *> *sameSize = self.bySize[sizeKey];
        if (sameSize.count < 2) continue;
        NSMutableDictionary<NSString *, NSMutableArray<SSFileItem *> *> *byPartial = [NSMutableDictionary dictionary];
        for (SSFileItem *item in sameSize) {
            NSString *h = [self partialHashForItem:item];
            if (!h) continue;
            NSMutableArray *arr = byPartial[h];
            if (!arr) { arr = [NSMutableArray array]; byPartial[h] = arr; }
            [arr addObject:item];
        }
        for (NSString *pKey in byPartial) {
            NSMutableArray<SSFileItem *> *samePartial = byPartial[pKey];
            if (samePartial.count < 2) continue;
            NSMutableDictionary<NSString *, NSMutableArray<SSFileItem *> *> *byFull = [NSMutableDictionary dictionary];
            for (SSFileItem *item in samePartial) {
                NSString *h = [self fullHashForItem:item];
                if (!h) continue;
                NSMutableArray *arr = byFull[h];
                if (!arr) { arr = [NSMutableArray array]; byFull[h] = arr; }
                [arr addObject:item];
            }
            for (NSString *fKey in byFull) {
                NSMutableArray<SSFileItem *> *sameFull = byFull[fKey];
                if (sameFull.count < 2) continue;
                SSDupGroup *g = [[SSDupGroup alloc] init];
                g.items = sameFull;
                g.fileSize = [sizeKey longLongValue];
                g.fullHash = fKey;
                SSFileItem *best = nil;
                NSInteger bestScore = NSIntegerMin;
                for (SSFileItem *item in sameFull) {
                    NSInteger s = [self originalScoreForItem:item];
                    BOOL better = NO;
                    if (!best) better = YES;
                    else if (s > bestScore) better = YES;
                    else if (s == bestScore) {
                        NSDate *a = item.created ?: item.modified;
                        NSDate *b = best.created ?: best.modified;
                        if (a && b && [a compare:b] == NSOrderedAscending) better = YES;
                        else if (a && !b) better = YES;
                    }
                    if (better) { best = item; bestScore = s; }
                }
                g.original = best;
                [groups addObject:g];
            }
        }
    }
    [groups sortUsingComparator:^NSComparisonResult(SSDupGroup *a, SSDupGroup *b) {
        int64_t wa = [a wastedBytes], wb = [b wastedBytes];
        return wa > wb ? NSOrderedAscending : (wa < wb ? NSOrderedDescending : NSOrderedSame);
    }];
    if (groups.count > 500) [groups removeObjectsInRange:NSMakeRange(500, groups.count - 500)];
    self.result.dupGroups = groups;
    SSLog(@"Tim trung: %lu nhom, tong ban sao xoa duoc %@", (unsigned long)groups.count, [SSUtil formatBytes:[self.result dupWastedBytes]]);
}

#pragma mark - Snapshot so sanh

- (void)loadPreviousSnapshotAndSaveCurrent {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [SSUtil snapshotsDir];
    NSMutableArray<NSString *> *files = [[[fm contentsOfDirectoryAtPath:dir error:nil] sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
    NSDictionary *prev = nil;
    if (files.count > 0) {
        NSString *last = [dir stringByAppendingPathComponent:files.lastObject];
        NSData *data = [NSData dataWithContentsOfFile:last];
        if (data) {
            NSDictionary *d = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([d isKindOfClass:[NSDictionary class]]) prev = d;
        }
    }
    self.result.previousSnapshot = prev;
    if (prev) {
        NSDictionary *prevApps = prev[@"apps"];
        NSMutableArray<NSDictionary *> *leaders = [NSMutableArray array];
        for (SSAppUsage *app in self.appsByBundle.allValues) {
            int64_t before = [prevApps[app.bundleID] longLongValue];
            int64_t delta = app.totalSize - before;
            if (delta >= 50 * 1024 * 1024) {
                [leaders addObject:@{@"name": app.name, @"bundleID": app.bundleID, @"delta": @(delta), @"total": @(app.totalSize)}];
            }
        }
        [leaders sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [b[@"delta"] compare:a[@"delta"]];
        }];
        if (leaders.count > 5) [leaders removeObjectsInRange:NSMakeRange(5, leaders.count - 5)];
        self.result.growthLeaders = leaders;
    }

    NSMutableDictionary *appsDict = [NSMutableDictionary dictionary];
    for (SSAppUsage *app in self.appsByBundle.allValues) appsDict[app.bundleID] = @(app.totalSize);
    NSDictionary *snap = @{
        @"date": @([[NSDate date] timeIntervalSince1970]),
        @"diskFree": @(self.result.diskFree),
        @"diskTotal": @(self.result.diskTotal),
        @"categories": self.result.categoryBytes,
        @"apps": appsDict,
        @"dupWasted": @([self.result dupWastedBytes]),
        @"junkTotal": @([self.result junkTotalBytes])
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:snap options:0 error:nil];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *name = [NSString stringWithFormat:@"snap-%@.json", [fmt stringFromDate:[NSDate date]]];
    [data writeToFile:[dir stringByAppendingPathComponent:name] atomically:YES];
    [files addObject:name];
    while (files.count > 12) {
        [fm removeItemAtPath:[dir stringByAppendingPathComponent:files.firstObject] error:nil];
        [files removeObjectAtIndex:0];
    }
}

@end
