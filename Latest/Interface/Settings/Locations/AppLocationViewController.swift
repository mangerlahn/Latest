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
	
	private let tableView = NSTableView()
	private let titleLabel = NSTextField(labelWithString: NSLocalizedString("Folders to scan", comment: "Settings label for app scan locations."))
	private let helperLabel = NSTextField(wrappingLabelWithString: NSLocalizedString("Latest checks these folders for installed apps and available updates.", comment: "Helper text for application scan locations."))
	private let addButton = NSButton(title: NSLocalizedString("Add Folder…", comment: "Button title for adding a location."), target: nil, action: nil)
	
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
			panel.urls.forEach { url in
				self.directoryStore.add(url)
			}
		}
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
