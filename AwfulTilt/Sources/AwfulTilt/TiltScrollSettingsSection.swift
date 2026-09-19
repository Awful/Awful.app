//  TiltScrollSettingsSection.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import SwiftUI

/**
 The tilt-to-scroll rows of the posts page settings popover: a "Tilt to Scroll" toggle and, below it, a sensitivity slider, an "Invert Direction" toggle, and a "Set Zero Point" button that only appear while tilt scrolling is enabled.

 Drop it into a `VStack`; it lays out its rows as siblings of whatever surrounds it. Colours come from the `theme` environment value, so put it under `.themed()`. Toggles use whatever `toggleStyle` the container sets.
 */
public struct TiltScrollSettingsSection: View {

    @AppStorage(Settings.tiltScrollEnabled) private var tiltScrollEnabled
    @AppStorage(Settings.tiltScrollInverted) private var tiltScrollInverted
    @AppStorage(Settings.tiltScrollSensitivity) private var tiltScrollSensitivity
    @Environment(\.theme) private var theme

    /// Called when the user taps "Set Zero Point" so the tilt scroll manager adopts the device's current pose as neutral.
    private let recalibrate: () -> Void

    public init(recalibrate: @escaping () -> Void) {
        self.recalibrate = recalibrate
    }

    public var body: some View {
        Toggle(isOn: $tiltScrollEnabled) {
            Text("Tilt to Scroll", bundle: .module)
        }
        .tint(theme[color: "settingsSwitchColor"])

        if tiltScrollEnabled {
            HStack(spacing: 12) {
                Text("Sensitivity", bundle: .module)
                    .fixedSize()
                Slider(value: $tiltScrollSensitivity, in: 0...1)
                    .tint(theme[color: "settingsSwitchColor"])
            }

            Toggle(isOn: $tiltScrollInverted) {
                Text("Invert Direction", bundle: .module)
            }
            .tint(theme[color: "settingsSwitchColor"])

            Button(action: recalibrate) {
                Text("Set Zero Point", bundle: .module)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }
}
