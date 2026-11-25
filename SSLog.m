#import "SSLog.h"

NSString *SSLogFilePath(void) {
    NSString *shared = @"/var/mobile/Documents/SpaceScope.log";
    if ([[NSFileManager defaultManager] isWritableFileAtPath:@"/var/mobile/Documents"] ||
        [[NSFileManager defaultManager] fileExistsAtPath:shared]) {
        return shared;
    }
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [docs stringByAppendingPathComponent:@"SpaceScope.log"];
}

void SSLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    static dispatch_queue_t SSLogQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SSLogQueue = dispatch_queue_create("com.anhdang.spacescope.log", DISPATCH_QUEUE_SERIAL);
    });
    dispatch_async(SSLogQueue, ^{
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [fmt stringFromDate:[NSDate date]], msg];
        NSString *path = SSLogFilePath();
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (fh) {
            [fh seekToEndOfFile];
            [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        } else {
            [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
        NSLog(@"[SpaceScope] %@", msg);
    });
}
