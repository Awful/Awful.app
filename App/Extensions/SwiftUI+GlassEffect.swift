//  SwiftUI+GlassEffect.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import AwfulSettings
import Foil

extension View {
    /// Conditionally applies glass effect based on the user's liquid glass setting
    /// Uses iOS 26's native glass effect API with .identity to disable the effect
    @ViewBuilder
    func conditionalGlassEffect() -> some View {
        if #available(iOS 26.0, *) {
            ConditionalGlassEffectView(content: self)
        } else {
            self
        }
    }
    
    /// Conditionally applies glass effect with explicit control
    /// - Parameter isEnabled: Whether to enable the glass effect
    @ViewBuilder
    func conditionalGlassEffect(_ isEnabled: Bool) -> some View {
        if #available(iOS 26.0, *) {
            let _ = print("🔴 conditionalGlassEffect called with isEnabled = \(isEnabled)")
            if isEnabled {
                let _ = print("🔴 Applying .regular glass effect")
                self.glassEffect(.regular)
            } else {
                let _ = print("🔴 Trying .identity with much larger background to fully obscure glass")
                self
                    .glassEffect(.identity)
                    .padding(8) // Much larger padding to fully cover glass rim
                    .background(Color.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(-8) // Remove padding after background is applied
            }
        } else {
            self
        }
    }
}

/// Internal view that handles the conditional glass effect with settings integration
@available(iOS 26.0, *)
private struct ConditionalGlassEffectView<Content: View>: View {
    let content: Content
    @AppStorage(Settings.enableLiquidGlass.key) private var enableLiquidGlass: Bool = Settings.enableLiquidGlass.default
    
    var body: some View {
        let manualCheck = UserDefaults.standard.bool(forKey: Settings.enableLiquidGlass.key)
        let _ = print("🔵 ConditionalGlassEffectView: @AppStorage value = \(enableLiquidGlass), UserDefaults direct check = \(manualCheck), setting key = \(Settings.enableLiquidGlass.key)")
        
        if enableLiquidGlass {
            content
                .glassEffect(.regular)
                .onAppear {
                    print("🔵 ConditionalGlassEffectView: APPLYING REGULAR glass effect")
                }
        } else {
            content
                .onAppear {
                    print("🔵 ConditionalGlassEffectView: NO glass effect applied - setting is disabled")
                }
        }
    }
}
