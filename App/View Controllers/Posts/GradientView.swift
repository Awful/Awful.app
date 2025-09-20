//  GradientView.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US

import AwfulTheming
import UIKit

/// A UIView subclass that uses CAGradientLayer as its backing layer.
/// This provides automatic frame management and proper animation support.
/// Automatically configures gradient based on the current theme.
final class GradientView: UIView {
    
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }
    
    /// Convenience accessor for the gradient layer.
    var gradientLayer: CAGradientLayer {
        layer as! CAGradientLayer
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureGradient()
    }
    
    /// Configure the gradient based on the current theme
    private func configureGradient() {
        let isDarkMode = Theme.defaultTheme()[string: "mode"] == "dark"

        if isDarkMode {
            // Black to clear gradient for dark themes
            gradientLayer.colors = [
                UIColor.black.cgColor,
                UIColor.black.withAlphaComponent(0.8).cgColor,
                UIColor.black.withAlphaComponent(0.4).cgColor,
                UIColor.clear.cgColor
            ]
            // Gradient locations - stronger at the top, fade to clear
            gradientLayer.locations = [0.0, 0.3, 0.7, 1.0]
        } else {
            // For light mode, use a very subtle white gradient that blends seamlessly
            gradientLayer.colors = [
                UIColor.white.withAlphaComponent(0.8).cgColor,
                UIColor.white.withAlphaComponent(0.6).cgColor,
                UIColor.white.withAlphaComponent(0.2).cgColor,
                UIColor.white.withAlphaComponent(0.02).cgColor,
                UIColor.clear.cgColor
            ]
            // Fade more quickly to maintain subtlety
            gradientLayer.locations = [0.0, 0.4, 0.7, 0.9, 1.0]
        }

        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
    }

    /// Update gradient when theme changes
    func themeDidChange() {
        configureGradient()
    }
}
