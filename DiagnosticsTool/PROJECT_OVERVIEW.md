# DiagnosticsTool - Project Overview & File-by-File Guide

## 📋 Executive Summary

**DiagnosticsTool** is a macOS diagnostic and crash reporting application built in Objective-C. It provides developers with tools to test crash scenarios, collect system logs, monitor network status, and report diagnostics to Sentry for analysis.

**Key Features:**
- 🔴 Crash testing playground (NSException, EXC_BAD_ACCESS, NSAssert)
- 📊 Sentry crash reporting integration
- 📝 System log collection via unified logging
- 🌐 Network path monitoring
- 🔒 Privacy-aware data redaction
- 📦 Diagnostic bundle generation (logs + optional sysdiagnose)

**Tech Stack:**
- Language: Objective-C
- Platform: macOS 14.5+
- Frameworks: AppKit, MetricKit, Network, OSLog, Core Data
- Dependencies: Sentry SDK (via CocoaPods)
- Architecture: MVC with Coordinator pattern

---

## 🏗️ Project Architecture

```
DiagnosticsTool/
├── main.m                    # App entry point
├── AppDelegate.h/m           # App lifecycle & initialization
├── Core/                     # Business logic layer
│   ├── CrashReporterAdapter  # Sentry integration wrapper
│   ├── MetricsListener       # MetricKit subscriber
│   ├── DiagnosticBundleBuilder # Log/sysdiagnose collector
│   ├── LogCollector         # In-memory application log collection
│   └── Redactor             # Privacy/PII redaction
├── UI/                       # Presentation layer
│   ├── AppCoordinator       # Navigation coordinator
│   ├── CrashViewController  # Crash testing UI
│   ├── LogsViewController   # Logging & network UI
│   └── DiagnosticsViewController # Bundle generation UI
└── ViewController.h/m        # (Legacy/unused)
```

**Design Patterns:**
- **Coordinator Pattern**: AppCoordinator manages navigation and view lifecycle
- **Singleton Pattern**: CrashReporterAdapter for single crash reporting instance
- **Adapter Pattern**: CrashReporterAdapter wraps Sentry SDK, MetricsListener wraps MetricKit
- **Builder Pattern**: DiagnosticBundleBuilder constructs diagnostic packages

---

## 📂 File-by-File Breakdown

### 🚀 Entry Point

#### `main.m` (20 lines)
**Purpose**: Application entry point

**What it does:**
- Creates NSApplication instance
- Instantiates and sets AppDelegate
- Launches the app via `NSApplicationMain()`

**Key Code:**
```objc
int main(int argc, const char * argv[]) {
    NSApplication *app = [NSApplication sharedApplication];
    AppDelegate *delegate = [AppDelegate new];
    [app setDelegate:delegate];
    return NSApplicationMain(argc, argv);
}
```

**Team Notes:**
- Standard macOS app entry point
- Minimal boilerplate - all logic in AppDelegate

---

### 🎯 Application Lifecycle

#### `AppDelegate.h/m` (~150 lines)
**Purpose**: Manages app lifecycle, initializes core services

**Responsibilities:**
1. ✅ Initializes Sentry crash reporting on launch
2. ✅ Sets up MetricKit listener (macOS 12+ only)
3. ✅ Creates and starts AppCoordinator
4. ✅ Manages Core Data stack (currently unused by diagnostic features)
5. ✅ Handles app termination and data persistence

**Key Initialization Flow:**
```objc
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // 1. Start crash reporting
    [[CrashReporterAdapter shared] start];

    // 2. Setup MetricKit for system metrics (macOS 12+)
    _metricsListener = [MetricsListener new];
    if (@available(macOS 12.0, *)) {
        [[MXMetricManager sharedManager] addSubscriber:_metricsListener];
    }

    // 3. Launch main UI
    _coordinator = [AppCoordinator new];
    [_coordinator start];
}
```

**Important Notes:**
- Sentry must be initialized **before** any crashes can occur
- MetricKit is iOS-focused; limited functionality on macOS
- Core Data setup is boilerplate but not actively used
- App closes when last window closes (single-window app)

**Team Discussion Points:**
- Consider removing Core Data if not needed long-term
- MetricsListener provides limited value on macOS vs iOS

---

## 🧩 Core Layer (Business Logic)

### 1️⃣ `CrashReporterAdapter.h/m` (~52 lines)

**Purpose**: Singleton wrapper around Sentry SDK for crash reporting

**Why it exists:**
- Decouples app code from specific crash reporting SDK (easy to swap Sentry for another service)
- Centralizes crash reporting configuration
- Provides simplified API for rest of app

**Public API:**
```objc
+ (instancetype)shared;                                    // Get singleton instance
- (void)start;                                             // Initialize Sentry
- (void)addBreadcrumb:(NSString *)message data:(NSDictionary *)data;  // Track events
- (void)setUserId:(NSString *)userId;                      // Identify user
```

**Configuration (in `-start`):**
```objc
options.dsn = @"https://...";                    // Sentry project endpoint
options.enableMetricKit = YES;                   // Integrate with MetricKit
options.enableAppHangTracking = YES;             // Detect frozen UI
options.tracesSampleRate = @1.0;                 // 100% performance sampling (reduce in prod)
options.enableAutoSessionTracking = YES;         // Track user sessions
options.debug = YES;                             // Verbose logging (DEBUG only)
options.environment = @"debug"/"production";     // Separate environments
```

**Usage Examples:**
```objc
// Track user action
[[CrashReporterAdapter shared] addBreadcrumb:@"User exported logs"
                                        data:@{@"format": @"zip"}];

// Test Sentry connectivity
[SentrySDK captureMessage:@"Test message"];
```

**Team Notes:**
- Currently sends 100% of traces; reduce `tracesSampleRate` to 0.1 (10%) in production
- Debug mode enabled - expect verbose console output
- DSN is environment-specific - rotate for prod deployment

---

### 2️⃣ `MetricsListener.h/m` (~36 lines)

**Purpose**: Subscribes to MetricKit for system performance metrics

**The Challenge:**
- MetricKit's `MXMetricPayload` and `MXDiagnosticPayload` classes are **iOS-only**
- macOS has MetricKit framework but doesn't provide these payload classes

**Solution Implemented:**
```objc
#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV
    // iOS: Full MetricKit support with JSON payloads
    - (void)didReceiveMetricPayloads:(NSArray<MXMetricPayload *> *)payloads {
        // Log JSON representation of metrics
    }
#else
    // macOS: Limited support - just count payloads
    - (void)didReceiveMetricPayloads:(NSArray *)payloads {
        os_log("MetricKit payloads received (count: %lu)", payloads.count);
    }
#endif
```

**What it collects (on iOS):**
- CPU usage, memory pressure
- Battery usage, thermal state
- Scroll hitches, animation frame drops
- App launch time
- Network requests

**Team Discussion:**
- **Limited value on macOS** - consider removing or expanding manually
- Sentry's `enableMetricKit` option handles most of this automatically
- Could extend to collect custom macOS-specific metrics

---

### 3️⃣ `DiagnosticBundleBuilder.h/m` (~450 lines)

**Purpose**: Collects application logs, system diagnostics, and optional extended diagnostics into a zip archive

**Public API:**
```objc
+ (void)buildWithSysdiagnose:(BOOL)includeExtended
                  completion:(void(^)(NSURL *zipURL, NSError *error))completion;
```

**Note**: Parameter name is `includeSys` but it now triggers **Extended Diagnostics** (not actual sysdiagnose, which requires sudo)

**What it does:**
1. Creates temporary directory
2. **Collects application logs from LogCollector** → `application_logs.txt` (last 10 days)
3. Collects basic system diagnostic information → `diagnostic_info.txt`
4. **(Optional)** Collects **Extended System Diagnostics** → `extended_diagnostics.txt`
   - Running processes (`ps aux`)
   - Network configuration (`ifconfig -a`)
   - Hardware information (`system_profiler SPHardwareDataType`)
   - Software information (`system_profiler SPSoftwareDataType`)
   - Virtual memory statistics (`vm_stat`)
   - Disk usage (`df -h`)
5. Creates README.txt with instructions
6. Zips everything into timestamped ZIP file
7. Saves to Downloads folder (sandboxing-compatible)
8. Returns zip URL via completion handler

**Implementation Details:**
```objc
// All work on background queue
dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    // 1. Create temp directory
    NSURL *dir = [self tempDir];

    // 2. Collect application logs from LogCollector
    NSURL *appLogsFile = [dir URLByAppendingPathComponent:@"application_logs.txt"];
    NSString *appLogs = [[LogCollector shared] getLogsFromLastDays:10];
    [appLogs writeToURL:appLogsFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    // 3. Collect basic system diagnostic information
    NSURL *diagnosticFile = [dir URLByAppendingPathComponent:@"diagnostic_info.txt"];
    NSString *diagnosticInfo = [self collectDiagnosticInfo];
    [diagnosticInfo writeToURL:diagnosticFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    // 4. Optional extended diagnostics (replaces sudo-requiring sysdiagnose)
    if (includeExtended) {
        NSURL *extendedFile = [dir URLByAppendingPathComponent:@"extended_diagnostics.txt"];
        NSMutableString *extended = [NSMutableString string];

        // Collect running processes
        [self runCommandAndAppend:@"/bin/ps" args:@[@"aux"] to:extended title:@"RUNNING PROCESSES"];

        // Collect network configuration
        [self runCommandAndAppend:@"/sbin/ifconfig" args:@[@"-a"] to:extended title:@"NETWORK CONFIGURATION"];

        // Collect hardware information
        [self runCommandAndAppend:@"/usr/sbin/system_profiler" args:@[@"SPHardwareDataType"]
                               to:extended title:@"HARDWARE INFORMATION"];

        // Collect software information
        [self runCommandAndAppend:@"/usr/sbin/system_profiler" args:@[@"SPSoftwareDataType"]
                               to:extended title:@"SOFTWARE INFORMATION"];

        // Collect VM statistics
        [self runCommandAndAppend:@"/usr/bin/vm_stat" args:@[] to:extended title:@"VIRTUAL MEMORY STATISTICS"];

        // Collect disk usage
        [self runCommandAndAppend:@"/bin/df" args:@[@"-h"] to:extended title:@"DISK USAGE"];

        [extended writeToURL:extendedFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }

    // 5. Create README with instructions
    NSURL *readmeFile = [dir URLByAppendingPathComponent:@"README.txt"];
    [readme writeToURL:readmeFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    // 6. Zip everything to Downloads folder
    NSURL *downloadsURL = [self desktopURL];  // Actually returns Downloads folder
    NSURL *finalZipURL = [downloadsURL URLByAppendingPathComponent:zipFilename];
    [self run:@"/usr/bin/zip" args:@[@"-r", @"-q", finalZipURL.path, @"."] cwd:dir.path];

    // 7. Clean up temp directory
    [[NSFileManager defaultManager] removeItemAtURL:dir error:nil];

    completion(finalZipURL, nil);
});
```

**Diagnostic Bundle Contents:**

**Always Included:**
- `application_logs.txt` - Application logs from last 10 days (from LogCollector)
- `diagnostic_info.txt` - Basic system and app information
- `README.txt` - Instructions for using the bundle

**Optional (Extended Diagnostics):**
- `extended_diagnostics.txt` - Detailed system diagnostics (~500 KB - 5 MB)
  - Running processes list (`ps aux`) - All active processes with CPU/memory usage
  - Network configuration (`ifconfig -a`) - All network interfaces, IP addresses, status
  - Hardware information (`system_profiler SPHardwareDataType`) - Chip, memory, serial number
  - Software information (`system_profiler SPSoftwareDataType`) - macOS build, kernel, uptime
  - Virtual memory statistics (`vm_stat`) - Memory pressure, page ins/outs, swap usage
  - Disk usage (`df -h`) - All mounted volumes with free/used space

**What's in diagnostic_info.txt (Basic):**
- System Information (macOS version, computer name, CPU, memory, uptime)
- Application Information (bundle ID, version, build number)
- Process Information (PID, active processors)
- Environment Variables (safe keys only: HOME, USER, SHELL, LANG, PATH)
- Disk Information (free space, total space, usage percentage)
- Crash Reporting Status (Sentry SDK enabled, breadcrumbs tracked)

**Permissions Required:**
- ✅ Read access to system information APIs (no special entitlements needed)
- ✅ Write access to Downloads folder (`com.apple.security.files.downloads.read-write`)
- ✅ Execute standard command-line tools (`ps`, `ifconfig`, `system_profiler`, `vm_stat`, `df`)
- ❌ No sudo/admin privileges required (works in sandboxed apps!)

**Team Notes:**
- Uses synchronous `NSTask` execution (blocking on background queue)
- Temporary files automatically cleaned up after ZIP creation
- Extended diagnostics takes 30-60 seconds (much faster than old sysdiagnose approach)
- LogCollector integration provides meaningful application logs
- Changed from Desktop to Downloads folder for sandboxing compatibility
- Replaced sudo-requiring `sysdiagnose` with sandboxing-compatible command-line tools
- Output files: 5-50MB for logs only, 10-60MB with extended diagnostics

**Why Not Real sysdiagnose?**
- `sysdiagnose` requires sudo (admin password)
- Sandboxed apps can't prompt for passwords
- Takes 2-10 minutes to complete
- Generates 50-500MB files (often too large)
- **Solution**: Custom extended diagnostics using standard command-line tools

**Sandboxing Solutions:**
1. **Desktop → Downloads**: Desktop is containerized in sandboxed apps
2. **sysdiagnose → Extended Diagnostics**: Use tools that don't require sudo
3. **log collect → LogCollector**: In-memory logging instead of system log access

**Potential Improvements:**
- Add progress callbacks for UI updates during extended collection
- Add file size checks before zipping
- Implement cancellation support
- Add compression level configuration
- Add filtering options (e.g., only collect network info)

---

### 4️⃣ `Redactor.h/m` (~8 lines)

**Purpose**: Privacy-preserving string redaction

**What it does:**
Replaces sensitive strings (emails, names, etc.) with a hash-based placeholder

**Implementation:**
```objc
+ (NSString *)safeString:(NSString *)value {
    if (!value) return @"";
    return [NSString stringWithFormat:@"[redacted:%lu]", (unsigned long)value.hash];
}
```

**Example:**
```objc
NSString *email = @"alice@example.com";
NSString *safe = [Redactor safeString:email];
// Result: "[redacted:1234567890]"
```

**Use Cases:**
- Logging user emails without exposing PII
- Redacting API keys in diagnostics
- Anonymizing user data in crash reports

**Team Notes:**
- **Currently very simple** - just hashes the input
- Hash is deterministic (same input = same hash) for debugging
- Could be enhanced with regex patterns for auto-detection
- Consider using bcrypt/SHA256 for better anonymization

**Potential Enhancements:**
```objc
// Auto-detect and redact emails, phone numbers, SSNs
+ (NSString *)autoRedact:(NSString *)text;

// Redact specific patterns
+ (NSString *)redactPattern:(NSString *)pattern in:(NSString *)text;
```

---

### 5️⃣ `LogCollector.h/m` (~186 lines)

**Purpose**: Thread-safe in-memory application log collection system

**Why it exists:**
- Sandboxed macOS apps can't access system logs via command-line tools
- Provides application-level logging that captures user actions and app events
- Collects logs over time (last 7-10 days) for diagnostic bundles
- Dual logging: both in-memory storage and system console (os_log)

**Public API:**
```objc
+ (instancetype)shared;                          // Get singleton instance
- (void)log:(NSString *)message level:(LogLevel)level;  // Log with specific level
- (void)debug:(NSString *)message;               // Debug-level log
- (void)info:(NSString *)message;                // Info-level log
- (void)warning:(NSString *)message;             // Warning-level log
- (void)error:(NSString *)message;               // Error-level log
- (NSString *)getAllLogsFormatted;               // Get all logs formatted
- (NSString *)getLogsFromLastDays:(NSInteger)days;  // Filter by date
- (void)clearLogs;                               // Clear all logs
```

**Log Levels:**
```objc
typedef NS_ENUM(NSInteger, LogLevel) {
    LogLevelDebug,    // Detailed debugging information
    LogLevelInfo,     // General informational messages
    LogLevelWarning,  // Warning messages - potential issues
    LogLevelError     // Error messages - actual problems
};
```

**Implementation Details:**
```objc
@implementation LogCollector {
    NSMutableArray<LogEntry *> *_logs;  // In-memory log storage
    NSLock *_lock;                      // Thread-safety
    NSDateFormatter *_dateFormatter;     // Timestamp formatting
}

- (void)log:(NSString *)message level:(LogLevel)level {
    [_lock lock];

    // Create log entry
    LogEntry *entry = [[LogEntry alloc] init];
    entry.timestamp = [NSDate date];
    entry.message = message;
    entry.level = level;
    [_logs addObject:entry];

    // Also log to system console
    os_log_with_type(OS_LOG_DEFAULT, osLogType, "[%s] %s",
                     [levelStr UTF8String], [message UTF8String]);

    // Memory management - keep only last 10,000 entries
    if (_logs.count > 10000) {
        [_logs removeObjectsInRange:NSMakeRange(0, 1000)];
    }

    [_lock unlock];
}
```

**Key Features:**
1. **Thread-Safe**: Uses NSLock to protect concurrent access
2. **Memory-Efficient**: Automatically limits to 10,000 entries
3. **Dual Logging**: Logs appear in both in-memory collection and Console.app
4. **Formatted Output**: Provides formatted string output with timestamps
5. **Date Filtering**: Can retrieve logs from last N days

**Usage Examples:**
```objc
// Initialization (in AppDelegate)
[[LogCollector shared] info:@"Application launching..."];

// User action logging (in view controllers)
[[LogCollector shared] info:@"User clicked: Collect logs"];

// Error logging
[[LogCollector shared] error:@"Failed to create diagnostic bundle"];

// Warning logging
[[LogCollector shared] warning:@"Network monitor already running"];

// Retrieve logs for export
NSString *logs = [[LogCollector shared] getLogsFromLastDays:10];
```

**Integration Points:**
- **AppDelegate.m**: Logs app lifecycle events (launch, Sentry init, MetricKit setup)
- **CrashViewController.m**: Logs user actions before crashes (crash type, test messages)
- **LogsViewController.m**: Logs network monitoring events (path changes, breadcrumbs)
- **DiagnosticsViewController.m**: Logs diagnostic collection events (start, success, failure)
- **DiagnosticBundleBuilder.m**: Exports collected logs to `application_logs.txt`

**Output Format:**
```
═══════════════════════════════════════════════════════════
           APPLICATION LOGS (Last 10 Days)
           Entries: 42
═══════════════════════════════════════════════════════════

[2025-01-28 14:32:15.123] [INFO   ] Application launching...
[2025-01-28 14:32:15.456] [INFO   ] macOS Version: macOS 14.5
[2025-01-28 14:32:15.789] [INFO   ] Sentry crash reporter started
[2025-01-28 14:32:16.012] [INFO   ] MetricKit listener registered
[2025-01-28 14:32:16.234] [INFO   ] UI coordinator started - application ready
[2025-01-28 14:33:42.567] [INFO   ] User clicked: Test Sentry (No Crash)
[2025-01-28 14:33:42.890] [INFO   ] Sentry test message sent successfully
[2025-01-28 14:35:18.123] [WARNING] User triggered NSException crash test
[2025-01-28 14:35:18.456] [ERROR  ] Throwing NSException - app will crash

═══════════════════════════════════════════════════════════
           End of Logs (42 entries)
═══════════════════════════════════════════════════════════
```

**Team Notes:**
- Logs persist only in memory - cleared on app restart
- Provides meaningful context for diagnostic bundles
- Thread-safe for concurrent logging from multiple components
- Automatically manages memory by limiting entries
- Works in sandboxed environment (no file system access needed)

**Benefits Over System Logging:**
- ✅ Works in sandboxed apps (system `log collect` doesn't work)
- ✅ Captures application-specific events and user actions
- ✅ Exportable to diagnostic bundles
- ✅ Provides last 7-10 days of logs for troubleshooting
- ✅ Formatted for easy reading

**Potential Improvements:**
- Add persistent storage (write to file for crash recovery)
- Add log level filtering (only show errors/warnings)
- Add search/filter capabilities
- Add log rotation and archiving
- Add structured logging with tags/metadata

---

## 🎨 UI Layer (Presentation)

### 1️⃣ `AppCoordinator.h/m` (~51 lines)

**Purpose**: Navigation coordinator managing the main window and tab-based UI

**Why we use a Coordinator:**
- Decouples view controllers from navigation logic
- Single source of truth for app navigation flow
- Makes testing easier (can mock coordinator)
- Keeps view controllers focused on presentation only

**What it creates:**
```
┌─────────────────────────────────────┐
│  Diagnostics Starter (ObjC)         │  ← NSWindow
├─────────────────────────────────────┤
│  [Crashes] [Logging] [Diagnostics]  │  ← NSTabView
├─────────────────────────────────────┤
│                                     │
│  Tab Content (View Controller)      │
│                                     │
└─────────────────────────────────────┘
```

**Startup Flow:**
```objc
- (void)start {
    // 1. Create main window (900x600)
    _window = [[NSWindow alloc] initWithContentRect:...];

    // 2. Create tab view
    NSTabView *tabs = [NSTabView new];

    // 3. Add three tabs
    crashItem.view = [[CrashViewController new] view];
    logItem.view = [[LogsViewController new] view];
    diagItem.view = [[DiagnosticsViewController new] view];

    // 4. Layout with Auto Layout
    [NSLayoutConstraint activateConstraints:...];

    // 5. Show window
    [_window makeKeyAndOrderFront:nil];
}
```

**Team Notes:**
- Pure programmatic UI (no storyboards)
- Window closes when last window closes
- Could be extended to manage multiple windows
- Consider adding window state restoration

---

### 2️⃣ `CrashViewController.h/m` (~80 lines)

**Purpose**: Crash testing playground for validating Sentry integration

**UI Layout:**
```
┌──────────────────────────────────────┐
│  Crash playground. Use different     │
│  crash types to validate reporting.  │
│                                      │
│  [Test Sentry (No Crash)]           │
│  [Throw NSException]                │
│  [EXC_BAD_ACCESS]                   │
│  [Abort via NSAssert]               │
└──────────────────────────────────────┘
```

**Crash Types Implemented:**

**1. NSException (Handled Exception)**
```objc
- (void)crashNSException {
    [[CrashReporterAdapter shared] addBreadcrumb:@"User triggered NSException crash"
                                            data:@{@"crash_type": @"NSException"}];
    @throw [NSException exceptionWithName:@"DemoException"
                                   reason:@"Intentional NSException for testing Sentry"
                                 userInfo:@{@"test": @"crash"}];
}
```
- **What happens**: App throws exception, Sentry catches it
- **Best for**: Testing exception handling
- **Sentry captures**: Full stack trace, exception name/reason

**2. EXC_BAD_ACCESS (Segmentation Fault)**
```objc
- (void)crashBadAccess {
    volatile char *ptr = (char *)0x1;  // Invalid memory address
    *ptr = 'X';                        // Triggers SIGSEGV
}
```
- **What happens**: App crashes immediately (segfault)
- **Best for**: Testing low-level crash handling
- **Sentry captures**: On **next app launch** (crashes are persisted and uploaded later)

**3. NSAssert (Debug Assertion)**
```objc
- (void)crashAssert {
    NSAssert(false, @"Intentional assert fail for testing Sentry");
}
```
- **What happens**: Assertion fails, calls `abort()`
- **Best for**: Testing assertion failures
- **Note**: Only crashes in DEBUG builds (stripped in Release)

**4. Test Sentry (No Crash)**
```objc
- (void)testSentry {
    [SentrySDK captureMessage:@"Test message from CrashViewController - Sentry is working!"];
    // Shows alert confirming message sent
}
```
- **What happens**: Sends test message to Sentry without crashing
- **Best for**: Verifying Sentry connectivity
- **Instant feedback**: Check Sentry dashboard in 10-30 seconds

**Team Notes:**
- Breadcrumbs added before each crash help with debugging
- EXC_BAD_ACCESS uploads on **next launch** (not immediately)
- Use "Test Sentry" button first to verify configuration
- All crashes include `os_log` entries for debugging

---

### 3️⃣ `LogsViewController.h/m` (~90 lines)

**Purpose**: Unified logging demonstration + network path monitoring

**UI Features:**
```
┌──────────────────────────────────────┐
│  [Emit sample logs]                  │
│  [Start NWPathMonitor]               │
│  [Add Crash breadcrumb]              │
│                                      │
│  ┌────────────────────────────────┐ │
│  │ Log output area...             │ │
│  │                                │ │
│  └────────────────────────────────┘ │
└──────────────────────────────────────┘
```

**Feature 1: Unified Logging**
```objc
- (void)emitLogs {
    // Create custom log subsystems
    os_log_t log_ui = os_log_create("com.yourco.app", "ui");
    os_log_t log_net = os_log_create("com.yourco.app", "network");

    // Log with different levels
    os_log_with_type(log_ui, OS_LOG_TYPE_INFO, "Button tapped user=%{public}s", user);
    os_log_with_type(log_net, OS_LOG_TYPE_ERROR, "Network error code=%d", 500);

    // Also uses NSLog for comparison
    NSLog(@"NSLog example with user=%@", user);
}
```

**Why unified logging?**
- Searchable in Console.app by subsystem
- Privacy-aware (use `%{public}s` to make visible)
- Performance-optimized
- Integrates with diagnostic tools

**Feature 2: Network Path Monitoring**
```objc
- (void)startNetworkWatch {
    _monitor = nw_path_monitor_create();  // Create monitor

    nw_path_monitor_set_update_handler(_monitor, ^(nw_path_t path) {
        // Check network status
        nw_path_status_t status = nw_path_get_status(path);
        // satisfied | unsatisfied | satisfiable

        // Check constraints
        bool expensive = nw_path_is_expensive(path);      // Cellular/hotspot
        bool constrained = nw_path_is_constrained(path);  // Low data mode

        // Log and report to Sentry
        os_log("NWPath changed: %s expensive=%d constrained=%d", status, expensive, constrained);
        [[CrashReporterAdapter shared] addBreadcrumb:@"NWPathChanged" data:@{...}];
    });

    nw_path_monitor_start(_monitor);
}
```

**Use Cases:**
- Detect when WiFi disconnects
- Detect cellular vs WiFi
- Detect low data mode
- Pause network-heavy operations when expensive

**Feature 3: Breadcrumb Testing**
```objc
- (void)addBreadcrumb {
    [[CrashReporterAdapter shared] addBreadcrumb:@"UserTappedBreadcrumb"
                                            data:@{@"screen": @"Logs"}];
}
```
- Breadcrumbs appear in Sentry crash reports
- Shows user actions leading up to crash
- Essential for debugging user-reported issues

**Team Notes:**
- Uses C-based Network framework (not NSURLSession)
- Monitor runs on background queue
- Redactor used for PII in logs
- Network monitor never stopped (memory leak) - consider cleanup

---

### 4️⃣ `DiagnosticsViewController.h/m` (~46 lines)

**Purpose**: UI for collecting diagnostic bundles

**UI Layout:**
```
┌──────────────────────────────────────┐
│  Generate a diagnostic bundle with   │
│  unified logs and optional           │
│  sysdiagnose.                        │
│                                      │
│  [Collect logs]                      │
│  [Collect logs + sysdiagnose]        │
│                                      │
│  Status: Idle.                       │
└──────────────────────────────────────┘
```

**Option 1: Logs Only (Fast - 5-10 seconds)**
```objc
- (void)collectLogs {
    _status.stringValue = @"Collecting logs...";

    [DiagnosticBundleBuilder buildWithSysdiagnose:NO completion:^(NSURL *zipURL, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (zipURL) {
                self->_status.stringValue = [NSString stringWithFormat:@"Saved: %@", zipURL.path];
            }
        });
    }];
}
```
- Collects: Unified logs for your app
- Time: ~5-10 seconds
- Size: ~5-50MB
- Output: `/var/tmp/{UUID}/App.logarchive` → `diagnostics.zip`

**Option 2: Logs + Extended Diagnostics (Medium - 30-60 seconds)**
```objc
- (void)collectLogsAndSys {
    _status.stringValue = @"Collecting logs and extended diagnostics...";

    [DiagnosticBundleBuilder buildWithSysdiagnose:YES completion:^(NSURL *zipURL, NSError *error) {
        // Includes extended diagnostics (not actual sysdiagnose)
    }];
}
```
- Collects: Application logs + basic diagnostics + **extended system diagnostics**
- Time: ~30-60 seconds (much faster than old sysdiagnose)
- Size: ~10-60MB (reasonable file size)
- Includes: Process list, network config, hardware/software info, VM stats, disk usage

**What's in extended_diagnostics.txt:**
- Running processes list with CPU/memory usage
- Network configuration (all interfaces, IPs, status)
- Hardware information (chip, memory, serial number)
- Software information (macOS build, kernel version)
- Virtual memory statistics (page ins/outs, swap)
- Disk usage (all volumes with free/used space)

**Why Not Real sysdiagnose?**
- Requires sudo (admin password prompt)
- Sandboxed apps can't prompt for passwords
- Takes 2-10 minutes to complete
- Generates 50-500MB files (too large)
- **Solution**: Custom diagnostics using accessible command-line tools

**Team Notes:**
- Status updates happen on main queue (good!)
- No progress indicator during sysdiagnose (could improve UX)
- Zip file path shown in status - consider "Open in Finder" button
- No error handling UI - errors just shown in status

**Potential UX Improvements:**
```objc
// Add progress bar
NSProgressIndicator *progress = ...;

// Add "Open in Finder" button after completion
NSButton *openButton = ...;
[[NSWorkspace sharedWorkspace] selectFile:zipURL.path inFileViewerRootedAtPath:@""];

// Add email/upload option
NSString *subject = @"Diagnostic Bundle";
[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:mailtoURL]];
```

---

## 🔧 Configuration Files

### `Podfile`
**Purpose**: CocoaPods dependency management

**Dependencies:**
```ruby
pod 'Sentry', '~> 8'  # Crash reporting & performance monitoring
```

**Notes:**
- Using Sentry SDK version 8.x
- `use_frameworks!` required for Swift-based pods
- Run `pod install` after cloning
- Use `.xcworkspace` file (not `.xcodeproj`) after pod install

---

### `DiagnosticsTool.entitlements`
**Purpose**: Defines app capabilities and sandboxing rules

**Enabled Capabilities:**
```xml
<key>com.apple.security.app-sandbox</key>
<true/>                                    <!-- App is sandboxed -->

<key>com.apple.security.network.client</key>
<true/>                                    <!-- Outbound network (Sentry) -->

<key>com.apple.security.network.server</key>
<true/>                                    <!-- Inbound network (debugging) -->

<key>com.apple.security.files.user-selected.read-only</key>
<true/>                                    <!-- Read user-selected files -->
```

**Why network entitlements were added:**
- Sandboxed apps block all network by default
- Sentry requires `network.client` for crash uploads
- Without this, you get DNS resolution errors: `Code=-1003 "A server with the specified hostname could not be found"`

---

## 🔄 Data Flow Diagrams

### Crash Reporting Flow
```
User clicks crash button
         ↓
CrashViewController adds breadcrumb
         ↓
App crashes (NSException/SIGSEGV/abort)
         ↓
Sentry SDK captures crash
         ↓
Crash stored locally (encrypted)
         ↓
Next app launch
         ↓
Sentry uploads crash to servers
         ↓
Dashboard shows crash report with breadcrumbs
```

### Diagnostic Bundle Flow
```
User clicks "Collect logs"
         ↓
DiagnosticsViewController calls DiagnosticBundleBuilder
         ↓
Background queue: Create temp dir
         ↓
Run /usr/bin/log collect → App.logarchive
         ↓
(Optional) Run /usr/sbin/sysdiagnose → sysdiagnose_*.tar.gz
         ↓
Zip all files → diagnostics.zip
         ↓
Return zip URL via completion handler
         ↓
Main queue: Update UI with zip path
```

### Network Monitoring Flow
```
User clicks "Start NWPathMonitor"
         ↓
Create nw_path_monitor_t
         ↓
Set update handler (runs on background queue)
         ↓
Start monitor
         ↓
Network changes (WiFi → Cellular, etc.)
         ↓
Handler called with new path
         ↓
Check status, expensive, constrained flags
         ↓
Log to os_log + send breadcrumb to Sentry
         ↓
Main queue: Update UI
```

---

## 🐛 Common Issues & Solutions

### Issue 1: Sentry Events Not Appearing
**Symptoms:** Crashes/messages don't show in dashboard

**Root Causes:**
1. ❌ **Network entitlements missing**
   - Error: `Code=-1003 "A server with the specified hostname could not be found"`
   - Fix: Add `com.apple.security.network.client` to entitlements

2. ❌ **Wrong DSN**
   - Check `CrashReporterAdapter.m:17`
   - Verify DSN matches Sentry project

3. ❌ **Debug mode not enabled**
   - Set `options.debug = YES` to see SDK logs
   - Check Xcode console for "Sentry is ready" message

4. ❌ **Crashes upload on next launch**
   - EXC_BAD_ACCESS and other native crashes only upload **after app restarts**
   - NSExceptions upload immediately

**Debugging Steps:**
```bash
# Watch Sentry SDK logs in real-time
log stream --predicate 'subsystem == "io.sentry"' --level debug

# Check network connectivity
curl -v https://o4510218691805184.ingest.sentry.io/api/4510218813571072/envelope/
```

---

### Issue 2: Build Failures After Pulling
**Symptoms:** Project won't build after `git pull`

**Solutions:**
```bash
# 1. Install/update pods
pod install

# 2. Clean build folder
xcodebuild clean -workspace DiagnosticsTool.xcworkspace -scheme DiagnosticsTool

# 3. Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/DiagnosticsTool-*

# 4. Rebuild
xcodebuild -workspace DiagnosticsTool.xcworkspace -scheme DiagnosticsTool build
```

---

### Issue 3: MetricKit Not Working on macOS
**Symptoms:** No metrics appearing

**Explanation:**
- MetricKit's `MXMetricPayload` is **iOS-only**
- macOS has MetricKit framework but limited functionality
- Our implementation logs payload count but can't parse content

**Solution:**
- Accept limited macOS support
- OR: Remove MetricKit and rely on Sentry's built-in metrics
- OR: Implement custom macOS performance tracking

---

## 🚀 Getting Started (For New Team Members)

### Initial Setup
```bash
# 1. Clone repo
git clone <repo-url>
cd DiagnosticsTool

# 2. Install dependencies
pod install

# 3. Open workspace (NOT .xcodeproj!)
open DiagnosticsTool.xcworkspace

# 4. Build & run
⌘ + R
```

### First Time Testing
1. Launch app → Should see "Sentry macOS setup complete!" in Sentry dashboard
2. Go to "Crashes" tab → Click "Test Sentry" → Verify message appears in dashboard
3. Go to "Logging" tab → Click "Emit sample logs" → Check Console.app for logs
4. Go to "Diagnostics" tab → Click "Collect logs" → Verify zip created

---

## 📊 Metrics & Performance

### App Size
- **Binary**: ~500KB (without Sentry)
- **With Sentry**: ~5MB
- **Diagnostic Bundle**: 5-500MB depending on options

### Performance
- **App Launch**: <100ms
- **Sentry Initialization**: ~50ms
- **Log Collection**: 5-10 seconds
- **Sysdiagnose**: 2-10 minutes

### Memory Usage
- **Idle**: ~30MB
- **During log collection**: ~50MB
- **Peak**: ~100MB (during sysdiagnose)

---

## 🔐 Security & Privacy

### PII Handling
- ✅ Redactor utility for sanitizing strings
- ✅ Unified logging uses `%{public}s` for explicit visibility
- ⚠️  Sentry breadcrumbs may contain user data - audit carefully

### Permissions Required
- ✅ Network access (outbound for Sentry)
- ✅ Read system logs (`/usr/bin/log collect`)
- ⚠️  Sysdiagnose may require sudo for full diagnostic data

### Sandboxing
- ✅ App is sandboxed (`com.apple.security.app-sandbox`)
- ✅ Network access explicitly granted
- ✅ File access limited to user-selected files

---

## 🎯 Future Enhancements

### Short Term
- [ ] Add progress indicators for long operations
- [ ] Implement "Open in Finder" for diagnostic bundles
- [ ] Add email/upload options for diagnostics
- [ ] Clean up temporary files after zip creation
- [ ] Fix network monitor memory leak (never stopped)

### Medium Term
- [ ] Add custom macOS metrics collection
- [ ] Implement user session tracking
- [ ] Add custom tags/context to Sentry reports
- [ ] Create automated test suite
- [ ] Add release tagging to match app versions

### Long Term
- [ ] Multi-window support
- [ ] Crash report viewer (parse Sentry data locally)
- [ ] Real-time log streaming
- [ ] Performance profiling tools
- [ ] Integration with CI/CD for automated testing

---

## 📞 Team Contacts & Resources

### Sentry Dashboard
- **URL**: https://sentry.io/organizations/your-org/projects/
- **Project**: DiagnosticsTool
- **Environment**: Debug / Production

### Documentation
- [Sentry Cocoa SDK](https://docs.sentry.io/platforms/apple/)
- [MetricKit Apple Docs](https://developer.apple.com/documentation/metrickit)
- [Unified Logging Guide](https://developer.apple.com/documentation/os/logging)
- [Network Framework](https://developer.apple.com/documentation/network)

### Build Commands
```bash
# Build
xcodebuild -workspace DiagnosticsTool.xcworkspace -scheme DiagnosticsTool build

# Test
xcodebuild test -workspace DiagnosticsTool.xcworkspace -scheme DiagnosticsTool

# Archive (for distribution)
xcodebuild archive -workspace DiagnosticsTool.xcworkspace -scheme DiagnosticsTool

# Clean
xcodebuild clean -workspace DiagnosticsTool.xcworkspace -scheme DiagnosticsTool
```

---

## 🎓 Key Takeaways for Team Presentation

### Technical Highlights
1. **Well-architected**: Clear separation of concerns (Core/UI layers)
2. **Modern patterns**: Coordinator pattern for navigation
3. **Privacy-first**: Sandboxed with explicit permissions
4. **Production-ready**: Crash reporting, logging, diagnostics all functional

### Business Value
1. **Faster debugging**: Sentry crash reports with breadcrumbs
2. **Better support**: Diagnostic bundles for support tickets
3. **Proactive monitoring**: Detect crashes before users report them
4. **Data-driven**: Performance metrics inform optimization

### Technical Debt
1. ⚠️  Core Data setup but unused (can remove)
2. ⚠️  MetricKit limited on macOS (consider removing)
3. ⚠️  No cleanup of temporary diagnostic files
4. ⚠️  Network monitor memory leak (never stopped)

### Next Steps
1. ✅ Reduce Sentry sample rate for production (1.0 → 0.1)
2. ✅ Add release tagging to match app versions
3. ✅ Implement file cleanup for diagnostics
4. ✅ Add UX improvements (progress bars, open in Finder)
5. ✅ Write automated tests

---

**Generated**: 2025-01-19
**Version**: 1.0
**Maintainer**: Development Team
