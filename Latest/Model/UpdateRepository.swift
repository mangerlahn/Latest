//
//  UpdateRepository.swift
//  Latest
//
//  Created by Max Langer on 01.10.23.
//  Copyright © 2023 Max Langer. All rights reserved.
//

import AppKit

/// User defaults key for storing the last cache update date.
private let CacheUpdateDateKey = "CacheUpdateDateKey"

/// A storage that fetches update information from an online source.
///
/// Can be asked for update version information for a given application bundle.
class UpdateRepository {

	/// The URL update information is being fetched from.
	private static let repositoryURL = URL(string: "https://formulae.brew.sh/api/cask.json")!
	
	/// Duration after which the cache will be invalidated. (1 hour in seconds)
	private static let cacheInvalidationDuration: Double = 1 * 60 * 60

	// MARK: - Init
	
	private init() {}
	
	/// Returns a new repository with up to date update information.
	static func newRepository() -> UpdateRepository {
		let repository = UpdateRepository()
		repository.load()
		
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
	
	/// Sets the given entries and performs pending requests.
	private func finalize(with entries: [Entry]) {
		// Filter out any entries without application name
		self.entries = entries.filter { !$0.names.isEmpty || !$0.bundleIdentifiers.isEmpty }
		
		// Perform any pending requests
		self.pendingRequests.forEach { request in
			request()
		}
		self.pendingRequests.removeAll()
	}
	
	/// Returns a repository entry for the given name, if available.
	private func entry(for bundle: App.Bundle) -> Entry? {
		let name = bundle.fileURL.lastPathComponent

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
	
	/// The URL where the cached repository will be stored.
	private var cacheURL: URL? = {
		if #available(macOS 11.0, *) {
			FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
				.appendingPathComponent(Bundle.main.bundleIdentifier!)
				.appendingPathComponent("RepositoryCache").appendingPathExtension(for: .json)
		} else {
			FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
				.appendingPathComponent(Bundle.main.bundleIdentifier!)
				.appendingPathComponent("RepositoryCache").appendingPathExtension("json")
		}
	}()
	
	/// Loads the repository data.
	private func load() {
		// Check for valid cache file
		let timeInterval = UserDefaults.standard.double(forKey: CacheUpdateDateKey) as TimeInterval
		if timeInterval > 0, timeInterval.distance(to: Date.timeIntervalSinceReferenceDate) < Self.cacheInvalidationDuration, 
			let cacheURL = self.cacheURL, let data = try? Data(contentsOf: cacheURL)  {
			parse(data)
			return
		}
		
		// Fetch data from server
		let session = URLSession(configuration: .default)
		let task = session.dataTask(with: Self.repositoryURL) { [weak self] data, response, error in
			guard let self else { return }
			
			self.parse(data)
			
			// Store in cache
			if let data, let cacheURL = self.cacheURL {
				try? data.write(to: cacheURL)
				UserDefaults.standard.setValue(Date.timeIntervalSinceReferenceDate, forKey: CacheUpdateDateKey)
			}
		}
		task.resume()
	}
	
	/// Parses the given repository data and finishes loading.
	private func parse(_ repositoryData: Data?) {
		guard let repositoryData else {
			finalize(with: [])
			return
		}
		
		do {
			finalize(with: try JSONDecoder().decode([Entry].self, from: repositoryData))
		} catch {
			finalize(with: [])
		}
	}

}
