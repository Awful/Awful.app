//  ThemePicker.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Acts as a segmented control for themes.
final class ThemePicker: UIControl {
    /// The currently-selected theme's index, or UISegmentedControlNoSegment is no theme is selected.
    var selectedThemeIndex: Int = UISegmentedControlNoSegment {
        didSet {
            if oldValue != UISegmentedControlNoSegment {
                buttons[oldValue].isSelected = false
            }
            if selectedThemeIndex != UISegmentedControlNoSegment {
                buttons[selectedThemeIndex].isSelected = true
            }
        }
    }
    
    var isLoaded: Bool = false
    fileprivate var buttons: [UIButton] = []
    
    /**
        Insert a new theme.
     
        - parameter color: A color describing the theme. Set its accessibilityLabel to a descriptive name.
        - parameter index: Where to insert the theme.
     */
    func insertThemeWithColor(_ color: UIColor, atIndex index: Int) {
        let button = ThemeButton(themeColor: color)
        button.addTarget(self, action: #selector(didTapThemeButton), for: .touchUpInside)
        let index = min(index, subviews.count)
        insertSubview(button, at: index)
        buttons.append(button)
        
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func setDefaultThemeColor(color: UIColor) {
        subviews[0].removeFromSuperview()
        buttons.remove(at: 0)
        insertThemeWithColor(color, atIndex: 0)
    }
    
    @objc fileprivate func didTapThemeButton(_ button: UIButton) {
        selectedThemeIndex = buttons.index(of: button) ?? UISegmentedControlNoSegment
        sendActions(for: .valueChanged)
    }
    
    override func layoutSubviews() {
        guard let size = buttons.first?.intrinsicContentSize else { return }
        
        var buttonFrame = CGRect(origin: .zero, size: size)
        for button in buttons {
            button.frame = buttonFrame
            
            buttonFrame.origin.x = margin + buttonFrame.maxX
            if buttonFrame.maxX > bounds.maxX {
                buttonFrame.origin = CGPoint(x: 0, y: margin + buttonFrame.maxY)
            }
        }
    }
    
    override var intrinsicContentSize: CGSize {
        guard let size = buttons.first?.intrinsicContentSize else { return .zero }
        let maxWidth = bounds.width
        guard maxWidth >= size.width else {
            print("\(self) \(#function) can't even lay out a single button")
            return .zero
        }
        let remainingWidth = maxWidth - size.width
        let buttonsPerLine = 1 + Int(remainingWidth / (margin + size.width))
        let numberOfLines = buttons.count / buttonsPerLine + min(buttons.count % buttonsPerLine, 1)
        return CGSize(
            width: CGFloat(buttonsPerLine) * size.width + CGFloat(buttonsPerLine - 1) * margin,
            height: CGFloat(numberOfLines) * size.height + CGFloat(numberOfLines - 1) * margin)
    }
}

private let margin: CGFloat = 6
