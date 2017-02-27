//
//  ViewController.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

protocol MLMUpdateListViewControllerDelegate : class {
    func startChecking(numberOfApps: Int)
    func didCheckApp()
}

class MLMUpdateListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, MLMAppUpdaterDelegate {

    var apps = [MLMAppUpdater]()
    
    weak var delegate : MLMUpdateListViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        if let cell = tableView.make(withIdentifier: "MLMUpdateCellIdentifier", owner: self) {
            self.tableView.rowHeight = cell.frame.height
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        guard let scrollView = self.tableView.enclosingScrollView else { return }
        
        let topConstraint = NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: self.view.window?.contentLayoutGuide, attribute: .top, multiplier: 1.0, constant: 0.0)
        topConstraint.isActive = true
    }
    
    // MARK: - TableView Stuff
    
    @IBOutlet weak var tableView: NSTableView!
    
    // MARK: Table View Delegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let app = self.apps[row]
        
        guard let cell = tableView.make(withIdentifier: "MLMUpdateCellIdentifier", owner: self) as? MLMUpdateCell,
            let versionBundle = app.currentVersion,
            let version = app.version,
            let newVersion = versionBundle.version,
            let url = app.appURL else {
            return nil
        }
        
        cell.textField?.stringValue = app.appName
        cell.currentVersionTextField?.stringValue = NSLocalizedString("Your version: \(version)", comment: "Current Version String")
        cell.newVersionTextField?.stringValue = NSLocalizedString("New version: \(newVersion)", comment: "New Version String")
        cell.imageView?.image = NSWorkspace.shared().icon(forFile: url.path)
        
        cell.appUrl = url
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let cell = tableView.make(withIdentifier: "MLMUpdateCellIdentifier", owner: self) else {
            return 50
        }
        
        return cell.frame.height
    }
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableRowActionEdge) -> [NSTableViewRowAction] {
        if edge == .trailing {
            let action = NSTableViewRowAction(style: .regular, title: NSLocalizedString("Update", comment: "Update String"), handler: { (action, row) in
                guard let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? MLMUpdateCell,
                let url = cell.appUrl else {
                    return
                }
                
                NSWorkspace.shared().open(url)
            })
            
            action.backgroundColor = NSColor.gray
            
            return [action]
        }
        
        return []
    }
    
    // MARK: Table View Data Source
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.apps.count
    }
    
    // MARK: - Update Checker Delegate
    
    func checkerDidFinishChecking(_ app: MLMAppUpdater) {
        self.delegate?.didCheckApp()
        
        if let versionBundle = app.currentVersion, let currentVersion = app.version, let newVersion = versionBundle.version, currentVersion != newVersion {
            self.apps.append(app)
            self.tableView.reloadData()
            
            NSApplication.shared().dockTile.badgeLabel = NumberFormatter().string(from: self.apps.count as NSNumber)
        }
    }
    
    // MARK: - Private Methods
    
    func checkForUpdates() {
        self.apps = []
        
        let fileManager = FileManager.default
        let applicationURLList = fileManager.urls(for: .applicationDirectory, in: .localDomainMask)
        
        guard applicationURLList.count > 0,
            let applicationURL = applicationURLList.first,
            let apps = try? fileManager.contentsOfDirectory(atPath: applicationURL.path) else { return }
        
        self.delegate?.startChecking(numberOfApps: apps.count)
        
        apps.forEach({ (file) in
            let appName = file as NSString
            
            if appName.pathExtension == "app" {
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
                            let checker = MLMAppUpdater(appName: appName.deletingPathExtension, shortVersion: shortVersionString, version: versionString)
                            
                            parser.delegate = checker
                            checker.delegate = self
                            checker.appURL = applicationURL.appendingPathComponent(file)
                            
                            parser.parse()
                        } else {
                            self.delegate?.didCheckApp()
                        }
                    })
                    
                    task.resume()
                } else {
                    self.delegate?.didCheckApp()
                }
            } else {
                self.delegate?.didCheckApp()
            }
        })
    }
    
}

