#import "DiagnosticBundleBuilder.h"
#import "Redactor.h"
#import "LogCollector.h"
#import <os/log.h>

@implementation DiagnosticBundleBuilder

+ (NSURL *)tempDir {
    NSURL *base = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    return [base URLByAppendingPathComponent:[[NSUUID UUID] UUIDString] isDirectory:YES];
}

+ (NSURL *)desktopURL {
    // For sandboxed apps, use Downloads folder which has proper entitlements
    // Desktop access in sandboxed apps points to containerized location which zip can't write to
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
    if (paths.count > 0) {
        return [NSURL fileURLWithPath:paths[0] isDirectory:YES];
    }
    return nil;
}

+ (void)buildWithSysdiagnose:(BOOL)includeSys completion:(void(^)(NSURL *zipURL, NSError *error))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *err = nil;
        NSFileManager *fm = [NSFileManager defaultManager];

        // Create temp directory
        NSURL *dir = [self tempDir];
        [fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&err];
        if (err) {
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Failed to create temp dir: %s", err.localizedDescription.UTF8String);
            if (completion) completion(nil, err);
            return;
        }

        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "Created temp dir: %s", dir.path.UTF8String);
        [[LogCollector shared] info:[NSString stringWithFormat:@"Starting diagnostic bundle collection (sysdiagnose: %@)",
                                     includeSys ? @"YES" : @"NO"]];

        // 1) Collect application logs from LogCollector
        NSURL *appLogsFile = [dir URLByAppendingPathComponent:@"application_logs.txt"];
        NSString *appLogs = [[LogCollector shared] getLogsFromLastDays:10];
        [appLogs writeToURL:appLogsFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "Application logs collected: %lu bytes",
                        (unsigned long)[appLogs length]);

        // 2) Collect diagnostic information
        // Note: Command-line 'log' tool doesn't work in sandboxed apps
        // Instead, collect system and app information that's accessible
        NSURL *logFile = [dir URLByAppendingPathComponent:@"diagnostic_info.txt"];

        NSMutableString *diagnosticInfo = [NSMutableString string];

        [diagnosticInfo appendString:@"═══════════════════════════════════════════════════════════\n"];
        [diagnosticInfo appendString:@"           DIAGNOSTIC INFORMATION\n"];
        [diagnosticInfo appendString:@"═══════════════════════════════════════════════════════════\n\n"];

        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        [diagnosticInfo appendFormat:@"Collection Time: %@\n\n", [dateFormatter stringFromDate:[NSDate date]]];

        // System Information
        [diagnosticInfo appendString:@"─────────────────────────────────────────────────────────\n"];
        [diagnosticInfo appendString:@"SYSTEM INFORMATION\n"];
        [diagnosticInfo appendString:@"─────────────────────────────────────────────────────────\n"];

        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        [diagnosticInfo appendFormat:@"macOS Version: %@\n", processInfo.operatingSystemVersionString];
        [diagnosticInfo appendFormat:@"Computer Name: %@\n", [[NSHost currentHost] localizedName]];
        [diagnosticInfo appendFormat:@"Processor Count: %lu cores\n", (unsigned long)processInfo.processorCount];
        [diagnosticInfo appendFormat:@"Physical Memory: %.2f GB\n", processInfo.physicalMemory / (1024.0 * 1024.0 * 1024.0)];
        [diagnosticInfo appendFormat:@"System Uptime: %.0f seconds (%.1f hours)\n",
                                      processInfo.systemUptime,
                                      processInfo.systemUptime / 3600.0];

        // Application Information
        [diagnosticInfo appendString:@"\n─────────────────────────────────────────────────────────\n"];
        [diagnosticInfo appendString:@"APPLICATION INFORMATION\n"];
        [diagnosticInfo appendString:@"─────────────────────────────────────────────────────────\n"];

        NSDictionary *appInfo = [[NSBundle mainBundle] infoDictionary];
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"Unknown";
        [diagnosticInfo appendFormat:@"Bundle ID: %@\n", bundleID];
        [diagnosticInfo appendFormat:@"App Name: %@\n", appInfo[@"CFBundleName"] ?: @"DiagnosticsTool"];
        [diagnosticInfo appendFormat:@"Version: %@\n", appInfo[@"CFBundleShortVersionString"] ?: @"1.0"];
        [diagnosticInfo appendFormat:@"Build: %@\n", appInfo[@"CFBundleVersion"] ?: @"1"];
        [diagnosticInfo appendFormat:@"Bundle Path: %@\n", [[NSBundle mainBundle] bundlePath]];

        // Process Information
        [diagnosticInfo appendString:@"\n─────────────────────────────────────────────────────────\n"];
        [diagnosticInfo appendString:@"PROCESS INFORMATION\n"];
        [diagnosticInfo appendString:@"─────────────────────────────────────────────────────────\n"];

        [diagnosticInfo appendFormat:@"Process ID: %d\n", [[NSProcessInfo processInfo] processIdentifier]];
        [diagnosticInfo appendFormat:@"Process Name: %@\n", [[NSProcessInfo processInfo] processName]];
        [diagnosticInfo appendFormat:@"Active Processor Count: %lu\n", (unsigned long)processInfo.activeProcessorCount];

        // Environment Variables (safe ones only)
        [diagnosticInfo appendString:@"\n─────────────────────────────────────────────────────────\n"];
        [diagnosticInfo appendString:@"ENVIRONMENT\n"];
        [diagnosticInfo appendString:@"─────────────────────────────────────────────────────────\n"];

        NSDictionary *env = [[NSProcessInfo processInfo] environment];
        NSArray *safeKeys = @[@"HOME", @"USER", @"SHELL", @"LANG", @"PATH"];
        for (NSString *key in safeKeys) {
            if (env[key]) {
                [diagnosticInfo appendFormat:@"%@: %@\n", key, env[key]];
            }
        }

        // Disk Information
        [diagnosticInfo appendString:@"\n─────────────────────────────────────────────────────────\n"];
        [diagnosticInfo appendString:@"DISK INFORMATION\n"];
        [diagnosticInfo appendString:@"─────────────────────────────────────────────────────────\n"];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *diskError = nil;
        NSDictionary *homeAttrs = [fileManager attributesOfFileSystemForPath:NSHomeDirectory() error:&diskError];
        if (homeAttrs) {
            NSNumber *freeSpace = homeAttrs[NSFileSystemFreeSize];
            NSNumber *totalSpace = homeAttrs[NSFileSystemSize];
            [diagnosticInfo appendFormat:@"Free Space: %.2f GB\n", [freeSpace doubleValue] / (1024.0 * 1024.0 * 1024.0)];
            [diagnosticInfo appendFormat:@"Total Space: %.2f GB\n", [totalSpace doubleValue] / (1024.0 * 1024.0 * 1024.0)];
            double usedPercent = 100.0 * (1.0 - ([freeSpace doubleValue] / [totalSpace doubleValue]));
            [diagnosticInfo appendFormat:@"Used: %.1f%%\n", usedPercent];
        }

        // Recent Console Logs (from this session)
        [diagnosticInfo appendString:@"\n─────────────────────────────────────────────────────────\n"];
        [diagnosticInfo appendString:@"APPLICATION LOGS (This Session)\n"];
        [diagnosticInfo appendString:@"─────────────────────────────────────────────────────────\n"];
        [diagnosticInfo appendString:@"Note: System log collection is restricted in sandboxed apps.\n"];
        [diagnosticInfo appendString:@"To view full logs, use Console.app and filter by process: DiagnosticsTool\n\n"];

        // Log some diagnostic events that will appear in Console.app
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "=== Diagnostic Bundle Collection Started ===");
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "System: macOS %s",
                        [processInfo.operatingSystemVersionString UTF8String]);
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "Memory: %.2f GB",
                        processInfo.physicalMemory / (1024.0 * 1024.0 * 1024.0));

        [diagnosticInfo appendString:@"✓ Logged diagnostic events to system console\n"];
        [diagnosticInfo appendString:@"✓ To view: Open Console.app → Filter for 'DiagnosticsTool'\n"];

        // Sentry Information
        [diagnosticInfo appendString:@"\n─────────────────────────────────────────────────────────\n"];
        [diagnosticInfo appendString:@"CRASH REPORTING\n"];
        [diagnosticInfo appendString:@"─────────────────────────────────────────────────────────\n"];
        [diagnosticInfo appendString:@"Sentry SDK: Enabled\n"];
        [diagnosticInfo appendString:@"Crash reports are automatically uploaded to Sentry\n"];
        [diagnosticInfo appendString:@"Breadcrumbs: Tracked for debugging context\n"];

        [diagnosticInfo appendString:@"\n═══════════════════════════════════════════════════════════\n"];
        [diagnosticInfo appendString:@"           End of Diagnostic Information\n"];
        [diagnosticInfo appendString:@"═══════════════════════════════════════════════════════════\n"];

        // Write diagnostic info to file
        [diagnosticInfo writeToURL:logFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "Diagnostic info collected: %lu bytes",
                        (unsigned long)[diagnosticInfo length]);

        // 2) Optional sysdiagnose - collect additional system information
        if (includeSys) {
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "Collecting extended system diagnostics...");
            [[LogCollector shared] info:@"Collecting extended system diagnostics"];

            // Create extended diagnostics file
            NSURL *extendedFile = [dir URLByAppendingPathComponent:@"extended_diagnostics.txt"];
            NSMutableString *extended = [NSMutableString string];

            [extended appendString:@"═══════════════════════════════════════════════════════════\n"];
            [extended appendString:@"           EXTENDED SYSTEM DIAGNOSTICS\n"];
            [extended appendString:@"═══════════════════════════════════════════════════════════\n\n"];

            // Process List
            [extended appendString:@"─────────────────────────────────────────────────────────\n"];
            [extended appendString:@"RUNNING PROCESSES\n"];
            [extended appendString:@"─────────────────────────────────────────────────────────\n"];
            NSTask *psTask = [NSTask new];
            psTask.launchPath = @"/bin/ps";
            psTask.arguments = @[@"aux"];
            NSPipe *psPipe = [NSPipe pipe];
            psTask.standardOutput = psPipe;
            @try {
                [psTask launch];
                [psTask waitUntilExit];
                NSData *psData = [[psPipe fileHandleForReading] readDataToEndOfFile];
                NSString *psOutput = [[NSString alloc] initWithData:psData encoding:NSUTF8StringEncoding];
                [extended appendString:psOutput ?: @"Failed to collect process list\n"];
            } @catch (NSException *e) {
                [extended appendFormat:@"Error collecting processes: %@\n", e.reason];
            }

            // Network Configuration
            [extended appendString:@"\n─────────────────────────────────────────────────────────\n"];
            [extended appendString:@"NETWORK CONFIGURATION\n"];
            [extended appendString:@"─────────────────────────────────────────────────────────\n"];
            NSTask *ifconfigTask = [NSTask new];
            ifconfigTask.launchPath = @"/sbin/ifconfig";
            ifconfigTask.arguments = @[@"-a"];
            NSPipe *ifconfigPipe = [NSPipe pipe];
            ifconfigTask.standardOutput = ifconfigPipe;
            @try {
                [ifconfigTask launch];
                [ifconfigTask waitUntilExit];
                NSData *ifconfigData = [[ifconfigPipe fileHandleForReading] readDataToEndOfFile];
                NSString *ifconfigOutput = [[NSString alloc] initWithData:ifconfigData encoding:NSUTF8StringEncoding];
                [extended appendString:ifconfigOutput ?: @"Failed to collect network config\n"];
            } @catch (NSException *e) {
                [extended appendFormat:@"Error collecting network config: %@\n", e.reason];
            }

            // System Profiler - Hardware
            [extended appendString:@"\n─────────────────────────────────────────────────────────\n"];
            [extended appendString:@"HARDWARE INFORMATION\n"];
            [extended appendString:@"─────────────────────────────────────────────────────────\n"];
            NSTask *hwTask = [NSTask new];
            hwTask.launchPath = @"/usr/sbin/system_profiler";
            hwTask.arguments = @[@"SPHardwareDataType"];
            NSPipe *hwPipe = [NSPipe pipe];
            hwTask.standardOutput = hwPipe;
            @try {
                [hwTask launch];
                [hwTask waitUntilExit];
                NSData *hwData = [[hwPipe fileHandleForReading] readDataToEndOfFile];
                NSString *hwOutput = [[NSString alloc] initWithData:hwData encoding:NSUTF8StringEncoding];
                [extended appendString:hwOutput ?: @"Failed to collect hardware info\n"];
            } @catch (NSException *e) {
                [extended appendFormat:@"Error collecting hardware info: %@\n", e.reason];
            }

            // System Profiler - Software
            [extended appendString:@"\n─────────────────────────────────────────────────────────\n"];
            [extended appendString:@"SOFTWARE INFORMATION\n"];
            [extended appendString:@"─────────────────────────────────────────────────────────\n"];
            NSTask *swTask = [NSTask new];
            swTask.launchPath = @"/usr/sbin/system_profiler";
            swTask.arguments = @[@"SPSoftwareDataType"];
            NSPipe *swPipe = [NSPipe pipe];
            swTask.standardOutput = swPipe;
            @try {
                [swTask launch];
                [swTask waitUntilExit];
                NSData *swData = [[swPipe fileHandleForReading] readDataToEndOfFile];
                NSString *swOutput = [[NSString alloc] initWithData:swData encoding:NSUTF8StringEncoding];
                [extended appendString:swOutput ?: @"Failed to collect software info\n"];
            } @catch (NSException *e) {
                [extended appendFormat:@"Error collecting software info: %@\n", e.reason];
            }

            // VM Statistics
            [extended appendString:@"\n─────────────────────────────────────────────────────────\n"];
            [extended appendString:@"VIRTUAL MEMORY STATISTICS\n"];
            [extended appendString:@"─────────────────────────────────────────────────────────\n"];
            NSTask *vmTask = [NSTask new];
            vmTask.launchPath = @"/usr/bin/vm_stat";
            NSPipe *vmPipe = [NSPipe pipe];
            vmTask.standardOutput = vmPipe;
            @try {
                [vmTask launch];
                [vmTask waitUntilExit];
                NSData *vmData = [[vmPipe fileHandleForReading] readDataToEndOfFile];
                NSString *vmOutput = [[NSString alloc] initWithData:vmData encoding:NSUTF8StringEncoding];
                [extended appendString:vmOutput ?: @"Failed to collect VM stats\n"];
            } @catch (NSException *e) {
                [extended appendFormat:@"Error collecting VM stats: %@\n", e.reason];
            }

            // Disk Usage
            [extended appendString:@"\n─────────────────────────────────────────────────────────\n"];
            [extended appendString:@"DISK USAGE\n"];
            [extended appendString:@"─────────────────────────────────────────────────────────\n"];
            NSTask *dfTask = [NSTask new];
            dfTask.launchPath = @"/bin/df";
            dfTask.arguments = @[@"-h"];
            NSPipe *dfPipe = [NSPipe pipe];
            dfTask.standardOutput = dfPipe;
            @try {
                [dfTask launch];
                [dfTask waitUntilExit];
                NSData *dfData = [[dfPipe fileHandleForReading] readDataToEndOfFile];
                NSString *dfOutput = [[NSString alloc] initWithData:dfData encoding:NSUTF8StringEncoding];
                [extended appendString:dfOutput ?: @"Failed to collect disk usage\n"];
            } @catch (NSException *e) {
                [extended appendFormat:@"Error collecting disk usage: %@\n", e.reason];
            }

            [extended appendString:@"\n═══════════════════════════════════════════════════════════\n"];
            [extended appendString:@"           End of Extended Diagnostics\n"];
            [extended appendString:@"═══════════════════════════════════════════════════════════\n"];

            [extended writeToURL:extendedFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "Extended diagnostics collected: %lu bytes",
                            (unsigned long)[extended length]);
            [[LogCollector shared] info:@"Extended diagnostics collection completed"];
        }

        // 3) Create simple README file
        NSMutableString *readme = [NSMutableString string];
        [readme appendString:@"═══════════════════════════════════════════════════════════\n"];
        [readme appendString:@"           DIAGNOSTICSTOOL - DIAGNOSTIC BUNDLE\n"];
        [readme appendString:@"═══════════════════════════════════════════════════════════\n\n"];

        [readme appendFormat:@"Generated: %@\n\n", [NSDate date]];

        [readme appendString:@"This diagnostic bundle contains:\n"];
        [readme appendString:@"  • application_logs.txt - Application logs from last 10 days\n"];
        [readme appendString:@"  • diagnostic_info.txt - System and application information\n"];
        if (includeSys) {
            [readme appendString:@"  • extended_diagnostics.txt - Detailed system diagnostics:\n"];
            [readme appendString:@"      - Running processes list\n"];
            [readme appendString:@"      - Network configuration (ifconfig)\n"];
            [readme appendString:@"      - Hardware information (system_profiler)\n"];
            [readme appendString:@"      - Software information\n"];
            [readme appendString:@"      - Virtual memory statistics\n"];
            [readme appendString:@"      - Disk usage information\n"];
        }
        [readme appendString:@"  • README.txt - This file\n"];

        [readme appendString:@"\n─────────────────────────────────────────────────────────\n"];
        [readme appendString:@"USAGE INSTRUCTIONS\n"];
        [readme appendString:@"─────────────────────────────────────────────────────────\n"];
        [readme appendString:@"To share this bundle:\n"];
        [readme appendString:@"  1. Email the entire ZIP file to support\n"];
        [readme appendString:@"  2. Or upload to your support ticket\n\n"];

        [readme appendString:@"Note on Logs:\n"];
        [readme appendString:@"  Due to sandboxing restrictions, this bundle contains system info\n"];
        [readme appendString:@"  rather than raw logs. For detailed logs, open Console.app and\n"];
        [readme appendString:@"  filter by process 'DiagnosticsTool' to view real-time logs.\n"];

        [readme appendString:@"\n═══════════════════════════════════════════════════════════\n"];

        NSURL *readmeFile = [dir URLByAppendingPathComponent:@"README.txt"];
        [readme writeToURL:readmeFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

        // 4) Zip the folder
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
        NSString *timestamp = [formatter stringFromDate:[NSDate date]];
        NSString *zipFilename = [NSString stringWithFormat:@"DiagnosticsTool_%@.zip", timestamp];

        NSURL *downloadsURL = [self desktopURL];
        if (!downloadsURL) {
            NSError *downloadsError = [NSError errorWithDomain:@"DiagnosticsTool"
                                                        code:-1
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Could not access Downloads folder"}];
            if (completion) completion(nil, downloadsError);
            return;
        }

        NSURL *finalZipURL = [downloadsURL URLByAppendingPathComponent:zipFilename];

        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "Creating ZIP at: %s", finalZipURL.path.UTF8String);

        // Create zip from temp directory to Desktop
        NSArray *zipArgs = @[@"-r", @"-q", finalZipURL.path, @"."];
        int rc2 = [self run:@"/usr/bin/zip" args:zipArgs cwd:dir.path];

        if (rc2 != 0) {
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "zip failed with code: %d", rc2);
            NSError *zipError = [NSError errorWithDomain:@"DiagnosticsTool"
                                                    code:rc2
                                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"ZIP creation failed with exit code %d", rc2]}];
            if (completion) completion(nil, zipError);
            return;
        }

        // Verify ZIP was created
        if (![fm fileExistsAtPath:finalZipURL.path]) {
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "ZIP file not found after creation");
            NSError *notFoundError = [NSError errorWithDomain:@"DiagnosticsTool"
                                                         code:-1
                                                     userInfo:@{NSLocalizedDescriptionKey: @"ZIP file was not created"}];
            if (completion) completion(nil, notFoundError);
            return;
        }

        // Get ZIP file size for logging
        NSDictionary *zipAttrs = [fm attributesOfItemAtPath:finalZipURL.path error:nil];
        unsigned long long zipSize = [zipAttrs[NSFileSize] unsignedLongLongValue];

        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "ZIP created successfully: %llu bytes", zipSize);

        // Clean up temp directory
        [fm removeItemAtURL:dir error:nil];

        // Success!
        if (completion) completion(finalZipURL, nil);
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
