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
	
	private let tableView = NSTableView()
	private let titleLabel = NSTextField(labelWithString: NSLocalizedString("Folders to scan", comment: "Settings label for app scan locations."))
	private let helperLabel = NSTextField(wrappingLabelWithString: NSLocalizedString("Latest checks these folders for installed apps and available updates.", comment: "Helper text for application scan locations."))
	private let addButton = NSButton(title: NSLocalizedString("Add Folder…", comment: "Button title for adding a location."), target: nil, action: nil)
	private let countProvider = AppDirectoryCountProvider()
	
	override func loadView() {
		self.view = NSView(frame: NSRect(origin: .zero, size: SettingsTabItemViewController.preferredSettingsContentSize))
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.preferredContentSize = SettingsTabItemViewController.preferredSettingsContentSize
		self.view.setFrameSize(self.preferredContentSize)
		self.buildInterface()
	}
	
	private lazy var directoryStore: AppDirectoryStore = {
		AppDirectoryStore(updateHandler: { [weak self] in
			self?.tableView.reloadData()
		})
	}()
	
	
	// MARK: - Table
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		directoryStore.URLs.count
	}

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let identifier = NSUserInterfaceItemIdentifier("directoryCellView")
		let view = (tableView.makeView(withIdentifier: identifier, owner: self) as? AppDirectoryCellView) ?? AppDirectoryCellView(frame: .zero)
		let url = directoryStore.URLs[row]
		view.identifier = identifier
		view.countProvider = countProvider
		view.observationFailureHandler = { [weak self] failedURL, error in
			self?.presentObservationFailure(for: failedURL, error: error)
		}
		view.isDefaultLocation = directoryStore.isDefault(url)
		view.canRemove = directoryStore.canRemove(url)
		view.onRemove = { [weak self] url in
			self?.removeDirectory(url)
		}
		view.url = url
		
		return view
	}

	func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
		false
	}

	// MARK: - Actions

	@IBAction private func addDirectory(_ sender: Any?) {
		presentOpenPanel()
	}

	private func removeDirectory(_ url: URL) {
		guard directoryStore.canRemove(url) else {
			return
		}
		
		directoryStore.remove(url)
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
		guard let window = self.view.window else { return }

		let alert = NSAlert()
		alert.alertStyle = .warning
		alert.messageText = NSLocalizedString("DirectoryObservationFailedAlertTitle", comment: "Title of alert shown when Latest cannot monitor a configured app scan directory.")
		alert.informativeText = self.directoryObservationFailureMessage(for: url, error: error)
		alert.addButton(withTitle: NSLocalizedString("OKAction", comment: "Default button for dismissing an informational alert."))
		alert.beginSheetModal(for: window)
	}

	private func directoryObservationFailureMessage(for url: URL, error: Error) -> String {
		let format = NSLocalizedString("DirectoryObservationFailedAlertMessage", comment: "Alert text shown when Latest cannot monitor a configured app scan directory. The first placeholder is the directory path, the second is the localized system error.")
		var message = String.localizedStringWithFormat(format, url.path, error.localizedDescription)

		let nsError = error as NSError
		if nsError.domain == NSPOSIXErrorDomain,
		   let code = POSIXErrorCode(rawValue: Int32(nsError.code)),
		   code == .EACCES || code == .EPERM {
			let recovery = NSLocalizedString("DirectoryObservationFailedPermissionSuggestion", comment: "Additional suggestion shown when the app likely lacks permission to observe a scan directory.")
			message += "\n\n\(recovery)"
		}

		return message
	}
	
	private func buildInterface() {
		let contentStack = NSStackView()
		contentStack.orientation = .vertical
		contentStack.alignment = .width
		contentStack.spacing = 16
		contentStack.translatesAutoresizingMaskIntoConstraints = false
		
		let headerStack = NSStackView()
		headerStack.orientation = .vertical
		headerStack.alignment = .leading
		headerStack.spacing = 4
		headerStack.translatesAutoresizingMaskIntoConstraints = false
		
		let scrollView = NSScrollView()
		scrollView.borderType = .noBorder
		scrollView.drawsBackground = false
		scrollView.hasVerticalScroller = true
		scrollView.autohidesScrollers = true
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		
		let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AutomaticTableColumnIdentifier.0"))
		tableColumn.resizingMask = .autoresizingMask
		
		tableView.addTableColumn(tableColumn)
		tableView.headerView = nil
		tableView.rowHeight = 64
		tableView.intercellSpacing = NSSize(width: 0, height: 8)
		tableView.selectionHighlightStyle = .none
		tableView.usesAlternatingRowBackgroundColors = false
		tableView.backgroundColor = .clear
		tableView.focusRingType = .none
		tableView.delegate = self
		tableView.dataSource = self
		tableView.translatesAutoresizingMaskIntoConstraints = false
		
		scrollView.documentView = tableView
		
		titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
		titleLabel.alignment = .left
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		
		helperLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
		helperLabel.textColor = .secondaryLabelColor
		helperLabel.alignment = .left
		helperLabel.translatesAutoresizingMaskIntoConstraints = false
		
		addButton.target = self
		addButton.action = #selector(addDirectory(_:))
		addButton.bezelStyle = .rounded
		addButton.translatesAutoresizingMaskIntoConstraints = false
		addButton.setContentHuggingPriority(.required, for: .horizontal)
		if #available(macOS 11.0, *) {
			addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: addButton.title)
		}
		
		let actionRow = NSStackView(views: [addButton, NSView()])
		actionRow.orientation = .horizontal
		actionRow.alignment = .centerY
		actionRow.translatesAutoresizingMaskIntoConstraints = false
		
		headerStack.addArrangedSubview(titleLabel)
		headerStack.addArrangedSubview(helperLabel)
		
		contentStack.addArrangedSubview(headerStack)
		contentStack.addArrangedSubview(scrollView)
		contentStack.addArrangedSubview(actionRow)
		
		self.view.addSubview(contentStack)
		
		NSLayoutConstraint.activate([
			contentStack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 24),
			contentStack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -24),
			contentStack.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 24),
			contentStack.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor, constant: -24),
			headerStack.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
			headerStack.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
			actionRow.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
			actionRow.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
			scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
		])
	}
}
