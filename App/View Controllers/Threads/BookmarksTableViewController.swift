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
import SwiftUI
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "BookmarksTableViewController")

@available(iOS 14.0, *)
private class FilterMenuViewController: UIViewController {
    private let segmentedControl: UISegmentedControl
    private let stackView: UIStackView
    private var currentFilter: BookmarkFilter
    private let starCategories: [StarCategory]
    private let theme: Theme
    private let onFilterSelected: (BookmarkFilter) -> Void
    private let createColorCircleImage: (StarCategory) -> UIImage?
    var onDismiss: (() -> Void)?
    
    private var visualEffectView: UIVisualEffectView?
    private var contentContainerView: UIView!
    private var sourceButtonRect: CGRect?
    private var sourceButtonSuperview: UIView?
    private var positioningConstraints: [NSLayoutConstraint] = []
    private var colorButtons: [UIButton] = []
    
    init(currentFilter: BookmarkFilter, theme: Theme, createColorCircleImage: @escaping (StarCategory) -> UIImage?, onFilterSelected: @escaping (BookmarkFilter) -> Void) {
        self.currentFilter = currentFilter
        self.theme = theme
        self.onFilterSelected = onFilterSelected
        self.createColorCircleImage = createColorCircleImage
        self.starCategories = Array(StarCategory.allCases.filter { $0 != .none })
        
        // Create segmented control
        self.segmentedControl = UISegmentedControl(items: ["All", "Unread", "Read"])
        
        // Set initial selection
        switch currentFilter {
        case .all: segmentedControl.selectedSegmentIndex = 0
        case .unreadOnly: segmentedControl.selectedSegmentIndex = 1
        case .readOnly: segmentedControl.selectedSegmentIndex = 2
        default: segmentedControl.selectedSegmentIndex = 0
        }
        
        // Create stack view
        self.stackView = UIStackView()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    func setSourceButton(_ button: UIView, in superview: UIView) {
        sourceButtonRect = button.frame
        sourceButtonSuperview = superview
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Clear main view and add semi-transparent backdrop
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        // Add tap gesture to dismiss when tapping backdrop
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backdropTapped(_:)))
        view.addGestureRecognizer(tapGesture)
        
        // Create content container that will be positioned like a popover
        contentContainerView = UIView()
        contentContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.layer.cornerRadius = 16
        contentContainerView.layer.masksToBounds = true
        view.addSubview(contentContainerView)
        
        // Setup background for content container - use glass effect for iOS 26+ if accessibility allows
        if #available(iOS 26.0, *), !UIAccessibility.isReduceTransparencyEnabled {
            let glassEffect = UIGlassEffect()
            let effectView = UIVisualEffectView(effect: glassEffect)
            effectView.translatesAutoresizingMaskIntoConstraints = false
            
            // Configure interface style for proper dark/light glass appearance
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
        }
    }
    
    @objc private func backdropTapped(_ gesture: UITapGestureRecognizer) {
        // Only dismiss if tap was on the backdrop, not the content
        let location = gesture.location(in: view)
        if !contentContainerView.frame.contains(location) {
            dismiss(animated: true) { [weak self] in
                self?.onDismiss?()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupContent()
        updateFilterUI()  // Set initial selection state
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Position after layout is complete, only if not already positioned
        if positioningConstraints.isEmpty {
            positionContentContainer()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Clean up UI elements when dismissing (only if being dismissed, not covered)
        if isBeingDismissed || isMovingFromParent {
            segmentedControl.isHidden = true
            stackView.isHidden = true
            colorButtons.forEach { $0.isHidden = true }
        }
    }
    
    private func setupContent() {
        // Configure segmented control
        segmentedControl.backgroundColor = theme["navigationBarBackgroundColor"]
        segmentedControl.selectedSegmentTintColor = theme["tintColor"]
        
        // Fix the segmented control appearance
        segmentedControl.selectedSegmentTintColor = theme["tintColor"]
        segmentedControl.backgroundColor = theme["navigationBarBackgroundColor"]
        segmentedControl.layer.cornerRadius = 8
        segmentedControl.clipsToBounds = true
        
        
        if let textColor = theme[uicolor: "listTextColor"] {
            segmentedControl.setTitleTextAttributes([
                .foregroundColor: textColor,
                .font: UIFont.systemFont(ofSize: 15, weight: .medium)
            ], for: .normal)
        }
        if let selectedTextColor = theme[uicolor: "navigationBarBackgroundColor"] {
            segmentedControl.setTitleTextAttributes([
                .foregroundColor: selectedTextColor,
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
            ], for: .selected)
        }
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        
        // Configure stack view
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .center
        stackView.distribution = .equalCentering
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(iOS 26.0, *), let effectView = visualEffectView {
            effectView.contentView.addSubview(stackView)
        } else {
            contentContainerView.addSubview(stackView)
        }
        
        // Set segmented control height to be much smaller
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            segmentedControl.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        stackView.addArrangedSubview(segmentedControl)
        
        // Add color category buttons if any exist
        if !starCategories.isEmpty {
            // Create 2x3 grid for color buttons with better spacing and centering
            let colorGridView = UIView()
            stackView.addArrangedSubview(colorGridView)
            
            let buttonSize: CGFloat = 32
            let horizontalSpacing: CGFloat = 24
            let verticalSpacing: CGFloat = 16
            
            // Calculate total grid dimensions
            let gridWidth = 3 * buttonSize + 2 * horizontalSpacing
            let gridHeight = 2 * buttonSize + verticalSpacing
            
            for (index, category) in starCategories.enumerated() {
                let button = createColorButton(for: category)
                colorButtons.append(button)
                colorGridView.addSubview(button)
                
                let row = index / 3
                let col = index % 3
                
                button.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    button.widthAnchor.constraint(equalToConstant: buttonSize),
                    button.heightAnchor.constraint(equalToConstant: buttonSize),
                    button.leadingAnchor.constraint(equalTo: colorGridView.leadingAnchor, constant: CGFloat(col) * (buttonSize + horizontalSpacing)),
                    button.topAnchor.constraint(equalTo: colorGridView.topAnchor, constant: CGFloat(row) * (buttonSize + verticalSpacing))
                ])
            }
            
            // Set grid constraints
            colorGridView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                colorGridView.heightAnchor.constraint(equalToConstant: gridHeight),
                colorGridView.widthAnchor.constraint(equalToConstant: gridWidth)
            ])
        }
        
        if #available(iOS 26.0, *), let effectView = visualEffectView {
            NSLayoutConstraint.activate([
                stackView.centerYAnchor.constraint(equalTo: effectView.contentView.centerYAnchor),
                stackView.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: 8),
                stackView.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -8),
                stackView.topAnchor.constraint(greaterThanOrEqualTo: effectView.contentView.topAnchor, constant: 8),
                stackView.bottomAnchor.constraint(lessThanOrEqualTo: effectView.contentView.bottomAnchor, constant: -8)
            ])
        } else {
            NSLayoutConstraint.activate([
                stackView.centerYAnchor.constraint(equalTo: contentContainerView.centerYAnchor),
                stackView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 8),
                stackView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -8),
                stackView.topAnchor.constraint(greaterThanOrEqualTo: contentContainerView.topAnchor, constant: 8),
                stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentContainerView.bottomAnchor, constant: -8)
            ])
        }
        
        // Set preferred content size - doubled size
        let categoryHeight = starCategories.isEmpty ? 0 : (8 + 44) // spacing + grid (20*2 + 4)
        let height = 8 + 32 + categoryHeight + 8 // top + segmented + categories + bottom
        preferredContentSize = CGSize(width: 300, height: min(height * 2, 200))
    }
    
    
    
    private func positionContentContainer() {
        guard let sourceRect = sourceButtonRect,
              let sourceSuperview = sourceButtonSuperview else {
            // Center if no source info
            centerContentContainer()
            return
        }
        
        // Convert source button rect to our view's coordinate system
        let convertedRect = view.convert(sourceRect, from: sourceSuperview)
        
        // Position container below and to the right of the button
        let containerWidth: CGFloat = 300
        let containerHeight: CGFloat = 200
        
        // Position more to the right and further down
        let x = max(16, min(convertedRect.midX + 40, view.bounds.width - containerWidth - 16))
        let y = convertedRect.maxY - 40
        
        // Remove existing positioning constraints
        NSLayoutConstraint.deactivate(positioningConstraints)
        
        // Create and store new constraints
        positioningConstraints = [
            contentContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: x),
            contentContainerView.topAnchor.constraint(equalTo: view.topAnchor, constant: y),
            contentContainerView.widthAnchor.constraint(equalToConstant: containerWidth),
            contentContainerView.heightAnchor.constraint(equalToConstant: containerHeight)
        ]
        
        NSLayoutConstraint.activate(positioningConstraints)
    }
    
    private func centerContentContainer() {
        // Remove existing positioning constraints
        NSLayoutConstraint.deactivate(positioningConstraints)
        
        // Create and store new constraints
        positioningConstraints = [
            contentContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentContainerView.widthAnchor.constraint(equalToConstant: 300),
            contentContainerView.heightAnchor.constraint(equalToConstant: 200)
        ]
        
        NSLayoutConstraint.activate(positioningConstraints)
    }
    
    
    private func createColorButton(for category: StarCategory) -> UIButton {
        let button = UIButton(type: .system)
        
        // Create color circle for the button background
        let buttonSize: CGFloat = 32
        let colorKey: String
        switch category {
        case .orange: colorKey = "unreadBadgeOrangeColor"
        case .red: colorKey = "unreadBadgeRedColor"
        case .yellow: colorKey = "unreadBadgeYellowColor"
        case .cyan: colorKey = "unreadBadgeCyanColor"
        case .green: colorKey = "unreadBadgeGreenColor"
        case .purple: colorKey = "unreadBadgePurpleColor"
        case .none: colorKey = "unreadBadgeBlueColor"
        }
        
        if let color = theme[uicolor: colorKey] {
            button.backgroundColor = color
        }
        
        // Make it circular
        button.layer.cornerRadius = buttonSize / 2
        button.clipsToBounds = true
        
        // Add selection indicator if this category is currently selected
        if case .starCategory(let currentCategory) = currentFilter, currentCategory == category {
            button.layer.borderWidth = 2
            button.layer.borderColor = theme[uicolor: "tintColor"]?.cgColor ?? UIColor.systemBlue.cgColor
        } else {
            button.layer.borderWidth = 0
        }
        
        button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
        button.tag = Int(category.rawValue)
        
        return button
    }
    
    
    @objc private func colorButtonTapped(_ sender: UIButton) {
        let category = StarCategory(rawValue: Int16(sender.tag)) ?? .orange
        
        // Check if this color is already selected
        if case .starCategory(let currentCategory) = currentFilter, currentCategory == category {
            // Already selected - unselect by switching to .all
            currentFilter = .all
            onFilterSelected(.all)
        } else {
            // Not selected - select this color
            let filter = BookmarkFilter.starCategory(category)
            currentFilter = filter
            // When selecting a color, move segmented control away from "All"
            segmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
            onFilterSelected(filter)
        }
        
        // Update UI to reflect new selection
        updateFilterUI()
    }
    
    @objc private func segmentChanged() {
        let filter: BookmarkFilter
        switch segmentedControl.selectedSegmentIndex {
        case 0: filter = .all  // This will clear any color selections
        case 1: filter = .unreadOnly
        case 2: filter = .readOnly
        default: filter = .all
        }
        
        currentFilter = filter
        onFilterSelected(filter)
        updateFilterUI()
    }
    
    private func updateFilterUI() {
        // Update segmented control selection
        switch currentFilter {
        case .all: segmentedControl.selectedSegmentIndex = 0
        case .unreadOnly: segmentedControl.selectedSegmentIndex = 1
        case .readOnly: segmentedControl.selectedSegmentIndex = 2
        case .starCategory(_): segmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
        default: segmentedControl.selectedSegmentIndex = 0
        }
        
        // Update color button borders
        for button in colorButtons {
            let category = StarCategory(rawValue: Int16(button.tag)) ?? .orange
            
            // Only show border if current filter is a starCategory AND matches this button's category
            if case .starCategory(let currentCategory) = currentFilter, currentCategory == category {
                // Selected - show border
                button.layer.borderWidth = 2
                button.layer.borderColor = theme[uicolor: "tintColor"]?.cgColor ?? UIColor.systemBlue.cgColor
            } else {
                // Not selected OR filter is not a starCategory - no border
                button.layer.borderWidth = 0
            }
        }
    }
}

final class BookmarksTableViewController: TableViewController {
    
    private var cancellables: Set<AnyCancellable> = []
    private var dataSource: ThreadListDataSource?
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
    private var searchBar: UISearchBar!
    private var searchBarContainerView: UIView!
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
        // Create a custom button for better control
        filterButtonView = UIButton(type: .system)
        filterButtonView.setImage(UIImage(systemName: "line.3.horizontal.decrease"), for: .normal)
        filterButtonView.accessibilityLabel = "Filter bookmarks"
        filterButtonView.addTarget(self, action: #selector(filterButtonTapped), for: .touchUpInside)
        
        // Wrap in bar button item
        filterButton = UIBarButtonItem(customView: filterButtonView)
        
        // Update filter menu when theme changes
        updateFilterMenuIfNeeded()
    }
    
    @available(iOS 14.0, *)
    private func createColorCircleImage(for starCategory: StarCategory) -> UIImage? {
        let colorKey: String
        switch starCategory {
        case .orange: colorKey = "unreadBadgeOrangeColor"
        case .red: colorKey = "unreadBadgeRedColor"
        case .yellow: colorKey = "unreadBadgeYellowColor"
        case .cyan: colorKey = "unreadBadgeCyanColor"
        case .green: colorKey = "unreadBadgeGreenColor"
        case .purple: colorKey = "unreadBadgePurpleColor"
        case .none: colorKey = "unreadBadgeBlueColor"
        }
        
        guard let color = theme[uicolor: colorKey] else { return nil }
        
        let size = CGSize(width: 20, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            color.setFill()
            let rect = CGRect(origin: .zero, size: size)
            context.cgContext.fillEllipse(in: rect)
        }
    }
    
    private func setupSearchButton() {
        searchButton = UIBarButtonItem(
            image: UIImage(named: "quick-look"),
            style: .plain,
            target: self,
            action: #selector(searchButtonTapped)
        )
        searchButton.accessibilityLabel = "Search bookmarks"
    }
    
    private func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "Search by title or author..."
        searchBar.showsCancelButton = true
        searchBar.searchBarStyle = .minimal
        searchBar.isHidden = true // Start hidden
        
        searchBarContainerView = UIView()
        searchBarContainerView.addSubview(searchBar)
        
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: searchBarContainerView.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: searchBarContainerView.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: searchBarContainerView.trailingAnchor, constant: -16),
            searchBar.bottomAnchor.constraint(equalTo: searchBarContainerView.bottomAnchor, constant: -8)
        ])
    }
    
    
    private func updateFilterMenuIfNeeded() {
        // No longer needed since we're using a custom popover instead of context menu
    }
    
    @objc private func filterButtonTapped() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        // If popover is already shown, dismiss it
        if let existingPopover = filterPopoverController {
            existingPopover.dismiss(animated: true) { [weak self] in
                self?.filterPopoverController = nil
            }
            return
        }
        
        if #available(iOS 14.0, *) {
            // Show custom filter menu with segmented control
            let filterMenuVC = FilterMenuViewController(
                currentFilter: currentFilter,
                theme: theme,
                createColorCircleImage: { [weak self] category in
                    return self?.createColorCircleImage(for: category)
                },
                onFilterSelected: { [weak self] filter in
                    self?.filterPopoverController?.dismiss(animated: true) { [weak self] in
                        self?.filterPopoverController = nil
                    }
                    self?.applyFilter(filter)
                }
            )
            
            // Set up onDismiss callback to clear reference
            filterMenuVC.onDismiss = { [weak self] in
                self?.filterPopoverController = nil
            }
            
            // Use overCurrentContext for glass effect, then position like a popover
            filterMenuVC.modalPresentationStyle = .overCurrentContext
            filterMenuVC.modalTransitionStyle = .crossDissolve
            filterMenuVC.presentationController?.delegate = self
            
            // Set source button information for positioning
            filterMenuVC.setSourceButton(filterButtonView, in: view)
            
            // No popover configuration needed - we handle positioning ourselves
            
            filterPopoverController = filterMenuVC
            present(filterMenuVC, animated: true)
        } else {
            // Fallback to action sheet for older iOS versions
            let alert = UIAlertController(title: "Filter Bookmarks", message: nil, preferredStyle: .actionSheet)
            
            for filter in BookmarkFilter.quickFilters {
                let action = UIAlertAction(title: filter.title, style: .default) { [weak self] _ in
                    self?.applyFilter(filter)
                }
                
                let isSelected: Bool
                switch (currentFilter, filter) {
                case (.all, .all), (.unreadOnly, .unreadOnly), (.readOnly, .readOnly):
                    isSelected = true
                case (.starCategory(let currentStar), .starCategory(let filterStar)):
                    isSelected = currentStar == filterStar
                default:
                    isSelected = false
                }
                
                if isSelected {
                    action.setValue(true, forKey: "checked")
                }
                alert.addAction(action)
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            if let popover = alert.popoverPresentationController {
                popover.barButtonItem = filterButton
            }
            
            present(alert, animated: true)
        }
    }
    
    @objc private func searchButtonTapped() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        toggleSearchBar()
    }
    
    private func toggleSearchBar() {
        let isSearchVisible = searchBarContainerView.frame.height > 0
        
        if !isSearchVisible {
            // Show search bar with smooth animation
            searchBar.isHidden = false
            searchBar.alpha = 0
            
            // Start with height 0, then animate to full height
            searchBarContainerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 0)
            tableView.tableHeaderView = searchBarContainerView
            
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3,
                options: [.curveEaseInOut],
                animations: {
                    // Animate height and alpha together
                    self.searchBarContainerView.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 56)
                    self.tableView.tableHeaderView = self.searchBarContainerView
                    self.searchBar.alpha = 1.0
                },
                completion: { _ in
                    self.searchBar.becomeFirstResponder()
                    self.updateButtonColors()
                }
            )
        } else {
            // Hide search bar with smooth animation
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
                    // Animate both height and alpha together
                    self.searchBarContainerView.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 0)
                    self.tableView.tableHeaderView = self.searchBarContainerView
                    self.searchBar.alpha = 0.0
                },
                completion: { _ in
                    self.searchBar.isHidden = true
                    self.updateButtonColors()
                }
            )
        }
    }
    
    private func applyFilter(_ filter: BookmarkFilter) {
        currentFilter = filter
        dataSource = makeDataSource()
        tableView.reloadData()
        
        // Update button colors based on filter state
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
        
        let isSearchVisible = searchBarContainerView.frame.height > 0
        
        // Use the same selected color for both filter and search when active
        let selectedColor = theme[uicolor: "tintColor"] ?? theme[uicolor: "navigationBarTextColor"]
        let normalColor = theme[uicolor: "navigationBarTextColor"]
        
        let filterColor = isFilterActive ? selectedColor : normalColor
        let searchColor = isSearchVisible ? selectedColor : normalColor
        
        filterButton?.tintColor = filterColor
        filterButtonView?.tintColor = filterColor
        searchButton?.tintColor = searchColor
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

                // Batch UI updates to prevent hitching
                await MainActor.run {
                    // Only recreate data source if we're on page 1 (full refresh)
                    // This prevents unnecessary recreation during load more
                    if page == 1 {
                        // Temporarily disable animations to prevent visual glitches
                        UIView.performWithoutAnimation {
                            dataSource = makeDataSource()
                            tableView.reloadData()
                        }
                    }
                    
                    if threads.count >= 40 {
                        enableLoadMore()
                    } else {
                        disableLoadMore()
                    }
                    
                    // Ensure pull-to-refresh stops after all UI updates
                    stopAnimatingPullToRefresh()
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

        tableView.hideExtraneousSeparators()
        tableView.restorationIdentifier = "Bookmarks table"
        
        // Set up search bar as table header view initially hidden
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
        // Takes care of toggling the button's title.
        super.setEditing(editing, animated: true)

        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        // Toggle table view editing.
        tableView.setEditing(editing, animated: true)
    }
    
    override func themeDidChange() {
        super.themeDidChange()

        loadMoreFooter?.themeDidChange()
        
        // Update navigation bar button colors to follow theme
        editButtonItem.tintColor = theme[uicolor: "navigationBarTextColor"]
        updateButtonColors()
        
        
        // Update search bar theme
        if let searchBar = searchBar {
            searchBarContainerView.backgroundColor = theme["listBackgroundColor"]
            searchBar.barTintColor = theme["listBackgroundColor"]
            searchBar.backgroundColor = theme["listBackgroundColor"]
            searchBar.searchTextField.backgroundColor = theme["navigationBarBackgroundColor"]
            searchBar.searchTextField.textColor = theme["listTextColor"]
            searchBar.tintColor = theme["tintColor"]
        }
        
        // Update filter menu to match theme
        updateFilterMenuIfNeeded()

        // Set interface style for context menus to follow theme
        let themeMode = theme[string: "mode"]
        let userInterfaceStyle: UIUserInterfaceStyle = themeMode == "light" ? .light : .dark
        
        overrideUserInterfaceStyle = userInterfaceStyle
        tableView.overrideUserInterfaceStyle = userInterfaceStyle
        view.overrideUserInterfaceStyle = userInterfaceStyle
        
        // Update interface style for context menus
        if #available(iOS 14.0, *) {
            let themeMode = theme[string: "mode"]
            let userInterfaceStyle: UIUserInterfaceStyle = themeMode == "light" ? .light : .dark
            filterButtonView?.overrideUserInterfaceStyle = userInterfaceStyle
        }
        

        tableView.separatorColor = theme["listSeparatorColor"]
        tableView.separatorInset.left = ThreadListCell.separatorLeftInset(
            showsTagAndRating: showThreadTags,
            inTableWithWidth: tableView.bounds.width
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Ensure context menu has correct appearance
        updateFilterMenuIfNeeded()
        
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
        // If search bar is animating, complete it first to prevent UI glitches
        if !searchBar.isHidden && searchBarContainerView.frame.height != 56 {
            // Force completion of any ongoing search bar animations
            searchBarContainerView.layer.removeAllAnimations()
            searchBar.layer.removeAllAnimations()
            
            // Set final state based on whether search is active
            if searchBar.text?.isEmpty == false {
                searchBarContainerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 56)
                searchBar.alpha = 1.0
            } else {
                searchBarContainerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 0)
                searchBar.alpha = 0.0
                searchBar.isHidden = true
            }
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
        postsViewController.restorationIdentifier = "Posts"
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
        let thread = dataSource!.thread(at: indexPath)
        return UIContextMenuConfiguration.makeFromThreadList(for: thread, presenter: self, theme: theme)
    }


        
}

extension BookmarksTableViewController: ThreadListDataSourceDeletionDelegate {
    func didDeleteThread(_ thread: AwfulThread, in dataSource: ThreadListDataSource) {
        setThread(thread, isBookmarked: false)
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

@available(iOS 14.0, *)
extension BookmarksTableViewController: UIPopoverPresentationControllerDelegate, UIAdaptivePresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        // Force popover style on all devices - glass effect now works with our fixes
        return .none
    }
    
    func prepareForPopoverPresentation(_ popoverPresentationController: UIPopoverPresentationController) {
        // Additional popover configuration if needed
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        // Clean up when popover is dismissed by user tapping outside
        filterPopoverController = nil
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // Clean up when dismissed via swipe or other system gesture
        filterPopoverController = nil
    }
}
