//
//  UpdateRepository.swift
//  Latest
//
//  Created by Max Langer on 01.10.23.
//  Copyright © 2023 Max Langer. All rights reserved.
//

import AppKit

/// A storage that fetches update information from an online source.
///
/// Can be asked for update version information for a given application bundle.
class UpdateRepository {

	/// The URL update information is being fetched from.
	private static let repositoryURL = URL(string: "https://formulae.brew.sh/api/cask.json")!

	// MARK: - Init
	
	private init() {}
	
	/// Returns a new repository with up to date update information.
	static func newRepository() -> UpdateRepository {
		let repository = UpdateRepository()
		
		let session = URLSession(configuration: .default)
		let task = session.dataTask(with: repositoryURL) { data, response, error in
			guard let data else {
				repository.finalize(with: [])
				return
			}
			
			do {
				repository.finalize(with: try JSONDecoder().decode([Entry].self, from: data))
			} catch {
				repository.finalize(with: [])
			}
		}
		task.resume()
		
		return repository
	}
	
	
	// MARK: - Accessors
	
	/// Returns update information for the given bundle.
	func updateInfo(for bundle: App.Bundle, handler: @escaping (_ bundle: App.Bundle, _ version: Version?, _ minimumOSVersion: OperatingSystemVersion?) -> Void) {
		let checkApp = {
			guard let entry = self.entry(for: bundle.fileURL.lastPathComponent) else {
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
		self.entries = entries.compactMap { !$0.names.isEmpty ? $0 : nil }
		
		// Perform any pending requests
		self.pendingRequests.forEach { request in
			request()
		}
		self.pendingRequests.removeAll()
	}
	
	/// Returns a repository entry for the given name, if available.
	private func entry(for name: String) -> Entry? {
		return self.entries?.first(where: { entry in
			return entry.names.contains { n in
				return n.caseInsensitiveCompare(name) == .orderedSame
			}
		})
	}

}

extension UpdateRepository {
	
	/// Represents one application within the repository.
	private struct Entry: Decodable {
		
		
		// MARK:  - Structure
		
		enum CodingKeys: String, CodingKey {
			case artifacts
			case token
			case rawVersion = "version"
			case minimumOSVersion = "depends_on"
		}
		
		private struct Artifact: Decodable {
			let app: [String]
		}
		
		private struct MinimumOS: Decodable {
			let macos: Version?
			
			struct Version: Decodable {
				let version: [String]?
				
				enum CodingKeys: String, CodingKey {
					case version = ">="
				}
			}
		}
		
		
		// MARK: - Accessors
		
		/// The name of the app.
		let names: [String]
		
		/// The raw version string of the app.
		private let rawVersion: String
		
		/// The brew identifier for the app.
		let token: String
		
		/// The minimum os version required for the update.
		let minimumOSVersion: OperatingSystemVersion?
				
		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			
			rawVersion = try container.decode(String.self, forKey: .rawVersion)
			token = try container.decode(String.self, forKey: .token)
			names = try container.decode([FailableDecodable<Artifact>].self, forKey: .artifacts).flatMap { $0.base?.app ?? [] }
			
			if let osVersion = try container.decode(MinimumOS.self, forKey: .minimumOSVersion).macos?.version?.first {
				minimumOSVersion = try OperatingSystemVersion(string: osVersion)
			} else {
				minimumOSVersion = nil
			}
		}
		
		
		// MARK: - Accessors
		
		/// The current version of the app.
		var version: Version {
			// Split raw version into components to separate out the version and build number
			let versionComponents =  rawVersion.split(separator: ",")
			
			var components = versionComponents.map { String($0) }
			let version = !components.isEmpty ? components.removeFirst() : nil
			let buildNumber = !components.isEmpty ? components.removeFirst() : nil

			return Version(versionNumber: version, buildNumber: buildNumber)
		}
		
	}

}
