//
//  MacAppStoreAppUpdate.swift
//  Latest
//
//  Created by Max Langer on 07.04.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa
import CommerceKit

/**
 Mac App Store app bundle subclass, it handles the parsing of the iTunes JSON
 */
class MacAppStoreAppBundle: AppBundle {

    /// The url of the app in the Mac App Store
    var appStoreURL : URL?
	
	/// The update information provided by CommerceKit, if available
	var updateInformation: CKUpdate? {
		return CKUpdateController.shared()?.availableUpdates().first(where: { $0.bundleID == self.bundleIdentifier })
	}
	
	/// The icon representing the source of the app.
	override class var sourceIcon: NSImage {
		return NSImage(named: "appstore")!
	}
	
	
	// MARK: - Actions
	
	override func open() {
		// Should preferably open the Mac App Store
		NSWorkspace.shared.open(self.appStoreURL ?? self.url)
	}
	
	override func update() {
		// This is a temporary workaround to disable direct updates of Mac App Store apps, which does not work anymore.
		self.open()
		// UpdateQueue.shared.addOperation(MacAppStoreUpdateOperation(app: self))
	}
	
}
