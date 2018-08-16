//
//  IconCache.swift
//  Latest
//
//  Created by Max Langer on 12.08.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import AppKit

class IconCache {
    
    static var shared = IconCache()
    
    private var cache: NSCache<NSURL, NSImage>
    
    init() {
        self.cache = NSCache()
    }
    
    func icon(for app: AppBundle, with completion: @escaping (NSImage) -> Void) {
        if let icon = self.cache.object(forKey: app.url as NSURL) {
            completion(icon)
        }
        
        DispatchQueue.main.async {
            let icon = NSWorkspace.shared.icon(forFile: app.url.path)
            self.cache.setObject(icon, forKey: app.url as NSURL)

            completion(icon)
        }
    }
    
}
