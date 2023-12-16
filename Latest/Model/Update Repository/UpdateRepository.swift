//
//  UpdateRepository.swift
//  Latest
//
//  Created by Max Langer on 01.10.23.
//  Copyright © 2023 Max Langer. All rights reserved.
//

import AppKit

/// User defaults key for storing the last cache update date.
private let UpdateDateKey = "UpdateDateKey"

/// A storage that fetches update information from an online source.
///
/// Can be asked for update version information for a given application bundle.
class UpdateRepository {
	
	/// Duration after which the cache will be invalidated. (1 hour in seconds)
	private static let cacheInvalidationDuration: Double = 1 * 60 * 60

	// MARK: - Init
	
	let fetchCompletedGroup = DispatchGroup()
	
	private init() {
		fetchCompletedGroup.enter()
		fetchCompletedGroup.notify(queue: .main) { [weak self] in
			self?.finalize()
		}
	}
	
	/// Returns a new repository with up to date update information.
	static func newRepository() -> UpdateRepository {
		let repository = UpdateRepository()
		repository.load()
		repository.fetchCompletedGroup.leave()
		
		return repository
	}
	
	
	// MARK: - Accessors
	
	/// Returns update information for the given bundle.
	func updateInfo(for bundle: App.Bundle, handler: @escaping (_ bundle: App.Bundle, _ version: Version?, _ minimumOSVersion: OperatingSystemVersion?) -> Void) {
		let checkApp = {
			guard let entry = self.entry(for: bundle) else {
				handler(bundle, nil, nil)
				return
			}
			
			return handler(bundle, entry.version, entry.minimumOSVersion)
		}
		
		/// Entries are still being fetched, add the request to the queue.
		if entries == nil {
			self.pendingRequests.append(checkApp)
		} else {
			checkApp()
		}
	}
	
	/// List of entries stored within the repository.
	private var entries: [Entry]?
	
	/// A list of requests being performed while the repository was still fetching data.
	private var pendingRequests: [() -> Void] = []
	
	/// A set of bundle identifiers for which update checking is currently not supported.
	private var unsupportedBundleIdentifiers: Set<String>!
	
	/// Sets the given entries and performs pending requests.
	private func finalize() {
		// Perform any pending requests
		self.pendingRequests.forEach { request in
			request()
		}
		self.pendingRequests.removeAll()
	}
	
	/// Returns a repository entry for the given name, if available.
	private func entry(for bundle: App.Bundle) -> Entry? {
		let name = bundle.fileURL.lastPathComponent

		// Don't return an entry for unsupported apps
		guard !unsupportedBundleIdentifiers.contains(bundle.bundleIdentifier) else { return nil }
		
		// Match bundle identifier
		return entries?.first(where: { entry in
			if entry.bundleIdentifiers.contains(bundle.bundleIdentifier) {
				return true
			}
			
			return false
		})
		
		// Fallback: Try to match app name (unreliable, since sometimes multiple apps with the same name exist. See Telegram or Eclipse)
		?? self.entries?.first(where: { entry in
			return entry.names.contains { n in
				return n.caseInsensitiveCompare(name) == .orderedSame
			}
		})
	}
	
	
	// MARK: - Cache Handling
	
	/// Loads the repository data.
	private func load() {
		RemoteURL.allCases.forEach { urlType in
			self.fetchCompletedGroup.enter()
			
			func handle(_ data: Data) {
				switch urlType {
				case .repository:
					parse(data)
				case .unsupportedApps:
					loadUnsupportedApps(from: data)
				}
				
				self.fetchCompletedGroup.leave()
			}
			
			// Check for valid cache file
			let timeInterval = UserDefaults.standard.double(forKey: urlType.userDefaultsKey) as TimeInterval
			if timeInterval > 0, timeInterval.distance(to: Date.timeIntervalSinceReferenceDate) < Self.cacheInvalidationDuration,
			   let cacheURL = urlType.cacheURL, let data = try? Data(contentsOf: cacheURL)  {
				handle(data)
				return
			}
			
			// Fetch data from server
			let session = URLSession(configuration: .default)
			let task = session.dataTask(with: urlType.url) { [weak self] data, response, error in
				guard let self else { return }
				guard let data = data ?? urlType.fallbackData else {
					self.fetchCompletedGroup.leave()
					return
				}
				
				handle(data)
				
				// Store in cache
				if let cacheURL = urlType.cacheURL {
					try? data.write(to: cacheURL)
					UserDefaults.standard.setValue(Date.timeIntervalSinceReferenceDate, forKey: urlType.userDefaultsKey)
				}
			}
			task.resume()

		}
	}
	
	/// Parses the given repository data and finishes loading.
	private func parse(_ repositoryData: Data) {
		do {
			let entries = try JSONDecoder().decode([Entry].self, from: repositoryData)
		
			// Filter out any entries without application name
			self.entries = entries.filter { !$0.names.isEmpty || !$0.bundleIdentifiers.isEmpty }
		} catch {
			self.entries = []
		}
	}
	
	private func loadUnsupportedApps(from data: Data) {
		let propertyList = try! PropertyListSerialization.propertyList(from: data, format: nil) as! [String]
		unsupportedBundleIdentifiers = Set(propertyList)
	}

	
	// MARK: - Repository URL
	
	private enum RemoteURL: String, CaseIterable {
		
		/// The URL update information is being fetched from.
		case repository = "RepositoryCache"
		
		/// Duration after which the cache will be invalidated. (1 hour in seconds)
		case unsupportedApps = "UnsupportedApps"
		
		/// The actual remote URL the information can be fetched from.
		var url: URL {
			let urlString = switch self {
			case .repository:
				"https://formulae.brew.sh/api/cask.json"
			case .unsupportedApps:
				"https://raw.githubusercontent.com/mangerlahn/Latest/develop/Latest/Resources/ExcludedAppIdentifiers.plist"
			}
			
			return URL(string: urlString)!
		}
		
		/// The URL where the cached data will be stored.
		var cacheURL: URL? {
			let name = rawValue
			let pathExtension = switch self {
			case .repository:
				"json"
			case .unsupportedApps:
				"plist"
			}
			
			return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
				.appendingPathComponent(Bundle.main.bundleIdentifier!)
				.appendingPathComponent(name).appendingPathExtension(pathExtension)
		}
		
		/// Possible fallback data within the binary if the remote content could not be fetched.
		var fallbackData: Data? {
			switch self {
			case .repository:
				return nil
			case .unsupportedApps:
				return try! Data(contentsOf: Bundle.main.url(forResource: "ExcludedAppIdentifiers", withExtension: "plist")!)
			}
		}
		
		/// The user defaults key used for storing the cache access information.
		var userDefaultsKey: String {
			rawValue + UpdateDateKey
		}
		
	}

}
