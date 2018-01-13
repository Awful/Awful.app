//  ForumListSectionHeaderView.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class ForumListSectionHeaderView: UITableViewHeaderFooterView {
    private let sectionNameLabel = UILabel()

    var viewModel: ViewModel = .empty {
        didSet {
            if backgroundView == nil {
                backgroundView = UIView()
            }
            backgroundView?.backgroundColor = viewModel.backgroundColor
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

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(sectionNameLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        sectionNameLabel.frame = bounds.divided(atDistance: leftInset, from: .minXEdge).remainder
    }
}

private let leftInset: CGFloat = 18
