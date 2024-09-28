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
	
	/// Label displaying the last modified/update date for the app.
	@IBOutlet private weak var dateTextField: NSTextField!
	
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
	var app: App? {
		didSet {
			self.updateButton.app = self.app
			self.updateContents()
		}
	}
	
	var filterQuery: String? {
		didSet {
			if filterQuery != oldValue {
				self.updateTitle()
			}
		}
	}
	
	
	// MARK: - Utilities
	
	/// A date formatter for preparing the update date.
	private lazy var dateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.timeStyle = .none
		dateFormatter.dateStyle = .short
		dateFormatter.doesRelativeDateFormatting = true
		
		return dateFormatter
	}()
	
	private func updateContents() {
		guard let app = self.app, let versionInformation = app.localizedVersionInformation else { return }
		
		self.updateTitle()
		
		// Update the contents of the cell
        self.currentVersionTextField.stringValue = versionInformation.current
		self.newVersionTextField.stringValue = versionInformation.new ?? ""
        self.newVersionTextField.isHidden = !app.updateAvailable
		self.dateTextField.stringValue = dateFormatter.string(from: app.updateDate)
	}
	    
	private func updateTitle() {
		self.nameTextField.attributedStringValue = self.app?.highlightedName(for: self.filterQuery) ?? NSAttributedString()
	}
	
	private func updateTextColors() {
		// Tint the name if the app is not supported
		let supported = self.app?.supported ?? false
		
		self.nameTextField.textColor = (self.backgroundStyle == .emphasized ? .alternateSelectedControlTextColor : (supported ? .labelColor : .tertiaryLabelColor))
		self.currentVersionTextField.textColor = (supported ? .secondaryLabelColor : .tertiaryLabelColor)
		self.newVersionTextField.textColor = (supported ? .secondaryLabelColor : .tertiaryLabelColor)
		self.dateTextField.textColor = (supported ? .secondaryLabelColor : .tertiaryLabelColor)
	}
}
