//
//  ViewController.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

/**
 The delegate for handling the visibility of an detail view
 */
protocol UpdateListViewControllerDelegate : class {
    /// Implementing class should show the detail view
    func shouldExpandDetail()
    
    /// Implementing class should hide the detail view
    func shouldCollapseDetail()
}

/**
 This is the class handling the update process and displaying its results
 */
class UpdateListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, AppBundleDelegate {

    /// The array holding the apps that have an update available
    var apps = [AppBundle]()
    
    /// The delegate for handling the visibility of the detail view
    weak var delegate : UpdateListViewControllerDelegate?
    
    /// The detail view controller that shows the release notes
    weak var releaseNotesViewController : UpdateReleaseNotesViewController?
    
    /// The empty state label centered in the list view indicating that no updates are available
    @IBOutlet weak var noUpdatesAvailableLabel: NSTextField!
    
    /// The label indicating how many updates are vailable
    @IBOutlet weak var updatesLabel: NSTextField!
    
    /// The divider separating the toolbar from the list
    @IBOutlet weak var toolbarDivider: NSBox!
    
    /// The menu displayed on secondary clicks on cells in the list
    @IBOutlet weak var tableViewMenu: NSMenu!
    
    /// The checker responsible for update checking
    var updateChecker = UpdateChecker()
    
    
    // MARK: - View Lifecycle
    
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
        
        self._updateEmtpyStateVisibility()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        guard let scrollView = self.tableView.enclosingScrollView else { return }
        
        let topConstraint = NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: self.view.window?.contentLayoutGuide, attribute: .top, multiplier: 1.0, constant: 1)
        topConstraint.isActive = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(scrollViewDidScroll(_:)), name: NSScrollView.didLiveScrollNotification, object: self.tableView.enclosingScrollView)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - TableView Stuff
    
    /// The table view displaying the list
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
        
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MLMUpdateCellIdentifier"), owner: self) as? UpdateCell,
            let info = app.newestVersion,
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
        
        guard let detailViewController = self.releaseNotesViewController else {
            return
        }
        
        if let url = app.newestVersion?.releaseNotes as? URL {
            self.delegate?.shouldExpandDetail()
            detailViewController.display(url: url)
        } else if let string = app.newestVersion?.releaseNotes as? String {
            self.delegate?.shouldExpandDetail()
            detailViewController.display(html: string)
        }
    }
    
    // MARK: Table View Data Source
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.apps.count
    }
    
    // MARK: - Update Checker Delegate
    
    /// An helper array indicating the apps that need to be removed from the list after the update process
    private var _appsToDelete : [AppBundle]?

    func appDidUpdateVersionInformation(_ app: AppBundle) {
        self.updateChecker.progressDelegate?.didCheckApp()
        
        if let index = self._appsToDelete?.index(where: { $0 == app }) {
            self._appsToDelete?.remove(at: index)
        }
        
        if let versionBundle = app.newestVersion, versionBundle.version > app.version {
            self._add(app)
        } else if let index = self.apps.index(where: { $0 == app }) {
            self.apps.remove(at: index)
            self.tableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
        }
        
        self._updateTitleAndBatch()
        self._updateEmtpyStateVisibility()
    }
    
    func finishedCheckingForUpdates() {
        defer {
            self._appsToDelete = self.apps
        }
        
        guard let apps = self._appsToDelete, apps.count != 0 else { return }
        
        apps.forEach { (app) in
            guard let index = self.apps.index(where: { $0 == app }) else { return }
            
            self.tableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
            self.apps.remove(at: index)
        }
        
        self._updateTitleAndBatch()
        self._updateEmtpyStateVisibility()
    }

    
    // MARK: - Public Methods
    
    /// Triggers the update checking mechanism
    func checkForUpdates() {
        self.updateChecker.run()
    }

    
    // MARK: - Menu Item Stuff
    
    /// Open a single app
    @IBAction func openApp(_ sender: NSMenuItem?) {
        self._openApp(atIndex: sender?.representedObject as? Int ?? self.tableView.selectedRow)
    }
    
    /// Show the bundle of an app in Finder
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
        menu.items.forEach({ $0.representedObject = row })
    }
    
    
    // MARK: - Private Methods

    /// Adds an item to the list of apps that have an update available. If the app is already in the list, the row in the table gets updated
    private func _add(_ app: AppBundle) {
        guard !self.apps.contains(where: { $0 == app }) else {
            guard let index = self.apps.index(of: app) else { return }
            
            self.tableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: 0))
            
            return
        }
        
        self.apps.append(app)
        
        self.apps.sort { (first, second) -> Bool in
            return first.appName < second.appName
        }
        
        guard let index = self.apps.index(of: app) else {
            return
        }
                
        self.tableView.insertRows(at: IndexSet(integer: index), withAnimation: .slideDown)
    }
    
    /// Opens the app and a given index
    private func _openApp(atIndex index: Int) {
        DispatchQueue.main.async {
            if index < 0 || index >= self.apps.count {
                return
            }
            
            let app = self.apps[index]
            var appStoreURL : URL?
            
            if let appStoreApp = app as? MacAppStoreAppBundle {
                appStoreURL = appStoreApp.appStoreURL
            }
            
            guard let url = appStoreURL ?? app.appURL else {
                return
            }
            
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Reveals the app at a given index in Finder
    private func _showAppInFinder(at index: Int) {
        if index < 0 || index >= self.apps.count {
            return
        }
        
        let app = self.apps[index]
        
        guard let url = app.appURL else { return }
        
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    /// Updates the UI depending on available updates (show empty states or update list)
    private func _updateEmtpyStateVisibility() {
        if self.apps.count == 0 && !self.tableView.isHidden {
            self.tableView.alphaValue = 0
            self.tableView.isHidden = true
            self.toolbarDivider.isHidden = true
            self.noUpdatesAvailableLabel.isHidden = false
        } else if self.apps.count != 0 && tableView.isHidden {
            self.tableView.alphaValue = 1
            self.tableView.isHidden = false
            self.toolbarDivider.isHidden = false
            self.noUpdatesAvailableLabel.isHidden = true
        }
    }
    
    /// Updates the title in the toolbar ("No / n updates available") and the badge of the app icon
    private func _updateTitleAndBatch() {
        let count = self.apps.count
        
        if count == 0 {
            NSApplication.shared.dockTile.badgeLabel = ""
            self.updatesLabel.stringValue = NSLocalizedString("Up to Date!", comment: "")
        } else {
            NSApplication.shared.dockTile.badgeLabel = NumberFormatter().string(from: count as NSNumber)
            
            let format = NSLocalizedString("number_of_updates_available", comment: "number of updates available")
            self.updatesLabel.stringValue = String.localizedStringWithFormat(format, count)
        }
    }
    
}

