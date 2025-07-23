//  SwiftUIForumsView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import CoreData
import SwiftUI

struct SwiftUIForumsView: View {
    @StateObject private var viewModel: ForumsListViewModel
    @SwiftUI.Environment(\.theme) private var theme
    var coordinator: (any MainCoordinator)?
    let isEditingFromParent: Bool
    
    @State private var showingSearch = false
    
    init(managedObjectContext: NSManagedObjectContext, coordinator: (any MainCoordinator)? = nil, isEditing: Bool = false) {
        self._viewModel = StateObject(wrappedValue: {
            do {
                return try ForumsListViewModel(managedObjectContext: managedObjectContext)
            } catch {
                fatalError("Failed to create ForumsListViewModel: \(error)")
            }
        }())
        self.coordinator = coordinator
        self.isEditingFromParent = isEditing
    }
    
    var body: some View {
        // For now, keep the standard refreshable - niggly implementation needs more work
        forumsList
            .themed()
    }
    
    private var forumsList: some View {
        List {
            ForEach(viewModel.sections) { section in
                forumSection(section)
            }
        }
        .listStyle(.grouped)
        .background(backgroundColor)
        .scrollContentBackground(.hidden)
        .background(backgroundColor)
        .refreshable {
            await viewModel.refresh()
        }
        .environment(\.editMode, .constant(isEditingFromParent ? .active : .inactive))
        .navigationTitle("Forums")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSearch) {
            SearchView(model: SearchPageViewModel())
        }
        .onAppear {
            handleViewAppear()
        }
        .onDisappear {
            handleViewDisappear()
        }
        .onReceive(viewModel.$tabBarBadgeValue) { badgeValue in
            updateTabBarBadge(badgeValue)
        }
    }
    
    private var backgroundColor: Color {
        theme[color: "backgroundColor"] ?? Color(UIColor.systemBackground)
    }
    
    
    private func forumSection(_ section: ForumsSection) -> some View {
        Section {
            let forEachView = ForEach(section.items) { item in
                ForumRowView(
                    item: item,
                    isEditing: isEditingFromParent,
                    isInFavorites: section.type == .favorites,
                    onTap: { handleItemTap(item) },
                    onToggleFavorite: { handleToggleFavorite(item) },
                    onToggleExpansion: { handleToggleExpansion(item) }
                )
            }
            
            if section.type == .favorites {
                forEachView
                    .onDelete { indices in
                        handleDelete(in: section, at: indices)
                    }
                    .onMove { source, destination in
                        viewModel.moveFavorite(from: source, to: destination)
                    }
            } else {
                forEachView
            }
        } header: {
            ForumSectionHeaderView(title: section.title)
        }
    }
    
    private func handleItemTap(_ item: ForumItem) {
        switch item {
        case .announcement(let announcement):
            openAnnouncement(announcement)
        case .forum(let forum):
            openForum(forum)
        }
    }
    
    private func handleToggleFavorite(_ item: ForumItem) {
        guard case .forum(let forum) = item else { return }
        viewModel.toggleFavorite(for: forum)
    }
    
    private func handleToggleExpansion(_ item: ForumItem) {
        guard case .forum(let forum) = item else { return }
        viewModel.toggleExpansion(for: forum)
    }
    
    private func handleDelete(in section: ForumsSection, at indices: IndexSet) {
        for index in indices {
            if case .forum(let forum) = section.items[index] {
                viewModel.removeFavorite(forum)
            }
        }
    }
    
    private func openForum(_ forum: Forum) {
        print("🔍 SwiftUIForumsView: Attempting to navigate to forum: \(forum.name ?? "unnamed")")
        print("🔍 SwiftUIForumsView: Coordinator exists: \(coordinator != nil)")
        
        // Try navigating via coordinator first
        coordinator?.navigateToForum(forum)
        
        // If that doesn't work, try direct UIKit navigation as fallback
        if let navController = findNavigationController() {
            let threadsVC = ThreadsTableViewController(forum: forum)
            threadsVC.restorationIdentifier = "Forum: \(forum.forumID)"
            navController.pushViewController(threadsVC, animated: true)
        }
    }
    
    private func openAnnouncement(_ announcement: Announcement) {
        let vc = AnnouncementViewController(announcement: announcement)
        vc.restorationIdentifier = "Announcement"
        
        if let viewController = findViewController() {
            viewController.showDetailViewController(vc, sender: viewController)
        }
    }
    
    private func handleViewAppear() {
        if RefreshMinder.sharedMinder.shouldRefresh(.forumList) {
            Task {
                await viewModel.refresh()
            }
        }
        
        // Handle tab bar visibility for iPhone
        if UIDevice.current.userInterfaceIdiom == .phone {
            coordinator?.isTabBarHidden = false
        }
        
        // Restore view state
        restoreViewState()
    }
    
    private func handleViewDisappear() {
        viewModel.undoManager.removeAllActions()
        saveViewState()
    }
    
    private func updateTabBarBadge(_ badgeValue: String?) {
        // Update tab bar badge - this would need to be integrated with the main app's tab bar
        if let tabBarController = findViewController()?.tabBarController,
           let tabBarItems = tabBarController.tabBar.items,
           let forumsTabItem = tabBarItems.first(where: { $0.title == "Forums" }) {
            forumsTabItem.badgeValue = badgeValue
        }
    }
    
    
}

// MARK: - State Restoration

extension SwiftUIForumsView {
    private func saveViewState() {
        let state: [String: Any] = [
            "showingSearch": showingSearch
        ]
        coordinator?.saveViewState(for: "SwiftUIForumsView", state: state)
    }
    
    private func restoreViewState() {
        guard let state = coordinator?.getViewState(for: "SwiftUIForumsView") else { return }
        
        if let showingSearch = state["showingSearch"] as? Bool {
            self.showingSearch = showingSearch
        }
    }
}

// MARK: - UIKit Integration Helpers

extension SwiftUIForumsView {
    private func findViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController?.topMostViewController()
    }
    
    private func findNavigationController() -> UINavigationController? {
        return findViewController()?.navigationController ?? 
               findViewController() as? UINavigationController
    }
}

extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presentedViewController = self.presentedViewController {
            return presentedViewController.topMostViewController()
        }
        
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?.topMostViewController() ?? self
        }
        
        if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.topMostViewController() ?? self
        }
        
        return self
    }
}

// MARK: - Preview

struct SwiftUIForumsView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIForumsView(managedObjectContext: NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType))
            .themed()
    }
}
