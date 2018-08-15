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
    var url: URL
    
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
    init(appName: String, versionNumber: String?, buildNumber: String?, url: URL) {
        self.version = Version(versionNumber ?? "", buildNumber ?? "")
        self.name = appName
        self.url = url
    }
    
    var updateAvailable: Bool {
        if let version = self.newestVersion, version.version > self.version {
            return true
        }
        
        return false
    }
    
    
    // MARK: - Actions
    
    /// Opens the app and a given index
    func open() {
        var appStoreURL : URL?
        
        if let appStoreApp = self as? MacAppStoreAppBundle {
            appStoreURL = appStoreApp.appStoreURL
        }
        
        let url = appStoreURL ?? self.url
        NSWorkspace.shared.open(url)
    }
    
    /// Reveals the app at a given index in Finder
    func showInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([self.url])
    }
    
    
    // MARK: - Debug
    
    func printDebugDescription() {
        print("-----------------------")
        print("Debug description for app \(name)")
        print("Version number: \(version?.versionNumber ?? "not given")")
        print("Build number: \(version?.buildNumber ?? "not given")")
    }
    
}

// Version String Handling
extension AppBundle {
    
    /// A container holding the current and new version information
    struct DisplayableVersionInformation {
        
        /// The localized version of the app present on the computer
        var current: String {
            return String(format:  NSLocalizedString("Your version: %@", comment: "Current Version String"), "\(self.rawCurrent)")
        }
        
        /// The new available version of the app
        var new: String {
            return String(format: NSLocalizedString("New version: %@", comment: "New Version String"), "\(self.rawNew)")
        }
        
        fileprivate var rawCurrent: String
        fileprivate var rawNew: String
        
    }
    
    var localizedVersionInformation: DisplayableVersionInformation? {
        guard let info = self.newestVersion else { return nil }
    
        var versionInformation: DisplayableVersionInformation?
        
        if let v = self.version.versionNumber, let nv = info.version.versionNumber {
            versionInformation = DisplayableVersionInformation(rawCurrent: v, rawNew: nv)
        
            // If the shortVersion string is identical, but the bundle version is different
            // Show the Bundle version in brackets like: "1.3 (21)"
            if self.updateAvailable, v == nv, let v = self.version?.buildNumber, let nv = info.version.buildNumber {
                versionInformation?.rawCurrent += " (\(v))"
                versionInformation?.rawNew += " (\(nv))"
            }
        } else if let v = self.version.buildNumber, let nv = info.version.buildNumber {
            versionInformation = DisplayableVersionInformation(rawCurrent: v, rawNew: nv)
        }
        
        return versionInformation
    }
    
}

extension AppBundle {
    /// Compares two apps on equality
    static func ==(lhs: AppBundle, rhs: AppBundle) -> Bool {
        return lhs.name == rhs.name && lhs.url == rhs.url
    }
}
