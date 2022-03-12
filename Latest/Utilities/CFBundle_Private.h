//
//  CFBundle_Private.h
//  Latest
//
//  Created by Max Langer on 19.02.22.
//  Copyright © 2022 Max Langer. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
 @abstract Clears cache values on the given bundle object.
 
 @discussion This is private API and is subject to change in future OS versions. Check for availability prior to usage.
 Source: https://michelf.ca/blog/2010/killer-private-eraser/
 */
extern void _CFBundleFlushBundleCaches(CFBundleRef bundle) __attribute__((weak_import));
