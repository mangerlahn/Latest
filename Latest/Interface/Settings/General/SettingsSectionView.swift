//
//  SettingsSectionView.swift
//  Latest
//
//  Created by Codex on 02.01.25.
//

import AppKit

/// Section container used for groups of related settings rows.
final class SettingsSectionView: NSView {
	
	init(title: String, symbolName: String, tintColor: NSColor, items: [NSView]) {
		super.init(frame: .zero)
		self.translatesAutoresizingMaskIntoConstraints = false
		
		let titleRow = NSStackView()
		titleRow.orientation = .horizontal
		titleRow.alignment = .centerY
		titleRow.spacing = 8
		titleRow.translatesAutoresizingMaskIntoConstraints = false
		
		if let imageView = Self.makeSymbolView(named: symbolName, tintColor: tintColor) {
			titleRow.addArrangedSubview(imageView)
		}
		
		let titleLabel = NSTextField(labelWithString: title)
		titleLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
		titleRow.addArrangedSubview(titleLabel)
		
		let spacer = NSView()
		spacer.translatesAutoresizingMaskIntoConstraints = false
		titleRow.addArrangedSubview(spacer)
		
		let contentStack = NSStackView()
		contentStack.orientation = .vertical
		contentStack.alignment = .width
		contentStack.spacing = 14
		contentStack.translatesAutoresizingMaskIntoConstraints = false
		
		contentStack.addArrangedSubview(titleRow)
		items.forEach { item in
			item.translatesAutoresizingMaskIntoConstraints = false
			contentStack.addArrangedSubview(item)
			item.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
			item.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
		}
		
		self.addSubview(contentStack)
		
		NSLayoutConstraint.activate([
			contentStack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
			contentStack.trailingAnchor.constraint(equalTo: self.trailingAnchor),
			contentStack.topAnchor.constraint(equalTo: self.topAnchor),
			contentStack.bottomAnchor.constraint(equalTo: self.bottomAnchor),
			titleRow.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
			titleRow.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor)
		])
	}
	
	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private static func makeSymbolView(named symbolName: String, tintColor: NSColor) -> NSImageView? {
		guard #available(macOS 11.0, *), let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
			return nil
		}
		
		image.isTemplate = true
		
		let imageView = NSImageView(image: image)
		imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
		imageView.contentTintColor = tintColor
		imageView.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			imageView.widthAnchor.constraint(equalToConstant: 18),
			imageView.heightAnchor.constraint(equalToConstant: 18)
		])
		return imageView
	}
}
