//
//  MLMMainWindowController.swift
//  Latest
//
//  Created by Max Langer on 27.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

class MLMMainWindowController: NSWindowController {
    
    lazy var listViewController : MLMUpdateListViewController = {
        guard let splitViewController = self.contentViewController as? NSSplitViewController,
            let firstItem = splitViewController.splitViewItems[0].viewController as? MLMUpdateListViewController else {
                return MLMUpdateListViewController()
        }
        
        return firstItem
    }()
    
    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        self.window?.titlebarAppearsTransparent = true
        self.window?.titleVisibility = .hidden
    }

    @IBAction func reload(_ sender: NSButton) {
        self.listViewController.checkForUpdates()
    }
    
    @IBAction func openAll(_ sender: NSButton) {
        let apps = self.listViewController.apps
        
        if apps.count > 4 {
            // Display warning
            let alert = NSAlert()
            alert.alertStyle = .warning
            
            alert.messageText = NSLocalizedString("You are going to open \(apps.count) apps.", comment: "Open a lot of apps - informative text")
            alert.informativeText = NSLocalizedString("This may slow down your Mac. Are you sure you want to open all apps at once?", comment: "Open a lot of apps - message text")
            
            alert.addButton(withTitle: NSLocalizedString("Open Apps", comment: "Open all apps button"))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel button"))
            
            alert.beginSheetModal(for: self.window!, completionHandler: { (response) in
                if response == 1000 {
                    // Open apps anyway
                    self.open(apps: apps)
                }
            })
        } else {
            self.open(apps: apps)
        }
    }
    
    private func open(apps: [MLMAppUpdater]) {
        for app in apps {
            guard let url = app.appURL else {
                continue
            }
            
            NSWorkspace.shared().open(url)
        }
        
    }
}