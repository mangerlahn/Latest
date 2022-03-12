//
//  ReleaseNotesProvider.swift
//  Latest
//
//  Created by Max Langer on 04.03.22.
//  Copyright © 2022 Max Langer. All rights reserved.
//

/// Handles release notes conversion and loading.
///
/// The object provides release notes in a uniform representation and caches remote contents for faster access.
class ReleaseNotesProvider {
	
	/// The return value, containing either the desired release notes, or an error if unavailable.
	typealias ReleaseNotes = Result<NSAttributedString, Error>
	
	/// Initializes the provider.
	init() {
		self.cache = NSCache()
	}
	
	/// Provides release notes for the given app.
	func releaseNotes(for app: App, with completion: @escaping (ReleaseNotes) -> Void) {
		if let releaseNotes = self.cache.object(forKey: app) {
			completion(.success(releaseNotes))
			return
		}

		self.loadReleaseNotes(for: app) { releaseNotes in
			if case .success(let text) = releaseNotes {
				self.cache.setObject(text, forKey: app)
			}
			
			completion(releaseNotes)
		}
	}
	
	
	// MARK: - Release Notes Handling
	
	/// The cache for release notes content.
	///
	/// All content is cached, since any given release notes object requires some sort of modification.
	private var cache: NSCache<App, NSAttributedString>
	
	private func loadReleaseNotes(for app: App, with completion: @escaping (ReleaseNotes) -> Void) {
		if let releaseNotes = app.releaseNotes {
			switch releaseNotes {
				case .html(let html):
					completion(self.releaseNotes(from: html))
				case .url(let url):
					self.releaseNotes(from: url, with: completion)
				case .encoded(let data):
					completion(self.releaseNotes(from: data))
			}
		} else if let error = app.error {
			completion(.failure(error))
		} else {
			completion(.failure(LatestError.releaseNotesUnavailable))
		}
	}
	
	/// Fetches release notes from the given URL.
	private func releaseNotes(from url: URL, with completion: @escaping (ReleaseNotes) -> Void) {
		let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
			DispatchQueue.main.async {
				if let data = data, !data.isEmpty {
					completion(self.releaseNotes(from: data))
				} else if let error = error {
					completion(.failure(error))
				}
			}
		}
		
		task.resume()
	}
	
	/// Returns rich text from the given HTML string.
	private func releaseNotes(from html: String) -> ReleaseNotes {
		guard let data = html.data(using: .utf16),
				let string = NSAttributedString(html: data, documentAttributes: nil) else {
					return .failure(LatestError.releaseNotesUnavailable)
		}
		
		return .success(string)
	}

	/// Extracts release notes from the given data.
	private func releaseNotes(from data: Data) -> ReleaseNotes {
		var options : [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: NSAttributedString.DocumentType.html]
		
		var string: NSAttributedString
		do {
			string = try NSAttributedString(data: data, options: options, documentAttributes: nil)
		} catch let error {
			return .failure(error)
		}

		// Having only one line means that the text was no HTML but plain text. Therefore we reinstantiate the attributed string as plain text
		// The initialization with HTML enabled removes all new lines
		// If anyone has a better idea for checking if the data is valid HTML or plain text, feel free to fix.
		if string.string.split(separator: "\n").count == 1 {
			options[.documentType] = NSAttributedString.DocumentType.plain
			
			do {
				string = try NSAttributedString(data: data, options: options, documentAttributes: nil)
			} catch let error {
				return .failure(error)
			}
		}
		
		return .success(string)
	}

}
