#import "LogCollector.h"
#import <os/log.h>

@interface LogEntry : NSObject
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) LogLevel level;
@end

@implementation LogEntry
@end

@implementation LogCollector {
    NSMutableArray<LogEntry *> *_logs;
    NSLock *_lock;
    NSDateFormatter *_dateFormatter;
}

+ (instancetype)shared {
    static LogCollector *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LogCollector alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _logs = [NSMutableArray array];
        _lock = [[NSLock alloc] init];

        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";

        // Log startup
        [self info:@"LogCollector initialized"];
        [self info:[NSString stringWithFormat:@"App launched at %@", [NSDate date]]];
    }
    return self;
}

- (void)log:(NSString *)message level:(LogLevel)level {
    [_lock lock];

    LogEntry *entry = [[LogEntry alloc] init];
    entry.timestamp = [NSDate date];
    entry.message = message;
    entry.level = level;

    [_logs addObject:entry];

    // Also log to system console using os_log
    os_log_type_t osLogType;
    NSString *levelStr;

    switch (level) {
        case LogLevelDebug:
            osLogType = OS_LOG_TYPE_DEBUG;
            levelStr = @"DEBUG";
            break;
        case LogLevelInfo:
            osLogType = OS_LOG_TYPE_INFO;
            levelStr = @"INFO";
            break;
        case LogLevelWarning:
            osLogType = OS_LOG_TYPE_DEFAULT;
            levelStr = @"WARNING";
            break;
        case LogLevelError:
            osLogType = OS_LOG_TYPE_ERROR;
            levelStr = @"ERROR";
            break;
    }

    os_log_with_type(OS_LOG_DEFAULT, osLogType, "[%s] %s",
                     [levelStr UTF8String],
                     [message UTF8String]);

    // Keep only last 10,000 entries to prevent memory bloat
    if (_logs.count > 10000) {
        [_logs removeObjectsInRange:NSMakeRange(0, 1000)];
    }

    [_lock unlock];
}

- (void)debug:(NSString *)message {
    [self log:message level:LogLevelDebug];
}

- (void)info:(NSString *)message {
    [self log:message level:LogLevelInfo];
}

- (void)warning:(NSString *)message {
    [self log:message level:LogLevelWarning];
}

- (void)error:(NSString *)message {
    [self log:message level:LogLevelError];
}

- (NSString *)getAllLogsFormatted {
    [_lock lock];
    NSMutableString *result = [NSMutableString string];

    [result appendString:@"═══════════════════════════════════════════════════════════\n"];
    [result appendString:@"           APPLICATION LOGS (In-Memory Collection)\n"];
    [result appendFormat:@"           Total Entries: %lu\n", (unsigned long)_logs.count];
    [result appendString:@"═══════════════════════════════════════════════════════════\n\n"];

    for (LogEntry *entry in _logs) {
        NSString *levelStr;
        switch (entry.level) {
            case LogLevelDebug:   levelStr = @"DEBUG  "; break;
            case LogLevelInfo:    levelStr = @"INFO   "; break;
            case LogLevelWarning: levelStr = @"WARNING"; break;
            case LogLevelError:   levelStr = @"ERROR  "; break;
        }

        [result appendFormat:@"[%@] [%@] %@\n",
         [_dateFormatter stringFromDate:entry.timestamp],
         levelStr,
         entry.message];
    }

    [result appendString:@"\n═══════════════════════════════════════════════════════════\n"];
    [result appendFormat:@"           End of Logs (%lu entries)\n", (unsigned long)_logs.count];
    [result appendString:@"═══════════════════════════════════════════════════════════\n"];

    [_lock unlock];
    return result;
}

- (NSString *)getLogsFromLastDays:(NSInteger)days {
    [_lock lock];

    NSDate *cutoffDate = [NSDate dateWithTimeIntervalSinceNow:-(days * 24 * 60 * 60)];
    NSMutableString *result = [NSMutableString string];

    NSUInteger count = 0;
    for (LogEntry *entry in _logs) {
        if ([entry.timestamp compare:cutoffDate] == NSOrderedDescending) {
            count++;
        }
    }

    [result appendString:@"═══════════════════════════════════════════════════════════\n"];
    [result appendFormat:@"           APPLICATION LOGS (Last %ld Days)\n", (long)days];
    [result appendFormat:@"           Entries: %lu\n", (unsigned long)count];
    [result appendString:@"═══════════════════════════════════════════════════════════\n\n"];

    for (LogEntry *entry in _logs) {
        if ([entry.timestamp compare:cutoffDate] == NSOrderedDescending) {
            NSString *levelStr;
            switch (entry.level) {
                case LogLevelDebug:   levelStr = @"DEBUG  "; break;
                case LogLevelInfo:    levelStr = @"INFO   "; break;
                case LogLevelWarning: levelStr = @"WARNING"; break;
                case LogLevelError:   levelStr = @"ERROR  "; break;
            }

            [result appendFormat:@"[%@] [%@] %@\n",
             [_dateFormatter stringFromDate:entry.timestamp],
             levelStr,
             entry.message];
        }
    }

    [result appendString:@"\n═══════════════════════════════════════════════════════════\n"];
    [result appendFormat:@"           End of Logs (%lu entries)\n", (unsigned long)count];
    [result appendString:@"═══════════════════════════════════════════════════════════\n"];

    [_lock unlock];
    return result;
}

- (void)clearLogs {
    [_lock lock];
    [_logs removeAllObjects];
    [_lock unlock];
}

@end
