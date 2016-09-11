//  ThreadTagView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class ThreadTagView: UIView {
    fileprivate let tagImageView = UIImageView()
    var tagImage: UIImage? {
        get { return tagImageView.image }
        set { tagImageView.image = newValue }
    }
    
    fileprivate let secondaryTagImageView = UIImageView()
    var secondaryTagImage: UIImage? {
        get { return secondaryTagImageView.image }
        set {
            if let
                image = newValue,
                let cgimage = image.cgImage
            {
                secondaryTagImageView.image = UIImage(cgImage: cgimage, scale: image.scale, orientation: image.imageOrientation)
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
        
        tagImageView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: tagImageView.trailingAnchor).isActive = true
        
        tagImageView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: tagImageView.bottomAnchor).isActive = true
        
        bottomAnchor.constraint(equalTo: secondaryTagImageView.bottomAnchor).isActive = true
        trailingAnchor.constraint(equalTo: secondaryTagImageView.trailingAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setTagBorderColor(_ borderColor: UIColor?, width: CGFloat) {
        guard let borderColor = borderColor , width > 0 else {
            secondaryTagImageView.layer.borderColor = nil
            secondaryTagImageView.layer.borderWidth = 0
            return
        }
        secondaryTagImageView.layer.borderColor = borderColor.cgColor
        secondaryTagImageView.layer.borderWidth = width
    }
}
