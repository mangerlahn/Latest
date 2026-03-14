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
	private let directoryPathsObserver: NSKeyValueObservation?
	private let excludedDirectoryPathsObserver: NSKeyValueObservation?

	/// Initializes the store with the given update handler.
	init(updateHandler: @escaping UpdateHandler) {
		directoryPathsObserver = UserDefaults.standard.observe(\.directoryPaths, changeHandler: { _, _ in
			updateHandler()
		})
		excludedDirectoryPathsObserver = UserDefaults.standard.observe(\.excludedDirectoryPaths, changeHandler: { _, _ in
			updateHandler()
		})
	}
	
	
	// MARK: - URLs
	
	/// The URLs stored in this object.
	var URLs: [URL] {
		self.visibleDefaultURLs + customURLs
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

	/// User-hidden default URLs.
	private var excludedDefaultURLs: [URL] {
		get {
			guard let paths = UserDefaults.standard.excludedDirectoryPaths else { return [] }
			
			return paths.map { path in
				if #available(macOS 13.0, *) {
					URL(filePath: path, directoryHint: .isDirectory, relativeTo: nil)
				} else {
					URL(fileURLWithPath: path)
				}
			}
		}
		
		set {
			UserDefaults.standard.excludedDirectoryPaths = newValue.map(\.relativePath)
		}
	}
	
	private var visibleDefaultURLs: [URL] {
		let excludedPaths = Set(self.excludedDefaultURLs.map(\.standardizedFileURL.path))
		return Self.defaultURLs.filter { !excludedPaths.contains($0.standardizedFileURL.path) }
	}
			

	// MARK: - Actions
	
	/// Adds the given URL to the store.
	///
	/// This method does nothing if the URL already exists.
	func add(_ url: URL) {
		if isDefault(url) {
			excludedDefaultURLs.removeAll(where: { $0.standardizedFileURL.path == url.standardizedFileURL.path })
			return
		}
		
		// Ignore adding the same URL multiple times
		guard !URLs.contains(url) else { return }
		customURLs.append(url)
	}
	
	/// Removes the URL from the visible scan locations.
	func remove(_ url: URL) {
		if isDefault(url) {
			guard !excludedDefaultURLs.contains(where: { $0.standardizedFileURL.path == url.standardizedFileURL.path }) else { return }
			excludedDefaultURLs.append(url)
			return
		}
		
		customURLs.removeAll(where: { $0.standardizedFileURL.path == url.standardizedFileURL.path })
	}
	
	/// Whether the URL can be removed from the store.
	func canRemove(_ url: URL) -> Bool {
		URLs.contains(where: { $0.standardizedFileURL.path == url.standardizedFileURL.path })
	}
	
	/// Whether the URL is one of the built-in scan locations.
	func isDefault(_ url: URL) -> Bool {
		Self.defaultURLs.contains(where: { $0.standardizedFileURL.path == url.standardizedFileURL.path })
	}
	
	/// Whether the url currently reachable.
	func isReachable(_ url: URL) -> Bool {
		(try? url.checkResourceIsReachable()) == true
	}
}

extension UserDefaults {
	private static let directoryPathsKey = "directoryPaths"
	private static let excludedDirectoryPathsKey = "excludedDirectoryPaths"
	
	@objc dynamic var directoryPaths: [String]? {
		get {
			stringArray(forKey: Self.directoryPathsKey)
		}
		set {
			setValue(newValue, forKey: Self.directoryPathsKey)
		}
	}
	
	@objc dynamic var excludedDirectoryPaths: [String]? {
		get {
			stringArray(forKey: Self.excludedDirectoryPathsKey)
		}
		set {
			setValue(newValue, forKey: Self.excludedDirectoryPathsKey)
		}
	}
}
														
													
