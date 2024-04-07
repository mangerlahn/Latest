//
//  BundleCollector.swift
//  Latest
//
//  Created by Max Langer on 07.03.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

/// Gathers apps at a given URL.
enum BundleCollector {
	
	/// Excluded subfolders that won't be checked.
	private static let excludedSubfolders = Set(["Setapp"])
	
	/// Set of bundles that should not be included in Latest.
	private static let excludedBundleIdentifiers = Set([
		// Safari Web Apps
		"com.apple.Safari.WebApp"
	])
	
	@available(macOS 11.0, *)
	private static let appExtension = UTType.applicationBundle.preferredFilenameExtension
	
	/// Returns a list of application bundles at the given URL.
	static func collectBundles(at url: URL) -> [App.Bundle] {
		let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants])
		
		var bundles = [App.Bundle]()
		while let bundleURL = enumerator?.nextObject() as? URL {
			guard !excludedSubfolders.contains(where: { bundleURL.path.contains($0) }) else {
				enumerator?.skipDescendants()
				continue
			}
			
			let expectedExtension = if #available(macOS 11.0, *) { appExtension } else { "app" }
			if bundleURL.pathExtension == expectedExtension, let bundle = bundle(forAppAt: bundleURL) {
				bundles.append(bundle)
			}
		}

		return bundles
	}
	
	
	// MARK: - Utilities
		
	/// Returns a bundle representation for the app at the given url, without Spotlight Metadata.
	static private func bundle(forAppAt url: URL) -> App.Bundle? {
		guard let appBundle = Bundle(url: url),
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
		
		// Skip bundles which are explicitly excluded
		guard !excludedBundleIdentifiers.contains(where: { identifier.contains($0) }) else {
			return nil
		}
		
		// Build version. Skip bundle if no version is provided.
		let version = Version(versionNumber: VersionParser.parse(versionNumber: versionNumber), buildNumber: VersionParser.parse(buildNumber: buildNumber))
		guard !version.isEmpty else {
			return nil
		}
		
		// Create bundle
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
