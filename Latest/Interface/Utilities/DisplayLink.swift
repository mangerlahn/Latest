//
//  DisplayLink.swift
//
//  Created by Max Langer on 23.05.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Foundation
import QuartzCore

/// Cross-plattform convenience for accessing a DisplayLink.
class DisplayLink: NSObject {

	/// The amount of time the display link should be running. If  set to `nil`, the display link runs indefinitly. 
    private(set) var duration : Double?
	
	/// An optional completion handler called after the display link stopped animating.
    var completionHandler : (() -> ())?
	
	/// The current  animation progess. Only useful if a duration has been set.
	private(set) var progress : Double = 0
    
    #if os(macOS)
    private var displayLink : CVDisplayLink?
    #else
    private var displayLink : CADisplayLink?
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

			unsafeBitCast(displayLinkContext, to: DisplayLink.self).displayTick()
			return kCVReturnSuccess
		}
		
		CVDisplayLinkCreateWithActiveCGDisplays(&self.displayLink)
		CVDisplayLinkSetOutputCallback(self.displayLink!, displayLinkOutputCallback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
		#else
		self.displayLink = CADisplayLink(target: self,
									   selector: #selector(DisplayLink.displayTick))
		self.displayLink!.add(to: .current, forMode: .common)
		#endif
	}
	
	deinit {
		self.stop()
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
        
        self._currentFrame += 1
        
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
        
        guard let displayLink = self.displayLink else { return }
        
        #if os(macOS)
        CVDisplayLinkStart(displayLink)
        #else
        displayLink.isPaused = false
        #endif
    }
    
	/// Stops the display link.
    func stop() {
        guard let displayLink = self.displayLink else { return }
        
        #if os(macOS)
        CVDisplayLinkStop(displayLink)
        #else
        displayLink.isPaused = true
        #endif
    }
    
	/// Whether the display link is currently running.
    var isRunning : Bool {
        guard let displayLink = self.displayLink else { return false }
        
        #if os(macOS)
        return CVDisplayLinkIsRunning(displayLink)
        #else
        return displayLink.isPaused
        #endif
    }
    
}
