//
//  Settings.swift
//  Latest
//
//  Created by Max Langer on 08.12.23.
//  Copyright © 2023 Max Langer. All rights reserved.
//

import Foundation

/// Observable front end to app list preferences.
struct UpdateCheckSettings: Observable {
	
	private static let legacyAutomaticChecksKey = "automaticChecksUserDefaultsKey"
	private static let legacyAutomaticAppUpdatesKey = "automaticAppUpdatesUserDefaultsKey"
	
	/// Available schedules for automatic update checks.
	enum CheckSchedule: Int, CaseIterable {
		case never = 0
		case hourly = 1
		case everyFourHours = 2
		case daily = 3
		
		var displayName: String {
			switch self {
			case .never:
				NSLocalizedString("Never", comment: "Schedule option that disables automatic execution.")
			case .hourly:
				NSLocalizedString("Hourly", comment: "Schedule option for running every hour.")
			case .everyFourHours:
				NSLocalizedString("Every 4 Hours", comment: "Schedule option for running every four hours.")
			case .daily:
				NSLocalizedString("Daily", comment: "Schedule option for running every day.")
			}
		}
		
		var interval: TimeInterval? {
			switch self {
			case .never:
				nil
			case .hourly:
				60 * 60
			case .everyFourHours:
				4 * 60 * 60
			case .daily:
				24 * 60 * 60
			}
		}
		
		func isDue(since date: Date?, now: Date = Date()) -> Bool {
			guard let interval else { return false }
			guard let date else { return true }
			
			return now.timeIntervalSince(date) >= interval
		}
	}
	
	/// Available schedules for automatically installing supported updates.
	enum UpdateSchedule: Int, CaseIterable {
		case never = 0
		case everyCheck = 1
		case hourly = 2
		case daily = 3
		
		var displayName: String {
			switch self {
			case .never:
				NSLocalizedString("Never", comment: "Schedule option that disables automatic execution.")
			case .everyCheck:
				NSLocalizedString("Every Check", comment: "Schedule option for running after every check.")
			case .hourly:
				NSLocalizedString("Hourly", comment: "Schedule option for running every hour.")
			case .daily:
				NSLocalizedString("Daily", comment: "Schedule option for running every day.")
			}
		}
		
		func isDue(since date: Date?, now: Date = Date()) -> Bool {
			switch self {
			case .never:
				return false
			case .everyCheck:
				return true
			case .hourly:
				guard let date else { return true }
				return now.timeIntervalSince(date) >= 60 * 60
			case .daily:
				guard let date else { return true }
				return now.timeIntervalSince(date) >= 24 * 60 * 60
			}
		}
	}
	
		enum Setting: String, CaseIterable {
			case appLocations
			case keepInMenuBar
			case keepInDock
			case automaticCheckSchedule
			case automaticUpdateSchedule
			case lastAutomaticCheckDate
		case lastAutomaticUpdateDate
		
		var userDefaultsKey: String {
			rawValue + "UserDefaultsKey"
		}
		
		var defaultValue: Any? {
				switch self {
				case .appLocations:
					true
				case .keepInMenuBar:
					false
				case .keepInDock:
					true
				case .automaticCheckSchedule:
					CheckSchedule.never.rawValue
				case .automaticUpdateSchedule:
				UpdateSchedule.never.rawValue
			case .lastAutomaticCheckDate, .lastAutomaticUpdateDate:
				nil
			}
		}
	}
	
	var observers = [UUID : ObservationHandler]()
	
	private init() {
		// Default settings
		let settings: [(key: String, value: Any)] = Setting.allCases.compactMap { setting in
			guard let defaultValue = setting.defaultValue else { return nil }
			return (setting.userDefaultsKey, defaultValue)
		}
		UserDefaults.standard.register(defaults: Dictionary(uniqueKeysWithValues: settings))
	}
	
	static var shared: UpdateCheckSettings = {
		return UpdateCheckSettings()
	}()
	
	
	// MARK: - App Locations
	
	/// Whether Latest should remain accessible from the menu bar after its main window is closed.
		var keepInMenuBar: Bool {
			set {
				set(newValue, for: .keepInMenuBar)
		}
		
			get {
				UserDefaults.standard.bool(forKey: Setting.keepInMenuBar.userDefaultsKey)
			}
		}
		
		/// Whether Latest should remain visible in the Dock while it is hidden in menu bar mode.
		var keepInDock: Bool {
			set {
				set(newValue, for: .keepInDock)
			}
			
			get {
				UserDefaults.standard.bool(forKey: Setting.keepInDock.userDefaultsKey)
			}
		}
		
		/// The selected schedule for automatic update checks.
		var automaticCheckSchedule: CheckSchedule {
		set {
			set(newValue.rawValue, for: .automaticCheckSchedule)
		}
		
		get {
			if let legacyValue = UserDefaults.standard.object(forKey: Self.legacyAutomaticChecksKey) as? Bool {
				return legacyValue ? .hourly : .never
			}
			
			return CheckSchedule(rawValue: UserDefaults.standard.integer(forKey: Setting.automaticCheckSchedule.userDefaultsKey)) ?? .never
		}
	}
	
	/// The selected schedule for automatically installing updates Latest supports directly.
	var automaticUpdateSchedule: UpdateSchedule {
		set {
			set(newValue.rawValue, for: .automaticUpdateSchedule)
		}
		
		get {
			if let legacyValue = UserDefaults.standard.object(forKey: Self.legacyAutomaticAppUpdatesKey) as? Bool {
				return legacyValue ? .everyCheck : .never
			}
			
			return UpdateSchedule(rawValue: UserDefaults.standard.integer(forKey: Setting.automaticUpdateSchedule.userDefaultsKey)) ?? .never
		}
	}
	
	/// The timestamp of the last automatic update check started by the scheduler.
	var lastAutomaticCheckDate: Date? {
		set {
			set(newValue?.timeIntervalSinceReferenceDate, for: .lastAutomaticCheckDate)
		}
		
		get {
			let value = UserDefaults.standard.object(forKey: Setting.lastAutomaticCheckDate.userDefaultsKey) as? TimeInterval
			return value.map(Date.init(timeIntervalSinceReferenceDate:))
		}
	}
	
	/// The timestamp of the last automatic update batch started by the scheduler.
	var lastAutomaticUpdateDate: Date? {
		set {
			set(newValue?.timeIntervalSinceReferenceDate, for: .lastAutomaticUpdateDate)
		}
		
		get {
			let value = UserDefaults.standard.object(forKey: Setting.lastAutomaticUpdateDate.userDefaultsKey) as? TimeInterval
			return value.map(Date.init(timeIntervalSinceReferenceDate:))
		}
	}

	
	// MARK: - Utilities
	
	private func set(_ value: Any?, for setting: Setting) {
		if let value {
			UserDefaults.standard.set(value, forKey: setting.userDefaultsKey)
		} else {
			UserDefaults.standard.removeObject(forKey: setting.userDefaultsKey)
		}
		
		DispatchQueue.main.async {
			self.notify()
		}
	}
	
}
