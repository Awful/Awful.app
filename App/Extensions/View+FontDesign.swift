//  View+FontDesign.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import AwfulTheming

extension View {
    @ViewBuilder
    func applyFontDesign(if condition: Bool) -> some View {
        if #available(iOS 16.1, *) {
            self.fontDesign(condition ? .rounded : .default)
        } else {
            self
        }
    }
    
    /// Applies theme-based post title font styling based on device type
    func postTitleFont(theme: Theme) -> some View {
        let baseStyle: Font.TextStyle = .callout
        let device = UIDevice.current.userInterfaceIdiom
        
        let sizeAdjustment: Double
        let fontWeight: Font.Weight
        
        switch device {
        case .pad:
            sizeAdjustment = theme[double: "postTitleFontSizeAdjustmentPad"] ?? 0
            let weightString = theme["postTitleFontWeightPad"] ?? "medium"
            fontWeight = FontWeight(rawValue: weightString)?.swiftUIWeight ?? .medium
        default:
            sizeAdjustment = theme[double: "postTitleFontSizeAdjustmentPhone"] ?? -1
            let weightString = theme["postTitleFontWeightPhone"] ?? "medium"
            fontWeight = FontWeight(rawValue: weightString)?.swiftUIWeight ?? .medium
        }
        
        let adjustedFont = Font.system(baseStyle).weight(fontWeight)
        
        // Apply size adjustment similar to UIKit
        if sizeAdjustment != 0 {
            let adjustedSize = UIFont.preferredFont(forTextStyle: .callout).pointSize + CGFloat(sizeAdjustment)
            return self.font(.system(size: adjustedSize, weight: fontWeight))
        } else {
            return self.font(adjustedFont)
        }
    }
}

// MARK: - FontWeight SwiftUI Support
extension FontWeight {
    /// Maps AwfulTheming FontWeight to SwiftUI Font.Weight
    var swiftUIWeight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}
