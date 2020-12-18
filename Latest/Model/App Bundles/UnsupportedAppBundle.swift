//
//  SparkleAppUpdate.swift
//  Latest
//
//  Created by Max Langer on 07.04.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

/**
 Sparkle subclass of the app bundle. This handles the parsing of the sparkle feed.
 */
class UnsupportedAppBundle: AppBundle {
	
	/// The icon representing the source of the app.
	override class var sourceIcon: NSImage? {
		return nil
	}
	
	/// The name of the app's source.
	override class var sourceName: String? {
		return nil
	}
	
	/// Provide Sparkle specifig update method.
	override func update() {
		fatalError("Attempted to update unsupported app.")
	}
	
}
