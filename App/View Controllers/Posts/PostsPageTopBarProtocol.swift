//  PostsPageTopBarProtocol.swift
//
//  Copyright 2025 Awful Contributors

import AwfulTheming
import UIKit

protocol PostsPageTopBarProtocol: UIView {
    var goToParentForum: (() -> Void)? { get set }
    var showPreviousPosts: (() -> Void)? { get set }
    var scrollToEnd: (() -> Void)? { get set }

    func themeDidChange(_ theme: Theme)
}
