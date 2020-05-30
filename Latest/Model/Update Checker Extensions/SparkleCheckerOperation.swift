//
//  MacAppStoreUpdateCheckerOperation.swift
//  Latest
//
//  Created by Max Langer on 03.10.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Cocoa

/// The operation for checking for updates for a Sparkle app.
class SparkleUpdateCheckerOperation: StatefulOperation, UpdateCheckerOperation {
	
	private static let dateFormatter: DateFormatter = {
		// Setup date formatter
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        
        // Example of the date format: Mon, 28 Nov 2016 14:00:00 +0100
        // This is problematic, because some developers use other date formats
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
		
		return dateFormatter
	}()

	/// The bundle to be checked for updates.
	private let app: SparkleAppBundle
	
	/// The url to check for updates.
	private let url: URL
		
	required init?(withAppURL appURL: URL, version: String, buildNumber: String, completionBlock: @escaping UpdateCheckerCompletionBlock) {
		let appName = appURL.lastPathComponent as NSString
        let bundle = Bundle(path: appURL.path)
        
        guard let information = bundle?.infoDictionary, let identifier = bundle?.bundleIdentifier else {
            return nil
        }
        
        var url: URL

        if let urlString = information["SUFeedURL"] as? String, let feedURL = URL(string: urlString.unQuoted())  {
            url = feedURL
        } else { // Maybe the app is built using DevMate
            // Check for the DevMate framework
            let frameworksURL = URL(fileURLWithPath: appURL.path, isDirectory: true).appendingPathComponent("Contents").appendingPathComponent("Frameworks")
            
			let frameworks = try? FileManager.default.contentsOfDirectory(atPath: frameworksURL.path)
            if !(frameworks?.contains(where: { $0.contains("DevMateKit") }) ?? false) {
                return nil
            }
            
            // The app uses Devmate, so lets get the appcast from their servers
            guard var feedURL = URL(string: "https://updates.devmate.com") else {
                return nil
            }
            
            feedURL.appendPathComponent(identifier)
            feedURL.appendPathExtension("xml")
            
            url = feedURL
        }

 		// The requirements are met, the url points to a Mac App Store app. Initialize the operation.
		self.url = url
		self.app = SparkleAppBundle(appName: appName.deletingPathExtension, bundleIdentifier: identifier, versionNumber: version, buildNumber: buildNumber, url: appURL)
		
		super.init()
		
		self.completionBlock = {
			completionBlock(self.app)
		}
	}

	override func execute() {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            if error == nil,
                let xmlData = data {

                let parser = XMLParser(data: xmlData)

				parser.delegate = self

                if !parser.parse() {
					self.finish()
                }
            } else {
				self.app.newestVersion.releaseNotes = error
				self.finish()
            }
        })
        
        task.resume()
	}
	
	
	// MARK: - XML Parser

	/// Variable holding the current parsing state
    private var currentlyParsing : ParsingType = .none
	
	/// An array holding all versions of the app contained in the Sparkle feed
    private var versionInfos = [UpdateInfo]()
	
}

fileprivate extension String {
    func unQuoted() -> String {
        return NSString(string: self).trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
    }
}

extension SparkleUpdateCheckerOperation: XMLParserDelegate {
	
    /// Enum reflecting the different parsing states
    private enum ParsingType {
        case pubDate
        case releaseNotesLink
        case releaseNotesData
        case version
        case shortVersion
        
        case none
    }
        
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "item" {
            self.createVersion()
        }
        
		let info = self.app.newestVersion
        
        // Lets find the version number
        switch elementName {
        case "enclosure":
            info.version.versionNumber = attributeDict["sparkle:shortVersionString"]
            info.version.buildNumber = attributeDict["sparkle:version"]
        case "pubDate":
            self.currentlyParsing = .pubDate
        case "sparkle:releaseNotesLink":
            self.currentlyParsing = .releaseNotesLink
        case "sparkle:version":
            self.currentlyParsing = .version
        case "sparkle:shortVersionString":
            self.currentlyParsing = .shortVersion
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
		let info = self.app.newestVersion

        switch currentlyParsing {
        case .pubDate:
			if let date = Self.dateFormatter.date(from: string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                info.date = date
            }
        case .releaseNotesLink:
            // Release Notes Link wins over other release notes types
            if info.releaseNotes is URL { return }
            info.releaseNotes = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines))
        case .releaseNotesData:
            if info.releaseNotes == nil {
                info.releaseNotes = ""
            }
            
            if var releaseNotes = info.releaseNotes as? String {
                releaseNotes += string
                info.releaseNotes = releaseNotes
            }
        case .version:
            info.version.buildNumber = string
        case .shortVersion:
            info.version.versionNumber = string
        case .none:
            ()
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        var foundItemWithDate = true
        
        self.versionInfos = self.versionInfos.filter { (info) -> Bool in
            return !info.version.isEmpty
        }
        
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
        
        guard let version = self.versionInfos.first, !version.version.isEmpty else {
			self.finish()
            return
        }
        
		self.app.newestVersion = version
        
        DispatchQueue.main.async(execute: {
			self.finish()
        })
    }
	
	
    // MARK: - Helper Methods
    
    /// Creates version info object and appends it to the versionInfos array
    private func createVersion() {
        let version = UpdateInfo()
        
        self.app.newestVersion = version
        self.versionInfos.append(version)
    }
	
}
