//
//  MacAppStoreUpdateCheckerOperation.swift
//  Latest
//
//  Created by Max Langer on 03.10.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Cocoa

/// The operation for checking for updates for a Mac App Store app.
class UnsupportedUpdateCheckerOperation: StatefulOperation, UpdateCheckerOperation {
		
	/// The bundle that is not supported.
	private let app: UnsupportedAppBundle
			
	required init?(withAppURL appURL: URL, version: String, buildNumber: String, completionBlock: @escaping UpdateCheckerCompletionBlock) {
        let appName = appURL.lastPathComponent as NSString
		let bundle = Bundle(path: appURL.path)
		
		guard let identifier = bundle?.bundleIdentifier else {
			return nil
		}
		self.app = UnsupportedAppBundle(appName: appName.deletingPathExtension, bundleIdentifier: identifier, versionNumber: version, buildNumber: buildNumber, url: appURL)

		super.init()

		self.completionBlock = {
			completionBlock(self.app)
		}
	}

	override func execute() {
		// Nothing to check for, finish immediately
		self.finish()
	}
	
}
