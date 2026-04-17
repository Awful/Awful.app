//  BookmarksTableViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import Combine
import CoreData
import os
import ScrollViewDelegateMultiplexer
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "BookmarksTableViewController")

private class FilterMenuViewController: UIViewController {
    // MARK: - Constants
    private enum Layout {
        static let cornerRadius: CGFloat = 13
        static let backdropOpacity: CGFloat = 0.2
        static let contentPadding: CGFloat = 16
        static let segmentedControlHeight: CGFloat = 32
        static let colorButtonSize: CGFloat = 36
        static let colorButtonSpacing: CGFloat = 20
        static let verticalSpacing: CGFloat = 16
        static let containerWidth: CGFloat = 280
        static let containerHeight: CGFloat = 180
        static let shadowRadius: CGFloat = 20
        static let shadowOpacity: Float = 0.15
    }
    
    // MARK: - Properties
    private let segmentedControl: UISegmentedControl
    private let stackView: UIStackView
    private var currentFilter: BookmarkFilter
    private let starCategories: [StarCategory]
    private let theme: Theme
    private let onFilterSelected: (BookmarkFilter) -> Void
    private let enableHaptics: Bool
    var onDismiss: (() -> Void)?
    
    private var visualEffectView: UIVisualEffectView?
    private lazy var contentContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = Layout.cornerRadius
        view.layer.masksToBounds = false

        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = Layout.shadowOpacity
        view.layer.shadowRadius = Layout.shadowRadius
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        return view
    }()
    private var sourceButtonRect: CGRect?
    private var positioningConstraints: [NSLayoutConstraint] = []
    private var colorButtons: [UIButton] = []
    
    init(currentFilter: BookmarkFilter, theme: Theme, enableHaptics: Bool, onFilterSelected: @escaping (BookmarkFilter) -> Void) {
        self.currentFilter = currentFilter
        self.theme = theme
        self.enableHaptics = enableHaptics
        self.onFilterSelected = onFilterSelected
        self.starCategories = Array(StarCategory.allCases.filter { $0 != .none })
        
        self.segmentedControl = UISegmentedControl(items: [
            LocalizedString("bookmarks.filter.all"),
            LocalizedString("bookmarks.filter.unread"),
            LocalizedString("bookmarks.filter.read"),
        ])
        
        switch currentFilter {
        case .all: segmentedControl.selectedSegmentIndex = 0
        case .unreadOnly: segmentedControl.selectedSegmentIndex = 1
        case .readOnly: segmentedControl.selectedSegmentIndex = 2
        default: segmentedControl.selectedSegmentIndex = 0
        }
        
        self.stackView = UIStackView()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    func setSourceButtonRect(_ rect: CGRect) {
        sourceButtonRect = rect
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(Layout.backdropOpacity)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backdropTapped(_:)))
        view.addGestureRecognizer(tapGesture)
        
        view.addSubview(contentContainerView)

        // Use glass effect for iOS 26+ when accessibility allows, otherwise solid background
        if #available(iOS 26.0, *), !UIAccessibility.isReduceTransparencyEnabled {
            let glassEffect = UIGlassEffect()
            let effectView = UIVisualEffectView(effect: glassEffect)
            effectView.translatesAutoresizingMaskIntoConstraints = false
            effectView.layer.cornerRadius = Layout.cornerRadius
            effectView.layer.masksToBounds = true
            
            let themeMode = theme[string: "mode"]
            effectView.overrideUserInterfaceStyle = themeMode == "dark" ? .dark : .light
            
            visualEffectView = effectView
            
            contentContainerView.addSubview(effectView)
            NSLayoutConstraint.activate([
                effectView.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
                effectView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
                effectView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor),
                effectView.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor)
            ])
        } else {
            contentContainerView.backgroundColor = theme["sheetBackgroundColor"]
            contentContainerView.layer.masksToBounds = true
        }
    }
    
    @objc private func backdropTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if !contentContainerView.frame.contains(location) {
            if UIAccessibility.isReduceMotionEnabled {
                UIView.animate(
                    withDuration: 0.2,
                    animations: { [weak self] in
                        self?.contentContainerView.alpha = 0
                        self?.view.backgroundColor = UIColor.black.withAlphaComponent(0)
                    },
                    completion: { [weak self] _ in
                        self?.dismiss(animated: false) { [weak self] in
                            self?.onDismiss?()
                        }
                    }
                )
            } else {
                UIView.animate(
                    withDuration: 0.25,
                    delay: 0,
                    usingSpringWithDamping: 1.0,
                    initialSpringVelocity: 0,
                    options: [.curveEaseIn],
                    animations: { [weak self] in
                        self?.contentContainerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                        self?.contentContainerView.alpha = 0
                        self?.view.backgroundColor = UIColor.black.withAlphaComponent(0)
                    },
                    completion: { [weak self] _ in
                        self?.dismiss(animated: false) { [weak self] in
                            self?.onDismiss?()
                        }
                    }
                )
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupContent()
        updateFilterUI()

        view.accessibilityViewIsModal = true
        contentContainerView.accessibilityLabel = LocalizedString("bookmarks.filter.menu.accessibility-label")
        contentContainerView.accessibilityHint = LocalizedString("bookmarks.filter.menu.accessibility-hint")
        
        contentContainerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        contentContainerView.alpha = 0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.2) { [weak self] in
                self?.contentContainerView.transform = .identity
                self?.contentContainerView.alpha = 1.0
            }
        } else {
            UIView.animate(
                withDuration: 0.35,
                delay: 0,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.5,
                options: [.curveEaseOut],
                animations: { [weak self] in
                    self?.contentContainerView.transform = .identity
                    self?.contentContainerView.alpha = 1.0
                }
            )
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if positioningConstraints.isEmpty {
            positionContentContainer()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            segmentedControl.isHidden = true
            stackView.isHidden = true
            colorButtons.forEach { $0.isHidden = true }
        }
    }
    
    private func setupContent() {
        segmentedControl.backgroundColor = theme["navigationBarBackgroundColor"]
        segmentedControl.selectedSegmentTintColor = theme["tintColor"]
        segmentedControl.layer.cornerRadius = Layout.segmentedControlHeight / 2
        segmentedControl.clipsToBounds = true
        
        if let textColor = theme[uicolor: "listTextColor"] {
            segmentedControl.setTitleTextAttributes([
                .foregroundColor: textColor,
                .font: UIFont.systemFont(ofSize: 14, weight: .medium)
            ], for: .normal)
        }
        if let selectedTextColor = theme[uicolor: "navigationBarBackgroundColor"] {
            segmentedControl.setTitleTextAttributes([
                .foregroundColor: selectedTextColor,
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
            ], for: .selected)
        }
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        
        stackView.axis = .vertical
        stackView.spacing = Layout.verticalSpacing
        stackView.alignment = .center
        stackView.distribution = .equalCentering
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(iOS 26.0, *), let effectView = visualEffectView {
            effectView.contentView.addSubview(stackView)
        } else {
            contentContainerView.addSubview(stackView)
        }
        
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            segmentedControl.heightAnchor.constraint(equalToConstant: Layout.segmentedControlHeight),
            segmentedControl.widthAnchor.constraint(equalToConstant: Layout.containerWidth - 2 * Layout.contentPadding)
        ])
        
        stackView.addArrangedSubview(segmentedControl)
        
        if !starCategories.isEmpty {
            let colorGridView = UIView()
            stackView.addArrangedSubview(colorGridView)
            
            let gridWidth = 3 * Layout.colorButtonSize + 2 * Layout.colorButtonSpacing
            let gridHeight = 2 * Layout.colorButtonSize + Layout.verticalSpacing
            
            for (index, category) in starCategories.enumerated() {
                let button = createColorButton(for: category)
                colorButtons.append(button)
                colorGridView.addSubview(button)
                
                let row = index / 3
                let col = index % 3
                
                button.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    button.widthAnchor.constraint(equalToConstant: Layout.colorButtonSize),
                    button.heightAnchor.constraint(equalToConstant: Layout.colorButtonSize),
                    button.leadingAnchor.constraint(equalTo: colorGridView.leadingAnchor, constant: CGFloat(col) * (Layout.colorButtonSize + Layout.colorButtonSpacing)),
                    button.topAnchor.constraint(equalTo: colorGridView.topAnchor, constant: CGFloat(row) * (Layout.colorButtonSize + Layout.verticalSpacing))
                ])
            }
            
            colorGridView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                colorGridView.heightAnchor.constraint(equalToConstant: gridHeight),
                colorGridView.widthAnchor.constraint(equalToConstant: gridWidth)
            ])
        }
        
        if #available(iOS 26.0, *), let effectView = visualEffectView {
            NSLayoutConstraint.activate([
                stackView.centerYAnchor.constraint(equalTo: effectView.contentView.centerYAnchor),
                stackView.centerXAnchor.constraint(equalTo: effectView.contentView.centerXAnchor),
                stackView.leadingAnchor.constraint(greaterThanOrEqualTo: effectView.contentView.leadingAnchor, constant: Layout.contentPadding),
                stackView.trailingAnchor.constraint(lessThanOrEqualTo: effectView.contentView.trailingAnchor, constant: -Layout.contentPadding),
                stackView.topAnchor.constraint(greaterThanOrEqualTo: effectView.contentView.topAnchor, constant: Layout.contentPadding),
                stackView.bottomAnchor.constraint(lessThanOrEqualTo: effectView.contentView.bottomAnchor, constant: -Layout.contentPadding)
            ])
        } else {
            NSLayoutConstraint.activate([
                stackView.centerYAnchor.constraint(equalTo: contentContainerView.centerYAnchor),
                stackView.centerXAnchor.constraint(equalTo: contentContainerView.centerXAnchor),
                stackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentContainerView.leadingAnchor, constant: Layout.contentPadding),
                stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentContainerView.trailingAnchor, constant: -Layout.contentPadding),
                stackView.topAnchor.constraint(greaterThanOrEqualTo: contentContainerView.topAnchor, constant: Layout.contentPadding),
                stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentContainerView.bottomAnchor, constant: -Layout.contentPadding)
            ])
        }
        
        preferredContentSize = CGSize(width: Layout.containerWidth, height: Layout.containerHeight)
    }

    private func positionContentContainer() {
        guard let sourceRect = sourceButtonRect else {
            centerContentContainer()
            return
        }

        let containerX = max(16, min(sourceRect.maxX - Layout.containerWidth, view.bounds.width - Layout.containerWidth - 16))

        let navBarBottom = navigationController?.navigationBar.frame.maxY ?? 100
        let safeAreaTop = view.safeAreaInsets.top
        let containerY = max(navBarBottom + 8, safeAreaTop + 8)
        let finalY = (containerY + Layout.containerHeight > view.bounds.height - 44)
            ? sourceRect.minY - Layout.containerHeight - 8
            : containerY
        
        NSLayoutConstraint.deactivate(positioningConstraints)
        positioningConstraints = [
            contentContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: containerX),
            contentContainerView.topAnchor.constraint(equalTo: view.topAnchor, constant: finalY),
            contentContainerView.widthAnchor.constraint(equalToConstant: Layout.containerWidth),
            contentContainerView.heightAnchor.constraint(equalToConstant: Layout.containerHeight)
        ]
        NSLayoutConstraint.activate(positioningConstraints)
    }
    
    private func centerContentContainer() {
        NSLayoutConstraint.deactivate(positioningConstraints)
        positioningConstraints = [
            contentContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentContainerView.widthAnchor.constraint(equalToConstant: Layout.containerWidth),
            contentContainerView.heightAnchor.constraint(equalToConstant: Layout.containerHeight)
        ]
        
        NSLayoutConstraint.activate(positioningConstraints)
    }

    private func createColorButton(for category: StarCategory) -> UIButton {
        let button = UIButton(type: .custom)

        let colorKey: String
        let colorName: String
        switch category {
        case .orange:
            colorKey = "unreadBadgeOrangeColor"
            colorName = "Orange"
        case .red:
            colorKey = "unreadBadgeRedColor"
            colorName = "Red"
        case .yellow:
            colorKey = "unreadBadgeYellowColor"
            colorName = "Yellow"
        case .cyan:
            colorKey = "unreadBadgeCyanColor"
            colorName = "Cyan"
        case .green:
            colorKey = "unreadBadgeGreenColor"
            colorName = "Green"
        case .purple:
            colorKey = "unreadBadgePurpleColor"
            colorName = "Purple"
        case .none:
            colorKey = "unreadBadgeBlueColor"
            colorName = "Blue"
        }
        
        if let color = theme[uicolor: colorKey] {
            button.backgroundColor = color
        }
        
        button.layer.cornerRadius = Layout.colorButtonSize / 2
        button.clipsToBounds = false

        let isSelected = {
            if case .starCategory(let currentCategory) = currentFilter {
                return currentCategory == category
            }
            return false
        }()
        
        button.accessibilityLabel = String(format: LocalizedString("bookmarks.filter.star.accessibility-label"), colorName)
        button.accessibilityHint = isSelected
            ? LocalizedString("bookmarks.filter.star.accessibility-hint.selected")
            : LocalizedString("bookmarks.filter.star.accessibility-hint.unselected")
        button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        
        if isSelected {
            button.layer.borderWidth = 3
            button.layer.borderColor = theme[uicolor: "tintColor"]?.cgColor ?? UIColor.systemBlue.cgColor
            button.layer.shadowColor = theme[uicolor: "tintColor"]?.cgColor ?? UIColor.systemBlue.cgColor
            button.layer.shadowRadius = 4
            button.layer.shadowOpacity = 0.3
            button.layer.shadowOffset = .zero
        } else {
            button.layer.borderWidth = 0
            button.layer.shadowOpacity = 0
        }
        
        button.addTarget(self, action: #selector(colorButtonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(colorButtonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
        button.tag = Int(category.rawValue)
        
        return button
    }

    @objc private func colorButtonTouchDown(_ sender: UIButton) {
        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.1) {
                sender.alpha = 0.7
            }
        } else {
            UIView.animate(
                withDuration: 0.1,
                delay: 0,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                }
            )
        }
        
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    @objc private func colorButtonTouchUp(_ sender: UIButton) {
        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.2) {
                sender.alpha = 1.0
            }
        } else {
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0.5,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    sender.transform = .identity
                }
            )
        }
    }
    
    @objc private func colorButtonTapped(_ sender: UIButton) {
        let category = StarCategory(rawValue: Int16(sender.tag)) ?? .orange

        if case .starCategory(let currentCategory) = currentFilter, currentCategory == category {
            currentFilter = .all
            onFilterSelected(.all)
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } else {
            let filter = BookmarkFilter.starCategory(category)
            currentFilter = filter
            segmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
            onFilterSelected(filter)
            if enableHaptics {
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }

        animateSelectionThenDismiss()
    }

    @objc private func segmentChanged() {
        if enableHaptics {
            UISelectionFeedbackGenerator().selectionChanged()
        }

        let filter: BookmarkFilter
        switch segmentedControl.selectedSegmentIndex {
        case 0: filter = .all
        case 1: filter = .unreadOnly
        case 2: filter = .readOnly
        default: filter = .all
        }

        currentFilter = filter
        onFilterSelected(filter)

        animateSelectionThenDismiss()
    }

    private func animateSelectionThenDismiss() {
        UIView.animate(
            withDuration: 0.2,
            animations: { [weak self] in
                self?.updateFilterUI()
            },
            completion: { [weak self] _ in
                self?.dismiss(animated: true) { [weak self] in
                    self?.onDismiss?()
                }
            }
        )
    }

    private func updateFilterUI() {
        switch currentFilter {
        case .all: segmentedControl.selectedSegmentIndex = 0
        case .unreadOnly: segmentedControl.selectedSegmentIndex = 1
        case .readOnly: segmentedControl.selectedSegmentIndex = 2
        case .starCategory(_): segmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
        default: segmentedControl.selectedSegmentIndex = 0
        }
        
        for button in colorButtons {
            let category = StarCategory(rawValue: Int16(button.tag)) ?? .orange
            
            let isSelected = {
                if case .starCategory(let currentCategory) = currentFilter {
                    return currentCategory == category
                }
                return false
            }()
            
            let colorName = {
                switch category {
                case .orange: return "Orange"
                case .red: return "Red"
                case .yellow: return "Yellow"
                case .cyan: return "Cyan"
                case .green: return "Green"
                case .purple: return "Purple"
                case .none: return "Blue"
                }
            }()
            
            button.accessibilityLabel = String(format: LocalizedString("bookmarks.filter.star.accessibility-label"), colorName)
            button.accessibilityHint = isSelected
                ? LocalizedString("bookmarks.filter.star.accessibility-hint.selected")
                : LocalizedString("bookmarks.filter.star.accessibility-hint.unselected")
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
            
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0,
                options: [.curveEaseInOut],
                animations: { [weak self] in
                    guard let self = self else { return }
                    if isSelected {
                        button.layer.borderWidth = 3
                        button.layer.borderColor = self.theme[uicolor: "tintColor"]?.cgColor ?? UIColor.systemBlue.cgColor
                        button.layer.shadowColor = self.theme[uicolor: "tintColor"]?.cgColor ?? UIColor.systemBlue.cgColor
                        button.layer.shadowRadius = 4
                        button.layer.shadowOpacity = 0.3
                        button.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                    } else {
                        button.layer.borderWidth = 0
                        button.layer.shadowOpacity = 0
                        button.transform = .identity
                    }
                }
            )
        }
    }
}

final class BookmarksTableViewController: TableViewController {
    
    private var cancellables: Set<AnyCancellable> = []
    private var dataSource: ThreadListDataSource?
    private var lastKnownTableWidth: CGFloat = 0
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    private var latestPage = 0
    private var loadMoreFooter: LoadMoreFooter?
    private let managedObjectContext: NSManagedObjectContext
    @FoilDefaultStorage(Settings.showThreadTags) private var showThreadTags
    @FoilDefaultStorage(Settings.bookmarksSortedUnread) private var sortUnreadToTop

    private var currentFilter: BookmarkFilter = .all
    private var filterButton: UIBarButtonItem!
    private var filterButtonView: UIButton!
    private var searchButton: UIBarButtonItem!
    private var searchButtonView: UIButton!
    private var searchBar: UISearchBar!
    private var searchBarContainerView: UIView!
    private var isSearchVisible = false
    private var filterPopoverController: UIViewController?
    

    private lazy var multiplexer: ScrollViewDelegateMultiplexer = {
        return ScrollViewDelegateMultiplexer(scrollView: tableView)
    }()

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        
        super.init(style: .plain)
        
        title = LocalizedString("bookmarks.title")

        tabBarItem.image = UIImage(named: "bookmarks")
        tabBarItem.selectedImage = UIImage(named: "bookmarks-filled")

        setupFilterButton()
        setupSearchButton()
        setupSearchBar()
        navigationItem.leftBarButtonItem = editButtonItem
        navigationItem.rightBarButtonItems = [filterButton, searchButton]

        themeDidChange()
    }
    
    private func setupFilterButton() {
        filterButtonView = UIButton(type: .system)
        filterButtonView.setImage(UIImage(systemName: "line.3.horizontal.decrease"), for: .normal)
        filterButtonView.accessibilityLabel = LocalizedString("bookmarks.filter.button.accessibility-label")
        filterButtonView.addTarget(self, action: #selector(filterButtonTapped), for: .touchUpInside)

        if #available(iOS 26.0, *) {
            filterButtonView.tintAdjustmentMode = .normal
        }

        filterButton = UIBarButtonItem(customView: filterButtonView)
    }
    
    private func setupSearchButton() {
        searchButtonView = UIButton(type: .system)
        searchButtonView.setImage(UIImage(named: "quick-look"), for: .normal)
        searchButtonView.accessibilityLabel = LocalizedString("bookmarks.search.button.accessibility-label")
        searchButtonView.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)

        if #available(iOS 26.0, *) {
            searchButtonView.tintAdjustmentMode = .normal
        }

        searchButton = UIBarButtonItem(customView: searchButtonView)
    }
    
    private func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = LocalizedString("bookmarks.search.placeholder")
        searchBar.showsCancelButton = true
        searchBar.searchBarStyle = .minimal
        searchBar.isHidden = true
        
        searchBarContainerView = UIView()
        searchBarContainerView.addSubview(searchBar)
        
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: searchBarContainerView.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: searchBarContainerView.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: searchBarContainerView.trailingAnchor, constant: -16),
            searchBar.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func filterButtonTapped() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        if let existingPopover = filterPopoverController {
            existingPopover.dismiss(animated: true) { [weak self] in
                self?.filterPopoverController = nil
                self?.updateButtonColors()
            }
            return
        }
        
        let filterMenuVC = FilterMenuViewController(
            currentFilter: currentFilter,
            theme: theme,
            enableHaptics: enableHaptics,
            onFilterSelected: { [weak self] filter in
                self?.applyFilter(filter)
            }
        )

        filterMenuVC.onDismiss = { [weak self] in
            self?.filterPopoverController = nil
            self?.updateButtonColors()
        }
        
        filterMenuVC.modalPresentationStyle = .overCurrentContext
        filterMenuVC.modalTransitionStyle = .crossDissolve
        filterMenuVC.presentationController?.delegate = self
        
        if filterButtonView.superview != nil {
            let buttonFrameInView = view.convert(filterButtonView.bounds, from: filterButtonView)
            filterMenuVC.setSourceButtonRect(buttonFrameInView)
        }
        
        filterPopoverController = filterMenuVC
        updateButtonColors()
        present(filterMenuVC, animated: false)
    }
    
    @objc private func searchButtonTapped() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        toggleSearchBar()
    }
    
    private func toggleSearchBar() {
        if !isSearchVisible {
            isSearchVisible = true
            searchBar.isHidden = false
            searchBar.alpha = 0

            searchBarContainerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 0)
            tableView.tableHeaderView = searchBarContainerView
            updateButtonColors()

            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3,
                options: [.curveEaseInOut],
                animations: {
                    self.searchBarContainerView.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 52)
                    self.tableView.tableHeaderView = self.searchBarContainerView
                    self.searchBar.alpha = 1.0
                },
                completion: { _ in
                    self.searchBar.becomeFirstResponder()
                }
            )
        } else {
            isSearchVisible = false
            searchBar.resignFirstResponder()
            searchBar.text = ""
            applyFilter(.all)

            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.9,
                initialSpringVelocity: 0.1,
                options: [.curveEaseInOut],
                animations: {
                    self.searchBarContainerView.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 0)
                    self.tableView.tableHeaderView = self.searchBarContainerView
                    self.searchBar.alpha = 0.0
                },
                completion: { _ in
                    self.searchBar.isHidden = true
                }
            )
        }
    }
    
    private func applyFilter(_ filter: BookmarkFilter) {
        currentFilter = filter
        dataSource = makeDataSource()
        tableView.reloadData()
        
        updateButtonColors()
    }
    
    private func updateButtonColors() {
        let isFilterActive: Bool
        switch currentFilter {
        case .starCategory(_), .unreadOnly, .readOnly:
            isFilterActive = true
        case .all:
            isFilterActive = false
        case .textSearch(_):
            isFilterActive = true
        }
        
        let isFilterMenuOpen = filterPopoverController != nil

        if #available(iOS 26.0, *) {
            // Explicit tint color prevents system default blue when NavigationController sets tintColor = nil
            let buttonTintColor = theme["mode"] == "dark" ? UIColor.white : UIColor.black

            filterButton?.tintColor = buttonTintColor
            filterButtonView?.tintColor = buttonTintColor
            searchButton?.tintColor = buttonTintColor
            searchButtonView?.tintColor = buttonTintColor

            filterButton?.customView?.alpha = (isFilterActive || isFilterMenuOpen) ? 0.5 : 1.0
            filterButtonView?.alpha = (isFilterActive || isFilterMenuOpen) ? 0.5 : 1.0

            searchButton?.customView?.alpha = isSearchVisible ? 0.5 : 1.0
            searchButtonView?.alpha = isSearchVisible ? 0.5 : 1.0
        } else {
            filterButton?.customView?.alpha = 1.0
            filterButtonView?.alpha = 1.0
            searchButton?.customView?.alpha = 1.0
            searchButtonView?.alpha = 1.0

            let selectedColor = theme[uicolor: "tintColor"] ?? theme[uicolor: "navigationBarTextColor"]
            let normalColor = theme[uicolor: "navigationBarTextColor"]

            let filterColor = (isFilterActive || isFilterMenuOpen) ? selectedColor : normalColor

            let searchColor = isSearchVisible ? selectedColor : normalColor
            
            filterButton?.tintColor = filterColor
            filterButtonView?.tintColor = filterColor

            if let buttonView = filterButtonView,
               let currentImage = buttonView.currentImage,
               let color = filterColor {
                let tintedImage = currentImage.withTintColor(color, renderingMode: .alwaysTemplate)
                buttonView.setImage(tintedImage, for: .normal)
            }

            searchButton?.tintColor = searchColor
            searchButtonView?.tintColor = searchColor

            if let buttonView = searchButtonView,
               let currentImage = buttonView.currentImage,
               let color = searchColor {
                let tintedImage = currentImage.withTintColor(color, renderingMode: .alwaysTemplate)
                buttonView.setImage(tintedImage, for: .normal)
            }
        }
    }

    deinit {
        if isViewLoaded {
            multiplexer.removeDelegate(self)
        }
    }

    private func makeDataSource() -> ThreadListDataSource {
        let dataSource = try! ThreadListDataSource(
            bookmarksSortedByUnread: sortUnreadToTop,
            showsTagAndRating: showThreadTags,
            filter: currentFilter,
            managedObjectContext: managedObjectContext,
            tableView: tableView
        )
        dataSource.deletionDelegate = self
        return dataSource
    }
    
    private func loadPage(page: Int) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        Task {
            do {
                let threads = try await ForumsClient.shared.listBookmarkedThreads(page: page)
                latestPage = page
                RefreshMinder.sharedMinder.didRefresh(.bookmarks)

                await MainActor.run {
                    stopAnimatingPullToRefresh()

                    if threads.count >= 40 {
                        enableLoadMore()
                    } else {
                        disableLoadMore()
                    }
                    
                    loadMoreFooter?.didFinish()
                }
            } catch {
                await MainActor.run {
                    if visible {
                        let alert = UIAlertController(networkError: error)
                        present(alert, animated: true)
                    }
                    stopAnimatingPullToRefresh()
                    loadMoreFooter?.didFinish()
                }
            }
        }
    }
    
    private func enableLoadMore() {
        guard loadMoreFooter == nil else { return }
        
        loadMoreFooter = LoadMoreFooter(tableView: tableView, multiplexer: multiplexer, loadMore: { [weak self] loadMoreFooter in
            guard let self = self else { return }
            self.loadPage(page: self.latestPage + 1)
        })
    }
    
    private func disableLoadMore() {
        loadMoreFooter?.removeFromTableView()
        loadMoreFooter = nil
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        multiplexer.addDelegate(self)

        tableView.insetsContentViewsToSafeArea = false
        tableView.hideExtraneousSeparators()

        searchBarContainerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 0)
        searchBarContainerView.clipsToBounds = true
        tableView.tableHeaderView = searchBarContainerView

        dataSource = makeDataSource()
        tableView.reloadData()
        
        pullToRefreshBlock = { [weak self] in self?.refresh() }

        $handoffEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.prepareUserActivity() }
            .store(in: &cancellables)

        Publishers.Merge($showThreadTags.dropFirst(), $sortUnreadToTop.dropFirst())
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                dataSource = makeDataSource()
                tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: true)

        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        tableView.setEditing(editing, animated: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let currentWidth = tableView.bounds.width
        if lastKnownTableWidth != 0 && lastKnownTableWidth != currentWidth {
            ThreadListCell.lastKnownContentViewWidth = nil
        }
        lastKnownTableWidth = currentWidth
    }

    override func themeDidChange() {
        super.themeDidChange()

        loadMoreFooter?.themeDidChange()

        if #unavailable(iOS 26.0) {
            editButtonItem.tintColor = theme[uicolor: "navigationBarTextColor"]
        }
        updateButtonColors()

        if let searchBar = searchBar {
            searchBarContainerView.backgroundColor = theme["listBackgroundColor"]
            searchBar.barTintColor = theme["listBackgroundColor"]
            searchBar.backgroundColor = theme["listBackgroundColor"]
            searchBar.searchTextField.backgroundColor = theme["navigationBarBackgroundColor"]
            searchBar.searchTextField.textColor = theme["listTextColor"]
            searchBar.tintColor = theme["tintColor"]
        }
        
        let themeMode = theme[string: "mode"]
        let userInterfaceStyle: UIUserInterfaceStyle = themeMode == "light" ? .light : .dark
        
        overrideUserInterfaceStyle = userInterfaceStyle
        tableView.overrideUserInterfaceStyle = userInterfaceStyle
        view.overrideUserInterfaceStyle = userInterfaceStyle
        
        filterButtonView?.overrideUserInterfaceStyle = userInterfaceStyle

        tableView.separatorColor = theme["listSeparatorColor"]
        
        tableView.separatorInset.left = ThreadListCell.separatorLeftInset(
            showsTagAndRating: showThreadTags,
            inTableWithWidth: tableView.bounds.width
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        prepareUserActivity()
        
        if tableView.numberOfSections > 0, tableView.numberOfRows(inSection: 0) > 0 {
            enableLoadMore()
        }
        
        becomeFirstResponder()
        
        if tableView.numberOfSections == 0
            || tableView.numberOfRows(inSection: 0) == 0
            || RefreshMinder.sharedMinder.shouldRefresh(.bookmarks)
        {
            refresh()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        undoManager.removeAllActions()
        
        resignFirstResponder()
    }
    
    // MARK: Actions

    private func refresh() {
        // Snap any in-flight search bar animation to its terminal state so
        // pull-to-refresh doesn't fight the spring animation.
        if isSearchVisible, searchBarContainerView.frame.height != 52 {
            searchBarContainerView.layer.removeAllAnimations()
            searchBar.layer.removeAllAnimations()
            searchBarContainerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 52)
            searchBar.alpha = 1.0
            tableView.tableHeaderView = searchBarContainerView
        } else if !isSearchVisible, !searchBar.isHidden {
            searchBarContainerView.layer.removeAllAnimations()
            searchBar.layer.removeAllAnimations()
            searchBarContainerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 0)
            searchBar.alpha = 0.0
            searchBar.isHidden = true
            tableView.tableHeaderView = searchBarContainerView
        }

        startAnimatingPullToRefresh()
        loadPage(page: 1)
    }
    
    // MARK: Handoff
    
    private func prepareUserActivity() {
        guard handoffEnabled else {
            userActivity = nil
            return
        }
        
        userActivity = NSUserActivity(activityType: Handoff.ActivityType.listingThreads)
        userActivity?.needsSave = true
    }
    
    override func updateUserActivityState(_ activity: NSUserActivity) {
        activity.route = .bookmarks
        activity.title = LocalizedString("handoff.bookmarks-title")

        logger.debug("handoff activity set: \(activity.activityType) with \(activity.userInfo ?? [:])")
    }
    
    // MARK: Undo
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override var undoManager: UndoManager {
        return _undoManager
    }
    
    private let _undoManager: UndoManager = {
        let undoManager = UndoManager()
        undoManager.levelsOfUndo = 1
        return undoManager
    }()
    
    @objc private func setThread(_ thread: AwfulThread, isBookmarked: Bool) {
        (undoManager.prepare(withInvocationTarget: self) as AnyObject).setThread(thread, isBookmarked: !isBookmarked)
        undoManager.setActionName("Delete")
        
        thread.bookmarked = false

        Task { [weak self] in
            do {
                try await ForumsClient.shared.setThread(thread, isBookmarked: isBookmarked)
            } catch {
                let alert = UIAlertController(networkError: error)
                self?.present(alert, animated: true)
            }
        }
    }
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: UITableViewDelegate
extension BookmarksTableViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return dataSource!.tableView(tableView, heightForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let thread = dataSource!.thread(at: indexPath)
        let postsViewController = PostsPageViewController(thread: thread)
        // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
        let targetPage = thread.beenSeen ? ThreadPage.nextUnread : .first
        postsViewController.loadPage(targetPage, updatingCache: true, updatingLastReadPost: true)
        showDetailViewController(postsViewController, sender: self)
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        if tableView.isEditing {
            let delete = UIContextualAction(style: .destructive, title: LocalizedString("table-view.action.delete"), handler: { action, view, completion in
                guard let thread = self.dataSource?.thread(at: indexPath) else { return }
                self.setThread(thread, isBookmarked: false)
                completion(true)
            })
            let config = UISwipeActionsConfiguration(actions: [delete])
            config.performsFirstActionWithFullSwipe = false
            return config
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if tableView.isEditing {
            return .delete
        }
        return .none
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let configuration = UIContextMenuConfiguration.makeFromThreadList(
            for: dataSource!.thread(at: indexPath),
            presenter: self
        )
        if #available(iOS 16.0, *) {
            configuration.preferredMenuElementOrder = .fixed
        }
        return configuration
    }
}

extension BookmarksTableViewController: ThreadListDataSourceDeletionDelegate {
    func didDeleteThread(_ thread: AwfulThread, in dataSource: ThreadListDataSource) {
        setThread(thread, isBookmarked: false)
    }
}

extension BookmarksTableViewController: RestorableLocation {
    var restorationRoute: AwfulRoute? {
        .bookmarks
    }
}

extension BookmarksTableViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            applyFilter(.all)
        } else {
            applyFilter(.textSearch(trimmedText))
        }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        toggleSearchBar()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension BookmarksTableViewController: UIPopoverPresentationControllerDelegate, UIAdaptivePresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        .none
    }

    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        filterPopoverController = nil
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        filterPopoverController = nil
    }
}
