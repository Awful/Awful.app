//  ThreadListCell.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import os
import UIKit

private let Log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ThreadListCell")

final class ThreadListCell: UITableViewCell {

    /// The actual contentView width from the most recent layout pass.
    /// On Mac Catalyst ("Designed for iPad"), contentView can be narrower
    /// than the table view due to platform-specific insets, so heightForRowAt
    /// should prefer this over tableView.bounds or safeAreaLayoutGuide.
    static var lastKnownContentViewWidth: CGFloat?

    private let pageCountBackgroundView = UIView()
    private let pageCountLabel = UILabel()
    private let pageIconView = UIImageView()
    private let postInfoLabel = UILabel()
    private let ratingImageView = UIImageView()
    private let secondaryTagImageView = UIImageView()
    private let stickyImageView = UIImageView()
    private let tagImageView = UIImageView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    private let unreadCountLabel = UILabel()

    var viewModel: ViewModel = .empty {
        didSet {
            backgroundColor = viewModel.backgroundColor

            pageCountLabel.attributedText = viewModel.pageCount
            
            if let color = viewModel.unreadCount.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor {
                 pageCountBackgroundView.backgroundColor = color.withAlphaComponent(0.2)
             } else {
                 pageCountBackgroundView.backgroundColor = .clear
             }
            pageCountBackgroundView.isHidden = viewModel.unreadCount.length == 0

            pageIconView.image = UIImage(named: "page")?.withTintColor(viewModel.pageIconColor)
            
            postInfoLabel.attributedText = viewModel.postInfo

            ratingImageView.image = viewModel.ratingImage

            ThreadTagLoader.shared.loadImage(named: viewModel.secondaryTagImageName, placeholder: nil, into: secondaryTagImageView)

            selectedBackgroundColor = viewModel.selectedBackgroundColor

            stickyImageView.image = viewModel.stickyImage

            ThreadTagLoader.shared.loadImage(named: viewModel.tagImage.imageName, placeholder: viewModel.tagImage.placeholder, into: tagImageView)

            titleLabel.attributedText = viewModel.title

            unreadCountLabel.attributedText = viewModel.unreadCount

            setNeedsLayout()
        }
    }

    struct ViewModel {
        let backgroundColor: UIColor
        let pageCount: NSAttributedString
        let pageIconColor: UIColor
        let postInfo: NSAttributedString
        let ratingImage: UIImage?
        let secondaryTagImageName: String?
        let selectedBackgroundColor: UIColor
        let stickyImage: UIImage?
        let tagImage: NamedThreadTag
        let title: NSAttributedString
        let unreadCount: NSAttributedString

        static let empty = ViewModel(
            backgroundColor: .clear,
            pageCount: NSAttributedString(),
            pageIconColor: .clear,
            postInfo: NSAttributedString(),
            ratingImage: nil,
            secondaryTagImageName: nil,
            selectedBackgroundColor: .clear,
            stickyImage: nil,
            tagImage: .none,
            title: NSAttributedString(),
            unreadCount: NSAttributedString())
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(pageCountBackgroundView)
        contentView.addSubview(pageCountLabel)
        contentView.addSubview(pageIconView)
        contentView.addSubview(postInfoLabel)
        contentView.addSubview(ratingImageView)
        contentView.addSubview(tagImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(unreadCountLabel)
        contentView.addSubview(secondaryTagImageView)
        contentView.addSubview(stickyImageView)

        pageCountBackgroundView.clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let contentWidth = contentView.bounds.width
        let previousWidth = ThreadListCell.lastKnownContentViewWidth
        ThreadListCell.lastKnownContentViewWidth = contentWidth

        // If the actual contentView width differs from what heightForRowAt
        // used (first layout, or width changed), schedule a height
        // recalculation so cells get the correct height for this width.
        if previousWidth.map({ abs($0 - contentWidth) > 1 }) != false {
            DispatchQueue.main.async { [weak self] in
                guard let tableView = self?.superview as? UITableView
                    ?? self?.superview?.superview as? UITableView else { return }
                UIView.performWithoutAnimation {
                    tableView.beginUpdates()
                    tableView.endUpdates()
                }
            }
        }

        let layout = Layout(width: contentWidth, viewModel: viewModel)
         // Background behind the page count label, with padding and pill shape
        if viewModel.unreadCount.length > 0 {
            let backgroundPadding = UIEdgeInsets(top: -2, left: -6, bottom: -2, right: -6)
            let bgFrame = layout.unreadCountFrame.inset(by: backgroundPadding)
            pageCountBackgroundView.frame = bgFrame
            pageCountBackgroundView.layer.cornerRadius = bgFrame.height / 2
         } else {
            pageCountBackgroundView.frame = .zero
         }

        pageCountLabel.frame = layout.pageCountFrame
        pageIconView.frame = layout.pageIconFrame
        postInfoLabel.frame = layout.postInfoFrame
        ratingImageView.frame = layout.ratingImageFrame
        secondaryTagImageView.frame = layout.secondaryTagFrame
        stickyImageView.frame = layout.stickyFrame
        tagImageView.frame = layout.tagImageFrame
        titleLabel.frame = layout.titleFrame
        unreadCountLabel.frame = layout.unreadCountFrame
        
        // rounded corners
        tagImageView.layer.masksToBounds = true
        tagImageView.layer.cornerRadius = 3
    }

    private struct Layout {
        let height: CGFloat
        let pageCountFrame: CGRect
        let pageIconFrame: CGRect
        let postInfoFrame: CGRect
        let ratingImageFrame: CGRect
        let secondaryTagFrame: CGRect
        let stickyFrame: CGRect
        let tagImageFrame: CGRect
        let titleFrame: CGRect
        let unreadCountFrame: CGRect

        static let minimumHeight: CGFloat = 72
        static let outerMargin: CGFloat = 8
        static let pageCountRightMargin: CGFloat = 2
        static let pageIconRightMargin: CGFloat = 5
        static let tagBottomMargin: CGFloat = 2
        static let tagRightMargin: CGFloat = 6
        static let titleBottomMargin: CGFloat = 2
        static let unreadLeftMargin: CGFloat = 5

        init(width: CGFloat, viewModel: ViewModel) {
            // 1. See how much width we have for the text.
            var textWidth = width - Layout.outerMargin - Layout.outerMargin

            let tagImageSize = viewModel.tagImage.imageSize
            if tagImageSize.width > 0 {
                textWidth -= tagImageSize.width + Layout.tagRightMargin
            }

            let unreadSize = viewModel.unreadCount.boundingRect(with: CGSize(width: width, height: .infinity), options: [], context: nil).pixelRound.size
            if unreadSize.width > 0 {
                textWidth -= unreadSize.width + Layout.unreadLeftMargin
            }

            // Pixel-ceil textWidth so the measurement width matches the rendered width after textRect is pixelRound'd.
            // Without this, a title that barely wraps at textWidth may fit on one line at the slightly wider pixelCeil(textWidth),
            // leaving a gap between the title and the subtitle row.
            textWidth = pixelCeil(textWidth)

            // 2. Figure out how tall things are.
            let titleHeight = viewModel.title.boundingRect(with: CGSize(width: textWidth, height: .infinity), options: [.usesLineFragmentOrigin], context: nil).pixelRound.height

            let pageCountSize = viewModel.pageCount.boundingRect(with: CGSize(width: width, height: .infinity), options: [], context: nil).pixelRound.size
            let postInfoSize = viewModel.postInfo.boundingRect(with: CGSize(width: width, height: .infinity), options: [], context: nil).pixelRound.size

            let textHeight = titleHeight + Layout.titleBottomMargin + max(pageCountSize.height, postInfoSize.height)

            let ratingHeight = viewModel.ratingImage?.size.height ?? 0

            let tagAndRatingMargin = tagImageSize.height > 0 && ratingHeight > 0 ? Layout.tagBottomMargin : 0
            let tagAndRatingHeight = tagImageSize.height + ratingHeight + tagAndRatingMargin

            let contentHeight = max(textHeight, tagAndRatingHeight)
            height = max(Layout.outerMargin + contentHeight + Layout.outerMargin, Layout.minimumHeight)

            // 3. Tag and rating
            let ratingWidth = viewModel.ratingImage?.size.width ?? 0
            let tagAndRatingRect = CGRect(
                x: Layout.outerMargin,
                y: (height - tagAndRatingHeight) / 2,
                width: max(tagImageSize.width, ratingWidth),
                height: tagAndRatingHeight)
                .pixelRound

            tagImageFrame = CGRect(
                x: tagAndRatingRect.minX + (tagAndRatingRect.width - tagImageSize.width) / 2,
                y: tagAndRatingRect.minY,
                width: tagImageSize.width,
                height: tagImageSize.height)
                .pixelRound

            let secondaryTagSize = CGSize(width: 14, height: 14)
            secondaryTagFrame = CGRect(
                x: tagImageFrame.maxX - secondaryTagSize.width + 2,
                y: tagImageFrame.minY - 2,
                width: secondaryTagSize.width,
                height: secondaryTagSize.height)

            ratingImageFrame = CGRect(
                x: tagAndRatingRect.minX + (tagAndRatingRect.width - ratingWidth) / 2,
                y: tagAndRatingRect.maxY - ratingHeight,
                width: ratingWidth,
                height: ratingHeight)
                .pixelRound

            // 4. Unread count
            unreadCountFrame = CGRect(
                x: width - Layout.outerMargin - unreadSize.width,
                y: (height - unreadSize.height) / 2,
                width: unreadSize.width,
                height: unreadSize.height)
                .pixelRound

            // 5. Title, page count, post info
            let textRect = CGRect(
                x: tagAndRatingRect.width > 0 ? tagAndRatingRect.maxX + Layout.tagRightMargin : Layout.outerMargin,
                y: (height - textHeight) / 2,
                width: textWidth,
                height: textHeight)
                .pixelRound

            titleFrame = CGRect(
                x: textRect.minX,
                y: textRect.minY,
                width: textRect.width,
                height: titleHeight)

            pageCountFrame = CGRect(
                x: textRect.minX,
                y: textRect.maxY - pageCountSize.height,
                width: pageCountSize.width,
                height: pageCountSize.height)

            let pageCountFont = viewModel.pageCount.attribute(.font, at: 0, effectiveRange: nil) as? UIFont ?? UIFont.systemFont(ofSize: 12)
            let pageIconHeight = pixelCeil(pageCountFont.capHeight)
            let pageIconWidth = CGFloat(9)
            pageIconFrame = CGRect(
                x: pageCountFrame.maxX + Layout.pageCountRightMargin,
                y: pageCountFrame.minY + pageCountFont.ascender - pageIconHeight,
                width: pageIconWidth,
                height: pageIconHeight)
                .pixelRound

            let postInfoFont = viewModel.postInfo.attribute(.font, at: 0, effectiveRange: nil) as? UIFont ?? UIFont.systemFont(ofSize: 11)
            postInfoFrame = CGRect(
                x: pageIconFrame.maxX + Layout.pageIconRightMargin,
                y: textRect.maxY - postInfoSize.height + (pageCountFont.descender - postInfoFont.descender),
                width: textWidth - (pageIconFrame.maxX - pageCountFrame.minX),
                height: postInfoSize.height)
                .pixelRound

            // 6. Sticky
            let stickySize = viewModel.stickyImage?.size ?? .zero
            stickyFrame = CGRect(
                x: width - stickySize.width,
                y: 0,
                width: stickySize.width,
                height: stickySize.height)
        }
    }

    static var estimatedHeight: CGFloat { return 75 }

    static func heightForViewModel(_ viewModel: ViewModel, inTableWithWidth width: CGFloat) -> CGFloat {
        return Layout(width: width, viewModel: viewModel).height
    }

    static func separatorLeftInset(showsTagAndRating: Bool, inTableWithWidth width: CGFloat) -> CGFloat {
        let viewModel = ViewModel(
            backgroundColor: .clear,
            pageCount: NSAttributedString(),
            pageIconColor: .clear,
            postInfo: NSAttributedString(),
            ratingImage: nil,
            secondaryTagImageName: nil,
            selectedBackgroundColor: .clear,
            stickyImage: nil,
            tagImage: showsTagAndRating ? .spacer : .none,
            title: NSAttributedString(),
            unreadCount: NSAttributedString())
        return Layout(width: width, viewModel: viewModel).titleFrame.minX
    }
}
