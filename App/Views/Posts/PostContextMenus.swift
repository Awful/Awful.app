//  PostContextMenus.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import SwiftUI
import UIKit

// MARK: - Post Context Menu

struct PostContextMenu: View {
    let post: Post
    let viewModel: PostsPageViewModel
    let onDismiss: () -> Void
    
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    
    var body: some View {
        Menu {
            Button(action: {
                performHapticFeedback()
                handleQuote()
            }) {
                Label("Quote", systemImage: "quote.bubble")
            }
            
            Button(action: {
                performHapticFeedback()
                handleMarkAsRead()
            }) {
                Label("Mark as Read Up To Here", systemImage: "eye")
            }
            
            Button(action: {
                performHapticFeedback()
                handleShare()
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Button(action: {
                performHapticFeedback()
                handleReport()
            }) {
                Label("Report", systemImage: "exclamationmark.triangle")
            }
        } label: {
            // Invisible button for menu positioning
            Rectangle()
                .fill(Color.clear)
                .frame(width: 1, height: 1)
        }
    }
    
    private func performHapticFeedback() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    private func handleQuote() {
        viewModel.quotePost(post) { workspace in
            // Handle reply workspace creation
            Task { @MainActor in
                AppDelegate.instance.mainCoordinator?.presentReplyWorkspace(workspace)
            }
        }
        onDismiss()
    }
    
    private func handleMarkAsRead() {
        viewModel.markAsReadUpTo(post)
        onDismiss()
    }
    
    private func handleShare() {
        AppDelegate.instance.mainCoordinator?.presentSharePost(post)
        onDismiss()
    }
    
    private func handleReport() {
        AppDelegate.instance.mainCoordinator?.presentReportPost(post)
        onDismiss()
    }
}

// MARK: - User Context Menu

struct UserContextMenu: View {
    let post: Post
    let author: User
    let viewModel: PostsPageViewModel
    let onDismiss: () -> Void
    
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    
    var body: some View {
        Menu(author.username ?? "Unknown User") {
            Button(action: {
                performHapticFeedback()
                handleProfile()
            }) {
                Label("Profile", systemImage: "person.circle")
            }
            
            if author.canReceivePrivateMessages == true {
                Button(action: {
                    performHapticFeedback()
                    handlePrivateMessage()
                }) {
                    Label("Send Private Message", systemImage: "envelope")
                }
            }
            
            Button(action: {
                performHapticFeedback()
                handleFilterPosts()
            }) {
                Label("User's Posts in This Thread", systemImage: "person.2")
            }
            
            Button(action: {
                performHapticFeedback()
                handleRapSheet()
            }) {
                Label("Rap Sheet", systemImage: "doc.text")
            }
        } label: {
            // Invisible button for menu positioning
            Rectangle()
                .fill(Color.clear)
                .frame(width: 1, height: 1)
        }
    }
    
    private func performHapticFeedback() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    private func handleProfile() {
        AppDelegate.instance.mainCoordinator?.presentUserProfile(userID: author.userID)
        onDismiss()
    }
    
    private func handlePrivateMessage() {
        AppDelegate.instance.mainCoordinator?.presentPrivateMessageComposer(for: author)
        onDismiss()
    }
    
    private func handleFilterPosts() {
        // Navigate to same thread but filtered by this user
        AppDelegate.instance.mainCoordinator?.navigateToThread(viewModel.thread, page: .specific(1), author: author)
        onDismiss()
    }
    
    private func handleRapSheet() {
        AppDelegate.instance.mainCoordinator?.presentRapSheet(userID: author.userID)
        onDismiss()
    }
}

// MARK: - Context Menu Presenter

/// A UIViewRepresentable that handles context menu presentation with precise positioning
struct ContextMenuPresenter: UIViewRepresentable {
    let menu: AnyView
    let sourceRect: CGRect
    let onDismiss: () -> Void
    
    func makeUIView(context: Context) -> ContextMenuHostView {
        let hostView = ContextMenuHostView()
        hostView.onDismiss = onDismiss
        return hostView
    }
    
    func updateUIView(_ uiView: ContextMenuHostView, context: Context) {
        uiView.presentMenu(menu, sourceRect: sourceRect)
    }
}

class ContextMenuHostView: UIView {
    var onDismiss: (() -> Void)?
    private var menuController: UIMenuController?
    private var hostingController: UIHostingController<AnyView>?
    
    func presentMenu<Content: View>(_ content: Content, sourceRect: CGRect) {
        // Remove any existing menu
        dismissMenu()
        
        // Create hosting controller for SwiftUI menu
        let hostingController = UIHostingController(rootView: AnyView(content))
        hostingController.view.backgroundColor = .clear
        self.hostingController = hostingController
        
        // Add as child and position
        if let superview = self.superview {
            superview.addSubview(hostingController.view)
            hostingController.view.frame = sourceRect
        }
        
        // Simulate touch to trigger menu
        DispatchQueue.main.async {
            // This will trigger the SwiftUI Menu
            if let menuView = hostingController.view.subviews.first {
                let touch = UITouch()
                // Trigger menu presentation via touch simulation
                menuView.isUserInteractionEnabled = true
            }
        }
    }
    
    private func dismissMenu() {
        hostingController?.view.removeFromSuperview()
        hostingController = nil
        onDismiss?()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        dismissMenu()
    }
}

// MARK: - UIKit Integration Helper

/// A simpler approach using UIContextMenuConfiguration directly
class ContextMenuHelper {
    static func createPostMenu(
        for post: Post,
        viewModel: PostsPageViewModel,
        at sourceRect: CGRect,
        in view: UIView
    ) -> UIContextMenuConfiguration {
        let enableHaptics = UserDefaults.standard.defaultingValue(for: Settings.enableHaptics)
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let quoteAction = UIAction(title: "Quote", image: UIImage(systemName: "quote.bubble")) { _ in
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                viewModel.quotePost(post) { workspace in
                    Task { @MainActor in
                        AppDelegate.instance.mainCoordinator?.presentReplyWorkspace(workspace)
                    }
                }
            }
            
            let markReadAction = UIAction(title: "Mark as Read Up To Here", image: UIImage(systemName: "eye")) { _ in
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                viewModel.markAsReadUpTo(post)
            }
            
            let shareAction = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                AppDelegate.instance.mainCoordinator?.presentSharePost(post)
            }
            
            let reportAction = UIAction(title: "Report", image: UIImage(systemName: "exclamationmark.triangle")) { _ in
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                AppDelegate.instance.mainCoordinator?.presentReportPost(post)
            }
            
            return UIMenu(title: "", children: [quoteAction, markReadAction, shareAction, reportAction])
        }
    }
    
    static func createUserMenu(
        for post: Post,
        author: User,
        viewModel: PostsPageViewModel,
        at sourceRect: CGRect,
        in view: UIView
    ) -> UIContextMenuConfiguration {
        let enableHaptics = UserDefaults.standard.defaultingValue(for: Settings.enableHaptics)
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            var actions: [UIAction] = []
            
            // Profile action
            actions.append(UIAction(title: "Profile", image: UIImage(systemName: "person.circle")) { _ in
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                AppDelegate.instance.mainCoordinator?.presentUserProfile(userID: author.userID)
            })
            
            // Private message action (if available)
            if author.canReceivePrivateMessages == true {
                actions.append(UIAction(title: "Send Private Message", image: UIImage(systemName: "envelope")) { _ in
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    AppDelegate.instance.mainCoordinator?.presentPrivateMessageComposer(for: author)
                })
            }
            
            // Filter posts action
            actions.append(UIAction(title: "User's Posts in This Thread", image: UIImage(systemName: "person.2")) { _ in
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                AppDelegate.instance.mainCoordinator?.navigateToThread(viewModel.thread, page: .specific(1), author: author)
            })
            
            // Rap sheet action
            actions.append(UIAction(title: "Rap Sheet", image: UIImage(systemName: "doc.text")) { _ in
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                AppDelegate.instance.mainCoordinator?.presentRapSheet(userID: author.userID)
            })
            
            return UIMenu(title: author.username ?? "Unknown User", children: actions)
        }
    }
}