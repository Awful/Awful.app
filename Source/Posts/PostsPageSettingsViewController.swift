//  PostsPageSettingsViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/**
A PostsPageSettingsViewController is a modal view controller for changing settings specific to a posts page. By default it presents in a popover on all devices.
*/
class PostsPageSettingsViewController: AwfulViewController, UIPopoverPresentationControllerDelegate {
    let forum: AwfulForum
    
    var themes: [AwfulTheme] {
        return AwfulThemeLoader.sharedLoader().themesForForumWithID(forum.forumID) as [AwfulTheme]
    }
    
    var selectedTheme: AwfulTheme! {
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
    private var _selectedTheme: AwfulTheme?
    
    init(forum: AwfulForum) {
        self.forum = forum
        super.init(nibName: "PostsPageSettings", bundle: nil)
        modalPresentationStyle = .Popover
        popoverPresentationController!.delegate = self
    }
    
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var headerBackground: UIView!
    
    @IBOutlet var labels: [UILabel]!
    @IBOutlet var switches: [UISwitch]!
    
    @IBOutlet weak var avatarsSwitch: UISwitch!
    @IBAction func toggleAvatarsEnabled(sender: UISwitch) {
        AwfulSettings.sharedSettings().showAvatars = sender.on
    }
    
    @IBOutlet weak var imagesSwitch: UISwitch!
    @IBAction func toggleImagesEnabled(sender: UISwitch) {
        AwfulSettings.sharedSettings().showImages = sender.on
    }
    
    @IBOutlet weak var fontScaleLabel: UILabel!
    @IBOutlet weak var fontScaleStepper: UIStepper!
    @IBAction func changeFontScale(sender: UIStepper) {
        AwfulSettings.sharedSettings().fontScale = sender.value
        updateFontScaleLabelFromStepper()
    }
    
    @IBOutlet weak var themePicker: AwfulThemePicker!
    @IBAction func changeSelectedTheme(sender: AwfulThemePicker) {
        _selectedTheme = themes[sender.selectedThemeIndex]
        AwfulSettings.sharedSettings().setThemeName(selectedTheme.name, forForumID: forum.forumID)
        if !selectedTheme.forumSpecific {
            AwfulSettings.sharedSettings().darkTheme = selectedTheme != AwfulThemeLoader.sharedLoader().defaultTheme
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for (i, theme) in enumerate(themes) {
            let color = theme.descriptiveColor
            color.accessibilityLabel = theme.descriptiveName
            themePicker.insertThemeWithColor(color, atIndex: i)
        }
        updateSelectedThemeInPicker()
        
        let preferredHeight = view.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
        preferredContentSize = CGSize(width: 320, height: preferredHeight)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        avatarsSwitch.on = AwfulSettings.sharedSettings().showAvatars
        imagesSwitch.on = AwfulSettings.sharedSettings().showImages
        fontScaleStepper.value = AwfulSettings.sharedSettings().fontScale
        updateFontScaleLabelFromStepper()
    }
    
    private func updateFontScaleLabelFromStepper() {
        fontScaleLabel.text = "\(Int(fontScaleStepper.value))%"
    }
    
    private func updateSelectedThemeInPicker() {
        if let i = find(themes, theme) {
            themePicker.selectedThemeIndex = i
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        view.tintColor = theme["tintColor"] as? UIColor
        let backgroundColor = theme["sheetBackgroundColor"] as? UIColor
        view.backgroundColor = backgroundColor
        popoverPresentationController?.backgroundColor = backgroundColor
		headerLabel.textColor = theme["sheetTitleColor"] as? UIColor ?? UIColor.blackColor()  //BUG Beta 7: UILabel doesn't accept optionals for textColor, but probably should.  Bug filed.
        headerBackground.backgroundColor = theme["sheetTitleBackgroundColor"] as? UIColor
        for label in labels {
            label.textColor = theme["sheetTextColor"] as? UIColor ?? UIColor.blackColor()
        }
        for uiswitch in switches {
            uiswitch.onTintColor = theme["settingsSwitchColor"] as? UIColor
        }
        
        // Theme picker's background is a light grey so I can see it (until I figure out how live views work in Xcode 6), but it should be transparent for real.
        themePicker.backgroundColor = nil
    }
    
    // MARK: UIAdaptivePresentationControllerDelegate
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController!) -> UIModalPresentationStyle {
        return .None
    }
    
    // MARK: Initializers not intended to be called
    
    private override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
        fatalError("Selectotron needs a posts view controller")
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
}
