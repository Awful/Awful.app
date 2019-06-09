//  ForumListCell.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// In the Forum list, each cell represents either a favorite forum or a plain old forum.
final class ForumListCell: UITableViewCell {

    /// Called when the expand/collapes button is tapped.
    var didTapExpand: ((ForumListCell) -> Void)?

    /// Called when the favorite star is tapped.
    var didTapFavorite: ((ForumListCell) -> Void)?

    private let expandButton = ExpandForumButton()
    private let favoriteButton = FavoriteForumButton()

    private let nameLabel: UILabel = {
        let nameLabel = UILabel()
        nameLabel.numberOfLines = 0
        return nameLabel
    }()

    var viewModel: ViewModel = .empty {
        didSet {
            backgroundColor = viewModel.backgroundColor

            switch viewModel.expansion {
            case .none:
                expandButton.isHidden = true

            case .canExpand:
                expandButton.isHidden = false
                expandButton.isSelected = false

            case .isExpanded:
                expandButton.isHidden = false
                expandButton.isSelected = true
            }

            expandButton.tintColor = viewModel.expansionTintColor

            switch viewModel.favoriteStar {
            case .hidden:
                favoriteButton.isHidden = true

            case .canFavorite:
                favoriteButton.isHidden = false
                favoriteButton.isSelected = false

            case .isFavorite:
                favoriteButton.isHidden = false
                favoriteButton.isSelected = true
            }

            favoriteButton.tintColor = viewModel.favoriteStarTintColor

            nameLabel.attributedText = viewModel.forumName

            if selectedBackgroundView == nil {
                selectedBackgroundView = UIView()
            }
            selectedBackgroundView?.backgroundColor = viewModel.selectedBackgroundColor

            setNeedsLayout()
        }
    }

    struct ViewModel {
        let backgroundColor: UIColor
        let expansion: Expansion
        let expansionTintColor: UIColor
        let favoriteStar: FavoriteStar
        let favoriteStarTintColor: UIColor
        let forumName: NSAttributedString
        let indentationLevel: Int
        let selectedBackgroundColor: UIColor

        enum Expansion {
            case none
            case canExpand
            case isExpanded
        }

        enum FavoriteStar {
            case hidden
            case canFavorite
            case isFavorite
        }

        static var empty: ViewModel {
            return ViewModel(
                backgroundColor: .white,
                expansion: .none,
                expansionTintColor: .black,
                favoriteStar: .hidden,
                favoriteStarTintColor: .black,
                forumName: .init(),
                indentationLevel: 0,
                selectedBackgroundColor: .white)
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(expandButton)
        contentView.addSubview(favoriteButton)
        contentView.addSubview(nameLabel)

        expandButton.addTarget(self, action: #selector(didTapExpandButton), for: .touchUpInside)
        favoriteButton.addTarget(self, action: #selector(didTapFavoriteButton), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func didTapExpandButton(_ sender: UIButton) {
        didTapExpand?(self)
    }

    @objc private func didTapFavoriteButton(_ sender: UIButton) {
        didTapFavorite?(self)
    }

    override func willTransition(to state: UITableViewCell.StateMask) {
        super.willTransition(to: state)

        if state.contains(UITableViewCell.StateMask.showingEditControl) {
            favoriteButton.alpha = 0
        }
        else {
            favoriteButton.alpha = 1
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let layout = Layout(width: contentView.bounds.width, viewModel: viewModel, isEditing: isEditing)
        expandButton.frame = layout.expandFrame
        favoriteButton.frame = layout.favoriteStarFrame
        nameLabel.frame = layout.nameFrame
    }

    private struct Layout {
        let expandFrame: CGRect
        let favoriteStarFrame: CGRect
        let height: CGFloat
        let nameFrame: CGRect

        static let expandWidth: CGFloat = 44
        static let indentationMargin: CGFloat = 15
        static let minimumHeight: CGFloat = 44
        static let nameMargin: CGFloat = 8
        static let starWidth: CGFloat = 38

        init(width: CGFloat, viewModel: ViewModel, isEditing: Bool) {
            let expandWidth = isEditing ? 0 : Layout.expandWidth
            let indentation = Layout.indentationMargin * CGFloat(viewModel.indentationLevel)
            let starWidth = isEditing ? 0 : Layout.starWidth

            let nameWidth = width
                - (starWidth + Layout.nameMargin)
                - (Layout.nameMargin + expandWidth)
                - indentation

            let nameHeight = ceil(viewModel.forumName.boundingRect(
                with: CGSize(width: nameWidth, height: .infinity),
                options: .usesLineFragmentOrigin,
                context: nil).height)

            height = max(Layout.minimumHeight, Layout.nameMargin + nameHeight + Layout.nameMargin)

            let contentRect = CGRect(x: 0, y: 0, width: width, height: height)

            var remainder: CGRect
            (favoriteStarFrame, remainder) = contentRect.divided(atDistance: starWidth, from: .minXEdge)
            (expandFrame, remainder) = remainder.divided(atDistance: expandWidth, from: .maxXEdge)
            nameFrame = remainder
                .insetBy(dx: Layout.nameMargin, dy: Layout.nameMargin)
                .divided(atDistance: indentation, from: .minXEdge).remainder
        }
    }

    static var estimatedHeight: CGFloat { return Layout.minimumHeight }

    static func heightForViewModel(_ viewModel: ViewModel, inTableWithWidth width: CGFloat) -> CGFloat {
        return Layout(width: width, viewModel: viewModel, isEditing: false).height
    }
}

final class ExpandForumButton: UIButton {
    init() {
        super.init(frame: .zero)

        setImage(UIImage(named: "forum-arrow-down"), for: .normal)
        setImage(UIImage(named: "forum-arrow-minus"), for: .selected)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class FavoriteForumButton: UIButton {
    init() {
        super.init(frame: .zero)

        setImage(UIImage(named: "star-off"), for: .normal)
        setImage(UIImage(named: "star-on"), for: .selected)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
