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
	static let preferredSettingsContentSize = NSSize(width: 760, height: 420)
	
	@IBOutlet weak var animatingTrailingConstraint: NSLayoutConstraint?
	@IBOutlet weak var animatingBottomConstraint: NSLayoutConstraint?
	
	/// Asks the controller to prepare its contents for animation.
	///
	/// This controller deactivates two constraints which allow the window frame to be animated.
	func prepareForAnimation() {
		animatingTrailingConstraint?.priority = .init(10)
		animatingBottomConstraint?.priority = .init(10)
	}
	
	/// Asks the controller to revert any changes to its contents done for animating.
	///
	/// This controller deactivates two constraints which allow the window frame to be animated.
	func commitAnimation() {
		animatingTrailingConstraint?.priority = .required
		animatingBottomConstraint?.priority = .required
	}
}

/// Tab bar controller handling animation transitions between tab items.
class SettingsTabViewController: NSTabViewController {
	private lazy var tabViewSizes: [NSTabViewItem: NSSize] = [:]
	private var stableContentSize: NSSize {
		self.tabViewSizes.values.reduce(.zero) { partialResult, size in
			NSSize(
				width: max(partialResult.width, size.width),
				height: max(partialResult.height, size.height)
			)
		}
	}
	
	// MARK: - View Lifecycle
	
	override func viewWillAppear() {
		super.viewWillAppear()
		self.view.window?.styleMask.insert(.resizable)
		self.cacheTabViewSizes()
		self.applyStableWindowConstraints()
		prepareForPresentation(of: tabView.selectedTabViewItem)
		
		// Fix icons for old OSes
		if #unavailable(macOS 11.0) {
			tabView.tabViewItems[0].image = NSImage(named: NSImage.preferencesGeneralName)
			if tabView.tabViewItems.count > 1 {
				tabView.tabViewItems[1].image = NSImage(named: NSImage.refreshTemplateName)
			}
			if tabView.tabViewItems.count > 2 {
				tabView.tabViewItems[2].image = NSImage(named: "PreferencesLocation")
			}
		}
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
		self.view.window?.styleMask.insert(.resizable)
		self.cacheTabViewSizes()
		self.applyStableWindowConstraints()
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
	
	private func prepareForPresentation(of tabViewItem: NSTabViewItem?) {
		(tabViewItem?.viewController as? SettingsTabItemViewController)?.prepareForAnimation()

		self.cacheSize(for: tabViewItem)
	}
	
	private func commitPresentation(of tabViewItem: NSTabViewItem?, animated: Bool) {
		if let tabViewItem = tabViewItem {
			view.window?.title = tabViewItem.label
			self.applyStableWindowConstraints()
			resizeWindowToFit(tabViewItem: tabViewItem, animated: animated)
		}
	}
	
	/// Resizes the window so that it fits the content of the tab.
	private func resizeWindowToFit(tabViewItem: NSTabViewItem, animated: Bool) {
		guard tabViewSizes[tabViewItem] != nil, let window = view.window else {
			return
		}
		
		let requiredContentSize = self.stableContentSize
		let currentContentSize = window.contentRect(forFrameRect: window.frame).size
		let targetContentSize = NSSize(
			width: max(currentContentSize.width, requiredContentSize.width),
			height: max(currentContentSize.height, requiredContentSize.height)
		)
		
		let contentRect = NSRect(origin: .zero, size: targetContentSize)
		let newFrameSize = window.frameRect(forContentRect: contentRect).size
		let newOrigin = NSPoint(
				x: window.frame.origin.x,
				y: window.frame.maxY - newFrameSize.height
			)
		let newFrame = NSRect(origin: newOrigin, size: newFrameSize)
		
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
	
	private func cacheTabViewSizes() {
		self.tabViewItems.forEach { tabViewItem in
			self.cacheSize(for: tabViewItem)
		}
	}
	
	private func cacheSize(for tabViewItem: NSTabViewItem?) {
		guard let tabViewItem else {
			return
		}
		
		let preferredSize = tabViewItem.viewController?.preferredContentSize ?? .zero
		if preferredSize.width > 0 && preferredSize.height > 0 {
			tabViewSizes[tabViewItem] = preferredSize
		} else if let size = tabViewItem.view?.fittingSize, size.width > 0 && size.height > 0 {
			tabViewSizes[tabViewItem] = size
		}
	}
	
	private func applyStableWindowConstraints() {
		guard let window = self.view.window, self.stableContentSize != .zero else {
			return
		}
		
		window.contentMinSize = self.stableContentSize
	}
}
