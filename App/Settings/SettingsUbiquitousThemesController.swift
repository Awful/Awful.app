//  SettingsUbiquitousThemesController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class SettingsUbiquitousThemesController: TableViewController {
    private var themes: [Theme] = []
    private var selectedThemeNames: Set<String> = []
    private var ignoreSettingsChanges = false
    
    init() {
        super.init(style: .Grouped)
        
        title = "Forum-Specific Themes"
        loadData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func loadData() {
        themes = Theme.allThemes.filter { $0.forumID != nil }
        selectedThemeNames = Set(AwfulSettings.sharedSettings().ubiquitousThemeNames as? [String] ?? [])
    }
    
    @objc private func settingsDidChange(notification: NSNotification) {
        guard !ignoreSettingsChanges else { return }
        guard let
            key = notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? String
            where key == AwfulSettingsKeys.ubiquitousThemeNames.takeUnretainedValue()
            else { return }
        loadData()
        
        guard isViewLoaded() else { return }
        tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellID)
        tableView.separatorStyle = .None
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(settingsDidChange), name: AwfulSettingsDidChangeNotification, object: nil)
    }
    
    // MARK: UITableViewDataSource and UITableViewDelegate
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return themes.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellID, forIndexPath: indexPath)
        let theme = themes[indexPath.row]
        
        cell.textLabel?.text = theme.descriptiveName
        cell.textLabel?.textColor = theme["listTextColor"]
        let descriptor = UIFontDescriptor.preferredFontDescriptorWithTextStyle(UIFontTextStyleSubheadline)
        guard let fontName = (theme["listFontName"] as String?) ?? descriptor.objectForKey(UIFontDescriptorNameAttribute) as? String else {
            fatalError("\(#function) couldn't find font name")
        }
        cell.textLabel?.font = UIFont(name: fontName, size: descriptor.pointSize)
        
        cell.accessoryType = selectedThemeNames.contains(theme.name) ? .Checkmark : .None
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.tintColor = theme["listSecondaryTextColor"]
        
        let selectedBackground = cell.selectedBackgroundView ?? UIView()
        selectedBackground.backgroundColor = theme["listSelectedBackgroundColor"]
        cell.selectedBackgroundView = selectedBackground
        
        return cell
    }
    
    override func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Selected themes become available in every forum."
    }
    
    override func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard let text = tableView.dataSource?.tableView?(tableView, titleForFooterInSection: section) else { return 0 }
        let maxSize = CGSizeMake(tableView.bounds.width - 40, .max)
        let expected = (text as NSString).boundingRectWithSize(maxSize, options: .UsesLineFragmentOrigin, attributes: [NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)], context: nil)
        return ceil(expected.height) + 14
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        let theme = themes[indexPath.row]
        guard let cell = tableView.cellForRowAtIndexPath(indexPath) else { return }
        if selectedThemeNames.contains(theme.name) {
            selectedThemeNames.remove(theme.name)
            cell.accessoryType = .None
        } else {
            selectedThemeNames.insert(theme.name)
            cell.accessoryType = .Checkmark
        }
        
        ignoreSettingsChanges = true
        AwfulSettings.sharedSettings().ubiquitousThemeNames = Array(selectedThemeNames)
        ignoreSettingsChanges = false
    }
    
    override func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let headerView = view as? UITableViewHeaderFooterView else { return }
        headerView.contentView.backgroundColor = theme["listHeaderBackgroundColor"]
    }
    
    override func tableView(tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let footerView = view as? UITableViewHeaderFooterView else { return }
        footerView.textLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
        footerView.contentView.backgroundColor = theme["listHeaderBackgroundColor"]
    }
}

private let cellID = "Cell"
