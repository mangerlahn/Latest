//
//  UpdateProgressView.swift
//  Latest
//
//  Created by Max Langer on 14.07.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Cocoa

class UpdateProgressViewController: NSViewController {
	
	private enum InterfaceState {
		case none
		case update
		case indeterminate
		case error
	}
	
	@IBOutlet weak var progressSection: NSStackView!
	@IBOutlet weak var warningButton: NSButton!
	
	@IBOutlet weak var cancelButton: NSButton!
	@IBOutlet weak var progressIndicator: NSProgressIndicator!
	
	@IBOutlet weak var progressLabel: NSTextField!
	
	var app: AppBundle? {
		willSet {
			// Remove observer from existing app
			if let app = self.app {
				app.updateProgress.removeObserver(self)
			}
		}
		
		didSet {
			if let app = self.app {
				app.updateProgress.addObserver(self, handler: { [weak self] progress in
					self?.updateInterface(with: progress)
				})
			} else {
				self.view.isHidden = true
			}
		}
	}

	@IBAction func cancelUpdate(_ sender: NSButton) {
		self.app?.cancelUpdate()
	}
	
	deinit {
		self.app?.updateProgress.removeObserver(self)
	}
	
	override func viewDidLoad() {
		self.progressIndicator.startAnimation(self)
	}
	
	private func updateInterface(with progress: UpdateProgress) {
		switch progress.state {
		case .none:
			self.updateInterface(with: .none)
		case .pending:
			self.updateInterface(with: .indeterminate)
			self.progressLabel.stringValue = NSLocalizedString("Waiting", comment: "Update progress state of waiting to start an update")
		case .initializing:
			self.updateInterface(with: .indeterminate)
			self.progressLabel.stringValue = NSLocalizedString("Initializing", comment: "Update progress state of initializing an update")
		case .downloading(let progress, let loadedSize, let totalSize):
			self.updateInterface(with: .update)
			self.progressIndicator.doubleValue = progress
			
			let byteFormatter = ByteCountFormatter()
			byteFormatter.countStyle = .file
			self.progressLabel.stringValue = NSLocalizedString("Downloading ", comment: "Update progress state of downloading an update") + byteFormatter.string(fromByteCount: loadedSize) + " of " + byteFormatter.string(fromByteCount: totalSize)
		case .installing:
			self.updateInterface(with: .indeterminate)
			self.progressLabel.stringValue = NSLocalizedString("Installing", comment: "Update progress state of installing an update")
		case .error(let error):
			self.updateInterface(with: .error)
			print(error)
		case .cancelling:
			self.updateInterface(with: .indeterminate)
			self.progressLabel.stringValue = NSLocalizedString("Cancelling", comment: "Update progress state of cancelling an update")
		}
	}
	
	private func updateInterface(with state: InterfaceState) {
		self.view.isHidden = (state == .none)
		self.warningButton.isHidden = (state != .error)
		self.progressSection.isHidden = (state == .update && state == .indeterminate)
		
		if state == .indeterminate {
			if (!self.progressIndicator.isIndeterminate) {
				self.progressIndicator.isIndeterminate = true
				self.progressIndicator.startAnimation(self)
			}
		} else {
			if (self.progressIndicator.isIndeterminate) {
				self.progressIndicator.stopAnimation(self)
				self.progressIndicator.isIndeterminate = false
			}
		}
	}

}
