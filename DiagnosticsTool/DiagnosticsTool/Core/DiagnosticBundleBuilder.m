#import "DiagnosticBundleBuilder.h"

@implementation DiagnosticBundleBuilder

+ (NSURL *)tempDir {
    NSURL *base = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    return [base URLByAppendingPathComponent:[[NSUUID UUID] UUIDString] isDirectory:YES];
}

+ (void)buildWithSysdiagnose:(BOOL)includeSys completion:(void(^)(NSURL *zipURL, NSError *error))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *err = nil;
        NSURL *dir = [self tempDir];
        [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&err];
        if (err) { if (completion) completion(nil, err); return; }

        // 1) log collect
        NSURL *logArchive = [dir URLByAppendingPathComponent:@"App.logarchive"];
        NSArray *logArgs = @[ @"collect", @"--output", logArchive.path ];
        int rc1 = [self run:@"/usr/bin/log" args:logArgs];
        if (rc1 != 0) NSLog(@"log collect failed rc=%d", rc1);

        // 2) optional sysdiagnose
        if (includeSys) {
            [self run:@"/usr/sbin/sysdiagnose" args:@[]];
            // Try to copy latest sysdiagnose from /var/tmp
            NSString *tmp = @"/var/tmp";
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmp error:nil];
            NSString *latest = nil; NSDate *latestDate = [NSDate distantPast];
            for (NSString *name in contents) {
                if ([name hasPrefix:@"sysdiagnose_"]) {
                    NSString *full = [tmp stringByAppendingPathComponent:name];
                    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:full error:nil];
                    NSDate *d = attrs[NSFileModificationDate];
                    if ([d compare:latestDate] == NSOrderedDescending) { latestDate = d; latest = full; }
                }
            }
            if (latest) {
                NSURL *dest = [dir URLByAppendingPathComponent:[latest lastPathComponent]];
                [[NSFileManager defaultManager] copyItemAtPath:latest toPath:dest.path error:nil];
            }
        }

        // 3) zip folder
        NSURL *zipURL = [dir URLByAppendingPathComponent:@"diagnostics.zip"];
        int rc2 = [self run:@"/usr/bin/zip" args:@[ @"-r", zipURL.path, @"." ] cwd:dir.path];
        if (rc2 != 0) NSLog(@"zip failed rc=%d", rc2);
        if (completion) completion(zipURL, nil);
    });
}

+ (int)run:(NSString *)cmd args:(NSArray<NSString*>*)args { return [self run:cmd args:args cwd:nil]; }
+ (int)run:(NSString *)cmd args:(NSArray<NSString*>*)args cwd:(NSString *)cwd {
    NSTask *task = [NSTask new];
    task.launchPath = cmd;
    task.arguments = args ?: @[];
    if (cwd) task.currentDirectoryPath = cwd;
    @try { [task launch]; [task waitUntilExit]; return task.terminationStatus; }
    @catch(NSException *e) { NSLog(@"Task failed: %@", e); return -1; }
}
@end
