#import "SSAppDelegate.h"
#import "SSOverviewVC.h"
#import "SSFilesVC.h"
#import "SSDupsVC.h"
#import "SSCleanVC.h"
#import "SSAppsVC.h"
#import "SSModels.h"
#import "SSUtil.h"
#import "SSLog.h"

@implementation SSAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    SSLog(@"=== SpaceScope 1.0.0 khoi dong ===");
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    SSOverviewVC *overview = [[SSOverviewVC alloc] init];
    overview.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Tổng quan" image:[UIImage systemImageNamed:@"chart.bar.fill"] tag:0];
    UINavigationController *navOverview = [[UINavigationController alloc] initWithRootViewController:overview];

    SSFilesVC *files = [[SSFilesVC alloc] init];
    files.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"File nặng" image:[UIImage systemImageNamed:@"doc.text.magnifyingglass"] tag:1];
    UINavigationController *navFiles = [[UINavigationController alloc] initWithRootViewController:files];

    SSDupsVC *dups = [[SSDupsVC alloc] init];
    dups.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Trùng lặp" image:[UIImage systemImageNamed:@"doc.on.doc.fill"] tag:2];
    UINavigationController *navDups = [[UINavigationController alloc] initWithRootViewController:dups];

    SSCleanVC *clean = [[SSCleanVC alloc] init];
    clean.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Dọn dẹp" image:[UIImage systemImageNamed:@"trash.fill"] tag:3];
    UINavigationController *navClean = [[UINavigationController alloc] initWithRootViewController:clean];

    SSAppsVC *apps = [[SSAppsVC alloc] init];
    apps.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Ứng dụng" image:[UIImage systemImageNamed:@"square.grid.2x2.fill"] tag:4];
    UINavigationController *navApps = [[UINavigationController alloc] initWithRootViewController:apps];

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[navOverview, navFiles, navDups, navClean, navApps];
    self.window.rootViewController = tabs;
    [self.window makeKeyAndVisible];

    // Don thung rac qua han giu (mac dinh 7 ngay) ngay khi mo app.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [SSUtil purgeExpiredTrash];
    });
    // Tu quet lan dau sau khi giao dien len xong.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[SSStore sharedStore] startScanIfNeeded];
    });
    return YES;
}

@end
