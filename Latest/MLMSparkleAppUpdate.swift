//
//  MLMSparkleAppUpdate.swift
//  Latest
//
//  Created by Max Langer on 07.04.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

class MLMSparkleAppUpdate: MLMAppUpdate, XMLParserDelegate {
    
    private enum ParsingType {
        case pubDate
        case releaseNotesLink
        case releaseNotesData
        
        case none
    }

    private var versions = [Version]()

    override init(appName: String, shortVersion: String?, version: String?) {
        super.init(appName: appName, shortVersion: shortVersion, version: version)
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale(identifier: "en_US")
        
        // Example of the date format: Mon, 28 Nov 2016 14:00:00 +0100
        // This is problematic, because some developers use other date formats
        self.dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    }
    
    override func printDebugDescription() {
        super.printDebugDescription()
        
        print("Number of versions parsed: \(versions.count)")
        
        print("Versions found:")
        for version in self.versions {
            print(version.newVersion)
        }
    }
    
    private func createVersion() {
        let version = Version()
        
        self.currentVersion = version
        self.versions.append(version)
    }
    
    // MARK: - XML Parser
    
    private var currentlyParsing : ParsingType = .none
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
            
            if let shortVersion = attributeDict["sparkle:shortVersionString"] {
                currentVersion.shortVersion = shortVersion
            }
        case "pubDate":
            self.currentlyParsing = .pubDate
        case "sparkle:releaseNotesLink":
            self.currentlyParsing = .releaseNotesLink
        case "description":
            self.currentlyParsing = .releaseNotesData
        default:
            ()
        }
        
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "pubDate" {
            self.currentlyParsing = .none
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentlyParsing {
        case .pubDate:
            if let date = self.dateFormatter.date(from: string) {
                self.currentVersion?.date = date
            }
        case .releaseNotesLink:
            if self.currentVersion?.releaseNotes == nil {
                self.currentVersion?.releaseNotes = URL(string: string)
            }
        case .releaseNotesData:
            if self.currentVersion?.releaseNotes == nil {
                self.currentVersion?.releaseNotes = ""
            }
            
            if var releaseNotes = self.currentVersion?.releaseNotes as? String {
                releaseNotes += string
                self.currentVersion?.releaseNotes = releaseNotes
            }
        default:
            ()
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
            
            self.currentVersion = version
            
            DispatchQueue.main.async(execute: { //[weak self] in
                self.delegate?.checkerDidFinishChecking(self)
            })
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
