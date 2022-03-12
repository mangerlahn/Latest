//
//  TouchBarHandling.swift
//  Latest
//
//  Created by Max Langer on 22.07.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import Cocoa

/// The identifier used for the update item view
fileprivate let UpdateItemViewIdentifier = NSUserInterfaceItemIdentifier(rawValue: "com.max-langer.latest.update-item-identifier")

fileprivate extension NSTouchBarItem.Identifier {
    
    /// The identifier for the update scrubber bar
    static let updatesScrubber = NSTouchBarItem.Identifier(rawValue: "com.max-langer.latest.updates-scrubber")
    
}

/// An extension of the Updates Table View that handles the touchbar related methods
extension UpdateTableViewController: NSTouchBarDelegate {
 
    /// Returns the scrubber bar, if available
    var scrubber: NSScrubber? {
        return self.touchBar?.item(forIdentifier: .updatesScrubber)?.view as? NSScrubber
    }
    
    
    // MARK: Delegate
    
    override func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        
        touchBar.defaultItemIdentifiers = [.updatesScrubber]
        touchBar.customizationAllowedItemIdentifiers = [.updatesScrubber]
        touchBar.principalItemIdentifier = .updatesScrubber
        touchBar.delegate = self
        
        return touchBar
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .updatesScrubber:
            let scrubber = NSScrubber()
            
            scrubber.register(UpdateItemView.self, forItemIdentifier: UpdateItemViewIdentifier)
            scrubber.mode = .free
            scrubber.showsArrowButtons = true
            scrubber.selectionBackgroundStyle = .roundedBackground
            scrubber.selectionOverlayStyle = .outlineOverlay
            scrubber.backgroundColor = NSColor.controlColor
            
            scrubber.dataSource = self
            scrubber.delegate = self
            
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = scrubber
            
            return item
        default:
            ()
        }
        
        return nil
    }
    
}

/// An extension of the Updates Table View that handles the scrubber bar that displays all available updates
extension UpdateTableViewController: NSScrubberDataSource, NSScrubberDelegate, NSScrubberFlowLayoutDelegate {
    
    // MARK: Data Source
    
    func numberOfItems(for scrubber: NSScrubber) -> Int {
        let count = self.apps.count
        
        self.updateScrubberAppearance(with: count)
        
        return count
    }
    
    func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
		switch self.apps[index] {
		case .section(let section):
			return self.view(for: section)
		case .app(let app):
			return self.view(for: app, in: scrubber)
		}
	}
    
    
    // MARK: Delegate
    
    func scrubber(_ scrubber: NSScrubber, layout: NSScrubberFlowLayout, sizeForItemAt itemIndex: Int) -> NSSize {
        if self.snapshot.isSectionHeader(at: itemIndex) {
            return NSSize(width: 100, height: 30)
        }
        
        let size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
		let name = self.snapshot.app(at: itemIndex)!.name as NSString
        let options: NSString.DrawingOptions = [.usesFontLeading, .usesLineFragmentOrigin]
		let attributes = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]
        
        let textRect = name.boundingRect(with: size, options: options, attributes: attributes)
        
        var width = 16 // Spacing
        width += 30 // Image
        width += Int(textRect.size.width)
        
        return NSSize(width: width, height: 30)
    }
    
    func scrubber(_ scrubber: NSScrubber, didSelectItemAt selectedIndex: Int) {
        if self.snapshot.isSectionHeader(at: selectedIndex) {
            self.scrubber?.selectedIndex = self.tableView.selectedRow
            return
        }
        
        self.selectApp(at: selectedIndex)
    }
    
    private func updateScrubberAppearance(with count: Int) {
        self.scrubber?.isHidden = count == 0
        self.scrubber?.showsArrowButtons = count > 3
    }
	
	private func view(for section: AppListSnapshot.Section) -> NSScrubberItemView {
        let view = NSScrubberTextItemView()
		
		view.textField.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize(for: .small))
		view.textField.textColor = NSColor.secondaryLabelColor
		view.textField.stringValue = section.shortTitle
		
        return view
    }
	
	private func view(for app: App, in scrubber: NSScrubber) -> NSScrubberItemView {
		guard let view = scrubber.makeItem(withIdentifier: UpdateItemViewIdentifier, owner: nil) as? UpdateItemView else {
            return NSScrubberItemView()
        }
        
        view.textField.attributedStringValue = app.highlightedName(for: self.snapshot.filterQuery)
        
        IconCache.shared.icon(for: app) { (image) in
            view.imageView.image = image
        }
        
        return view
	}
    
}
