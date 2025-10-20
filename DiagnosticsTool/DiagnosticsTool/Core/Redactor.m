#import "Redactor.h"
@implementation Redactor
+ (NSString *)safeString:(NSString *)value {
    if (!value) return @"";
    return [NSString stringWithFormat:@"[redacted:%lu]", (unsigned long)value.hash];
}
@end
