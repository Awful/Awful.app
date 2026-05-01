//  ForumListCell.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import UIKit

/// In the Forum list, each cell represents either a favorite forum or a plain old forum.
final class ForumListCell: UICollectionViewListCell {

    /// Called when the expand/collapse button is tapped.
    var didTapExpand: ((ForumListCell) -> Void)?

    /// Called when the favorite star is tapped.
    var didTapFavorite: ((ForumListCell) -> Void)?

    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    private let expandButton = ExpandForumButton()
    private let favoriteButton = FavoriteForumButton()

    private let nameLabel: UILabel = {
        let nameLabel = UILabel()
        nameLabel.numberOfLines = 0
        return nameLabel
    }()

    var viewModel: ViewModel = .empty {
        didSet {
            contentView.backgroundColor = viewModel.backgroundColor

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

            selectedBackgroundColor = viewModel.selectedBackgroundColor

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

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundConfiguration = UIBackgroundConfiguration.clear()

        // Stop the cell's own directional layout margins from inseting contentView.
        // The Layout struct already accounts for explicit nameMargin / starWidth /
        // expandWidth — letting the system add another ~8pt on each side narrows
        // the name label and forces unnecessary wraps.
        preservesSuperviewLayoutMargins = false
        directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        contentView.preservesSuperviewLayoutMargins = false
        contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

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
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        didTapExpand?(self)
    }

    @objc private func didTapFavoriteButton(_ sender: UIButton) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        didTapFavorite?(self)
    }

    private var isInEditingState = false

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)

        // Hide the favorite star while editing so the row's delete accessory has room.
        isInEditingState = state.isEditing
        favoriteButton.alpha = state.isEditing ? 0 : 1
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let layout = Layout(width: contentView.bounds.width, viewModel: viewModel, isEditing: isInEditingState)
        expandButton.frame = layout.expandFrame
        favoriteButton.frame = layout.favoriteStarFrame
        nameLabel.frame = layout.nameFrame
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let width = layoutAttributes.size.width
        let height = Layout(width: width, viewModel: viewModel, isEditing: isInEditingState).height
        attributes.size = CGSize(width: width, height: height)
        return attributes
    }

    private struct Layout {
        let expandFrame: CGRect
        let favoriteStarFrame: CGRect
        let height: CGFloat
        let nameFrame: CGRect

        static let expandWidth: CGFloat = 30
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
