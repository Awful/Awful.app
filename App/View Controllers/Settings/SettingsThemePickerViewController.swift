//  SettingsThemePickerViewController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class SettingsThemePickerViewController: TableViewController {

    private let forumID: String?
    private let mode: Theme.Mode
    private let settingsKey: String
    private let themes = Theme.allThemes

    init(defaultMode mode: Theme.Mode) {
        forumID = nil
        self.mode = mode

        switch mode {
        case .dark:
            settingsKey = SettingsKeys.defaultDarkTheme
        case .light:
            settingsKey = SettingsKeys.defaultLightTheme
        }

        super.init(style: .plain)
    }

    init(forumID: String, mode: Theme.Mode) {
        self.forumID = forumID
        self.mode = mode
        settingsKey = Theme.defaultsKeyForForum(identifiedBy: forumID, mode: mode)
        super.init(style: .plain)
    }

    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: settingsKey, context: &KVOContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.hideExtraneousSeparators()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        UserDefaults.standard.addObserver(self, forKeyPath: settingsKey, options: [], context: &KVOContext)
    }

    private func setSelectedTheme(name: String?) {
        let newIndexPath = themes
            .firstIndex { $0.name == name }
            .map { IndexPath(row: $0, section: 0) }
        let oldIndexPaths = tableView.visibleCells
            .filter { $0.accessoryType == .checkmark }
            .compactMap { tableView.indexPath(for: $0) }
        tableView.reloadRows(at: [newIndexPath].compactMap { $0 } + oldIndexPaths, with: .none)
    }

    private func fontForRow(at indexPath: IndexPath) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline)
        guard
            let fontName = themes[indexPath.row][string: "listFontName"]
                ?? descriptor.object(forKey: .name) as? String
            else { fatalError("couldn't find font name") }
        return UIFont(name: fontName, size: descriptor.pointSize)!
    }

    // MARK: KVO

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &KVOContext else {
            return super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }

        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.setSelectedTheme(name: UserDefaults.standard.string(forKey: self.settingsKey))
        }
    }

    // MARK: UITableViewDataSource and UITableViewDelegate

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return themes.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let text = themes[indexPath.row].name
        let tableWidth: CGFloat
        if #available(iOS 11.0, *) {
            tableWidth = tableView.safeAreaLayoutGuide.layoutFrame.width
        } else {
            tableWidth = tableView.bounds.width
        }
        let maxSize = CGSize(width: tableWidth - 40, height: .greatestFiniteMagnitude)
        let fittingSize = (text as NSString).boundingRect(with: maxSize, options: .usesLineFragmentOrigin, attributes: [.font: fontForRow(at: indexPath)], context: nil)
        return max(44, floor(fittingSize.height + 16))
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let theme = themes[indexPath.row]

        cell.backgroundColor = theme["listBackgroundColor"]
        cell.textLabel?.textColor = theme["listTextColor"]
        cell.selectedBackgroundColor = theme["listSelectedBackgroundColor"]

        cell.textLabel?.font = fontForRow(at: indexPath)
        cell.textLabel?.text = theme.descriptiveName

        cell.accessoryType = UserDefaults.standard.string(forKey: settingsKey) == theme.name ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if let forumID = forumID {
            Theme.setThemeName(themes[indexPath.row].name, forForumIdentifiedBy: forumID, modes: [mode])
        } else {
            UserDefaults.standard.set(themes[indexPath.row].name, forKey: settingsKey)
        }
    }

    // MARK: - Gunk

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private var KVOContext = 0
