//
//  UpdateGroupRowView.swift
//  Latest
//
//  Created by Max Langer on 15.08.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import Cocoa

/// The row view used by the group rows in the update tableView
class UpdateGroupRowView: NSTableRowView {
    
	// Prevent any row view drawing
	override func draw(_ dirtyRect: NSRect) {}
	
    override func layout() {
        super.layout()
    
		// Make the cell as big as the row view
        self.subviews.forEach { (view) in
            view.frame = self.bounds
		}
    }
    
	// Make sure the display of the row is not altered in any way
	override var isGroupRowStyle: Bool {
		get {
			return false
		}
		set {}
	}
        
}
