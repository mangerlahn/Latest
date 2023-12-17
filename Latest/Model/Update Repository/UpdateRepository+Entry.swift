//
//  UpdateRepository.swift
//  Latest
//
//  Created by Max Langer on 01.10.23.
//  Copyright © 2023 Max Langer. All rights reserved.
//

import AppKit

extension UpdateRepository {
	
	/// Represents one application within the repository.
	struct Entry: Decodable {
		
		
		// MARK:  - Structure
		
		enum CodingKeys: String, CodingKey {
			case artifacts
			case token
			case rawVersion = "version"
			case minimumOSVersion = "depends_on"
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
		
		/// Possible names of the app.
		///
		/// Used for matching app bundles with repository entries.
		let names: Set<String>
		
		/// Possible bundle identifiers of the app.
		///
		/// Used for matching app bundles with repository entries.
		let bundleIdentifiers: Set<String>
		
		/// The raw version string of the app.
		private let rawVersion: String
		
		/// The brew identifier for the app.
		let token: String
		
		/// The minimum os version required for the update.
		let minimumOSVersion: OperatingSystemVersion?
				
		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			
			// Trivial keys
			rawVersion = try container.decode(String.self, forKey: .rawVersion)
			token = try container.decode(String.self, forKey: .token)
			
			// Artifacts: Contains application names and bundle identifiers.
			let artifacts = try container.decode([FailableDecodable<Artifact>].self, forKey: .artifacts)
				.reduce((names: [String](), identifiers: [String]())) { partialResult, artifactWrapper in
					guard let artifact = artifactWrapper.base else {
						return partialResult
					}
					
					var result = partialResult
					result.names.append(contentsOf: artifact.names)
					result.identifiers.append(contentsOf: artifact.identifiers)
					
					return result
				}
			names = Set(artifacts.names)
			bundleIdentifiers = Set(artifacts.identifiers)

			// OS Version
			if let osVersion = try container.decode(MinimumOS.self, forKey: .minimumOSVersion).macos?.version?.first {
				minimumOSVersion = try OperatingSystemVersion(string: osVersion)
			} else {
				minimumOSVersion = nil
			}
		}
		
		
		// MARK: - Accessors
		
		/// The current version of the app.
		var version: Version {
			return VersionParser.parse(combinedVersionNumber: rawVersion)
		}
		
	}

}

fileprivate extension UpdateRepository.Entry {
	
	/// One entry datapoint containing possible application names and bundle identifiers.
	struct Artifact: Decodable {
		
		/// Possible application names.
		let names: Set<String>
		
		/// Possible bundle identifiers.
		let identifiers: Set<String>
		
		private enum CodingKeys: String, CodingKey {
			/// Contains application names
			case app
			
			/// Contains paths to files and folders that should be deleted upon deinstallation.
			///
			/// These paths usually contain the bundle identifier of an app so we extract those from the paths.
			case zap
			
			/// Contains file paths and identifiers.
			///
			/// Both app names and identifiers can be extracted from this data set.
			case uninstall
		}
		
		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			
			// App names, if present no identifiers will be parsed.
			if let appNames = try? Self.decodeAppNames(container) {
				self.names = Set(appNames)
				self.identifiers = []
				return
			}
			
			// Extract everything else.
			var identifiers = (try? Self.decodeZap(container)) ?? []
			if let uninstall = try? Self.decodeUninstall(container) {
				names = Set(uninstall.names)
				identifiers.append(contentsOf: uninstall.identifiers)
			} else {
				names = []
			}
			
			self.identifiers = Set(identifiers.flatMap { path in
				let string = path as NSString
				guard !string.pathExtension.isEmpty else { return [String]() }
				let identifier = string.lastPathComponent
				return [identifier, (identifier as NSString).deletingPathExtension]
			})
			
		}
		
		
		// MARK: - Decoding
		
		private static func decodeAppNames(_ container: KeyedDecodingContainer<CodingKeys>) throws -> [String] {
			struct Target: Decodable {
				let target: String
			}
			
			var appContainer = try container.nestedUnkeyedContainer(forKey: .app)
			var names: [String] = []
			while !appContainer.isAtEnd {
				do {
					let target = try appContainer.decode(Target.self)
					names.append(target.target)
				} catch {
					let stringValue = try appContainer.decode(String.self)
					names.append(stringValue)
				}
			}
			
			return names
		}
		
		private static func decodeZap(_ container: KeyedDecodingContainer<CodingKeys>) throws -> [String] {
			enum ZapKeys: String, CodingKey {
				case trash
			}
			
			var nestedContainer = try container.nestedUnkeyedContainer(forKey: .zap)
			let zapContainer = try nestedContainer.nestedContainer(keyedBy: ZapKeys.self)
			return try zapContainer.decodeVariable(String.self, forKey: .trash)
		}
		
		private static func decodeUninstall(_ container: KeyedDecodingContainer<CodingKeys>) throws -> (names: [String], identifiers: [String]) {
			enum UninstallKeys: String, CodingKey {
				/// List of bundle identifiers of binaries to be closed before uninstallation.
				case quit
				
				/// List of binary paths to be deleted separately.
				case delete
				
				/// List of bundle identifiers of binaries to be deleted separately..
				case pkgutil
			}
			
			guard var a = try? container.nestedUnkeyedContainer(forKey: .uninstall), let uninstallContainer = try? a.nestedContainer(keyedBy: UninstallKeys.self) else { return ([],[]) }
			
			// Try to get application names
			let names: [String] = (try? uninstallContainer.decodeVariable(String.self, forKey: .delete))?.compactMap { path in
				let url = URL(fileURLWithPath: path)
				guard url.pathExtension == "app" else { return nil }
				return url.lastPathComponent
			} ?? []
			
			// Try to get bundle identifiers
			let identifiers = [UninstallKeys.pkgutil, .quit].flatMap { key in
				(try? uninstallContainer.decodeVariable(String.self, forKey: key)) ?? []
			}
			
			return (names, identifiers)
		}
		
	}

}

fileprivate extension KeyedDecodingContainer {
	
	/// Returns an array with objects of the given type for the given key.
	///
	/// Can decode single objects and arrays.
	func decodeVariable<T>(_ type: T.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> [T] where T : Decodable {
		var value: [T] = []
		do {
			// Attempt to decode single object.
			let identifier = try decode(T.self, forKey: key)
			value.append(identifier)
		} catch {
			// Must be an array now.
			value = try decode([T].self, forKey: key)
		}
		return value
	}
	
}

