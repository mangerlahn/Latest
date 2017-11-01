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
                  fileManager.fileExists(atPath: receiptPath) else { return false }
        
        // App is from Mac App Store
        let languageCode = Locale.current.regionCode ?? "US"

        guard let bundleIdentifier = appBundle?.bundleIdentifier,
              let information = appBundle?.infoDictionary,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleIdentifier)&country=\(languageCode)&entity=macSoftware&limit=1")
              else { return false }
        
        if bundleIdentifier.contains("com.apple.InstallAssistant") {
            self.progressDelegate?.didCheckApp()
            return true
        }
        
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        let dataTask = session.dataTask(with: request) { (data, response, error) in
            guard error == nil,
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                let results = json?["results"] as? [Any],
                results.count != 0,
                let appData = results[0] as? [String: Any] else {
                    DispatchQueue.main.async {
                        self.progressDelegate?.didCheckApp()
                    }
                    
                    return
            }
            
            let versionNumber = information["CFBundleShortVersionString"] as? String
            let buildNumber = information["CFBundleVersion"] as? String
            
            let appUpdate = MLMMacAppStoreAppUpdate(appName: appName.deletingPathExtension, versionNumber: versionNumber, buildNumber: buildNumber)
            appUpdate.delegate = self.appUpdateDelegate
            appUpdate.appURL = applicationURL.appendingPathComponent(app)
            appUpdate.parse(data: appData)
        }
        
        dataTask.resume()
        
        return true
    }
}
