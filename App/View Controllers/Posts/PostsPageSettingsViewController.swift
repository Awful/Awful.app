//  PostsPageSettingsViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

/// A PostsPageSettingsViewController is a modal view controller for changing settings specific to a posts page. By default it presents in a popover on all devices.
final class PostsPageSettingsViewController: ViewController, UIPopoverPresentationControllerDelegate {
    
    private var observers: [NSKeyValueObservation] = []

    init() {
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
    
    @IBOutlet private var automaticDarkModeSwitch: UISwitch!
    @IBAction func toggleAutomaticDarkMode(_ sender: UISwitch) {
        UserDefaults.standard.automaticallyEnableDarkMode = sender.isOn
    }

    @IBOutlet private var darkModeStack: UIStackView!
    @IBOutlet private var darkModeLabel: UILabel!
    @IBOutlet private var darkModeSwitch: UISwitch!
    @IBAction func toggleDarkMode(_ sender: UISwitch) {
        UserDefaults.standard.isDarkModeEnabled = sender.isOn
    }

    private lazy var fontScaleFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        scaleTextLabel.font = scaleTextLabel.font.monospacedDigitFont

        observers += UserDefaults.standard.observeSeveral {
            $0.observe(\.automaticallyEnableDarkMode, \.isDarkModeEnabled, options: .initial) {
                [weak self] defaults in
                guard let self = self else { return }

                self.automaticDarkModeSwitch.isOn = defaults.automaticallyEnableDarkMode
                self.darkModeSwitch.isOn = defaults.isDarkModeEnabled
                
                let canManuallyToggleDarkTheme = !defaults.automaticallyEnableDarkMode
                self.darkModeStack.isHidden = !canManuallyToggleDarkTheme
                self.darkModeLabel.isEnabled = canManuallyToggleDarkTheme
                self.darkModeSwitch.isEnabled = canManuallyToggleDarkTheme

                self.updatePreferredContentSize()
            }
            $0.observe(\.fontScale, options: .initial) {
                [weak self] defaults in
                guard let self = self else { return }

                let percent = self.fontScaleFormatter.string(from: (defaults.fontScale / 100) as NSNumber) ?? ""
                let format = LocalizedString("settings.font-scale.title")
                self.scaleTextLabel.text = String(format: format, percent)
                self.scaleTextStepper.value = defaults.fontScale
            }
            $0.observe(\.showAuthorAvatars, options: .initial) {
                [avatarsSwitch] defaults in
                avatarsSwitch?.isOn = defaults.showAuthorAvatars
            }
            $0.observe(\.showImages, options: .initial) {
                [imagesSwitch] defaults in
                imagesSwitch?.isOn = defaults.showImages
            }
        }

        updatePreferredContentSize()
    }

    private func updatePreferredContentSize() {
        let preferredHeight = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        preferredContentSize = CGSize(width: 320, height: preferredHeight)
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
    }
    
    // MARK: UIAdaptivePresentationControllerDelegate
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    // MARK: Gunk

    required init?(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
}
