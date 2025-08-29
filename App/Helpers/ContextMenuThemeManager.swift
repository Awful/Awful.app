//  ContextMenuThemeManager.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US

import UIKit
import AwfulTheming

/// Manages window-level theme overrides to ensure context menus respect app theming
/// even when system appearance differs from app settings
final class ContextMenuThemeManager: NSObject {
    
    static let shared = ContextMenuThemeManager()
    
    private var originalWindowInterfaceStyles: [UIWindow: UIUserInterfaceStyle] = [:]
    private var isOverriding = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - Theme Override Management
    
    /// Set all app windows to match the app's theme mode permanently
    func ensureWindowsMatchAppTheme() {
        let appThemeMode = Theme.defaultTheme()[string: "mode"]
        let targetInterfaceStyle: UIUserInterfaceStyle = appThemeMode == "light" ? .light : .dark
        
        // Get all windows in all scenes
        let allWindows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        
        for window in allWindows {
            // Set to app's theme permanently - no need to store originals
            window.overrideUserInterfaceStyle = targetInterfaceStyle
        }
    }
    
    /// Restore original window interface styles
    func restoreWindowInterfaceStyles() {
        guard isOverriding else { return }
        isOverriding = false
        
        for (window, originalStyle) in originalWindowInterfaceStyles {
            window.overrideUserInterfaceStyle = originalStyle
        }
        originalWindowInterfaceStyles.removeAll()
    }
}
