//
//  MLMAppUpdater.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

protocol MLMAppUpdateDelegate : class {
    
    func checkerDidFinishChecking(_ app: MLMAppUpdate)
    
}

class MLMAppUpdate : NSObject, NSFilePresenter {
    
    var version: MLMVersion!
    var appName = ""
    var appURL: URL?
    
    weak var delegate : MLMAppUpdateDelegate?
    
    var currentVersion: MLMVersionInfo?
    
    var dateFormatter: DateFormatter!
    
    init(appName: String, versionNumber: String?, buildNumber: String?) {
        self.version = MLMVersion(versionNumber ?? "", buildNumber ?? "")
        self.appName = appName
    }
    
    func printDebugDescription() {
        print("-----------------------")
        print("Debug description for app \(appName)")
        print("Version number: \(version?.versionNumber ?? "not given")")
        print("Build number: \(version?.buildNumber ?? "not given")")
    }
    
    static func ==(lhs: MLMAppUpdate, rhs: MLMAppUpdate) -> Bool {
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
