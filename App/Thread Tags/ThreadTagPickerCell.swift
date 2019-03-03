//  ThreadTagPickerCell.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Represents a thread tag in a ThreadTagPickerViewController.
final class ThreadTagPickerCell: UICollectionViewCell {
    
    private let imageNameLabel: UILabel = {
        let imageNameLabel = UILabel()
        imageNameLabel.backgroundColor = UIColor(white: 1, alpha: 0.75)
        imageNameLabel.minimumScaleFactor = 0.5
        imageNameLabel.numberOfLines = 0
        imageNameLabel.lineBreakMode = .byCharWrapping
        return imageNameLabel
    }()
    
    private let selectedIcon: UIImageView = {
        let selectedIcon = UIImageView(image: UIImage(named: "selected-tick-icon"))
        selectedIcon.isHidden = true
        return selectedIcon
    }()
    
    private let tagImageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.addSubview(tagImageView, constrainEdges: .all)
        contentView.addSubview(imageNameLabel, constrainEdges: .all)
        contentView.addSubview(selectedIcon, constrainEdges: [.bottom, .right])
    }
    
    // MARK: Selected state
    
    override var isSelected: Bool {
        didSet { updateForIsSelected() }
    }
    
    private func updateForIsSelected() {
        selectedIcon.isHidden = !isSelected
    }
    
    // MARK: Configuration
    
    private func commonConfig() {
        imageNameLabel.isHidden = true
        updateForIsSelected()
    }
    
    func configure(tagImageName: String?) {
        commonConfig()
        
        imageNameLabel.text = tagImageName
        
        ThreadTagLoader.shared.loadImage(
            named: tagImageName,
            placeholder: .thread(tintColor: nil),
            into: tagImageView,
            completion: { [weak self] response, error in
                if response?.image == nil, let self = self {
                    self.imageNameLabel.isHidden = false
                }
        })
    }
    
    func configure(placeholder: ThreadTagLoader.Placeholder) {
        commonConfig()
        
        ThreadTagLoader.shared.loadImage(named: nil, placeholder: placeholder, into: tagImageView)
    }
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
