//
//  ViewController.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

class MLMUpdateListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, MLMAppUpdaterDelegate {

    var apps = [MLMAppUpdater]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        self.checkForUpdates()
    }
    
    // MARK: - TableView Stuff
    
    @IBOutlet weak var tableView: NSTableView!
    
    // MARK: Table View Delegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let app = self.apps[row]
        
        guard let cell = tableView.make(withIdentifier: "MLMUpdateCellIdentifier", owner: self) as? MLMUpdateCell,
            let versionBundle = app.currentVersion,
            let version = app.version,
            let newVersion = versionBundle.version else {
            return nil
        }
        
        cell.textField?.stringValue = app.appName
        cell.currentVersionTextField?.stringValue = NSLocalizedString("Current version: \(version)", comment: "Current Version String")
        cell.newVersionTextField?.stringValue = NSLocalizedString("New version: \(newVersion)", comment: "New Version String")
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let cell = tableView.make(withIdentifier: "MLMUpdateCellIdentifier", owner: self) else {
            return 50
        }
        
        return cell.frame.height
    }
    
    // MARK: Table View Data Source
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.apps.count
    }
    
    // MARK: - Update Checker Delegate
    
    func checkerDidFinishChecking(_ app: MLMAppUpdater) {
        if let versionBundle = app.currentVersion, let currentVersion = app.version, let newVersion = versionBundle.version, currentVersion != newVersion {
            self.apps.append(app)
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Private Methods
    
    func checkForUpdates() {
        let fileManager = FileManager.default
        let applicationURLList = fileManager.urls(for: .applicationDirectory, in: .localDomainMask)
        
        guard applicationURLList.count > 0,
            let applicationURL = applicationURLList.first,
            let apps = try? fileManager.contentsOfDirectory(atPath: applicationURL.path) else { return }
        
        apps.forEach({ (file) in
            if file.contains(".app") {
                let plistPath = applicationURL.appendingPathComponent(file)
                    .appendingPathComponent("Contents")
                    .appendingPathComponent("Info.plist").path
                
                if FileManager.default.fileExists(atPath: plistPath),
                    let plistData = NSDictionary(contentsOfFile: plistPath),
                    let urlString = plistData["SUFeedURL"] as? String,
                    let url = URL(string: urlString) {
                    
                    let session = URLSession(configuration: URLSessionConfiguration.default)
                    
                    let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
                        if error == nil,
                            let xmlData = data {
                            
                            let shortVersionString = plistData["CFBundleShortVersionString"] as? String
                            let versionString = plistData["CFBundleVersion"] as? String
                            
                            let parser = XMLParser(data: xmlData)
                            let checker = MLMAppUpdater(appName: file, shortVersion: shortVersionString, version: versionString)
                            
                            parser.delegate = checker
                            checker.delegate = self
                            
                            parser.parse()
                        }
                    })
                    
                    task.resume()
                }
            }
        })
    }
    
}

