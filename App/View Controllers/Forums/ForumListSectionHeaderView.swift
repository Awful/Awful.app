//  ForumListSectionHeaderView.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class ForumListSectionHeaderView: UICollectionReusableView {
    private let sectionNameLabel = UILabel()

    var viewModel: ViewModel = .empty {
        didSet {
            backgroundColor = viewModel.backgroundColor
            sectionNameLabel.font = viewModel.font
            sectionNameLabel.text = viewModel.sectionName
            sectionNameLabel.textColor = viewModel.textColor
        }
    }

    struct ViewModel {
        let backgroundColor: UIColor?
        let font: UIFont?
        let sectionName: String
        let textColor: UIColor?

        static var empty: ViewModel {
            return .init(
                backgroundColor: nil,
                font: nil,
                sectionName: "",
                textColor: nil)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        sectionNameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sectionNameLabel)

        NSLayoutConstraint.activate([
            sectionNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leftInset),
            sectionNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            sectionNameLabel.topAnchor.constraint(equalTo: topAnchor, constant: verticalPadding),
            sectionNameLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -verticalPadding),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private let leftInset: CGFloat = 18
private let verticalPadding: CGFloat = 8
