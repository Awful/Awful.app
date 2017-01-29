//  SettingsViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData

final class SettingsViewController: TableViewController {
    fileprivate let managedObjectContext: NSManagedObjectContext
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(style: .grouped)
        
        title = "Settings"
        
        tabBarItem.image = UIImage(named: "cog")
        tabBarItem.selectedImage = UIImage(named: "cog-filled")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate let sections: [[String: AnyObject]]! = {
        let currentDevice: String
        // For settings purposes, we consider devices with a regular horizontal size class in landscape to be iPads. This includes iPads and also the iPhone 6 Plus.
        let tc = UIScreen.main.traitCollection
        if tc.horizontalSizeClass == .regular || tc.verticalSizeClass == .regular {
            currentDevice = "iPad"
        } else {
            currentDevice = "iPhone"
        }
        
        guard let sections = AwfulSettings.shared().sections as? [[String: AnyObject]] else { fatalError("can't interpret settings sections") }
        func validSection(_ section: [String: AnyObject]) -> Bool {
            if let device = section["Device"] as? String, !device.hasPrefix(currentDevice) {
                return false
            }
            if let capability = section["DeviceCapability"] as? String , capability == "Handoff" && !UIDevice.current.isHandoffCapable {
                return false
            }
            if let visible = section["VisibleInSettingsTab"] as? Bool {
                return visible
            }
            return true
        }
        return sections.lazy
            .filter(validSection)
            .map { (section) in
                guard let settings = section["Settings"] as? [[String: AnyObject]] else { return section }
                var section = section
                
                section["Settings"] = settings.filter { (setting) in
                    if let device = setting["Device"] as? String, !device.hasPrefix(currentDevice) {
                        return false
                    }
                    if
                        let urlString = setting["CanOpenURL"] as? String,
                        let url = URL(string: urlString)
                    {
                        return UIApplication.shared.canOpenURL(url)
                    }
                    return true
                } as NSArray
                return section
        }
    }()
    
    fileprivate var loggedInUser: User {
        let key = UserKey(userID: AwfulSettings.shared().userID, username: AwfulSettings.shared().username)
        return User.objectForKey(objectKey: key, inManagedObjectContext: managedObjectContext) as! User
    }
    
    fileprivate func refreshIfNecessary() {
        guard RefreshMinder.sharedMinder.shouldRefreshLoggedInUser else { return }
        AwfulForumsClient.shared().learnLogged { [weak self] (error: Error?, user: User?) in
            if let error = error {
                print("\(#function) failed refreshing user info: \(error)")
                return
            }
            
            guard let user = user else { fatalError("no error should mean yes user") }
            RefreshMinder.sharedMinder.didRefreshLoggedInUser()
            
            AwfulSettings.shared().userID = user.userID
            AwfulSettings.shared().username = user.username
            AwfulSettings.shared().canSendPrivateMessages = user.canReceivePrivateMessages
            
            self?.tableView.reloadData()
        }
    }
    
    fileprivate func setting(at indexPath: IndexPath) -> [String: AnyObject] {
        guard let settings = sections[(indexPath as NSIndexPath).section]["Settings"] as? [[String: AnyObject]] else { fatalError("wrong settings type") }
        return settings[(indexPath as NSIndexPath).row]
    }
    
    @objc fileprivate func showProfile() {
        let profileVC = ProfileViewController(user: loggedInUser)
        present(profileVC.enclosingNavigationController, animated: true, completion: nil)
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.separatorStyle = .singleLine
        tableView.register(UINib(nibName: "SettingsSliderCell", bundle: nil), forCellReuseIdentifier: SettingType.Slider.rawValue)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        refreshIfNecessary()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
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
    
    fileprivate enum SettingType: String {
        case Immutable = "ImmutableSetting"
        case OnOff = "Switch"
        case Button = "Action"
        case Stepper = "Stepper"
        case Disclosure = "Disclosure"
        case DisclosureDetail = "DisclosureDetail"
        case Slider = "Slider"
        
        var cellStyle: UITableViewCellStyle {
            switch self {
            case .OnOff, .Button, .Disclosure:
                return .default
                
            case .Immutable, .Stepper, .DisclosureDetail:
                return .value1
            
            case .Slider:
                return .default
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
            if setting["DisplayTransformer"] != nil || setting["ShowValue"] as? Bool == true {
                settingType = .DisclosureDetail
            } else {
                settingType = .Disclosure
            }
        } else if let typeString = setting["Type"] as? String, typeString == "Slider" {
            settingType = .Slider
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
                cell.accessibilityTraits |= UIAccessibilityTraitButton
                
            case .Stepper:
                cell.accessoryView = UIStepper()
                
            case .Button where setting["ThreadID"] != nil:
                cell.accessibilityTraits |= UIAccessibilityTraitButton
                cell.accessoryType = .disclosureIndicator
                
            case .Button:
                cell.accessibilityTraits |= UIAccessibilityTraitButton
                cell.accessoryType = .none
                
            case .Immutable, .Slider:
                break
            }
        }
        if settingType.cellStyle == .value1 {
            cell.detailTextLabel?.textColor = UIColor.gray
        }
        
        if let transformerTypeName = setting["DisplayTransformer"] as? String {
            guard let transformerType = NSClassFromString(transformerTypeName) as? ValueTransformer.Type else { fatalError("Couldn't make transformer of type \(transformerTypeName)") }
            let transformer = transformerType.init()
            switch settingType {
            case .DisclosureDetail:
                cell.textLabel?.text = setting["Title"] as? String
                cell.detailTextLabel?.text = transformer.transformedValue(AwfulSettings.shared()) as? String
                
            case .Immutable, .OnOff, .Disclosure, .Stepper, .Button:
                cell.textLabel?.text = transformer.transformedValue(AwfulSettings.shared()) as? String
                
            case .Slider:
                break
            }
        } else if setting["ShowValue"] as? Bool == true {
            cell.textLabel?.text = setting["Title"] as? String
            guard let key = setting["Key"] as? String else { fatalError("expected a key for setting \(setting)") }
            cell.detailTextLabel?.text = AwfulSettings.shared()[key] as? String
        } else {
            cell.textLabel?.text = setting["Title"] as? String
        }
        
        if settingType == .Immutable, let valueID = setting["ValueIdentifier"] as? String , valueID == "Username" {
            cell.detailTextLabel?.text = AwfulSettings.shared().username
        }
        
        if settingType == .OnOff {
            guard let switchView = cell.accessoryView as? UISwitch else { fatalError("setting should have a UISwitch accessory") }
            switchView.awful_setting = setting["Key"] as? String
            
            // Add overriding settings
            if switchView.awful_setting == AwfulSettingsKeys.darkTheme.takeUnretainedValue() as String {
                switchView.addAwful_overridingSetting(AwfulSettingsKeys.autoDarkTheme.takeUnretainedValue() as String)
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
            
            // Add overriding settings
            if slider.awful_setting == AwfulSettingsKeys.autoThemeThreshold.takeUnretainedValue() as String {
                slider.addAwful_overridingSetting(AwfulSettingsKeys.autoDarkTheme.takeUnretainedValue() as String)
            }
            
        }
        switch settingType {
        case .Button, .Disclosure, .DisclosureDetail:
            cell.selectionStyle = .blue
            
        case .Immutable, .OnOff, .Stepper, .Slider:
            cell.selectionStyle = .none
        }
        
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.textLabel?.textColor = theme["listTextColor"]
        cell.selectedBackgroundColor = theme["listSelectedBackgroundColor"]
        
        if let switchView = cell.accessoryView as? UISwitch {
            switchView.onTintColor = theme["settingsSwitchColor"]
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let ok = ["Action", "Choices", "ViewController"]
        if let _ = setting(at: indexPath).keys.index(where: ok.contains) {
            return indexPath
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        
        let setting = self.setting(at: indexPath)
        switch (setting["Action"] as? String, setting["ViewController"] as? String) {
        case ("LogOut"?, _):
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
            alert.title = "Log Out"
            alert.message = "Are you sure you want to log out?"
            alert.addCancelActionWithHandler(nil)
            alert.addActionWithTitle("Log Out", handler: { AppDelegate.instance.logOut() })
            present(alert, animated: true, completion: nil)
            
        case ("GoToAwfulThread"?, _):
            guard let threadID = setting["ThreadID"] as? String else { fatalError("setting \(setting) needs a ThreadID") }
            let url = URL(string: "awful://threads/")!.appendingPathComponent(threadID, isDirectory: false)
            AppDelegate.instance.openAwfulURL(url)
            
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
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection sectionIndex: Int) -> String? {
        let section = sections[sectionIndex]
        if let titleKey = section["TitleKey"] as? String {
            return AwfulSettings.shared()[titleKey] as? String
        }
        guard let title = section["Title"] as? String else { return nil }
        if title == "Awful x.y.z" {
            guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { fatalError("couldn't find version") }
            return "Awful \(version)"
        }
        return title
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection sectionIndex: Int) -> UIView? {
        let section = sections[sectionIndex]
        guard let action = section["Action"] as? String else { return nil }
        let header = SettingsAvatarHeader.newFromNib()
        
        if let titleKey = section["TitleKey"] as? String {
            header.usernameLabel.awful_setting = titleKey
        }
        header.usernameLabel.textColor = theme["listTextColor"]
        
        header.contentEdgeInsets = tableView.separatorInset
        
        if action == "ShowProfile" {
            header.setTarget(self, action: #selector(showProfile))
        }
        
        header.setAvatarImage(AvatarLoader.sharedLoader.cachedAvatarImageForUser(loggedInUser))
        AvatarLoader.sharedLoader.fetchAvatarImageForUser(loggedInUser) { (modified, image, error) in
            guard modified else { return }
            header.setAvatarImage(image)
        }
        
        return header
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section]["Explanation"] as? String
    }
    
    func awfulSettingsDidChange(_ notification: Notification) {
        
    }
}
