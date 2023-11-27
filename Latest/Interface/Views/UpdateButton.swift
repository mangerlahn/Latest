//
//  UpdateButton.swift
//  Latest
//
//  Created by Max Langer on 1.12.20.
//  Copyright © 2020 Max Langer. All rights reserved.
//

import Cocoa

/// The button controlling and displaying the entire update procedure.
class UpdateButton: NSButton {

	/// Internal state that represents the current display mode
	private enum InterfaceState {
		/// No update progress should be shown.
		case none
		
		/// A state where the update button should be shown.
		case update
		
		/// A state where the open button should be shown.
		case open
		
		/// A progress bar should be shown.
		case progress
		
		/// An indeterminate progress should be shown.
		case indeterminate
		
		/// An error should be shown.
		case error
		
		var contentType: UpdateButtonCell.ContentType {
			switch self {
			case .none:
				return .none
			case .update, .open, .error:
				return .button
			case .progress:
				return .progress
			case .indeterminate:
				return .indeterminate
			}
		}
	}
	
	/// Whether an action button such as "Open" or "Update" should be displayed
	@IBInspectable var showActionButton: Bool = true
	
	/// The app for which update progress should be displayed.
	var app: App? {
		willSet {
			// Remove observer from existing app
			if let app = self.app {
				UpdateQueue.shared.removeObserver(self, for: app.identifier)
			}
		}
		
		didSet {
			if let app = self.app {
				UpdateQueue.shared.addObserver(self, to: app.identifier) { [weak self] progress in
					self?.updateInterface(with: progress)
				}
			} else {
				self.isHidden = true
			}
		}
	}
	
	/// The cell handling the drawing for this button.
	var contentCell: UpdateButtonCell {
		return self.cell as! UpdateButtonCell
	}
	
	/// The background color for this button. Animatable.
	@objc dynamic var backgroundColor: NSColor = #colorLiteral(red: 0.9488552213, green: 0.9487094283, blue: 0.9693081975, alpha: 1) {
		didSet {
			self.needsDisplay = true
		}
	}

	/// Temporary reference to the last occurred error.
	private var error: Error?
	
	
	// MARK: - Initialization
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.target = self;
		self.action = #selector(performAction(_:))
		
		self.isBordered = false
		if #available(OSX 10.14, *) {
			self.contentTintColor = .controlAccentColor
		}
	}
	
	deinit {
		if let app = self.app {
			UpdateQueue.shared.removeObserver(self, for: app.identifier)
		}
	}

	
	// MARK: - Interface Updates
	
	override var intrinsicContentSize: NSSize {
		var size = super.intrinsicContentSize
		size.height = 21
		
		if (self.title.count > 0) {
			size.width += 12
		} else {
			size.height += 4
			size.width = size.height
		}
		
		return size
	}
		
	/// Updates the UI state with the given progress definition.
	private func updateInterface(with state: UpdateOperation.ProgressState) {
		switch state {
		case .none:
			if let app = self.app, self.showActionButton {
				self.updateInterfaceVisibility(with: app.updateAvailable ? .update : .open)
			} else {
				self.updateInterfaceVisibility(with: .none)
			}
		
		case .pending:
			self.updateInterfaceVisibility(with: .indeterminate)
			self.toolTip = NSLocalizedString("WaitingUpdateStatus", comment: "Update progress state of waiting to start an update")
		
		case .initializing:
			self.updateInterfaceVisibility(with: .indeterminate)
			self.toolTip = NSLocalizedString("InitializingUpdateStatus", comment: "Update progress state of initializing an update")
		
		case .downloading(let loadedSize, let totalSize):
			self.updateInterfaceVisibility(with: .progress)
			
			// Downloading goes to 75% of the progress
			self.contentCell.updateProgress = (Double(loadedSize) / Double(totalSize)) * 0.75
			
			let byteFormatter = ByteCountFormatter()
			byteFormatter.countStyle = .file
			
			let formatString = NSLocalizedString("DownloadingUpdateStatus", comment: "Update progress state of downloading an update. The first %@ stands for the already downloaded bytes, the second one for the total amount of bytes. One expected output would be 'Downloading 3 MB of 21 MB'")
			self.toolTip = String.localizedStringWithFormat(formatString, byteFormatter.string(fromByteCount: loadedSize), byteFormatter.string(fromByteCount: totalSize))
		
		case .extracting(let progress):
			self.updateInterfaceVisibility(with: .progress)
			
			// Extracting goes to 95%
			self.contentCell.updateProgress = 0.75 + (progress * 0.25)
			self.toolTip = NSLocalizedString("ExtractingUpdateStatus", comment: "Update progress state of extracting the downloaded update")
		
		case .installing:
			self.updateInterfaceVisibility(with: .indeterminate)
			self.toolTip = NSLocalizedString("InstallingUpdateStatus", comment: "Update progress state of installing an update")
		
		case .error(let error):
			self.updateInterfaceVisibility(with: self.showActionButton ? .error : .none)
			self.error = error
		
		case .cancelling:
			self.updateInterfaceVisibility(with: .indeterminate)
			self.toolTip = NSLocalizedString("CancellingUpdateStatus", comment: "Update progress state of cancelling an update")
		}
	}
	
	/// Updates the visibility of single views with the given state.
	private var interfaceState: InterfaceState = .none
	private func updateInterfaceVisibility(with state: InterfaceState) {
		self.isHidden = (state == .none)

		// Nothing to update
		guard self.interfaceState != state || self.contentCell.contentType != state.contentType else {
			return
		}
		
		self.interfaceState = state
		self.contentCell.contentType = state.contentType
		
		var title: String?
		var image: NSImage?
		switch state {
		case .update:
			title = NSLocalizedString("UpdateAction", comment: "Action to update a given app.")
		case .open:
			title = NSLocalizedString("OpenAction", comment: "Action to open a given app.")
		case .error:
			if #available(OSX 11.0, *) {
				image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: NSLocalizedString("ErrorButtonAccessibilityTitle", comment: "Description of button that opens an error dialogue."))
			} else {
				image = NSImage(named: "warning")!
			}
		default:
			()
		}
		
		// Beginning with macOS 14, the button text is no longer uppercase
		if #available(macOS 14.0, *) {
			self.title = title ?? ""
		} else {
			self.title = title?.localizedUppercase ?? ""
		}
		self.image = image
	}
	
	
	// MARK: - Actions
	
	@objc func performAction(_ sender: UpdateButton) {
		switch self.interfaceState {
		case .update:
			self.app?.performUpdate()
		case .open:
			self.app?.open()
		case .progress:
			self.app?.cancelUpdate()
		case .error:
			self.presentErrorModally()
			
		// Do nothing in the other states
		default:
			()
		}
	}
	
}

// MARK: - Error Handling

private extension UpdateButton {
	
	/// Responses to error alerts shown to the user.
	enum ErrorAlertResponse: Int {
		/// The update operation should be rescheduled.
		case retry = 1000
		
		/// No further action is required.
		case cancel = 1001
	}
	
	/// Presents the stored error as modal alert.
	private func presentErrorModally() {
		if let error = self.error, let window = self.window {
			self.alert(for: error).beginSheetModal(for: window) { (response) in
				switch ErrorAlertResponse(rawValue: response.rawValue) {
				case .retry:
					self.app?.performUpdate()
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
		
		let message = NSLocalizedString("UpdateErrorAlertTitle", comment: "Title of alert stating that an error occurred during an app update. The placeholder %@ will be replaced with the name of the app.")
		alert.messageText = String.localizedStringWithFormat(message, self.app!.name)
		
		alert.informativeText = error.localizedDescription
		
		alert.addButton(withTitle: NSLocalizedString("RetryAction", comment: "Button to retry an update in an error dialogue"))
		alert.addButton(withTitle: NSLocalizedString("CancelAction", comment: "Cancel button in an update dialogue"))
		
		return alert
	}
	
}

// MARK: - Animator Proxy
extension UpdateButton {
	 override func animation(forKey key: NSAnimatablePropertyKey) -> Any? {
		switch key {
		case "backgroundColor":
			return CABasicAnimation()
			
		default:
			return super.animation(forKey: key)
		}
	}
}
