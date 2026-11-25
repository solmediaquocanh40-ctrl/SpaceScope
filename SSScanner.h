#import <Foundation/Foundation.h>
#import "SSModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface SSScanner : NSObject
- (SSScanResult *)runScanWithProgress:(void (^)(NSString *text))progress;
@end

NS_ASSUME_NONNULL_END
