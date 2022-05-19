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
	
	// MARK: - Update Check
	
	static func canPerformUpdateCheck(forAppAt url: URL) -> Bool {
		// Can check for updates if a feed URL is available for the given app
		return Self.feedURL(from: url) != nil
	}

	static var sourceType: App.Bundle.Source {
		return .sparkle
	}
	
	required init(with app: App.Bundle, completionBlock: @escaping UpdateCheckerCompletionBlock) {
		self.app = app
		self.url = Self.feedURL(from: app.fileURL)
		
		super.init()

		self.completionBlock = {
			guard !self.isCancelled else { return }
			if let update = self.update {
				completionBlock(.success(update))
			} else {
				completionBlock(.failure(self.error ?? LatestError.updateInfoNotFound))
			}
		}
	}
	
	/// Returns the Sparkle feed url for the app at the given URL, if available.
	private static func feedURL(from appURL: URL) -> URL? {
		guard let bundle = Bundle(path: appURL.path) else { return nil }
		return Sparke.feedURL(from: bundle)
	}

	/// The bundle to be checked for updates.
	private let app: App.Bundle
	
	/// The url to check for updates.
	private let url: URL?
	
	/// The update fetched during the checking operation.
	fileprivate var update: App.Update?

	
	// MARK: - Operation
	
	override func execute() {
		guard let url = self.url else {
			self.finish(with: LatestError.updateInfoNotFound)
			return
		}

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
				self.finish(with: error ?? MalformedURLError)
			}
		})
		
		task.resume()
	}
	
	
	// MARK: - XML Parser

	/// Variable holding the current parsing state
    private var currentlyParsing : ParsingType = .none
	
	/// An array holding all versions of the app contained in the Sparkle feed
	private var updates = [UpdateEntry]()
	
}

extension SparkleUpdateCheckerOperation: XMLParserDelegate {
	
	private static let dateFormatter: DateFormatter = {
		// Setup date formatter
		let dateFormatter = DateFormatter()
		dateFormatter.locale = Locale(identifier: "en_US")
		
		// Example of the date format: Mon, 28 Nov 2016 14:00:00 +0100
		// This is problematic, because some developers use other date formats
		dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
		
		return dateFormatter
	}()
	
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
        
		guard let info = self.currentUpdate else { return }
        
        // Lets find the version number
        switch elementName {
        case "enclosure":
            info.versionNumber = attributeDict["sparkle:shortVersionString"] ?? info.versionNumber
            info.buildNumber = attributeDict["sparkle:version"] ?? info.buildNumber
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
			self.currentlyParsing = .none
        }
        
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		self.currentlyParsing = .none
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
		guard let info = self.currentUpdate else { return }

        switch currentlyParsing {
        case .pubDate:
			if let date = Self.dateFormatter.date(from: string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                info.date = date
            }
        case .releaseNotesLink:
            // Release Notes Link wins over other release notes types
			if case .url(_) = info.releaseNotes { return }
			guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
			info.releaseNotes = .url(url: url)
        case .releaseNotesData:
            if info.releaseNotes == nil {
				info.releaseNotes = .html(string: "")
            }
            
			if case .html(var releaseNotes) = info.releaseNotes {
                releaseNotes += string
				info.releaseNotes = .html(string: releaseNotes)
            }
        case .version:
            info.buildNumber = string
        case .shortVersion:
            info.versionNumber = string
        case .none:
            ()
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        var foundItemWithDate = true
        
        self.updates = self.updates.filter { (info) -> Bool in
            return !info.version.isEmpty
        }
        
        self.updates.sort { (first, second) -> Bool in
            guard let firstDate = first.date else {
                foundItemWithDate = false
                return false
            }
            
            guard let secondDate = second.date else { return true }
            
            // Ok, we can sort after dates now
            return firstDate.compare(secondDate) == .orderedDescending
        }
        
        if !foundItemWithDate && self.updates.count > 1 {
            // The feed did not provide proper dates, so we only can try to compare version numbers against each other
            // With this information, we might be able to find the newest item
            // I don't want this to be the default option, as there might be version formats I don't think of right now
            // We will see how this plays out in the future
            self.updates.sort(by: { (first, second) -> Bool in
                return first.version >= second.version
            })
        }
        
        guard let update = self.updates.first else {
			self.finish(with: LatestError.updateInfoNotFound)
            return
        }
		
		self.update = App.Update(app: self.app, remoteVersion: update.version, date: update.date, releaseNotes: update.releaseNotes, updateAction: { app in
			UpdateQueue.shared.addOperation(SparkleUpdateOperation(bundleIdentifier: app.bundleIdentifier, appIdentifier: app.identifier))
		})
        
        DispatchQueue.main.async(execute: {
			self.finish()
        })
    }
	
	
    // MARK: - Helper Methods
    
    /// Creates version info object and appends it to the versionInfos array
    private func createVersion() {
        self.updates.append(UpdateEntry())
    }
	
	/// The currently parsed update entry.
	private var currentUpdate: UpdateEntry? {
		return self.updates.last
	}
	
}

// MARK: - Utilities

/// Simple container holding update information for a single entry in the update feed.
fileprivate class UpdateEntry {
	
	/// The version information of the entry.
	var version: Version {
		return Version(versionNumber: versionNumber, buildNumber: buildNumber)
	}
	
	/// The version number of the entry.
	var versionNumber: String?
	
	/// The build number of the entry.
	var buildNumber: String?
	
	/// The release date of the update entry.
	var date: Date?
	
	/// Release notes associated with the entry.
	var releaseNotes: App.Update.ReleaseNotes?
		
}
