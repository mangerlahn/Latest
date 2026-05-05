//
//  UpdateTableView+Search.swift
//  Latest
//
//  Created by Max Langer on 27.12.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import AppKit

/// Custom search field subclass that resigns first responder on ESC
class UpdateSearchField: NSSearchField {

	override func cancelOperation(_ sender: Any?) {
		self.window?.makeFirstResponder(nil)
	}
	
}

extension UpdateTableViewController {

	func configureSortOrderPopupButton() {
		guard let sortOrderPopupButton else { return }

		sortOrderPopupButton.removeAllItems()
		sortOrderPopupButton.menu?.autoenablesItems = false

		AppListSettings.SortOptions.allCases.forEach { order in
			let item = order.menuItem(
				target: nil,
				action: nil,
				isSelected: AppListSettings.shared.sortOrder == order
			)
			item.isEnabled = true
			sortOrderPopupButton.menu?.addItem(item)
		}

		updateSortOrderPopupButtonSelection()
	}

	func updateSortOrderPopupButtonSelection() {
		guard let sortOrderPopupButton else { return }

		let selectedSortOrder = AppListSettings.shared.sortOrder
		guard let item = sortOrderPopupButton.itemArray.first(where: {
			($0.representedObject as? AppListSettings.SortOptions) == selectedSortOrder
		}) else {
			return
		}

		sortOrderPopupButton.select(item)
	}

	@IBAction func changeSortOrderFromPopup(_ sender: NSPopUpButton) {
		guard let selectedSortOrder = sender.selectedItem?.representedObject as? AppListSettings.SortOptions else {
			return
		}

		AppListSettings.shared.sortOrder = selectedSortOrder
	}
	
	@IBAction func searchFieldTextDidChange(_ sender: NSSearchField) {
		var searchQuery: String? = sender.stringValue
		if sender.stringValue.isEmpty {
			searchQuery = nil
		}
		self.scheduleSnapshotUpdate(withApps: self.snapshot.apps, filterQuery: searchQuery, animated: false)
		
		// Reload all visible lists
		self.scrubber?.reloadData()
	}
	
}
