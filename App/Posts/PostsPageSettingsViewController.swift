//  PostsPageSettingsViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

/// A PostsPageSettingsViewController is a modal view controller for changing settings specific to a posts page. By default it presents in a popover on all devices.
final class PostsPageSettingsViewController: ViewController, UIPopoverPresentationControllerDelegate {
    
    let forum: Forum
    private var observers: [NSKeyValueObservation] = []
    var themes: [Theme] { return Theme.themesForForum(forum) }
    
    var selectedTheme: Theme! {
        get {
            return _selectedTheme
        }
        set {
            _selectedTheme = selectedTheme
            if isViewLoaded {
                updateSelectedThemeInPicker()
            }
        }
    }
    private var _selectedTheme: Theme?
    
    init(forum: Forum) {
        self.forum = forum
        super.init(nibName: "PostsPageSettings", bundle: nil)
        modalPresentationStyle = .popover
        popoverPresentationController?.delegate = self
    }
    
    @IBOutlet private var headerLabel: UILabel!
    @IBOutlet private var headerBackground: UIView!
    
    @IBOutlet private var labels: [UILabel]!
    @IBOutlet private var switches: [UISwitch]!
    
    @IBOutlet private var avatarsSwitch: UISwitch!
    @IBAction func toggleAvatars(_ sender: UISwitch) {
        UserDefaults.standard.showAuthorAvatars = sender.isOn
    }
    @IBOutlet private var imagesSwitch: UISwitch!
    @IBAction private func toggleImages(_ sender: UISwitch) {
        UserDefaults.standard.showImages = sender.isOn
    }
    
    @IBOutlet private var scaleTextLabel: UILabel!
    @IBOutlet private var scaleTextStepper: UIStepper!
    @IBAction private func scaleStepperDidChange(_ sender: UIStepper) {
        UserDefaults.standard.fontScale = sender.value
    }
    
    @IBOutlet private var autoThemeSwitch: UISwitch!
    @IBAction func toggleAutomaticDarkTheme(_ sender: UISwitch) {
        UserDefaults.standard.automaticallyEnableDarkMode = sender.isOn
    }
    @IBOutlet private var darkThemeLabel: UILabel!
    @IBOutlet private var darkThemeSwitch: UISwitch!
    @IBAction func toggleDarkTheme(_ sender: UISwitch) {
    
        UserDefaults.standard.isDarkModeEnabled = sender.isOn
    }
    
    @IBOutlet private var themeLabel: UILabel!
    @IBOutlet private var themePicker: ThemePicker!
    @IBAction private func changeSelectedTheme(_ sender: ThemePicker) {
        _selectedTheme = themes[sender.selectedThemeIndex]
        Theme.setThemeName(selectedTheme.name, forForumIdentifiedBy: forum.forumID)
        if selectedTheme.forumID == nil {
            UserDefaults.standard.isDarkModeEnabled = selectedTheme != Theme.defaultTheme
        }
    }
    
    private lazy var fontScaleFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for (i, theme) in themes.enumerated() {
            let color = theme.descriptiveColor
            color.accessibilityLabel = theme.descriptiveName
            themePicker.insertThemeWithColor(color, atIndex: i)
        }
        updateSelectedThemeInPicker()
        themePicker.isLoaded = true
        NotificationCenter.default.addObserver(self, selector: #selector(forumSpecificThemeDidChange), name: Theme.themeForForumDidChangeNotification, object: Theme.self)
        
        observers += UserDefaults.standard.observeSeveral {
            $0.observe(\.automaticallyEnableDarkMode, \.isDarkModeEnabled, options: .initial) {
                [unowned self] defaults in
                self.autoThemeSwitch.isOn = defaults.automaticallyEnableDarkMode
                self.darkThemeSwitch.isOn = defaults.isDarkModeEnabled
                
                let canManuallyToggleDarkTheme = !defaults.automaticallyEnableDarkMode
                self.darkThemeLabel.isEnabled = canManuallyToggleDarkTheme
                self.darkThemeSwitch.isEnabled = canManuallyToggleDarkTheme
            }
            $0.observe(\.fontScale, options: .initial) { [unowned self] defaults in
                let percent = self.fontScaleFormatter.string(from: (defaults.fontScale / 100) as NSNumber) ?? ""
                let format = LocalizedString("settings.font-scale.title")
                self.scaleTextLabel.text = String(format: format, percent)
            }
            $0.observe(\.showAuthorAvatars, options: .initial) { [unowned self] defaults in
                self.avatarsSwitch.isOn = defaults.showAuthorAvatars
            }
            $0.observe(\.showImages, options: .initial) { [unowned self] defaults in
                self.imagesSwitch.isOn = defaults.showImages
            }
        }
        
        let preferredHeight = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        preferredContentSize = CGSize(width: 320, height: preferredHeight)
    }
    
    @objc private func forumSpecificThemeDidChange(_ notification: Notification) {
        guard
            let forumID = notification.userInfo?[Theme.forumIDKey] as? String,
            forumID == forum.forumID
            else { return }
        
        updateSelectedThemeInPicker()
    }
    
    private func updateSelectedThemeInPicker() {
        let names = themes.map { $0.name }
        if var themeName = Theme.themeNameForForum(identifiedBy: forum.forumID) {
            if themeName == "default" || themeName == "dark" || themeName == "alternate" || themeName == "alternateDark" {
                themeName = Theme.currentTheme.name
            }
            if let i = names.firstIndex(of: themeName) {
                themePicker.selectedThemeIndex = i
            }
        }
        else {
            themePicker.selectedThemeIndex = names.firstIndex(of: Theme.currentTheme.name)!
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        view.tintColor = theme["tintColor"]
        view.backgroundColor = theme["sheetBackgroundColor"]
        popoverPresentationController?.backgroundColor = theme["sheetBackgroundColor"]
		headerLabel.textColor = theme["sheetTitleColor"]
        headerBackground.backgroundColor = theme["sheetTitleBackgroundColor"]
        for label in labels {
            label.textColor = theme["sheetTextColor"]
        }
        for uiswitch in switches {
            uiswitch.onTintColor = theme["settingsSwitchColor"]
        }
        
        // Theme picker's background is a light grey so I can see it (until I figure out how live views work in Xcode 6), but it should be transparent for real.
        themePicker.backgroundColor = nil
        
        if themePicker.isLoaded {
            themePicker.setDefaultThemeColor(color: theme["descriptiveColor"]!)
            updateSelectedThemeInPicker()
        }
    }
    
    // MARK: UIAdaptivePresentationControllerDelegate
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    // MARK: Initializers not intended to be called
    
    private override init(nibName: String?, bundle: Bundle?) {
        fatalError("Selectotron needs a posts view controller")
    }
    
    required init?(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
}
