//
//  OSNotificationScheduler.m
//  OSNotificationScheduler
//
//  Created by Chris Birch on 05/04/2013.
//  Copyright (c) 2013 Ocasta Studios. All rights reserved.
//



#import "OSNotificationScheduler.h"

#define PLISTFILE @"OSNotificationScheduler" 

#define OSNOTIFICATION_PLIST_KEY_GLOBAL_ENABLE @"EnableNotifications"
#define OSNOTIFICATION_PLIST_KEY_NOTIFICATIONS_ARRAY @"Notifications"

//The name of the notification, also used for NSNotification generation
#define OSNOTIFICATION_PLIST_KEY_NOTIFICATION_NAME @"Name"
//A description of the notification
#define OSNOTIFICATION_PLIST_KEY_NOTIFICATION_DESCRIPTION @"Description"
//Describes the number of seconds between subsequent notifications
#define OSNOTIFICATION_PLIST_KEY_NOTIFICATION_INTERVAL @"IntervalSeconds"
/**
 * If YES means that this notification will only fire once in the lifetime of the app
 */
#define OSNOTIFICATION_PLIST_KEY_NOTIFICATION_ONETIMEONLY @"OneTimeOnly"
/**
 * If NO means that the notification will not fire and cannot be tested manually
 */
#define OSNOTIFICATION_PLIST_KEY_NOTIFICATION_ENABLED @"Enabled"

/**
 * If NO means that the notification will not fire automatically but can tested manually with
 */
#define OSNOTIFICATION_PLIST_KEY_NOTIFICATION_CAUSES_NOTIFICATION @"CausesNotificationGeneration"


/**
 * If NO means that the notification will fire immediately after update is called on a newly added event for the first time
 */
#define OSNOTIFICATION_PLIST_KEY_SHOULD_WAIT_INTERVAL_FIRST_TIME @"ShouldWaitIntervalBeforeFirstFire"

//used to store notication name inside timer user info dictionary
#define TIMER_USER_INFO_KEY_NOTIFICATION_NAME @"NotificationName"




#pragma mark -
#pragma mark OSNotificationDescriptor Friend stuff



@interface OSNotificationDescriptor ()
{
    
}


/**
 * Loads data about this notification from the user defaults store.
 * Returns YES if there is data stored.
 */
-(BOOL)__loadPersistedData;
/**
 * Saves the storedData dictionary to the NSUserDefaults
 */
-(BOOL)__saveData;

/**
 * sets the last fired date to NOW
 */
-(void)__setLastFiredDate;

/**
 * Sets the timer started date to the specified date or nil
 */
-(void)__setTimerStartedDate:(NSDate*)startedDate;



@end





@interface OSNotificationScheduler ()
{
    NSMutableArray* _notifications;
    /**
     * Notification descriptors are added here when they are removed.
     * the update function uses this array to unregister notifications
     */
    NSMutableArray* _removedNotifications;
    
    /**
     * Contains active notification timers. These timers are used to fire the notifications at the correct intervals.
     * The key for each notification is the same as its name.
     */
    NSMutableDictionary* _timers;
    
    /**
     * Contains block handlers that user code has registered to deal with notifications.
     * The key for each notification is the notification name + a user code supplied tag used to distinguish between different handlers for the same notification.
     */
    NSMutableDictionary* _blocks;
}

/**
 * Returns the OSNotificationDescriptor for the notification with the specified name
 */
-(OSNotificationDescriptor*)notificationDescriptorForNotificationName:(NSString*)name;

/**
 * Outputs the specified message to the console if debug logging is enabeld
 */
-(void)debugLog:(NSString*)message;

/**
 * Constructs the full key used to store a handler block in the blocks dictionary
 */
-(NSString*)blockFullKeyNameWithNotificationName:(NSString*)notificationName andHandlerTag:(NSString*)tag;

///**
// * Returns all handlers for the specified notification name
// */
//-(NSArray*)handlersForNotificationName:(NSString*)notificationName;
/**
 * Returns all handler keys for the specified notification name
 */
-(NSArray*)handlerKeysForNotificationName:(NSString*)notificationName;

/**
 * Executes all block handlers for the specified notification descriptor
 */
-(void)fireHandlersForNotificationDescriptor:(OSNotificationDescriptor*)descriptor;


@end

@implementation OSNotificationScheduler

@synthesize notifications=_notifications;


#pragma mark -
#pragma mark Shared

/**
 * Shared instance
 */
static OSNotificationScheduler* _shared=nil;

+(OSNotificationScheduler*)shared
{
    @synchronized(_shared)
    {
        if (!_shared)
            _shared = [[OSNotificationScheduler alloc] init];
    }
    
    return _shared;
}

#pragma mark -
#pragma mark Properties

-(void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
    
    if (_enabled != enabled)
    {
        //we need to destroy all the timers
        for (OSNotificationDescriptor* descriptor in _notifications)
        {
            [self destroyTimerForNotificationName:descriptor.name];
        }
    }
    
    //now we check to see if we need to recreate the timers
    if (_enabled)
        [self update];
    
}

#pragma mark -
#pragma mark Descriptor helpers

-(OSNotificationDescriptor*)notificationDescriptorForNotificationName:(NSString*)name
{
    
    for (OSNotificationDescriptor* descriptor in _notifications)
    {
        if ([descriptor.name isEqualToString:name])
            return descriptor;
    }
    
    [self debugLog:[[NSString alloc] initWithFormat:@"No OSNotificationDescriptor for notification with name: %@",name]];
    return nil;
}

#pragma mark -
#pragma mark Timer stuff

-(void)destroyTimerForNotificationName:(NSString*)notificationName
{
    if ([_timers.allKeys containsObject:notificationName])
    {
        [self debugLog:[[NSString alloc] initWithFormat:@"For some reason we already have a timer for key: %@. Cancelling timer",notificationName]];
        NSTimer* timer = [_timers objectForKey:notificationName];
        [timer invalidate];
        [_timers removeObjectForKey:notificationName];
    }

}

-(void)scheduleTimerForNotificationDescriptor:(OSNotificationDescriptor*)descriptor
{
    if (!_timers)
        _timers = [[NSMutableDictionary alloc] init];
    else
    {
        [self destroyTimerForNotificationName:descriptor.name];
    }
    
    NSDictionary* userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:descriptor.name, TIMER_USER_INFO_KEY_NOTIFICATION_NAME,nil];
    //use interval until next fire as this takes into account how long ago this was last fired
    //this useful for times when app is closed
    NSTimeInterval intervalTillNextFire = descriptor.intervalUntilNextFire;
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:intervalTillNextFire target:self selector:@selector(timerElapsed:) userInfo:userInfo repeats:NO];
    
    [_timers setObject:timer forKey:descriptor.name];
    
    //Now set the date that this timer was started
    [descriptor __setTimerStartedDate:[NSDate date]];
    
    [self debugLog:[[NSString alloc] initWithFormat:@"Scheduled timer for key: %@. Timer will elapse in %.2f seconds",descriptor.name,intervalTillNextFire]];
    
}

-(void)timerElapsed:(NSTimer*)timer
{
    
    NSDictionary* userInfo = timer.userInfo;
    
    NSString* notificationName = [userInfo objectForKey:TIMER_USER_INFO_KEY_NOTIFICATION_NAME];
    
    //remove timer from timers dict
    [_timers removeObjectForKey:notificationName];
    
    OSNotificationDescriptor* descriptor = [self notificationDescriptorForNotificationName:notificationName];
    
    if (descriptor)
    {
        //check whether user has modified the descriptor to disable notifications since we scheduled the timer
        if (!descriptor.enabled || !descriptor.causesNotificationGeneration)
        {   
            [self debugLog:[[NSString alloc] initWithFormat:@"Timer has elapsed for notification named: %@ but the descriptor states that we shouldnt fire the notification. Ignoring", notificationName]];
        }
        else
        {
            //fire all the handlers for this notification
            [self fireHandlersForNotificationDescriptor:descriptor];
            
            //post a NSNotificationCentre notification
            [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:descriptor userInfo:descriptor.userInfo];
            
            //Save the last time that we fired
            [descriptor __setLastFiredDate];
            
            //now we check whether we need to reschedule this notification
            if (!descriptor.oneTimeOnly)
            {
                //schedule notification
                [self scheduleTimerForNotificationDescriptor:descriptor];
            }
        }
    }
    else
    {
        [self debugLog:[[NSString alloc] initWithFormat:@"Timer has elapsed for notification named: %@ but no matching descriptor can be found. Ignoring", notificationName]];
    }
}


#pragma mark -
#pragma mark Block helpers

-(NSString*)blockFullKeyNameWithNotificationName:(NSString*)notificationName andHandlerTag:(NSString*)tag
{
    return [[NSString alloc] initWithFormat:@"%@-%@",notificationName,tag];
}


-(NSArray*)handlerKeysForNotificationName:(NSString*)notificationName
{
    NSMutableArray* handlerKeys = [[NSMutableArray alloc] init];
    
    for (NSString* handlerKey in _blocks.allKeys)
    {
        if ([handlerKey hasPrefix:notificationName])
        {
            
            [handlerKeys addObject:handlerKey];
        }
        
    }
    
    return handlerKeys;
}

-(void)fireHandlersForNotificationDescriptor:(OSNotificationDescriptor*)descriptor
{
    NSArray* handlerKeys = [self handlerKeysForNotificationName:descriptor.name];
    
   
    for (NSString* handlerKey in handlerKeys)
    {
        OSNotificationBlock handler = [_blocks objectForKey:handlerKey];
        //fire handler
        [self debugLog:[[NSString alloc] initWithFormat:@"Firing handler: %@",handlerKey]];
        
        handler(descriptor);
    }

}


#pragma mark -
#pragma mark Block registration


-(BOOL)registerNotificationName:(NSString*)notificationName withHandlerTag:(NSString*)handlerTag andHandler:(OSNotificationBlock)handler
{
    //construct full key for this block
    NSString* handlerKey = [self blockFullKeyNameWithNotificationName:notificationName andHandlerTag:handlerTag];
    
    //make sure blocks dictionary exists
    if (!_blocks)
        _blocks = [[NSMutableDictionary alloc] init];
    
    
    //Make sure a block doesnt already exist for this notification with the specified tag name
    if ([_blocks.allKeys containsObject:handlerKey])
    {
        [self debugLog:[[NSString alloc] initWithFormat:@"A handler with tag %@ for %@ already been defined.",handlerTag,notificationName]];
        return NO;
    }
    else
    {
        //store block
        [_blocks setObject:[handler copy] forKey:handlerKey];
        
        [self debugLog:[[NSString alloc] initWithFormat:@"Successfully registered handler %@",handlerKey]];
        
        return YES;
    }
    
}


-(BOOL)unregisterAllBlocksForNotificationName:(NSString*)notificationName
{
    if (_blocks)
    {
        //retrieve all keys for blocks that handle the specified notification name
        NSArray* handlerKeys = [self handlerKeysForNotificationName:notificationName];
        
        for (OSNotificationBlock handlerKey in handlerKeys)
        {
            [_blocks removeObjectForKey:handlerKey];
            [self debugLog:[[NSString alloc] initWithFormat:@"Successfully unregistered handler %@",handlerKey]];
        }
        
        return YES;
    }
    else
    {
        [self debugLog:[[NSString alloc] initWithFormat:@"Cant unregister handlers for %@. No blocks have been defined",notificationName]];
        return NO;
    }
}

-(BOOL)unregisterBlockForNotificationName:(NSString*)notificationName andHandlerTag:(NSString*)handlerTag
{
    if (_blocks)
    {
        //construct full key for this block
        NSString* handlerKey = [self blockFullKeyNameWithNotificationName:notificationName andHandlerTag:handlerTag];
        
        //Make sure a block exists for this notification with the specified tag name
        if ([_blocks.allKeys containsObject:handlerKey])
        {
            [_blocks removeObjectForKey:handlerKey];
            
            [self debugLog:[[NSString alloc] initWithFormat:@"Successfully unregistered handler %@",handlerKey]];
            
            return YES;
        }
        else
        {
            [self debugLog:[[NSString alloc] initWithFormat:@"Cant unregister handler with tag %@ for %@. No such handler has been registered",handlerTag,notificationName]];
            return NO;
        }
        

    }
    else
    {
        [self debugLog:[[NSString alloc] initWithFormat:@"Cant unregister handler with tag %@ for %@. No blocks have been defined",handlerTag,notificationName]];
        return NO;
    }

}


#pragma mark -
#pragma mark Update


-(void)update
{
    //create the timers dictionary if it doesnt exist
    if (!_timers)
    {
        _timers = [[NSMutableDictionary alloc] init];
    }
    
    //first we need to clean up notifications that have been removed
    for (OSNotificationDescriptor* descriptor in _removedNotifications)
    {
        NSString* name = descriptor.name;
        
        //removing startdate
        [descriptor __setTimerStartedDate:nil];
        
        //remove timer if it exists
        if ([_timers.allKeys containsObject:name])
        {
            [self debugLog:[[NSString alloc] initWithFormat:@"Destroying timer for notification: %@",descriptor]];
            
            NSTimer* timer = [_timers objectForKey:name];
            [timer invalidate];
            
            [_timers removeObjectForKey:name];
        }
        else
        {
            [self debugLog:[[NSString alloc] initWithFormat:@"Timer for notification: %@ doesnt exist",descriptor]];
        }
    }
    
    //reset removed notifications
    _removedNotifications = nil;
    
    //Now register all the notifications
    for (OSNotificationDescriptor* descriptor in _notifications)
    {
        [self debugLog:[[NSString alloc] initWithFormat:@"Updating notification: %@", descriptor]];

        if (descriptor.enabled)
        {
            if (!descriptor.causesNotificationGeneration)
            {
                [self debugLog:@"Not creating timer for notification as it doesn't generate notifications automatically. Please manually test for this notification."];
                
                //Now set the date that this timer was started. Even though we arent starting a timer, we still need to know when this
                //notification was started.
                [descriptor __setTimerStartedDate:[NSDate date]];
            }
            //check if this is onetime only and has already been fired
            else if (descriptor.oneTimeOnly && descriptor.lastFired)
            {
                [self debugLog:@"Not notifying of this one as it is one time only"];
            }
            else
            {
                //schedule timer for this
                [self scheduleTimerForNotificationDescriptor:descriptor];
            }
        }
        else
        {
            [self debugLog:@"Notifcation is disabled"];
        }
    }
}

#pragma mark -
#pragma mark Add/remove notifications


-(BOOL)addNotification:(OSNotificationDescriptor*)descriptor
{
    //Create array if it doesnt exist
    if (!_notifications)
        _notifications = [[NSMutableArray alloc] init];
    else
    {
        if ([_notifications containsObject:descriptor])
        {
            [self debugLog:[[NSString alloc] initWithFormat:@"Can't add notification: %@ as it already exists!", descriptor]];
            return NO;
        }
    }
    
    [_notifications addObject:descriptor];
    [self debugLog:[[NSString alloc] initWithFormat:@"Added notification: %@\nBe sure to call update function when finished adding notifications. Failure to do so will result in no notifications being fired.", descriptor]];
    
    return YES;
    
}

-(BOOL)removeNotification:(OSNotificationDescriptor*)descriptor
{
    if (_notifications)
    {
        if ([_notifications containsObject:descriptor])
        {
            //check if we need to create the removed descriptor array
            if (!_removedNotifications)
            {
                _removedNotifications = [[NSMutableArray alloc] init];
            }
            
            //add to the removed notifications array, this is so the update function will be able to unregister the notification
            [_removedNotifications addObject:descriptor];
            //remove from active notifications array
            [_notifications removeObject:descriptor];
            
            [self debugLog:[[NSString alloc] initWithFormat:@"Removed notification: %@\nBe sure to call update function when finished removing notifications. Failure to do so will result in old notifications being fired.", descriptor]];
            return YES;
        }
        else
        {
            //Notification doesnt exist in array
            [self debugLog:[[NSString alloc] initWithFormat:@"Can't remove notification: %@ because it doesnt exist", descriptor.description]];
            return NO;
        }
    }
    else
    {
        //Cant remove because we dont even have an array!
        [self debugLog:[[NSString alloc] initWithFormat:@"Can't remove notification: %@ because we dont have any existing notifications", descriptor.description]];
        return NO;
    }
}

#pragma mark -
#pragma mark Manual test for non automaticically fired notifications


-(BOOL)shouldNotifyWithNotificationName:(NSString*)notificationName
{
    OSNotificationDescriptor* descriptor = [self notificationDescriptorForNotificationName:notificationName];
    return [self shouldNotifyWithNotificationDescriptior:descriptor];
}

-(BOOL)shouldNotifyWithNotificationDescriptior:(OSNotificationDescriptor*)notification
{
    if (notification)
    {
        return notification.shouldNotify;
    }
    
    return NO;
}


#pragma mark -
#pragma mark PList stuff

-(BOOL)loadPlist
{
    
    NSString *resourcePath = [[NSBundle mainBundle] pathForResource:PLISTFILE ofType:@"plist"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:resourcePath])
    {
        [self debugLog:[[NSString alloc] initWithFormat:@"PList file exists: %@", resourcePath]];
        
        NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:resourcePath];
        
        if (dict)
        {
            [self debugLog:[[NSString alloc] initWithFormat:@"PList loaded into dictionary"]];
            
            NSArray *rawNotifications = [dict objectForKey:OSNOTIFICATION_PLIST_KEY_NOTIFICATIONS_ARRAY];
            
            for (NSDictionary* descriptor in rawNotifications)
            {
                //read values from dictionary
                NSString* name = [descriptor objectForKey:OSNOTIFICATION_PLIST_KEY_NOTIFICATION_NAME];
                NSString* desc = [descriptor objectForKey:OSNOTIFICATION_PLIST_KEY_NOTIFICATION_DESCRIPTION];
                NSTimeInterval interval = [(NSNumber*) [descriptor objectForKey:OSNOTIFICATION_PLIST_KEY_NOTIFICATION_INTERVAL] doubleValue];
                BOOL oneTimeOnly = [(NSNumber*) [descriptor objectForKey:OSNOTIFICATION_PLIST_KEY_NOTIFICATION_ONETIMEONLY] boolValue];
                BOOL enabled = [(NSNumber*) [descriptor objectForKey:OSNOTIFICATION_PLIST_KEY_NOTIFICATION_ENABLED] boolValue];
                BOOL causesNotificationGeneration = [(NSNumber*) [descriptor objectForKey:OSNOTIFICATION_PLIST_KEY_NOTIFICATION_CAUSES_NOTIFICATION] boolValue];
                BOOL waitsIntervalBeforeFirstFire = [(NSNumber*) [descriptor objectForKey:OSNOTIFICATION_PLIST_KEY_SHOULD_WAIT_INTERVAL_FIRST_TIME] boolValue];
                
                //Create notificationDescriptor
                OSNotificationDescriptor* descriptor = [[OSNotificationDescriptor alloc] init];
                descriptor.name = name;
                descriptor.notificationDescription = desc;
                descriptor.interval = interval;
                descriptor.oneTimeOnly = oneTimeOnly;
                descriptor.enabled = enabled;
                descriptor.causesNotificationGeneration = causesNotificationGeneration;
                descriptor.shouldWaitIntervalBeforeFirstFire =waitsIntervalBeforeFirstFire;
                
                //Add the descriptor to the array
                [self addNotification:descriptor];
                
                //try and load persisted data
                if ([descriptor __loadPersistedData])
                {
                    [self debugLog:[[NSString alloc] initWithFormat:@"Loaded persisted data for notification: %@\n%@",name,descriptor.storedData]];
                }
                else
                {
                    [self debugLog:[[NSString alloc] initWithFormat:@"There is no persisted data for notification: %@",name]];
                }
            }
            
            [self debugLog:[[NSString alloc] initWithFormat:@"Succesfully parsed notification plist"]];
            
            //Call update to start the notifications
            [self update];
            
            return YES;
        }
        else
        {
            //Failed to parse plist
            [self debugLog:[[NSString alloc] initWithFormat:@"Failed to parse Plist file"]];
        }
    }
    else
    {
        [self debugLog:[[NSString alloc] initWithFormat:@"Failed to load PList as file doesnt exist: %@", resourcePath]];
    }
    
    return NO;
}



#pragma mark -
#pragma mark Debug log

-(void)debugLog:(NSString*)message
{
    if (_debugLoggingEnabled)
        NSLog(@"OSNotificationScheduler: %@",message);
}

@end
