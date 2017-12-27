//
//  UpdateCell.swift
//  Latest
//
//  Created by Max Langer on 26.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

class UpdateCell: NSTableCellView {

    @IBOutlet weak var currentVersionTextField: NSTextField?
    @IBOutlet weak var newVersionTextField: NSTextField?
        
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
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
