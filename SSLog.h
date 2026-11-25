#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Ghi log go loi ra /var/mobile/Documents/SpaceScope.log (du phong: Documents cua app).
void SSLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
NSString *SSLogFilePath(void);

NS_ASSUME_NONNULL_END
