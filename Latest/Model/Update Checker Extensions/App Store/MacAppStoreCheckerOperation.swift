//
//  MacAppStoreUpdateCheckerOperation.swift
//  Latest
//
//  Created by Max Langer on 03.10.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Cocoa

let MalformedURLError = NSError(domain: NSURLErrorDomain, code: NSURLErrorUnsupportedURL, userInfo: nil)

/// The operation for checking for updates for a Mac App Store app.
class MacAppStoreUpdateCheckerOperation: StatefulOperation, UpdateCheckerOperation, @unchecked Sendable {
	
	// MARK: - Update Check
	
	static var sourceType: App.Source {
		return .appStore
	}
	
	static func canPerformUpdateCheck(forAppAt url: URL) -> Bool {
		let fileManager = FileManager.default
		
		// Mac Apps contain a receipt, iOS apps are only available via the Mac App Store
		guard let receiptPath = receiptPath(forAppAt: url), fileManager.fileExists(atPath: receiptPath) || isIOSAppBundle(at: url) else { return false }
		
		return true
	}
	
	required init(with app: App.Bundle, repository: UpdateRepository?, completionBlock: @escaping UpdateCheckerCompletionBlock) {
		self.app = app
		
		super.init()

		self.completionBlock = {
			guard !self.isCancelled else { return }
			
			if let update = self.update {
				completionBlock(.success(update))
			} else {
				completionBlock(.failure(self.error ?? LatestError.updateInfoUnavailable))
			}
		}
	}

	/// The bundle to be checked for updates.
	fileprivate let app: App.Bundle

	/// The update fetched during this operation.
	fileprivate var update: App.Update?

	
	// MARK: - Operation
	
	override func execute() {
		if self.app.bundleIdentifier.contains("com.apple.InstallAssistant") {
			self.finish()
			return
		}
		
		self.fetchAppInfo { result in
			switch result {
			// Process fetched info
			case .success(let entry):
				self.update = self.update(from: entry)
				self.finish()

			// Forward fetch error
			case .failure(let error):
				self.finish(with: error)

			}
		}
	}
	
	
	// MARK: - Bundle Operations
	
	/// Returns the app store receipt path for the app at the given URL, if available.
	static fileprivate func receiptPath(forAppAt url: URL) -> String? {
		let bundle = Bundle(path: url.path)
		return bundle?.appStoreReceiptURL?.path
	}
	
	/// Returns whether the app at the given URL is an iOS app wrapped to run on macOS.
	static fileprivate func isIOSAppBundle(at url: URL) -> Bool {
		// iOS apps are wrapped inside a macOS bundle
		let path = receiptPath(forAppAt: url)
		return path?.contains("WrappedBundle") ?? false
	}
	
}

extension MacAppStoreUpdateCheckerOperation {
	
	/// Returns a proper update object from the given app store entry.
	private func update(from entry: AppStoreEntry) -> App.Update {
		let version = Version(versionNumber: entry.versionNumber, buildNumber: nil)
		let action: App.Update.Action = if Self.isIOSAppBundle(at: app.fileURL) {
			// iOS Apps: Open App Store page where the user can update manually. The update operation does not work for them.
			.external(label: NSLocalizedString("AppStoreSource", comment: "The source name of apps loaded from the App Store."), block: { app in
				NSWorkspace.shared.open(entry.pageURL)
			})
		} else {
			// Perform the update in-app
			.builtIn(block: { app in
				UpdateQueue.shared.addOperation(MacAppStoreUpdateOperation(bundleIdentifier: app.bundleIdentifier, appIdentifier: app.identifier, appStoreIdentifier: entry.appStoreIdentifier))
			})

		}
		
		return App.Update(app: self.app, remoteVersion: version, minimumOSVersion: entry.minimumOSVersion, source: .appStore, date: entry.date, releaseNotes: entry.releaseNotes, updateAction: action)
	}
	
	/// Fetches update info and returns the result in the given completion handler.
	private func fetchAppInfo(completion: @escaping (_ result: Result<AppStoreEntry, Error>) -> ()) {
		// We need a two-level fetch process. `desktopSoftware` delivers metadata for mac-native software. `macSoftware` seems to be more broad, also includes Catalyst and iOS-only software. The former however is more accurate, as `macSoftware` might return iPad metadata for certain apps. We therefore prefer `desktopSoftware` and fall back to `macSoftware` if no info was found.
		self.fetchAppInfo(with: "desktopSoftware") { result in
			switch result {
			case .success(let entry):
				// Success, forward data
				completion(.success(entry))
				
			case .failure(_):
				// Data could not be fetched, try the broader entity type
				self.fetchAppInfo(with: "macSoftware", completion: completion)
			}
		}
	}
	
	/// Fetches update info and returns the result in the given completion handler.
	///
	/// The entity describes the kind of app which will be looked for.
	private func fetchAppInfo(with entityType: String, completion: @escaping (_ result: Result<AppStoreEntry, Error>) -> ()) {
		// Build URL
		guard let endpoint = URL(string: "https://itunes.apple.com/lookup") else {
			completion(.failure(MalformedURLError))
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
			completion(.failure(MalformedURLError))
			return
		}
		
		// Perform request
		let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
		let dataTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
			guard error == nil, let data = data else {
				completion(.failure(MalformedURLError))
				return
			}
			
			do {
				guard let entry = try JSONDecoder().decode(EntryList.self, from: data).results.first else {
					completion(.failure(LatestError.updateInfoUnavailable))
					return
				}
				
				completion(.success(entry))
			}
			
			catch let error {
				completion(.failure(error))
			}
		}
		
		dataTask.resume()
	}
		
}

// MARK: - Decoding

/// Object containing a list of App Store entries.
fileprivate struct EntryList: Decodable {
	
	/// The list of entries found while fetching information from the app store.
	let results: [AppStoreEntry]
	
}

/// Object representing a single entry in fetched information from the app store.
fileprivate struct AppStoreEntry: Decodable {
	
	/// The version number of the entry.
	let versionNumber: String
	
	/// The release notes associated with the entry.
	let releaseNotesContent: String?
	
	/// The release date of the entry.
	let date: Date?
	
	/// The link to the app store page.
	let pageURL: URL
	
	/// The identifier for this app in the App Store context.
	let appStoreIdentifier: UInt64
	
	/// The minimum OS version required to run this update.
	let minimumOSVersion: OperatingSystemVersion
	
	
	// MARK: - Decoding
	
	enum CodingKeys: String, CodingKey {
		case versionNumber = "version"
		case releaseNotes = "releaseNotes"
		case date = "currentVersionReleaseDate"
		case pageURL = "trackViewUrl"
		case appStoreIdentifier = "trackId"
		case minimumOSVersion = "minimumOsVersion"
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		self.versionNumber = try container.decode(String.self, forKey: .versionNumber)
		
		let releaseNotes = try container.decodeIfPresent(String.self, forKey: .releaseNotes)
		self.releaseNotesContent = releaseNotes?.replacingOccurrences(of: "\n", with: "<br>")
		
		if let date = try container.decodeIfPresent(String.self, forKey: .date) {
			self.date = Self.dateFormatter.date(from: date)
		} else {
			self.date = nil
		}
		
		let pageURL = try container.decode(String.self, forKey: .pageURL)
		guard let url = URL(string: pageURL.replacingOccurrences(of: "https", with: "macappstore")) else {
			throw MalformedURLError
		}
		self.pageURL = url
		
		self.appStoreIdentifier = try container.decode(UInt64.self, forKey: .appStoreIdentifier)
		
		let osVersionString = try container.decode(String.self, forKey: .minimumOSVersion)
		self.minimumOSVersion = try OperatingSystemVersion(string: osVersionString)
	}
	
	
	// MARK: - Utilities
	
	// The release notes object derived from fetched texts.
	var releaseNotes: App.Update.ReleaseNotes? {
		if let releaseNotesContent = releaseNotesContent {
			return .html(string: releaseNotesContent)
		}
		
		return nil
	}
	
	private static let dateFormatter: DateFormatter = {
		// Setup date formatter
		let dateFormatter = DateFormatter()
		dateFormatter.locale = Locale(identifier: "en_US")
		
		// Example of the date format: Mon, 28 Nov 2016 14:00:00 +0100
		// This is problematic, because some developers use other date formats
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
		
		return dateFormatter
	}()
	
}
