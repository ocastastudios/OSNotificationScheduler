//
//  OSNotificationScheduler.h
//  OSNotificationScheduler
//
//  Created by Chris Birch on 05/04/2013.
//  Copyright (c) 2013 Ocasta Studios. All rights reserved.
//


/**
 * Used for firing notifications at regular intervals.
 * Example use could be a notification that fires once a day to open an alertview reminding the user of something.
 *
 * Can define these notifications programatically or in a plist named "OSNotificationScheduler.plist" 
 * included in the bundle.
 * 
 * Another way to use this is to register the notification and then set its CausesNotificationGeneration property to NO, this will stop
 * noticiations from being generated and user code can test the notification manually using a shouldNotify function variant or a notificationDescriptors shouldNotify property
 */


#import <Foundation/Foundation.h>
#import "OSNotificationDescriptor.h"


/**
 * Block used for responding to notifications
 */
typedef void(^OSNotificationBlock)(OSNotificationDescriptor* notificationDescriptor);


@interface OSNotificationScheduler : NSObject

@property (nonatomic,strong) NSArray* notifications;

@property (nonatomic,assign) BOOL enabled;

/**
 * YES if we should print verbose logging info to console
 */
@property (nonatomic,assign) BOOL debugLoggingEnabled;


#pragma mark -
#pragma mark Shared instance

/**
 * Gets a pointer to the shared instance
 */
+(OSNotificationScheduler*)shared;

#pragma mark -
#pragma mark Block registration

/**
 * Registers the specified block to deal with notifications for the specified name. 
 * Many blocks may be registered for per notification. Make sure you provide unique tag names.
 * NO will be returned if the tag name has allready been registered for that notification.
 */
-(BOOL)registerNotificationName:(NSString*)notificationName withHandlerTag:(NSString*)handlerTag andHandler:(OSNotificationBlock)handler;

/**
 * Unregisters all block handlers for the specified notification name that were previously registered
 * with the registerNotificationName:withHandlerTag:andHandler: function
 */
-(BOOL)unregisterAllBlocksForNotificationName:(NSString*)notificationName;

/**
 * Unregisters the block handler for the specified notification name and tag that was previously registered
 * with the registerNotificationName:withHandlerTag:andHandler: function
 */
-(BOOL)unregisterBlockForNotificationName:(NSString*)notificationName andHandlerTag:(NSString*)handlerTag;


#pragma mark -
#pragma mark Manual checking of notifications

/**
 * Returns YES if the notification with the specified name is ready to be triggered. It only makes sense to call
 * this function when dealing with notifications that dont automatically fire based on time. i.e CausesNotificationGeneration == NO.
 * NB! If YES is returned, this has the side effect of setting the lastFiredDate for the notification, so calling shouldNotify again
 * will result in NO being returned!
 */
-(BOOL)shouldNotifyWithNotificationName:(NSString*)notificationName;

/**
 * Returns YES if the notification with the specified name is ready to be triggered. It only makes sense to call
 * this function when dealing with notifications that dont automatically fire based on time. i.e CausesNotificationGeneration == NO
 * NB! If YES is returned, this has the side effect of setting the lastFiredDate for the notification, so calling shouldNotify again
 * will result in NO being returned!
 */
-(BOOL)shouldNotifyWithNotificationDescriptior:(OSNotificationDescriptor*)notification;


#pragma mark -
#pragma mark Descriptor search
/**
 * Returns the descriptor for the specified notification name. If no descriptor exists, nil is returned
 */
-(OSNotificationDescriptor*)notificationDescriptorForNotificationName:(NSString*)name;

#pragma mark -
#pragma mark Update

/**
 * Causes changes to notifcations to be persisted and notifications to be started.
 * You must call this after any calls to addNotification or removeNotification.
 * Failure to comply with this will result in invalid notifications being fired or
 * valid notifications not being fired.
 */
-(void)update;

#pragma mark -
#pragma mark Add/Remove


/**
 * Adds a notification and returns YES if succesful.
 * Be sure to call update function when finished adding all notifications. Failure to do so
 * will result in no notifications being fired.
 */
-(BOOL)addNotification:(OSNotificationDescriptor*)descriptor;

/**
 * Removes a notification and returns YES if succesful
 * Be sure to call update function when finished removing all notifications. Failure to do so
 * will result in old notifications being fired.
 */
-(BOOL)removeNotification:(OSNotificationDescriptor*)descriptor;

#pragma mark -
#pragma mark Plist Stuff

/**
 * Loads the notifications from the plist named "OSNotificationScheduler.plist"
 */
-(BOOL)loadPlist;


@end
