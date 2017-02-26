//
//  MLMUpdateCell.swift
//  Latest
//
//  Created by Max Langer on 26.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

class MLMUpdateCell: NSTableCellView {

    @IBOutlet weak var currentVersionTextField: NSTextField?
    @IBOutlet weak var newVersionTextField: NSTextField?
    
    var appUrl: URL?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    // MARK: Actions
    
    @IBAction func openApp(sender: NSButton) {
        
    }
    
}
