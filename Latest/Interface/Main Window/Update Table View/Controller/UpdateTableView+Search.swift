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
