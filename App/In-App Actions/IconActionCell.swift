//  IconActionCell.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class IconActionCell: UICollectionViewCell {
    let iconImageView = UIImageView()
    let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        iconImageView.contentMode = .center
        contentView.addSubview(iconImageView)
        
        titleLabel.font = UIFont.systemFont(ofSize: 12)
        titleLabel.textColor = .white
        titleLabel.backgroundColor = .clear
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center
        contentView.addSubview(titleLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isHighlighted: Bool {
        didSet {
            iconImageView.tintColor = isHighlighted ? .white : nil
        }
    }
    
    override func layoutSubviews() {
        var (iconFrame, titleFrame) = contentView.bounds.divided(atDistance: imageSize.height, from: .minYEdge)
        
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
