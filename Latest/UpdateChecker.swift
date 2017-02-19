//
//  UpdateChecker.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

struct Version {
    var currentVersion = ""
    var newVersion = ""
}

protocol UpdateCheckerDelegate: class {
    func checkerDidFinishChecking(_ checker: UpdateChecker, versionBundle: Version)
}

class UpdateChecker: NSObject, XMLParserDelegate {
    
    var shortVersion: String?
    var version: String?
    var appName = ""
    
    var versionBundle = Version()
    
    var updateDate = Date(timeIntervalSince1970: 0)
    
    weak var delegate : UpdateCheckerDelegate?
    
    convenience init(appName: String, shortVersion: String?, version: String?) {
        self.init()
        
        self.appName = appName
        self.shortVersion = shortVersion
        self.version = version
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        // Lets find the version number
        print(elementName)
        
        if elementName == "enclosure" {
            
            if let newVersion = attributeDict["sparkle:shortVersionString"], let shortVersion = self.shortVersion {
                versionBundle.currentVersion = shortVersion
                versionBundle.newVersion = newVersion
            } else if let newVersion = attributeDict["sparkle:version"], let version = self.version  {
                versionBundle.currentVersion = version
                versionBundle.newVersion = newVersion
            }
            
        }
        
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        delegate?.checkerDidFinishChecking(self, versionBundle: self.versionBundle)
    }
}
