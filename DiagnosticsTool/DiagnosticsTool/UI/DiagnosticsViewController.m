#import "DiagnosticsViewController.h"
#import "DiagnosticBundleBuilder.h"
#import "LogCollector.h"

@implementation DiagnosticsViewController {
    NSTextField *_status;
    NSProgressIndicator *_progressIndicator;
    NSButton *_btnLogOnly;
    NSButton *_btnLogSys;
}

- (void)loadView {
    NSView *v = [NSView new];
    self.view = v;
    // Don't set translatesAutoresizingMaskIntoConstraints on root view

    // Title
    NSTextField *title = [NSTextField labelWithString:@"Generate a diagnostic bundle with unified logs and optional sysdiagnose."];
    title.font = [NSFont systemFontOfSize:13];
    title.textColor = [NSColor secondaryLabelColor];
    title.lineBreakMode = NSLineBreakByWordWrapping;
    title.maximumNumberOfLines = 0;

    // Buttons
    _btnLogOnly = [NSButton buttonWithTitle:@"Collect logs" target:self action:@selector(collectLogs)];
    _btnLogOnly.bezelStyle = NSBezelStyleRounded;

    _btnLogSys = [NSButton buttonWithTitle:@"Collect logs + sysdiagnose" target:self action:@selector(collectLogsAndSys)];
    _btnLogSys.bezelStyle = NSBezelStyleRounded;

    // Progress indicator (spinning wheel)
    _progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    _progressIndicator.style = NSProgressIndicatorStyleSpinning;
    _progressIndicator.controlSize = NSControlSizeSmall;
    _progressIndicator.hidden = YES; // Hidden by default

    // Status label
    _status = [NSTextField labelWithString:@"Idle."];
    _status.font = [NSFont systemFontOfSize:12];
    _status.textColor = [NSColor labelColor];
    _status.lineBreakMode = NSLineBreakByWordWrapping;
    _status.maximumNumberOfLines = 0;

    // Create horizontal stack for progress indicator and status
    NSStackView *progressStack = [NSStackView stackViewWithViews:@[_progressIndicator, _status]];
    progressStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    progressStack.spacing = 8;
    progressStack.alignment = NSLayoutAttributeCenterY;
    progressStack.distribution = NSStackViewDistributionFill;

    // Main vertical stack
    NSStackView *stack = [NSStackView stackViewWithViews:@[title, _btnLogOnly, _btnLogSys, progressStack]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 12;
    stack.alignment = NSLayoutAttributeLeading;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [v addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:450]
    ]];
}

- (void)collectLogs {
    [[LogCollector shared] info:@"User clicked: Collect logs (without sysdiagnose)"];
    // Show loading state
    [self setLoadingState:YES];
    _status.stringValue = @"Collecting logs...";

    [DiagnosticBundleBuilder buildWithSysdiagnose:NO completion:^(NSURL *zipURL, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Hide loading state
            [self setLoadingState:NO];

            if (zipURL) {
                [[LogCollector shared] info:[NSString stringWithFormat:@"Diagnostic bundle created successfully: %@",
                                            zipURL.lastPathComponent]];
                self->_status.stringValue = [NSString stringWithFormat:@"✅ Success! Saved to Downloads: %@", zipURL.lastPathComponent];

                // Show alert with option to reveal in Finder
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:@"Diagnostic Bundle Created"];
                [alert setInformativeText:[NSString stringWithFormat:@"ZIP file saved to Downloads folder:\n%@", zipURL.path]];
                [alert addButtonWithTitle:@"Show in Finder"];
                [alert addButtonWithTitle:@"OK"];

                NSModalResponse response = [alert runModal];
                if (response == NSAlertFirstButtonReturn) {
                    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[zipURL]];
                }
            } else {
                [[LogCollector shared] error:[NSString stringWithFormat:@"Diagnostic bundle creation failed: %@",
                                             error.localizedDescription ?: @"Unknown error"]];
                self->_status.stringValue = [NSString stringWithFormat:@"❌ Failed: %@", error.localizedDescription ?: @"Unknown error"];

                // Show error alert
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:@"Failed to Create Diagnostic Bundle"];
                [alert setInformativeText:error.localizedDescription ?: @"An unknown error occurred"];
                [alert addButtonWithTitle:@"OK"];
                [alert runModal];
            }
        });
    }];
}

- (void)collectLogsAndSys {
    [[LogCollector shared] info:@"User clicked: Collect logs + sysdiagnose"];
    NSAlert *warning = [[NSAlert alloc] init];
    [warning setMessageText:@"Sysdiagnose Collection"];
    [warning setInformativeText:@"This will collect comprehensive system diagnostics and may take 2-3 minutes. You may be prompted for your password.\n\nThe app will show a spinning loader while collecting."];
    [warning addButtonWithTitle:@"Continue"];
    [warning addButtonWithTitle:@"Cancel"];

    NSModalResponse response = [warning runModal];
    if (response != NSAlertFirstButtonReturn) {
        [[LogCollector shared] info:@"User cancelled sysdiagnose collection"];
        _status.stringValue = @"Cancelled.";
        return;
    }

    [[LogCollector shared] info:@"Starting diagnostic bundle collection with sysdiagnose"];
    // Show loading state
    [self setLoadingState:YES];
    _status.stringValue = @"Collecting logs and sysdiagnose (this may take 2-3 minutes)...";

    [DiagnosticBundleBuilder buildWithSysdiagnose:YES completion:^(NSURL *zipURL, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Hide loading state
            [self setLoadingState:NO];

            if (zipURL) {
                [[LogCollector shared] info:[NSString stringWithFormat:@"Diagnostic bundle with sysdiagnose created: %@",
                                            zipURL.lastPathComponent]];
                self->_status.stringValue = [NSString stringWithFormat:@"✅ Success! Saved to Downloads: %@", zipURL.lastPathComponent];

                // Show alert with option to reveal in Finder
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:@"Diagnostic Bundle Created"];
                [alert setInformativeText:[NSString stringWithFormat:@"ZIP file saved to Downloads folder:\n%@\n\nNote: Sysdiagnose requires administrator privileges and may have failed if password was not provided.", zipURL.path]];
                [alert addButtonWithTitle:@"Show in Finder"];
                [alert addButtonWithTitle:@"OK"];

                NSModalResponse response = [alert runModal];
                if (response == NSAlertFirstButtonReturn) {
                    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[zipURL]];
                }
            } else {
                [[LogCollector shared] error:[NSString stringWithFormat:@"Diagnostic bundle with sysdiagnose failed: %@",
                                             error.localizedDescription ?: @"Unknown error"]];
                self->_status.stringValue = [NSString stringWithFormat:@"❌ Failed: %@", error.localizedDescription ?: @"Unknown error"];

                // Show error alert
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:@"Failed to Create Diagnostic Bundle"];
                [alert setInformativeText:error.localizedDescription ?: @"An unknown error occurred"];
                [alert addButtonWithTitle:@"OK"];
                [alert runModal];
            }
        });
    }];
}

// Helper method to show/hide loading state
- (void)setLoadingState:(BOOL)isLoading {
    if (isLoading) {
        // Show spinner and disable buttons
        _progressIndicator.hidden = NO;
        [_progressIndicator startAnimation:nil];
        _btnLogOnly.enabled = NO;
        _btnLogSys.enabled = NO;
    } else {
        // Hide spinner and enable buttons
        [_progressIndicator stopAnimation:nil];
        _progressIndicator.hidden = YES;
        _btnLogOnly.enabled = YES;
        _btnLogSys.enabled = YES;
    }
}
@end
