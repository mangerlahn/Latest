//
//  SUUpdater+Private.h
//  Latest
//
//  Created by Max Langer on 04.08.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//


#import <Sparkle/Sparkle.h>

NS_ASSUME_NONNULL_BEGIN

@class SUUpdateDriver, SUBasicUpdateDriver;

/*!
 @abstract Expose some private methods and properties of SUUpdater.
 */
@interface SUUpdater (Private)

/*!
 @abstract The driver handling the update mechanism.
 */
@property (strong, nullable, readonly) SUBasicUpdateDriver *driver;

/*!
 @abstract Initializes the update process.
 */
- (void)checkForUpdatesWithDriver:(SUUpdateDriver *)driver;

/*!
 @abstract Starts automatic updating mechanism.
 */
- (void)startUpdateCycle;

/*!
 @abstract A method that shedules an update check at a defined point of time in the future.
 */
- (void)scheduleNextUpdateCheck;

@end

NS_ASSUME_NONNULL_END
