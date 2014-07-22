//
//  OSViewController.m
//  OSNotificationScheduler
//
//  Created by Chris Birch on 05/04/2013.
//  Copyright (c) 2013 Ocasta Studios. All rights reserved.
//

#import "OSViewController.h"
#import "OSAppDelegate.h"
#import "OSNotificationScheduler.h"

@interface OSViewController ()

@end

@implementation OSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self setupNotificationHandlers];
}


-(void)setupNotificationHandlers
{
    OSNotificationScheduler* shared = [OSNotificationScheduler shared];
    shared.debugLoggingEnabled = YES;
    
    BOOL loaded = [shared loadPlist];
    
    OSNotificationDescriptor* descriptor = [shared notificationDescriptorForNotificationName:NOTIFICATION_EXAMPLE];

    
    if (loaded)
    {
        [shared registerNotificationName:NOTIFICATION_EXAMPLE withHandlerTag:@"HANDLER1" andHandler:
         ^(OSNotificationDescriptor *notificationDescriptor)
        {
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Notification Alert" message:@"This is a notification example" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        }];
        
       // [self performSelector:@selector(doDat) withObject:nil afterDelay:3];
    }
}


-(void)doDat
{
   if([[OSNotificationScheduler shared] shouldNotifyWithNotificationName:NOTIFICATION_EXAMPLE])
   {
       
       UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Notification Alert" message:@"Slurp" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
       [alert show];
   }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
