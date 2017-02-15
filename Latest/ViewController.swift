//
//  ViewController.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

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
                    let versionString = plistData["CFBundleShortVersionString"] as? String,
                    let urlString = plistData["SUFeedURL"] as? String,
                    let url = URL(string: urlString) {
                    
                    let session = URLSession(configuration: URLSessionConfiguration.default)
                    
                    let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
                        if error == nil,
                            let xmlData = data,
                            let xml = String(data: xmlData, encoding: String.Encoding.utf8) {
                            
                            if let newVersionString = self.version(for: "sparkle:shortVersionString=\"", in: xml) {
                                if newVersionString != versionString {
                                    print("App \(file) is not up to date. The new version is \(newVersionString), your version is \(versionString)")
                                }
                            } else if let newVersionString = self.version(for: "sparkle:version=\"", in: xml),
                                versionString != newVersionString {
                                print("App \(file) is not up to date. The new version is \(newVersionString), your version is \(versionString)")
                            }
                        }
                    })
                    
                    task.resume()
                }
            }
        })
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    private func version(for query: String, in xml: String) -> String? {
        var lowerBounds = [Range<String.Index>?]()
        
        var returnString : String?
        
        lowerBounds.append(xml.range(of: query))
        
        lowerBounds.forEach({ (element) in
            if let lowerBound = element {
                var newVersion = xml.substring(from: lowerBound.upperBound)
                
                if let upperBound = newVersion.range(of: "\"") {
                    newVersion = newVersion.substring(to: upperBound.lowerBound)
                    
                    returnString = newVersion
                }
            }
        })
        
        return returnString
    }

}

