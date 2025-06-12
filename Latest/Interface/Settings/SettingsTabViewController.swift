//
//  SettingsTabViewController.swift
//  Latest
//
//  Created by Max Langer on 27.12.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import AppKit

/// Base view controller for settings views.
class SettingsTabItemViewController: NSViewController {
	
	@IBOutlet weak var animatingTrailingConstraint: NSLayoutConstraint!
	@IBOutlet weak var animatingBottomConstraint: NSLayoutConstraint!
	
	/// Asks the controller to prepare its contents for animation.
	///
	/// This controller deactivates two constraints which allow the window frame to be animated.
	func prepareForAnimation() {
		animatingTrailingConstraint.priority = .init(10)
		animatingBottomConstraint.priority = .init(10)
	}
	
	/// Asks the controller to revert any changes to its contents done for animating.
	///
	/// This controller deactivates two constraints which allow the window frame to be animated.
	func commitAnimation() {
		animatingTrailingConstraint.priority = .required
		animatingBottomConstraint.priority = .required
	}
}

/// Tab bar controller handling animation transitions between tab items.
class SettingsTabViewController: NSTabViewController {
	
	// MARK: - View Lifecycle
	
	override func viewWillAppear() {
		super.viewWillAppear()
		prepareForPresentation(of: tabView.selectedTabViewItem)
		
		// Fix icons for old OSes
		if #unavailable(macOS 11.0) {
			tabView.tabViewItems[0].image = NSImage(named: NSImage.preferencesGeneralName)
			tabView.tabViewItems[1].image = NSImage(named: "PreferencesLocation")
		}
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
		commitPresentation(of: tabView.selectedTabViewItem, animated: false)
	}

	// MARK: - Tab View
	
    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, willSelect: tabViewItem)
		prepareForPresentation(of: tabViewItem)
    }

	override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
		super.tabView(tabView, didSelect: tabViewItem)
		commitPresentation(of: tabViewItem, animated: true)
	}
	
	// MARK: - Animation
	
	private lazy var tabViewSizes: [NSTabViewItem: NSSize] = [:]
	
	private func prepareForPresentation(of tabViewItem: NSTabViewItem?) {
		(tabViewItem?.viewController as? SettingsTabItemViewController)?.prepareForAnimation()

		// Cache the size of the tab item
		if let tabViewItem = tabViewItem, let size = tabViewItem.view?.frame.size {
			tabViewSizes[tabViewItem] = size
		}
	}
	
	private func commitPresentation(of tabViewItem: NSTabViewItem?, animated: Bool) {
		if let tabViewItem = tabViewItem {
			view.window?.title = tabViewItem.label
			resizeWindowToFit(tabViewItem: tabViewItem, animated: animated)
		}
	}
	
    /// Resizes the window so that it fits the content of the tab.
	private func resizeWindowToFit(tabViewItem: NSTabViewItem, animated: Bool) {
        guard let size = tabViewSizes[tabViewItem], let window = view.window else {
            return
        }

        let contentRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let contentFrame = window.frameRect(forContentRect: contentRect)
        let toolbarHeight = window.frame.size.height - contentFrame.size.height
        let newOrigin = NSPoint(x: window.frame.origin.x, y: window.frame.origin.y + toolbarHeight)
        let newFrame = NSRect(origin: newOrigin, size: contentFrame.size)
		
		window.setFrame(newFrame, display: false, animate: animated)

		if animated {
			NSAnimationContext.runAnimationGroup { context in
				context.duration = window.animationResizeTime(newFrame)
			} completionHandler: {
				(tabViewItem.viewController as? SettingsTabItemViewController)?.commitAnimation()
			}
		} else {
			(tabViewItem.viewController as? SettingsTabItemViewController)?.commitAnimation()
		}
    }
}
