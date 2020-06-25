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

	/// The image view holding the source icon of the app.
	@IBOutlet weak var sourceIconImageView: NSImageView!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.contentStackView?.addArrangedSubview(self.updateProgressViewController.view)
		self.currentVersionTextField?.topAnchor.constraint(equalTo: self.updateProgressViewController.view.topAnchor).isActive = true
	}
	
    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            if self.backgroundStyle == .dark {
                let color = NSColor.white
                
                self.currentVersionTextField?.textColor = color
                self.newVersionTextField?.textColor = color
            } else {
                let color = NSColor.secondaryLabelColor
                
                self.currentVersionTextField?.textColor = color
                self.newVersionTextField?.textColor = color
            }
        }
    }
		
	
	// MARK: - Update Progress
	
	/// The update progress controller that displays any progress made during app updates.
	private let updateProgressViewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "updateProgressViewControllerIdentifier") as! UpdateProgressViewController

	/// The app represented by this cell
	var app: AppBundle? {
		didSet {
			self.updateProgressViewController.app = self.app
			self.updateContents()
		}
	}
	
	var filterQuery: String? {
		didSet {
			self.updateContents()
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
		self.sourceIconImageView.image = type(of: app).sourceIcon
		self.sourceIconImageView.toolTip = String(format: NSLocalizedString("Source: %@", comment: "The description of the app's source. e.g. 'Source: Mac App Store'"), type(of: app).sourceName)
	}
	    
	private func updateTitle() {
		self.nameTextField.attributedStringValue = self.app?.highlightedName(for: self.filterQuery) ?? NSAttributedString()
	}
	
}
