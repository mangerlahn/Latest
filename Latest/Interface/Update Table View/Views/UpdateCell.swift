//
//  UpdateCell.swift
//  Latest
//
//  Created by Max Langer on 26.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

/**
 The cell that is used in the list of available updates
 */
class UpdateCell: NSTableCellView {
	
	// MARK: - View Lifecycle
	
	/// The label displaying the current version of the app
	@IBOutlet private weak var nameTextField: NSTextField!

    /// The label displaying the current version of the app
    @IBOutlet private weak var currentVersionTextField: NSTextField!
    
    /// The label displaying the newest version available for the app
    @IBOutlet private weak var newVersionTextField: NSTextField!
	
	/// The stack view holding the cells contents.
	@IBOutlet private weak var contentStackView: NSStackView!
	
	/// The constraint defining the leading inset of the content.
	@IBOutlet private weak var leadingConstraint: NSLayoutConstraint!
	
	/// The button handling the update of the app.
	@IBOutlet private weak var updateButton: UpdateButton!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		if #available(macOS 11.0, *) {
			self.leadingConstraint.constant = 0;
		} else {
			self.leadingConstraint.constant = 20;
		}
	}
	
    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
			self.updateTextColors()
		}
    }
		
	
	// MARK: - Update Progress
	
	/// The app represented by this cell
	var app: AppBundle? {
		didSet {
			self.updateButton.app = self.app
			self.updateContents()
		}
	}
	
	var filterQuery: String? {
		didSet {
			self.updateTitle()
		}
	}
	
	
	// MARK: - Utilities
	
	private func updateContents() {
		guard let app = self.app, let versionInformation = app.localizedVersionInformation else { return }
		
		self.updateTitle()
		
		// Update the contents of the cell
        self.currentVersionTextField.stringValue = versionInformation.current
        self.newVersionTextField.stringValue = versionInformation.new
        self.newVersionTextField.isHidden = !app.updateAvailable
	}
	    
	private func updateTitle() {
		self.nameTextField.attributedStringValue = self.app?.highlightedName(for: self.filterQuery) ?? NSAttributedString()
	}
	
	private func updateTextColors() {
		if self.backgroundStyle == .emphasized {
			self.nameTextField.textColor = .alternateSelectedControlTextColor
				self.currentVersionTextField.textColor = .alternateSelectedControlTextColor
				self.newVersionTextField.textColor = .alternateSelectedControlTextColor
		} else {
			// Tint the name if the app is not supported
			let supported: Bool
			if let app = self.app {
				supported = type(of: app).supported
			} else {
				supported = false
			}
			
			self.nameTextField.textColor = (supported ? .labelColor : .tertiaryLabelColor)
			self.currentVersionTextField.textColor = (supported ? .secondaryLabelColor : .tertiaryLabelColor)
			self.newVersionTextField.textColor = (supported ? .secondaryLabelColor : .tertiaryLabelColor)
		}

	}
}
