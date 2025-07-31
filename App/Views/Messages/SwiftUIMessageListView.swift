//  SwiftUIMessageListView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import CoreData
import SwiftUI

struct SwiftUIMessageListView: View {
    @StateObject private var viewModel: MessageListViewModel
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.tabManager) private var tabManager
    // Removed AwfulNavigationController - using coordinator only
    var coordinator: (any MainCoordinator)?
    @State private var error: Error?
    @State private var showingError = false
    
    private let managedObjectContext: NSManagedObjectContext
    
    init(managedObjectContext: NSManagedObjectContext, coordinator: (any MainCoordinator)? = nil) {
        self.managedObjectContext = managedObjectContext
        self.coordinator = coordinator
        self._viewModel = StateObject(wrappedValue: {
            do {
                return try MessageListViewModel(managedObjectContext: managedObjectContext)
            } catch {
                fatalError("Failed to create MessageListViewModel: \(error)")
            }
        }())
    }
    
    var body: some View {
        messagesList
        .onAppear {
            handleViewAppear()
        }
        .onDisappear {
            handleViewDisappear()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            // Handle Core Data context saves if needed
        }
        .onReceive(viewModel.$tabBarBadgeValue) { badgeValue in
            updateTabBarBadge(badgeValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DeleteMessage"))) { notification in
            if let message = notification.object as? PrivateMessage {
                handleDeleteMessage(message)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            if let error = error {
                Text(error.localizedDescription)
            }
        }
        .themed()
    }
    
    private var messagesList: some View {
        List {
            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, messageViewModel in
                MessageRowView(
                    viewModel: messageViewModel,
                    onTap: {
                        handleMessageTap(messageViewModel, at: index)
                    },
                    message: viewModel.message(at: index)
                )
                .listRowPressEffect {
                    handleMessageTap(messageViewModel, at: index)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                .listRowSeparator(.visible, edges: .bottom)
                .listRowSeparatorTint(Color(theme[uicolor: "listSeparatorColor"] ?? UIColor.separator))
                .listRowBackground(backgroundColor)
                .deleteDisabled(!tabManager.messagesIsEditing)
            }
            .onDelete(perform: tabManager.messagesIsEditing ? deleteMessages : nil)
        }
        .listStyle(.plain)
        .background(backgroundColor)
        .scrollContentBackground(.hidden)
        .refreshable {
            await refresh()
        }
        .environment(\.editMode, .constant(tabManager.messagesIsEditing ? .active : .inactive))
        .onAppear {
            // Set the background color for edit mode controls
            UITableView.appearance().backgroundColor = UIColor(backgroundColor)
        }
    }
    
    private var backgroundColor: Color {
        Color(theme[uicolor: "listBackgroundColor"] ?? UIColor.systemBackground)
    }
    
    // MARK: - Actions
    
    private func showCompose() {
        if viewModel.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        // Present compose view controller
        let composeVC = MessageComposeViewController()
        composeVC.restorationIdentifier = "Compose private message"
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        // Find the topmost view controller to present from
        var topViewController = window.rootViewController
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        
        topViewController?.present(composeVC.enclosingNavigationController, animated: true)
    }
    
    private func handleMessageTap(_ messageViewModel: MessageRowViewModel, at index: Int) {
        guard let message = viewModel.message(at: index) else { return }
        
        if viewModel.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        showMessage(message)
    }
    
    private func showMessage(_ message: PrivateMessage) {
        // Use coordinator to navigate via SwiftUI NavigationStack
        let destination = PrivateMessageDestination(message: message)
        
        // Always use main path so messages appear in detail pane on iPad
        coordinator?.path.append(destination)
    }
    
    private func handleDeleteMessage(_ message: PrivateMessage) {
        Task {
            do {
                try await viewModel.deleteMessage(message)
            } catch {
                self.error = error
                self.showingError = true
            }
        }
    }
    
    private func deleteMessages(at offsets: IndexSet) {
        for index in offsets {
            guard let message = viewModel.message(at: index) else { continue }
            handleDeleteMessage(message)
        }
    }
    
    private func refresh() async {
        do {
            try await viewModel.refresh()
        } catch {
            self.error = error
            self.showingError = true
        }
    }
    
    // MARK: - View Lifecycle
    
    private func handleViewAppear() {
        Task {
            if viewModel.shouldRefresh() {
                await refresh()
            }
        }
    }
    
    private func handleViewDisappear() {
        // Clean up if needed
    }
    
    private func updateTabBarBadge(_ badgeValue: String?) {
        // Update tab bar badge - integrate with the main app's tab bar
        if let tabBarController = findViewController()?.tabBarController,
           let tabBarItems = tabBarController.tabBar.items,
           let messagesTabItem = tabBarItems.first(where: { $0.title == "Messages" }) {
            messagesTabItem.badgeValue = badgeValue
        }
    }
    
    private func findViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
}

struct SwiftUIMessageListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        SwiftUIMessageListView(managedObjectContext: context)
            .themed()
    }
}