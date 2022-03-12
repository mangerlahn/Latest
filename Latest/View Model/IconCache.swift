//
//  IconCache.swift
//  Latest
//
//  Created by Max Langer on 12.08.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import AppKit

/// A cache for app icons.
class IconCache {
    
	/// The shared cache object.
    static var shared = IconCache()
    
	/// Initializes the cache.
    private init() {
        self.cache = NSCache()
    }

	/// The object storing app images.
	private var cache: NSCache<App, NSImage>
	
	/// Provides the icon for the given app through the given completion handler.
    func icon(for app: App, with completion: @escaping (NSImage) -> Void) {
        if let icon = self.cache.object(forKey: app) {
            completion(icon)
			return
        }
        
        DispatchQueue.main.async {
            let icon = NSWorkspace.shared.icon(forFile: app.fileURL.path)
            self.cache.setObject(icon, forKey: app)

            completion(icon)
        }
    }
    
}
