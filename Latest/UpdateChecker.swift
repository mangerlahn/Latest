//
//  UpdateChecker.swift
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

protocol UpdateCheckerDelegate: class {
    func checkerDidFinishChecking(_ checker: UpdateChecker, newestVersion: Version)
}

class UpdateChecker: NSObject, XMLParserDelegate {
    
    var shortVersion: String?
    var version: String?
    var appName = ""
    
    weak var delegate : UpdateCheckerDelegate?
    
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
        var foundItemWithDate = false
        
        self.versions.sort { (first, second) -> Bool in
            guard let firstDate = first.date else { return false }
            guard let secondDate = second.date else { return true }
            
            // Ok, we can sort after dates now
            foundItemWithDate = true
            return firstDate.compare(secondDate) == .orderedDescending
        }
        
        if !foundItemWithDate && self.versions.count > 1 {
            // The feed did not provide proper dates, so we only can try to compare version numbers against each other
            // With this information, we might be able to find the newest item 
            
            self.versions.sort(by: { (first, second) -> Bool in
                return true
            })
            
        }
        
        if let version = self.versions.first {
            delegate?.checkerDidFinishChecking(self, newestVersion: version)
        }
    }
    
    private func createVersion() {
        let version = Version()
    
        self.currentVersion = version
        self.versions.append(version)
    }
    
    func printDebugDescription() {
        print("Debug description for app \(appName)")
        print("Short version: \(shortVersion ?? "not given")")
        print("Version: \(version ?? "not given")")
        print("Number of versions parsed: \(versions.count)")
    }
}
