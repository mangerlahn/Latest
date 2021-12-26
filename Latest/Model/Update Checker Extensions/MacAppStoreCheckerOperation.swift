//
//  MacAppStoreUpdateCheckerOperation.swift
//  Latest
//
//  Created by Max Langer on 03.10.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Cocoa

/// The operation for checking for updates for a Mac App Store app.
class MacAppStoreUpdateCheckerOperation: StatefulOperation, UpdateCheckerOperation {
	
	private static let dateFormatter: DateFormatter = {
		// Setup date formatter
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        
        // Example of the date format: Mon, 28 Nov 2016 14:00:00 +0100
        // This is problematic, because some developers use other date formats
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
		
		return dateFormatter
	}()
	
	/// The bundle to be checked for updates.
	private let app: MacAppStoreAppBundle
		
	required init?(withAppURL appURL: URL, version: String, buildNumber: String, completionBlock: @escaping UpdateCheckerCompletionBlock) {
        let appName = appURL.lastPathComponent as NSString

        let appBundle = Bundle(path: appURL.path)
        let fileManager = FileManager.default
        
		// Mac Apps contain a receipt, iOS apps are wrapped inside a macOS bundle, but without an actual purchase receipt
        guard let receiptPath = appBundle?.appStoreReceiptURL?.path,
			  fileManager.fileExists(atPath: receiptPath) || receiptPath.contains("WrappedBundle") else { return nil }
        
        // App is from Mac App Store
        guard let bundleIdentifier = appBundle?.bundleIdentifier else { return nil }

		// The requirements are met. Initialize the operation.
		self.app = MacAppStoreAppBundle(appName: appName.deletingPathExtension, bundleIdentifier: bundleIdentifier, versionNumber: version, buildNumber: buildNumber, url: appURL)
		
		super.init()

		self.completionBlock = {
			completionBlock(self.app)
		}
	}

	override func execute() {
		if self.app.bundleIdentifier.contains("com.apple.InstallAssistant") {
			self.finish()
            return
        }
        
		self.fetchAppInfo { data, error in
			// Process fetched info
			if let data = data {
				self.parse(data: data)
			}
			
			// Forward fetch error
			else {
				self.app.newestVersion.releaseNotes = error
				self.finish()
			}
		}
	}
	
	private func fetchAppInfo(completion: @escaping (_ data: [String : Any]?, _ error: Error?) -> ()) {
		// We need a two-level fetch process. `desktopSoftware` delivers metadata for mac-native software. `macSoftware` seems to be more broad, also includes Catalyst and iOS-only software. The former however is more accurate, as `macSoftware` might return iPad metadata for certain apps. We therefore prefer `desktopSoftware` and fall back to `macSoftware` if no info was found.
		self.fetchAppInfo(with: "desktopSoftware") { data, error in
			// Success, forward data
			if let data = data {
				completion(data, error)
				return
			}
			
			// Data could not be fetched, try the broader entity type
			self.fetchAppInfo(with: "macSoftware") { data, error in
				completion(data, error)
			}
		}
	}
	
	private func fetchAppInfo(with entityType: String, completion: @escaping (_ data: [String : Any]?, _ error: Error?) -> ()) {
		// Build URL
		guard let endpoint = URL(string: "https://itunes.apple.com/lookup") else {
			completion(nil, nil)
			return
		}

		// Add parameters
		let languageCode = Locale.current.regionCode ?? "US"
		var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
		components?.queryItems = [
			URLQueryItem(name: "limit", value: "1"),
			URLQueryItem(name: "entity", value: entityType),
			URLQueryItem(name: "country", value: languageCode),
			URLQueryItem(name: "bundleId", value: self.app.bundleIdentifier)
		]
		guard let url = components?.url else {
			completion(nil, nil)
			return
		}
		
		// Perform request
		let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
		let dataTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
			guard error == nil,
				let data = data,
				let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
				let results = json["results"] as? [Any],
				results.count != 0,
				let appData = results[0] as? [String: Any] else {
					completion(nil, error)
					return
			}
			
			completion(appData, error)
		}
		
		dataTask.resume()
	}
	
}

// MARK: - Parsing

extension MacAppStoreUpdateCheckerOperation {
	
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
			let date = Self.dateFormatter.date(from: dateString) {
			info.date = date
		}

		// Get App Store Link
		if var appURL = data["trackViewUrl"] as? String {
			appURL = appURL.replacingOccurrences(of: "https", with: "macappstore")
			self.app.appStoreURL = URL(string: appURL)
		}
		   
		self.app.newestVersion = info
		   
		self.finish()
	}
	
}
