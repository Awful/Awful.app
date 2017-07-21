//  PostsPageSettingsViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

/// A PostsPageSettingsViewController is a modal view controller for changing settings specific to a posts page. By default it presents in a popover on all devices.
final class PostsPageSettingsViewController: ViewController, UIPopoverPresentationControllerDelegate {
    let forum: Forum
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
    fileprivate var _selectedTheme: Theme?
    
    init(forum: Forum) {
        self.forum = forum
        super.init(nibName: "PostsPageSettings", bundle: nil)
        modalPresentationStyle = .popover
        popoverPresentationController!.delegate = self
    }
    
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var headerBackground: UIView!
    
    @IBOutlet var labels: [UILabel]!
    @IBOutlet var switches: [UISwitch]!
    
    @IBOutlet weak var autoThemeSwitch: UISwitch!
    @IBOutlet weak var darkThemeSwitch: UISwitch!
    @IBOutlet weak var darkThemeLabel: UILabel!
    @IBAction func toggleAutomaticTheme(_ sender: UISwitch) {
        updateAutoThemeSetting()
    }
    
    @IBOutlet weak var themeLabel: UILabel!
    @IBOutlet weak var themePicker: ThemePicker!
    @IBAction func changeSelectedTheme(_ sender: ThemePicker) {
        _selectedTheme = themes[sender.selectedThemeIndex]
        AwfulSettings.shared().setThemeName(selectedTheme.name, forForumID: forum.forumID)
        if selectedTheme.forumID == nil {
            AwfulSettings.shared().darkTheme = selectedTheme != Theme.defaultTheme
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for (i, theme) in themes.enumerated() {
            let color = theme.descriptiveColor
            color.accessibilityLabel = theme.descriptiveName
            themePicker.insertThemeWithColor(color, atIndex: i)
        }
        updateSelectedThemeInPicker()
        updateAutoThemeSetting()
        themePicker.isLoaded = true
        
        let preferredHeight = view.systemLayoutSizeFitting(UILayoutFittingCompressedSize).height
        preferredContentSize = CGSize(width: 320, height: preferredHeight)
    }
    
    fileprivate func updateSelectedThemeInPicker() {
        let names = themes.map { $0.name }
        if var themeName = AwfulSettings.shared().themeName(forForumID: forum.forumID) {
            if themeName == "default" || themeName == "dark" || themeName == "alternate" || themeName == "alternateDark" {
                themeName = Theme.currentTheme.name
            }
            if let i = names.index(of: themeName) {
                themePicker.selectedThemeIndex = i
            }
        }
        else {
            themePicker.selectedThemeIndex = names.index(of: Theme.currentTheme.name)!
        }
    }
    
    private func updateAutoThemeSetting() {
        if autoThemeSwitch.isOn {
            darkThemeSwitch.isEnabled = false;
            darkThemeLabel.isEnabled = false;
        }
        else {
            darkThemeSwitch.isEnabled = true;
            darkThemeLabel.isEnabled = true;
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
    
    fileprivate override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
        fatalError("Selectotron needs a posts view controller")
    }
    
    required init?(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
}
