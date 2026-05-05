//
//  SettingsCheckboxItemView.swift
//  Latest
//
//  Created by Codex on 02.01.25.
//

import AppKit

/// Checkbox row with helper text shown directly underneath the control.
final class SettingsCheckboxItemView: NSView {
	
	init(button: NSButton, symbolName: String, tintColor: NSColor, helper: String) {
		super.init(frame: .zero)
		self.translatesAutoresizingMaskIntoConstraints = false
		
		let row = NSStackView()
		row.orientation = .horizontal
		row.alignment = .centerY
		row.spacing = 8
		row.translatesAutoresizingMaskIntoConstraints = false
		
		let leadingAnchorView = Self.makeLeadingAnchorView()
		
			if let imageView = Self.makeSymbolView(named: symbolName, tintColor: tintColor) {
				leadingAnchorView.addSubview(imageView)
				NSLayoutConstraint.activate([
					imageView.centerXAnchor.constraint(equalTo: leadingAnchorView.centerXAnchor),
					imageView.centerYAnchor.constraint(equalTo: leadingAnchorView.centerYAnchor)
				])
			}
		
		row.addArrangedSubview(leadingAnchorView)
		
		button.translatesAutoresizingMaskIntoConstraints = false
		button.setContentCompressionResistancePriority(.required, for: .horizontal)
		button.toolTip = helper
		row.addArrangedSubview(button)
		row.addArrangedSubview(NSView())
		
		let helperLabel = Self.makeHelperLabel(helper)
		
		self.addSubview(row)
		self.addSubview(helperLabel)
		
		NSLayoutConstraint.activate([
			row.leadingAnchor.constraint(equalTo: self.leadingAnchor),
			row.trailingAnchor.constraint(equalTo: self.trailingAnchor),
			row.topAnchor.constraint(equalTo: self.topAnchor),
			helperLabel.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 6),
			helperLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor),
			helperLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
			helperLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor)
		])
	}
	
	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private static func makeHelperLabel(_ text: String) -> NSTextField {
		let label = NSTextField(wrappingLabelWithString: text)
		label.textColor = .secondaryLabelColor
		label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
		label.lineBreakMode = .byWordWrapping
		label.maximumNumberOfLines = 0
		label.translatesAutoresizingMaskIntoConstraints = false
		label.toolTip = text
		return label
	}
	
	private static func makeLeadingAnchorView() -> NSView {
		let view = NSView()
		view.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			view.widthAnchor.constraint(equalToConstant: 18),
			view.heightAnchor.constraint(greaterThanOrEqualToConstant: 18)
		])
		return view
	}
	
	private static func makeSymbolView(named symbolName: String, tintColor: NSColor) -> NSImageView? {
		guard #available(macOS 11.0, *), let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
			return nil
		}
		
		image.isTemplate = true
		
		let imageView = NSImageView(image: image)
		imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
		imageView.contentTintColor = tintColor
		imageView.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			imageView.widthAnchor.constraint(equalToConstant: 18),
			imageView.heightAnchor.constraint(equalToConstant: 18)
		])
		return imageView
	}
}
