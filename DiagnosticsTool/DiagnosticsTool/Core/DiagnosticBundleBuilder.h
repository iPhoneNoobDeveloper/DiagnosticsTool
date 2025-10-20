#import <Foundation/Foundation.h>
@interface DiagnosticBundleBuilder : NSObject
+ (void)buildWithSysdiagnose:(BOOL)includeSys completion:(void(^)(NSURL *zipURL, NSError *error))completion;
@end
