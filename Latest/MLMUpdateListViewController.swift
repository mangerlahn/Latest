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

class MLMUpdateListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, MLMAppUpdateDelegate {

    var apps = [MLMAppUpdate]()
    
    weak var delegate : MLMUpdateListViewControllerDelegate?
    
    weak var detailViewController : MLMUpdateDetailsViewController?
    
    @IBOutlet weak var noUpdatesAvailableLabel: NSTextField!
    @IBOutlet weak var updatesLabel: NSTextField!
    @IBOutlet weak var rightMarginConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var toolbarDivider: NSBox!
    
    var updateChecker = MLMUpdateChecker()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        if let cell = tableView.make(withIdentifier: "MLMUpdateCellIdentifier", owner: self) {
            self.tableView.rowHeight = cell.frame.height
        }
        
        self.updateChecker.appUpdateDelegate = self
        
        self.scrollViewDidScroll(nil)
        
        self.updatesLabel.stringValue = NSLocalizedString("Up to Date!", comment: "")
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        guard let scrollView = self.tableView.enclosingScrollView else { return }
        
        let topConstraint = NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: self.view.window?.contentLayoutGuide, attribute: .top, multiplier: 1.0, constant: 3)
        topConstraint.isActive = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.scrollViewDidScroll(_:)), name: Notification.Name.NSScrollViewDidLiveScroll, object: self.tableView.enclosingScrollView)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - TableView Stuff
    
    @IBOutlet weak var tableView: NSTableView!
    
    func scrollViewDidScroll(_ notification: Notification?) {
        guard let scrollView = self.tableView.enclosingScrollView else {
            return
        }
        
        let pos = scrollView.contentView.bounds.origin.y
        self.toolbarDivider.alphaValue = min(pos / 15, 1)
    }
    
    // MARK: Table View Delegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let app = self.apps[row]
        
        guard let cell = tableView.make(withIdentifier: "MLMUpdateCellIdentifier", owner: self) as? MLMUpdateCell,
            let versionBundle = app.currentVersion,
            let url = app.appURL else {
            return nil
        }
        
        var version = ""
        var newVersion = ""
        
        if let v = app.shortVersion, let nv = versionBundle.shortVersion {
            version = v
            newVersion = nv
            
            // If the shortVersion string is identical, but the bundle version is different
            // Show the Bundle version in brackets like: "1.3 (21)"
            if version == newVersion, let v = app.version, let nv = versionBundle.version {
                version += " (\(v))"
                newVersion += " (\(nv))"
            }
        } else if let v = app.version, let nv = versionBundle.version {
            version = v
            newVersion = nv
        }
        
        cell.textField?.stringValue = app.appName
        cell.currentVersionTextField?.stringValue = String(format:  NSLocalizedString("Your version: %@", comment: "Current Version String"), "\(version)")
        cell.newVersionTextField?.stringValue = String(format: NSLocalizedString("New version: %@", comment: "New Version String"), "\(newVersion)")
        cell.imageView?.image = NSWorkspace.shared().icon(forFile: url.path)
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let cell = tableView.make(withIdentifier: "MLMUpdateCellIdentifier", owner: self) else {
            return 50
        }
        
        return cell.frame.height
    }
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableRowActionEdge) -> [NSTableViewRowAction] {
        if edge == .trailing {
            let action = NSTableViewRowAction(style: .regular, title: NSLocalizedString("Update", comment: "Update String"), handler: { (action, row) in
                self._openApp(atIndex: row)
            })
            
            action.backgroundColor = NSColor.gray
            
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
        
        if let versionBundle = app.currentVersion, let currentVersion = app.version, let newVersion = versionBundle.version, currentVersion != newVersion {
            self.apps.append(app)
            self.tableView.reloadData()
            
            NSApplication.shared().dockTile.badgeLabel = NumberFormatter().string(from: self.apps.count as NSNumber)
            
            let format = NSLocalizedString("number_of_updates_available", comment: "number of updates available")
            self.updatesLabel.stringValue = String.localizedStringWithFormat(format, self.apps.count)
        }
        
        if self.apps.count == 0 {
            NSApplication.shared().dockTile.badgeLabel = ""
            self.updatesLabel.stringValue = NSLocalizedString("Up to Date!", comment: "")
        }
    }
    
    // MARK: - Public Methods
    
    func checkForUpdates() {
        self.apps = []
        self.updateChecker.run()
    }
    
    // MARK: - Menu Item Stuff
    
    @IBAction func openApp(_ sender: Any?) {
        self._openApp(atIndex: self.tableView.selectedRow)
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(openApp(_:)) {
            return self.tableView.selectedRow != -1
        }
        
        return super.validateMenuItem(menuItem)
    }
    
    // MARK: - Private Methods

    private func _openApp(atIndex index: Int) {
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
        
        NSWorkspace.shared().open(url)
    }

}

