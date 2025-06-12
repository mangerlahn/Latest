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
	var section: AppListSnapshot.Section? {
		didSet {
			guard let section = self.section else { return }
			
			// Format section title
			let count = Self.numberFormatter.string(from: section.numberOfApps as NSNumber) ?? "0"
			let format = NSLocalizedString("SectionTitle", comment: "The title of a section divider in the app list. The first placeholder is the name of the section. The value in paranthesis describes how many apps are in that section, number of apps is inserted in the second placeholder. Use the HTML underline tag <u> to mark the deemphasized part of the text, which should be the count. Example: 'Installed Apps (42)'")
			let sectionText = String(format: format, section.title, count)
			
			// Convert to text
			guard let htmlData = sectionText.data(using: .utf8),
				  let text = try? NSAttributedString(data: htmlData, options: [
					.documentType: NSAttributedString.DocumentType.html,
					.characterEncoding: String.Encoding.utf8.rawValue
				  ], documentAttributes: nil) else {
				assertionFailure("Localized string could not be loaded.")
				self.titleField.stringValue = section.title
				return
			}
			
			// Find the range of the underlined text
			var range: NSRange = NSMakeRange(0, 0)
			text.enumerateAttribute(.underlineStyle, in: NSMakeRange(0, text.length)) { value, valueRange, stop in
				if value != nil {
					range = valueRange
					stop.pointee = true
				}
			}
			
			// Remove the underline and add special formatting to the count
			let formattedText = NSMutableAttributedString(string: text.string)
			formattedText.setAttributes([.foregroundColor: NSColor.tertiaryLabelColor, .font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))], range: range)
			
			self.titleField.attributedStringValue = formattedText
		}
	}
	
}
