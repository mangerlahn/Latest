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
class UpdateChecker {
    
    typealias UpdateCheckerCallback = (_ newVersionAvailable: Bool, _ app: AppBundle) -> Void
    
    /// The callback called after every update check
    var didFinishCheckingAppCallback: UpdateCheckerCallback?
    
    /// The delegate for the progress of the entire update checking progress
    weak var progressDelegate : UpdateCheckerProgress?
    
    /// The methods that are executed upon each app
    private let updateMethods : [(UpdateChecker) -> (String, String, String) -> Bool] = [
        updatesThroughMacAppStore,
        updatesThroughSparkle
    ]
    
    private var folderListener : FolderUpdateListener?
    
    /// The url of the /Applications folder on the users Mac
    var applicationURL : URL? {
        let applicationURLList = self.fileManager.urls(for: .applicationDirectory, in: .localDomainMask)
        
        return applicationURLList.first
    }
    
    /// The path of the users /Applications folder
    private var applicationPath : String {
        return applicationURL?.path ?? "/Applications/"
    }
    
    /// A number indicating the number of apps that remain to be checked
    private var remainingApps = 0
    
    let lock = NSLock()
    
    /// A shared instance of the fileManager
    let fileManager = FileManager.default
    
    /// Starts the update checking process
    func run() {
        if self.remainingApps > 0 { return }
        
        if self.folderListener == nil, let url = self.applicationURL {
            self.folderListener = FolderUpdateListener(url: url, updateChecker: self)
        }
        
        self.folderListener?.resumeTracking()
        
        guard var apps = try? fileManager.contentsOfDirectory(atPath: self.applicationPath), let url = self.applicationURL else { return }
        apps = apps.filter({ $0.contains(".app") })
        
        let count = apps.count
        apps = apps.filter { (app) in
            let contentURL = url.appendingPathComponent(app).appendingPathComponent("Contents")
            
            // Check, if the changed file was the Info.plist
            guard let plists = try? FileManager.default.contentsOfDirectory(at: contentURL, includingPropertiesForKeys: nil)
                .filter({ $0.pathExtension == "plist" }),
                let plistURL = plists.first,
                let infoDict = NSDictionary(contentsOf: plistURL),
                let version = infoDict["CFBundleShortVersionString"] as? String,
                let buildNumber = infoDict["CFBundleVersion"] as? String else {
                    return true
            }
            
            // Perform check on whether the the app can be updated using the given method
            return !self.updateMethods.contains(where: { $0(self)(app, version, buildNumber) })
        }
        
        self.remainingApps = count - apps.count
        self.progressDelegate?.startChecking(numberOfApps: self.remainingApps)
    }
    
}

extension UpdateChecker: AppBundleDelegate {
    
    func appDidUpdateVersionInformation(_ app: AppBundle) {
        self.lock.lock()
        
        self.remainingApps -= 1
        self.progressDelegate?.didCheckApp()
        
        DispatchQueue.main.async {            
            if let versionBundle = app.newestVersion, versionBundle.version < app.version {
                self.didFinishCheckingAppCallback?(true, app)
                return
            }
            
            self.didFinishCheckingAppCallback?(false, app)
        }
        
        self.lock.unlock()
    }
    
    func didFailToUpdateApp() {
        DispatchQueue.main.async {
            self.remainingApps -= 1
            self.progressDelegate?.didCheckApp()
        }
    }
    
}
