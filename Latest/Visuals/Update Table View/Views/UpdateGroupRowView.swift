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

    override func draw(_ dirtyRect: NSRect) {
        // Draw a small border at the bottom
        let path = NSBezierPath(rect: NSMakeRect(0, self.bounds.height - 1, self.bounds.width, 1))
        
        NSColor.gridColor.setFill()
        
        path.fill()
    }
    
    override func layout() {
        super.layout()
        
        self.subviews.forEach { (view) in
            view.frame = self.bounds
            view.frame.origin.y = -1
        }
    }
    
}
