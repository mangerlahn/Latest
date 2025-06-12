//
//  ReleaseNotesContentProtocol.swift
//  Latest
//
//  Created by Max Langer on 12.08.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import AppKit

/// This protocol manages the instantiation of the content controllers
protocol ReleaseNotesContentProtocol {
    
    /// The type of the viewController
    associatedtype ReleaseNotesContentController: NSViewController
    
    /// The identifier from which the object is instantiated
    static var StoryboardIdentifier: String { get }
    
    /// The method loading the storyboard
    static func fromStoryboard() -> ReleaseNotesContentController?
    
}

extension ReleaseNotesContentProtocol {
    static func fromStoryboard() -> ReleaseNotesContentController? {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        
        return storyboard.instantiateController(withIdentifier: StoryboardIdentifier) as? ReleaseNotesContentController
    }
}

