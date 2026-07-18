//
//  UpdateCell.swift
//  Latest
//
//  Created by Max Langer on 26.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

/**
 The cell that is used in the list of available updates
 */
class UpdateCell: NSTableCellView {

    // MARK: - Outlets

    /// The label displaying the app name
    @IBOutlet private weak var nameTextField: NSTextField!

    /// The label displaying the current version of the app
    @IBOutlet private weak var currentVersionTextField: NSTextField!

    /// The label displaying the newest version available for the app
    @IBOutlet private weak var newVersionTextField: NSTextField!

    /// The stack view holding the cell’s contents
    @IBOutlet private weak var contentStackView: NSStackView!

    /// Constraints defining the horizontal insets of the cell
    @IBOutlet private weak var leadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var trailingConstraint: NSLayoutConstraint!

    /// Label displaying the last modified/update date for the app
    @IBOutlet private weak var dateTextField: NSTextField!

    /// The button handling the update of the app
    @IBOutlet private weak var updateButton: UpdateButton!

    /// Image view displaying a status indicator for the support status of the app
    @IBOutlet private weak var supportStateImageView: NSImageView!

    // MARK: - View Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()

        if #available(macOS 11.0, *) {
            leadingConstraint.constant = 0
            trailingConstraint.constant = 0
        } else {
            leadingConstraint.constant = 20
            trailingConstraint.constant = 20
        }
    }

    // MARK: - Update Progress

    /// The app represented by this cell
    var app: App? {
        willSet {
            if let app = self.app {
                UpdateQueue.shared.removeObserver(self, for: app.identifier)
            }
        }
        didSet {
            if let app = self.app {
                UpdateQueue.shared.addObserver(self, to: app.identifier) { [weak self] _ in
                    guard let self else { return }
                    self.supportStateImageView.isHidden = !self.showSupportState
                }
            }

            updateButton.app = app
            updateContents()
        }
    }

    var filterQuery: String? {
        didSet {
            if filterQuery != oldValue {
                updateTitle()
            }
        }
    }

    // MARK: - Utilities

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private func updateContents() {
        guard
            let app,
            let versionInformation = app.localizedVersionInformation
        else { return }

        updateTitle()

        currentVersionTextField.stringValue = versionInformation.current
        newVersionTextField.stringValue = versionInformation.new ?? ""
        newVersionTextField.isHidden = !app.updateAvailable
        dateTextField.stringValue = dateFormatter.string(from: app.updateDate)

        supportStateImageView.isHidden = !showSupportState
        if showSupportState {
            supportStateImageView.image = app.source.supportState.statusImage
            supportStateImageView.toolTip = app.source.supportState.label
        }
    }

    /// Whether the status indicator for the app’s support state should be visible
    private var showSupportState: Bool {
        guard let app else { return false }

        let isUpdating = switch UpdateQueue.shared.state(for: app.identifier) {
        case .none, .error: false
        default: true
        }

        return !isUpdating &&
            (AppListSettings.shared.includeAppsWithLimitedSupport ||
             AppListSettings.shared.includeUnsupportedApps)
    }

    private func updateTitle() {
        nameTextField.attributedStringValue =
            app?.highlightedName(for: filterQuery) ?? NSAttributedString()
    }
}
