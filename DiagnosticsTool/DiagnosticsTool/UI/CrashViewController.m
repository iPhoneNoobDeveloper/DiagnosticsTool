#import "CrashViewController.h"
#import <os/log.h>
#import "CrashReporterAdapter.h"
#import "LogCollector.h"
@import Sentry;

@implementation CrashViewController {
    NSButton *_btnNSException;
    NSButton *_btnBadAccess;
    NSButton *_btnAssert;
    NSButton *_btnTestSentry;
    NSTextField *_info;
}

- (void)loadView {
    NSView *v = [NSView new];
    self.view = v;
    v.translatesAutoresizingMaskIntoConstraints = NO;

    _info = [self label:@"Crash playground. Use different crash types to validate reporting."];
    _btnTestSentry = [self button:@"Test Sentry (No Crash)" action:@selector(testSentry)];
    _btnNSException = [self button:@"Throw NSException" action:@selector(crashNSException)];
    _btnBadAccess = [self button:@"EXC_BAD_ACCESS" action:@selector(crashBadAccess)];
    _btnAssert = [self button:@"Abort via NSAssert" action:@selector(crashAssert)];

    NSStackView *stack = [NSStackView stackViewWithViews:@[_info,_btnTestSentry,_btnNSException,_btnBadAccess,_btnAssert]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [v addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:420]
    ]];
}

- (NSTextField *)label:(NSString *)text {
    NSTextField *l = [NSTextField labelWithString:text];
    l.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    return l;
}

- (NSButton *)button:(NSString *)title action:(SEL)sel {
    NSButton *b = [NSButton buttonWithTitle:title target:self action:sel];
    return b;
}

- (void)testSentry {
    [[LogCollector shared] info:@"User clicked: Test Sentry (No Crash)"];
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "Testing Sentry without crash");
    [[CrashReporterAdapter shared] addBreadcrumb:@"Testing Sentry connectivity" data:@{@"test": @"true"}];
    [SentrySDK captureMessage:@"Test message from CrashViewController - Sentry is working!"];
    [[LogCollector shared] info:@"Sentry test message sent successfully"];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Sentry Test"];
    [alert setInformativeText:@"A test message was sent to Sentry. Check your dashboard in a few seconds."];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)crashNSException {
    [[LogCollector shared] warning:@"User triggered NSException crash test"];
    [[CrashReporterAdapter shared] addBreadcrumb:@"User triggered NSException crash" data:@{@"crash_type": @"NSException"}];
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "About to throw NSException intentionally");
    [[LogCollector shared] error:@"Throwing NSException - app will crash"];
    @throw [NSException exceptionWithName:@"DemoException" reason:@"Intentional NSException for testing Sentry" userInfo:@{@"test": @"crash"}];
}

- (void)crashBadAccess {
    [[LogCollector shared] warning:@"User triggered EXC_BAD_ACCESS crash test"];
    [[CrashReporterAdapter shared] addBreadcrumb:@"User triggered EXC_BAD_ACCESS crash" data:@{@"crash_type": @"EXC_BAD_ACCESS"}];
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "About to trigger EXC_BAD_ACCESS intentionally");
    [[LogCollector shared] error:@"Triggering EXC_BAD_ACCESS - app will crash"];
    volatile char *ptr = (char *)0x1;
    *ptr = 'X';
}

- (void)crashAssert {
    [[LogCollector shared] warning:@"User triggered NSAssert crash test"];
    [[CrashReporterAdapter shared] addBreadcrumb:@"User triggered NSAssert crash" data:@{@"crash_type": @"NSAssert"}];
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "About to trigger NSAssert crash intentionally");
    [[LogCollector shared] error:@"Triggering NSAssert - app will crash"];
    NSAssert(false, @"Intentional assert fail for testing Sentry");
}

@end
