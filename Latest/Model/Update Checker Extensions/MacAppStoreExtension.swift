//
//  MacAppStoreExtension.swift
//  Latest
//
//  Created by Max Langer on 07.04.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Foundation

/**
 This is the Mac App Store Extension for update checking.
 It checks for the presence an App Store receipt in the app bundle and then loads the iTunes feed, which will then be parsed.
 */
extension UpdateChecker {
    
    /**
     Tries to update the app through the Mac App Store. In case of success, the app object is created and delegated.
     - returns: A Boolean indicating if the app is updated through the Mac App Store
     */
    func updatesThroughMacAppStore(app: URL, version: String, buildNumber: String) -> Bool {
        let appName = app.lastPathComponent as NSString

        let appBundle = Bundle(path: app.path)
        let fileManager = FileManager.default
        
        guard let receiptPath = appBundle?.appStoreReceiptURL?.path,
                  fileManager.fileExists(atPath: receiptPath) else { return false }
        
        // App is from Mac App Store
        let languageCode = Locale.current.regionCode ?? "US"

        guard let bundleIdentifier = appBundle?.bundleIdentifier,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleIdentifier)&country=\(languageCode)&entity=macSoftware&limit=1")
              else { return false }
        
        let appUpdate = MacAppStoreAppBundle(appName: appName.deletingPathExtension, versionNumber: version, buildNumber: buildNumber, url: app)

        if bundleIdentifier.contains("com.apple.InstallAssistant") {
            self.didFailToProcess(appUpdate)
            return true
        }
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        let dataTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard error == nil,
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                let results = json["results"] as? [Any],
                results.count != 0,
                let appData = results[0] as? [String: Any] else {
                    appUpdate.newestVersion.releaseNotes = error
                    self.didFailToProcess(appUpdate)
                    return
            }
            
            appUpdate.delegate = self
            appUpdate.parse(data: appData)
        }
        
        dataTask.resume()
        
        return true
    }
}
