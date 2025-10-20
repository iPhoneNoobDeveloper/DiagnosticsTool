#import <Foundation/Foundation.h>
@interface CrashReporterAdapter : NSObject
+ (instancetype)shared;
- (void)start;
- (void)addBreadcrumb:(NSString *)message data:(NSDictionary *)data;
- (void)setUserId:(NSString *)userId;
@end
