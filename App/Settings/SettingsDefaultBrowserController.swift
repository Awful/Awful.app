//  SettingsDefaultBrowserController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class SettingsDefaultBrowserController: TableViewController {
    fileprivate var selectedIndexPath: IndexPath = selectedBrowserIndexPath()
    
    init() {
        super.init(style: .grouped)
        title = "Default Browser"
    }
    
    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.separatorStyle = .singleLine
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AwfulDefaultBrowsers().count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) 
        let browsers = AwfulDefaultBrowsers() as! [String]
        let thisBrowser = browsers[(indexPath as NSIndexPath).row]
        cell.textLabel?.text = thisBrowser
        cell.accessoryType = thisBrowser == AwfulSettings.shared().defaultBrowser ? .checkmark : .none
        
        let theme = self.theme
        cell.textLabel?.textColor = theme["listTextColor"]
        cell.backgroundColor = theme["listBackgroundColor"]
        if cell.selectedBackgroundView == nil {
            cell.selectedBackgroundView = UIView()
        }
        cell.selectedBackgroundView!.backgroundColor = theme["listSelectedBackgroundColor"]
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath == selectedIndexPath {
            return
        }
        
        AwfulSettings.shared().defaultBrowser = (AwfulDefaultBrowsers() as! [String])[(indexPath as NSIndexPath).row]
        
        tableView.cellForRow(at: selectedIndexPath)?.accessoryType = .none
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        
        selectedIndexPath = indexPath
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

private let cellIdentifier = "Cell"

private func selectedBrowserIndexPath() -> IndexPath {
    let row = (AwfulDefaultBrowsers() as! [String]).index(of: AwfulSettings.shared().defaultBrowser)!
    return IndexPath(row: row, section: 0)
}
