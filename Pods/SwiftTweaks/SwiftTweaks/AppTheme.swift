//
//  AppTheme.swift
//  SwiftTweaks
//
//  Created by Bryan Clark on 4/6/16.
//  Copyright © 2016 Khan Academy. All rights reserved.
//

import UIKit

/// A central "palette" so to help keep our design consistent.
internal struct AppTheme {
	struct Colors {
		fileprivate struct Palette {
			static let whiteColor = UIColor.white
			static let blackColor = UIColor.black
			static let grayColor = UIColor(hex: 0x8E8E93)
			static let pageBackground1 = UIColor(hex: 0xF8F8F8)
			static let touchHighlight = UIColor(hex: 0xF2F2F2)

			static let tintColor = UIColor(hex: 0x007AFF)
			static let tintColorPressed = UIColor(hex: 0x084BC1)
			static let controlGrayscale = UIColor.darkGray

			static let secondaryControl = UIColor(hex: 0xC8C7CC)
			static let secondaryControlPressed = UIColor(hex: 0xAFAFB3)

			static let destructiveRed = UIColor(hex: 0xC90911)
		}

		static let sectionHeaderTitleColor = Palette.grayColor

		static let textPrimary = Palette.blackColor

		static let controlTinted = Palette.tintColor
		static let controlTintedPressed = Palette.tintColorPressed
		static let controlDisabled = Palette.secondaryControl
		static let controlDestructive = Palette.destructiveRed
		static let controlSecondary = Palette.secondaryControl
		static let controlSecondaryPressed = Palette.secondaryControlPressed
		static let controlGrayscale = Palette.controlGrayscale

		static let floatingTweakGroupNavBG = Palette.pageBackground1

		static let tableSeparator = Palette.secondaryControl
		static let tableCellTouchHighlight = Palette.touchHighlight

		static let debugRed = UIColor.red.withAlphaComponent(0.3)
		static let debugYellow = UIColor.yellow.withAlphaComponent(0.3)
		static let debugBlue = UIColor.blue.withAlphaComponent(0.3)

	}

	struct Fonts {
		static let sectionHeaderTitleFont: UIFont = .preferredFont(forTextStyle: UIFont.TextStyle.body)
	}

	struct Shadows {
		static let floatingShadowColor = Colors.Palette.blackColor.cgColor
		static let floatingShadowOpacity: Float = 0.6
		static let floatingShadowOffset = CGSize(width: 0, height: 1)
		static let floatingShadowRadius: CGFloat = 4

		static let floatingNavShadowColor = floatingShadowColor
		static let floatingNavShadowOpacity: Float = 0.1
		static let floatingNavShadowOffset = floatingShadowOffset
		static let floatingNavShadowRadius: CGFloat = 0
	}
}
