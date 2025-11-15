//  PostsPageSettingsViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import Combine
import UIKit

/// A PostsPageSettingsViewController is a modal view controller for changing settings specific to a posts page. By default it presents in a popover on all devices.
final class PostsPageSettingsViewController: ViewController, UIPopoverPresentationControllerDelegate {
    
    @FoilDefaultStorage(Settings.autoDarkTheme) private var automaticDarkTheme
    private var cancellables: Set<AnyCancellable> = []
    @FoilDefaultStorage(Settings.darkMode) private var darkMode
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.fontScale) private var fontScale
    @FoilDefaultStorage(Settings.immersionModeEnabled) private var immersionModeEnabled
    @FoilDefaultStorage(Settings.showAvatars) private var showAvatars
    @FoilDefaultStorage(Settings.loadImages) private var showImages

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
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        showAvatars = sender.isOn
    }

    @IBOutlet private var imagesSwitch: UISwitch!
    @IBAction private func toggleImages(_ sender: UISwitch) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        showImages = sender.isOn
    }
    
    @IBOutlet private var scaleTextLabel: UILabel!
    @IBOutlet private var scaleTextStepper: UIStepper!
    @IBAction private func scaleStepperDidChange(_ sender: UIStepper) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        fontScale = sender.value
    }
    
    @IBOutlet private var automaticDarkModeSwitch: UISwitch!
    @IBAction func toggleAutomaticDarkMode(_ sender: UISwitch) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        automaticDarkTheme = sender.isOn
    }

    @IBOutlet private var darkModeStack: UIStackView!
    @IBOutlet private var darkModeLabel: UILabel!
    @IBOutlet private var darkModeSwitch: UISwitch!
    @IBAction func toggleDarkMode(_ sender: UISwitch) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        darkMode = sender.isOn
    }
    
    private var immersionModeStack: UIStackView?
    private var immersionModeLabel: UILabel?
    private var immersionModeSwitch: UISwitch?
    
    @objc private func toggleImmersionMode(_ sender: UISwitch) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        immersionModeEnabled = sender.isOn
    }

    private lazy var fontScaleFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let autoDark = $automaticDarkTheme
        autoDark.receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                automaticDarkModeSwitch.isOn = $0
                darkModeStack.isHidden = $0
                darkModeLabel.isEnabled = !$0
                darkModeSwitch.isEnabled = !$0
            }
            .store(in: &cancellables)

        let manualDark = $darkMode
        manualDark.receive(on: RunLoop.main)
            .sink { [weak self] in self?.darkModeSwitch.isOn = $0 }
            .store(in: &cancellables)

        Publishers.Merge(
            autoDark.dropFirst(),
            manualDark /* no dropFirst(), we want to execute exactly once on load */
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.updatePreferredContentSize() }
        .store(in: &cancellables)

        $fontScale
            .receive(on: RunLoop.main)
            .sink { [weak self] fontScale in
                guard let self else { return }
                let percent = fontScaleFormatter.string(from: (fontScale / 100) as NSNumber) ?? ""
                let format = LocalizedString("settings.font-scale.title")
                scaleTextLabel.text = String(format: format, percent)
                scaleTextStepper.value = Double(fontScale)
            }
            .store(in: &cancellables)

        // Using RunLoop.main instead of DispatchQueue.main is intentional here.
        // This defers UI updates during scrolling (tracking mode) for better performance.
        // Settings toggles are not time-critical and can wait until scrolling completes.
        $showAvatars
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.avatarsSwitch?.isOn = $0 }
            .store(in: &cancellables)

        $showImages
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.imagesSwitch?.isOn = $0 }
            .store(in: &cancellables)

        $immersionModeEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.immersionModeSwitch?.isOn = $0 }
            .store(in: &cancellables)
        
        DispatchQueue.main.async { [weak self] in
            self?.setupImmersionModeUI()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreferredContentSize()
    }
    
    private func setupImmersionModeUI() {
        guard isViewLoaded, immersionModeStack == nil else { return }
        
        let label = UILabel()
        label.text = "Immersion Mode"
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = theme["sheetTextColor"] ?? UIColor.label
        immersionModeLabel = label
        
        let modeSwitch = UISwitch()
        modeSwitch.isOn = immersionModeEnabled
        modeSwitch.onTintColor = theme["settingsSwitchColor"]
        modeSwitch.addTarget(self, action: #selector(toggleImmersionMode(_:)), for: .valueChanged)
        immersionModeSwitch = modeSwitch
        
        let stack = UIStackView(arrangedSubviews: [label, modeSwitch])
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        immersionModeStack = stack
        
        if let darkModeStack = darkModeStack,
           let parentStack = darkModeStack.superview as? UIStackView {
            if let index = parentStack.arrangedSubviews.firstIndex(of: darkModeStack) {
                parentStack.insertArrangedSubview(stack, at: index + 1)
            } else {
                parentStack.addArrangedSubview(stack)
            }
        } else {
            view.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                stack.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
    }

    private func updatePreferredContentSize() {
        let preferredHeight = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        preferredContentSize = CGSize(width: 320, height: max(preferredHeight, 246))
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
        
        immersionModeLabel?.textColor = theme["sheetTextColor"] ?? UIColor.label
        immersionModeSwitch?.onTintColor = theme["settingsSwitchColor"]
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
