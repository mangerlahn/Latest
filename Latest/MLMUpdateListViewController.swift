//
//  ViewController.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

protocol MLMUpdateListViewControllerDelegate : class {    
    func shouldExpandDetail()
    func shouldCollapseDetail()
}

class MLMUpdateListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, MLMAppUpdateDelegate {

    var apps = [MLMAppUpdate]()
    
    weak var delegate : MLMUpdateListViewControllerDelegate?
    
    weak var detailViewController : MLMUpdateDetailsViewController?
    
    @IBOutlet weak var noUpdatesAvailableLabel: NSTextField!
    @IBOutlet weak var updatesLabel: NSTextField!
    @IBOutlet weak var rightMarginConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var toolbarDivider: NSBox!
    
    @IBOutlet weak var tableViewMenu: NSMenu!
    
    var updateChecker = MLMUpdateChecker()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MLMUpdateCellIdentifier"), owner: self) {
            self.tableView.rowHeight = cell.frame.height
        }
        
        self.updateChecker.appUpdateDelegate = self
        
        self.scrollViewDidScroll(nil)
        
        self.tableViewMenu.delegate = self
        self.tableView.menu = self.tableViewMenu
        
        self.updatesLabel.stringValue = NSLocalizedString("Up to Date!", comment: "")
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        guard let scrollView = self.tableView.enclosingScrollView else { return }
        
        let topConstraint = NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: self.view.window?.contentLayoutGuide, attribute: .top, multiplier: 1.0, constant: 3)
        topConstraint.isActive = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.scrollViewDidScroll(_:)), name: NSScrollView.didLiveScrollNotification, object: self.tableView.enclosingScrollView)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - TableView Stuff
    
    @IBOutlet weak var tableView: NSTableView!
    
    @objc func scrollViewDidScroll(_ notification: Notification?) {
        guard let scrollView = self.tableView.enclosingScrollView else {
            return
        }
        
        let pos = scrollView.contentView.bounds.origin.y
        self.toolbarDivider.alphaValue = min(pos / 15, 1)
    }
    
    // MARK: Table View Delegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let app = self.apps[row]
        
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MLMUpdateCellIdentifier"), owner: self) as? MLMUpdateCell,
            let info = app.currentVersion,
            let url = app.appURL else {
            return nil
        }
        
        var version = ""
        var newVersion = ""
        
        if let v = app.version.versionNumber, let nv = info.version.versionNumber {
            version = v
            newVersion = nv
            
            // If the shortVersion string is identical, but the bundle version is different
            // Show the Bundle version in brackets like: "1.3 (21)"
            if version == newVersion, let v = app.version?.buildNumber, let nv = info.version.buildNumber {
                version += " (\(v))"
                newVersion += " (\(nv))"
            }
        } else if let v = app.version.buildNumber, let nv = info.version.buildNumber {
            version = v
            newVersion = nv
        }
        
        cell.textField?.stringValue = app.appName
        cell.currentVersionTextField?.stringValue = String(format:  NSLocalizedString("Your version: %@", comment: "Current Version String"), "\(version)")
        cell.newVersionTextField?.stringValue = String(format: NSLocalizedString("New version: %@", comment: "New Version String"), "\(newVersion)")
        
        DispatchQueue.main.async {
            cell.imageView?.image = NSWorkspace.shared.icon(forFile: url.path)
        }
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MLMUpdateCellIdentifier"), owner: self) else {
            return 50
        }
        
        return cell.frame.height
    }
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        if edge == .trailing {
            let action = NSTableViewRowAction(style: .regular, title: NSLocalizedString("Update", comment: "Update String"), handler: { (action, row) in
                self._openApp(atIndex: row)
            })
            
            action.backgroundColor = #colorLiteral(red: 0.2588235438, green: 0.7568627596, blue: 0.9686274529, alpha: 1)
            
            return [action]
        } else if edge == .leading {
            let action = NSTableViewRowAction(style: .regular, title: NSLocalizedString("Show in Finder", comment: "Revea in Finder Row action"), handler: { (action, row) in
                self._showAppInFinder(at: row)
            })
            
            action.backgroundColor = #colorLiteral(red: 0.6975218654, green: 0.6975218654, blue: 0.6975218654, alpha: 1)
            
            return [action]
        }
        
        return []
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let index = self.tableView.selectedRow
        
        if index == -1 {
            return
        }
        
        let app = self.apps[index]
        
        guard let detailViewController = self.detailViewController else {
            return
        }
        
        if let url = app.currentVersion?.releaseNotes as? URL {
            self.delegate?.shouldExpandDetail()
            detailViewController.display(url: url)
        } else if let string = app.currentVersion?.releaseNotes as? String {
            self.delegate?.shouldExpandDetail()
            detailViewController.display(html: string)
        }
    }
    
    // MARK: Table View Data Source
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        let count = self.apps.count
        
        if count == 0 {
            self.tableView.alphaValue = 0
            self.tableView.isHidden = true
            self.toolbarDivider.isHidden = true
            self.noUpdatesAvailableLabel.isHidden = false
        } else {
            self.tableView.alphaValue = 1
            self.tableView.isHidden = false
            self.toolbarDivider.isHidden = false
            self.noUpdatesAvailableLabel.isHidden = true
        }
        
        return count
    }
    
    // MARK: - Update Checker Delegate
    
    func checkerDidFinishChecking(_ app: MLMAppUpdate) {
        self.updateChecker.progressDelegate?.didCheckApp()
        
        if let versionBundle = app.currentVersion, versionBundle.version != app.version {
            self.apps.append(app)
            self.tableView.reloadData()
            
            NSApplication.shared.dockTile.badgeLabel = NumberFormatter().string(from: self.apps.count as NSNumber)
            
            let format = NSLocalizedString("number_of_updates_available", comment: "number of updates available")
            self.updatesLabel.stringValue = String.localizedStringWithFormat(format, self.apps.count)
        }
        
        if self.apps.count == 0 {
            NSApplication.shared.dockTile.badgeLabel = ""
            self.updatesLabel.stringValue = NSLocalizedString("Up to Date!", comment: "")
        }
    }
    
    // MARK: - Public Methods
    
    func checkForUpdates() {
        self.apps = []
        self.updateChecker.run()
    }
    
    // MARK: - Menu Item Stuff
    
    @IBAction func openApp(_ sender: NSMenuItem?) {
        self._openApp(atIndex: sender?.representedObject as? Int ?? self.tableView.selectedRow)
    }
    
    @IBAction func showAppInFinder(_ sender: NSMenuItem?) {
        self._showAppInFinder(at: sender?.representedObject as? Int ?? self.tableView.selectedRow)
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else {
            return super.validateMenuItem(menuItem)
        }
        
        switch action {
        case #selector(openApp(_:)),
             #selector(showAppInFinder(_:)):
            return menuItem.representedObject as? Int ?? self.tableView.selectedRow != -1
        default:
            return super.validateMenuItem(menuItem)
        }
    }
    
    // MARK: Delegate
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        let row = self.tableView.clickedRow
        
        guard row != -1 else { return }
        for item in menu.items {
            item.representedObject = row
        }
    }
    
    // MARK: - Private Methods

    private func _openApp(atIndex index: Int) {
        DispatchQueue.main.async {
            if index < 0 || index >= self.apps.count {
                return
            }
            
            let app = self.apps[index]
            var appStoreURL : URL?
            
            if let appStoreApp = app as? MLMMacAppStoreAppUpdate {
                appStoreURL = appStoreApp.appStoreURL
            }
            
            guard let url = appStoreURL ?? app.appURL else {
                return
            }
            
            NSWorkspace.shared.open(url)
        }
    }

    private func _showAppInFinder(at index: Int) {
        if index < 0 || index >= self.apps.count {
            return
        }
        
        let app = self.apps[index]
        
        guard let url = app.appURL else { return }
        
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
}

