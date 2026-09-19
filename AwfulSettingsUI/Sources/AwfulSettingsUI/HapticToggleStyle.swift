//  HapticToggleStyle.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import SwiftUI
import UIKit

/**
 The standard switch, plus a medium impact when it flips and the "Enable Haptics" setting is on.

 Apply it once to a container (`.toggleStyle(.hapticSwitch)`) so every toggle inside buzzes the same way and none of them has to know about haptics.
 */
public struct HapticToggleStyle: ToggleStyle {

    @AppStorage(Settings.enableHaptics) private var enableHaptics

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Toggle(isOn: configuration.$isOn) { EmptyView() }
                .labelsHidden()
                .toggleStyle(.switch) // Explicit, or the inner toggle would pick this style up from the environment and recurse.
        }
        .onChange(of: configuration.isOn) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }
}

public extension ToggleStyle where Self == HapticToggleStyle {
    /// A switch that gives medium haptic feedback when it flips, if the user has enabled haptics.
    static var hapticSwitch: HapticToggleStyle { .init() }
}
