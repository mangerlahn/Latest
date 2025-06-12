//
//  AppListSettings.swift
//  Latest
//
//  Created by Max Langer on 09.01.22.
//  Copyright © 2022 Max Langer. All rights reserved.
//

private let SortOptionsKey = "SortOptionsKey"
private let ShowInstalledUpdatesKey = "ShowInstalledUpdatesKey"
private let ShowIgnoredUpdatesKey = "ShowIgnoredUpdatesKey"

private let IncludeUnsupportedAppsKey = "ShowUnsupportedUpdatesKey"
private let IncludeAppsWithLimitedSupportKey = "IncludeAppsWithLimitedSupportKey"

/// Observable front end to app list preferences.
struct AppListSettings: Observable {
	
	/// Sorting options available to the app list.
	enum SortOptions: Int, CaseIterable {
		/// Sort based on the date of the the last update, similar to what the App Store does.
		case updateDate = 0
		
		/// Sort alphabetically by app name.
		case name = 1
		
		/// A user-displayable text of the given sort option.
		var displayName: String {
			switch self {
			case .updateDate:
				return NSLocalizedString("DateSortOption", comment: "Update date sorting option. Displayed in menu with title: 'Sort By' -> 'Date'")
			case .name:
				return NSLocalizedString("NameSortOption", comment: "Sorting option to list by app names alphabetically. Displayed in menu with title: 'Sort By' -> 'Name'")
			}
		}
	}
	
	var observers = [UUID : ObservationHandler]()

	private init() {
		// Show installed updates by default
		UserDefaults.standard.register(defaults: [ShowInstalledUpdatesKey: true])
	}
	
	static var shared: AppListSettings = {
		return AppListSettings()
	}()
	
	/// The order the app list should be shown in.
	var sortOrder: SortOptions {
		set {
			set(newValue.rawValue, forKey: SortOptionsKey)
		}
		
		get {
			SortOptions(rawValue: UserDefaults.standard.integer(forKey: SortOptionsKey))!
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
	var includeUnsupportedApps: Bool {
		set {
			set(newValue, forKey: IncludeUnsupportedAppsKey)
		}
		
		get {
			UserDefaults.standard.bool(forKey: IncludeUnsupportedAppsKey)
		}
	}
	
	/// Whether apps only partially supported by Latest should be included.
	var includeAppsWithLimitedSupport: Bool {
		set {
			set(newValue, forKey: IncludeAppsWithLimitedSupportKey)
		}
		
		get {
			UserDefaults.standard.bool(forKey: IncludeAppsWithLimitedSupportKey)
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
