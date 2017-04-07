//
//  MLMMacAppStoreExtension.swift
//  Latest
//
//  Created by Max Langer on 07.04.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Foundation

extension MLMUpdateChecker {
    func updatesThroughMacAppStore(app: String) -> Bool {
        let appName = app as NSString
        
        guard appName.pathExtension == "app", let applicationURL = self.applicationURL else {
            return false
        }
        
        let appPath = applicationURL.appendingPathComponent(app).path
        let appBundle = Bundle(path: appPath)
        let fileManager = FileManager.default
        
        guard let receiptPath = appBundle?.appStoreReceiptURL?.path,
            fileManager.fileExists(atPath: receiptPath) else {
            return false
        }
        
        // App is from Mac App Store
        
        return true
    }
}
