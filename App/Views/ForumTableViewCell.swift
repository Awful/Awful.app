//  ForumTableViewCell.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

@IBDesignable final class ForumTableViewCell: UITableViewCell {
    static let identifier = "ForumTableViewCell"
    static let nibName = "ForumTableViewCell"
    static let estimatedRowHeight: CGFloat = 50
    
    var viewModel: ViewModel? {
        didSet { applyViewModel(viewModel) }
    }
    var themeData: ThemeData! {
        didSet { applyThemeData(themeData) }
    }
    var starButtonAction: ((ForumTableViewCell) -> Void)?
    var disclosureButtonAction: ((ForumTableViewCell) -> Void)?
    
    @IBOutlet fileprivate weak var starButton: UIButton!
    @IBOutlet fileprivate weak var nameLabel: UILabel!
    @IBOutlet fileprivate weak var disclosureButton: UIButton!
    @IBOutlet fileprivate weak var separator: HairlineView!
    @IBOutlet fileprivate var nameLeadingConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var nameTrailingConstraint: NSLayoutConstraint!
    
    fileprivate var baseNameLeadingConstant: CGFloat = 0
    fileprivate static let indentationLevelIncrease: CGFloat = 15
    var nameIndentationLevel: Int = 0 {
        didSet {
            let newConstant = baseNameLeadingConstant + ForumTableViewCell.indentationLevelIncrease * CGFloat(nameIndentationLevel)
            nameLeadingConstraint.constant = max(newConstant, baseNameLeadingConstant)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Constraints we can't set in IB.
        contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        separator.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        
        starButton.addTarget(self, action: #selector(ForumTableViewCell.didTapStarButton), for: .touchUpInside)
        disclosureButton.addTarget(self, action: #selector(ForumTableViewCell.didTapDisclosureButton), for: .touchUpInside)
        
        baseNameLeadingConstant = nameLeadingConstraint.constant
        
        NotificationCenter.default.addObserver(self, selector: #selector(ForumTableViewCell.contentSizeCategoryDidChange(_:)), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
    }
    
    // MARK: Actions
    
    @objc fileprivate func didTapStarButton() {
        starButtonAction?(self)
    }
    
    @objc fileprivate func didTapDisclosureButton() {
        disclosureButtonAction?(self)
    }
    
    // MARK: Notifications
    
    @objc fileprivate func contentSizeCategoryDidChange(_ notification: Notification) {
        guard let style = nameLabel.font.fontDescriptor.object(forKey: UIFontDescriptorTextStyleAttribute) as? String else { return }
        nameLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle(rawValue: style))
    }
    
    // MARK: Editing
    
    override func willTransition(to state: UITableViewCellStateMask) {
        super.willTransition(to: state)
        
        if state.contains(.showingEditControlMask) {
            starButton.alpha = 0
            nameLeadingConstraint.isActive = false
            
            disclosureButton.alpha = 0
            nameTrailingConstraint.isActive = false
        } else {
            /*
            Setting `startButton.alpha = 1` here does not get animated, and I don't know why.
            
            Neither UIView.setAnimationsEnabled(_:) nor CATransaction.setDisableActions(_:) seem to have any effect.
            
            So for now we'll set the alpha in didTransitionToState(_:), even though it looks ugly. If you can get the starButton to fade in here, please do it!
            */
            // startButton.alpha = 1
            nameLeadingConstraint.isActive = true
            
            disclosureButton.alpha = 1
            nameTrailingConstraint.isActive = true
        }
    }
    
    override func didTransition(to state: UITableViewCellStateMask) {
        super.didTransition(to: state)
        
        if !state.contains(.showingEditControlMask) {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [], animations: {
                self.starButton.alpha = 1
                }, completion: nil)
        }
    }
    
    // MARK: Rendering
    
    struct ViewModel: Equatable {
        let favorite: ButtonStatus
        let name: String
        let canExpand: ButtonStatus
        let childSubforumCount: Int
        let indentationLevel: Int
        let showSeparator: Bool
        
        enum ButtonStatus: Int {
            case on, off, hidden
        }
        
        var cellAccessibilityLabel: String {
            var accessibilityLabel = name
            if childSubforumCount > 0 {
                let s = childSubforumCount == 1 ? "" : "s"
                accessibilityLabel += ". \(childSubforumCount) subforum\(s)"
            }
            return accessibilityLabel
        }
        
        var disclosureAccessibilityLabel: String {
            switch canExpand {
            case .on:
                return "Hide subforums"
                
            case .off:
                return "Expand subforums"
                
            case .hidden:
                return ""
            }
        }
    }
    
    fileprivate func applyViewModel(_ data: ViewModel?) {
        starButton.configure(data?.favorite ?? .hidden)
        disclosureButton.configure(data?.canExpand ?? .hidden)
        
        nameLabel.text = data?.name ?? ""
        nameIndentationLevel = data?.indentationLevel ?? 0
        
        accessibilityLabel = data?.cellAccessibilityLabel
        disclosureButton.accessibilityLabel = data?.disclosureAccessibilityLabel
        
        separator.isHidden = data?.showSeparator == false
    }
    
    // MARK: Theming
    
    struct ThemeData {
        let nameColor: UIColor
        let separatorColor: UIColor
        let backgroundColor: UIColor
        let selectedBackgroundColor: UIColor
    }
    
    fileprivate func applyThemeData(_ theme: ThemeData) {
        nameLabel.textColor = theme.nameColor
        separator.backgroundColor = theme.separatorColor
        backgroundColor = theme.backgroundColor
        selectedBackgroundColor = theme.selectedBackgroundColor
    }
}

func ==(lhs: ForumTableViewCell.ViewModel, rhs: ForumTableViewCell.ViewModel) -> Bool {
    return
        lhs.favorite == rhs.favorite &&
        lhs.canExpand == rhs.canExpand &&
        lhs.childSubforumCount == rhs.childSubforumCount &&
        lhs.indentationLevel == rhs.indentationLevel &&
        lhs.name == rhs.name &&
        lhs.showSeparator == rhs.showSeparator
}

private extension UIButton {
    func configure(_ status: ForumTableViewCell.ViewModel.ButtonStatus) {
        switch status {
        case .on:
            isHidden = false
            isSelected = true
            
        case .off:
            isHidden = false
            isSelected = false
            
        case .hidden:
            isHidden = true
        }
    }
}
