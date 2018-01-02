//
//  FolderUpdateListener.swift
//  Latest
//
//  Created by Max Langer on 02.01.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import Cocoa

/**
 The folder listener listens for changes in the given directory and then runs the update checker on changes
 */
class FolderUpdateListener {

    /// The url on which the listener reacts to changes on
    var url : URL
    
    /// The update checker which should be run when the contents change
    var updateChecker : UpdateChecker
    
    /// The file system listener
    lazy var listener : DispatchSourceFileSystemObject = {
        let descriptor = open((self.url as NSURL).fileSystemRepresentation, O_EVTONLY)
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                                                               eventMask: .all)
        
        source.setEventHandler(handler: self.folderContentsChanged)
        
        return source
    }()

    /// Initializes the class and resumes the listener automatically
    init(url: URL, updateChecker: UpdateChecker) {
        self.url = url
        self.updateChecker = updateChecker
        
        self.resumeTracking()
    }
    
    /// Resumes tracking if it is not already running
    func resumeTracking() {
        if self.listener.isCancelled {
            self.listener.resume()
        }
    }
    
    /// Triggers an update run
    private func folderContentsChanged() {
        DispatchQueue.main.async {
            self.updateChecker.run()
        }
    }
    
}
