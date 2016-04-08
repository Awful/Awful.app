//  IconActionCell.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class IconActionCell: UICollectionViewCell {
    let iconImageView = UIImageView()
    let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        iconImageView.contentMode = .Center
        contentView.addSubview(iconImageView)
        
        titleLabel.font = UIFont.systemFontOfSize(12)
        titleLabel.textColor = .whiteColor()
        titleLabel.backgroundColor = .clearColor()
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .Center
        contentView.addSubview(titleLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var highlighted: Bool {
        didSet {
            iconImageView.tintColor = highlighted ? .whiteColor() : nil
        }
    }
    
    override func layoutSubviews() {
        var (iconFrame, titleFrame) = contentView.bounds.divide(imageSize.height, fromEdge: .MinYEdge)
        
        iconFrame.origin.x += (iconFrame.width - imageSize.width) / 2
        iconFrame.size.width = imageSize.width
        iconImageView.frame = iconFrame
        
        titleLabel.frame = titleFrame
        titleLabel.sizeToFit()
        titleFrame.size.height = titleLabel.bounds.height
        titleLabel.frame = titleFrame
    }
}

private let imageSize = CGSize(width: 56, height: 40)
