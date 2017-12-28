//
//  UpdateChecker.swift
//  Latest
//
//  Created by Max Langer on 07.04.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Foundation

/**
 Protocol that defines some methods on reporting the progress of the update checking process.
 */
protocol UpdateCheckerProgress : class {
    
    /**
     The process of checking apps for updates has started
     - parameter numberOfApps: The number of apps that will be checked
     */
    func startChecking(numberOfApps: Int)
    
    /// Indicates that a single app has been checked.
    func didCheckApp()
}

/**
 UpdateChecker handles the logic for checking for updates.
 Each new method of checking for updates should be implemented in its own extension and then included in the `updateMethods` array
 */
struct UpdateChecker {
 
    /// The delegate for the progress of the entire update checking progress
    weak var progressDelegate : UpdateCheckerProgress?
    
    /// The delegate that will be assigned to all AppBundles
    weak var appUpdateDelegate : AppBundleDelegate?
    
    /// The methods that are executed upon each app
    private let updateMethods : [(UpdateChecker) -> (String) -> Bool] = [
        updatesThroughMacAppStore,
        updatesThroughSparkle
    ]
    
    /// The url of the /Applications folder on the users Mac
    var applicationURL : URL? {
        let fileManager = FileManager.default
        let applicationURLList = fileManager.urls(for: .applicationDirectory, in: .localDomainMask)
        
        return applicationURLList.first
    }
    
    /// The path of the users /Applications folder
    private var applicationPath : String {
        return applicationURL?.path ?? "/Applications/"
    }
    
    /// Starts the update checking process
    func run() {
        let fileManager = FileManager.default
        guard var apps = try? fileManager.contentsOfDirectory(atPath: self.applicationPath) else { return }
        
        self.progressDelegate?.startChecking(numberOfApps: apps.count)
        
        for method in self.updateMethods {
            apps = apps.filter({ (file) -> Bool in
                return !method(self)(file)
            })
        }
        
        for _ in apps {
            self.progressDelegate?.didCheckApp()
        }
    }
    
}
