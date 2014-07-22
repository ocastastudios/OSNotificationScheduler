//
//  OSNotificationDescriptor.h
//  OSNotificationScheduler
//
//  Created by Chris Birch on 05/04/2013.
//  Copyright (c) 2013 Ocasta Studios. All rights reserved.
//


/**
 * Describes a notification used by OSNotificationScheduler
 */

#import <Foundation/Foundation.h>


#define STORED_DATA_KEY_TIMER_STARTED_DATE @"timerStartedDate"
#define STORED_DATA_KEY_LAST_FIRED_DATE @"lastFiredDate"


@interface OSNotificationDescriptor : NSObject

/**
 * The name of the notification
 */
@property(nonatomic,strong) NSString* name;
/**
 * The description of the notification
 */
@property (nonatomic,strong) NSString* notificationDescription;
/**
 * The interval in seconds that the notification should fire
 */
@property (nonatomic,assign) NSTimeInterval interval;
/**
 * Describes whether or not the notification should fire only once in the lifetime of the app
 */
@property (nonatomic,assign) BOOL oneTimeOnly;
/**
 * Describes whether or not the notification is enabled
 */
@property (nonatomic,assign) BOOL enabled;

/**
 * If NO means that the notification will not fire automatically but can tested manually with shouldNotify function
 */
@property (nonatomic,assign) BOOL causesNotificationGeneration;

/**
 * If the notification has been fired before, this will be set to that date.
 * If it has not fired then this will be nil
 */
@property(nonatomic,readonly) NSDate* lastFired;


/**
 * The datetime that this notification was started.
 * If it has not been started then this will be nil
 */
@property(nonatomic,readonly) NSDate* startedDate;

/**
 * This is the number of seconds left until this notification is fired again.
 * returns -1 if not enabled
 */
@property(nonatomic,readonly) NSTimeInterval intervalUntilNextFire;

/**
 * Should we wait the interval before first firing this event?
 */
@property (nonatomic,assign) BOOL shouldWaitIntervalBeforeFirstFire;

/**
 * A dictionary containing custom information about this notification. This is passed via NSNotificationCentre
 */
@property (nonatomic,strong) NSMutableDictionary* userInfo;

/**
 * Object passed along with created NSNotification
 */
@property(nonatomic,strong) id object;

/**
 * Returns YES if this notification is ready to be triggered. It only makes sense to query this
 * when dealing with notifications that don't automatically fire based on time. i.e CausesNotificationGeneration == NO.
 * NB! If YES is returned, this has the side effect of setting the lastFiredDate for the notification, so calling shouldNotify again
 * will result in NO being returned!
 */
@property (nonatomic,readonly) BOOL shouldNotify;



#pragma mark -
#pragma mark The following are not to be directly set by user code

/**
 * Holds data about this descriptor that is persisted to NSUserDefaults
 */
@property (nonatomic,strong) NSMutableDictionary* storedData;

#pragma mark -
#pragma mark Public functions


/**
 * Deletes the all data stored about this notification. Useful when dealing with OneTimeOnly notifications
 */
-(void)deleteStoredData;






@end
