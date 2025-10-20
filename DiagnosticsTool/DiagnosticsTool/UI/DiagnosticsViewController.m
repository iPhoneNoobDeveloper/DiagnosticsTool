#import "DiagnosticsViewController.h"
#import "DiagnosticBundleBuilder.h"

@implementation DiagnosticsViewController {
    NSTextField *_status;
}

- (void)loadView {
    NSView *v = [NSView new]; self.view = v;
    NSTextField *title = [NSTextField labelWithString:@"Generate a diagnostic bundle with unified logs and optional sysdiagnose."];
    NSButton *btnLogOnly = [NSButton buttonWithTitle:@"Collect logs" target:self action:@selector(collectLogs)];
    NSButton *btnLogSys = [NSButton buttonWithTitle:@"Collect logs + sysdiagnose" target:self action:@selector(collectLogsAndSys)];
    _status = [NSTextField labelWithString:@"Idle."];

    NSStackView *stack = [NSStackView stackViewWithViews:@[title, btnLogOnly, btnLogSys, _status]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical; stack.spacing = 12; stack.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:520]
    ]];
}

- (void)collectLogs {
    _status.stringValue = @"Collecting logs...";
    [DiagnosticBundleBuilder buildWithSysdiagnose:NO completion:^(NSURL *zipURL, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (zipURL) { self->_status.stringValue = [NSString stringWithFormat:@"Saved: %@", zipURL.path]; }
            else { self->_status.stringValue = error.localizedDescription ?: @"Failed."; }
        });
    }];
}

- (void)collectLogsAndSys {
    _status.stringValue = @"Collecting logs and sysdiagnose...";
    [DiagnosticBundleBuilder buildWithSysdiagnose:YES completion:^(NSURL *zipURL, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (zipURL) { self->_status.stringValue = [NSString stringWithFormat:@"Saved: %@", zipURL.path]; }
            else { self->_status.stringValue = error.localizedDescription ?: @"Failed."; }
        });
    }];
}
@end
