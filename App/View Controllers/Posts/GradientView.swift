//  GradientView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US

import AwfulTheming
import UIKit

/// A UIView subclass that uses CAGradientLayer as its backing layer. Fades from the theme's
/// mode colour (black in a dark theme, white in a light one) to clear, unless `contentColor`
/// says the content beneath is the other way round.
final class GradientView: UIView {
    
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    private var gradientLayer: CAGradientLayer {
        layer as! CAGradientLayer
    }

    /// The `.black`/`.white` a `ContentContrastSampler` decided for the strip beneath this view,
    /// or nil to follow the theme's mode. A light gradient goes with black content colour
    /// (light content) and a dark one with white. Changes cross-dissolve, like the title.
    var contentColor: UIColor? {
        didSet {
            guard contentColor != oldValue else { return }
            UIView.transition(with: self, duration: ContentContrastSampler.flipDuration, options: [.transitionCrossDissolve, .beginFromCurrentState]) {
                self.configureGradient()
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureGradient()
    }
    
    private func configureGradient() {
        let isDarkMode: Bool
        switch contentColor {
        case .white?: isDarkMode = true
        case .black?: isDarkMode = false
        default: isDarkMode = Theme.defaultTheme()[string: "mode"] == "dark"
        }

        if isDarkMode {
            gradientLayer.colors = [
                UIColor.black.cgColor,
                UIColor.black.withAlphaComponent(0.8).cgColor,
                UIColor.black.withAlphaComponent(0.4).cgColor,
                UIColor.clear.cgColor
            ]
            gradientLayer.locations = [0.0, 0.3, 0.7, 1.0]
        } else {
            gradientLayer.colors = [
                UIColor.white.withAlphaComponent(0.8).cgColor,
                UIColor.white.withAlphaComponent(0.6).cgColor,
                UIColor.white.withAlphaComponent(0.2).cgColor,
                UIColor.white.withAlphaComponent(0.02).cgColor,
                UIColor.clear.cgColor
            ]
            gradientLayer.locations = [0.0, 0.4, 0.7, 0.9, 1.0]
        }

        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
    }

    func themeDidChange() {
        configureGradient()
    }
}
