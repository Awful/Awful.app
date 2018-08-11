//  MessageListCell.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class MessageListCell: UITableViewCell {

    private let dateLabel = UILabel()

    private let senderLabel: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let subjectLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    private let tagImageView = UIImageView()

    private let tagOverlayView = TagOverlayView()

    private class TagOverlayView: UIView {
        private let background: CAShapeLayer = {
            let layer = CAShapeLayer()
            layer.fillColor = UIColor.white.cgColor
            return layer
        }()

        private let imageLayer = CALayer()

        var image: UIImage? {
            didSet {
                imageLayer.contents = image?.cgImage
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.addSublayer(background)
            layer.addSublayer(imageLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            background.frame = CGRect(origin: .zero, size: bounds.size)
            background.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2)).cgPath
            imageLayer.frame = CGRect(origin: .zero, size: bounds.size)
        }
    }

    var viewModel: ViewModel = .empty {
        didSet {
            backgroundColor = viewModel.backgroundColor

            dateLabel.attributedText = viewModel.formattedSentDate

            if selectedBackgroundView == nil {
                selectedBackgroundView = UIView()
            }
            selectedBackgroundView?.backgroundColor = viewModel.selectedBackgroundColor

            senderLabel.attributedText = viewModel.sender

            subjectLabel.attributedText = viewModel.subject

            tagImageView.image = viewModel.tagImage

            tagOverlayView.image = viewModel.tagOverlayImage
            tagOverlayView.isHidden = viewModel.tagOverlayImage == nil

            setNeedsLayout()
        }
    }

    struct ViewModel {
        let backgroundColor: UIColor
        let selectedBackgroundColor: UIColor
        let sender: NSAttributedString
        let sentDate: Date
        let sentDateAttributes: [NSAttributedString.Key: Any]
        let subject: NSAttributedString
        let tagImage: UIImage?
        let tagOverlayImage: UIImage?

        fileprivate var accessibilityLabel: String {
            return String(
                format: LocalizedString("private-messages-list.message.accessibility-label"),
                sender.string,
                subject.string,
                stringForSentDate(sentDate))
        }

        fileprivate var formattedSentDate: NSAttributedString {
            return NSAttributedString(string: stringForSentDate(sentDate), attributes: sentDateAttributes)
        }

        static let empty: ViewModel = ViewModel(
            backgroundColor: .clear,
            selectedBackgroundColor: .clear,
            sender: .init(),
            sentDate: .distantPast,
            sentDateAttributes: [:],
            subject: .init(),
            tagImage: nil,
            tagOverlayImage: nil)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(dateLabel)
        contentView.addSubview(senderLabel)
        contentView.addSubview(subjectLabel)
        contentView.addSubview(tagImageView)
        contentView.addSubview(tagOverlayView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let layout = Layout(width: contentView.bounds.width, viewModel: viewModel)
        dateLabel.frame = layout.dateFrame
        senderLabel.frame = layout.senderFrame
        subjectLabel.frame = layout.subjectFrame
        tagImageView.frame = layout.tagFrame
        tagOverlayView.frame = layout.tagOverlayFrame
    }

    private struct Layout {
        let dateFrame: CGRect
        let height: CGFloat
        let senderFrame: CGRect
        let subjectFrame: CGRect
        let tagFrame: CGRect
        let tagOverlayFrame: CGRect

        private static let cellHorizontalMargin: CGFloat = 8
        private static let cellVerticalMargin: CGFloat = 4
        private static let dateLeftMargin: CGFloat = 4
        private static let minimumHeight: CGFloat = 65
        private static let subjectTopMargin: CGFloat = 2
        private static let tagRightMargin: CGFloat = 8
        private static let tagOverlayOffset = UIOffset(horizontal: 2, vertical: 3)

        init(width: CGFloat, viewModel: ViewModel) {
            // 1. See how much width we have for the subject.
            var subjectWidth = width - Layout.cellHorizontalMargin - Layout.cellHorizontalMargin
            let tagSize = viewModel.tagImage?.size.width ?? 0
            if viewModel.tagImage != nil {
                subjectWidth -= tagSize - Layout.tagRightMargin
            }

            let subjectHeight = viewModel.subject.boundingRect(with: CGSize(width: subjectWidth, height: .infinity), options: .usesLineFragmentOrigin, context: nil).pixelRound.height

            // 2. Figure out how tall things are.
            let senderHeight = viewModel.sender.boundingRect(with: CGSize(width: width, height: .infinity), options: [], context: nil).pixelRound.height
            let dateSize = viewModel.formattedSentDate.boundingRect(with: CGSize(width: width, height: .infinity), options: [], context: nil).pixelRound

            let tagHeight = viewModel.tagImage?.size.height ?? 0
            let textHeight = max(senderHeight, dateSize.height) + Layout.subjectTopMargin + subjectHeight
            height = max(Layout.minimumHeight,
                         Layout.cellVerticalMargin + max(tagHeight, textHeight) + Layout.cellVerticalMargin)

            // 3. Tag and overlay
            tagFrame = CGRect(
                x: Layout.cellHorizontalMargin,
                y: (height - tagHeight) / 2,
                width: tagSize,
                height: tagHeight)
                .pixelRound

            let tagOverlaySize = CGSize(width: 18, height: 18)
            tagOverlayFrame = CGRect(
                x: tagFrame.maxX - tagOverlaySize.width + Layout.tagOverlayOffset.horizontal,
                y: tagFrame.maxY - tagOverlaySize.height + Layout.tagOverlayOffset.vertical,
                width: tagOverlaySize.width,
                height: tagOverlaySize.height)

            // 4. Date
            dateFrame = CGRect(
                x: width - Layout.cellHorizontalMargin - dateSize.width,
                y: (height - textHeight) / 2,
                width: dateSize.width,
                height: dateSize.height)
                .pixelRound

            // 5. Sender
            let senderX = viewModel.tagImage == nil
                ? Layout.cellHorizontalMargin
                : tagFrame.maxX + Layout.tagRightMargin
            senderFrame = CGRect(
                x: senderX,
                y: (height - textHeight) / 2,
                width: dateFrame.maxX - senderX - Layout.dateLeftMargin,
                height: senderHeight)

            // 6. Subject
            subjectFrame = CGRect(
                x: senderFrame.minX,
                y: senderFrame.maxY + Layout.subjectTopMargin,
                width: dateFrame.maxX - senderFrame.minX,
                height: subjectHeight)
        }
    }

    static var estimatedHeight: CGFloat { return 65 }

    static func heightForViewModel(_ viewModel: ViewModel, inTableWithWidth width: CGFloat) -> CGFloat {
        return Layout(width: width, viewModel: viewModel).height
    }

    static func separatorLeftInset(showsTagAndRating: Bool, inTableWithWidth width: CGFloat) -> CGFloat {
        let viewModel = ViewModel(
            backgroundColor: .clear,
            selectedBackgroundColor: .clear,
            sender: .init(),
            sentDate: .distantPast,
            sentDateAttributes: [:],
            subject: .init(),
            tagImage: showsTagAndRating ? ThreadTagLoader.emptyThreadTagImage : nil,
            tagOverlayImage: nil)
        return Layout(width: width, viewModel: viewModel).subjectFrame.minX
    }
}

private func stringForSentDate(_ date: Date?) -> String {
    guard let date = date else { return "" }

    let calendar = Calendar.current
    let units: Set<Calendar.Component> = [.day, .month, .year]
    let sent = calendar.dateComponents(units, from: date)
    let today = calendar.dateComponents(units, from: Date())
    let formatter = sent == today ? sentTimeFormatter : sentDateFormatter
    return formatter.string(from: date)
}

private let sentDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    formatter.doesRelativeDateFormatting = true
    return formatter
}()

private let sentTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()
