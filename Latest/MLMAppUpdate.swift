//
//  MLMAppUpdater.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

class Version {
    var newVersion = ""
    
    var version : String? {
        return newVersion == "" ? nil : newVersion
    }
    
    var shortVersion : String?

    var date : Date?
    
    var releaseNotes: Any?
}

protocol MLMAppUpdateDelegate : class {
    func checkerDidFinishChecking(_ app: MLMAppUpdate)
}

class MLMAppUpdate : NSObject {
    
    var shortVersion: String?
    var version: String?
    var appName = ""
    var appURL: URL?
    
    weak var delegate : MLMAppUpdateDelegate?
    
    var currentVersion: Version?
    
    var dateFormatter: DateFormatter!
    
    init(appName: String, shortVersion: String?, version: String?) {    
        self.appName = appName
        self.shortVersion = shortVersion
        self.version = version
    }
    
    func printDebugDescription() {
        print("-----------------------")
        print("Debug description for app \(appName)")
        print("Short version: \(shortVersion ?? "not given")")
        print("Version: \(version ?? "not given")")
    }
}
