//
//  AppUpdater.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

extension App {
	
	/// An object representing a single application that is available on the computer.
	class Bundle {
		
		typealias Identifier = URL
		
		/// The version currently present on the users computer
		let version: Version
		
		/// The display name of the app
		let name: String
		
		/// The bundle identifier of the app
		let identifier: Identifier
		
		let bundleIdentifier: String
		
		/// The url of the app on the users computer
		let fileURL: URL
		
		let source: Source
		
		init(version: Version, name: String, bundleIdentifier: String, fileURL: URL, source: Source) {
			self.version = version
			self.name = name
			self.identifier = fileURL
			self.bundleIdentifier = bundleIdentifier
			self.fileURL = fileURL
			self.source = source
		}
		
		
		// MARK: - Secure Coding
		
		static var supportsSecureCoding: Bool {
			return true
		}
		
		required convenience init?(coder: NSCoder) {
			let versionNumber = coder.decodeObject(of: NSString.self, forKey: "versionNumber") as String?
			let buildNumber = coder.decodeObject(of: NSString.self, forKey: "buildNumber") as String?
			
			guard let name = coder.decodeObject(of: NSString.self, forKey: "name") as String?,
				  let bundleIdentifier = coder.decodeObject(of: NSString.self, forKey: "bundleIdentifier") as String?,
				  let fileURL = coder.decodeObject(of: NSURL.self, forKey: "fileURL") as URL?,
				  let rawSource = coder.decodeObject(of: NSString.self, forKey: "source") as String?, let source = Source(rawValue: rawSource) else { return nil }
			
			self.init(version: Version(versionNumber: versionNumber, buildNumber: buildNumber), name: name, bundleIdentifier: bundleIdentifier, fileURL: fileURL, source: source)
		}
		
		func encode(with coder: NSCoder) {
			coder.encode(self.version.versionNumber, forKey: "versionNumber")
			coder.encode(self.version.buildNumber, forKey: "buildNumber")
			coder.encode(self.name, forKey: "name")
			coder.encode(self.identifier, forKey: "bundleIdentifier")
			coder.encode(self.fileURL, forKey: "fileURL")
			coder.encode(self.source.rawValue, forKey: "source")
		}
	}
	
}

extension App.Bundle: Equatable {
    /// Compares two apps on equality
    static func ==(lhs: App.Bundle, rhs: App.Bundle) -> Bool {
        return lhs.fileURL == rhs.fileURL
    }
}

extension App.Bundle: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(self.identifier)
		hasher.combine(self.version)
	}
}

extension App.Bundle: CustomDebugStringConvertible {
	var debugDescription: String {
		return "\(name), \(version)"
	}
}

extension App.Bundle {
	
	/// The source of update information.
	enum Source: String, Equatable {
		/// No known source had information about this app. It is unsupported by the update checker.
		case unsupported
		
		/// The Sparkle Updater is the update source.
		case sparkle
		
		/// The Mac App Store is the update source.
		case appStore
		
		/// The icon representing the source.
		var sourceIcon: NSImage? {
			switch self {
			case .unsupported:
				return nil
			case .sparkle:
				return NSImage(named: "sparkle")!
			case .appStore:
				return NSImage(named: "AppStoreSource")
			}
		}
		
		/// The name of the source.
		var sourceName: String? {
			switch self {
			case .unsupported:
				return nil
			case .sparkle:
				return NSLocalizedString("WebSource", comment: "The source name for apps loaded from third-party websites.")
			case .appStore:
				return NSLocalizedString("AppStoreSource", comment: "The source name of apps loaded from the App Store.")
			}
		}
		
	}
	
}
