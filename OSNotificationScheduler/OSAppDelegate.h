//
//  OSAppDelegate.h
//  OSNotificationScheduler
//
//  Created by Chris Birch on 05/04/2013.
//  Copyright (c) 2013 Ocasta Studios. All rights reserved.
//

//defined in OSNotificationScheduler.plist
#define NOTIFICATION_EXAMPLE @"ExampleNotification"



#import <UIKit/UIKit.h>

@class OSViewController;

@interface OSAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) OSViewController *viewController;

@end
