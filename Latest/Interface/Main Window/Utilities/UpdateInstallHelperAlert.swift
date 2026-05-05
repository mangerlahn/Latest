//
//  UpdateInstallHelperAlert.swift
//  Latest
//
//  Created by Max Langer on 31.01.26.
//  Copyright © 2026 Max Langer. All rights reserved.
//

import AppKit
import ServiceManagement

/// An alert that handles setting up the install helper for app store updates.
enum UpdateInstallHelperAlert {
	/// Presents the alert with the given error.
	static func present(with error: InstallHelperError, fallbackURL: URL) {
		guard let window = NSApplication.shared.mainWindow else {
			return
		}
		
		// Common alert configuration
		let alert = NSAlert(error: error)
		alert.alertStyle = .informational
		alert.messageText = NSLocalizedString("UpdateInstallHelperAlert.Title",
											  comment: "Title of the alert prompting to install or enable the update helper")
		
		// Use only the localized errorDescription provided by InstallHelperError
		alert.informativeText = error.errorDescription ?? ""
		
		// Suppression checkbox to remember preference
		alert.showsSuppressionButton = true
		alert.suppressionButton?.title = NSLocalizedString("UpdateInstallHelperAlert.SuppressionTitle",
														   comment: "Checkbox title to always open the App Store instead of using the helper")
		alert.suppressionButton?.state = AppStoreUpdateSettings.alwaysPerformManualUpdates.active ? .on : .off
		
		
		// The only difference: the primary button title and action
		let primaryTitle: String
		let primaryAction: () -> Void
		
		switch error {
		case .installHelperNotRegistered:
			primaryTitle = NSLocalizedString("UpdateInstallHelperAlert.Primary.InstallHelper",
											 comment: "Primary button to install the update helper")
			primaryAction = {
				try? InstallHelper.installHelper()
			}
			
		case .installHelperRequiresApproval:
			primaryTitle = NSLocalizedString("UpdateInstallHelperAlert.Primary.OpenSettings",
											 comment: "Primary button to open Settings to enable the update helper")
			primaryAction = {
				SMAppService.openSystemSettingsLoginItems()
			}
		}
		
		// Add buttons (primary varies, others are shared)
		alert.addButton(withTitle: primaryTitle) // First
		alert.addButton(withTitle: NSLocalizedString("UpdateInstallHelperAlert.Secondary.AppStore",
													 comment: "Button to update the app in the App Store"))
		alert.addButton(withTitle: NSLocalizedString("UpdateInstallHelperAlert.Cancel",
													 comment: "Cancel button in the helper alert"))
		
		// Shared sheet handling
		alert.beginSheetModal(for: window) { response in
			// Persist suppression choice
			AppStoreUpdateSettings.alwaysPerformManualUpdates.active = (alert.suppressionButton?.state == .on)
			
			switch response {
			case .alertFirstButtonReturn:
				primaryAction()
			case .alertSecondButtonReturn:
				NSWorkspace.shared.open(fallbackURL)
			default:
				()
			}
		}
	}
}
