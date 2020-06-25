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
class SparkleAppBundle: AppBundle {
	
	/// The icon representing the source of the app.
	override class var sourceIcon: NSImage {
		return NSImage(named: "sparkle")!
	}
	
	/// The name of the app's source.
	override class var sourceName: String {
		return NSLocalizedString("Web", comment: "The source name for apps loaded from third-party websites.")
	}
    
	/// Provide Sparkle specifig update method.
    override func update() {
		UpdateQueue.shared.addOperation(SparkleUpdateOperation(app: self))
	}
	
}
