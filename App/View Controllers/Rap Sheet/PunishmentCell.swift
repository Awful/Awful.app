//  PunishmentCell.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Details a probation or ban.
final class PunishmentCell: UICollectionViewListCell {
    static let reasonFont = UIFont.systemFont(ofSize: reasonFontSize)
    static let reasonInsets = UIEdgeInsets(top: 63, left: 10, bottom: 10, right: 30)

    let iconView = UIImageView()
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    /// A label that explains why the infraction occurred.
    let reasonLabel = UILabel()

    /**
        Returns the height of a cell.

        - parameter banReason: The reason for the ban that will be wrapped into several lines if necessary.
        - parameter width: The width of the cell.
     */
    class func rowHeightWithBanReason(_ banReason: NSAttributedString, width: CGFloat) -> CGFloat {
        let reasonInsets = PunishmentCell.reasonInsets
        let remainingWidth = width - reasonInsets.left - reasonInsets.right
        let reasonRect = (banReason).boundingRect(with: CGSize(width: remainingWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil)
        return ceil(reasonRect.height) + reasonInsets.top + reasonInsets.bottom
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        // Use the cell's `backgroundView` (set via `bubbleColor`) for the notched
        // bubble; clear the default backgroundConfiguration so it doesn't paint
        // over our backgroundView.
        backgroundConfiguration = UIBackgroundConfiguration.clear()

        iconView.contentMode = .scaleAspectFit
        contentView.addSubview(iconView)

        titleLabel.font = UIFont.boldSystemFont(ofSize: 15)
        titleLabel.backgroundColor = .clear
        contentView.addSubview(titleLabel)

        subtitleLabel.font = UIFont.systemFont(ofSize: 13)
        subtitleLabel.backgroundColor = .clear
        contentView.addSubview(subtitleLabel)

        reasonLabel.numberOfLines = 0
        reasonLabel.font = PunishmentCell.reasonFont
        reasonLabel.backgroundColor = .clear
        reasonLabel.highlightedTextColor = titleLabel.highlightedTextColor
        contentView.addSubview(reasonLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate static let backgroundImageCache: NSCache<UIColor, UIImage> = {
        let cache = NSCache<UIColor, UIImage>()
        cache.name = "PunishmentCell background image cache"
        return cache
    }()

    fileprivate class func backgroundImageWithColor(_ color: UIColor) -> UIImage {
        if let image = backgroundImageCache.object(forKey: color) {
            return image
        }

        let size = CGSize(width: 40, height: 56)
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        defer { UIGraphicsEndImageContext() }
        let context = UIGraphicsGetCurrentContext()!

        let topColor = color
        let shadowColor = UIColor(white: 0.5, alpha: 0.2)
        let bottomColor = bottomColorForTopColor(topColor)

        // Subtract 2: 1 for shadow, 1 for resizable part.
        let topHalf = CGRect(x: 0, y: 0, width: size.width, height: size.height - 2)

        context.withGState {
            context.setFillColor(bottomColor.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }

        context.withGState {
            // For whatever reason drawing a shadow in the little triangular notch draws the shadow all the way down, like a stripe. We clip first to prevent the stripe.
            context.clip(to: topHalf.insetBy(dx: 0, dy: -1))

            context.move(to: CGPoint(x: topHalf.minX, y: topHalf.minY))
            context.addLine(to: CGPoint(x: topHalf.minX, y: topHalf.maxY))
            context.addLine(to: CGPoint(x: topHalf.minX + 25, y: topHalf.maxY))
            context.addLine(to: CGPoint(x: topHalf.minX + 31, y: topHalf.maxY - 4))
            context.addLine(to: CGPoint(x: topHalf.minX + 37, y: topHalf.maxY))
            context.addLine(to: CGPoint(x: topHalf.maxX, y: topHalf.maxY))
            context.addLine(to: CGPoint(x: topHalf.maxX, y: topHalf.minY))
            context.setFillColor(topColor.cgColor)
            context.setShadow(offset: CGSize(width: 0, height: 1), blur: 1, color: shadowColor.cgColor)
            context.fillPath()
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        let capInsets = UIEdgeInsets(top: size.height - 1, left: size.width - 1, bottom: 0, right: 0)
        guard let backgroundImage = image?.resizableImage(withCapInsets: capInsets) else { fatalError("couldn't get image") }
        backgroundImageCache.setObject(backgroundImage, forKey: color)
        return backgroundImage
    }

    /// Color of the notched-bubble backgroundView. The notched gradient image is
    /// rebuilt (cached by color) and assigned to `backgroundView`.
    var bubbleColor: UIColor? {
        didSet {
            guard let color = bubbleColor else {
                backgroundView = nil
                return
            }
            let backgroundImage = PunishmentCell.backgroundImageWithColor(color)
            let bgView = (backgroundView as? UIImageView) ?? UIImageView()
            bgView.image = backgroundImage
            if backgroundView !== bgView {
                backgroundView = bgView
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cellMargin = UIEdgeInsets(top: 5, left: 10, bottom: 10, right: 10)

        iconView.frame = CGRect(x: cellMargin.left, y: cellMargin.top - 1, width: 44, height: 44)

        let imageViewRightMargin: CGFloat = 10
        let imageViewBottomMargin: CGFloat = 12

        var titleFrame = CGRect.zero
        titleFrame.origin.x = iconView.frame.maxX + imageViewRightMargin
        titleFrame.origin.y = 9
        titleFrame.size.width = contentView.bounds.width - titleFrame.minX - cellMargin.right
        titleFrame.size.height = titleLabel.font.lineHeight
        titleLabel.frame = titleFrame
        subtitleLabel.frame = titleFrame.offsetBy(dx: 0, dy: titleFrame.height)

        let reasonLabelRightMargin: CGFloat = 32
        var reasonFrame = CGRect.zero
        reasonFrame.origin.x = cellMargin.left
        reasonFrame.origin.y = iconView.frame.maxY + imageViewBottomMargin
        reasonFrame.size.width = contentView.bounds.width - cellMargin.left - reasonLabelRightMargin
        reasonFrame.size.height = contentView.bounds.height - reasonFrame.minY - cellMargin.bottom
        reasonLabel.frame = reasonFrame
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let width = layoutAttributes.size.width
        let height = PunishmentCell.rowHeightWithBanReason(reasonLabel.attributedText ?? NSAttributedString(), width: width)
        attributes.size = CGSize(width: width, height: height)
        return attributes
    }
}

private let reasonFontSize: CGFloat = 15

private func bottomColorForTopColor(_ topColor: UIColor) -> UIColor {
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    guard topColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { fatalError("\(#function) couldn't convert color \(topColor)") }

    if brightness >= 0.5 {
        brightness -= 0.05
    } else {
        brightness += 0.05
    }

    return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
}
