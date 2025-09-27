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
    private let createColorCircleImage: (StarCategory) -> UIImage?
    private let enableHaptics: Bool
    var onDismiss: (() -> Void)?
    
    private var visualEffectView: UIVisualEffectView?
    private lazy var contentContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = Layout.cornerRadius
        view.layer.masksToBounds = false  // Allow shadow
        
        // Add subtle shadow for depth
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = Layout.shadowOpacity
        view.layer.shadowRadius = Layout.shadowRadius
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        return view
    }()
    private var sourceButtonRect: CGRect?
    private var sourceButtonSuperview: UIView?
    private var positioningConstraints: [NSLayoutConstraint] = []
    private var colorButtons: [UIButton] = []
    
    init(currentFilter: BookmarkFilter, theme: Theme, enableHaptics: Bool, createColorCircleImage: @escaping (StarCategory) -> UIImage?, onFilterSelected: @escaping (BookmarkFilter) -> Void) {
        self.currentFilter = currentFilter
        self.theme = theme
        self.enableHaptics = enableHaptics
        self.onFilterSelected = onFilterSelected
        self.createColorCircleImage = createColorCircleImage
        self.starCategories = Array(StarCategory.allCases.filter { $0 != .none })
        
        // Create segmented control
        // TODO: Add proper localization keys to the app's localization files
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
        // Get the button's frame in the superview's coordinate system
        sourceButtonRect = button.frame
        sourceButtonSuperview = superview
        
        print("Setting source button: frame=\(button.frame) in superview=\(superview)")
    }
    
    func setSourceButtonRect(_ rect: CGRect) {
        // Direct rect setting (already in the correct coordinate system)
        sourceButtonRect = rect
        sourceButtonSuperview = view // Use our own view as reference since rect is already converted
        
        print("Setting source button rect directly: \(rect)")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Clear main view and add semi-transparent backdrop
        view.backgroundColor = UIColor.black.withAlphaComponent(Layout.backdropOpacity)
        
        // Add tap gesture to dismiss when tapping backdrop
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backdropTapped(_:)))
        view.addGestureRecognizer(tapGesture)
        
        // Add content container to view
        view.addSubview(contentContainerView)
        
        // Setup background for content container - use glass effect for iOS 26+ if accessibility allows
        if #available(iOS 26.0, *), !UIAccessibility.isReduceTransparencyEnabled {
            let glassEffect = UIGlassEffect()
            let effectView = UIVisualEffectView(effect: glassEffect)
            effectView.translatesAutoresizingMaskIntoConstraints = false
            effectView.layer.cornerRadius = Layout.cornerRadius
            effectView.layer.masksToBounds = true
            
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
            contentContainerView.layer.masksToBounds = true
        }
    }
    
    @objc private func backdropTapped(_ gesture: UITapGestureRecognizer) {
        // Only dismiss if tap was on the backdrop, not the content
        let location = gesture.location(in: view)
        if !contentContainerView.frame.contains(location) {
            // Animate out (respect reduce motion setting)
            if UIAccessibility.isReduceMotionEnabled {
                // Simple fade for reduced motion
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
        updateFilterUI()  // Set initial selection state
        
        // Accessibility setup
        view.accessibilityViewIsModal = true
        // TODO: Add proper localization keys to the app's localization files
        contentContainerView.accessibilityLabel = "Filter Menu"
        contentContainerView.accessibilityHint = "Filter bookmarks by read status or star color"
        
        // Add spring animation on appearance
        contentContainerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        contentContainerView.alpha = 0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Animate in (respect reduce motion setting)
        if UIAccessibility.isReduceMotionEnabled {
            // Simple fade for reduced motion
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
        // Configure segmented control with improved styling
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
        
        // Configure stack view with refined spacing
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
        
        // Set segmented control height with proper sizing
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            segmentedControl.heightAnchor.constraint(equalToConstant: Layout.segmentedControlHeight),
            segmentedControl.widthAnchor.constraint(equalToConstant: Layout.containerWidth - 2 * Layout.contentPadding)
        ])
        
        stackView.addArrangedSubview(segmentedControl)
        
        // Add color category buttons if any exist
        if !starCategories.isEmpty {
            // Create 2x3 grid for color buttons with refined spacing
            let colorGridView = UIView()
            stackView.addArrangedSubview(colorGridView)
            
            // Calculate total grid dimensions
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
        
        // Set preferred content size based on actual content
        let categoryHeight = starCategories.isEmpty ? 0 : (Layout.verticalSpacing + 2 * Layout.colorButtonSize + Layout.verticalSpacing)
        let _ = Layout.contentPadding + Layout.segmentedControlHeight + categoryHeight + Layout.contentPadding
        preferredContentSize = CGSize(width: Layout.containerWidth, height: Layout.containerHeight)
    }
    
    
    
    private func positionContentContainer() {
        guard let sourceRect = sourceButtonRect else {
            // Center if no source info
            centerContentContainer()
            return
        }
        
        // If sourceButtonSuperview is our own view, the rect is already converted
        let convertedRect: CGRect
        if let sourceSuperview = sourceButtonSuperview, sourceSuperview != view {
            convertedRect = view.convert(sourceRect, from: sourceSuperview)
        } else {
            convertedRect = sourceRect
        }
        
        // Debug: Print positioning info
        print("Filter menu positioning:")
        print("  Source rect: \(sourceRect)")
        print("  Converted rect: \(convertedRect)")
        print("  View bounds: \(view.bounds)")
        
        // Calculate optimal position (prefer below button, aligned to trailing edge)
        let containerX = max(16, min(convertedRect.maxX - Layout.containerWidth, view.bounds.width - Layout.containerWidth - 16))
        
        // Position below the navigation bar with proper spacing
        let navBarBottom = navigationController?.navigationBar.frame.maxY ?? 100
        let safeAreaTop = view.safeAreaInsets.top
        let containerY = max(navBarBottom + 8, safeAreaTop + 8)  // Ensure it's below the nav bar
        
        print("  Navigation bar bottom: \(navBarBottom)")
        print("  Safe area top: \(safeAreaTop)")
        
        // Check if there's enough space below, otherwise position above
        let finalY = (containerY + Layout.containerHeight > view.bounds.height - 44)
            ? convertedRect.minY - Layout.containerHeight - 8
            : containerY
        
        print("  Final position: x=\(containerX), y=\(finalY)")
        
        // Remove existing positioning constraints
        NSLayoutConstraint.deactivate(positioningConstraints)
        
        // Create and store new constraints
        positioningConstraints = [
            contentContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: containerX),
            contentContainerView.topAnchor.constraint(equalTo: view.topAnchor, constant: finalY),
            contentContainerView.widthAnchor.constraint(equalToConstant: Layout.containerWidth),
            contentContainerView.heightAnchor.constraint(equalToConstant: Layout.containerHeight)
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
            contentContainerView.widthAnchor.constraint(equalToConstant: Layout.containerWidth),
            contentContainerView.heightAnchor.constraint(equalToConstant: Layout.containerHeight)
        ]
        
        NSLayoutConstraint.activate(positioningConstraints)
    }
    
    
    private func createColorButton(for category: StarCategory) -> UIButton {
        let button = UIButton(type: .custom)  // Use custom for better control
        
        // Create color circle for the button background
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
        
        // Make it circular
        button.layer.cornerRadius = Layout.colorButtonSize / 2
        button.clipsToBounds = false  // Allow for shadow/glow effects
        
        // Accessibility setup
        let isSelected = {
            if case .starCategory(let currentCategory) = currentFilter {
                return currentCategory == category
            }
            return false
        }()
        
        // TODO: Add proper localization keys to the app's localization files
        button.accessibilityLabel = "Filter by \(colorName) star"
        button.accessibilityHint = isSelected
            ? "Currently selected. Double-tap to deselect."
            : "Double-tap to filter by this star color."
        button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        
        // Add selection indicator if this category is currently selected
        if isSelected {
            button.layer.borderWidth = 3
            button.layer.borderColor = theme[uicolor: "tintColor"]?.cgColor ?? UIColor.systemBlue.cgColor
            // Add subtle glow for selected state
            button.layer.shadowColor = theme[uicolor: "tintColor"]?.cgColor ?? UIColor.systemBlue.cgColor
            button.layer.shadowRadius = 4
            button.layer.shadowOpacity = 0.3
            button.layer.shadowOffset = .zero
        } else {
            button.layer.borderWidth = 0
            button.layer.shadowOpacity = 0
        }
        
        // Add touch handlers for animation
        button.addTarget(self, action: #selector(colorButtonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(colorButtonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
        button.tag = Int(category.rawValue)
        
        return button
    }
    
    
    @objc private func colorButtonTouchDown(_ sender: UIButton) {
        // Animate button press (respect reduce motion setting)
        if UIAccessibility.isReduceMotionEnabled {
            // Simple fade for reduced motion
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
        
        // Haptic feedback (only if enabled by user)
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    @objc private func colorButtonTouchUp(_ sender: UIButton) {
        // Animate button release (respect reduce motion setting)
        if UIAccessibility.isReduceMotionEnabled {
            // Simple fade back for reduced motion
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
        
        // Check if this color is already selected
        if case .starCategory(let currentCategory) = currentFilter, currentCategory == category {
            // Already selected - unselect by switching to .all
            currentFilter = .all
            onFilterSelected(.all)
            // Haptic feedback for deselection
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } else {
            // Not selected - select this color
            let filter = BookmarkFilter.starCategory(category)
            currentFilter = filter
            // When selecting a color, move segmented control away from "All"
            segmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
            onFilterSelected(filter)
            // Haptic feedback for selection
            if enableHaptics {
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
        
        // Update UI to reflect new selection with animation
        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.updateFilterUI()
        }
    }
    
    @objc private func segmentChanged() {
        // Haptic feedback
        if enableHaptics {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        
        let filter: BookmarkFilter
        switch segmentedControl.selectedSegmentIndex {
        case 0: filter = .all  // This will clear any color selections
        case 1: filter = .unreadOnly
        case 2: filter = .readOnly
        default: filter = .all
        }
        
        currentFilter = filter
        onFilterSelected(filter)
        
        // Animate filter UI update
        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.updateFilterUI()
        }
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
        
        // Update color button appearance with animation
        for button in colorButtons {
            let category = StarCategory(rawValue: Int16(button.tag)) ?? .orange
            
            // Check if this button should be selected
            let isSelected = {
                if case .starCategory(let currentCategory) = currentFilter {
                    return currentCategory == category
                }
                return false
            }()
            
            // Update accessibility properties
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
            
            // TODO: Add proper localization keys to the app's localization files
            button.accessibilityLabel = "Filter by \(colorName) star"
            button.accessibilityHint = isSelected
                ? "Currently selected. Double-tap to deselect."
                : "Double-tap to filter by this star color."
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
            
            // Animate selection state change
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0,
                options: [.curveEaseInOut],
                animations: { [weak self] in
                    guard let self = self else { return }
                    if isSelected {
                        // Selected - show border and glow
                        button.layer.borderWidth = 3
                        button.layer.borderColor = self.theme[uicolor: "tintColor"]?.cgColor ?? UIColor.systemBlue.cgColor
                        button.layer.shadowColor = self.theme[uicolor: "tintColor"]?.cgColor ?? UIColor.systemBlue.cgColor
                        button.layer.shadowRadius = 4
                        button.layer.shadowOpacity = 0.3
                        button.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                    } else {
                        // Not selected - remove border and glow
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
            searchBar.heightAnchor.constraint(equalToConstant: 44) // Standard search bar height
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
                self?.updateButtonColors()  // Update button color when menu closes
            }
            return
        }
        
        // Show custom filter menu with refined appearance
        let filterMenuVC = FilterMenuViewController(
            currentFilter: currentFilter,
            theme: theme,
            enableHaptics: enableHaptics,
            createColorCircleImage: { [weak self] category in
                return self?.createColorCircleImage(for: category)
            },
            onFilterSelected: { [weak self] filter in
                // Don't dismiss immediately - let the animation complete first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.filterPopoverController?.dismiss(animated: true) { [weak self] in
                        self?.filterPopoverController = nil
                        self?.updateButtonColors()  // Update button color when menu closes after selection
                    }
                }
                self?.applyFilter(filter)
            }
        )
        
        // Set up onDismiss callback to clear reference
        filterMenuVC.onDismiss = { [weak self] in
            self?.filterPopoverController = nil
            self?.updateButtonColors()  // Update button color when menu is dismissed by backdrop tap
        }
        
        // Use overCurrentContext for glass effect
        filterMenuVC.modalPresentationStyle = .overCurrentContext
        filterMenuVC.modalTransitionStyle = .crossDissolve
        filterMenuVC.presentationController?.delegate = self
        
        // Set source button information for positioning
        // Convert the button's frame to our view's coordinate system
        if filterButtonView.superview != nil {
            let buttonFrameInView = view.convert(filterButtonView.bounds, from: filterButtonView)
            filterMenuVC.setSourceButtonRect(buttonFrameInView)
            print("Converted button frame to view coordinates: \(buttonFrameInView)")
        } else {
            // Fallback: center the menu
            print("Could not find button superview, will center menu")
        }
        
        filterPopoverController = filterMenuVC
        updateButtonColors()  // Update button color when menu opens
        present(filterMenuVC, animated: false)  // Custom animation handles the fade-in
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
                    // Animate height and alpha together (8pt top margin + 44pt search bar height)
                    self.searchBarContainerView.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 52)
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
        let isFilterMenuOpen = filterPopoverController != nil
        
        // Use the same selected color for both filter and search when active
        let selectedColor = theme[uicolor: "tintColor"] ?? theme[uicolor: "navigationBarTextColor"]
        let normalColor = theme[uicolor: "navigationBarTextColor"]
        
        // Filter button should be highlighted if filter is active OR menu is open
        let filterColor = (isFilterActive || isFilterMenuOpen) ? selectedColor : normalColor
        let searchColor = isSearchVisible ? selectedColor : normalColor
        
        // Debug logging
        print("Updating button colors: filter active=\(isFilterActive), menu open=\(isFilterMenuOpen), search visible=\(isSearchVisible)")
        print("Filter color: \(String(describing: filterColor)), Normal color: \(String(describing: normalColor))")
        
        // Apply colors to both the bar button item and the custom view
        filterButton?.tintColor = filterColor
        filterButtonView?.tintColor = filterColor
        
        // For custom views in bar button items, sometimes we need to set the image tint color directly
        if let buttonView = filterButtonView,
           let currentImage = buttonView.currentImage,
           let color = filterColor {
            let tintedImage = currentImage.withTintColor(color, renderingMode: .alwaysTemplate)
            buttonView.setImage(tintedImage, for: .normal)
        }
        
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
                    // Stop the refresh animation first, before any table updates
                    stopAnimatingPullToRefresh()
                    
                    // Note: We don't need to recreate the data source here.
                    // The NSFetchedResultsController automatically updates the table
                    // when Core Data changes, which prevents the hitching issue.
                    
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
        filterButtonView?.overrideUserInterfaceStyle = userInterfaceStyle

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
        if !searchBar.isHidden && searchBarContainerView.frame.height != 52 {
            // Force completion of any ongoing search bar animations
            searchBarContainerView.layer.removeAllAnimations()
            searchBar.layer.removeAllAnimations()
            
            // Set final state based on whether search is active
            if searchBar.text?.isEmpty == false {
                searchBarContainerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 52)
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
