//
//  VersionInfo.swift
//  Latest
//
//  Created by Max Langer on 01.11.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Foundation

/**
 A simple class holding the update information for a single update
 */
class UpdateInfo {
    
    /// The version of the updated app
    var version = Version()
    
    /// The release date of the update
    var date : Date?
    
    /// The release notes of the update
    var releaseNotes: Any?
    
}
