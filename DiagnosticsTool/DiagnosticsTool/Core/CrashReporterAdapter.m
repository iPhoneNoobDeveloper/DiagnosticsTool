#import "CrashReporterAdapter.h"
@import Sentry; // Using Sentry by default

@implementation CrashReporterAdapter

+ (instancetype)shared {
    static CrashReporterAdapter *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [CrashReporterAdapter new];
    });
    return s;
}

- (void)start {
    [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
        options.dsn = @"https://972473d417099361fc26db3bdf37f9e7@o4510218691805184.ingest.us.sentry.io/4510218813571072";
    
        options.enableMetricKit = YES; // macOS 12+
        options.enableAppHangTracking = YES;

        // Additional recommended settings
        options.tracesSampleRate = @1.0; // 100% sampling for testing; reduce in production
        options.enableAutoSessionTracking = YES;

#if DEBUG
        options.debug = YES; // Enabling debug when first installing is always helpful
        options.environment = @"debug";
#else
        options.environment = @"production";
#endif
    }];

    // Sentry is now initialized and ready to capture crashes
    // Test message removed - use CrashViewController to generate real crashes
}

- (void)addBreadcrumb:(NSString *)message data:(NSDictionary *)data {
    SentryBreadcrumb *b = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo category:@"app"];
    b.message = message;
    b.data = data;
    [SentrySDK addBreadcrumb:b];
}

- (void)setUserId:(NSString *)userId {
    SentryUser *u = [[SentryUser alloc] init];
    u.userId = userId;
    [SentrySDK setUser:u];
}

@end
