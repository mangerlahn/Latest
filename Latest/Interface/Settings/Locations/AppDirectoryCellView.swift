//
//  AppDirectoryCellView.swift
//  Latest
//
//  Created by Max Langer on 29.02.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import Cocoa

/// Shared provider for counting tracked apps in a directory without rescanning the same URL on every table reload.
final class AppDirectoryCountProvider {
	
	typealias CountFailureHandler = (URL, Error) -> Void
	typealias BundleCounter = (URL, CountFailureHandler?) -> Int
	typealias CountHandler = (Int) -> Void
	
	private let collectionQueue: DispatchQueue
	private let stateQueue = DispatchQueue(label: "AppDirectoryCountProvider.state")
	private let bundleCounter: BundleCounter
	private var cachedCounts = [URL: Int]()
	private var pendingHandlers = [URL: [CountHandler]]()
	private var pendingFailureHandlers = [URL: [CountFailureHandler]]()
	
	init(
		collectionQueue: DispatchQueue = DispatchQueue(label: "AppDirectoryCountProvider.collection", qos: .utility),
		bundleCounter: @escaping BundleCounter = { url, failureHandler in
			BundleCollector.collectBundles(at: url, errorHandler: failureHandler).count
		}
	) {
		self.collectionQueue = collectionQueue
		self.bundleCounter = bundleCounter
	}
	
	func count(for url: URL, completion: @escaping CountHandler, onFailure: CountFailureHandler? = nil) {
		if let cachedCount = stateQueue.sync(execute: { cachedCounts[url] }) {
			completion(cachedCount)
			return
		}
		
		let shouldStartCollection = stateQueue.sync { () -> Bool in
			if pendingHandlers[url] != nil {
				pendingHandlers[url]?.append(completion)
				if let onFailure {
					pendingFailureHandlers[url, default: []].append(onFailure)
				}
				return false
			}
			
			pendingHandlers[url] = [completion]
			if let onFailure {
				pendingFailureHandlers[url] = [onFailure]
			}
			return true
		}
		
		guard shouldStartCollection else { return }
		
		collectionQueue.async { [bundleCounter] in
			let count = bundleCounter(url) { failedURL, error in
				let failureHandlers = self.stateQueue.sync { () -> [CountFailureHandler] in
					self.pendingFailureHandlers[url] ?? []
				}
				
				DispatchQueue.main.async {
					failureHandlers.forEach { $0(failedURL, error) }
				}
			}
			let handlers = self.stateQueue.sync { () -> [CountHandler] in
				self.cachedCounts[url] = count
				let handlers = self.pendingHandlers[url] ?? []
				self.pendingHandlers[url] = nil
				self.pendingFailureHandlers[url] = nil
				return handlers
			}
			
			DispatchQueue.main.async {
				handlers.forEach { $0(count) }
			}
		}
	}
	
	func invalidate(_ url: URL) {
		stateQueue.sync {
			cachedCounts.removeValue(forKey: url)
			pendingFailureHandlers.removeValue(forKey: url)
		}
	}
}

/// View that holds a single location checked for updates.
class AppDirectoryCellView: NSTableCellView {
	
	/// The label holding the path of the directory.
	@IBOutlet private weak var titleLabel: NSTextField!
	
	/// The image view displaying the directories icon.
	@IBOutlet private weak var iconImageView: NSImageView!
	
	/// The label holding the app count for this directory.
	@IBOutlet private weak var appCountLabel: NSTextField!
	
	/// The activity indicator shown while the apps are being counted.
	@IBOutlet private weak var activityIndicator: NSProgressIndicator!
	
	/// The URL to be displayed by the cell.
	var url: URL? {
		didSet {
			guard url != oldValue else { return }
			
			isReachable = (try? url?.checkResourceIsReachable()) == true
			setUpView()
		}
	}
	
	var countProvider: AppDirectoryCountProvider? {
		didSet {
			setUpView()
		}
	}
	
	var observationFailureHandler: AppDirectoryCountProvider.CountFailureHandler?
	
	var isReachable: Bool = false
	
	private func setUpView() {
		guard let url else {
			titleLabel.stringValue = ""
			iconImageView.image = nil
			activityIndicator.stopAnimation(nil)
			appCountLabel.isHidden = true
			return
		}
		
		// Title
		titleLabel.stringValue = url.relativePath
		titleLabel.textColor = tintColor
		
		// Image
		iconImageView.image = icon
		
		// App Count
		activityIndicator.startAnimation(nil)
		appCountLabel.isHidden = true
		guard let countProvider else {
			activityIndicator.stopAnimation(nil)
			return
		}
		
		countProvider.count(for: url, completion: { [weak self] count in
			guard let self, self.url == url else { return }
			
			self.appCountLabel.isHidden = false
			self.activityIndicator.stopAnimation(nil)
			self.appCountLabel.stringValue = NumberFormatter.localizedString(from: NSNumber(value: count), number: .none)
		}, onFailure: { [weak self] failedURL, error in
			guard let self, self.url == url else { return }
			self.observationFailureHandler?(failedURL, error)
		})
	}
	
	private var tintColor: NSColor {
		isReachable ? .labelColor : .secondaryLabelColor
	}
	
	private var icon: NSImage {
		if isReachable {
			guard let url else { return NSImage() }
			return NSWorkspace.shared.icon(forFile: url.relativePath)
		}
		
		return NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "")!
	}
}
