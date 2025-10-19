//
//  AppDelegate.h
//  DiagnosticsTool
//
//  Created by Nirav Jain on 10/18/25.
//

#import <Cocoa/Cocoa.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly, strong) NSPersistentContainer *persistentContainer;


@end

