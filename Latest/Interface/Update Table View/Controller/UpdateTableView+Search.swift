//
//  UpdateTableView+Search.swift
//  Latest
//
//  Created by Max Langer on 27.12.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import AppKit

extension UpdateTableViewController {
	
	@IBAction func searchFieldTextDidChange(_ sender: NSSearchField) {
		self.apps.filterQuery = sender.stringValue
		self.tableView.reloadData()
	}
	
}
