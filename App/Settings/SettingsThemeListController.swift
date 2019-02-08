//  SettingsThemeListControllerTableViewController.swift
//
//  Copyright © 2019 Awful Contributors. All rights reserved.

import UIKit

class SettingsThemeListController: TableViewController {
    
    private let cellID = "Cell"
    
    fileprivate var themes: [Theme] = []
    
    init() {
        super.init(style: .grouped)
        
        title = "Select Theme"
        loadData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellID)
        tableView.separatorStyle = .none
    }
    
    fileprivate func loadData() {
        themes = Theme.allThemes
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return themes.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        
        let theme = themes[(indexPath as NSIndexPath).row]
        cell.textLabel?.text = theme.descriptiveName
        cell.textLabel?.textColor = theme["listTextColor"]
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFont.TextStyle.subheadline)
        guard let fontName = (theme["listFontName"] as String?) ?? descriptor.object(forKey: .name) as? String else {
            fatalError("\(#function) couldn't find font name")
        }
        
        cell.textLabel?.font = UIFont(name: fontName, size: descriptor.pointSize)
        
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.tintColor = theme["listSecondaryTextColor"]

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        if (cell.accessoryType == .none) {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
    }

}
