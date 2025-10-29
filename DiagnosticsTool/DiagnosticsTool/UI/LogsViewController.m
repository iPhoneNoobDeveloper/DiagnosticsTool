#import "LogsViewController.h"
#import <os/log.h>
#import <Network/Network.h>
#import "Redactor.h"
#import "CrashReporterAdapter.h"
#import "LogCollector.h"

static os_log_t log_ui;
static os_log_t log_net;

@implementation LogsViewController {
    NSTextView *_logText;
    nw_path_monitor_t _monitor;
}

- (void)loadView {
    NSView *v = [NSView new];
    self.view = v;

    log_ui = os_log_create("com.yourco.app", "ui");
    log_net = os_log_create("com.yourco.app", "network");

    NSButton *btnLog = [NSButton buttonWithTitle:@"Emit sample logs" target:self action:@selector(emitLogs)];
    NSButton *btnNetwork = [NSButton buttonWithTitle:@"Start NWPathMonitor" target:self action:@selector(startNetworkWatch)];
    NSButton *btnBreadcrumb = [NSButton buttonWithTitle:@"Add Crash breadcrumb" target:self action:@selector(addBreadcrumb)];

    _logText = [NSTextView new];
    _logText.editable = NO;
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.hasVerticalScroller = YES; scroll.documentView = _logText; scroll.translatesAutoresizingMaskIntoConstraints = NO;

    NSStackView *row = [NSStackView stackViewWithViews:@[btnLog, btnNetwork, btnBreadcrumb]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal; row.spacing = 12; row.translatesAutoresizingMaskIntoConstraints = NO;

    [v addSubview:row];
    [v addSubview:scroll];

    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:v.topAnchor constant:16],
        [row.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16],
        [scroll.topAnchor constraintEqualToAnchor:row.bottomAnchor constant:12],
        [scroll.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:12],
        [scroll.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-12],
        [scroll.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-12]
    ]];
}

- (void)append:(NSString *)line {
    _logText.string = [_logText.string stringByAppendingFormat:@"%@\n", line];
}

- (void)emitLogs {
    [[LogCollector shared] info:@"User clicked: Emit sample logs"];
    NSString *user = [Redactor safeString:@"alice@example.com"];
    os_log_with_type(log_ui, OS_LOG_TYPE_INFO, "Button tapped user=%{public}s", user.UTF8String);
    os_log_with_type(log_net, OS_LOG_TYPE_ERROR, "Network error code=%d", 500);
    NSLog(@"NSLog example with user=%@", user);
    [[LogCollector shared] info:@"Sample logs emitted to system console"];
    [self append:@"Emitted a few logs. Check Console.app under subsystem com.yourco.app."];
}

- (void)startNetworkWatch {
    if (_monitor) {
        [[LogCollector shared] warning:@"User tried to start network monitor but it's already running"];
        return;
    }
    [[LogCollector shared] info:@"User clicked: Start NWPathMonitor"];
    _monitor = nw_path_monitor_create();
    __weak typeof(self) weakSelf = self;
    nw_path_monitor_set_update_handler(_monitor, ^(nw_path_t path) {
        NSString *status = @"unknown";
        nw_path_status_t pathStatus = nw_path_get_status(path);
        switch (pathStatus) {
            case nw_path_status_satisfied: status = @"satisfied"; break;
            case nw_path_status_unsatisfied: status = @"unsatisfied"; break;
            case nw_path_status_satisfiable: status = @"satisfiable"; break;
            default: status = @"invalid"; break;
        }
        bool expensive = nw_path_is_expensive(path);
        bool constrained = nw_path_is_constrained(path);
        [[LogCollector shared] info:[NSString stringWithFormat:@"Network path changed: %@ (expensive=%d, constrained=%d)",
                                     status, expensive, constrained]];
        os_log_with_type(log_net, OS_LOG_TYPE_INFO, "NWPath changed: %{public}s expensive=%d constrained=%d",
                         status.UTF8String, expensive, constrained);
        [[CrashReporterAdapter shared] addBreadcrumb:@"NWPathChanged"
                                                data:@{ @"status": status,
                                                        @"expensive": @(expensive),
                                                        @"constrained": @(constrained)}];
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf append:[NSString stringWithFormat:@"NWPath: %@", status]]; });
    });
    nw_path_monitor_set_queue(_monitor, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
    nw_path_monitor_start(_monitor);
    [[LogCollector shared] info:@"Network path monitor started successfully"];
    [self append:@"NWPathMonitor started."];
}

- (void)addBreadcrumb {
    [[LogCollector shared] info:@"User clicked: Add Crash breadcrumb"];
    [[CrashReporterAdapter shared] addBreadcrumb:@"UserTappedBreadcrumb" data:@{ @"screen": @"Logs" }];
    [[LogCollector shared] debug:@"Breadcrumb added to Sentry crash reporter"];
    [self append:@"Breadcrumb added to crash reporter."];
}
@end
