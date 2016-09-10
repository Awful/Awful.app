//  PunishmentCell.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Details a probation or ban.
final class PunishmentCell: UITableViewCell {
    /// A label that explains why the infraction occurred.
    let reasonLabel = UILabel()
    
    /**
        Returns the height of a cell.
     
        - parameter banReason: The reason for the ban that will be wrapped into several lines if necessary.
        - parameter width: The width of the cell.
     */
    class func rowHeightWithBanReason(_ banReason: String, width: CGFloat) -> CGFloat {
        let reasonInsets = UIEdgeInsets(top: 63, left: 10, bottom: 10, right: 30)
        let remainingWidth = width - reasonInsets.left - reasonInsets.right
        let reasonRect = (banReason as NSString).boundingRect(with: CGSize(width: remainingWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: reasonFontSize)], context: nil)
        return ceil(reasonRect.height) + reasonInsets.top + reasonInsets.bottom
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        
        contentView.autoresizingMask.formUnion(.flexibleWidth)
        
        imageView?.contentMode = .scaleAspectFit
        
        textLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        textLabel?.backgroundColor = .clear
        
        detailTextLabel?.font = UIFont.systemFont(ofSize: 13)
        detailTextLabel?.backgroundColor = .clear
        
        reasonLabel.numberOfLines = 0
        reasonLabel.font = UIFont.systemFont(ofSize: reasonFontSize)
        reasonLabel.backgroundColor = .clear
        reasonLabel.highlightedTextColor = textLabel?.highlightedTextColor
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
    
    override var backgroundColor: UIColor? {
        didSet {
            guard let color = backgroundColor else { return }
            let backgroundImage = PunishmentCell.backgroundImageWithColor(color)
            let backgroundView = self.backgroundView as? UIImageView ?? UIImageView()
            backgroundView.image = backgroundImage
            backgroundView.frame = CGRect(origin: .zero, size: contentView.bounds.size)
            self.backgroundView = backgroundView
        }
    }
    
    override func layoutSubviews() {
        guard let imageView = imageView, let textLabel = textLabel, let detailTextLabel = detailTextLabel else { return }
        
        let cellMargin = UIEdgeInsets(top: 5, left: 10, bottom: 10, right: 10)
        
        imageView.frame = CGRect(x: cellMargin.left, y: cellMargin.top - 1, width: 44, height: 44)
        
        let imageViewRightMargin: CGFloat = 10
        let imageViewBottomMargin: CGFloat = 12
        
        var textLabelFrame = CGRect.zero
        textLabelFrame.origin.x = imageView.frame.maxX + imageViewRightMargin
        textLabelFrame.origin.y = 9
        textLabelFrame.size.width = contentView.bounds.width - textLabelFrame.minX - cellMargin.right
        textLabelFrame.size.height = textLabel.font.lineHeight
        textLabel.frame = textLabelFrame
        detailTextLabel.frame = textLabelFrame.offsetBy(dx: 0, dy: textLabelFrame.height)
        
        let reasonLabelRightMargin: CGFloat = 32
        var reasonFrame = CGRect.zero
        reasonFrame.origin.x = cellMargin.left
        reasonFrame.origin.y = imageView.frame.maxY + imageViewBottomMargin
        reasonFrame.size.width = contentView.bounds.width - cellMargin.left - reasonLabelRightMargin
        reasonFrame.size.height = contentView.bounds.height - reasonFrame.minY - cellMargin.bottom
        reasonLabel.frame = reasonFrame
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
