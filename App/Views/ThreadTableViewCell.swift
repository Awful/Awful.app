//  ThreadTableViewCell.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

final class ThreadTableViewCell: UITableViewCell {
    static let identifier = "ThreadTableViewCell"
    static let nibName = "ThreadTableViewCell"
    static let estimatedRowHeight: CGFloat = 75
    
    var viewModel: ViewModel? {
        didSet { applyViewModel(viewModel) }
    }
    var themeData: ThemeData? {
        didSet { applyThemeData(themeData!) }
    }
    var longPressAction: ((ThreadTableViewCell) -> Void)? {
        didSet { longPress.isEnabled = longPressAction != nil }
    }
    
    @IBOutlet fileprivate weak var tagAndRatingView: UIStackView!
    @IBOutlet fileprivate weak var tagView: UIImageView!
    @IBOutlet fileprivate weak var secondaryTagView: UIImageView!
    @IBOutlet fileprivate weak var ratingView: UIImageView!
    @IBOutlet fileprivate weak var titleLabel: UILabel!
    @IBOutlet fileprivate weak var pageCountLabel: UILabel!
    @IBOutlet fileprivate weak var pageIconView: UIImageView!
    @IBOutlet fileprivate weak var killedPostedByLabel: UILabel!
    @IBOutlet fileprivate weak var unreadPostsLabel: UILabel!
    @IBOutlet fileprivate weak var stickyView: UIImageView!
    @IBOutlet fileprivate weak var separatorView: HairlineView!
    fileprivate lazy var longPress: UILongPressGestureRecognizer = { [unowned self] in
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(ThreadTableViewCell.didLongPress))
        self.addGestureRecognizer(recognizer)
        return recognizer
    }()
    
    // MARK: Actions
    
    @objc fileprivate func didLongPress() {
        longPressAction?(self)
    }
    
    // MARK: Rendering
    
    struct ViewModel: Equatable {
        let title: String
        let titleAlpha: CGFloat
        
        let numberOfPages: Int
        let killedBy: String
        let postedBy: String
        
        let unreadPosts: Int
        let beenSeen: Bool
        
        // Included so updates happen; actual color applied in applyTheme.
        let starCategory: StarCategory
        
        let sticky: Bool
        
        let showsTagAndRating: Bool
        let tag: Tag
        let secondaryTag: UIImage?
        let secondaryTagImageName: String?
        let rating: UIImage?
        let ratingImageName: String?
        let tagAndRatingAlpha: CGFloat
        
        enum Tag: Equatable {
            case downloaded(UIImage)
            case unavailable(fallbackImage: UIImage, desiredImageName: String)
            
            var image: UIImage {
                switch self {
                case let .downloaded(image): return image
                case let .unavailable(image, _): return image
                }
            }
        }
        
        var killedPostedBy: String {
            if beenSeen {
                return "Killed by \(killedBy)"
            } else {
                return "Posted by \(postedBy)"
            }
        }
        
        var accessibilityLabel: String {
            var components = [title]
            
            if beenSeen {
                let s = unreadPosts == 1 ? "" : "s"
                components.append(", \(unreadPosts) unread post\(s)")
            }
            
            if sticky {
                components.append(", sticky")
            }
            
            do {
                let s = numberOfPages == 1 ? "" : "s"
                components.append(". \(numberOfPages) page\(s)")
            }
            
            components.append(", \(killedPostedBy)")
            
            return components.joined(separator: "")
        }
    }
    
    fileprivate func applyViewModel(_ data: ViewModel?) {
        tagAndRatingView.isHidden = !(data?.showsTagAndRating ?? false)
        tagAndRatingView.alpha = data?.tagAndRatingAlpha ?? 1
        
        tagView.image = data?.tag.image
        secondaryTagView.image = data?.secondaryTag
        ratingView.image = data?.rating
        
        titleLabel.text = data?.title
        titleLabel.alpha = data?.titleAlpha ?? 1
        
        if let pages = data?.numberOfPages {
            pageCountLabel.text = "\(pages)"
        } else {
            pageCountLabel.text = ""
        }
        
        killedPostedByLabel.text = data?.killedPostedBy
        
        if let unreadPosts = data?.unreadPosts {
            unreadPostsLabel.text = "\(unreadPosts)"
        } else {
            unreadPostsLabel.text = ""
        }
        let beenSeen = data?.beenSeen ?? false
        unreadPostsLabel.isHidden = !beenSeen
        
        let sticky = data?.sticky ?? false
        stickyView.isHidden = !sticky
        
        accessibilityLabel = data?.accessibilityLabel
    }
    
    // MARK: Theming
    
    struct ThemeData {
        let titleColor: UIColor
        let titleFont: UIFont
        
        let pageCountColor: UIColor
        let pageCountFont: UIFont
        
        let pageIconColor: UIColor
        
        let killedPostedByColor: UIColor
        let killedPostedByFont: UIFont
        
        let unreadPostsColor: UIColor
        let unreadPostsFont: UIFont
        
        let separatorColor: UIColor
        let backgroundColor: UIColor
        let selectedBackgroundColor: UIColor
    }
    
    fileprivate func applyThemeData(_ theme: ThemeData) {
        titleLabel.textColor = theme.titleColor
        titleLabel.font = theme.titleFont
        
        pageCountLabel.textColor = theme.pageCountColor
        pageCountLabel.font = theme.pageCountFont
        
        pageIconView.tintColor = theme.pageIconColor
        
        killedPostedByLabel.textColor = theme.killedPostedByColor
        killedPostedByLabel.font = theme.killedPostedByFont
        
        unreadPostsLabel.textColor = theme.unreadPostsColor
        unreadPostsLabel.font = theme.unreadPostsFont
        
        separatorView.backgroundColor = theme.separatorColor
        backgroundColor = theme.backgroundColor
        selectedBackgroundColor = theme.selectedBackgroundColor
    }
}

func ==(lhs: ThreadTableViewCell.ViewModel, rhs: ThreadTableViewCell.ViewModel) -> Bool {
    return
        lhs.title == rhs.title &&
        lhs.titleAlpha == rhs.titleAlpha &&
        lhs.numberOfPages == rhs.numberOfPages &&
        lhs.killedBy == rhs.killedBy &&
        lhs.postedBy == rhs.postedBy &&
        lhs.beenSeen == rhs.beenSeen &&
        lhs.unreadPosts == rhs.unreadPosts &&
        lhs.starCategory == rhs.starCategory &&
        lhs.sticky == rhs.sticky &&
        lhs.showsTagAndRating == rhs.showsTagAndRating &&
        lhs.tag == rhs.tag &&
        lhs.secondaryTagImageName == rhs.secondaryTagImageName &&
        lhs.ratingImageName == rhs.ratingImageName
}

func ==(lhs: ThreadTableViewCell.ViewModel.Tag, rhs: ThreadTableViewCell.ViewModel.Tag) -> Bool {
    switch (lhs, rhs) {
    case (.downloaded, .downloaded):
        return true
        
    case let (.unavailable(_, lhsName), .unavailable(_, rhsName)):
        return lhsName == rhsName
        
    default:
        return false
    }
}

extension ThreadTableViewCell.ThemeData {
    init(theme: Theme, thread: AwfulThread) {
        titleColor = theme["listTextColor"]!
        
        pageCountColor = theme["listSecondaryTextColor"]!
        pageIconColor = pageCountColor
        killedPostedByColor = theme["listSecondaryTextColor"]!
        
        if thread.unreadPosts == 0 {
            unreadPostsColor = theme["unreadBadgeGrayColor"]!
        } else {
            switch thread.starCategory {
            case .Orange: unreadPostsColor = theme["unreadBadgeOrangeColor"]!
            case .Red: unreadPostsColor = theme["unreadBadgeRedColor"]!
            case .Yellow: unreadPostsColor = theme["unreadBadgeYellowColor"]!
            case .None: unreadPostsColor = theme["unreadBadgeBlueColor"]!
            }
        }
        
        let fontName: String? = theme["listFontName"]
        titleFont = UIFont.preferredFontForTextStyle(.body, fontName: fontName)
        pageCountFont = UIFont.preferredFontForTextStyle(.footnote, fontName: fontName)
        killedPostedByFont = pageCountFont
        unreadPostsFont = UIFont.preferredFontForTextStyle(.caption1, fontName: fontName, sizeAdjustment: 2)
        
        separatorColor = theme["listSeparatorColor"]!
        backgroundColor = theme["listBackgroundColor"]!
        selectedBackgroundColor = theme["listSelectedBackgroundColor"]!
    }
}
