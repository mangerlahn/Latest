//
//  SparkleExtension.swift
//  Latest
//
//  Created by Max Langer on 07.04.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Foundation

/**
 This is the Sparkle Extension for update checking.
 It reads the feed URL from the app bundle and then loads the sparkle feed, which will then be parsed.
 */
extension UpdateChecker {
    
    /**
     Tries to update the app through the Sparkle mechanism. In case of success, the app object is created and delegated.
     - returns: A Boolean indicating if the app is updated through Sparkle
     */
    func updatesThroughSparkle(app: URL, version: String, buildNumber: String) -> Bool {
        let appName = app.lastPathComponent as NSString
        let bundle = Bundle(path: app.path)
        
        guard let information = bundle?.infoDictionary, let identifier = bundle?.bundleIdentifier else {
            return false
        }
        
        var url: URL
        
        if let urlString = information["SUFeedURL"] as? String, let feedURL = URL(string: urlString)  {
            url = feedURL
        } else { // Maybe the app is built using DevMate
            // Check for the DevMate framework
            let frameworksURL = URL(fileURLWithPath: app.path, isDirectory: true).appendingPathComponent("Contents").appendingPathComponent("Frameworks")
            
            let frameworks = try? self.fileManager.contentsOfDirectory(atPath: frameworksURL.path)
            if !(frameworks?.contains(where: { $0.contains("DevMateKit") }) ?? false) {
                return false
            }
            
            // The app uses Devmate, so lets get the appcast from their servers
            guard var feedURL = URL(string: "https://updates.devmate.com") else {
                return false
            }
            
            feedURL.appendPathComponent(identifier)
            feedURL.appendPathExtension("xml")
            
            url = feedURL
        }

        let appBundle = SparkleAppBundle(appName: appName.deletingPathExtension, bundleIdentifier: identifier, versionNumber: version, buildNumber: buildNumber, url: app)
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            if error == nil,
                let xmlData = data {

                let parser = XMLParser(data: xmlData)

                parser.delegate = appBundle
                appBundle.delegate = self

                if !parser.parse() {
                    self.didFailToProcess(appBundle)
                }
            } else {
                appBundle.newestVersion.releaseNotes = error
                self.didFailToProcess(appBundle)
            }
        })
        
        task.resume()
        
        return true
    }
    
}
