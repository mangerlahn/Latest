//
//  UpdateButtonCell.swift
//  Latest
//
//  Created by Max Langer on 1.12.20.
//  Copyright © 2020 Max Langer. All rights reserved.
//

import Cocoa

/// The cell handling the drawing for the Update Button.
class UpdateButtonCell: NSButtonCell {
	
	/// Defines possible button types this cell can draw.
	enum ContentType {
		/// No button shape is rendered at all.
		case none
		
		/// The button is rendered in a pill-shaped manner.
		case button
		
		/// A indeterminate activity indicator will be rendered.
		case indeterminate
		
		/// Draws a circular progress including a cancel button.
		case progress
	}
	
	/// The type of button that should be drawn.
	var contentType: ContentType = .button {
		didSet {
			self.displayLink?.stop()
			
			// Start a display link that continuously updates the activity indicator
			if self.contentType == .indeterminate {
				self.startDisplayLink(withDuration: nil)
			} else {
				self.displayLink = nil
			}
		}
	}
	
	/// The display link animating the view.
	private var displayLink: DisplayLink?
	
	/// A reference to the view holding the cell.
	private var view: UpdateButton {
		return self.controlView as! UpdateButton
	}
	
	/// Convenience for accessing the tint of the button.
	private static var tintColor: NSColor {
		if #available(OSX 10.14, *) {
			return .controlAccentColor
		} else {
			return .systemBlue
		}
	}
	
	/// The progress to be rendered when `.progress` is set as the content type. Animates the transition.
	private var _oldUpdateProgress: Double = 0.0
	var updateProgress: Double = 0.0 {
		didSet {
			guard case .progress = self.contentType else {
				return
			}
			
			self._oldUpdateProgress = oldValue
			self.startDisplayLink(withDuration: 0.2)
		}
	}
	
	private func startDisplayLink(withDuration duration: Double?) {
		displayLink = DisplayLink(duration: duration, callback: { [weak self] frame in
			self?.view.needsDisplay = true
		})
		displayLink?.start()
	}
	
	
	// MARK: - Interface Updates
	
	override func highlight(_ flag: Bool, withFrame cellFrame: NSRect, in controlView: NSView) {
		super.highlight(flag, withFrame: cellFrame, in: controlView)
		
		// On mouseDown, make the background slightly darker
		self.view.animator().backgroundColor = (flag ? #colorLiteral(red: 0.7995074391, green: 0.8113409281, blue: 0.8403512836, alpha: 1) : #colorLiteral(red: 0.9488552213, green: 0.9487094283, blue: 0.9693081975, alpha: 1))
	}
	
	
	// MARK: - Drawing
	
	override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
		switch self.contentType {
		case .none:
			return
		case .button:
			self.drawButtonBackground(withFrame: cellFrame)
		case .indeterminate:
			self.drawIndeterminateActivityIndicator(withFrame: cellFrame)
		case .progress:
			self.drawProgressIndicator(withFrame: cellFrame, controlView: controlView)
		}
		
		super.drawInterior(withFrame: cellFrame, in: controlView)
	}
	
	override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {
		let string = NSMutableAttributedString(attributedString: title)
		let range = NSMakeRange(0, string.length)
		
		// Adjust the styling of the button
		string.addAttribute(.foregroundColor, value: Self.tintColor, range: range)
		string.addAttribute(.font, value: NSFont.systemFont(ofSize: self.font!.pointSize - 1, weight: .medium), range: range)
		
		// Slightly shift frame to account for adjusted font size
		var adjustedFrame = frame
		adjustedFrame.origin.y -= 1
				
		return super.drawTitle(string, withFrame: adjustedFrame, in: controlView)
	}
	
	override func drawImage(_ image: NSImage, withFrame frame: NSRect, in controlView: NSView) {
		// Adjust the position
		var adjustedFrame = frame
		adjustedFrame.origin.y -= 1
		
		super.drawImage(image, withFrame: adjustedFrame, in: controlView)
	}
	
	private func drawButtonBackground(withFrame frame: NSRect) {
		let radius = frame.height / 2.0
		let path = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
		
		self.view.backgroundColor.setFill()
		path.fill()
	}
	
	private func drawIndeterminateActivityIndicator(withFrame frame: NSRect) {
		guard var progress = self.displayLink?.progress else {
			assertionFailure("No display link set to draw with")
			return
		}
		
		let radius = frame.height * 0.4
		let center = CGPoint(x: frame.midX, y: frame.midY)
				
		let path = NSBezierPath()
		progress = progress.truncatingRemainder(dividingBy: 360) * 6
		path.appendArc(withCenter: center, radius: radius, startAngle: CGFloat(progress), endAngle: CGFloat(progress) + 270)
				
		path.lineCapStyle = .round
		path.lineWidth = 2.5
		
		self.indicatorColor(for: NSColor.tertiaryLabelColor).setStroke()
		path.stroke()
	}
	
	private func drawProgressIndicator(withFrame frame: NSRect, controlView: NSView) {
		let radius = frame.height * 0.4
		let center = CGPoint(x: frame.midX, y: frame.midY)
		
		// Draw background circle
		NSColor.tertiaryLabelColor.setStroke()
		var alignedRect = controlView.backingAlignedRect(NSInsetRect(NSRect(origin: center, size: .zero), -radius, -radius), options: .alignAllEdgesOutward)
		var path = NSBezierPath(ovalIn: alignedRect)
		path.lineWidth = 2.5
		path.stroke()
		
		// Draw pause block
		self.indicatorColor(for: Self.tintColor).set()
		alignedRect = controlView.backingAlignedRect(NSInsetRect(NSRect(origin: center, size: .zero), -3, -3), options: .alignAllEdgesOutward)
		NSBezierPath(roundedRect: alignedRect, xRadius: 2, yRadius: 2).fill()
		
		var progress = self.updateProgress
		if let animationProgress = self.displayLink?.progress {
			progress = self._oldUpdateProgress + ((self.updateProgress - self._oldUpdateProgress) * animationProgress)
		}
		
		guard progress > 0 else {
			return
		}
		
		
		// Draw the progress bar
		let start: CGFloat = 270
		let end = start + CGFloat(360 * progress)
		
		path = NSBezierPath()
		path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end)
				
		path.lineCapStyle = .round
		path.lineWidth = 2.5
		
		path.stroke()
	}
		
	private func indicatorColor(for color: NSColor) -> NSColor {
		let tintColor: NSColor = (self.backgroundStyle == .emphasized ? .alternateSelectedControlTextColor : color)
		if #available(OSX 10.14, *) {
			return (self.isHighlighted ? tintColor.withSystemEffect(.pressed) : tintColor)
		} else {
			return (self.isHighlighted ? tintColor.shadow(withLevel: 0.8)! : tintColor)
		}
	}
	
}
