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
    func updatesThroughSparkle(app: String, version: String, buildNumber: String) -> Bool {
        let appName = app as NSString
        
        guard appName.pathExtension == "app", let applicationURL = self.applicationURL else {
            return false
        }
        
        let appPath = applicationURL.appendingPathComponent(app).path

        let bundle = Bundle(path: appPath)
        
        guard let information = bundle?.infoDictionary else {
            return false
        }
        
        var url: URL
        
        if let urlString = information["SUFeedURL"] as? String, let feedURL = URL(string: urlString)  {
            url = feedURL
        } else { // Maybe the app is built using DevMate
            // Check for the DevMate framework
            let frameworksURL = URL(fileURLWithPath: appPath, isDirectory: true).appendingPathComponent("Contents").appendingPathComponent("Frameworks")
            
            let frameworks = try? self.fileManager.contentsOfDirectory(atPath: frameworksURL.path)
            if !(frameworks?.contains(where: { $0.contains("DevMateKit") }) ?? false) {
                return false
            }
            
            // The app uses Devmate, so lets get the appcast from their servers
            guard let identifier = bundle?.bundleIdentifier,
                var feedURL = URL(string: "https://updates.devmate.com") else {
                return false
            }
            
            feedURL.appendPathComponent(identifier)
            feedURL.appendPathExtension("xml")
            
            url = feedURL
        }

        let session = URLSession(configuration: URLSessionConfiguration.default)
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        let task = session.dataTask(with: request, completionHandler: { (data, response, error) in
            if error == nil,
                let xmlData = data {

                let parser = XMLParser(data: xmlData)
                let checker = SparkleAppBundle(appName: appName.deletingPathExtension, versionNumber: version, buildNumber: buildNumber)

                parser.delegate = checker
                checker.delegate = self.appUpdateDelegate
                checker.appURL = applicationURL.appendingPathComponent(app)

                parser.parse()
            } else {
                DispatchQueue.main.async {
                    self.progressDelegate?.didCheckApp()
                }
            }
        })
        
        task.resume()
        
        return true
    }
    
}
