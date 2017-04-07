//
//  MLMSparkleExtension.swift
//  Latest
//
//  Created by Max Langer on 07.04.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Foundation

extension MLMUpdateChecker {
    
    func updatesThroughSparkle(app: String) -> Bool {
        let appName = app as NSString
        
        guard appName.pathExtension == "app", let applicationURL = self.applicationURL else {
            return false
        }
        
        let appPath = applicationURL.appendingPathComponent(app).path

        let bundle = Bundle(path: appPath)
        
        
        guard let information = bundle?.infoDictionary,
            let urlString = information["SUFeedURL"] as? String,
            let url = URL(string: urlString) else {
                return false
        }

        let session = URLSession(configuration: URLSessionConfiguration.default)

        let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
            if error == nil,
                let xmlData = data {

                let shortVersionString = information["CFBundleShortVersionString"] as? String
                let versionString = information["CFBundleVersion"] as? String

                let parser = XMLParser(data: xmlData)
                let checker = MLMAppUpdate(appName: appName.deletingPathExtension, shortVersion: shortVersionString, version: versionString)

                parser.delegate = checker
                checker.delegate = self.appUpdateDelegate
                checker.appURL = applicationURL.appendingPathComponent(app)

                parser.parse()
            }
        })
        
        task.resume()
        
        return true
    }
    
}
