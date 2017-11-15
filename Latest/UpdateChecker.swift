//
//  UpdateChecker.swift
//  Latest
//
//  Created by Max Langer on 07.04.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Foundation

protocol UpdateCheckerProgress : class {
    func startChecking(numberOfApps: Int)
    func didCheckApp()
}

struct UpdateChecker {
 
    weak var progressDelegate : UpdateCheckerProgress?
    weak var appUpdateDelegate : AppUpdateDelegate?
    
    private let _updateMethods : [(UpdateChecker) -> (String) -> Bool] = [
        updatesThroughMacAppStore,
        updatesThroughSparkle
    ]
    
    var applicationURL : URL? {
        let fileManager = FileManager.default
        let applicationURLList = fileManager.urls(for: .applicationDirectory, in: .localDomainMask)
        
        return applicationURLList.first
    }
    
    private var _applicationPath : String {
        return applicationURL?.path ?? "/Applications/"
    }
    
    func run() {
        let fileManager = FileManager.default
        guard var apps = try? fileManager.contentsOfDirectory(atPath: _applicationPath) else { return }
        
        self.progressDelegate?.startChecking(numberOfApps: apps.count)
        
        for method in _updateMethods {
            apps = apps.filter({ (file) -> Bool in
                return !method(self)(file)
            })
        }
        
        for _ in apps {
            self.progressDelegate?.didCheckApp()
        }
    }
    
}
