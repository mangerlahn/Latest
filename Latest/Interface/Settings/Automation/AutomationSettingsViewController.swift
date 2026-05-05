//
//  AutomationSettingsViewController.swift
//  Latest
//
//  Created by Codex on 02.01.25.
//

import AppKit

/// Controller for settings of the Automation tab.
class AutomationSettingsViewController: SettingsTabItemViewController, Observer {
	var id = UUID()
	
	private enum Style {
		static let automationColor = NSColor.systemGreen
	}
	
	private let checkSchedulePopUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
	private let updateSchedulePopUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
	private let selfUpdateCheckBox = NSButton(checkboxWithTitle: NSLocalizedString("Automatically check for Latest updates", comment: "Title for enabling Sparkle self-update checks for Latest."), target: nil, action: nil)
	
	override func loadView() {
		self.view = NSView(frame: NSRect(origin: .zero, size: SettingsTabItemViewController.preferredSettingsContentSize))
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.preferredContentSize = SettingsTabItemViewController.preferredSettingsContentSize
		self.view.setFrameSize(self.preferredContentSize)
		self.buildInterface()
		self.configureAutomaticCheckSchedulePopUp()
		self.configureAutomaticUpdateSchedulePopUp()
		self.refreshControls()
		UpdateCheckSettings.shared.add(self, handler: self.refreshControls)
	}
	
	deinit {
		UpdateCheckSettings.shared.remove(self)
	}
	
	@IBAction @objc private func changeAutomaticCheckSchedule(_ sender: NSPopUpButton) {
		let rawValue = sender.selectedTag()
		UpdateCheckSettings.shared.automaticCheckSchedule = UpdateCheckSettings.CheckSchedule(rawValue: rawValue) ?? .never
	}
	
	@IBAction @objc private func changeAutomaticUpdateSchedule(_ sender: NSPopUpButton) {
		let rawValue = sender.selectedTag()
		UpdateCheckSettings.shared.automaticUpdateSchedule = UpdateCheckSettings.UpdateSchedule(rawValue: rawValue) ?? .never
	}

	@IBAction @objc private func changeSelfUpdatePreference(_ sender: NSButton) {
		self.appDelegate?.automaticallyChecksForSelfUpdates = (sender.state == .on)
		self.refreshControls()
	}
	
	private func configureAutomaticCheckSchedulePopUp() {
		self.checkSchedulePopUpButton.removeAllItems()
		
		UpdateCheckSettings.CheckSchedule.allCases.forEach { schedule in
			self.checkSchedulePopUpButton.addItem(withTitle: schedule.displayName)
			self.checkSchedulePopUpButton.lastItem?.tag = schedule.rawValue
		}
	}
	
	private func configureAutomaticUpdateSchedulePopUp() {
		self.updateSchedulePopUpButton.removeAllItems()
		
		UpdateCheckSettings.UpdateSchedule.allCases.forEach { schedule in
			self.updateSchedulePopUpButton.addItem(withTitle: schedule.displayName)
			self.updateSchedulePopUpButton.lastItem?.tag = schedule.rawValue
		}
	}
	
	private func buildInterface() {
		self.view.subviews.forEach { $0.isHidden = true }
		
		let contentStack = NSStackView()
		contentStack.orientation = .vertical
		contentStack.alignment = .width
		contentStack.spacing = 24
		contentStack.translatesAutoresizingMaskIntoConstraints = false
		
		self.view.addSubview(contentStack)
		
		NSLayoutConstraint.activate([
			contentStack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 24),
			contentStack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -24),
			contentStack.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 24),
			contentStack.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor, constant: -24)
		])
		
		self.checkSchedulePopUpButton.target = self
		self.checkSchedulePopUpButton.action = #selector(changeAutomaticCheckSchedule(_:))
		
		self.updateSchedulePopUpButton.target = self
		self.updateSchedulePopUpButton.action = #selector(changeAutomaticUpdateSchedule(_:))
		self.selfUpdateCheckBox.target = self
		self.selfUpdateCheckBox.action = #selector(changeSelfUpdatePreference(_:))
		
		let automationSection = SettingsSectionView(
			title: NSLocalizedString("Automation", comment: "Settings section title."),
			symbolName: "clock.arrow.circlepath",
			tintColor: Style.automationColor,
			items: [
				SettingsPopUpItemView(
					title: NSLocalizedString("Automatically check for updates", comment: "Automatic check schedule title."),
					symbolName: "magnifyingglass.circle",
					tintColor: Style.automationColor,
					popUpButton: self.checkSchedulePopUpButton,
					helper: NSLocalizedString("Latest also checks after your Mac wakes up when the selected schedule is due.", comment: "Helper text for automatic checks.")
				),
				SettingsPopUpItemView(
					title: NSLocalizedString("Automatically install supported updates", comment: "Automatic update schedule title."),
					symbolName: "square.and.arrow.down",
					tintColor: Style.automationColor,
					popUpButton: self.updateSchedulePopUpButton,
					helper: NSLocalizedString("Only updates that Latest can install itself are applied automatically.", comment: "Helper text for automatic updates.")
				),
				SettingsCheckboxItemView(
					button: self.selfUpdateCheckBox,
					symbolName: "sparkles",
					tintColor: Style.automationColor,
					helper: NSLocalizedString("Re-enable Latest's own Sparkle automatic update checks after dismissing the first-launch prompt.", comment: "Helper text for enabling Sparkle self-update checks in settings.")
				)
			]
		)
		contentStack.addArrangedSubview(automationSection)
		
		NSLayoutConstraint.activate([
			automationSection.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
			automationSection.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor)
		])
	}
	
	private func refreshControls() {
		self.checkSchedulePopUpButton.selectItem(withTag: UpdateCheckSettings.shared.automaticCheckSchedule.rawValue)
		self.updateSchedulePopUpButton.selectItem(withTag: UpdateCheckSettings.shared.automaticUpdateSchedule.rawValue)
		self.selfUpdateCheckBox.state = self.appDelegate?.automaticallyChecksForSelfUpdates == true ? .on : .off
		self.selfUpdateCheckBox.isEnabled = (self.appDelegate != nil)
	}

	private var appDelegate: AppDelegate? {
		NSApp.delegate as? AppDelegate
	}
}
