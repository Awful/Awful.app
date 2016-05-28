//  SettingsViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData

final class SettingsViewController: TableViewController {
    private let managedObjectContext: NSManagedObjectContext
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(style: .Grouped)
        
        title = "Settings"
        
        tabBarItem.image = UIImage(named: "cog")
        tabBarItem.selectedImage = UIImage(named: "cog-filled")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let sections: [[String: AnyObject]]! = {
        let currentDevice: String
        // For settings purposes, we consider devices with a regular horizontal size class in landscape to be iPads. This includes iPads and also the iPhone 6 Plus.
        // TODO Find a better way of doing this than checking the displayScale.
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad || UIScreen.mainScreen().nativeScale == 3 {
            currentDevice = "iPad"
        } else {
            currentDevice = "iPhone"
        }
        
        guard let sections = AwfulSettings.sharedSettings().sections as? [[String: AnyObject]] else { fatalError("can't interpret settings sections") }
        func validSection(section: [String: AnyObject]) -> Bool {
            if let device = section["Device"] as? String where !device.hasPrefix(currentDevice) {
                return false
            }
            if let capability = section["DeviceCapability"] as? String where capability == "Handoff" && !UIDevice.currentDevice().isHandoffCapable {
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
                
                func validSetting(setting: [String: AnyObject]) -> Bool {
                    if let device = setting["Device"] as? String where !device.hasPrefix(currentDevice) {
                        return false
                    }
                    if let
                        urlString = setting["CanOpenURL"] as? String,
                        url = NSURL(string: urlString)
                    {
                        return UIApplication.sharedApplication().canOpenURL(url)
                    }
                    return true
                }
                section["Settings"] = settings.filter(validSetting)
                return section
        }
    }()
    
    private var loggedInUser: User {
        let key = UserKey(userID: AwfulSettings.sharedSettings().userID, username: AwfulSettings.sharedSettings().username)
        return User.objectForKey(key, inManagedObjectContext: managedObjectContext) as! User
    }
    
    private func refreshIfNecessary() {
        guard RefreshMinder.sharedMinder.shouldRefreshLoggedInUser else { return }
        AwfulForumsClient.sharedClient().learnLoggedInUserInfoAndThen { [weak self] (error, user) in
            if let error = error {
                print("\(#function) failed refreshing user info: \(error)")
                return
            }
            
            guard let user = user else { fatalError("no error should mean yes user") }
            RefreshMinder.sharedMinder.didRefreshLoggedInUser()
            
            AwfulSettings.sharedSettings().userID = user.userID
            AwfulSettings.sharedSettings().username = user.username
            AwfulSettings.sharedSettings().canSendPrivateMessages = user.canReceivePrivateMessages
            
            self?.tableView.reloadData()
        }
    }
    
    private func setting(at indexPath: NSIndexPath) -> [String: AnyObject] {
        guard let settings = sections[indexPath.section]["Settings"] as? [[String: AnyObject]] else { fatalError("wrong settings type") }
        return settings[indexPath.row]
    }
    
    @objc private func showProfile() {
        let profileVC = ProfileViewController(user: loggedInUser)
        presentViewController(profileVC.enclosingNavigationController, animated: true, completion: nil)
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.separatorStyle = .SingleLine
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        refreshIfNecessary()
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        coordinator.animateAlongsideTransition(nil) { (context) in
            self.tableView.reloadData()
        }
    }
    
    // MARK: Table view
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let settings = sections[section]["Settings"] as? [[String: AnyObject]] else { return 0 }
        return settings.count
    }
    
    private enum SettingType: String {
        case Immutable = "ImmutableSetting"
        case OnOff = "Switch"
        case Button = "Action"
        case Stepper = "Stepper"
        case Disclosure = "Disclosure"
        case DisclosureDetail = "DisclosureDetail"
        
        var cellStyle: UITableViewCellStyle {
            switch self {
            case .OnOff, .Button, .Disclosure:
                return .Default
                
            case .Immutable, .Stepper, .DisclosureDetail:
                return .Value1
            }
        }
        
        var cellIdentifier: String {
            return rawValue
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let setting = self.setting(at: indexPath)
        let settingType: SettingType
        if let typeString = setting["Type"] as? String where typeString == "Switch" {
            settingType = .OnOff
        } else if let action = setting["Action"] as? String where action != "ShowProfile" {
            settingType = .Button
        } else if let typeString = setting["Type"] as? String where typeString == "Stepper" {
            settingType = .Stepper
        } else if setting["ViewController"] != nil {
            if setting["DisplayTransformer"] != nil || setting["ShowValue"] as? Bool == true {
                settingType = .DisclosureDetail
            } else {
                settingType = .Disclosure
            }
        } else {
            settingType = .Immutable
        }
        
        let cell: UITableViewCell
        if let dequeued = tableView.dequeueReusableCellWithIdentifier(settingType.cellIdentifier) {
            cell = dequeued
        } else {
            cell = UITableViewCell(style: settingType.cellStyle, reuseIdentifier: settingType.cellIdentifier)
            switch settingType {
            case .OnOff:
                cell.accessoryView = UISwitch()
                
            case .Disclosure, .DisclosureDetail:
                cell.accessoryType = .DisclosureIndicator
                cell.accessibilityTraits |= UIAccessibilityTraitButton
                
            case .Stepper:
                cell.accessoryView = UIStepper()
                
            case .Button where setting["ThreadID"] != nil:
                cell.accessibilityTraits |= UIAccessibilityTraitButton
                cell.accessoryType = .DisclosureIndicator
                
            case .Button:
                cell.accessibilityTraits |= UIAccessibilityTraitButton
                cell.accessoryType = .None
                
            case .Immutable:
                break
            }
        }
        if settingType.cellStyle == .Value1 {
            cell.detailTextLabel?.textColor = UIColor.grayColor()
        }
        
        if let transformerTypeName = setting["DisplayTransformer"] as? String {
            guard let transformerType = NSClassFromString(transformerTypeName) as? NSValueTransformer.Type else { fatalError("Couldn't make transformer of type \(transformerTypeName)") }
            let transformer = transformerType.init()
            switch settingType {
            case .DisclosureDetail:
                cell.textLabel?.text = setting["Title"] as? String
                cell.detailTextLabel?.text = transformer.transformedValue(AwfulSettings.sharedSettings()) as? String
                
            case .Immutable, .OnOff, .Disclosure, .Stepper, .Button:
                cell.textLabel?.text = transformer.transformedValue(AwfulSettings.sharedSettings()) as? String
            }
        } else if setting["ShowValue"] as? Bool == true {
            cell.textLabel?.text = setting["Title"] as? String
            guard let key = setting["Key"] as? String else { fatalError("expected a key for setting \(setting)") }
            cell.detailTextLabel?.text = AwfulSettings.sharedSettings()[key] as? String
        } else {
            cell.textLabel?.text = setting["Title"] as? String
        }
        
        if settingType == .Immutable, let valueID = setting["ValueIdentifier"] as? String where valueID == "Username" {
            cell.detailTextLabel?.text = AwfulSettings.sharedSettings().username
        }
        
        if settingType == .OnOff {
            guard let switchView = cell.accessoryView as? UISwitch else { fatalError("setting should have a UISwitch accessory") }
            switchView.awful_setting = setting["Key"] as? String
        }
        
        if settingType == .Stepper {
            guard let stepper = cell.accessoryView as? UIStepper else { fatalError("setting should have a UIStepper accessory") }
            stepper.awful_setting = setting["Key"] as? String
            cell.textLabel?.awful_setting = setting["Key"] as? String
            cell.textLabel?.awful_settingFormatString = setting["Title"] as? String
        }
        
        switch settingType {
        case .Button, .Disclosure, .DisclosureDetail:
            cell.selectionStyle = .Blue
            
        case .Immutable, .OnOff, .Stepper:
            cell.selectionStyle = .None
        }
        
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.textLabel?.textColor = theme["listTextColor"]
        cell.selectedBackgroundColor = theme["listSelectedBackgroundColor"]
        
        if let switchView = cell.accessoryView as? UISwitch {
            switchView.onTintColor = theme["settingsSwitchColor"]
        }
        
        return cell
    }
    
    override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        let ok = ["Action", "Choices", "ViewController"]
        if let _ = setting(at: indexPath).keys.indexOf(ok.contains) {
            return indexPath
        }
        return nil
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        defer { tableView.deselectRowAtIndexPath(indexPath, animated: true) }
        
        let setting = self.setting(at: indexPath)
        switch (setting["Action"] as? String, setting["ViewController"] as? String) {
        case ("LogOut"?, _):
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .Alert)
            alert.title = "Log Out"
            alert.message = "Are you sure you want to log out?"
            alert.addCancelActionWithHandler(nil)
            alert.addActionWithTitle("Log Out", handler: { AppDelegate.instance.logOut() })
            presentViewController(alert, animated: true, completion: nil)
            
        case ("GoToAwfulThread"?, _):
            guard let threadID = setting["ThreadID"] as? String else { fatalError("setting \(setting) needs a ThreadID") }
            let url = NSURL(string: "awful://threads/")!.URLByAppendingPathComponent(threadID, isDirectory: false)
            AppDelegate.instance.openAwfulURL(url)
            
        case (_, let vcTypeName?):
            guard let vcType = NSClassFromString(vcTypeName) as? UIViewController.Type else { fatalError("couldn't find type named \(vcTypeName)") }
            let vc = vcType.init()
            if vc.modalPresentationStyle == .FormSheet && UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                presentViewController(vc.enclosingNavigationController, animated: true, completion: nil)
            } else {
                navigationController?.pushViewController(vc, animated: true)
            }
            
        case (let action?, _):
            fatalError("unknown setting action \(action)")
            
        default:
            fatalError("don't know how to handle selected setting \(setting)")
        }
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection sectionIndex: Int) -> String? {
        let section = sections[sectionIndex]
        if let titleKey = section["TitleKey"] as? String {
            return AwfulSettings.sharedSettings()[titleKey] as? String
        }
        guard let title = section["Title"] as? String else { return nil }
        if title == "Awful x.y.z" {
            guard let version = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as? String else { fatalError("couldn't find version") }
            return "Awful \(version)"
        }
        return title
    }
    
    override func tableView(tableView: UITableView, viewForHeaderInSection sectionIndex: Int) -> UIView? {
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
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    override func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section]["Explanation"] as? String
    }
}
