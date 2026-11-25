#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SSModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface SSUtil : NSObject

// Dinh dang & duong dan
+ (NSString *)formatBytes:(int64_t)bytes;
+ (NSString *)jbPrefix;
+ (NSString *)workDir;
+ (NSString *)trashDir;
+ (NSString *)backupDir;
+ (NSString *)snapshotsDir;
+ (BOOL)isPathInPhotoLibrary:(NSString *)path;
+ (BOOL)isPhotoThumbnailPath:(NSString *)path;
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

// Danh sach bao ve: app (theo bundle id) va thu muc anh tu chon trong Cai dat.
// Mac dinh co san Zalo (du lieu chat) trong danh sach app bao ve.
// Nen ung dung (Cai dat -> Giao dien): 0 = mac dinh theo he thong, 1-8 = mau sang, 9-10 = mau toi.
+ (NSArray<NSString *> *)backgroundNames;
+ (NSInteger)backgroundChoice;
+ (void)setBackgroundChoice:(NSInteger)choice;
+ (nullable UIColor *)backgroundColorForChoice:(NSInteger)choice;
+ (void)applyThemeToViewController:(UIViewController *)vc;

+ (NSSet<NSString *> *)protectedAppIDs;
+ (void)setAppID:(NSString *)bundleID protected:(BOOL)isProtected;
+ (NSArray<NSString *> *)protectedFolderPaths;
+ (void)addProtectedFolderPath:(NSString *)path;
+ (void)removeProtectedFolderPath:(NSString *)path;
// Duong dan co nam trong vung bao ve san (thu muc ghi am cuoc goi...) hoac thu muc tuy chon khong.
+ (BOOL)isProtectedPath:(NSString *)path;
// Phan loai nhanh cho man duyet noi dung (khong can ban do dpkg).
+ (SSItemKind)kindForPath:(NSString *)path;
+ (void)classifyBrowsedItem:(SSFileItem *)item;
// Chuyen vao thung rac nhung bo qua lop chan vung bao ve (chi dung cho thao tac
// xoa le 1 file sau khi nguoi dung da xac nhan canh bao rieng). Cac khoa cung
// khac (file goc, thu vien Anh, goi app) van giu nguyen.
+ (nullable NSString *)moveToTrashProtectedOverride:(NSString *)path;

// Backup: nen cac file da chon thanh 1 file .zip (dinh dang stored, kem
// MANIFEST.txt ghi duong dan goc) trong Documents/SpaceScope/Backup.
// Tra nil neu thanh cong va gan outPath; tra chuoi loi neu that bai.
+ (nullable NSString *)createBackupZipForItems:(NSArray<SSFileItem *> *)items outPath:(NSString *_Nullable *_Nullable)outPath;

// Cai dat (NSUserDefaults)
+ (NSInteger)warnFreeGB;
+ (void)setWarnFreeGB:(NSInteger)value;
+ (NSInteger)trashKeepDays;
+ (void)setTrashKeepDays:(NSInteger)value;
+ (NSInteger)dupMinMB;
+ (void)setDupMinMB:(NSInteger)value;

@end

NS_ASSUME_NONNULL_END
