//  NigglyRefreshableListView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI
import UIKit
import PullToRefresh

struct NigglyRefreshableListView<Content: View>: UIViewRepresentable {
    let theme: Theme
    let content: Content
    let onRefresh: () async -> Void
    
    init(theme: Theme, onRefresh: @escaping () async -> Void, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.onRefresh = onRefresh
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = theme[uicolor: "backgroundColor"] ?? UIColor.systemBackground
        
        // Create the hosting controller for SwiftUI content
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = theme[uicolor: "backgroundColor"] ?? UIColor.systemBackground
        
        // Find the UITableView in the SwiftUI hierarchy
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Store the hosting controller
        context.coordinator.hostingController = hostingController
        
        // Set up niggly refresh after a delay to ensure the table view is ready
        DispatchQueue.main.async {
            self.setupNigglyRefresh(in: hostingController.view, coordinator: context.coordinator)
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the SwiftUI content
        context.coordinator.hostingController?.rootView = content
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onRefresh: onRefresh)
    }
    
    private func setupNigglyRefresh(in view: UIView, coordinator: Coordinator) {
        // Find the UITableView recursively
        func findTableView(in view: UIView) -> UITableView? {
            if let tableView = view as? UITableView {
                return tableView
            }
            for subview in view.subviews {
                if let found = findTableView(in: subview) {
                    return found
                }
            }
            return nil
        }
        
        guard let tableView = findTableView(in: view) else {
            print("❌ Could not find UITableView in SwiftUI hierarchy")
            return
        }
        
        // Hide the default refresh control
        tableView.refreshControl?.isHidden = true
        tableView.refreshControl?.tintColor = UIColor.clear
        
        // Create niggly refresh view
        let nigglyRefreshView = NigglyRefreshLottieView(theme: theme)
        let refreshAnimator = NigglyRefreshLottieView.RefreshAnimator(view: nigglyRefreshView)
        
        let pullToRefresh = PullToRefresh(
            refreshView: nigglyRefreshView,
            animator: refreshAnimator,
            height: nigglyRefreshView.intrinsicContentSize.height,
            position: .top
        )
        
        pullToRefresh.animationDuration = 0.3
        pullToRefresh.initialSpringVelocity = 0
        pullToRefresh.springDamping = 1
        
        tableView.addPullToRefresh(pullToRefresh) {
            Task { @MainActor in
                await coordinator.onRefresh()
                tableView.endRefreshing(at: .top)
            }
        }
        
        print("✅ Successfully added niggly refresh to table view")
    }
    
    class Coordinator {
        let onRefresh: () async -> Void
        var hostingController: UIHostingController<Content>?
        
        init(onRefresh: @escaping () async -> Void) {
            self.onRefresh = onRefresh
        }
    }
}

extension View {
    func nigglyRefreshableList(theme: Theme, onRefresh: @escaping () async -> Void) -> some View {
        NigglyRefreshableListView(theme: theme, onRefresh: onRefresh) {
            self
        }
    }
}