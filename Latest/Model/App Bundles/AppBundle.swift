//
//  AppUpdater.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

/**
 Delegate Protocol defining functions for changes of an app update
 */
protocol AppBundleDelegate {
    
    /**
     The version information of the AppUpdate changed. This can euther be the version or currentVersion parameter
     
     - parameter app: The app update with updated information
     */
    mutating func appDidUpdateVersionInformation(_ app: AppBundle)
}

/**
 The class containing information about one specific app. It holds information like its current version, name and path.
 */
class AppBundle : NSObject {
    
    /// The version currently present on the users computer
    var version: Version!
    
    /// The display name of the app
    var name = ""
    
    /// The url of the app on the users computer
    var url: URL?
    
    /// The delegate to be notified when app information changes
    var delegate : AppBundleDelegate?
    
    /// The newest information available for this app
    var newestVersion: UpdateInfo?
    
    /**
     Convenience initializer for creating an app object
     - parameter name: The name of the app
     - parameter versionNumber: The current version number of the app
     - parameter buildNumber: The current build number of the app
     */
    init(appName: String, versionNumber: String?, buildNumber: String?) {
        self.version = Version(versionNumber ?? "", buildNumber ?? "")
        self.name = appName
    }
    
    /// Compares two apps on equality
    static func ==(lhs: AppBundle, rhs: AppBundle) -> Bool {
        return lhs.name == rhs.name && lhs.url == rhs.url
    }
    
    
    // MARK: - Actions
    
    /// Opens the app and a given index
    func open() {
        var appStoreURL : URL?
        
        if let appStoreApp = self as? MacAppStoreAppBundle {
            appStoreURL = appStoreApp.appStoreURL
        }
        
        guard let url = appStoreURL ?? self.url else {
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    /// Reveals the app at a given index in Finder
    func showInFinder() {
        guard let url = self.url else { return }
        
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    
    // MARK: - Debug
    
    func printDebugDescription() {
        print("-----------------------")
        print("Debug description for app \(name)")
        print("Version number: \(version?.versionNumber ?? "not given")")
        print("Build number: \(version?.buildNumber ?? "not given")")
    }
    
}
