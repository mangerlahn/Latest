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
protocol AppBundleDelegate : class {
    
    /**
     The version information of the AppUpdate changed. This can euther be the version or currentVersion parameter
     
     - parameter app: The app update with updated information
     */
    func appDidUpdateVersionInformation(_ app: AppBundle)
}

/**
 The class containing information about one specific app. It holds information like its current version, name and path.
 */
class AppBundle : NSObject, NSFilePresenter {
    
    /// The version currently present on the users computer
    var version: Version!
    
    /// The display name of the app
    var appName = ""
    
    /// The url of the app on the users computer
    var appURL: URL?
    
    /// The delegate to be notified when app information changes
    weak var delegate : AppBundleDelegate?
    
    /// The newest information available for this app
    var newestVersion: UpdateInfo?
    
    /**
     Convenience initializer for creating an app object
     - parameter appName: The name of the app
     - parameter versionNumber: The current version number of the app
     - parameter buildNumber: The current build number of the app
     */
    init(appName: String, versionNumber: String?, buildNumber: String?) {
        self.version = Version(versionNumber ?? "", buildNumber ?? "")
        self.appName = appName
    }
    
    /// Compares two apps on equality
    static func ==(lhs: AppBundle, rhs: AppBundle) -> Bool {
        return lhs.appName == rhs.appName && lhs.appURL == rhs.appURL
    }
    
    
    // MARK: - NSFilePresenter
    
    /// Returns the url of the file to be observed
    var presentedItemURL: URL? {
        return self.appURL
    }
    
    /// The queue on which the change handlers should be delegated on
    var presentedItemOperationQueue: OperationQueue {
        return .main
    }
    
    /// The app bundle changed in any way
    func presentedSubitemDidChange(at url: URL) {
        // Check, if the changed file was the Info.plist
        guard url.pathExtension == "plist",
            let infoDict = NSDictionary(contentsOf: url),
            let version = infoDict["CFBundleShortVersionString"] as? String,
            let buildNumber = infoDict["CFBundleVersion"] as? String else { return }

        // Update the build and version number of the app with the new information from the plist file
        self.version.versionNumber = version
        self.version.buildNumber = buildNumber
        
        self.delegate?.appDidUpdateVersionInformation(self)
    }
    
    
    // MARK: - Debug
    
    func printDebugDescription() {
        print("-----------------------")
        print("Debug description for app \(appName)")
        print("Version number: \(version?.versionNumber ?? "not given")")
        print("Build number: \(version?.buildNumber ?? "not given")")
    }
    
}
