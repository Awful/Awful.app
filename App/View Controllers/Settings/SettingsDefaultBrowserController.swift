//  SettingsDefaultBrowserController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class SettingsDefaultBrowserController: TableViewController {
    
    private lazy var installedBrowsers = DefaultBrowser.installedBrowsers
    private var observer: NSKeyValueObservation?
    
    init() {
        super.init(style: .grouped)
        title = LocalizedString("settings.default-browser.title")
    }
    
    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.separatorStyle = .singleLine
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return installedBrowsers.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) 
        let browser = installedBrowsers[indexPath.row]
        cell.textLabel?.text = browser.rawValue
        cell.accessoryType = browser == UserDefaults.standard.defaultBrowser ? .checkmark : .none
        
        let theme = self.theme
        cell.textLabel?.textColor = theme["listTextColor"]
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.selectedBackgroundColor = theme["listSelectedBackgroundColor"]
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footer = UITextView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 50))
        footer.text = "iOS14+ users may set a third party browser as their default system browser via iOS Settings."
        footer.textAlignment = .left
        footer.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        footer.font = UIFont.preferredFontForTextStyle(.footnote, sizeAdjustment: 1, weight: .semibold)
        footer.textColor = theme["listSecondaryTextColor"]
        footer.backgroundColor = theme["listBackgroundColor"]
        footer.isEditable = false
        return footer
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let browser = installedBrowsers[indexPath.row]
        if UserDefaults.standard.defaultBrowser == browser { return }
        
        UserDefaults.standard.defaultBrowser = browser
        
        tableView.indexPathsForVisibleRows?
            .filter { $0 != indexPath }
            .compactMap { tableView.cellForRow(at: $0) }
            .forEach { $0.accessoryType = .none }
        
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
    }
    
    // MARK: Gunk
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private let cellIdentifier = "Cell"
