//  TiltScrollSettingsView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import Combine
import UIKit

/// The tilt-to-scroll rows of the posts page settings sheet: a "Tilt to
/// Scroll" switch and, below it, a sensitivity slider, an "Invert Direction"
/// switch, and a "Set Zero Point" button that are only shown while tilt
/// scrolling is enabled.
final class TiltScrollSettingsView: UIStackView {

    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.tiltScrollEnabled) private var tiltScrollEnabled
    @FoilDefaultStorage(Settings.tiltScrollInverted) private var tiltScrollInverted
    @FoilDefaultStorage(Settings.tiltScrollSensitivity) private var tiltScrollSensitivity
    private var cancellables: Set<AnyCancellable> = []

    /// Set by the presenter; called when the user taps "Set Zero Point" so the
    /// tilt scroll manager adopts the device's current pose as neutral.
    var recalibrate: (() -> Void)?

    /// Called when rows are shown or hidden, so the containing sheet can
    /// update its preferred content size.
    var sizeDidChange: (() -> Void)?

    private let toggleLabel = UILabel()
    private let toggleSwitch = UISwitch()
    private let sensitivityLabel = UILabel()
    private let sensitivitySlider = UISlider()
    private let sensitivityRow = UIStackView()
    private let invertLabel = UILabel()
    private let invertSwitch = UISwitch()
    private let invertRow = UIStackView()
    private let zeroButton = UIButton(type: .system)

    init() {
        super.init(frame: .zero)

        axis = .vertical
        spacing = 16
        translatesAutoresizingMaskIntoConstraints = false

        toggleLabel.text = "Tilt to Scroll"
        toggleLabel.font = UIFont.preferredFont(forTextStyle: .body)

        toggleSwitch.isOn = tiltScrollEnabled
        toggleSwitch.addTarget(self, action: #selector(toggleTiltScroll(_:)), for: .valueChanged)

        let toggleRow = UIStackView(arrangedSubviews: [toggleLabel, toggleSwitch])
        toggleRow.axis = .horizontal
        toggleRow.distribution = .equalSpacing
        toggleRow.alignment = .center

        sensitivityLabel.text = "Sensitivity"
        sensitivityLabel.font = UIFont.preferredFont(forTextStyle: .body)
        sensitivityLabel.setContentHuggingPriority(.required, for: .horizontal)

        sensitivitySlider.minimumValue = 0
        sensitivitySlider.maximumValue = 1
        sensitivitySlider.value = Float(tiltScrollSensitivity)
        sensitivitySlider.isContinuous = true
        sensitivitySlider.addTarget(self, action: #selector(sensitivityDidChange(_:)), for: .valueChanged)

        sensitivityRow.addArrangedSubview(sensitivityLabel)
        sensitivityRow.addArrangedSubview(sensitivitySlider)
        sensitivityRow.axis = .horizontal
        sensitivityRow.spacing = 12
        sensitivityRow.alignment = .center
        sensitivityRow.isHidden = !tiltScrollEnabled

        invertLabel.text = "Invert Direction"
        invertLabel.font = UIFont.preferredFont(forTextStyle: .body)

        invertSwitch.isOn = tiltScrollInverted
        invertSwitch.addTarget(self, action: #selector(toggleTiltScrollInverted(_:)), for: .valueChanged)

        invertRow.addArrangedSubview(invertLabel)
        invertRow.addArrangedSubview(invertSwitch)
        invertRow.axis = .horizontal
        invertRow.distribution = .equalSpacing
        invertRow.alignment = .center
        invertRow.isHidden = !tiltScrollEnabled

        zeroButton.setTitle("Set Zero Point", for: .normal)
        zeroButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        zeroButton.addTarget(self, action: #selector(setTiltZeroPoint(_:)), for: .touchUpInside)
        zeroButton.isHidden = !tiltScrollEnabled
        zeroButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        addArrangedSubview(toggleRow)
        addArrangedSubview(sensitivityRow)
        addArrangedSubview(invertRow)
        addArrangedSubview(zeroButton)

        $tiltScrollEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                toggleSwitch.isOn = enabled
                sensitivityRow.isHidden = !enabled
                invertRow.isHidden = !enabled
                zeroButton.isHidden = !enabled
                sizeDidChange?()
            }
            .store(in: &cancellables)

        $tiltScrollSensitivity
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.sensitivitySlider.value = Float($0) }
            .store(in: &cancellables)

        $tiltScrollInverted
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.invertSwitch.isOn = $0 }
            .store(in: &cancellables)
    }

    func applyTheme(_ theme: Theme) {
        toggleLabel.textColor = theme["sheetTextColor"] ?? UIColor.label
        toggleSwitch.onTintColor = theme["settingsSwitchColor"]
        sensitivityLabel.textColor = theme["sheetTextColor"] ?? UIColor.label
        sensitivitySlider.minimumTrackTintColor = theme["settingsSwitchColor"]
        invertLabel.textColor = theme["sheetTextColor"] ?? UIColor.label
        invertSwitch.onTintColor = theme["settingsSwitchColor"]
    }

    @objc private func toggleTiltScroll(_ sender: UISwitch) {
        performHapticFeedback()
        tiltScrollEnabled = sender.isOn
    }

    @objc private func sensitivityDidChange(_ sender: UISlider) {
        tiltScrollSensitivity = Double(sender.value)
    }

    @objc private func toggleTiltScrollInverted(_ sender: UISwitch) {
        performHapticFeedback()
        tiltScrollInverted = sender.isOn
    }

    @objc private func setTiltZeroPoint(_ sender: UIButton) {
        performHapticFeedback()
        recalibrate?()
    }

    private func performHapticFeedback() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    required init(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
}
