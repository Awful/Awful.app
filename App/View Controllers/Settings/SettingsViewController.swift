//  SettingsViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import CoreData
import SwiftUI

private let Log = Logger.get()

final class SettingsViewController: TableViewController {
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    @FoilDefaultStorageOptional(Settings.userID) private var loggedInUserID
    @FoilDefaultStorageOptional(Settings.username) private var loggedInUsername
    fileprivate let managedObjectContext: NSManagedObjectContext
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(style: .grouped)
        
        title = "Settings"
        
        tabBarItem.image = UIImage(named: "cog")
        tabBarItem.selectedImage = UIImage(named: "cog-filled")
        themeDidChange()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate let sections = { () -> [[String: Any]] in
        // For settings purposes, we consider devices with a regular horizontal size class in landscape to be iPads. This includes iPads and the iPhones Plus.
        let currentDevice = { () -> String in
            // Can't think of a way to actually test for "is horizontal regular in landscape orientation", so we'll use a display scale of 3x as a proxy.
            if UIDevice.current.userInterfaceIdiom == .pad || UIScreen.main.scale > 2 {
                return "iPad"
            }
            else {
                return "iPhone"
            }
        }()

        let sections = SettingsSection.bundled

        func validSection(_ section: SettingsSection) -> Bool {
            if let device = section.device, !device.hasPrefix(currentDevice) {
                return false
            }

            if section.requiresSupportsAlternateAppIcons == true {
                return UIApplication.shared.supportsAlternateIcons
            }

            if !section.visibleInSettingsTab {
                return false
            }
            
            return true
        }
        
        return sections.lazy
            .filter(validSection)
            .map { section -> [String: Any] in
                guard let settings = section.info["Settings"] as? [[String: Any]] else { return section.info }
                var section = section.info
                
                section["Settings"] = settings.filter { setting in
                    if let device = setting["Device"] as? String, !device.hasPrefix(currentDevice) || device == "iPad-only", UIDevice.current.userInterfaceIdiom != .pad {
                        return false
                    }

                    if
                        let urlString = setting["CanOpenURL"] as? String,
                        let url = URL(string: urlString)
                    {
                        return UIApplication.shared.canOpenURL(url)
                    }

                    return true
                }
                return section
        }
    }()
    
    private var loggedInUser: User? {
        loggedInUserID
            .map { UserKey(userID: $0, username: loggedInUsername) }
            .flatMap { User.objectForKey(objectKey: $0, in: managedObjectContext) }
    }
    
    fileprivate func refreshIfNecessary() {
        guard RefreshMinder.sharedMinder.shouldRefresh(.loggedInUser) else { return }
        Task {
            do {
                let user = try await ForumsClient.shared.profileLoggedInUser()
                RefreshMinder.sharedMinder.didRefresh(.loggedInUser)

                canSendPrivateMessages = user.canReceivePrivateMessages
                loggedInUserID = user.userID
                loggedInUsername = user.username

                tableView.reloadData()
            } catch {
                Log.i("failed refreshing user info: \(error)")
            }
        }
    }

    fileprivate func setting(at indexPath: IndexPath) -> [String: AnyObject] {
        guard let settings = sections[(indexPath as NSIndexPath).section]["Settings"] as? [[String: AnyObject]] else { fatalError("wrong settings type") }
        return settings[(indexPath as NSIndexPath).row]
    }
    
    @objc private func showProfile() {
        guard let loggedInUser = loggedInUser else {
            Log.e("expected to have a logged-in user")
            return
        }
        
        let profileVC = ProfileViewController(user: loggedInUser)
        present(profileVC.enclosingNavigationController, animated: true, completion: nil)
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        registerTransformers()
        
        tableView.separatorStyle = .singleLine
        tableView.register(UINib(nibName: "SettingsSliderCell", bundle: Bundle(for: SettingsViewController.self)), forCellReuseIdentifier: SettingType.Slider.cellIdentifier)
        tableView.register(UINib(nibName: "AppIconPickerCell", bundle: Bundle(for: SettingsViewController.self)), forCellReuseIdentifier: SettingType.AppIconPicker.cellIdentifier)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        refreshIfNecessary()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tableView.reloadData()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        Log.d("hello")

        coordinator.animate(alongsideTransition: nil) { (context) in
            self.tableView.reloadData()
        }
    }
    
    // MARK: Table view
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let settings = sections[section]["Settings"] as? [[String: AnyObject]] else { return 0 }
        return settings.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let setting = self.setting(at: indexPath)
        if let typeString = setting["Type"] as? String, typeString == "AppIconPicker" {
            return 120
        } else {
            return 44
        }
    }
    
    fileprivate enum SettingType: String {
        case Immutable = "ImmutableSetting"
        case OnOff = "Switch"
        case Button = "Action"
        case Stepper = "Stepper"
        case Disclosure = "Disclosure"
        case DisclosureDetail = "DisclosureDetail"
        case Slider = "Slider"
        case AppIconPicker = "AppIconPicker"
        
        var cellStyle: UITableViewCell.CellStyle {
            switch self {
            case .OnOff, .Button, .Disclosure, .Slider, .AppIconPicker:
                return .default
                
            case .Immutable, .Stepper, .DisclosureDetail:
                return .value1
            }
        }
        
        var cellIdentifier: String {
            return rawValue
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let setting = self.setting(at: indexPath)
        let settingType: SettingType
        if let typeString = setting["Type"] as? String , typeString == "Switch" {
            settingType = .OnOff
        } else if let action = setting["Action"] as? String , action != "ShowProfile" {
            settingType = .Button
        } else if let typeString = setting["Type"] as? String , typeString == "Stepper" {
            settingType = .Stepper
        } else if setting["ViewController"] != nil {
            if setting["ShowValue"] as? Bool == true {
                settingType = .DisclosureDetail
            } else {
                settingType = .Disclosure
            }
        } else if let typeString = setting["Type"] as? String, typeString == "Slider" {
            settingType = .Slider
        } else if let typeString = setting["Type"] as? String, typeString == "AppIconPicker" {
            settingType = .AppIconPicker
        } else {
            settingType = .Immutable
        }
        
        let cell: UITableViewCell
        if let dequeued = tableView.dequeueReusableCell(withIdentifier: settingType.cellIdentifier) {
            cell = dequeued
        } else if settingType == .Slider {
            cell = SettingsSliderCell(style:settingType.cellStyle, reuseIdentifier: settingType.cellIdentifier)
        } else {
            cell = UITableViewCell(style: settingType.cellStyle, reuseIdentifier: settingType.cellIdentifier)
            switch settingType {
            case .OnOff:
                cell.accessoryView = UISwitch()
                
            case .Disclosure, .DisclosureDetail:
                cell.accessoryType = .disclosureIndicator
                cell.accessibilityTraits.insert(UIAccessibilityTraits.button)
                
            case .Stepper:
                cell.accessoryView = UIStepper()
                
            case .Button where setting["ThreadID"] != nil:
                cell.accessibilityTraits.insert(UIAccessibilityTraits.button)
                cell.accessoryType = .disclosureIndicator
                
            case .Button:
                cell.accessibilityTraits.insert(UIAccessibilityTraits.button)
                cell.accessoryType = .none

            case .AppIconPicker:
                assertionFailure("Please register the AppIconPickerTableViewCell nib with the table view")
                
            case .Immutable, .Slider:
                break
            }
        }
        if settingType.cellStyle == .value1 {
            cell.detailTextLabel?.textColor = UIColor.gray
        }
        
        if setting["ShowValue"] as? Bool == true {
            cell.textLabel?.text = setting["Title"] as? String
            guard let key = setting["Key"] as? String else { fatalError("expected a key for setting \(setting)") }
            let value = UserDefaults.standard.string(forKey: key)
            if
                let transformerName = setting["ValueTransformer"] as? String,
                let transformer = ValueTransformer(forName: NSValueTransformerName(rawValue: transformerName))
            {
                cell.detailTextLabel?.text = transformer.transformedValue(value) as? String
            } else {
                cell.detailTextLabel?.text = value
            }
        } else {
            if settingType != .Slider {
                cell.textLabel?.text = setting["Title"] as? String
            }
        }
        
        if settingType == .Immutable, let valueID = setting["ValueIdentifier"] as? String , valueID == "Username" {
            cell.detailTextLabel?.text = loggedInUsername
        }
        
        if settingType == .OnOff {
            guard let switchView = cell.accessoryView as? UISwitch else { fatalError("setting should have a UISwitch accessory") }
            switchView.awful_setting = setting["Key"] as? String
            
            // Add overriding settings
            if switchView.awful_setting == Settings.darkMode.key {
                switchView.addAwful_overridingSetting(Settings.darkMode.key)
            }
            else {
                switchView.isEnabled = true
            }
        }
        
        if settingType == .Stepper {
            guard let stepper = cell.accessoryView as? UIStepper else { fatalError("setting should have a UIStepper accessory") }
            stepper.awful_setting = setting["Key"] as? String
            cell.textLabel?.awful_setting = setting["Key"] as? String
            cell.textLabel?.awful_settingFormatString = setting["Title"] as? String
        }
        
        if settingType == .Slider {
            guard let slider = (cell as! SettingsSliderCell).slider as UISlider? else { fatalError("setting should have a UISlider accessory") }
            slider.awful_setting = setting["Key"] as? String
        }
        
        if settingType == .AppIconPicker {
            if #available(iOS 16, *) {
                cell.contentConfiguration = UIHostingConfiguration {
                    ScrollView(.horizontal) {
                        HStack {
                            let appIcons: [AppIcon] = findAppIcons()
                            ForEach(appIcons, id: \.iconName) { icon in
                                Button(action: {
                                    if icon.iconName == "AppIcon" {
                                        UIApplication.shared.setAlternateIconName(nil)
                                    } else {
                                        UIApplication.shared.setAlternateIconName(icon.iconName)
                                    }
                                }){
                                    Image("\(icon.iconName)Image")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(idealWidth: 55, idealHeight: 55)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        }
                        .padding(.bottom)
                    }
                }
            } else {
                guard let collection = (cell as! AppIconPickerCell).collectionView else { fatalError("setting should have collection view") }
                collection.awful_setting = setting["Key"] as? String
                collection.backgroundColor = theme["listBackgroundColor"]
            }
        }
        switch settingType {
        case .Button, .Disclosure, .DisclosureDetail:
            cell.selectionStyle = .blue
            
        case .Immutable, .OnOff, .Stepper, .AppIconPicker:
            cell.selectionStyle = .none
            
        case .Slider:
            cell.selectionStyle = .none
            let slider = (cell as! SettingsSliderCell)
            slider.setImageColor(theme["listTextColor"]!)
            
        }
        
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.textLabel?.textColor = theme["listTextColor"]
        cell.textLabel?.font = UIFont.preferredFontForTextStyle(.body, fontName: theme["listFontName"], weight: .regular)
        
        cell.selectedBackgroundColor = theme["listSelectedBackgroundColor"]
        
        if let switchView = cell.accessoryView as? UISwitch {
            switchView.onTintColor = theme["settingsSwitchColor"]
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let ok = ["Action", "Choices", "ViewController"]
        if let _ = setting(at: indexPath).keys.firstIndex(where: ok.contains) {
            return indexPath
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }

        let setting = self.setting(at: indexPath)
        switch (setting["Action"] as? String, setting["ViewController"] as? String) {
        case ("LogOut"?, _):
            let alert = UIAlertController(title: "Log Out", message: "Are you sure you want to log out?", alertActions: [
                .cancel(),
                .default(title: "Log Out", handler: AppDelegate.instance.logOut),
            ])
            present(alert, animated: true)
            
        case ("EmptyCache"?, _):
            let usageBefore = URLCache.shared.currentDiskUsage
            AppDelegate.instance.emptyCache();
            let usageAfter = URLCache.shared.currentDiskUsage
            let message = "You cleared up \((usageBefore - usageAfter)/(1024*1024)) megabytes! Great job, go hog wild!!"
            let alertController = UIAlertController(title: "Cache Cleared", message: message, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { action in
                self.dismiss(animated: true)
            }
            alertController.addAction(okAction)
            self.present(alertController, animated: true)
            
        case ("GoToAwfulThread"?, _):
            guard let threadID = setting["ThreadID"] as? String else {
                fatalError("setting \(setting) needs a ThreadID")
            }

            AppDelegate.instance.open(route: .threadPage(threadID: threadID, page: .nextUnread, .seen))

        case (_, "theme-picker"):
            let mode: Theme.Mode
            switch setting["Key"] as! String {
            case Settings.defaultDarkThemeName.key:
                mode = .dark
            case Settings.defaultLightThemeName.key:
                mode = .light
            default:
                fatalError("unknown default theme key \(setting["Key"] as Any)")
            }
            let vc = SettingsThemePickerViewController(defaultMode: mode)
            vc.title = setting["Title"] as! String?
            navigationController?.pushViewController(vc, animated: true)

        case (_, "forum-specific-themes"):
            let vc = SettingsForumSpecificThemesViewController(context: managedObjectContext)
            vc.title = setting["Title"] as? String
            navigationController?.pushViewController(vc, animated: true)
            
        case (_, let vcTypeName?):
            guard let vcType = NSClassFromString(vcTypeName) as? UIViewController.Type else { fatalError("couldn't find type named \(vcTypeName)") }
            let vc = vcType.init()
            if vc.modalPresentationStyle == .formSheet && UIDevice.current.userInterfaceIdiom == .pad {
                present(vc.enclosingNavigationController, animated: true, completion: nil)
            } else {
                navigationController?.pushViewController(vc, animated: true)
            }
            
        case (let action?, _):
            fatalError("unknown setting action \(action)")
            
        default:
            fatalError("don't know how to handle selected setting \(setting)")
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection sectionIndex: Int) -> UIView? {
        let section = sections[sectionIndex]
        
        if let action = section["Action"] as? String, action == "ShowProfile" {
            let avatarHeader = SettingsAvatarHeader.newFromNib()
            avatarHeader.setTarget(self, action: #selector(showProfile))
            avatarHeader.configure(
                avatarURL: loggedInUser?.avatarURL,
                horizontalPadding: tableView.separatorInset.left,
                textColor: theme["listTextColor"])
            return avatarHeader
        }
        
        guard let title = section["Title"] as? String else { return nil }
        
        var cellTitleText = title
        
        if let title = section["TitleKey"] as? String, title == "username" {
            cellTitleText = loggedInUsername ?? "Not logged in??"
        }
        
        if title == "Awful x.y.z" {
            var components = [Bundle.main.localizedName, Bundle.main.shortVersionString]
            if Environment.isDebugBuild || Environment.isSimulator || Environment.isInstalledViaTestFlight {
                components.append(Bundle.main.version.map { "(\($0))" })
            }
            cellTitleText = components.compactMap { $0 }.joined(separator: " ")
        }
        
        let textHeader = UITextView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 50))
        textHeader.textAlignment = .left
        textHeader.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textHeader.font = UIFont.preferredFontForTextStyle(.body, sizeAdjustment: 0, weight: .semibold)
        textHeader.textColor = theme["listSecondaryTextColor"]
        textHeader.backgroundColor = theme["listBackgroundColor"]
        textHeader.text = cellTitleText
        textHeader.isEditable = false
        textHeader.isScrollEnabled = false
        
        return textHeader
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footer = UITextView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 50))
        footer.text = sections[section]["Explanation"] as? String
        footer.textAlignment = .left
        footer.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        footer.font = UIFont.preferredFontForTextStyle(.footnote, sizeAdjustment: 1, weight: .semibold)
        footer.textColor = theme["listSecondaryTextColor"]
        footer.backgroundColor = theme["listBackgroundColor"]
        footer.isEditable = false
        footer.isScrollEnabled = false
        
        return footer
    }
    
    override func themeDidChange() {
        super.themeDidChange()

        tableView.separatorColor = theme["listSeparatorColor"]
    }
}

private let registerTransformers: () -> Void = {
    ValueTransformer.setValueTransformer(ThemeNameTransformer(), forName: ThemeNameTransformer.name)
    return {}
}()
