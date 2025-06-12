//
//  VersionParser.swift
//  Latest
//
//  Created by Max Langer on 29.11.23.
//  Copyright © 2023 Max Langer. All rights reserved.
//

import Foundation

/// Utility to parse version numbers by a fixed set of rules.
enum VersionParser {

	// MARK: - Patterns
	
	private static let buildNumberPatterns: [Pattern] = [
		// Two-letter prefix (IU-1234, IC-1234)
		.init(pattern: "[A-Z]{2}-(.*)", components: [.buildNumber: 1]),

		// Version Number / Build Number (1.2/1234)
		.init(pattern: "(.*)/(.*)", components: [.buildNumber: 2]),
		
		// Build number postfix (1.2 (r1234))
		.init(pattern: ".* \\(r(.*)\\)", components: [.buildNumber: 1]),
		
		// Catch all
		.init(pattern: ".*", components: [.buildNumber: 0])
	]
	
	private static let versionNumberPatterns: [Pattern] = [
		// Build prefix (Build 1234)
		.init(pattern: "Build (.*)", components: [.versionNumber: 1]),
		
		// Version prefix (v1234)
		.init(pattern: "v(.*)", components: [.versionNumber: 1]),
		
		// Commit postfix (1.2-HEAD-123abc / 1.2-stable.123abc)
		.init(pattern: "(.*)-HEAD-.*", components: [.versionNumber: 1]),
		.init(pattern: "(.*)-stable.*", components: [.versionNumber: 1]),
		
		// OSX postfix (1.2.osx2)
		.init(pattern: "(.*).osx.*", components: [.versionNumber: 1]),
		
		// Build number postfix (1.2 (r1234))
		.init(pattern: "(.*) \\(r.*\\)", components: [.versionNumber: 1]),
		
		// word postfixes
		.init(pattern: "(.*)-release", components: [.versionNumber: 1]),
		.init(pattern: "(.*)-latest", components: [.versionNumber: 1]),
		.init(pattern: "(.*)-demo", components: [.versionNumber: 1]),

		// Catch all
		.init(pattern: ".*", components: [.versionNumber: 0])
	]
	
	private static let combinedVersionPatterns: [Pattern] = [
		// Comma or dash separated (1.2,312; 1.2-312)
		.init(pattern: "^^(?:(?:([^,-]*)[,-]){1}([^,-]*))", components: [.versionNumber: 1, .buildNumber: 2]),
		
		// Catch all
		.init(pattern: ".*", components: [.versionNumber: 0])
	]
	
	
	// MARK: - Actions
	
	static func parse(buildNumber: String) -> String? {
		parse(buildNumber, using: buildNumberPatterns).buildNumber
	}
	
	static func parse(versionNumber: String) -> String? {
		parse(versionNumber, using: versionNumberPatterns).versionNumber
	}
	
	static func parse(combinedVersionNumber: String) -> Version {
		parse(combinedVersionNumber, using: combinedVersionPatterns)
	}

	private static func parse(_ versionString: String, using patterns: [Pattern]) -> Version {
		patterns.reduce(Version(versionNumber: nil, buildNumber: nil)) { partialResult, pattern in
			if partialResult.versionNumber != nil || partialResult.buildNumber != nil {
				return partialResult
			}
			
			guard let match = pattern.regex.firstMatch(in: versionString, range: .init(location: 0, length: versionString.count)) else {
				return partialResult
			}
	
			return Version(versionNumber: pattern.string(for: .versionNumber, in: versionString, match: match),
						   buildNumber: pattern.string(for: .buildNumber, in: versionString, match: match))
		}
	}
	
}

extension VersionParser {
	
	/// A pattern after which a given version number should be parsed.
	fileprivate struct Pattern {
		
		/// A component to parse a given version number into.
		enum Component {
			/// The build number part of the number.
			case buildNumber
			
			/// The version number part of the number.
			case versionNumber
		}
		
		/// Initializes the pattern with its string representation and the to be parsed components.
		init(pattern: String, components: [Component : Int]) {
			self.regex = try! NSRegularExpression(pattern: pattern)
			self.components = components
		}
		
		/// The pattern as regular expression.
		let regex: NSRegularExpression
		
		/// The set of components to be parsed from a given version number.
		let components: [Component: Int]
		
		/// Extracts the component as string from the given parsing result.
		func string(for component: Component, in versionString: String, match: NSTextCheckingResult) -> String? {
			guard !versionString.isEmpty, let index = components[component] else {
				return nil
			}
			
			return (versionString as NSString).substring(with: match.range(at: index))
		}
	}

}
