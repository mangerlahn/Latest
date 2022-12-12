//
//  AppLibrary.swift
//  Latest
//
//  Created by Max Langer on 08.01.22.
//  Copyright © 2022 Max Langer. All rights reserved.
//

import Foundation

/// Observes the local collection of apps and notifies its owner of changes.
class AppLibrary {
	
	/// The handler to be called when apps change locally.
	typealias UpdateHandler = ([App.Bundle]) -> Void
	let updateHandler: UpdateHandler
	
	/// A list of all application bundles that are available locally.
	private(set) var bundles = [App.Bundle]() {
		didSet {
			self.updateHandler(self.bundles)
		}
	}

	/// Initializes the library with the given handler for updates.
	init(handler: @escaping UpdateHandler) {
		self.updateHandler = handler

		NotificationCenter.default.addObserver(self, selector: #selector(self.gatherAppBundles), name: .NSMetadataQueryDidFinishGathering, object: self.appSearchQuery)
		NotificationCenter.default.addObserver(self, selector: #selector(self.gatherAppBundles), name: .NSMetadataQueryDidUpdate, object: self.appSearchQuery)

		self.appSearchQuery.searchScopes = Self.applicationURLs
	}
	
	
	// MARK: - Actions
	
	/// Starts the update checking process
	func startQuery() {
		// Gather apps if no update is already ongoing
		if !self.appSearchQuery.isStarted || self.appSearchQuery.isStopped {
			self.appSearchQuery.start()
		}
	}

	/// Fetches app bundles from the search query. Must not be called directly.
	@objc func gatherAppBundles() {
		self.appSearchQuery.disableUpdates()
		
		let appSearchQueryResults = self.appSearchQuery.results
		var isSpotlightEnabled = true
		if appSearchQueryResults.isEmpty {
			isSpotlightEnabled = false
		} else if appSearchQueryResults.count == 1 {
			if (appSearchQueryResults[0] as? NSMetadataItem)?.value(forAttribute: NSMetadataItemPathKey) as? String == "/Applications/Safari.app" {
				isSpotlightEnabled = false // In macOS 13.0.1, Spotlight query returns a single installed app Safari even when Spotlight indexing on applications itself is disabled!
			}
		}
		if !isSpotlightEnabled {
			// Look for applications in the /Applications folder manually
			let fileManager = FileManager.default
			var bundles = [App.Bundle]()
			for applicationPath in Self.applicationPaths {
				if let appPaths = try? fileManager.contentsOfDirectory(atPath: applicationPath) {
					for appPath in appPaths {
						let url = URL(fileURLWithPath: applicationPath).appendingPathComponent(appPath)
						if Self.excludedSubfolders.contains(where: { url.path.contains($0) }) {
							continue
						}
						if let bundle = self.bundle(forAppAt: url) {
							bundles.append(bundle)
						}
					}
				}
			}
			self.bundles = bundles
		} else {
			// Run metadata query to gather all apps
			self.bundles = appSearchQueryResults.compactMap { item -> App.Bundle? in
				guard let metadata = item as? NSMetadataItem,
					let path = metadata.value(forAttribute: NSMetadataItemPathKey) as? String else { return nil }
				
				let url = URL(fileURLWithPath: path)
				
				// Only allow apps in the application folder and outside excluded subfolders
				if Self.excludedSubfolders.contains(where: { url.path.contains($0) }) {
					return nil
				}
				
				// Create an update check operation from the url if possible
				return self.bundle(forAppAt: url, metadata: metadata)
			}
		}
		
		self.appSearchQuery.enableUpdates()
	}
	
	
	// MARK: - Accessors
	
	/// The path of the users /Applications folder
	private static var applicationPaths : [String] {
		return applicationURLs.map({ $0.path })
	}
	
	/// The url of the /Applications folder on the users Mac
	static private var applicationURLs : [URL] {
		let fileManager = FileManager.default
		let urls = [FileManager.SearchPathDomainMask.localDomainMask, .userDomainMask].flatMap { (domainMask) -> [URL] in
			return fileManager.urls(for: .applicationDirectory, in: domainMask)
		}
		
		return urls.filter { url -> Bool in
			return fileManager.fileExists(atPath: url.path)
		}
	}
	
	/// Excluded subfolders that won't be checked.
	private static let excludedSubfolders = Set(["Setapp/", ".app/"])
	
	/// The metadata query that gathers all apps.
	private let appSearchQuery: NSMetadataQuery = {
		let query = NSMetadataQuery()
		query.predicate = NSPredicate(fromMetadataQueryString: "kMDItemContentTypeTree=com.apple.application")
		
		return query
	}()
	
	
	// MARK: - Utilities
	
	/// Returns a bundle representation for the app at the given url.
	private func bundle(forAppAt url: URL, metadata: NSMetadataItem) -> App.Bundle? {
		guard let appBundle = Bundle(path: url.path),
			  let buildNumber = appBundle.uncachedBundleVersion,
			  let identifier = appBundle.bundleIdentifier,
			  let versionNumber = metadata.value(forAttribute: NSMetadataItemVersionKey) as? String,
			  let appName = metadata.value(forAttribute: NSMetadataItemDisplayNameKey) as? String else {
			return nil
		}
		
		// Find update source
		guard let source = UpdateCheckCoordinator.source(forAppAt: url) else {
			return nil
		}
		
		// Create bundle
		let version = Version(versionNumber: versionNumber, buildNumber: buildNumber)
		return App.Bundle(version: version, name: appName, bundleIdentifier: identifier, fileURL: url, source: source)
	}
	
	/// Returns a bundle representation for the app at the given url, without Spotlight Metadata.
	private func bundle(forAppAt url: URL) -> App.Bundle? {
		guard let appBundle = Bundle(path: url.path),
			  let buildNumber = appBundle.uncachedBundleVersion,
			  let identifier = appBundle.bundleIdentifier,
			  let versionNumber = appBundle.versionNumber,
			  let appName = appBundle.bundleName else {
			return nil
		}
		// Find update source
		guard let source = UpdateCheckCoordinator.source(forAppAt: url) else {
			return nil
		}
		
		// Create bundle
		let version = Version(versionNumber: versionNumber, buildNumber: buildNumber)
		return App.Bundle(version: version, name: appName, bundleIdentifier: identifier, fileURL: url, source: source)
	}
	
}

fileprivate extension Bundle {
	
	/// Returns the bundle version which is guaranteed to be current.
	var uncachedBundleVersion: String? {
		let bundleRef = CFBundleCreate(.none, self.bundleURL as CFURL)
		
		// (NS)Bundle has a cache for (all?) properties, presumably to reduce disk access. Therefore, after updating an app, the old bundle version may be
		// returned. Flushing the cache (private method) resolves this.
		_CFBundleFlushBundleCaches(bundleRef)
		
		return infoDictionary?["CFBundleVersion"] as? String
	}

	/// Returns the bundle name when working without Spotlight.
	var bundleName: String? {
		return infoDictionary?["CFBundleName"] as? String
	}

	/// Returns the short version string when working without Spotlight.
	var versionNumber: String? {
		return infoDictionary?["CFBundleShortVersionString"] as? String
	}
}
