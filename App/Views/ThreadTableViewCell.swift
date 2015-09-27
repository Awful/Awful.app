//  ThreadTableViewCell.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

final class ThreadTableViewCell: UITableViewCell {
    static let identifier = "ThreadTableViewCell"
    static let nibName = "ThreadTableViewCell"
    static let estimatedRowHeight: CGFloat = 75
    
    @IBOutlet private weak var tagAndRatingView: UIStackView!
    @IBOutlet private weak var tagView: UIImageView!
    @IBOutlet private weak var secondaryTagView: UIImageView!
    @IBOutlet private weak var ratingView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var pageCountLabel: UILabel!
    @IBOutlet private weak var killedPostedByLabel: UILabel!
    @IBOutlet private weak var unreadPostsLabel: UILabel!
    @IBOutlet private weak var stickyView: UIImageView!
    @IBOutlet private weak var separatorView: HairlineView!
    
    lazy var longPress: UILongPressGestureRecognizer = { [unowned self] in
        let recognizer = UILongPressGestureRecognizer()
        self.addGestureRecognizer(recognizer)
        return recognizer
    }()
    
    struct ViewModel {
        let title: String
        let titleAlpha: CGFloat
        
        let numberOfPages: String
        let killedPostedBy: String
        let unreadPosts: String
        
        let sticky: Bool
        
        let showsTagAndRating: Bool
        let tag: UIImage
        let secondaryTag: UIImage?
        let rating: UIImage?
        let tagAndRatingAlpha: CGFloat
        
        var accessibilityLabel: String {
            var components = [title]
            
            if !unreadPosts.isEmpty {
                // TODO: why convert from int to string to int??
                let s = Int(unreadPosts) == 1 ? "" : "s"
                components.append(", \(unreadPosts) unread post\(s)")
            }
            
            if sticky {
                components.append(", sticky")
            }
            
            do {
                let s = Int(numberOfPages) == 1 ? "" : "s"
                components.append(". \(numberOfPages) page\(s)")
            }
            
            components.append(", \(killedPostedBy)")
            
            return components.joinWithSeparator("")
        }
    }
    
    var viewModel: ViewModel? {
        didSet { applyViewModel(viewModel) }
    }
    
    private func applyViewModel(data: ViewModel?) {
        tagAndRatingView.hidden = !(data?.showsTagAndRating ?? false)
        tagAndRatingView.alpha = data?.tagAndRatingAlpha ?? 1
        
        tagView.image = data?.tag
        secondaryTagView.image = data?.secondaryTag
        ratingView.image = data?.rating
        
        titleLabel.text = data?.title
        titleLabel.alpha = data?.titleAlpha ?? 1
        pageCountLabel.text = data?.numberOfPages
        killedPostedByLabel.text = data?.killedPostedBy
        
        unreadPostsLabel.text = data?.unreadPosts
        
        stickyView.hidden = !(data?.sticky ?? false)
        
        accessibilityLabel = data?.accessibilityLabel
    }
    
    struct ThemeData {
        let titleColor: UIColor
        let titleFont: UIFont
        
        let pageCountColor: UIColor
        let pageCountFont: UIFont
        
        let killedPostedByColor: UIColor
        let killedPostedByFont: UIFont
        
        let unreadPostsColor: UIColor
        let unreadPostsFont: UIFont
        
        let separatorColor: UIColor
        let backgroundColor: UIColor
        let selectedBackgroundColor: UIColor
    }
    
    var themeData: ThemeData? {
        didSet { applyThemeData(themeData!) }
    }
    
    private func applyThemeData(theme: ThemeData) {
        titleLabel.textColor = theme.titleColor
        titleLabel.font = theme.titleFont
        
        pageCountLabel.textColor = theme.pageCountColor
        pageCountLabel.font = theme.pageCountFont
        
        killedPostedByLabel.textColor = theme.killedPostedByColor
        killedPostedByLabel.font = theme.killedPostedByFont
        
        unreadPostsLabel.textColor = theme.unreadPostsColor
        unreadPostsLabel.font = theme.unreadPostsFont
        
        separatorView.backgroundColor = theme.separatorColor
        backgroundColor = theme.backgroundColor
        selectedBackgroundColor = theme.selectedBackgroundColor
    }
}

extension ThreadTableViewCell.ViewModel {
    init(thread: Thread, showsTag: Bool, overrideSticky stickyOverride: Bool? = nil) {
        title = thread.title ?? ""
        let p = Int(thread.numberOfPages) == 1 ? "p" : "pp"
        numberOfPages = "\(thread.numberOfPages)\(p)"
        
        if thread.beenSeen {
            let poster = thread.lastPostAuthorName ?? ""
            killedPostedBy = "Killed by \(poster)"
            unreadPosts = String(thread.unreadPosts)
        } else {
            let author = thread.author?.username ?? ""
            killedPostedBy = "Posted by \(author)"
            unreadPosts = ""
        }
        
        showsTagAndRating = showsTag
        if let
            imageName = thread.threadTag?.imageName,
            image = AwfulThreadTagLoader.imageNamed(imageName)
        {
            tag = image
        } else {
            tag = AwfulThreadTagLoader.emptyThreadTagImage()
        }
        
        if let secondaryTagImageName = thread.secondaryThreadTag?.imageName {
            secondaryTag = UIImage(named: secondaryTagImageName)
        } else {
            secondaryTag = nil
        }
        
        var rating: Int?
        if AwfulForumTweaks(forumID: thread.forum?.forumID)?.showRatings ?? true {
            let rounded = lroundf(thread.rating).clamp(0...5)
            if rounded != 0 {
                rating = rounded
            }
        }
        if let rating = rating {
            self.rating = UIImage(named: "rating\(rating)")
        } else {
            self.rating = nil
        }
        
        let faded = thread.closed && !thread.sticky
        let alpha: CGFloat = faded ? 0.5 : 1
        titleAlpha = alpha
        tagAndRatingAlpha = alpha
        
        self.sticky = stickyOverride ?? thread.sticky
    }
}

extension ThreadTableViewCell.ThemeData {
    init(theme: Theme, thread: Thread) {
        titleColor = theme["listTextColor"]!
        
        pageCountColor = theme["listSecondaryTextColor"]!
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
        titleFont = UIFont.preferredFontForTextStyle(.Body, fontName: fontName)
        pageCountFont = UIFont.preferredFontForTextStyle(.Footnote, fontName: fontName)
        killedPostedByFont = pageCountFont
        unreadPostsFont = UIFont.preferredFontForTextStyle(.Caption1, fontName: fontName, sizeAdjustment: 2)
        
        separatorColor = theme["listSeparatorColor"]!
        backgroundColor = theme["listBackgroundColor"]!
        selectedBackgroundColor = theme["listSelectedBackgroundColor"]!
    }
}
