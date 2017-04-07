//
//  MLMMainWindowController.swift
//  Latest
//
//  Created by Max Langer on 27.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

class MLMMainWindowController: NSWindowController, MLMUpdateListViewControllerDelegate, MLMUpdateCheckerProgressDelegate {
    
    lazy var listViewController : MLMUpdateListViewController = {
        guard let splitViewController = self.contentViewController as? NSSplitViewController,
            let firstItem = splitViewController.splitViewItems[0].viewController as? MLMUpdateListViewController else {
                return MLMUpdateListViewController()
        }
        
        return firstItem
    }()
    
    lazy var detailViewController : MLMUpdateDetailsViewController = {
        guard let splitViewController = self.contentViewController as? NSSplitViewController,
            let secondItem = splitViewController.splitViewItems[1].viewController as? MLMUpdateDetailsViewController else {
                return MLMUpdateDetailsViewController()
        }
        
        return secondItem
    }()
    
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var reloadButton: NSButton!
    
    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        self.window?.titlebarAppearsTransparent = true
        self.window?.titleVisibility = .hidden
        
        if let splitViewController = self.contentViewController as? NSSplitViewController {
            splitViewController.splitViewItems[1].isCollapsed = true
        }
        
        self.listViewController.updateChecker.progressDelegate = self
        self.listViewController.delegate = self
        self.listViewController.checkForUpdates()
        self.listViewController.detailViewController = self.detailViewController
    }

    // MARK: - Action Methods
    
    @IBAction func reload(_ sender: Any?) {
        self.listViewController.checkForUpdates()
    }
    
    @IBAction func openAll(_ sender: Any?) {
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
    
    @IBAction func toggleDetail(_ sender: Any?) {
        guard let splitViewController = self.contentViewController as? NSSplitViewController else {
            return
        }
        
        let detailItem = splitViewController.splitViewItems[1]
        
        detailItem.animator().isCollapsed = !detailItem.isCollapsed
    }
    
    // MARK: Menu Item Validation

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else {
            return super.validateMenuItem(menuItem)
        }
        
        switch action {
        case #selector(openAll(_:)):
            return self.listViewController.apps.count != 0
        case #selector(reload(_:)):
            return self.reloadButton.isEnabled
        case #selector(toggleDetail(_:)):
            guard let splitViewController = self.contentViewController as? NSSplitViewController else {
                return false
            }
            
            let detailItem = splitViewController.splitViewItems[1]
            
            menuItem.title = detailItem.isCollapsed ?
                NSLocalizedString("Show Version Details", comment: "MenuItem Show Version Details") :
                NSLocalizedString("Hide Version Details", comment: "MenuItem Hide Version Details")
            
            return self.listViewController.tableView.selectedRow != -1
        default:
            return super.validateMenuItem(menuItem)
        }
    }
    
    // MARK: - MLMUpdateListViewController Delegate
    
    // MARK: Checking
    
    func startChecking(numberOfApps: Int) {
        self.reloadButton.isEnabled = false
    
        self.progressIndicator.doubleValue = 0
        self.progressIndicator.maxValue = Double(numberOfApps)
    }
    
    func didCheckApp() {
        self.progressIndicator.increment(by: 1)
        
        if self.progressIndicator.doubleValue == self.progressIndicator.maxValue - 2 {
            self.reloadButton.isEnabled = true
        }
    }
    
    // MARK: Visuals
    
    func shouldExpandDetail() {
        guard let splitViewController = self.contentViewController as? NSSplitViewController else {
            return
        }
        
        let detailItem = splitViewController.splitViewItems[1]
        
        detailItem.animator().isCollapsed = false
    }
    
    func shouldCollapseDetail() {
        guard let splitViewController = self.contentViewController as? NSSplitViewController else {
            return
        }
        
        let detailItem = splitViewController.splitViewItems[1]
        
        detailItem.animator().isCollapsed = true
    }
    
    // MARK: - Private Methods
    
    private func open(apps: [MLMAppUpdate]) {
        for app in apps {
            guard let url = app.appURL else {
                continue
            }
            
            NSWorkspace.shared().open(url)
        }
        
    }
}
