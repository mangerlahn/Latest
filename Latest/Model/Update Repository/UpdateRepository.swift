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
	
	/// Queue on which requests will be handled.
	private var queue = DispatchQueue(label: "repositoryQueue")

	// MARK: - Init
	
	let fetchCompletedGroup = DispatchGroup()
	
	private init() {
		fetchCompletedGroup.enter()
		fetchCompletedGroup.notify(queue: .main) { [weak self] in
			self?.finalize()
		}
	}
	
	/// Creates a repository from the given entries without fetching anything. Used for testing.
	init(entries: [Entry]) {
		self.entries = entries
		self.entriesByIdentifier = Self.index(entries)
		self.unsupportedBundleIdentifiers = []
		self.pendingRequests = nil
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
		queue.async { [weak self] in
			guard let self else { return }
			
			if self.pendingRequests != nil {
				self.pendingRequests?.append(checkApp)
			} else {
				checkApp()
			}
		}
	}
	
	/// List of entries stored within the repository.
	private var entries = [Entry]() {
		didSet { entriesByIdentifier = Self.index(entries) }
	}
	
	/// The entries by lowercased bundle identifier, so matching by identifier does not scan every cask for every app.
	private var entriesByIdentifier = [String: [Entry]]()
	
	private static func index(_ entries: [Entry]) -> [String: [Entry]] {
		var index = [String: [Entry]]()
		for entry in entries {
			for identifier in entry.bundleIdentifiers {
				index[identifier.lowercased(), default: []].append(entry)
			}
		}
		return index
	}
	
	/// A list of requests being performed while the repository was still fetching data.
	///
	/// It also acts as a flag for whether initialization finished. The array is initialized when the repository is created. It will be set to nil once `finalize()` is being called.
	private var pendingRequests: [() -> Void]? = []
	
	/// A set of bundle identifiers for which update checking is currently not supported.
	private var unsupportedBundleIdentifiers: Set<String>!
	
	/// Sets the given entries and performs pending requests.
	private func finalize() {
		queue.async { [weak self] in
			guard let self else { return }
			guard let pendingRequests else {
				fatalError("Finalize must only be called once!")
			}
			
			// Perform any pending requests
			pendingRequests.forEach { request in
				request()
			}
			
			// Mark repository as loaded.
			self.pendingRequests = nil
		}
	}
	
	/// Returns a repository entry for the given name, if available.
	func entry(for bundle: App.Bundle) -> Entry? {
		// Don't return an entry for unsupported apps
		guard !unsupportedBundleIdentifiers.contains(bundle.bundleIdentifier) else { return nil }
		
		// Finding the correct entry is not trivial as there is no bundle identifier stored in an entry. We have a list of app names (could be ambiguous) and a list of bundle identifier guesses.
		// However, both app names and bundle identifiers may occur in more than one entry:
		// - App Names: Might occur multiple times for similar apps (Telegram.app for Desktop vs. Telegram.app for Mac)
		// - Bundle Identifiers: Might occur multiple times for apps in bundles (com.microsoft.word in Word.app and Office bundle)
		//
		// Strategy: Find all entries that point to the given app name. If only one entry comes up, return that. Otherwise, try to match bundle identifiers to narrow it down.
		let name = bundle.fileURL.lastPathComponent
		var possibleEntries = entries.filter { entry in
			return entry.names.contains { n in
				return n.caseInsensitiveCompare(name) == .orderedSame
			}
		}
		
		guard !possibleEntries.isEmpty else { return fallbackEntry(for: bundle) }
		if possibleEntries.count == 1 {
			return possibleEntries.first.flatMap { isPlausible($0, for: bundle) ? $0 : fallbackEntry(for: bundle) }
		}
		
		// Match bundle identifier
		possibleEntries = possibleEntries.filter { entry in
			entry.bundleIdentifiers.contains(bundle.bundleIdentifier)
		}
		
		// Only return an entry if we fixed the disambiguation
		return (possibleEntries.count == 1 ? possibleEntries.first : fallbackEntry(for: bundle))
	}
	
	/// Whether a cask that matched by app name is plausibly the same product as the bundle.
	///
	/// Generic file names ("Studio.app") exist in many unrelated casks. A match is rejected if the cask lists bundle identifiers that share neither the exact identifier nor the vendor with the app, unless the cask's token or display name equals the app's name.
	private func isPlausible(_ entry: Entry, for bundle: App.Bundle) -> Bool {
		let identifier = bundle.bundleIdentifier.lowercased()
		let known = entry.bundleIdentifiers.map { $0.lowercased() }
		guard !identifier.isEmpty, !known.isEmpty, !known.contains(identifier) else { return true }
		
		let vendor = identifier.split(separator: ".").prefix(2).joined(separator: ".")
		if known.contains(where: { $0.split(separator: ".").prefix(2).joined(separator: ".") == vendor }) {
			return true
		}
		
		let appName = Self.normalize(bundle.fileURL.lastPathComponent)
		return Self.normalize(entry.token) == appName || entry.displayNames.contains { Self.normalize($0) == appName }
	}
	
	/// Lowercased alphanumeric form of a name, used to compare names loosely.
	private static func normalize(_ name: String) -> String {
		var name = name.lowercased()
		if name.hasSuffix(".app") { name.removeLast(4) }
		return String(name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
	}
	
	/// Finds an entry for apps whose file name does not appear in the cask data.
	///
	/// A cask is only accepted if its cleanup metadata lists the app's bundle identifier *and* its token or display name resembles the app's name. Either signal alone produces false positives (identifiers are shared between suites, names between unrelated apps), and a wrong match would update the wrong app.
	private func fallbackEntry(for bundle: App.Bundle) -> Entry? {
		let identifier = bundle.bundleIdentifier.lowercased()
		guard !identifier.isEmpty, !identifier.hasPrefix("com.apple.") else { return nil }
		
		let appName = Self.normalize(bundle.fileURL.lastPathComponent)
		guard appName.count >= 4 else { return nil }
		
		func resembles(_ candidate: String) -> Bool {
			let candidate = Self.normalize(candidate)
			guard candidate.count >= 4 else { return false }
			return appName.contains(candidate) || candidate.contains(appName)
		}
		
		let candidates = (entriesByIdentifier[identifier] ?? []).filter { entry in
			resembles(entry.token) || entry.displayNames.contains(where: resembles)
		}
		guard candidates.count > 1 else { return candidates.first }
		
		// Prefer an exact name match.
		let exact = candidates.filter { entry in
			Self.normalize(entry.token) == appName || entry.displayNames.contains { Self.normalize($0) == appName }
		}
		if exact.count == 1 { return exact.first }
		
		// Otherwise prefer the base cask over its variants ("zoom" over "zoom-for-it-admins").
		guard let base = candidates.min(by: { $0.token.count < $1.token.count }) else { return nil }
		let isBase = candidates.allSatisfy { $0.token == base.token || $0.token.hasPrefix(base.token + "-") }
		return isBase ? base : nil
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
			self.entries = entries.filter { !$0.names.isEmpty }
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
				"https://raw.githubusercontent.com/mangerlahn/Latest/main/Latest/Resources/ExcludedAppIdentifiers.plist"
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
