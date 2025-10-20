#import "MetricsListener.h"
#import <os/log.h>

@implementation MetricsListener

#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV
- (void)didReceiveMetricPayloads:(NSArray<MXMetricPayload *> *)payloads API_AVAILABLE(ios(13.0)) {
    for (MXMetricPayload *p in payloads) {
        NSData *jsonData = p.JSONRepresentation;
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "MetricKit payload: %s", jsonString.UTF8String);
    }
}

- (void)didReceiveDiagnosticPayloads:(NSArray<MXDiagnosticPayload *> *)payloads API_AVAILABLE(ios(14.0)) {
    for (MXDiagnosticPayload *p in payloads) {
        NSData *jsonData = p.JSONRepresentation;
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Diagnostic payload: %s", jsonString.UTF8String);
    }
}
#else
// MetricKit on macOS doesn't provide MXMetricPayload or MXDiagnosticPayload
// The framework is available but these specific classes are iOS-only
- (void)didReceiveMetricPayloads:(NSArray *)payloads API_AVAILABLE(macos(12.0)) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "MetricKit payloads received (count: %lu)", (unsigned long)payloads.count);
    // On macOS, you would need to use different approaches to collect metrics
}

- (void)didReceiveDiagnosticPayloads:(NSArray *)payloads API_AVAILABLE(macos(12.0)) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Diagnostic payloads received (count: %lu)", (unsigned long)payloads.count);
    // On macOS, you would need to use different approaches to collect diagnostics
}
#endif
@end
