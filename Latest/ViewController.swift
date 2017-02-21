//
//  ViewController.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, UpdateCheckerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        let fileManager = FileManager.default
        let applicationURLList = fileManager.urls(for: .applicationDirectory, in: .localDomainMask)
        
        guard applicationURLList.count > 0,
            let applicationURL = applicationURLList.first,
            let apps = try? fileManager.contentsOfDirectory(atPath: applicationURL.path) else { return }
        
        apps.forEach({ (file) in
            if file.contains(".app") {
                let plistPath = applicationURL.appendingPathComponent(file)
                    .appendingPathComponent("Contents")
                    .appendingPathComponent("Info.plist").path
                
                if FileManager.default.fileExists(atPath: plistPath),
                    let plistData = NSDictionary(contentsOfFile: plistPath),
                    let urlString = plistData["SUFeedURL"] as? String,
                    let url = URL(string: urlString) {
                    
                    let session = URLSession(configuration: URLSessionConfiguration.default)
                    
                    let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
                        if error == nil,
                            let xmlData = data {
                            
                            let shortVersionString = plistData["CFBundleShortVersionString"] as? String
                            let versionString = plistData["CFBundleVersion"] as? String
                            
                            let parser = XMLParser(data: xmlData)
                            let checker = UpdateChecker(appName: file, shortVersion: shortVersionString, version: versionString)
                            
                            parser.delegate = checker
                            checker.delegate = self
                            
                            parser.parse()
                        }
                    })
                    
                    task.resume()
                }
            }
        })
    }
    
    func checkerDidFinishChecking(_ checker: UpdateChecker, newestVersion: Version) {
        if let currentVersion = checker.version, let newVersion = newestVersion.version, currentVersion != newVersion {
            print("\(checker.appName) is not up to date: \(currentVersion) vs \(newVersion)")
        }
    }

}

