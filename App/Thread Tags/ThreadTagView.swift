//  ThreadTagView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class ThreadTagView: UIView {
    private let tagImageView = UIImageView()
    var tagImage: UIImage? {
        get { return tagImageView.image }
        set { tagImageView.image = newValue }
    }
    
    private let secondaryTagImageView = UIImageView()
    var secondaryTagImage: UIImage? {
        get { return secondaryTagImageView.image }
        set {
            if let
                image = newValue,
                cgimage = image.CGImage
            {
                secondaryTagImageView.image = UIImage(CGImage: cgimage, scale: image.scale, orientation: image.imageOrientation)
            } else {
                secondaryTagImageView.image = newValue
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        tagImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tagImageView)
        
        secondaryTagImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(secondaryTagImageView)
        
        tagImageView.leadingAnchor.constraintEqualToAnchor(leadingAnchor).active = true
        trailingAnchor.constraintEqualToAnchor(tagImageView.trailingAnchor).active = true
        
        tagImageView.topAnchor.constraintEqualToAnchor(topAnchor).active = true
        bottomAnchor.constraintEqualToAnchor(tagImageView.bottomAnchor).active = true
        
        bottomAnchor.constraintEqualToAnchor(secondaryTagImageView.bottomAnchor).active = true
        trailingAnchor.constraintEqualToAnchor(secondaryTagImageView.trailingAnchor).active = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setTagBorderColor(borderColor: UIColor?, width: CGFloat) {
        guard let borderColor = borderColor where width > 0 else {
            secondaryTagImageView.layer.borderColor = nil
            secondaryTagImageView.layer.borderWidth = 0
            return
        }
        secondaryTagImageView.layer.borderColor = borderColor.CGColor
        secondaryTagImageView.layer.borderWidth = width
    }
}
