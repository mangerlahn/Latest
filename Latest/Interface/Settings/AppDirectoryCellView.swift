//
//  AppDirectoryCellView.swift
//  Latest
//
//  Created by Max Langer on 29.02.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import Cocoa

/// View that holds a single location checked for updates.
class AppDirectoryCellView: NSTableCellView {
	
	/// The label holding the path of the directory.
	@IBOutlet private weak var titleLabel: NSTextField!
	
	/// The image view displaying the directories icon.
	@IBOutlet private weak var iconImageView: NSImageView!
	
	/// The label holding the app count for this directory.
	@IBOutlet private weak var appCountLabel: NSTextField!
	
	/// The activity indicator shown while the apps are being counted.
	@IBOutlet private weak var activityIndicator: NSProgressIndicator!
	
	/// The URL to be displayed by the cell.
	var url: URL? {
		didSet {
			guard url != oldValue else { return }
			setUpView()
		}
	}
	
	private func setUpView() {
		guard let url else {
			titleLabel.stringValue = ""
			iconImageView.image = nil
			appCountLabel.isHidden = true
			return
		}
		
		// Title
		titleLabel.stringValue = url.relativePath
		
		// Image
		iconImageView.image = NSWorkspace.shared.icon(forFile: url.relativePath)
		
		// App Count
		activityIndicator.startAnimation(nil)
		appCountLabel.isHidden = true
		DispatchQueue.global().async {
			let count = BundleCollector.collectBundles(at: url).count
			DispatchQueue.main.async {
				self.appCountLabel.isHidden = false
				self.activityIndicator.stopAnimation(nil)
				self.appCountLabel.stringValue = NumberFormatter.localizedString(from: NSNumber(value: count), number: .none)
			}
		}
	}
	
}
