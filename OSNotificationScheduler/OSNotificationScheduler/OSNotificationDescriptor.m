//
//  OSNotificationDescriptor.m
//  OSNotificationScheduler
//
//  Created by Chris Birch on 05/04/2013.
//  Copyright (c) 2013 Ocasta Studios. All rights reserved.
//

#import "OSNotificationDescriptor.h"


#pragma mark -
#pragma mark Friend stuff



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


#pragma mark -
#pragma mark OSNotificationDescriptor implementation

@implementation OSNotificationDescriptor

-(id)init
{
    if (self = [super init])
    {
        _userInfo = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}


#pragma mark -
#pragma mark Properties

-(NSString *)description
{
    NSString* enabledString = _enabled ? @"YES" : @"NO";
    NSString* manuallyTested =!_causesNotificationGeneration ? @"YES" : @"NO";
    NSString* oneTimeOnly = _oneTimeOnly ? @"YES" : @"NO";
    
    return [[NSString alloc] initWithFormat:@"OSNotificationDescriptor: %@ {Interval=%.2f Enabled=%@, ManuallyTested=%@, OneTimeOnly=%@}", _name,_interval,enabledString,manuallyTested,oneTimeOnly];
}

-(NSDate *)lastFired
{
    NSDate* lastFiredDate=nil;
    //first we need to check if we have passed the lastFiredDate + interval
    if ([_storedData.allKeys containsObject:STORED_DATA_KEY_LAST_FIRED_DATE])
    {
        lastFiredDate = [_storedData objectForKey:STORED_DATA_KEY_LAST_FIRED_DATE];
    }
    
    return lastFiredDate;
}


-(NSDate *)startedDate
{
    NSDate* startedDate=nil;
    //first we need to check if we have set this
    
    if ([_storedData.allKeys containsObject:STORED_DATA_KEY_TIMER_STARTED_DATE])
    {
        startedDate = [_storedData objectForKey:STORED_DATA_KEY_TIMER_STARTED_DATE];
    }
    
    return startedDate;
}

-(BOOL)shouldNotify
{
    if (_enabled)
    {
        BOOL result = self.intervalUntilNextFire <=0;
        
        if (result)
        {
            [self __setLastFiredDate];
            return YES;
        }
        else
            return NO;
    }
    else
        return NO;
}

-(NSTimeInterval)intervalUntilNextFire
{
    if (_enabled)
    {

        NSDate* lastFiredDate=self.lastFired;
        NSDate* startedDate = self.startedDate;
        
        //first we need to check if we have passed the lastFiredDate + interval
        //this takes priority over startedDate because we may have loaded the app from cold start
        //and not been running for an extended period
        if (lastFiredDate)
        {
            //if we have already fired once and this is a onetime only notification
            if (_oneTimeOnly)
                return -1;
            
            NSTimeInterval timeSinceLastFired = [lastFiredDate timeIntervalSinceNow];
            
            if (timeSinceLastFired < 0)
                timeSinceLastFired *= -1; //invert
            
            if (timeSinceLastFired >= _interval)
            {
                //we should fire immediately
                return 0;
            }
            else
            {
                NSTimeInterval timeLeft = _interval - timeSinceLastFired;
                return timeLeft;
            }
        }
        else if (startedDate)
        {
            //work out when the timer has elapsed
            
            NSDate* fireDate = [NSDate dateWithTimeInterval:_interval sinceDate:startedDate];
            NSDate* now = [NSDate date];
            
            NSTimeInterval tillNextFire =  fireDate.timeIntervalSince1970 - now.timeIntervalSince1970;
            
            if (tillNextFire <=0)
                return 0;
            else
                return tillNextFire;
            
        }
        else if(!_shouldWaitIntervalBeforeFirstFire)
        {
            //start immediately
            return 0;
        }
        else
        {
            //just wait interval
            return _interval;
        }
    
    }

    //We arent enabled or havent been started yet
    return -1;
}


#pragma mark -
#pragma mark Public functions

-(void)deleteStoredData
{
    [_storedData removeAllObjects];

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    [defaults removeObjectForKey:_name];
    [defaults synchronize];
}


#pragma mark -
#pragma mark Shouldnt be called by user code

-(BOOL)__saveData
{
    if (_name && ![_name isEqualToString:@""])
    {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:_storedData forKey:_name];
        return [defaults synchronize];
    }

    return NO;
}

-(BOOL)__loadPersistedData
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary* storedData = [defaults dictionaryForKey:_name];
    
    if (storedData)
    {
        _storedData = [storedData mutableCopy];
        return YES;
    }
    else
    {
        _storedData = [[NSMutableDictionary alloc] init];
        return NO;
    }
}

-(void)__setLastFiredDate
{
    //Save the last time that we fired
    [_storedData setObject:[NSDate date] forKey:STORED_DATA_KEY_LAST_FIRED_DATE];
    [self __saveData];
}

-(void)__setTimerStartedDate:(NSDate*)startedDate
{
    //Save the time that the timer started
    [_storedData setObject:startedDate forKey:STORED_DATA_KEY_TIMER_STARTED_DATE];
    [self __saveData];
}



@end
