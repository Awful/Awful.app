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
    @FoilDefaultStorage(Settings.endlessScrollPosts) private var endlessScrollPosts
    @FoilDefaultStorage(Settings.fontScale) private var fontScale
    @FoilDefaultStorage(Settings.immersiveModeEnabled) private var immersiveModeEnabled
    @FoilDefaultStorage(Settings.showAvatars) private var showAvatars
    @FoilDefaultStorage(Settings.loadImages) private var showImages
    @FoilDefaultStorage(Settings.tiltScrollEnabled) private var tiltScrollEnabled
    @FoilDefaultStorage(Settings.tiltScrollInverted) private var tiltScrollInverted
    @FoilDefaultStorage(Settings.tiltScrollSensitivity) private var tiltScrollSensitivity

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
        performHapticFeedback()
        showAvatars = sender.isOn
    }

    @IBOutlet private var imagesSwitch: UISwitch!
    @IBAction private func toggleImages(_ sender: UISwitch) {
        performHapticFeedback()
        showImages = sender.isOn
    }

    @IBOutlet private var scaleTextLabel: UILabel!
    @IBOutlet private var scaleTextStepper: UIStepper!
    @IBAction private func scaleStepperDidChange(_ sender: UIStepper) {
        performHapticFeedback()
        fontScale = sender.value
    }

    @IBOutlet private var automaticDarkModeSwitch: UISwitch!
    @IBAction func toggleAutomaticDarkMode(_ sender: UISwitch) {
        performHapticFeedback()
        automaticDarkTheme = sender.isOn
    }

    @IBOutlet private var darkModeStack: UIStackView!
    @IBOutlet private var darkModeLabel: UILabel!
    @IBOutlet private var darkModeSwitch: UISwitch!
    @IBAction func toggleDarkMode(_ sender: UISwitch) {
        performHapticFeedback()
        darkMode = sender.isOn
    }

    private var immersiveModeStack: UIStackView?
    private var immersiveModeLabel: UILabel?
    private var immersiveModeSwitch: UISwitch?

    @objc private func toggleImmersiveMode(_ sender: UISwitch) {
        performHapticFeedback()
        immersiveModeEnabled = sender.isOn
    }

    private var endlessScrollButton: UIButton?

    @objc private func exitEndlessScroll(_ sender: UIButton) {
        performHapticFeedback()
        endlessScrollPosts = false
        dismiss(animated: true)
    }

    private var tiltScrollStack: UIStackView?
    private var tiltScrollLabel: UILabel?
    private var tiltScrollSwitch: UISwitch?
    private var tiltSensitivityStack: UIStackView?
    private var tiltSensitivityLabel: UILabel?
    private var tiltSensitivitySlider: UISlider?
    private var tiltInvertStack: UIStackView?
    private var tiltInvertLabel: UILabel?
    private var tiltInvertSwitch: UISwitch?
    private var tiltZeroButton: UIButton?

    /// Set by the presenter; called when the user taps "Set Zero Point" so the
    /// tilt scroll manager adopts the device's current pose as neutral.
    var tiltScrollRecalibrate: (() -> Void)?

    @objc private func toggleTiltScroll(_ sender: UISwitch) {
        performHapticFeedback()
        tiltScrollEnabled = sender.isOn
    }

    @objc private func tiltSensitivityDidChange(_ sender: UISlider) {
        tiltScrollSensitivity = Double(sender.value)
    }

    @objc private func toggleTiltScrollInverted(_ sender: UISwitch) {
        performHapticFeedback()
        tiltScrollInverted = sender.isOn
    }

    @objc private func setTiltZeroPoint(_ sender: UIButton) {
        performHapticFeedback()
        tiltScrollRecalibrate?()
    }

    // MARK: - Helper Methods

    private func performHapticFeedback() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
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

        $immersiveModeEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.immersiveModeSwitch?.isOn = $0 }
            .store(in: &cancellables)

        $endlessScrollPosts
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                endlessScrollButton?.isHidden = !enabled
                updatePreferredContentSize()
            }
            .store(in: &cancellables)

        $tiltScrollEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                tiltScrollSwitch?.isOn = enabled
                tiltSensitivityStack?.isHidden = !enabled
                tiltInvertStack?.isHidden = !enabled
                tiltZeroButton?.isHidden = !enabled
                updatePreferredContentSize()
            }
            .store(in: &cancellables)

        $tiltScrollSensitivity
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.tiltSensitivitySlider?.value = Float($0) }
            .store(in: &cancellables)

        $tiltScrollInverted
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.tiltInvertSwitch?.isOn = $0 }
            .store(in: &cancellables)

        DispatchQueue.main.async { [weak self] in
            self?.setupImmersiveModeUI()
            self?.setupEndlessScrollUI()
            self?.setupTiltScrollUI()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreferredContentSize()
    }
    
    private func setupImmersiveModeUI() {
        guard isViewLoaded, immersiveModeStack == nil else { return }
        
        let label = UILabel()
        label.text = "Immersive Mode"
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = theme["sheetTextColor"] ?? UIColor.label
        immersiveModeLabel = label
        
        let modeSwitch = UISwitch()
        modeSwitch.isOn = immersiveModeEnabled
        modeSwitch.onTintColor = theme["settingsSwitchColor"]
        modeSwitch.addTarget(self, action: #selector(toggleImmersiveMode(_:)), for: .valueChanged)
        immersiveModeSwitch = modeSwitch
        
        let stack = UIStackView(arrangedSubviews: [label, modeSwitch])
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        immersiveModeStack = stack
        
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

    /// Adds an "Exit Endless Scroll" row below the immersive mode row. Hidden unless endless scroll is on — it's the way back to the paging controls, which are hidden while endless scrolling.
    private func setupEndlessScrollUI() {
        guard isViewLoaded, endlessScrollButton == nil else { return }

        let button = UIButton(type: .system)
        button.setTitle("Exit Endless Scroll", for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.addTarget(self, action: #selector(exitEndlessScroll(_:)), for: .touchUpInside)
        button.isHidden = !endlessScrollPosts
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        endlessScrollButton = button

        if let anchorStack = immersiveModeStack ?? darkModeStack,
           let parentStack = anchorStack.superview as? UIStackView {
            if let index = parentStack.arrangedSubviews.firstIndex(of: anchorStack) {
                parentStack.insertArrangedSubview(button, at: index + 1)
            } else {
                parentStack.addArrangedSubview(button)
            }
        }

        updatePreferredContentSize()
    }

    /// Adds a "Tilt to Scroll" switch row and, below it, a sensitivity slider
    /// row that's only shown while tilt scrolling is enabled.
    private func setupTiltScrollUI() {
        guard isViewLoaded, tiltScrollStack == nil else { return }

        let label = UILabel()
        label.text = "Tilt to Scroll"
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = theme["sheetTextColor"] ?? UIColor.label
        tiltScrollLabel = label

        let tiltSwitch = UISwitch()
        tiltSwitch.isOn = tiltScrollEnabled
        tiltSwitch.onTintColor = theme["settingsSwitchColor"]
        tiltSwitch.addTarget(self, action: #selector(toggleTiltScroll(_:)), for: .valueChanged)
        tiltScrollSwitch = tiltSwitch

        let toggleStack = UIStackView(arrangedSubviews: [label, tiltSwitch])
        toggleStack.axis = .horizontal
        toggleStack.distribution = .equalSpacing
        toggleStack.alignment = .center
        toggleStack.translatesAutoresizingMaskIntoConstraints = false
        tiltScrollStack = toggleStack

        let sensitivityLabel = UILabel()
        sensitivityLabel.text = "Sensitivity"
        sensitivityLabel.font = UIFont.preferredFont(forTextStyle: .body)
        sensitivityLabel.textColor = theme["sheetTextColor"] ?? UIColor.label
        sensitivityLabel.setContentHuggingPriority(.required, for: .horizontal)
        tiltSensitivityLabel = sensitivityLabel

        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = Float(tiltScrollSensitivity)
        slider.isContinuous = true
        slider.minimumTrackTintColor = theme["settingsSwitchColor"]
        slider.addTarget(self, action: #selector(tiltSensitivityDidChange(_:)), for: .valueChanged)
        tiltSensitivitySlider = slider

        let sliderStack = UIStackView(arrangedSubviews: [sensitivityLabel, slider])
        sliderStack.axis = .horizontal
        sliderStack.spacing = 12
        sliderStack.alignment = .center
        sliderStack.translatesAutoresizingMaskIntoConstraints = false
        sliderStack.isHidden = !tiltScrollEnabled
        tiltSensitivityStack = sliderStack

        let invertLabel = UILabel()
        invertLabel.text = "Invert Direction"
        invertLabel.font = UIFont.preferredFont(forTextStyle: .body)
        invertLabel.textColor = theme["sheetTextColor"] ?? UIColor.label
        tiltInvertLabel = invertLabel

        let invertSwitch = UISwitch()
        invertSwitch.isOn = tiltScrollInverted
        invertSwitch.onTintColor = theme["settingsSwitchColor"]
        invertSwitch.addTarget(self, action: #selector(toggleTiltScrollInverted(_:)), for: .valueChanged)
        tiltInvertSwitch = invertSwitch

        let invertStack = UIStackView(arrangedSubviews: [invertLabel, invertSwitch])
        invertStack.axis = .horizontal
        invertStack.distribution = .equalSpacing
        invertStack.alignment = .center
        invertStack.translatesAutoresizingMaskIntoConstraints = false
        invertStack.isHidden = !tiltScrollEnabled
        tiltInvertStack = invertStack

        let zeroButton = UIButton(type: .system)
        zeroButton.setTitle("Set Zero Point", for: .normal)
        zeroButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        zeroButton.addTarget(self, action: #selector(setTiltZeroPoint(_:)), for: .touchUpInside)
        zeroButton.isHidden = !tiltScrollEnabled
        zeroButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        tiltZeroButton = zeroButton

        if let anchor: UIView = endlessScrollButton ?? immersiveModeStack ?? darkModeStack,
           let parentStack = anchor.superview as? UIStackView {
            if let index = parentStack.arrangedSubviews.firstIndex(of: anchor) {
                parentStack.insertArrangedSubview(toggleStack, at: index + 1)
                parentStack.insertArrangedSubview(sliderStack, at: index + 2)
                parentStack.insertArrangedSubview(invertStack, at: index + 3)
                parentStack.insertArrangedSubview(zeroButton, at: index + 4)
            } else {
                parentStack.addArrangedSubview(toggleStack)
                parentStack.addArrangedSubview(sliderStack)
                parentStack.addArrangedSubview(invertStack)
                parentStack.addArrangedSubview(zeroButton)
            }
        }

        updatePreferredContentSize()
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
        
        immersiveModeLabel?.textColor = theme["sheetTextColor"] ?? UIColor.label
        immersiveModeSwitch?.onTintColor = theme["settingsSwitchColor"]

        tiltScrollLabel?.textColor = theme["sheetTextColor"] ?? UIColor.label
        tiltScrollSwitch?.onTintColor = theme["settingsSwitchColor"]
        tiltSensitivityLabel?.textColor = theme["sheetTextColor"] ?? UIColor.label
        tiltSensitivitySlider?.minimumTrackTintColor = theme["settingsSwitchColor"]
        tiltInvertLabel?.textColor = theme["sheetTextColor"] ?? UIColor.label
        tiltInvertSwitch?.onTintColor = theme["settingsSwitchColor"]
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
