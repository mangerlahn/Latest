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
	
	enum Setting: String, CaseIterable {
		case appLocations
		
		var userDefaultsKey: String {
			rawValue + "UserDefaultsKey"
		}
		
		var defaultValue: Any {
			switch self {
			case .appLocations:
				true
			}
		}
	}
	
	var observers = [UUID : ObservationHandler]()
	
	private init() {
		// Default settings
		let settings: [(key: String, value: Any)] = Setting.allCases.map { setting in
			return (setting.userDefaultsKey, setting.defaultValue)
		}
		UserDefaults.standard.register(defaults: Dictionary(uniqueKeysWithValues: settings))
	}
	
	static var shared: UpdateCheckSettings = {
		return UpdateCheckSettings()
	}()
	
	
	// MARK: - App Locations
	
	

	
	// MARK: - Utilities
	
	private func set(_ value: Any, for setting: Setting) {
		UserDefaults.standard.set(value, forKey: setting.userDefaultsKey)
		
		DispatchQueue.main.async {
			self.notify()
		}
	}
	
}
