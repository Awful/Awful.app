//  SettingsDefaultBrowserController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class SettingsDefaultBrowserController: AwfulTableViewController {
    private var selectedIndexPath: NSIndexPath = selectedBrowserIndexPath()
    
    init() {
        super.init(style: .Grouped)
        title = "Default Browser"
    }
    
    override init(nibName: String?, bundle: NSBundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.separatorStyle = .SingleLine
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AwfulDefaultBrowsers().count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! UITableViewCell
        let browsers = AwfulDefaultBrowsers() as! [String]
        let thisBrowser = browsers[indexPath.row]
        cell.textLabel?.text = thisBrowser
        cell.accessoryType = thisBrowser == AwfulSettings.sharedSettings().defaultBrowser ? .Checkmark : .None
        
        let theme = self.theme
        cell.textLabel?.textColor = theme["listTextColor"]
        cell.backgroundColor = theme["listBackgroundColor"]
        if cell.selectedBackgroundView == nil {
            cell.selectedBackgroundView = UIView()
        }
        cell.selectedBackgroundView.backgroundColor = theme["listSelectedBackgroundColor"]
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath == selectedIndexPath {
            return
        }
        
        AwfulSettings.sharedSettings().defaultBrowser = (AwfulDefaultBrowsers() as! [String])[indexPath.row]
        
        tableView.cellForRowAtIndexPath(selectedIndexPath)?.accessoryType = .None
        tableView.cellForRowAtIndexPath(indexPath)?.accessoryType = .Checkmark
        
        selectedIndexPath = indexPath
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}

private let cellIdentifier = "Cell"

private func selectedBrowserIndexPath() -> NSIndexPath {
    let row = find(AwfulDefaultBrowsers() as! [String], AwfulSettings.sharedSettings().defaultBrowser)!
    return NSIndexPath(forRow: row, inSection: 0)
}
