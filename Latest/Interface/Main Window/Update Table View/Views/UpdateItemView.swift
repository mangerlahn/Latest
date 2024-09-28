//
//  UpdateScrubberItemView.swift
//  Latest
//
//  Created by Max Langer on 22.07.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

// Basically adapted from the NSTouchBar Catalog @ https://developer.apple.com/library/archive/samplecode/NSTouchBarCatalog/Introduction/Intro.html

import Cocoa

/// The scubber view holds the applications icon as well as it's name
class UpdateItemView: NSScrubberItemView {

    let imageView = NSImageView()
    
    let textField = NSTextField()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
		// Pass 0 for default siue
		self.textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        self.textField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        self.textField.textColor = NSColor.white

        self.imageView.imageScaling = .scaleProportionallyDown

        self.addSubview(self.imageView)
        self.addSubview(self.textField)
        
        self.setupLayout()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
    
    private func setupLayout() {
        let stackView = NSStackView(views: [imageView, textField])
        
        stackView.orientation = .horizontal
        stackView.spacing = 0
        stackView.alignment = .centerY
        
        self.addSubview(stackView)
        
        let constraints = [
            stackView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0),
            stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 0),
            stackView.topAnchor.constraint(equalTo: self.topAnchor, constant: 0),
            stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 1.0),
            imageView.widthAnchor.constraint(equalToConstant: 20),
            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 5),
            textField.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: 1)
        ]
        
        NSLayoutConstraint.activate(constraints)
    }
    
    
}
