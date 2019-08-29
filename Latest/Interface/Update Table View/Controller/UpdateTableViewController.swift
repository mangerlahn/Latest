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
class UpdateTableViewController: NSViewController, NSMenuItemValidation, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {

    /// The array holding the apps that have an update available
    var dataStore = AppDataStore()
	
	var apps: [AppDataStore.Entry] {
		return self.dataStore.filteredApps
	}
    
    /// Flag indicating that all apps are displayed or only the ones with updates available
    var showInstalledUpdates = false {
        didSet {
            if oldValue != self.showInstalledUpdates {
				self.dataStore.showInstalledUpdates = self.showInstalledUpdates
            }
        }
    }
    
    /// The delegate for handling the visibility of the detail view
    weak var delegate : UpdateListViewControllerDelegate?
    
    /// The detail view controller that shows the release notes
    weak var releaseNotesViewController : ReleaseNotesViewController?
    
    /// The empty state label centered in the list view indicating that no updates are available
    @IBOutlet weak var noUpdatesAvailableLabel: NSTextField!
	
	/// The label indicating how many updates are vailable
    @IBOutlet weak var updatesLabel: NSTextField!
    
    /// The divider separating the toolbar from the list
    @IBOutlet weak var toolbarDivider: NSBox!
    
    /// The menu displayed on secondary clicks on cells in the list
    @IBOutlet weak var tableViewMenu: NSMenu!
    
    /// The checker responsible for update checking
    lazy var updateChecker: UpdateChecker = {
        var checker = UpdateChecker()
        
        // We treat them equal, if an app fails to load its update info, we can still show the installed app
        checker.didFinishCheckingAppCallback = self.updateCheckerDidFinishCheckingApp
        checker.didFailCheckingAppCallback = self.updateCheckerDidFinishCheckingApp
        
        return checker
    }()
    
    
    // MARK: - View Lifecycle
	
	let coalescingSource = DispatchSource.makeUserDataAddSource(queue: .main)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MLMUpdateCellIdentifier"), owner: self) {
            self.tableView.rowHeight = cell.frame.height
        }
                
        self.scrollViewDidScroll(nil)
        
        self.tableViewMenu.delegate = self
        self.tableView.menu = self.tableViewMenu
        
		self.dataStore.showInstalledUpdates = self.showInstalledUpdates
        self.updatesLabel.stringValue = NSLocalizedString("Up to Date!", comment: "")
        
		self.coalescingSource.setEventHandler {
			self.tableView.reloadData()
		}
		
		self.coalescingSource.resume()

		self.dataStore.addObserver(self) {
			self.updateEmtpyStateVisibility()
			self.updateTitleAndBatch()
			
			self.coalescingSource.add(data: 1)
		}
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
		
		// Setup search field
        NSLayoutConstraint(item: self.searchField!, attribute: .top, relatedBy: .equal, toItem: self.view.window?.contentLayoutGuide, attribute: .top, multiplier: 1.0, constant: 1).isActive = true
		self.view.window?.makeFirstResponder(nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(scrollViewDidScroll(_:)), name: NSScrollView.didLiveScrollNotification, object: self.tableView.enclosingScrollView)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - TableView Stuff
    
    /// The table view displaying the list
    @IBOutlet weak var tableView: NSTableView!
    
    @objc func scrollViewDidScroll(_ notification: Notification?) {
        guard let scrollView = self.tableView.enclosingScrollView, !self.showInstalledUpdates else {
            return
        }
        
        let pos = scrollView.contentView.bounds.origin.y
        self.toolbarDivider.alphaValue = min(pos / 15, 1)
    }
    
    // MARK: Table View Delegate
	
	private func contentCell(for app: AppBundle) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MLMUpdateCellIdentifier"), owner: self) as? UpdateCell,
            let versionInformation = app.localizedVersionInformation else {
            return nil
        }
        
        cell.nameTextField?.attributedStringValue = app.highlightedName(for: self.dataStore.filterQuery)
        cell.currentVersionTextField?.stringValue = versionInformation.current
        cell.newVersionTextField?.stringValue = versionInformation.new
        
        cell.newVersionTextField?.isHidden = !app.updateAvailable
		cell.app = app
        
        IconCache.shared.icon(for: app) { (image) in
            cell.imageView?.image = image
        }
        
        return cell
	}
	
	private func headerCell(of type: AppDataStore.Section) -> NSView? {
		switch type {
		case .updateAvailable:
			return self.tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MLMUpdateCellAvailableUpdatesIdentifier"), owner: self)
		case .installed:
			return self.tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MLMUpdateCellInstalledUpdatesIdentifier"), owner: self)
		}
	}
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		switch self.apps[row] {
		case .app(let app):
			return self.contentCell(for: app)
		case .section(let type):
			return self.headerCell(of: type)
		}
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
		return nil
//        return self.dataStore.isSectionHeader(at: row) ? UpdateGroupRowView() : nil
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if self.dataStore.isSectionHeader(at: row) { return 27 }
        
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MLMUpdateCellIdentifier"), owner: self) else {
            return 50
        }
        
        return cell.frame.height
    }
    
    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        return self.dataStore.isSectionHeader(at: row)
    }
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        if edge == .trailing {
            let action = NSTableViewRowAction(style: .regular, title: NSLocalizedString("Update", comment: "Update String"), handler: { (action, row) in
                self.updateApp(atIndex: row)
            })
            
            action.backgroundColor = #colorLiteral(red: 0.2588235438, green: 0.7568627596, blue: 0.9686274529, alpha: 1)
            
            return [action]
        } else if edge == .leading {
            let action = NSTableViewRowAction(style: .regular, title: NSLocalizedString("Show in Finder", comment: "Revea in Finder Row action"), handler: { (action, row) in
                self.showAppInFinder(at: row)
            })
            
            action.backgroundColor = #colorLiteral(red: 0.6975218654, green: 0.6975218654, blue: 0.6975218654, alpha: 1)
            
            return [action]
        }
        
        return []
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return !self.dataStore.isSectionHeader(at: row)
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let index = self.tableView.selectedRow
        
        if index == -1 {
            return
        }
        
        self.selectApp(at: index)
    }
    
    // MARK: Table View Data Source
    
    func numberOfRows(in tableView: NSTableView) -> Int {
		return self.apps.count
    }
    
    
    // MARK: - Update Checker
        
    func updateCheckerDidFinishCheckingApp(for app: AppBundle) {
		self.dataStore.update(app)
//        self.tableView.beginUpdates()
//        self.add(app)
//        self.tableView.endUpdates()
        
//        self.updateTitleAndBatch()
//        self.updateEmtpyStateVisibility()
    }

    
    // MARK: - Public Methods
    
    /// Triggers the update checking mechanism
    func checkForUpdates() {
        self.updateChecker.run()
        self.becomeFirstResponder()
    }

    /**
    Selects the app at the given index.
     - parameter index: The index of the given app. If nil, the currently selected app is deselected.
     */
    func selectApp(at index: Int?) {
        guard let index = index else {
            self.tableView.deselectAll(nil)
            if #available(OSX 10.12.2, *) {
                self.scrubber?.animator().selectedIndex = -1
            }
            
            return
        }
        
        if #available(OSX 10.12.2, *) {
            self.scrubber?.animator().scrollItem(at: index, to: .center)
            self.scrubber?.animator().selectedIndex = index
        }
        
        self.tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        self.tableView.scrollRowToVisible(index)
			
		guard let app = self.dataStore.app(at: index), let detailViewController = self.releaseNotesViewController else {
            return
        }
        
        self.delegate?.shouldExpandDetail()
        detailViewController.display(content: app.newestVersion.releaseNotes, for: app)
    }
    
    
    // MARK: - Menu Item Stuff
    
    /// Open a single app
    @IBAction func updateApp(_ sender: NSMenuItem?) {
        self.updateApp(atIndex: sender?.representedObject as? Int ?? self.tableView.selectedRow)
    }
    
    /// Show the bundle of an app in Finder
    @IBAction func showAppInFinder(_ sender: NSMenuItem?) {
        self.showAppInFinder(at: sender?.representedObject as? Int ?? self.tableView.selectedRow)
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else {
            return true
        }
        
		let index = menuItem.representedObject as? Int ?? self.tableView.selectedRow
		let hasIndex = index != -1
		
		switch action {
		case #selector(updateApp(_:)):
			return hasIndex && !(self.dataStore.app(at: index)?.isUpdating ?? false)
		case #selector(showAppInFinder(_:)):
            return hasIndex
        default:
            return true
        }
    }
    
    // MARK: Delegate
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        let row = self.tableView.clickedRow
        
        guard row != -1, !self.dataStore.isSectionHeader(at: row) else { return }
        menu.items.forEach({ $0.representedObject = row })
    }
    
	
	// MARK: - Search
	
	/// The search field used for filtering apps
	@IBOutlet weak var searchField: NSSearchField!
	
    
    // MARK: - Private Methods

//    /// Adds an item to the list of apps that have an update available. If the app is already in the list, the row in the table gets updated
//    private func add(_ app: AppBundle) {
//        guard !self.apps.contains(where: { $0 == app }) else {
//            self.reload(app)
//            return
//        }
//
//        self.apps.append(app)
//
//        guard let index = self.apps.index(of: app) else { return }
//        self.tableView.insertRows(at: IndexSet(integer: index), withAnimation: .slideDown)
//    }
//
//    private func reload(_ app: AppBundle) {
//        guard let index = self.apps.firstIndex(where: { $0 == app }) else { return }
//
//        let oldApp = self.apps[index]
//        let stateChanged = oldApp.updateAvailable != app.updateAvailable
//
//        if stateChanged && !self.showInstalledUpdates && !app.updateAvailable {
//            self.remove(oldApp)
//            return
//        }
//
//		guard let newIndex = self.apps.update(app) else { return }
//
//        // The update state of that app changed
//        if stateChanged || index != newIndex {
//            if self.showInstalledUpdates {
//
//                let selected = self.tableView.selectedRow == index
//                self.tableView.beginUpdates()
//                self.tableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
//                self.tableView.insertRows(at: IndexSet(integer: newIndex), withAnimation: .slideDown)
//                self.tableView.endUpdates()
//
//                if selected {
//                    self.selectApp(at: newIndex)
//                }
//
//                return
//            }
//
//			self.tableView.insertRows(at: IndexSet(integer: newIndex), withAnimation: .slideDown)
//            return
//        }
//
//		// Just update the app information
//		self.tableView.reloadData(forRowIndexes: IndexSet(integer: newIndex), columnIndexes: IndexSet(integer: 0))
//    }
//
//    /// Removes the item from the list, if it exists
//    private func remove(_ app: AppBundle) {
//        guard let index = self.apps.remove(app) else { return }
//
//        // Close the detail view
//        if self.tableView.selectedRow == index {
//            self.tableView.deselectRow(index)
//            self.delegate?.shouldCollapseDetail()
//        }
//
//        self.tableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
//    }
    
	
	// MARK: - Actions
	
    /// Updates the app and a given index
    private func updateApp(atIndex index: Int) {
        DispatchQueue.main.async {
            if index < 0 || index >= self.apps.count {
                return
            }
            
			self.dataStore.app(at: index)?.update()
        }
    }
    
    /// Reveals the app at a given index in Finder
    private func showAppInFinder(at index: Int) {
        if index < 0 || index >= self.apps.count {
            return
        }
        
        self.dataStore.app(at: index)?.showInFinder()
    }
	
	
	// MARK: - Interface Updating
    
    /// Updates the UI depending on available updates (show empty states or update list)
    private func updateEmtpyStateVisibility() {
        if self.apps.count == 0 && self.noUpdatesAvailableLabel.isHidden {
            self.tableView.alphaValue = 0
            self.tableView.isHidden = true
            self.toolbarDivider.isHidden = true
            self.noUpdatesAvailableLabel.isHidden = false
        } else if self.apps.count != 0 && !self.noUpdatesAvailableLabel.isHidden {
            self.tableView.alphaValue = 1
            self.tableView.isHidden = false
            self.toolbarDivider.isHidden = false
            self.noUpdatesAvailableLabel.isHidden = true
        }
    }
    
    /// Updates the title in the toolbar ("No / n updates available") and the badge of the app icon
    private func updateTitleAndBatch() {
        let count = self.dataStore.countOfAvailableUpdates
        
        if count == 0 {
            NSApplication.shared.dockTile.badgeLabel = ""
            self.updatesLabel.stringValue = NSLocalizedString("Up to Date!", comment: "")
        } else {
            NSApplication.shared.dockTile.badgeLabel = NumberFormatter().string(from: count as NSNumber)
            
            let format = NSLocalizedString("number_of_updates_available", comment: "number of updates available")
            self.updatesLabel.stringValue = String.localizedStringWithFormat(format, count)
        }
        
        if #available(OSX 10.12.2, *) {
            self.scrubber?.reloadData()
        }
    }
    
//    /// Updates the table view to show all apps or only the ones who have an update available
//    private func installedAppsVisibilityChanged() {
//        let indexSet = self.dataStore.indexesOfInstalledApps
//
//        self.tableView.beginUpdates()
//
//        if self.showInstalledUpdates {
//            // Insert installed apps
//            self.apps.showInstalledUpdates = self.showInstalledUpdates
//            self.tableView.insertRows(at: indexSet, withAnimation: .slideDown)
//        } else {
//            // Remove installed apps
//            self.tableView.removeRows(at: indexSet, withAnimation: .slideUp)
//            self.apps.showInstalledUpdates = self.showInstalledUpdates
//        }
//
//        self.tableView.endUpdates()
//    }
    
}
