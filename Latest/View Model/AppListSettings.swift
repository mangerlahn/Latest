//
//  AppListSettings.swift
//  Latest
//
//  Created by Max Langer on 09.01.22.
//  Copyright © 2022 Max Langer. All rights reserved.
//

private let ShowInstalledUpdatesKey = "ShowInstalledUpdatesKey"
private let ShowIgnoredUpdatesKey = "ShowIgnoredUpdatesKey"
private let ShowUnsupportedUpdatesKey = "ShowUnsupportedUpdatesKey"

/// Observable front end to app list preferences.
struct AppListSettings: Observable {
	
	var observers = [UUID : ObservationHandler]()

	private init() {}
	
	static var shared: AppListSettings = {
		return AppListSettings()
	}()
	
	/// Whether ignored apps should be visible
	var showIgnoredUpdates: Bool {
		set {
			set(newValue, forKey: ShowIgnoredUpdatesKey)
		}
		
		get {
			UserDefaults.standard.bool(forKey: ShowIgnoredUpdatesKey)
		}
	}
	
	/// Whether unsupported apps should be visible
	var showUnsupportedUpdates: Bool {
		set {
			set(newValue, forKey: ShowUnsupportedUpdatesKey)
		}
		
		get {
			UserDefaults.standard.bool(forKey: ShowUnsupportedUpdatesKey)
		}
	}
	
	/// Whether installed apps should be visible
	var showInstalledUpdates: Bool {
		set {
			set(newValue, forKey: ShowInstalledUpdatesKey)
		}
		
		get {
			UserDefaults.standard.bool(forKey: ShowInstalledUpdatesKey)
		}
	}
	
	
	// MARK: - Utilities
	
	private func set(_ value: Any, forKey key: String) {
		UserDefaults.standard.set(value, forKey: key)
		
		DispatchQueue.main.async {
			self.notify()
		}
	}
	
}
