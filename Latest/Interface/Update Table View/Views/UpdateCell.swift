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
	@IBOutlet weak var nameTextField: NSTextField?

    /// The label displaying the current version of the app
    @IBOutlet weak var currentVersionTextField: NSTextField?
    
    /// The label displaying the newest version available for the app
    @IBOutlet weak var newVersionTextField: NSTextField?
	
	/// The stack view holding the cells contents.
	@IBOutlet private weak var contentStackView: NSStackView?

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
		}
	}
	    
}
