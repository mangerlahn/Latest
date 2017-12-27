//
//  AppUpdater.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

protocol AppUpdateDelegate : class {
    func checkerDidFinishChecking(_ app: AppUpdate)
}

class AppUpdate : NSObject, NSFilePresenter {
    
    var version: Version!
    var appName = ""
    var appURL: URL?
    
    weak var delegate : AppUpdateDelegate?
    
    var currentVersion: VersionInfo?
    
    var dateFormatter: DateFormatter!
    
    init(appName: String, versionNumber: String?, buildNumber: String?) {
        self.version = Version(versionNumber ?? "", buildNumber ?? "")
        self.appName = appName
    }
    
    func printDebugDescription() {
        print("-----------------------")
        print("Debug description for app \(appName)")
        print("Version number: \(version?.versionNumber ?? "not given")")
        print("Build number: \(version?.buildNumber ?? "not given")")
    }
    
    static func ==(lhs: AppUpdate, rhs: AppUpdate) -> Bool {
        return lhs.appName == rhs.appName && lhs.appURL == rhs.appURL
    }
    
    // MARK: - NSFilePresenter
    
    var presentedItemURL: URL? {
        return self.appURL
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return .main
    }
    
    func presentedSubitemDidChange(at url: URL) {
        guard url.pathExtension == "plist",
            let infoDict = NSDictionary(contentsOf: url),
            let version = infoDict["CFBundleShortVersionString"] as? String,
            let buildNumber = infoDict["CFBundleVersion"] as? String else { return }

        self.version.versionNumber = version
        self.version.buildNumber = buildNumber
        
        self.delegate?.checkerDidFinishChecking(self)
    }
    
}
