//
//  SupportStatusButtonCell.swift
//  Latest
//
//  Created by Max Langer on 07.02.25.
//  Copyright © 2025 Max Langer. All rights reserved.
//

import AppKit

/// Cell for displaying the support status.
///
/// A custom cell is used to adjust the position of image and label within the button.
class SupportStatusButtonCell: NSButtonCell {
	
	private let spacing: CGFloat = 2
	private let titlePadding: CGFloat = 4
	
	private var imageWidth: CGFloat {
		guard let image else { return .zero }
		return image.size.width
	}
	
	/// The initial position for content on  both the x and y axis
	private var contentStart: CGFloat {
		guard let image, let controlView else { return .zero }
		return controlView.frame.midY - (image.size.width / 2)
	}
	
	private var imageFrame: NSRect {
		// Position the image to the leading or trailing edge
		guard let image, let controlView else { return .zero }
		
		let x: CGFloat = switch controlView.userInterfaceLayoutDirection {
		case .leftToRight:
			contentStart
		case .rightToLeft:
			controlView.bounds.maxX - contentStart - image.size.width
		@unknown default:
			0
		}
		
		return NSRect(origin: .init(x: x, y: contentStart), size: image.size)
	}
	
	private var titleFrame: NSRect {
		guard let controlView else { return .zero }

		let size = attributedTitle.size()
		let y = controlView.frame.midY - (size.height / 2)
		let origin: CGPoint = switch controlView.userInterfaceLayoutDirection {
		case .leftToRight:
			// Position to the right of the image
			CGPoint(x: contentStart+imageWidth + spacing, y: y)
		case .rightToLeft:
			CGPoint(x: contentStart+titlePadding, y: y)
		@unknown default:
			.zero
		}
		
		return NSRect(origin: origin, size: size)
	}
	
	override func drawImage(_ image: NSImage, withFrame frame: NSRect, in controlView: NSView) {
		super.drawImage(image, withFrame: imageFrame, in: controlView)
	}
	
	override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {
		return super.drawTitle(title, withFrame: titleFrame, in: controlView)
	}
	
	override var cellSize: NSSize {
		get {
			var size = super.cellSize
			size.width = contentStart * 2 + imageWidth + attributedTitle.size().width + spacing + titlePadding
			return size
		}
		set {}
	}
}
