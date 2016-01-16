//  ForumTableViewCell.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulViews
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
    var starButtonAction: (ForumTableViewCell -> Void)?
    var disclosureButtonAction: (ForumTableViewCell -> Void)?
    
    @IBOutlet private weak var starButton: UIButton!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var disclosureButton: UIButton!
    @IBOutlet private weak var separator: HairlineView!
    @IBOutlet private var nameLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private var nameTrailingConstraint: NSLayoutConstraint!
    
    private var baseNameLeadingConstant: CGFloat = 0
    private static let indentationLevelIncrease: CGFloat = 15
    var nameIndentationLevel: Int = 0 {
        didSet {
            let newConstant = baseNameLeadingConstant + ForumTableViewCell.indentationLevelIncrease * CGFloat(nameIndentationLevel)
            nameLeadingConstraint.constant = max(newConstant, baseNameLeadingConstant)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Constraints we can't set in IB.
        contentView.heightAnchor.constraintGreaterThanOrEqualToConstant(44).active = true
        separator.trailingAnchor.constraintEqualToAnchor(trailingAnchor).active = true
        
        starButton.addTarget(self, action: "didTapStarButton", forControlEvents: .TouchUpInside)
        disclosureButton.addTarget(self, action: "didTapDisclosureButton", forControlEvents: .TouchUpInside)
        
        baseNameLeadingConstant = nameLeadingConstraint.constant
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "contentSizeCategoryDidChange:", name: UIContentSizeCategoryDidChangeNotification, object: nil)
    }
    
    // MARK: Actions
    
    @objc private func didTapStarButton() {
        starButtonAction?(self)
    }
    
    @objc private func didTapDisclosureButton() {
        disclosureButtonAction?(self)
    }
    
    // MARK: Notifications
    
    @objc private func contentSizeCategoryDidChange(notification: NSNotification) {
        guard let style = nameLabel.font.fontDescriptor().objectForKey(UIFontDescriptorTextStyleAttribute) as? String else { return }
        nameLabel.font = UIFont.preferredFontForTextStyle(style)
    }
    
    // MARK: Editing
    
    override func willTransitionToState(state: UITableViewCellStateMask) {
        super.willTransitionToState(state)
        
        if state.contains(.ShowingEditControlMask) {
            starButton.alpha = 0
            nameLeadingConstraint.active = false
            
            disclosureButton.alpha = 0
            nameTrailingConstraint.active = false
        } else {
            /*
            Setting `startButton.alpha = 1` here does not get animated, and I don't know why.
            
            Neither UIView.setAnimationsEnabled(_:) nor CATransaction.setDisableActions(_:) seem to have any effect.
            
            So for now we'll set the alpha in didTransitionToState(_:), even though it looks ugly. If you can get the starButton to fade in here, please do it!
            */
            // startButton.alpha = 1
            nameLeadingConstraint.active = true
            
            disclosureButton.alpha = 1
            nameTrailingConstraint.active = true
        }
    }
    
    override func didTransitionToState(state: UITableViewCellStateMask) {
        super.didTransitionToState(state)
        
        if !state.contains(.ShowingEditControlMask) {
            UIView.animateWithDuration(0.3, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [], animations: {
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
            case On, Off, Hidden
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
            case .On:
                return "Hide subforums"
                
            case .Off:
                return "Expand subforums"
                
            case .Hidden:
                return ""
            }
        }
    }
    
    private func applyViewModel(data: ViewModel?) {
        starButton.configure(data?.favorite ?? .Hidden)
        disclosureButton.configure(data?.canExpand ?? .Hidden)
        
        nameLabel.text = data?.name ?? ""
        nameIndentationLevel = data?.indentationLevel ?? 0
        
        accessibilityLabel = data?.cellAccessibilityLabel
        disclosureButton.accessibilityLabel = data?.disclosureAccessibilityLabel
        
        separator.hidden = data?.showSeparator == false
    }
    
    // MARK: Theming
    
    struct ThemeData {
        let nameColor: UIColor
        let separatorColor: UIColor
        let backgroundColor: UIColor
        let selectedBackgroundColor: UIColor
    }
    
    private func applyThemeData(theme: ThemeData) {
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
    func configure(status: ForumTableViewCell.ViewModel.ButtonStatus) {
        switch status {
        case .On:
            hidden = false
            selected = true
            
        case .Off:
            hidden = false
            selected = false
            
        case .Hidden:
            hidden = true
        }
    }
}
