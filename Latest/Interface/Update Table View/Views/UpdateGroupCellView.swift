//
//  UpdateGroupCellView.swift
//  Latest
//
//  Created by Max Langer on 03.05.20.
//  Copyright © 2020 Max Langer. All rights reserved.
//

import Cocoa

/// The section header row of the update list.
class UpdateGroupCellView: NSTableCellView {

	/// The label holding the sections title.
	@IBOutlet private weak var titleField: NSTextField!
	
	/// The number formatter formatting the app counter
	private static let numberFormatter = NumberFormatter()

	/// The section to be presented by this view.
	var section: AppDataStore.Section? {
		didSet {
			guard let section = self.section else { return }
			
			// Format app counter
			let count = Self.numberFormatter.string(from: section.numberOfApps as NSNumber) ?? "0"
			let countString = String(format: NSLocalizedString("(%@)", comment: "Describes how many apps are in a section, number of apps is inserted in placeholder."), count)
			
			// Build text
			let text = NSMutableAttributedString(string: section.title + " ")
			text.append(NSAttributedString(string: countString, attributes: [.foregroundColor: NSColor.tertiaryLabelColor, .font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))]))
			
			self.titleField.attributedStringValue = text
		}
	}
	
}
