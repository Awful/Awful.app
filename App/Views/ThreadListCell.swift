//  ThreadListCell.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

private let Log = Logger.get(level: .debug)

final class ThreadListCell: UITableViewCell {

    private let pageCountLabel = UILabel()
    private let pageIconView = PageIconView()
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

            pageIconView.borderColor = viewModel.pageIconColor

            postInfoLabel.attributedText = viewModel.postInfo

            ratingImageView.image = viewModel.ratingImage

            secondaryTagImageView.image = viewModel.secondaryTagImage

            if selectedBackgroundView == nil {
                selectedBackgroundView = UIView()
            }
            selectedBackgroundView?.backgroundColor = viewModel.selectedBackgroundColor

            stickyImageView.image = viewModel.stickyImage

            tagImageView.image = viewModel.tagImage

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
        let secondaryTagImage: UIImage?
        let selectedBackgroundColor: UIColor
        let stickyImage: UIImage?
        let tagImage: UIImage?
        let title: NSAttributedString
        let unreadCount: NSAttributedString

        static let empty = ViewModel(
            backgroundColor: .clear,
            pageCount: NSAttributedString(),
            pageIconColor: .clear,
            postInfo: NSAttributedString(),
            ratingImage: nil,
            secondaryTagImage: nil,
            selectedBackgroundColor: .clear,
            stickyImage: nil,
            tagImage: nil,
            title: NSAttributedString(),
            unreadCount: NSAttributedString())
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(pageCountLabel)
        contentView.addSubview(pageIconView)
        contentView.addSubview(postInfoLabel)
        contentView.addSubview(ratingImageView)
        contentView.addSubview(tagImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(unreadCountLabel)
        contentView.addSubview(secondaryTagImageView)
        contentView.addSubview(stickyImageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let layout = Layout(width: contentView.bounds.width, viewModel: viewModel)
        pageCountLabel.frame = layout.pageCountFrame
        pageIconView.frame = layout.pageIconFrame
        postInfoLabel.frame = layout.postInfoFrame
        ratingImageView.frame = layout.ratingImageFrame
        secondaryTagImageView.frame = layout.secondaryTagFrame
        stickyImageView.frame = layout.stickyFrame
        tagImageView.frame = layout.tagImageFrame
        titleLabel.frame = layout.titleFrame
        unreadCountLabel.frame = layout.unreadCountFrame
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

            if let tagImage = viewModel.tagImage {
                textWidth -= tagImage.size.width + Layout.tagRightMargin
            }

            let unreadSize = viewModel.unreadCount.boundingRect(with: CGSize(width: width, height: .infinity), options: [], context: nil).pixelRound.size
            if unreadSize.width > 0 {
                textWidth -= unreadSize.width + Layout.unreadLeftMargin
            }

            // 2. Figure out how tall things are.
            let titleHeight = viewModel.title.boundingRect(with: CGSize(width: textWidth, height: .infinity), options: [.usesLineFragmentOrigin], context: nil).pixelRound.height

            let pageCountSize = viewModel.pageCount.boundingRect(with: CGSize(width: width, height: .infinity), options: [], context: nil).pixelRound.size
            let postInfoSize = viewModel.postInfo.boundingRect(with: CGSize(width: width, height: .infinity), options: [], context: nil).pixelRound.size

            let textHeight = titleHeight + Layout.titleBottomMargin + max(pageCountSize.height, postInfoSize.height)

            let ratingHeight = viewModel.ratingImage?.size.height ?? 0
            let tagHeight = viewModel.tagImage?.size.height ?? 0

            let tagAndRatingMargin = tagHeight > 0 && ratingHeight > 0 ? Layout.tagBottomMargin : 0
            let tagAndRatingHeight = tagHeight + ratingHeight + tagAndRatingMargin

            let contentHeight = max(textHeight, tagAndRatingHeight)
            height = max(Layout.outerMargin + contentHeight + Layout.outerMargin, Layout.minimumHeight)

            // 3. Tag and rating
            let tagWidth = viewModel.tagImage?.size.width ?? 0
            let ratingWidth = viewModel.ratingImage?.size.width ?? 0
            let tagAndRatingRect = CGRect(
                x: Layout.outerMargin,
                y: (height - tagAndRatingHeight) / 2,
                width: max(tagWidth, ratingWidth),
                height: tagAndRatingHeight)
                .pixelRound

            tagImageFrame = CGRect(
                x: tagAndRatingRect.minX + (tagAndRatingRect.width - tagWidth) / 2,
                y: tagAndRatingRect.minY,
                width: tagWidth,
                height: tagHeight)
                .pixelRound

            let secondaryTagSize = viewModel.secondaryTagImage?.size ?? .zero
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
            let pageIconWidth = pageIconHeight * PageIconView.aspectRatio
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
                width: textWidth - pageIconFrame.maxX - Layout.pageIconRightMargin,
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
            secondaryTagImage: nil,
            selectedBackgroundColor: .clear,
            stickyImage: nil,
            tagImage: showsTagAndRating ? ThreadTagLoader.emptyThreadTagImage : nil,
            title: NSAttributedString(),
            unreadCount: NSAttributedString())
        return Layout(width: width, viewModel: viewModel).titleFrame.minX
    }
}
