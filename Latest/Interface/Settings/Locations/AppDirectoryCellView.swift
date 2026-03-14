//
//  AppDirectoryCellView.swift
//  Latest
//
//  Created by Max Langer on 29.02.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import Cocoa

/// View that holds a single location checked for updates.
class AppDirectoryCellView: NSTableCellView {
	
	private let backgroundContainerView = NSView()
	private let iconContainerView = NSView()
	private let titleLabel = NSTextField(labelWithString: "")
	private let subtitleLabel = NSTextField(labelWithString: "")
	private let iconImageView = NSImageView()
	private let appCountBadgeView = NSView()
	private let appCountLabel = NSTextField(labelWithString: "")
	private let activityIndicator = NSProgressIndicator()
	private let removeButton = NSButton(title: "", target: nil, action: nil)
	private let trailingActionContainer = NSView()
	
	var onRemove: ((URL) -> Void)?
	
	var isDefaultLocation: Bool = false {
		didSet {
			self.updateSubtitle()
		}
	}
	
	var canRemove: Bool = false {
		didSet {
			self.updateRemoveButton()
			self.updateSubtitle()
		}
	}
	
	/// The URL to be displayed by the cell.
	var url: URL? {
		didSet {
			guard url != oldValue else { return }
			
			isReachable = (try? url?.checkResourceIsReachable()) == true
			setUpView()
		}
	}
	
	var isReachable: Bool = false
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		self.setUpLayout()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		self.setUpLayout()
	}
	
	private func setUpView() {
		guard let url else {
			titleLabel.stringValue = ""
			subtitleLabel.stringValue = ""
			iconImageView.image = nil
			appCountBadgeView.isHidden = true
			activityIndicator.stopAnimation(nil)
			return
		}
		
		titleLabel.stringValue = FileManager.default.displayName(atPath: url.path)
		titleLabel.textColor = tintColor
		titleLabel.toolTip = url.path
		self.updateSubtitle()
		
		iconImageView.image = icon
		iconContainerView.layer?.backgroundColor = (isReachable ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.quaternaryLabelColor.withAlphaComponent(0.18)).cgColor
		backgroundContainerView.layer?.borderColor = (isReachable ? NSColor.separatorColor.withAlphaComponent(0.3) : NSColor.systemOrange.withAlphaComponent(0.35)).cgColor
		self.updateRemoveButton()
		
		activityIndicator.stopAnimation(nil)
		activityIndicator.startAnimation(nil)
		appCountBadgeView.isHidden = false
		appCountLabel.stringValue = "..."
		appCountLabel.textColor = .secondaryLabelColor
		
		guard isReachable else {
			activityIndicator.stopAnimation(nil)
			appCountLabel.stringValue = "-"
			return
		}
		
		let expectedURL = url
		DispatchQueue.global().async {
			let count = BundleCollector.collectBundles(at: url).count
			DispatchQueue.main.async {
				guard self.url == expectedURL else {
					return
				}
				
				self.activityIndicator.stopAnimation(nil)
				self.appCountLabel.stringValue = NumberFormatter.localizedString(from: NSNumber(value: count), number: .none)
				self.appCountLabel.textColor = .labelColor
			}
		}
	}
	
	private var tintColor: NSColor {
		isReachable ? .labelColor : .secondaryLabelColor
	}
	
	private var icon: NSImage {
		if isReachable {
			guard let url else { return NSImage() }
			return NSWorkspace.shared.icon(forFile: url.relativePath)
		}
		
		return if #available(macOS 11.0, *) {
			NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "")!
		} else {
			NSImage(named: .init("NSCaution"))!
		}
	}
	
	@objc private func removeDirectory(_ sender: Any?) {
		guard let url, canRemove else {
			return
		}
		
		self.onRemove?(url)
	}
	
	private func updateRemoveButton() {
		removeButton.isHidden = false
		removeButton.isEnabled = canRemove
		removeButton.alphaValue = canRemove ? 1 : 0
	}
	
	private func updateSubtitle() {
		guard let url else {
			subtitleLabel.stringValue = ""
			return
		}
		
		let locationDescription = isDefaultLocation
			? NSLocalizedString("Standard folder", comment: "Location row subtitle for a default folder.")
			: NSLocalizedString("Custom folder", comment: "Location row subtitle for a user-added folder.")
		let availabilityDescription = isReachable
			? url.path
			: String.localizedStringWithFormat(
				NSLocalizedString("%@ • Not available right now", comment: "Location row subtitle for an unavailable folder. The placeholder is the folder path."),
				url.path
			)
		
		subtitleLabel.stringValue = "\(locationDescription) • \(availabilityDescription)"
		subtitleLabel.textColor = .secondaryLabelColor
		subtitleLabel.toolTip = url.path
	}
	
	private func setUpLayout() {
		self.wantsLayer = true
		
		backgroundContainerView.wantsLayer = true
		backgroundContainerView.layer?.cornerRadius = 12
		backgroundContainerView.layer?.cornerCurve = .continuous
		backgroundContainerView.layer?.borderWidth = 1
		backgroundContainerView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.75).cgColor
		backgroundContainerView.translatesAutoresizingMaskIntoConstraints = false
		
		let rowStackView = NSStackView()
		rowStackView.orientation = .horizontal
		rowStackView.alignment = .centerY
		rowStackView.spacing = 12
		rowStackView.translatesAutoresizingMaskIntoConstraints = false
		
		let textStackView = NSStackView()
		textStackView.orientation = .vertical
		textStackView.alignment = .leading
		textStackView.spacing = 2
		textStackView.translatesAutoresizingMaskIntoConstraints = false
		
		iconContainerView.wantsLayer = true
		iconContainerView.layer?.cornerRadius = 10
		iconContainerView.layer?.cornerCurve = .continuous
		iconContainerView.translatesAutoresizingMaskIntoConstraints = false
		
		iconImageView.translatesAutoresizingMaskIntoConstraints = false
		iconImageView.imageScaling = .scaleProportionallyDown
		iconImageView.setContentHuggingPriority(.required, for: .horizontal)
		
		titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
		titleLabel.lineBreakMode = .byTruncatingMiddle
		titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		
		subtitleLabel.lineBreakMode = .byTruncatingMiddle
		subtitleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
		subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		
		activityIndicator.controlSize = .small
		activityIndicator.style = .spinning
		activityIndicator.isDisplayedWhenStopped = false
		activityIndicator.translatesAutoresizingMaskIntoConstraints = false
		
		appCountBadgeView.wantsLayer = true
		appCountBadgeView.layer?.cornerRadius = 9
		appCountBadgeView.layer?.cornerCurve = .continuous
		appCountBadgeView.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.16).cgColor
		appCountBadgeView.translatesAutoresizingMaskIntoConstraints = false
		
		appCountLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
		appCountLabel.alignment = .center
		appCountLabel.setContentHuggingPriority(.required, for: .horizontal)
		appCountLabel.translatesAutoresizingMaskIntoConstraints = false
		
		trailingActionContainer.translatesAutoresizingMaskIntoConstraints = false
		
		removeButton.bezelStyle = .texturedRounded
		removeButton.isBordered = false
		removeButton.imagePosition = .imageOnly
		removeButton.contentTintColor = .secondaryLabelColor
		removeButton.target = self
		removeButton.action = #selector(removeDirectory(_:))
		removeButton.toolTip = NSLocalizedString("Remove folder from scan list", comment: "Tooltip for removing a folder from the locations list.")
		removeButton.translatesAutoresizingMaskIntoConstraints = false
		if #available(macOS 11.0, *) {
			removeButton.image = NSImage(systemSymbolName: "minus.circle.fill", accessibilityDescription: removeButton.toolTip)
		} else {
			removeButton.title = NSLocalizedString("Remove", comment: "Button title for removing a custom folder from the locations list.")
		}
		
		iconContainerView.addSubview(iconImageView)
		textStackView.addArrangedSubview(titleLabel)
		textStackView.addArrangedSubview(subtitleLabel)
		appCountBadgeView.addSubview(appCountLabel)
		trailingActionContainer.addSubview(removeButton)
		
		rowStackView.addArrangedSubview(iconContainerView)
		rowStackView.addArrangedSubview(textStackView)
		rowStackView.addArrangedSubview(NSView())
		rowStackView.addArrangedSubview(activityIndicator)
		rowStackView.addArrangedSubview(appCountBadgeView)
		rowStackView.addArrangedSubview(trailingActionContainer)
		
		self.addSubview(backgroundContainerView)
		backgroundContainerView.addSubview(rowStackView)
		
		NSLayoutConstraint.activate([
			backgroundContainerView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 2),
			backgroundContainerView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -2),
			backgroundContainerView.topAnchor.constraint(equalTo: self.topAnchor, constant: 2),
			backgroundContainerView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -2),
			rowStackView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor, constant: 14),
			rowStackView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor, constant: -14),
			rowStackView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor, constant: 10),
			rowStackView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor, constant: -10),
			iconContainerView.widthAnchor.constraint(equalToConstant: 36),
			iconContainerView.heightAnchor.constraint(equalToConstant: 36),
			iconImageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
			iconImageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
			iconImageView.widthAnchor.constraint(equalToConstant: 20),
			iconImageView.heightAnchor.constraint(equalToConstant: 20),
			activityIndicator.widthAnchor.constraint(equalToConstant: 16),
			activityIndicator.heightAnchor.constraint(equalToConstant: 16),
			appCountBadgeView.widthAnchor.constraint(equalToConstant: 44),
			appCountBadgeView.heightAnchor.constraint(equalToConstant: 24),
			appCountLabel.centerXAnchor.constraint(equalTo: appCountBadgeView.centerXAnchor),
			appCountLabel.centerYAnchor.constraint(equalTo: appCountBadgeView.centerYAnchor),
			trailingActionContainer.widthAnchor.constraint(equalToConstant: 24),
			removeButton.centerXAnchor.constraint(equalTo: trailingActionContainer.centerXAnchor),
			removeButton.centerYAnchor.constraint(equalTo: trailingActionContainer.centerYAnchor)
		])
		
		appCountBadgeView.isHidden = true
	}
}
