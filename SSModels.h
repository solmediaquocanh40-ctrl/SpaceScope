#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const SSStoreDidUpdateNotification;

typedef NS_ENUM(NSInteger, SSItemKind) {
    SSItemKindOther = 0,
    SSItemKindPhoto,
    SSItemKindVideo,
    SSItemKindAudio,
    SSItemKindArchive,
    SSItemKindDocument
};

typedef NS_ENUM(NSInteger, SSFileLevel) {
    SSFileLevelSafe = 0,
    SSFileLevelCaution,
    SSFileLevelDanger
};

@interface SSFileItem : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) int64_t size;
@property (nonatomic, strong, nullable) NSDate *created;
@property (nonatomic, strong, nullable) NSDate *modified;
@property (nonatomic, assign) BOOL inLibrary;
@property (nonatomic, assign) BOOL downloaded;
@property (nonatomic, copy) NSString *appName;
@property (nonatomic, assign) SSItemKind kind;
@property (nonatomic, assign) SSFileLevel level;
@property (nonatomic, copy) NSString *note;
@property (nonatomic, copy) NSString *ownerName;
@property (nonatomic, copy) NSString *ownerPackage;
@property (nonatomic, assign) BOOL isProtected;
- (instancetype)initWithPath:(NSString *)path size:(int64_t)size created:(nullable NSDate *)created modified:(nullable NSDate *)modified;
- (NSString *)kindLabel;
- (NSString *)levelLabel;
@end

@interface SSDupGroup : NSObject
@property (nonatomic, strong) NSMutableArray<SSFileItem *> *items;
@property (nonatomic, assign) int64_t fileSize;
@property (nonatomic, copy) NSString *fullHash;
@property (nonatomic, strong, nullable) SSFileItem *original;
- (NSArray<SSFileItem *> *)deletableCopies;
- (int64_t)wastedBytes;
@end

@interface SSAppUsage : NSObject
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *containerPath;
@property (nonatomic, assign) int64_t totalSize;
@property (nonatomic, assign) int64_t bundleSize;
@property (nonatomic, assign) int64_t dataSize;
@property (nonatomic, assign) int64_t cacheSize;
@property (nonatomic, assign) int64_t tmpSize;
@property (nonatomic, assign) int64_t docsSize;
@property (nonatomic, strong) NSMutableArray<NSString *> *offlineHints;
@property (nonatomic, strong) NSMutableArray<SSFileItem *> *topItems;
@end

typedef NS_ENUM(NSInteger, SSJunkTier) {
    SSJunkTierSafe = 0,
    SSJunkTierCaution,
    SSJunkTierInfo
};

typedef NS_ENUM(NSInteger, SSJunkAction) {
    SSJunkActionClearContents = 0,
    SSJunkActionTrashItem,
    SSJunkActionInfoOnly,
    SSJunkActionBrowse
};

@interface SSJunkItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) int64_t size;
@property (nonatomic, assign) SSJunkTier tier;
@property (nonatomic, assign) SSJunkAction action;
@property (nonatomic, assign) BOOL protectedZone;
@property (nonatomic, strong) NSMutableArray<NSString *> *extraPaths;
@end

@interface SSScanResult : NSObject
@property (nonatomic, strong) NSDate *scannedAt;
@property (nonatomic, assign) int64_t diskTotal;
@property (nonatomic, assign) int64_t diskFree;
@property (nonatomic, assign) int64_t scannedBytes;
@property (nonatomic, assign) NSInteger fileCount;
@property (nonatomic, assign) NSInteger errorCount;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *categoryBytes;
@property (nonatomic, strong) NSMutableArray<SSFileItem *> *topFiles;
@property (nonatomic, strong) NSMutableArray<SSAppUsage *> *apps;
@property (nonatomic, strong) NSMutableArray<SSDupGroup *> *dupGroups;
@property (nonatomic, strong) NSMutableArray<SSJunkItem *> *junkItems;
@property (nonatomic, assign) int64_t dcimBytes;
@property (nonatomic, assign) int64_t photoDataBytes;
@property (nonatomic, assign) int64_t jbBytes;
@property (nonatomic, assign) int64_t downloadsBytes;
@property (nonatomic, assign) int64_t cacheBytesTotal;
@property (nonatomic, assign) int64_t growth7;
@property (nonatomic, assign) int64_t growth30;
@property (nonatomic, assign) int64_t growth90;
@property (nonatomic, strong, nullable) NSDictionary *previousSnapshot;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *growthLeaders;
- (int64_t)dupWastedBytes;
- (int64_t)junkTotalBytes;
- (NSArray<NSDictionary *> *)topCauses;
@end

@interface SSStore : NSObject
+ (instancetype)sharedStore;
@property (nonatomic, strong, nullable) SSScanResult *result;
@property (nonatomic, assign) BOOL scanning;
@property (nonatomic, copy) NSString *progressText;
@property (nonatomic, strong) NSMutableSet<NSString *> *protectedOriginals;
- (void)startScanIfNeeded;
- (void)startScan;
- (BOOL)isOriginalProtected:(NSString *)path;
@end

NS_ASSUME_NONNULL_END
