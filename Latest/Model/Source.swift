//
//  Source.swift
//  Latest
//
//  Created by Max Langer on 14.03.22.
//  Copyright © 2022 Max Langer. All rights reserved.
//

import AppKit

extension App {
	
	/// The source of update information.
	enum Source: String, Equatable {
		/// No known source had information about this app. It is unsupported by the update checker.
		case unsupported
		
		/// The Sparkle Updater is the update source.
		case sparkle
		
		/// The Mac App Store is the update source.
		case appStore
		
		/// Homebrew is the update source.
		case homebrew
		
		/// The icon representing the source.
		var sourceIcon: NSImage? {
			switch self {
			case .unsupported:
				return nil
			case .sparkle:
				return NSImage(named: "sparkle")
			case .appStore:
				return NSImage(named: "appstore")
			case .homebrew:
				return NSImage(named: "brew")
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
			case .homebrew:
				return NSLocalizedString("HomebrewSource", comment: "The source name for apps checked via the Homebrew package manager.")
				
			}
		}
		
	}
	
}
