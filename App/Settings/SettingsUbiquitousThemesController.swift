//  SettingsUbiquitousThemesController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class SettingsUbiquitousThemesController: TableViewController {
    fileprivate var themes: [Theme] = []
    fileprivate var selectedThemeNames: Set<String> = []
    fileprivate var ignoreSettingsChanges = false
    
    init() {
        super.init(style: .grouped)
        
        title = "Forum-Specific Themes"
        loadData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func loadData() {
        themes = Theme.allThemes.filter { $0.forumID != nil }
        selectedThemeNames = Set(AwfulSettings.shared().ubiquitousThemeNames as? [String] ?? [])
    }
    
    @objc fileprivate func settingsDidChange(_ notification: Notification) {
        guard !ignoreSettingsChanges else { return }
        guard let
            key = (notification as NSNotification).userInfo?[AwfulSettingsDidChangeSettingKey] as? String,
            key == AwfulSettingsKeys.ubiquitousThemeNames.takeUnretainedValue() as String
            else { return }
        loadData()
        
        guard isViewLoaded else { return }
        tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellID)
        tableView.separatorStyle = .none
        
        NotificationCenter.default.addObserver(self, selector: #selector(settingsDidChange), name: NSNotification.Name.AwfulSettingsDidChange, object: nil)
    }
    
    // MARK: UITableViewDataSource and UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return themes.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        let theme = themes[(indexPath as NSIndexPath).row]
        
        cell.textLabel?.text = theme.descriptiveName
        cell.textLabel?.textColor = theme["listTextColor"]
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFontTextStyle.subheadline)
        guard let fontName = (theme["listFontName"] as String?) ?? descriptor.object(forKey: UIFontDescriptorNameAttribute) as? String else {
            fatalError("\(#function) couldn't find font name")
        }
        cell.textLabel?.font = UIFont(name: fontName, size: descriptor.pointSize)
        
        cell.accessoryType = selectedThemeNames.contains(theme.name) ? .checkmark : .none
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.tintColor = theme["listSecondaryTextColor"]
        
        let selectedBackground = cell.selectedBackgroundView ?? UIView()
        selectedBackground.backgroundColor = theme["listSelectedBackgroundColor"]
        cell.selectedBackgroundView = selectedBackground
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Selected themes become available in every forum."
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard let text = tableView.dataSource?.tableView?(tableView, titleForFooterInSection: section) else { return 0 }
        let maxSize = CGSize(width: tableView.bounds.width - 40, height: .greatestFiniteMagnitude)
        let expected = (text as NSString).boundingRect(with: maxSize, options: .usesLineFragmentOrigin, attributes: [NSFontAttributeName: UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote)], context: nil)
        return ceil(expected.height) + 14
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let theme = themes[(indexPath as NSIndexPath).row]
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        if selectedThemeNames.contains(theme.name) {
            selectedThemeNames.remove(theme.name)
            cell.accessoryType = .none
        } else {
            selectedThemeNames.insert(theme.name)
            cell.accessoryType = .checkmark
        }
        
        ignoreSettingsChanges = true
        AwfulSettings.shared().ubiquitousThemeNames = Array(selectedThemeNames)
        ignoreSettingsChanges = false
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let headerView = view as? UITableViewHeaderFooterView else { return }
        headerView.contentView.backgroundColor = theme["listHeaderBackgroundColor"]
    }
    
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let footerView = view as? UITableViewHeaderFooterView else { return }
        footerView.textLabel?.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote)
        footerView.contentView.backgroundColor = theme["listHeaderBackgroundColor"]
    }
}

private let cellID = "Cell"
