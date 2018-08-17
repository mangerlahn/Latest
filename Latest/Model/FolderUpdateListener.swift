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
    
    private var timer: Timer?
    
    /// The file system listener
    lazy var listener : DispatchSourceFileSystemObject = {
        let descriptor = open((self.url as NSURL).fileSystemRepresentation, O_EVTONLY)
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                                                               eventMask: .write)
        
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
        self.listener.activate()
    }
    
    /// Triggers an update run
    private func folderContentsChanged() {
        DispatchQueue.main.async {
            if !(self.timer?.isValid ?? false) {
                
                // Hide the run method behind a timer, so that multiple content changes can occur before we check for new updates
                self.timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] (_) in
                    self?.updateChecker.run()
                    self?.timer?.invalidate()
                }
            }
        }
    }
    
}
