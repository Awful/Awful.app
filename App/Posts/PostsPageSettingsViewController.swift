//  PostsPageSettingsViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A PostsPageSettingsViewController is a modal view controller for changing settings specific to a posts page. By default it presents in a popover on all devices.
final class PostsPageSettingsViewController: AwfulViewController, UIPopoverPresentationControllerDelegate {
    let forum: Forum
    var themes: [Theme] { return Theme.themesForForum(forum) }
    
    var selectedTheme: Theme! {
        get {
            return _selectedTheme
        }
        set {
            _selectedTheme = selectedTheme
            if isViewLoaded() {
                updateSelectedThemeInPicker()
            }
        }
    }
    private var _selectedTheme: Theme?
    
    init(forum: Forum) {
        self.forum = forum
        super.init(nibName: "PostsPageSettings", bundle: nil)
        modalPresentationStyle = .Popover
        popoverPresentationController!.delegate = self
    }
    
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var headerBackground: UIView!
    
    @IBOutlet var labels: [UILabel]!
    @IBOutlet var switches: [UISwitch]!
    
    @IBOutlet weak var themePicker: ThemePicker!
    @IBAction func changeSelectedTheme(sender: ThemePicker) {
        _selectedTheme = themes[sender.selectedThemeIndex]
        AwfulSettings.sharedSettings().setThemeName(selectedTheme.name, forForumID: forum.forumID)
        if selectedTheme.forumID == nil {
            AwfulSettings.sharedSettings().darkTheme = selectedTheme != Theme.defaultTheme
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for (i, theme) in themes.enumerate() {
            let color = theme.descriptiveColor
            color.accessibilityLabel = theme.descriptiveName
            themePicker.insertThemeWithColor(color, atIndex: i)
        }
        updateSelectedThemeInPicker()
        
        let preferredHeight = view.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
        preferredContentSize = CGSize(width: 320, height: preferredHeight)
    }
    
    private func updateSelectedThemeInPicker() {
        let names = themes.map { $0.name }
        if let themeName = AwfulSettings.sharedSettings().themeNameForForumID(forum.forumID) {
            if let i = names.indexOf(themeName) {
                themePicker.selectedThemeIndex = i
            }
        }
        else {
            if AwfulSettings.sharedSettings().darkTheme {
                themePicker.selectedThemeIndex = names.indexOf("dark")!
            }
            else {
                themePicker.selectedThemeIndex = names.indexOf("default")!
            }
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
    }
    
    // MARK: UIAdaptivePresentationControllerDelegate
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return .None
    }
    
    // MARK: Initializers not intended to be called
    
    private override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
        fatalError("Selectotron needs a posts view controller")
    }
    
    required init?(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
}
