//
//  AppDirectoryViewController.swift
//  Latest
//
//  Created by Max Langer on 29.02.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import AppKit

/// View displaying a list of directories to be checked for apps with updates.
class AppDirectoryViewController: SettingsTabItemViewController, NSTableViewDataSource, NSTableViewDelegate {
	private var presentedObservationFailures = Set<String>()
	private var observationFailureSheetController: DirectoryObservationSheetController?
	
	// MARK: - View Lifecycle
	
	@IBOutlet private weak var tableView: NSTableView!
	@IBOutlet private weak var actionControl: NSSegmentedControl!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		validateButtons()
	}
	
	private let countProvider = AppDirectoryCountProvider()
	
	private lazy var directoryStore: AppDirectoryStore = {
		AppDirectoryStore(updateHandler: { [weak self] in
			self?.tableView.reloadData()
			self?.validateButtons()
		})
	}()
	
	
	// MARK: - Table
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		directoryStore.URLs.count
	}

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("directoryCellView"), owner: self) as? AppDirectoryCellView else { return nil }
		view.countProvider = countProvider
		view.observationFailureHandler = { [weak self] url, error in
			self?.presentObservationFailure(for: url, error: error)
		}
		view.url = directoryStore.URLs[row]
		
		return view
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		validateButtons()
	}
	
	
	// MARK: - Actions
	
	/// Possible actions on the segmented control.
	private enum Action: Int {
		/// Add a new directory to the list.
		case add = 0
		
		/// Remove the selected directory from the list.
		case delete = 1
	}
	
	@IBAction func performAction(_ sender: NSSegmentedControl) {
		switch Action(rawValue: sender.selectedSegment) {
		case .add:
			presentOpenPanel()
		case .delete:
			let selectedIndex = tableView.selectedRow
			guard selectedIndex != -1 else { return }
			let url = directoryStore.URLs[selectedIndex]
			if directoryStore.canRemove(url) {
				directoryStore.remove(url)
			}
		case .none:
			()
		}
	}
	
	private func validateButtons() {
		let selectedIndex = tableView.selectedRow
		let enabled = if selectedIndex == -1 {
			false
		} else {
			directoryStore.canRemove(directoryStore.URLs[selectedIndex])
		}
		
		actionControl.setEnabled(enabled, forSegment: Action.delete.rawValue)
	}
	
	private func presentOpenPanel() {
		let panel = NSOpenPanel()
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		
		panel.beginSheetModal(for: self.view.window!) { response in
			guard response == .OK else { return }
			self.confirmAddition(of: panel.urls, at: 0)
		}
	}

	private func confirmAddition(of urls: [URL], at index: Int) {
		guard index < urls.count else { return }
		let url = urls[index]
		let addDirectory = {
			self.countProvider.invalidate(url)
			self.directoryStore.add(url)
			self.confirmAddition(of: urls, at: index + 1)
		}

		guard isLikelyBroadScanLocation(url) else {
			addDirectory()
			return
		}

		presentBroadScanWarning(for: url) { shouldAdd in
			if shouldAdd {
				addDirectory()
			} else {
				self.confirmAddition(of: urls, at: index + 1)
			}
		}
	}

	private func isLikelyBroadScanLocation(_ url: URL) -> Bool {
		let normalizedURL = url.standardizedFileURL.resolvingSymlinksInPath()
		if normalizedURL.path == "/" || normalizedURL.path == NSHomeDirectory() {
			return true
		}

		guard let volumeURL = try? normalizedURL.resourceValues(forKeys: [.volumeURLKey]).volume else {
			return false
		}

		return volumeURL.standardizedFileURL.resolvingSymlinksInPath() == normalizedURL
	}

	private func presentBroadScanWarning(for url: URL, completion: @escaping (Bool) -> Void) {
		let alert = NSAlert()
		alert.alertStyle = .warning
		alert.messageText = NSLocalizedString("BroadAppDirectoryAlertTitle", comment: "Title shown when the user selects a very broad folder to scan for apps.")
		alert.informativeText = String.localizedStringWithFormat(
			NSLocalizedString("BroadAppDirectoryAlertMessage", comment: "Warning shown when the user selects a very broad folder to scan for apps."),
			url.path
		)
		alert.addButton(withTitle: NSLocalizedString("AddAnywayAction", comment: "Confirmation action for keeping a broad app scan folder."))
		alert.addButton(withTitle: NSLocalizedString("ChooseDifferentFolderAction", comment: "Action for cancelling a broad app scan folder selection."))

		if let window = self.view.window {
			alert.beginSheetModal(for: window) { response in
				completion(response == .alertFirstButtonReturn)
			}
		} else {
			completion(alert.runModal() == .alertFirstButtonReturn)
		}
	}

	private func presentObservationFailure(for url: URL, error: Error) {
		let failureKey = "\(url.path)|\(error.localizedDescription)"
		guard presentedObservationFailures.insert(failureKey).inserted else { return }
		NSApplication.shared.requestUserAttention(.informationalRequest)
		NSApplication.shared.activate(ignoringOtherApps: true)
		if let window = self.view.window {
			let sheetController = DirectoryObservationSheetController(url: url, error: error)
			observationFailureSheetController = sheetController
			window.beginSheet(sheetController.window!) { [weak self] response in
				self?.observationFailureSheetController = nil
				DirectoryObservationAlertPresenter.handle(response: response, for: url, error: error)
			}
		}
	}
}
