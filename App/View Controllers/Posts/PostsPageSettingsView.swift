//  PostsPageSettingsView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulSettingsUI
import AwfulTheming
import AwfulTilt
import SwiftUI

/**
 The posts page's settings popover: the handful of settings you're likely to change while reading, mirroring their rows on the Settings tab.

 Sized to its content at a fixed width, so the hosting controller can hand the size straight to the popover.
 */
struct PostsPageSettingsView: View {

    /// Dismisses the popover. Used after "Exit Endless Scroll", which brings the paging controls back.
    let dismiss: () -> Void

    /// Called when the user taps "Set Zero Point" so the tilt scroll manager adopts the device's current pose as neutral.
    let recalibrateTiltScroll: () -> Void

    var body: some View {
        PostsPageSettingsForm(dismiss: dismiss, recalibrateTiltScroll: recalibrateTiltScroll)
            .themed()
    }
}

/// Reads the theme that `PostsPageSettingsView` sets up.
private struct PostsPageSettingsForm: View {

    static let width: CGFloat = 320

    let dismiss: () -> Void
    let recalibrateTiltScroll: () -> Void

    @AppStorage(Settings.autoDarkTheme) private var automaticDarkMode
    @AppStorage(Settings.darkMode) private var darkMode
    @AppStorage(Settings.enableHaptics) private var enableHaptics
    @AppStorage(Settings.endlessScrollPosts) private var endlessScrollPosts
    @AppStorage(Settings.fontScale) private var fontScale
    @AppStorage(Settings.immersiveModeEnabled) private var immersiveModeEnabled
    @AppStorage(Settings.loadImages) private var loadImages
    @AppStorage(Settings.showAvatars) private var showAvatars
    @SwiftUI.Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Text("Settings")
                .foregroundColor(theme[color: "sheetTitleColor"])
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(theme[color: "sheetTitleBackgroundColor"])

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 20) {
                    Toggle("Avatars", isOn: $showAvatars)
                    Toggle("Images", isOn: $loadImages)
                }

                Stepper(value: $fontScale, in: 50...200, step: 10) {
                    Text(fontScaleTitle)
                }
                .onChange(of: fontScale) { _ in performHapticFeedback() }

                Toggle("Automatic Dark Mode", isOn: $automaticDarkMode)

                if !automaticDarkMode {
                    Toggle("Dark Mode", isOn: $darkMode)
                }

                Toggle("Immersive Mode", isOn: $immersiveModeEnabled)

                if endlessScrollPosts {
                    // The way back to the paging controls, which are hidden while endless scrolling.
                    Button {
                        performHapticFeedback()
                        endlessScrollPosts = false
                        dismiss()
                    } label: {
                        Text("Exit Endless Scroll")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }

                TiltScrollSettingsSection(recalibrate: {
                    performHapticFeedback()
                    recalibrateTiltScroll()
                })
            }
            .tint(theme[color: "settingsSwitchColor"])
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: Self.width)
        .font(.body)
        .foregroundColor(theme[color: "sheetTextColor"])
        .toggleStyle(.hapticSwitch)
        .buttonStyle(SheetButtonStyle(color: theme[color: "tintColor"]))
        .background(theme[color: "sheetBackgroundColor"])
    }

    private var fontScaleTitle: String {
        let percent = Self.percentFormatter.string(from: (fontScale / 100) as NSNumber) ?? ""
        return String(format: LocalizedString("settings.font-scale.title"), percent)
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()

    private func performHapticFeedback() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

/// A plain text button in the theme's tint colour, so buttons stand apart from the sheet's labels even though the whole form sets a text colour.
private struct SheetButtonStyle: ButtonStyle {
    let color: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color)
            .opacity(configuration.isPressed ? 0.4 : 1)
    }
}
