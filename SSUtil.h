#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSUtil : NSObject

// Dinh dang & duong dan
+ (NSString *)formatBytes:(int64_t)bytes;
+ (NSString *)jbPrefix;
+ (NSString *)workDir;
+ (NSString *)trashDir;
+ (NSString *)snapshotsDir;
+ (BOOL)isPathInPhotoLibrary:(NSString *)path;
+ (BOOL)isPathInAppBundle:(NSString *)path;

// Do kich thuoc & don thu muc (khong di theo symlink)
+ (int64_t)sizeOfPath:(NSString *)path;
+ (int64_t)clearContentsOfDirectory:(NSString *)path;

// Thung rac tam: moi thu xoa deu vao day truoc, giu theo so ngay cai dat.
// Cac ham tra nil neu thanh cong, tra ve chuoi mo ta loi neu that bai.
+ (nullable NSString *)moveToTrash:(NSString *)path;
+ (NSArray<NSDictionary *> *)trashManifestEntries;
+ (nullable NSString *)restoreTrashEntry:(NSDictionary *)entry;
+ (nullable NSString *)purgeTrashEntry:(NSDictionary *)entry;
+ (int64_t)trashTotalSize;
+ (void)purgeExpiredTrash;

// Cai dat (NSUserDefaults)
+ (NSInteger)warnFreeGB;
+ (void)setWarnFreeGB:(NSInteger)value;
+ (NSInteger)trashKeepDays;
+ (void)setTrashKeepDays:(NSInteger)value;
+ (NSInteger)dupMinMB;
+ (void)setDupMinMB:(NSInteger)value;

@end

NS_ASSUME_NONNULL_END
