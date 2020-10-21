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

    /// The array holding the apps that have an update available.
	var dataStore: AppDataStore {
		return UpdateChecker.shared.dataStore
	}
	
	/// Convenience for accessing apps that should be displayed in the table.
	var apps: [AppDataStore.Entry] {
		return self.dataStore.filteredApps
	}
	
	/// Represents the last state of apps used for animating transitions.
	var appSnapshot = [AppDataStore.Entry]()
    
    /// Flag indicating that all apps are displayed or only the ones with updates available
	var showInstalledUpdates: Bool {
        set {
			self.dataStore.showInstalledUpdates = newValue
        }
		
		get {
			return self.dataStore.showInstalledUpdates
		}
    }
	
    /// Whether ignored apps should be visible
	var showIgnoredUpdates: Bool {
        set {
			self.dataStore.showIgnoredUpdates = newValue
        }
		
		get {
			return self.dataStore.showIgnoredUpdates
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
        
    /// The menu displayed on secondary clicks on cells in the list
    @IBOutlet weak var tableViewMenu: NSMenu!
    
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MLMUpdateCellIdentifier"), owner: self) {
            self.tableView.rowHeight = cell.frame.height
        }
                        
        self.tableViewMenu.delegate = self
        self.tableView.menu = self.tableViewMenu
        
		self.dataStore.showInstalledUpdates = self.showInstalledUpdates
        
		self.dataStore.addObserver(self) { newValue in
			self.updateTableView(with: self.appSnapshot, with: newValue)
			self.appSnapshot = newValue
			
			self.updateEmtpyStateVisibility()
			self.updateTitleAndBatch()
		}
		
		if #available(macOS 11, *) {
			self.updatesLabel.isHidden = true
		}
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
		
		// Setup search field
        NSLayoutConstraint(item: self.searchField!, attribute: .top, relatedBy: .equal, toItem: self.view.window?.contentLayoutGuide, attribute: .top, multiplier: 1.0, constant: 1).isActive = true
		self.view.window?.makeFirstResponder(nil)
	}
    
    
    // MARK: - TableView Stuff
    
    /// The table view displaying the list
    @IBOutlet weak var tableView: NSTableView!
    
	
    // MARK: Table View Delegate
	
	private func contentCell(for app: AppBundle) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MLMUpdateCellIdentifier"), owner: self) as? UpdateCell else {
            return nil
        }
        
		cell.app = app
		cell.filterQuery = self.dataStore.filterQuery
		
        IconCache.shared.icon(for: app) { (image) in
            cell.imageView?.image = image
        }
        
        return cell
	}
	
	private func headerCell(of section: AppDataStore.Section) -> NSView? {
		let view = self.tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MLMUpdateCellSectionIdentifier"), owner: self) as? UpdateGroupCellView
		
		view?.section = section
		
		return view
	}
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		switch self.apps[row] {
		case .app(let app):
			return self.contentCell(for: app)
		case .section(let section):
			return self.headerCell(of: section)
		}
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
		if self.dataStore.isSectionHeader(at: row) {
			guard let view = tableView.rowView(atRow: row, makeIfNecessary: false) else {
				return UpdateGroupRowView()
			}
			
			return view
		}
		
		return nil
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
		return self.dataStore.isSectionHeader(at: row) ? 27 : 60
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
        self.selectApp(at: self.tableView.selectedRow)
    }
    
    // MARK: Table View Data Source
    
    func numberOfRows(in tableView: NSTableView) -> Int {
		return self.apps.count
    }
    
    
    // MARK: - Public Methods
    
    /// Triggers the update checking mechanism
    func checkForUpdates() {
		UpdateChecker.shared.run()
		self.view.window?.makeFirstResponder(self)
    }

    /**
    Selects the app at the given index.
     - parameter index: The index of the given app. If nil, the currently selected app is deselected.
     */
    func selectApp(at index: Int?) {
        guard let index = index, index >= 0 else {
            self.tableView.deselectAll(nil)
			
            if #available(OSX 10.12.2, *) {
                self.scrubber?.animator().selectedIndex = -1
            }
			
			// Clear release notes
			if let detailViewController = self.releaseNotesViewController {
				detailViewController.display(content: nil, for: nil)
			}
            
            return
        }
        
        if #available(OSX 10.12.2, *) {
            self.scrubber?.animator().scrollItem(at: index, to: .center)
            self.scrubber?.animator().selectedIndex = index
        }
        
        self.tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        self.tableView.scrollRowToVisible(index)
			
		guard let app = self.dataStore.app(at: index) else {
            return
        }
        
        self.delegate?.shouldExpandDetail()
		self.releaseNotesViewController?.display(content: app.newestVersion.releaseNotes, for: app)
    }
    
    
    // MARK: - Menu Item Stuff
	
	private func rowIndex(forMenuItem menuItem: NSMenuItem?) -> Int {
		return menuItem?.representedObject as? Int ?? self.tableView.selectedRow
	}
    
    /// Open a single app
    @IBAction func updateApp(_ sender: NSMenuItem?) {
		self.updateApp(atIndex: self.rowIndex(forMenuItem: sender))
    }
	
	@IBAction func ignoreApp(_ sender: NSMenuItem?) {
		self.setIgnored(true, forAppAt: self.rowIndex(forMenuItem: sender))
	}
	
	@IBAction func unignoreApp(_ sender: NSMenuItem?) {
		self.setIgnored(false, forAppAt: self.rowIndex(forMenuItem: sender))
	}
    
    /// Show the bundle of an app in Finder
    @IBAction func showAppInFinder(_ sender: NSMenuItem?) {
        self.showAppInFinder(at: self.rowIndex(forMenuItem: sender))
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else {
            return true
        }
        
		let index = self.rowIndex(forMenuItem: menuItem)
		let hasIndex = index != -1
		let app = (hasIndex ? self.dataStore.app(at: index) : nil)
		
		switch action {
		case #selector(updateApp(_:)):
			return hasIndex && !(app?.isUpdating ?? false)
		case #selector(showAppInFinder(_:)):
            return hasIndex
		case #selector(ignoreApp(_:)):
			if let app = app {
				let isIgnored = self.dataStore.isAppIgnored(app)
				menuItem.isHidden = isIgnored
				return true
			}
		case #selector(unignoreApp(_:)):
			if let app = app {
				let isIgnored = self.dataStore.isAppIgnored(app)
				menuItem.isHidden = !isIgnored
				return true
			}
        default:
            ()
        }
		
		return false
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
	
	/// Sets the ignored state for the app at the given index
	private func setIgnored(_ ignored: Bool, forAppAt index: Int) {
		guard let app = self.dataStore.app(at: index) else { return }
		self.dataStore.setIgnored(ignored, for: app)
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
            self.noUpdatesAvailableLabel.isHidden = false
        } else if self.apps.count != 0 && !self.noUpdatesAvailableLabel.isHidden {
            self.tableView.alphaValue = 1
            self.tableView.isHidden = false
            self.noUpdatesAvailableLabel.isHidden = true
        }
    }
    
    /// Updates the title in the toolbar ("No / n updates available") and the badge of the app icon
    private func updateTitleAndBatch() {
        let count = self.dataStore.countOfAvailableUpdates
		let statusText: String
		
        if count == 0 {
            NSApplication.shared.dockTile.badgeLabel = ""
            statusText = NSLocalizedString("Up to Date!", comment: "")
        } else {
            NSApplication.shared.dockTile.badgeLabel = NumberFormatter().string(from: count as NSNumber)
            
            let format = NSLocalizedString("number_of_updates_available", comment: "number of updates available")
            statusText = String.localizedStringWithFormat(format, count)
        }
        
		self.scrubber?.reloadData()
		
		if #available(macOS 11, *) {
			self.view.window?.subtitle = statusText
		} else {
			self.updatesLabel.stringValue = statusText
		}
    }
	
	/// Updates the contents of the table view
	func reloadTableView() {
		// Update snapshot
		self.appSnapshot = self.apps
		self.tableView.reloadData()
	}
	
	/// Animates changes made to the apps list
	private func updateTableView(with oldValue: [AppDataStore.Entry], with newValue: [AppDataStore.Entry]) {
		self.tableView.beginUpdates()
		
		var state = oldValue
		var i = 0, j = 0
		
		// Iterate both states
		while i < state.count || j < newValue.count {
			self.tableView.reloadData(forRowIndexes: IndexSet(integer: i), columnIndexes: IndexSet(integer: 0))
			
			// Skip identical items
			if i < state.count && j < newValue.count && state[i] == newValue[j] {
				i += 1
				j += 1
				continue
			}
			
			// Remove deleted elements
			if i < state.count && !newValue.contains(state[i]) {
				self.tableView.removeRows(at: IndexSet(integer: i), withAnimation: [.slideUp, .effectFade])
				state.remove(at: i)
				continue
			}
			
			// Move existing elements
			if let index = state.firstIndex(of: newValue[i]) {
				let newIndex = i - (index < i ? 1 : 0)
				self.tableView.moveRow(at: index, to: newIndex)
				
				state.remove(at: index)
				state.insert(newValue[j], at: newIndex)
				
				i += 1
				j += 1
				continue
			}
			
			// insert new elements
			self.tableView.insertRows(at: IndexSet(integer: i), withAnimation: [.slideDown, .effectFade])
			state.insert(newValue[j], at: i)
			
			i += 1
			j += 1
		}
		
		self.tableView.endUpdates()
	}
    
}
