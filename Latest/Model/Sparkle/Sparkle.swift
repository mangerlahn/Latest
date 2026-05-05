//
//  Sparkle.swift
//  Latest
//
//  Created by Max Langer on 23.04.22.
//  Copyright © 2022 Max Langer. All rights reserved.
//

import Foundation

struct Sparke {
	
	/// Returns the Sparkle feed url for the app at the given URL, if available.
	static func feedURL(from bundle: Bundle) -> URL? {
		guard let information = bundle.infoDictionary, let identifier = bundle.bundleIdentifier else {
			return nil
		}

		if let urlString = information["SUFeedURL"] as? String, let feedURL = URL(string: urlString.unquoted)  {
			return Self.adjustedFeedURL(feedURL, bundleIdentifier: identifier, executableArchitectures: bundle.executableArchitectures)
		} else { // Maybe the app is built using DevMate
			// Check for the DevMate framework
			let frameworksURL = URL(fileURLWithPath: bundle.bundlePath, isDirectory: true).appendingPathComponent("Contents").appendingPathComponent("Frameworks")
			
			let frameworks = try? FileManager.default.contentsOfDirectory(atPath: frameworksURL.path)
			if !(frameworks?.contains(where: { $0.contains("DevMateKit") }) ?? false) {
				return nil
			}
			
			// The app uses Devmate, so lets get the appcast from their servers
			guard var feedURL = URL(string: "https://updates.devmate.com") else {
				return nil
			}
			
			feedURL.appendPathComponent(identifier)
			feedURL.appendPathExtension("xml")
			
			return feedURL
		}
	}
	
	static func adjustedFeedURL(_ feedURL: URL, bundleIdentifier: String, executableArchitectures: [NSNumber]?) -> URL {
		guard Self.usesWiresharkArchitectureSpecificFeed(feedURL, bundleIdentifier: bundleIdentifier),
			  let architecture = Self.architecturePathComponent(from: executableArchitectures),
			  var components = URLComponents(url: feedURL, resolvingAgainstBaseURL: false) else {
			return feedURL
		}

		var pathComponents = components.path.split(separator: "/").map(String.init)
		guard pathComponents.count >= 6 else {
			return feedURL
		}

		pathComponents[5] = architecture
		components.path = "/\(pathComponents.joined(separator: "/"))"

		return components.url ?? feedURL
	}

	private static func usesWiresharkArchitectureSpecificFeed(_ feedURL: URL, bundleIdentifier: String) -> Bool {
		guard ["org.wireshark.Wireshark", "org.wireshark.Stratoshark"].contains(bundleIdentifier),
			  ["wireshark.org", "www.wireshark.org"].contains(feedURL.host ?? "") else {
			return false
		}

		let pathComponents = feedURL.path.split(separator: "/").map(String.init)
		guard pathComponents.count >= 8 else {
			return false
		}

		return pathComponents[0] == "update"
			&& pathComponents[1] == "0"
			&& pathComponents[4] == "macOS"
	}

	private static func architecturePathComponent(from executableArchitectures: [NSNumber]?) -> String? {
		guard let executableArchitectures else {
			return nil
		}

		if #available(macOS 11.0, *),
		   executableArchitectures.contains(where: { $0.intValue == NSBundleExecutableArchitectureARM64 }) {
			return "arm64"
		}

		if executableArchitectures.contains(where: { $0.intValue == NSBundleExecutableArchitectureX86_64 }) {
			return "x86-64"
		}

		if executableArchitectures.contains(where: { $0.intValue == NSBundleExecutableArchitectureI386 }) {
			return "x86"
		}

		return nil
	}

}

fileprivate extension String {
	
	/// Returns the string with quotation marks trimmed.
	var unquoted: String {
		return NSString(string: self).trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
	}
	
}
