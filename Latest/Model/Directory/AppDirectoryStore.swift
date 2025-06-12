//
//  AppDirectoryStore.swift
//  Latest
//
//  Created by Max Langer on 05.07.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import Foundation

/// Object that takes care of storing and observing application directories.
class AppDirectoryStore {
	
	typealias UpdateHandler = () -> Void
	private let observer: NSKeyValueObservation?

	/// Initializes the store with the given update handler.
	init(updateHandler: @escaping UpdateHandler) {
		observer = UserDefaults.standard.observe(\.directoryPaths, changeHandler: { _, _ in
			updateHandler()
		})
	}
	
	
	// MARK: - URLs
	
	/// The URLs stored in this object.
	var URLs: [URL] {
		Self.defaultURLs + customURLs
	}
	
	/// Set of URLs that will always be checked.
	private static let defaultURLs: [URL] = {
		let fileManager = FileManager.default
		let urls = [FileManager.SearchPathDomainMask.localDomainMask, .userDomainMask].flatMap { (domainMask) -> [URL] in
			return fileManager.urls(for: .applicationDirectory, in: domainMask)
		}
		
		return urls.filter { url -> Bool in
			return fileManager.fileExists(atPath: url.path)
		}
	}()

	/// User-definable URLs.
	private var customURLs: [URL] {
		get {
			guard let paths = UserDefaults.standard.directoryPaths else { return [] }
			
			return paths.map { path in
				if #available(macOS 13.0, *) {
					URL(filePath: path, directoryHint: .isDirectory, relativeTo: nil)
				} else {
					URL(fileURLWithPath: path)
				}
			}
		}
		
		set {
			UserDefaults.standard.directoryPaths = newValue.map { $0.relativePath }
		}
	}
			

	// MARK: - Actions
	
	/// Adds the given URL to the store.
	///
	/// This method does nothing if the URL already exists.
	func add(_ url: URL) {
		// Ignore adding the same URL multiple times
		guard !URLs.contains(url) else { return }
		customURLs.append(url)
	}
	
	/// Removes the custom URL, if set.
	func remove(_ url: URL) {
		customURLs.removeAll(where: { $0 == url })
	}
	
	/// Whether the URL can be removed from the store.
	func canRemove(_ url: URL) -> Bool {
		customURLs.contains(url) && !Self.defaultURLs.contains(url)
	}
	
	/// Whether the url currently reachable.
	func isReachable(_ url: URL) -> Bool {
		(try? url.checkResourceIsReachable()) == true
	}
}

extension UserDefaults {
	private static let directoryPathsKey = "directoryPaths"
	@objc dynamic var directoryPaths: [String]? {
		get {
			stringArray(forKey: Self.directoryPathsKey)
		}
		set {
			setValue(newValue, forKey: Self.directoryPathsKey)
		}
	}
}
														
													
