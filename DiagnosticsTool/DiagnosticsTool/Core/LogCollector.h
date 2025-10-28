#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LogLevel) {
    LogLevelDebug,
    LogLevelInfo,
    LogLevelWarning,
    LogLevelError
};

@interface LogCollector : NSObject

+ (instancetype)shared;

// Log a message with level
- (void)log:(NSString *)message level:(LogLevel)level;

// Convenience methods
- (void)debug:(NSString *)message;
- (void)info:(NSString *)message;
- (void)warning:(NSString *)message;
- (void)error:(NSString *)message;

// Get all collected logs as formatted string
- (NSString *)getAllLogsFormatted;

// Get logs from last N days
- (NSString *)getLogsFromLastDays:(NSInteger)days;

// Clear all logs
- (void)clearLogs;

@end

NS_ASSUME_NONNULL_END
