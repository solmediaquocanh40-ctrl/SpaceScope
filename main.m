#import <UIKit/UIKit.h>
#import "SSAppDelegate.h"
#import "SSLog.h"

// Ghi lai moi exception khong duoc xu ly vao file log truoc khi app vang,
// de lan sau mo log ra la thay ngay vang o dau, vi sao.
static void SSUncaughtExceptionHandler(NSException *exception) {
    SSLog(@"CRASH (exception): %@ — %@\nStack:\n%@", exception.name, exception.reason,
          [exception.callStackSymbols componentsJoinedByString:@"\n"]);
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSSetUncaughtExceptionHandler(&SSUncaughtExceptionHandler);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([SSAppDelegate class]));
    }
}
