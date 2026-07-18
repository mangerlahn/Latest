//
//  MainWindowController.swift
//  Latest
//
//  Created by Max Langer on 27.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

/**
 This class controls the main window of the app. It includes the list of apps that have an update available as well as the release notes for the specific update.
 */
class MainWindowController: NSWindowController, NSMenuItemValidation, NSMenuDelegate, UpdateCheckProgressReporting {
    
	/// Encapsulates the main window items with their according tag identifiers
	private enum MainMenuItem: Int {
		case latest = 0, file, edit, view, window, help
	}
    
    /// The list view holding the apps
    lazy var listViewController : UpdateTableViewController = {
		let splitViewController = self.contentViewController as? NSSplitViewController
        guard let firstItem = splitViewController?.splitViewItems[0], let controller = firstItem.viewController as? UpdateTableViewController else {
                return UpdateTableViewController()
        }
		
		// Override sidebar collapsing behavior
		firstItem.canCollapse = false
        
        return controller
    }()
    
    /// The detail view controller holding the release notes
    lazy var releaseNotesViewController : ReleaseNotesViewController = {
        guard let splitViewController = self.contentViewController as? NSSplitViewController,
            let secondItem = splitViewController.splitViewItems[1].viewController as? ReleaseNotesViewController else {
                return ReleaseNotesViewController()
        }
        
        return secondItem
    }()
    
    /// The progress indicator showing how many apps have been checked for updates
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    /// The button that triggers an reload/recheck for updates
    @IBOutlet weak var reloadButton: NSButton!
    @IBOutlet weak var reloadTouchBarButton: NSButton!
    
	/// The button that triggers all available updates to be done
	@IBOutlet weak var updateAllButton: NSButton!

	private struct ObservationFailure {
		let url: URL
		let error: Error
	}

	private var presentedObservationFailures = Set<String>()
	private var pendingObservationFailures = [ObservationFailure]()
	private var currentObservationFailure: ObservationFailure?
	private var observationFailureSheetController: DirectoryObservationSheetController?
        
    override func windowDidLoad() {
        super.windowDidLoad()
		DiagnosticsLog.trace(.mainWindow, "windowDidLoad")
    
		self.window?.titlebarAppearsTransparent = true
		self.window?.title = Bundle.main.localizedInfoDictionary?[kCFBundleNameKey as String] as! String

		if #available(macOS 11.0, *) {
			self.window?.toolbarStyle = .unified
		} else {
			self.window?.titleVisibility = .hidden
		}
        
		// Set ourselves as the view menu delegate
		NSApplication.shared.mainMenu?.item(at: MainMenuItem.view.rawValue)?.submenu?.delegate = self
		
		UpdateCheckCoordinator.shared.progressDelegate = self
        
        self.window?.makeFirstResponder(self.listViewController)
        self.window?.delegate = self
        
		self.listViewController.checkForUpdates()
		self.listViewController.releaseNotesViewController = self.releaseNotesViewController

		if let splitViewController = self.contentViewController as? NSSplitViewController {
			splitViewController.splitView.autosaveName = "MainSplitView"
			
            let detailItem = splitViewController.splitViewItems[1]
            detailItem.collapseBehavior = .preferResizingSplitViewWithFixedSiblings
		}
		
		self.presentNextObservationFailureIfPossible()
    }

    
    // MARK: - Action Methods
    
    /// Reloads the list / checks for updates
    @IBAction func reload(_ sender: Any?) {
        self.listViewController.checkForUpdates()
    }
    
    /// Open all apps that have an update available. If apps from the Mac App Store are there as well, open the Mac App Store
    @IBAction func updateAll(_ sender: Any?) {
		// Iterate all updatable apps and perform update
		UpdateCheckCoordinator.shared.appProvider.updatableApps.forEach({ app in
			if !app.isUpdating {
				app.performUpdate()
			}
		})
    }
    	
	@IBAction func performFindPanelAction(_ sender: Any?) {
		self.window?.makeFirstResponder(self.listViewController.searchField)
	}
    
	@IBAction func visitWebsite(_ sender: NSMenuItem?) {
		NSWorkspace.shared.open(URL(string: "https://max.codes/latest")!)
    }
	
	@IBAction func donate(_ sender: NSMenuItem?) {
		NSWorkspace.shared.open(URL(string: "https://max.codes/latest/donate/")!)
	}
    
    
    // MARK: Menu Item

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else {
            return true
        }
        
        switch action {
        case #selector(updateAll(_:)):
			return hasUpdatesAvailable
        case #selector(reload(_:)):
            return self.reloadButton.isEnabled
		case #selector(performFindPanelAction(_:)):
			// Only allow the find item
			return menuItem.tag == 1
        default:
            return true
        }
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items.forEach { (menuItem) in
			// Sort By menu constructed dynamically
			if menuItem.identifier == NSUserInterfaceItemIdentifier(rawValue: "sortByMenu") {
				menuItem.submenu?.items = sortByMenuItems
			}

            guard let action = menuItem.action else { return }
            
            switch action {
			case #selector(toggleShowInstalledUpdates(_:)):
                menuItem.state = AppListSettings.shared.showInstalledUpdates ? .on : .off
			case #selector(toggleShowIgnoredUpdates(_:)):
                menuItem.state = AppListSettings.shared.showIgnoredUpdates ? .on : .off
            default:
                ()
            }
		}
    }
	
	private var sortByMenuItems: [NSMenuItem] {
		AppListSettings.SortOptions.allCases.map { order in
			let item = NSMenuItem(title: order.displayName, action: #selector(changeSortOrder), keyEquivalent: "")
			item.representedObject = order
			item.state = AppListSettings.shared.sortOrder == order ? .on : .off
			
			return item
		}
	}
    
    
    // MARK: - Update Checker Progress Delegate
	
	func updateCheckerDidStartScanningForApps(_ updateChecker: UpdateCheckCoordinator) {
		// Disable UI
        self.reloadButton.isEnabled = false
        self.reloadTouchBarButton.isEnabled = false
		
		// Setup indeterminate progress indicator
		self.progressIndicator.isIndeterminate = true
        self.progressIndicator.isHidden = false
		self.progressIndicator.startAnimation(updateChecker)
	}
    
    /// This implementation activates the progress indicator, sets its max value and disables the reload button
	func updateChecker(_ updateChecker: UpdateCheckCoordinator, didStartCheckingApps numberOfApps: Int) {
		// Setup progress indicator
		self.progressIndicator.isIndeterminate = false
        self.progressIndicator.doubleValue = 0
        self.progressIndicator.maxValue = Double(numberOfApps - 1)
	}
    
    /// Update the progress indicator
	func updateChecker(_ updateChecker: UpdateCheckCoordinator, didCheckApp: App) {
		self.progressIndicator.increment(by: 1)
    }
	
	func updateCheckerDidFinishCheckingForUpdates(_ updateChecker: UpdateCheckCoordinator) {
		self.reloadButton.isEnabled = true
		self.reloadTouchBarButton.isEnabled = true
		self.progressIndicator.isHidden = true
        self.updateAllButton.isEnabled = hasUpdatesAvailable
	}

	func updateChecker(_ updateChecker: UpdateCheckCoordinator, didFailToObserveDirectoryAt url: URL, error: Error) {
		DispatchQueue.main.async {
			DiagnosticsLog.trace(.mainWindow, "didFailToObserveDirectoryAt path=\(url.path) error=\(error.localizedDescription)")
			let failureKey = "\(url.path)|\(error.localizedDescription)"
			guard self.presentedObservationFailures.insert(failureKey).inserted else { return }
			NSApplication.shared.requestUserAttention(.informationalRequest)
			self.pendingObservationFailures.append(ObservationFailure(url: url, error: error))
			self.presentNextObservationFailureIfPossible()
		}
	}
    
	
	// MARK: - Actions
	
	@IBAction func changeSortOrder(_ sender: NSMenuItem?) {
		AppListSettings.shared.sortOrder = sender?.representedObject as! AppListSettings.SortOptions
	}

	@IBAction func toggleShowInstalledUpdates(_ sender: NSMenuItem?) {
		AppListSettings.shared.showInstalledUpdates.toggle()
	}
	
	@IBAction func toggleShowIgnoredUpdates(_ sender: NSMenuItem?) {
		AppListSettings.shared.showIgnoredUpdates.toggle()
	}

	
	// MARK: - Accessors
	
	/// Whether there are any updatable apps.
	private var hasUpdatesAvailable: Bool {
		!UpdateCheckCoordinator.shared.appProvider.updatableApps.isEmpty
	}

    
    // MARK: - Private Methods
    	
    private func showReleaseNotes(_ show: Bool, animated: Bool) {
        guard let splitViewController = self.contentViewController as? NSSplitViewController else {
            return
        }
        
        let detailItem = splitViewController.splitViewItems[1]
        
        if animated {
            detailItem.animator().isCollapsed = !show
        } else {
            detailItem.isCollapsed = !show
        }
        
        if !show {
            // Deselect current app
            self.listViewController.selectApp(at: nil)
        }
    }

	private func presentNextObservationFailureIfPossible() {
		DiagnosticsLog.trace(.mainWindow, "presentNextObservationFailureIfPossible current=\(currentObservationFailure != nil) pending=\(pendingObservationFailures.count)")
		guard currentObservationFailure == nil, !pendingObservationFailures.isEmpty else { return }
		guard let window = self.window, window.isVisible, window.attachedSheet == nil else {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
				self.presentNextObservationFailureIfPossible()
			}
			return
		}

		let failure = pendingObservationFailures.removeFirst()
		currentObservationFailure = failure
		let sheetController = DirectoryObservationSheetController(url: failure.url, error: failure.error)
		observationFailureSheetController = sheetController
		DiagnosticsLog.trace(.mainWindow, "presentingCustomSheet path=\(failure.url.path)")
		window.beginSheet(sheetController.window!) { [weak self] response in
			guard let self else { return }
			self.observationFailureSheetController = nil
			switch response {
			case .alertFirstButtonReturn:
				DirectoryObservationAlertPresenter.openPrivacySettings(for: failure.url)
			case .alertSecondButtonReturn:
				DirectoryObservationAlertPresenter.openFullDiskAccess()
			default:
				break
			}
			self.currentObservationFailure = nil
			self.presentNextObservationFailureIfPossible()
		}
	}
	
}

extension MainWindowController: NSWindowDelegate {
	@available(macOS, deprecated: 11.0)
	func window(_ window: NSWindow, willPositionSheet sheet: NSWindow, using rect: NSRect) -> NSRect {
		NSRect(x: rect.minX + 50, y: rect.minY - 50, width: rect.width, height: rect.height)
	}
    
}

enum DirectoryObservationAlertPresenter {

	static func handle(response: NSApplication.ModalResponse, for url: URL, error: Error) {
		switch action(for: response, error: error) {
		case .dismiss:
			return
		case .openPrivacySettings:
			_ = openPrivacySettings(for: url)
		case .openFullDiskAccess:
			_ = openFullDiskAccess()
		}
	}

	static func summary(for error: Error) -> String {
		isPermissionError(error)
			? NSLocalizedString("DirectoryObservationFailedPermissionSummary", comment: "Summary shown when Latest cannot access a configured app folder because of missing macOS privacy permissions.")
			: NSLocalizedString("DirectoryObservationFailedSummary", comment: "Summary shown when Latest cannot access a configured app folder.")
	}

	static func recoverySuggestion(for url: URL) -> String {
		let recoveryKey = url.path.hasPrefix("/Volumes/")
			? "DirectoryObservationFailedRemovableVolumeSuggestion"
			: "DirectoryObservationFailedPermissionSuggestion"
		return NSLocalizedString(recoveryKey, comment: "Guidance shown when Latest cannot access a configured app folder because of permissions.")
	}

	private enum Action {
		case dismiss
		case openPrivacySettings
		case openFullDiskAccess
	}

	private static func action(for response: NSApplication.ModalResponse, error: Error) -> Action {
		guard isPermissionError(error) else { return .dismiss }

		switch response {
		case .alertFirstButtonReturn:
			return .openPrivacySettings
		case .alertSecondButtonReturn:
			return .openFullDiskAccess
		default:
			return .dismiss
		}
	}

	@discardableResult
	static func openPrivacySettings(for url: URL) -> Bool {
		let candidates = if url.path.hasPrefix("/Volumes/") {
			[
				"x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_FilesAndFolders",
				"x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders",
				"x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
				"x-apple.systempreferences:com.apple.preference.security"
			]
		} else {
			[
				"x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
				"x-apple.systempreferences:com.apple.preference.security"
			]
		}

		return openFirstAvailableURL(from: candidates)
	}

	@discardableResult
	static func openFullDiskAccess() -> Bool {
		openFirstAvailableURL(from: [
			"x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
			"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
			"x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
			"x-apple.systempreferences:com.apple.preference.security"
		])
	}

	private static func openFirstAvailableURL(from urlStrings: [String]) -> Bool {
		for urlString in urlStrings {
			guard let url = URL(string: urlString) else { continue }
			if NSWorkspace.shared.open(url) {
				return true
			}
		}

		let fallbackURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
		return NSWorkspace.shared.open(fallbackURL)
	}

	static func isPermissionError(_ error: Error) -> Bool {
		let nsError = error as NSError

		if isPermissionCode(domain: nsError.domain, code: nsError.code) {
			return true
		}

		if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
			return isPermissionCode(domain: underlyingError.domain, code: underlyingError.code)
		}

		return false
	}

	private static func isPermissionCode(domain: String, code: Int) -> Bool {
		if domain == NSPOSIXErrorDomain,
		   let posixCode = POSIXErrorCode(rawValue: Int32(code)) {
			return posixCode == .EACCES || posixCode == .EPERM
		}

		return domain == NSCocoaErrorDomain && code == NSFileReadNoPermissionError
	}
}

final class DirectoryObservationBannerView: NSVisualEffectView {
	var onDismiss: (() -> Void)?
	var onOpenPrivacySettings: ((URL) -> Void)?
	var onOpenFullDiskAccess: (() -> Void)?

	private let iconView = NSImageView()
	private let titleLabel = NSTextField(labelWithString: NSLocalizedString("DirectoryObservationFailedAlertTitle", comment: "Title of alert shown when Latest cannot monitor a configured app scan directory."))
	private let summaryLabel = NSTextField(wrappingLabelWithString: "")
	private let folderCaptionLabel = NSTextField(labelWithString: NSLocalizedString("DirectoryObservationFailedFolderLabel", comment: "Caption shown above the inaccessible folder path."))
	private let folderPathLabel = NSTextField(wrappingLabelWithString: "")
	private let reasonCaptionLabel = NSTextField(labelWithString: NSLocalizedString("DirectoryObservationFailedReasonLabel", comment: "Caption shown above the system-provided failure reason."))
	private let reasonLabel = NSTextField(wrappingLabelWithString: "")
	private let recoveryLabel = NSTextField(wrappingLabelWithString: "")
	private let permissionNoteLabel = NSTextField(wrappingLabelWithString: NSLocalizedString("DirectoryObservationFailedPermissionControlNote", comment: "Note clarifying that Latest cannot grant macOS privacy permissions on the user's behalf."))
	private let openPrivacySettingsButton = NSButton(title: NSLocalizedString("OpenPrivacySettingsAction", comment: "Action to open the relevant Privacy & Security settings pane."), target: nil, action: nil)
	private let openFullDiskAccessButton = NSButton(title: NSLocalizedString("OpenFullDiskAccessAction", comment: "Action to open the Full Disk Access privacy settings pane."), target: nil, action: nil)
	private let dismissButton = NSButton(title: NSLocalizedString("OKAction", comment: "Default button for dismissing an informational alert."), target: nil, action: nil)
	private let container = NSView()
	private let buttonRowContainer = NSView()
	private let buttonSeparator = NSBox()

	private var url: URL?

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		configureView()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		configureView()
	}

	func configure(with url: URL, error: Error) {
		self.url = url
		summaryLabel.stringValue = DirectoryObservationAlertPresenter.summary(for: error)
		folderPathLabel.stringValue = url.path
		reasonLabel.stringValue = error.localizedDescription
		recoveryLabel.stringValue = DirectoryObservationAlertPresenter.recoverySuggestion(for: url)

		let isPermissionError = DirectoryObservationAlertPresenter.isPermissionError(error)
		openPrivacySettingsButton.isHidden = !isPermissionError
		openFullDiskAccessButton.isHidden = !isPermissionError
		permissionNoteLabel.isHidden = !isPermissionError
		invalidateIntrinsicContentSize()
	}

	override var intrinsicContentSize: NSSize {
		let containerSize = container.fittingSize
		return NSSize(width: NSView.noIntrinsicMetric, height: containerSize.height + 28)
	}

	@objc private func dismiss(_ sender: Any?) {
		onDismiss?()
	}

	@objc private func openPrivacySettings(_ sender: Any?) {
		guard let url else { return }
		onOpenPrivacySettings?(url)
	}

	@objc private func openFullDiskAccess(_ sender: Any?) {
		onOpenFullDiskAccess?()
	}

	private func configureView() {
		translatesAutoresizingMaskIntoConstraints = false
		material = .contentBackground
		blendingMode = .withinWindow
		state = .followsWindowActiveState

		container.translatesAutoresizingMaskIntoConstraints = false
		addSubview(container)

		let rootStack = NSStackView()
		rootStack.orientation = .vertical
		rootStack.alignment = .leading
		rootStack.spacing = 14
		rootStack.translatesAutoresizingMaskIntoConstraints = false
		container.addSubview(rootStack)

		iconView.image = NSImage(named: NSImage.cautionName)
		iconView.contentTintColor = .systemOrange
		iconView.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			iconView.widthAnchor.constraint(equalToConstant: 16),
			iconView.heightAnchor.constraint(equalToConstant: 16)
		])

		titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize + 1, weight: .semibold)
		titleLabel.lineBreakMode = .byWordWrapping

		let headerStack = NSStackView(views: [iconView, titleLabel])
		headerStack.orientation = .horizontal
		headerStack.alignment = .centerY
		headerStack.spacing = 10
		rootStack.addArrangedSubview(headerStack)
		rootStack.setCustomSpacing(22, after: headerStack)

		configureWrappingLabel(summaryLabel)
		configureSectionLabel(folderCaptionLabel)
		configurePathLabel(folderPathLabel)
		configureSectionLabel(reasonCaptionLabel)
		configureWrappingLabel(reasonLabel)
		configureWrappingLabel(recoveryLabel)
		configureWrappingLabel(permissionNoteLabel, secondary: true)

		[summaryLabel, folderCaptionLabel, folderPathLabel, reasonCaptionLabel, reasonLabel, recoveryLabel, permissionNoteLabel].forEach {
			rootStack.addArrangedSubview($0)
		}
		rootStack.setCustomSpacing(18, after: summaryLabel)
		rootStack.setCustomSpacing(18, after: folderPathLabel)
		rootStack.setCustomSpacing(18, after: reasonLabel)
		rootStack.setCustomSpacing(20, after: recoveryLabel)
		rootStack.setCustomSpacing(24, after: permissionNoteLabel)

		openPrivacySettingsButton.target = self
		openPrivacySettingsButton.action = #selector(openPrivacySettings(_:))
		openFullDiskAccessButton.target = self
		openFullDiskAccessButton.action = #selector(openFullDiskAccess(_:))
		dismissButton.target = self
		dismissButton.action = #selector(dismiss(_:))
		[openPrivacySettingsButton, openFullDiskAccessButton, dismissButton].forEach {
			$0.controlSize = .small
			$0.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
			$0.bezelStyle = .rounded
			$0.sizeToFit()
		}

		let buttonStack = NSStackView(views: [openPrivacySettingsButton, openFullDiskAccessButton, dismissButton])
		buttonStack.orientation = .horizontal
		buttonStack.alignment = .centerY
		buttonStack.spacing = 8
		buttonStack.translatesAutoresizingMaskIntoConstraints = false

		buttonSeparator.boxType = .separator
		buttonSeparator.translatesAutoresizingMaskIntoConstraints = false
		rootStack.addArrangedSubview(buttonSeparator)
		rootStack.setCustomSpacing(14, after: buttonSeparator)

		buttonRowContainer.translatesAutoresizingMaskIntoConstraints = false
		buttonRowContainer.addSubview(buttonStack)
		rootStack.addArrangedSubview(buttonRowContainer)

		NSLayoutConstraint.activate([
			container.topAnchor.constraint(equalTo: topAnchor, constant: 20),
			container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
			container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
			container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
			rootStack.topAnchor.constraint(equalTo: container.topAnchor),
			rootStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
			rootStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
			rootStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
			buttonRowContainer.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
			buttonStack.topAnchor.constraint(equalTo: buttonRowContainer.topAnchor),
			buttonStack.trailingAnchor.constraint(equalTo: buttonRowContainer.trailingAnchor),
			buttonStack.bottomAnchor.constraint(equalTo: buttonRowContainer.bottomAnchor)
		])
	}

	private func configureWrappingLabel(_ label: NSTextField, secondary: Bool = false) {
		label.textColor = secondary ? .secondaryLabelColor : .labelColor
		label.alignment = .left
		label.font = .systemFont(ofSize: NSFont.systemFontSize)
		label.lineBreakMode = .byWordWrapping
		label.maximumNumberOfLines = 0
		label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
	}

	private func configureSectionLabel(_ label: NSTextField) {
		label.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
		label.textColor = .secondaryLabelColor
	}

	private func configurePathLabel(_ label: NSTextField) {
		configureWrappingLabel(label)
		label.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
	}
}

final class DirectoryObservationSheetController: NSWindowController {
	init(url: URL, error: Error) {
		let contentViewController = DirectoryObservationSheetViewController(url: url, error: error)
		let window = NSWindow(contentViewController: contentViewController)
		window.styleMask = [.titled]
		window.titleVisibility = .hidden
		window.titlebarAppearsTransparent = true
		window.isReleasedWhenClosed = false
		window.standardWindowButton(.miniaturizeButton)?.isHidden = true
		window.standardWindowButton(.zoomButton)?.isHidden = true
		window.standardWindowButton(.closeButton)?.isHidden = true
		window.contentMinSize = contentViewController.preferredContentSize
		window.setContentSize(contentViewController.preferredContentSize)
		super.init(window: window)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

final class DirectoryObservationSheetViewController: NSViewController {
	private let bannerView = DirectoryObservationBannerView()

	init(url: URL, error: Error) {
		super.init(nibName: nil, bundle: nil)
		bannerView.configure(with: url, error: error)
		bannerView.onDismiss = { [weak self] in
			self?.endSheet(with: .cancel)
		}
		bannerView.onOpenPrivacySettings = { [weak self] _ in
			self?.endSheet(with: .alertFirstButtonReturn)
		}
		bannerView.onOpenFullDiskAccess = { [weak self] in
			self?.endSheet(with: .alertSecondButtonReturn)
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		let view = NSView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.wantsLayer = true
		view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
		view.addSubview(bannerView)
		bannerView.translatesAutoresizingMaskIntoConstraints = false

		NSLayoutConstraint.activate([
			bannerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
			bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
			bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
			bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
			bannerView.widthAnchor.constraint(equalToConstant: 490)
		])

		self.view = view
		updatePreferredContentSize()
	}

	override func viewDidLayout() {
		super.viewDidLayout()
		updatePreferredContentSize()
	}

	private func updatePreferredContentSize() {
		let size = bannerView.fittingSize
		self.preferredContentSize = NSSize(width: 522, height: size.height + 32)
	}

	private func endSheet(with response: NSApplication.ModalResponse) {
		guard let sheetWindow = self.view.window, let sheetParent = sheetWindow.sheetParent else { return }
		sheetParent.endSheet(sheetWindow, returnCode: response)
	}
}
