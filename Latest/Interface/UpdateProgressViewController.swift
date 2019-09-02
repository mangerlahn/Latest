//
//  UpdateProgressView.swift
//  Latest
//
//  Created by Max Langer on 14.07.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

import Cocoa

/// The controller handling update progress states on the UI-level
class UpdateProgressViewController: NSViewController {
	
	deinit {
		if let app = self.app {
			UpdateQueue.shared.removeObserver(self, for: app)
		}
	}
	
	// MARK: - Accessors
	
	/// The anchor with which the progress bar can be aligned to a user interface element.
	var leadingProgressAnchor: NSLayoutXAxisAnchor {
		return self.progressIndicator.leadingAnchor
	}
	
	/// Whether the cancel button should be displayed.
	var displayCancelButton = true
	
	/// The app for which update progress should be displayed.
	var app: AppBundle? {
		willSet {
			// Remove observer from existing app
			if let app = self.app {
				UpdateQueue.shared.removeObserver(self, for: app)
			}
		}
		
		didSet {
			if let app = self.app {
				UpdateQueue.shared.addObserver(self, to: app) { [weak self] progress in
					self?.updateInterface(with: progress)
				}
			} else {
				self.view.isHidden = true
			}
		}
	}

	
	// MARK: - Interface Definitions
	
	/// Internal state that represents the current display mode
	private enum InterfaceState {
		/// No update progress should be shown.
		case none
		
		/// A progress bar should be shown.
		case progress
		
		/// An indeterminate progress should be shown.
		case indeterminate
		
		/// An error should be shown.
		case error
	}
	
	/// The stack view holding the progress bar and cancel button. These two views are always shown together.
	@IBOutlet private weak var progressSection: NSStackView!
	
	/// The warning button, indicating that the update process was cancelled due to an error.
	@IBOutlet private weak var warningButton: NSButton!
	
	/// The button to cancel the update operation.
	@IBOutlet private weak var cancelButton: NSButton!
	
	/// The process indicator used to display progress and indeterminate states.
	@IBOutlet private weak var progressIndicator: NSProgressIndicator!
	
	/// The label used for informing about the current state.
	@IBOutlet private weak var progressLabel: NSTextField!
	
	/// Forwards an update operation cancellation to the app.
	@IBAction private func cancelUpdate(_ sender: NSButton) {
		self.app?.cancelUpdate()
	}
	
	/// Updates the UI state with the given progress definition.
	private func updateInterface(with state: UpdateOperation.ProgressState) {
		switch state {
		case .none:
			self.updateInterfaceVisibility(with: .none)
		
		case .pending:
			self.updateInterfaceVisibility(with: .indeterminate)
			self.progressLabel.stringValue = NSLocalizedString("Waiting", comment: "Update progress state of waiting to start an update")
		
		case .initializing:
			self.updateInterfaceVisibility(with: .indeterminate)
			self.progressLabel.stringValue = NSLocalizedString("Initializing", comment: "Update progress state of initializing an update")
		
		case .downloading(let loadedSize, let totalSize):
			self.updateInterfaceVisibility(with: .progress)
			self.progressIndicator.doubleValue = Double(loadedSize) / Double(totalSize)
			
			let byteFormatter = ByteCountFormatter()
			byteFormatter.countStyle = .file
			
			let formatString = NSLocalizedString("Downloading %@ of %@", comment: "Update progress state of downloading an update. The first %@ stands for the already downloaded bytes, the second one for the total amount of bytes. One expected output would be 'Downloading 3 MB of 21 MB'")
			self.progressLabel.stringValue = String.localizedStringWithFormat(formatString, byteFormatter.string(fromByteCount: loadedSize), byteFormatter.string(fromByteCount: totalSize))
		
		case .extracting(let progress):
			self.updateInterfaceVisibility(with: .progress)
			self.progressIndicator.doubleValue = progress
			self.progressLabel.stringValue = NSLocalizedString("Extracting Update", comment: "Update progress state of extracting the downloaded update")
		
		case .installing:
			self.updateInterfaceVisibility(with: .indeterminate)
			self.progressLabel.stringValue = NSLocalizedString("Installing", comment: "Update progress state of installing an update")
		
		case .error(let error):
			self.updateInterfaceVisibility(with: .error)
			print(error)
		
		case .cancelling:
			self.updateInterfaceVisibility(with: .indeterminate)
			self.progressLabel.stringValue = NSLocalizedString("Cancelling", comment: "Update progress state of cancelling an update")
		}
	}
		
	/// Updates the visibility of single views with the given state.
	private func updateInterfaceVisibility(with state: InterfaceState) {
		self.view.isHidden = (state == .none)
		self.warningButton.isHidden = (state != .error)
		self.progressSection.isHidden = (state != .progress && state != .indeterminate)
		self.progressLabel.isHidden = self.progressSection.isHidden
		
		self.cancelButton.isHidden = !self.displayCancelButton
		
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

// MARK: - Error Handling

private extension UpdateProgressViewController {
	
	/// Responses to error alerts shown to the user.
	enum ErrorAlertResponse: Int {
		/// The update operation should be rescheduled.
		case retry = 1000
		
		/// No further action is required.
		case cancel = 1001
	}
	
	/// Presents the stored error as modal alert.
	@IBAction private func presentErrorModally(_ sender: NSButton) {
		guard let app = self.app else { return }
		
		if case .error(let error) = UpdateQueue.shared.state(for: app), let window = self.view.window {
			self.alert(for: error).beginSheetModal(for: window) { (response) in
				switch ErrorAlertResponse(rawValue: response.rawValue) {
				case .retry:
					self.app?.update()
				case .cancel, .none:
					()
				}
			}
		}
	}
	
	/// Configures and returns an alert for the given error.
	private func alert(for error: Error) -> NSAlert {
		let alert = NSAlert()
		alert.alertStyle = .informational
		
		let message = NSLocalizedString("An error occurred while updating %@.", comment: "Title of alert stating that an error occurred during an app update. %@ is the name of the app.")
		alert.messageText = String.localizedStringWithFormat(message, self.app!.name)
		
		alert.informativeText = error.localizedDescription
		
		alert.addButton(withTitle: NSLocalizedString("Retry", comment: "Button to retry an update in an error dialogue"))
		alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel button in an update dialogue"))
		
		return alert
	}
	
}
