//
//  SparkleAppUpdate.swift
//  Latest
//
//  Created by Max Langer on 07.04.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

/**
 Sparkle subclass of the app bundle. This handles the parsing of the sparkle feed.
 */
class SparkleAppBundle: AppBundle, XMLParserDelegate {
    
    /// Enum reflecting the different parsing states
    private enum ParsingType {
        case pubDate
        case releaseNotesLink
        case releaseNotesData
        
        case none
    }

    /// An array holding all versions of the app contained in the Sparkle feed
    private var versionInfos = [UpdateInfo]()

    /// The date formatter used for parsing
    private var dateFormatter: DateFormatter!

    override init(appName: String, versionNumber: String?, buildNumber: String?) {
        super.init(appName: appName, versionNumber: versionNumber, buildNumber: buildNumber)
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale(identifier: "en_US")
        
        // Example of the date format: Mon, 28 Nov 2016 14:00:00 +0100
        // This is problematic, because some developers use other date formats
        self.dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    }
    
    
    // MARK: - XML Parser
    
    /// Variable holding the current parsing state
    private var currentlyParsing : ParsingType = .none
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "item" {
            self.createVersion()
        }
        
        guard let info = self.newestVersion else { return }
        
        // Lets find the version number
        switch elementName {
        case "enclosure":
            info.version.versionNumber = attributeDict["sparkle:shortVersionString"]
            info.version.buildNumber = attributeDict["sparkle:version"]
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
            if let date = self.dateFormatter.date(from: string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                self.newestVersion?.date = date
            }
        case .releaseNotesLink:
            if self.newestVersion?.releaseNotes == nil {
                self.newestVersion?.releaseNotes = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        case .releaseNotesData:
            if self.newestVersion?.releaseNotes == nil {
                self.newestVersion?.releaseNotes = ""
            }
            
            if var releaseNotes = self.newestVersion?.releaseNotes as? String {
                releaseNotes += string
                self.newestVersion?.releaseNotes = releaseNotes
            }
        default:
            ()
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        var foundItemWithDate = true
        
        self.versionInfos.sort { (first, second) -> Bool in
            guard let firstDate = first.date else {
                foundItemWithDate = false
                return false
            }
            
            guard let secondDate = second.date else { return true }
            
            // Ok, we can sort after dates now
            return firstDate.compare(secondDate) == .orderedDescending
        }
        
        if !foundItemWithDate && self.versionInfos.count > 1 {
            // The feed did not provide proper dates, so we only can try to compare version numbers against each other
            // With this information, we might be able to find the newest item
            // I don't want this to be the default option, as there might be version formats I don't think of right now
            // We will see how this plays out in the future
            
            self.versionInfos.sort(by: { (first, second) -> Bool in
                return first.version >= second.version
            })
        }
        
        if let version = self.versionInfos.first {
            
            self.newestVersion = version
        }
        
        DispatchQueue.main.async(execute: {
            self.delegate?.appDidUpdateVersionInformation(self)
        })
    }
    
    
    // MARK: - Helper Methods
    
    /// Creates version info object and appends it to the versionInfos array
    private func createVersion() {
        let version = UpdateInfo()
        
        self.newestVersion = version
        self.versionInfos.append(version)
    }

    
    // MARK: - Debug
    
    override func printDebugDescription() {
        super.printDebugDescription()
        
        print("Number of versions parsed: \(versionInfos.count)")
        
        print("Versions found:")
        self.versionInfos.forEach({ print($0.version) })
    }
    
}
