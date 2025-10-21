#import "AppCoordinator.h"
#import "CrashViewController.h"
#import "LogsViewController.h"
#import "DiagnosticsViewController.h"

@implementation AppCoordinator {
    NSWindow *_window;
    CrashViewController *_crashVC;
    LogsViewController *_logsVC;
    DiagnosticsViewController *_diagnosticsVC;
}

- (void)start {
    NSRect frame = NSMakeRect(0, 0, 900, 600);
    _window = [[NSWindow alloc] initWithContentRect:frame
                                          styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable)
                                            backing:NSBackingStoreBuffered defer:NO];
    [_window center];
    [_window setTitle:@"Diagnostics Starter (ObjC)"];

    NSTabView *tabs = [NSTabView new];
    tabs.translatesAutoresizingMaskIntoConstraints = NO;

    // Keep strong references to view controllers so their button actions work
    _crashVC = [CrashViewController new];
    _logsVC = [LogsViewController new];
    _diagnosticsVC = [DiagnosticsViewController new];

    NSTabViewItem *crashItem = [[NSTabViewItem alloc] initWithIdentifier:@"crashes"];
    crashItem.label = @"Crashes";
    crashItem.view = _crashVC.view;

    NSTabViewItem *logItem = [[NSTabViewItem alloc] initWithIdentifier:@"logs"];
    logItem.label = @"Logging";
    logItem.view = _logsVC.view;

    NSTabViewItem *diagItem = [[NSTabViewItem alloc] initWithIdentifier:@"diagnostics"];
    diagItem.label = @"Diagnostics";
    diagItem.view = _diagnosticsVC.view;

    [tabs addTabViewItem:crashItem];
    [tabs addTabViewItem:logItem];
    [tabs addTabViewItem:diagItem];

    NSView *content = [NSView new];
    _window.contentView = content;

    [content addSubview:tabs];
    [NSLayoutConstraint activateConstraints:@[
        [tabs.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:12],
        [tabs.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-12],
        [tabs.topAnchor constraintEqualToAnchor:content.topAnchor constant:12],
        [tabs.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-12]
    ]];

    [_window makeKeyAndOrderFront:nil];
}
@end
