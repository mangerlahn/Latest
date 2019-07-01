//
//  MacAppStoreAppUpdate.swift
//  Latest
//
//  Created by Max Langer on 07.04.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

/**
 Mac App Store app bundle subclass, it handles the parsing of the iTunes JSON
 */
class MacAppStoreAppBundle: AppBundle {

    /// The url of the app in the Mac App Store
    var appStoreURL : URL?
    
    /// The date formatter used for parsing
    private var dateFormatter: DateFormatter!
    
	override init(appName: String, bundleIdentifier: String, versionNumber: String?, buildNumber: String?, url: URL) {
		super.init(appName: appName, bundleIdentifier: bundleIdentifier, versionNumber: versionNumber, buildNumber: buildNumber, url: url)
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale(identifier: "en_US")
        
        // Example of the date format: Mon, 28 Nov 2016 14:00:00 +0100
        // This is problematic, because some developers use other date formats
        self.dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    }
    
    /**
     Parses the data to extract information like release notes and version number
 
     - parameter data: The JSON dictionary to be parsed
     */
    func parse(data: [String : Any]) {
        let info = UpdateInfo()
        
        // Get newest version
        if let currentVersion = data["version"] as? String {
            info.version.versionNumber = currentVersion
        }
        
        // Get release notes
        if var releaseNotes = data["releaseNotes"] as? String {
            releaseNotes = releaseNotes.replacingOccurrences(of: "\n", with: "<br>")
            info.releaseNotes = releaseNotes
        }
        
        // Get update date
        if let dateString = data["currentVersionReleaseDate"] as? String,
           let date = self.dateFormatter.date(from: dateString) {
            info.date = date
        }
        
        // Get App Store Link
        if var appURL = data["trackViewUrl"] as? String {
            appURL = appURL.replacingOccurrences(of: "https", with: "macappstore")
            self.appStoreURL = URL(string: appURL)
        }
        
        self.newestVersion = info
        
        DispatchQueue.main.async(execute: {
            self.delegate?.appDidUpdateVersionInformation(self)
        })
    }
	// MARK: - Actions
	
	override func open() {
		// Should preferably open the Mac App Store
		NSWorkspace.shared.open(self.appStoreURL ?? self.url)
	}
	
}
