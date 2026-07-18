//
//  AppStoreUpdateCheckerOperation.swift
//  Latest
//
//  Created by Max Langer on 03.10.19.
//  Copyright © 2019 Max Langer. All rights reserved.
//

/// Collection of settings around app store updates
enum AppStoreUpdateSettings: String {
	/// Whether app store updates should always be performed manually.
	case alwaysPerformManualUpdates = "AlwaysPerformManualUpdates"
	
	/// Whether the setting is active.
	var active: Bool {
		get { UserDefaults.standard.bool(forKey: rawValue) }
		nonmutating set { UserDefaults.standard.set(newValue, forKey: rawValue) }
	}
}

