//
//  DisplayLink.swift
//
//  Created by Max Langer on 23.05.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Foundation
import QuartzCore

/// Cross-platform convenience for accessing a DisplayLink.
class DisplayLink: NSObject {

	/// The amount of time the display link should be running. If  set to `nil`, the display link runs indefinitely. 
    private(set) var duration : Double?
	
	/// An optional completion handler called after the display link stopped animating.
    var completionHandler : (() -> ())?
	
	/// The current  animation progress. Only useful if a duration has been set.
	private(set) var progress : Double = 0
    
    #if os(macOS)
    private var displayLink : CVDisplayLink!
    #else
    private var displayLink : CADisplayLink!
    #endif
    
	/// Frames used to calculate the animation progress
    private var _currentFrame : Double = 0
    private var _frames : Double = 0
    
	/// The callback called for each animation step.
    private(set) var callback : ((_ progress: Double) -> Void)!
    
	
	// MARK: - Initialization
	
	/// Initializes the display link with the given duration and callback.
	init(duration: Double?, callback: @escaping ((_ progress: Double) -> Void)) {
        super.init()
        
        self.duration = duration
        self.callback = callback
        
		#if os(macOS)
		func displayLinkOutputCallback(_ displayLink: CVDisplayLink, _ inNow: UnsafePointer<CVTimeStamp>, _ inOutputTime: UnsafePointer<CVTimeStamp>, _ flagsIn: CVOptionFlags, _ flagsOut: UnsafeMutablePointer<CVOptionFlags>, _ displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
			guard let displayLinkContext else { return kCVReturnInvalidArgument }
			
			unsafeBitCast(displayLinkContext, to: DisplayLink.self).displayTick()
			return kCVReturnSuccess
		}
		
		CVDisplayLinkCreateWithActiveCGDisplays(&self.displayLink)
		CVDisplayLinkSetOutputCallback(self.displayLink, displayLinkOutputCallback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
		#else
		self.displayLink = CADisplayLink(target: self,
									   selector: #selector(DisplayLink.displayTick))
		self.displayLink.add(to: .current, forMode: .common)
		#endif
	}
	
	deinit {
		#if os(macOS)
		// Immediately remove callback to avoid access to the deallocated access to this object from the callback on a background thread
		CVDisplayLinkSetOutputCallback(self.displayLink, nil, nil)
		#endif
	}

	
	// MARK: - Animation
    
    @objc private func displayTick() {
        guard let displayLink = self.displayLink else { return }
        
		if let duration = self.duration {
			#if os(macOS)
				let rate = CVDisplayLinkGetActualOutputVideoRefreshPeriod(displayLink)
				self._frames = duration / rate
			#else
				let rate = (1 / (displayLink.targetTimestamp - displayLink.timestamp)).rounded()
				self._frames = duration * rate
			#endif
		}
		
		else {
			self._frames = 1
		}
        
#if os(macOS)
		// Make 60 FPS the default rate and adjust progress increases based on the actual refresh rate of the display.
		self._currentFrame += CVDisplayLinkGetActualOutputVideoRefreshPeriod(displayLink) / (1 / 60.0)
#else
		self._currentFrame += 1
#endif
        
		// Forward progress to the observer
		DispatchQueue.main.async {
			self.progress = self._currentFrame / self._frames
			if self.duration != nil, self.progress >= 1 {
                self.completionHandler?()
				self.stop()
            }
            
			self.callback(self.progress)
        }
	}
    
	
	// MARK: - Actions
	
	/// Starts the display link.
    func start() {
        self._currentFrame = 0
                
        #if os(macOS)
        CVDisplayLinkStart(displayLink)
        #else
        displayLink.isPaused = false
        #endif
    }
    
	/// Stops the display link.
    func stop() {
        #if os(macOS)
		// Must not be called on sync Main Thread, as it causes a deadlock there.
		DispatchQueue.global().async { [weak self] in
			guard let self = self else { return }
			CVDisplayLinkStop(self.displayLink)
		}
        #else
        displayLink.isPaused = true
        #endif
    }
    
	/// Whether the display link is currently running.
    var isRunning : Bool {
        #if os(macOS)
        return CVDisplayLinkIsRunning(displayLink)
        #else
        return displayLink.isPaused
        #endif
    }
    
}
