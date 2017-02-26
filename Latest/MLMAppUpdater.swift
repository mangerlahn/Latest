//
//  MLMAppUpdater.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

class Version {
    fileprivate var newVersion = ""
    
    var version : String? {
        return newVersion == "" ? nil : newVersion
    }
    
    var shortVersion = ""
    var date : Date?
}

protocol MLMAppUpdaterDelegate : class {
    func checkerDidFinishChecking(_ checker: MLMAppUpdater, newestVersion: Version)
}

class MLMAppUpdater: NSObject, XMLParserDelegate {
    
    var shortVersion: String?
    var version: String?
    var appName = ""
    
    weak var delegate : MLMAppUpdaterDelegate?
    
    private var versions = [Version]()
    var currentVersion: Version?
    
    var dateFormatter: DateFormatter!
    
    convenience init(appName: String, shortVersion: String?, version: String?) {
        self.init()
    
        self.appName = appName
        self.shortVersion = shortVersion
        self.version = version
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale(identifier: "en_US")
        
        // Example of the date format: Mon, 28 Nov 2016 14:00:00 +0100
        // This is problematic, because some developers use other date formats
        self.dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    }
    
    private var parsingDate = false
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "item" {
            self.createVersion()
        }
        
        guard let currentVersion = self.currentVersion else { return }

        // Lets find the version number
        switch elementName {
        case "enclosure":
            if let newVersion = attributeDict["sparkle:version"]  {
                currentVersion.newVersion = newVersion
            }
        case "pubDate":
            self.parsingDate = true
        default:
            ()
        }
        
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "pubDate" {
            self.parsingDate = false
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if parsingDate {
            if let date = self.dateFormatter.date(from: string) {
                currentVersion?.date = date
            }
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        var foundItemWithDate = true
        
        self.versions.sort { (first, second) -> Bool in
            guard let firstDate = first.date else {
                foundItemWithDate = false
                return false
            }
            
            guard let secondDate = second.date else { return true }
            
            // Ok, we can sort after dates now
            return firstDate.compare(secondDate) == .orderedDescending
        }
        
        if !foundItemWithDate && self.versions.count > 1 {
            // The feed did not provide proper dates, so we only can try to compare version numbers against each other
            // With this information, we might be able to find the newest item 
            // I don't want this to be the default option, as there might be version formats I don't think of right now
            // We will see how this plays out in the future
            
            self.versions.sort(by: { (first, second) -> Bool in
                guard let firstVersion = first.version, let secondVersion = second.version else { return false }
                
                let c1 = firstVersion.versionComponents()
                let c2 = secondVersion.versionComponents()
                
                if c1.count > c2.count {
                    for index in (0...c2.count) {
                        if c1[index] > c2[index] {
                            return true
                        } else if c1[index] < c2[index] {
                            return false
                        }
                    }
                    
                    return true
                } else {
                    for index in (0...c1.count - 1) {
                        if c1[index] > c2[index] {
                            return true
                        } else if c1[index] < c2[index] {
                            return false
                        }
                    }
                    
                    return false
                }
            })
        }
        
        if let version = self.versions.first {
            
            DispatchQueue.main.async(execute: { //[weak self] in
                self.delegate?.checkerDidFinishChecking(self, newestVersion: version)
            })
        }
    }
    
    private func createVersion() {
        let version = Version()
    
        self.currentVersion = version
        self.versions.append(version)
    }
    
    func printDebugDescription() {
        print("-----------------------")
        print("Debug description for app \(appName)")
        print("Short version: \(shortVersion ?? "not given")")
        print("Version: \(version ?? "not given")")
        print("Number of versions parsed: \(versions.count)")
        
        print("Versions found:")
        for version in self.versions {
            print(version.newVersion)
        }
    }
}

extension String {
    func versionComponents() -> [Int] {
        let components = self.components(separatedBy: ".")
        var versionComponents = [Int]()
        
        components.forEach { (component) in
            if let number = Int.init(component) {
                versionComponents.append(number)
            }
        }
        
        return versionComponents
    }
}
