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
	
	var app: AppBundle? {
		willSet {
			// Remove observer from existing app
			if let app = self.app {
				app.updateProgress.removeObserver(self)
			}
		}
		
		didSet {
			if let app = self.app {
				app.updateProgress.addObserver(self, handler: { [weak self] in
					
				})
			}
		}
	}
	
	/// The label displaying the current version of the app
	@IBOutlet weak var nameTextField: NSTextField?

    /// The label displaying the current version of the app
    @IBOutlet weak var currentVersionTextField: NSTextField?
    
    /// The label displaying the newest version available for the app
    @IBOutlet weak var newVersionTextField: NSTextField?
	
	deinit {
		self.app?.updateProgress.removeObserver(self)
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
    
}
