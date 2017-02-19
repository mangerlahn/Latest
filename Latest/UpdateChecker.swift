//
//  UpdateChecker.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

class Version {
    var currentVersion = ""
    var newVersion = ""
    
    var version = ""
    var shortVersion = ""
    var date : Date?
}

protocol UpdateCheckerDelegate: class {
    func checkerDidFinishChecking(_ checker: UpdateChecker, versionBundle: Version)
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
        if self.currentVersion == nil || elementName == "item" {
            self.createVersion()
        }
        
        guard let currentVersion = self.currentVersion else { return }

        // Lets find the version number
        switch elementName {
        case "enclosure":
            if let newVersion = attributeDict["sparkle:shortVersionString"], let shortVersion = self.shortVersion {
                currentVersion.currentVersion = shortVersion
                currentVersion.newVersion = newVersion
            } else if let newVersion = attributeDict["sparkle:version"], let version = self.version  {
                currentVersion.currentVersion = version
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
        self.versions.sort { (first, second) -> Bool in
            guard let firstDate = first.date else { return false }
            guard let secondDate = second.date else { return true }
            
            return firstDate.compare(secondDate) == .orderedDescending
        }
        
        if let version = self.versions.first, let _ = version.date {
            delegate?.checkerDidFinishChecking(self, versionBundle: version)
        }
    }
    
    private func createVersion() {
        let version = Version()
    
        self.currentVersion = version
        self.versions.append(version)
    }
}
