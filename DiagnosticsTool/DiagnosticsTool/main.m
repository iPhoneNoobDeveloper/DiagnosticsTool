//
//  main.m
//  DiagnosticsTool
//
//  Created by Nirav Jain on 10/18/25.
//

#pragma mark - main.m
#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [AppDelegate new];
        [app setDelegate:delegate];
        return NSApplicationMain(argc, argv);
    }
}
