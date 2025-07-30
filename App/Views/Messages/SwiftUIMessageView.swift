//  SwiftUIMessageView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import Combine
import CoreData
import HTMLReader
import SwiftUI
import UIKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SwiftUIMessageView")

struct SwiftUIMessageView: View {
    let message: PrivateMessage
    var coordinator: (any MainCoordinator)?
    
    @SwiftUI.Environment(\.theme) private var theme
    // Removed AwfulNavigationController - using coordinator only
    
    @StateObject private var viewModel: MessageViewModel
    @State private var showingReplyActions = false
    @State private var composeViewController: MessageComposeViewController?
    @State private var error: Error?
    @State private var showingError = false
    
    private let managedObjectContext: NSManagedObjectContext
    
    init(message: PrivateMessage, managedObjectContext: NSManagedObjectContext, coordinator: (any MainCoordinator)? = nil) {
        self.message = message
        self.managedObjectContext = managedObjectContext
        self.coordinator = coordinator
        self._viewModel = StateObject(wrappedValue: MessageViewModel(message: message))
    }
    
    var body: some View {
        messageContent
            .navigationTitle(message.subject ?? LocalizedString("private-message.title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Use coordinator for navigation
                        if let coordinator = coordinator, !coordinator.path.isEmpty {
                            coordinator.path.removeLast()
                        }
                    }) {
                        Image("back")
                            .renderingMode(.template)
                    }
                    .foregroundColor(theme[color: "navigationBarTextColor"] ?? .primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showReplyActions()
                    } label: {
                        Image("reply")
                            .renderingMode(.template)
                    }
                    .foregroundColor(theme[color: "navigationBarTextColor"] ?? .primary)
                }
            }
        .onAppear {
            handleViewAppear()
        }
        .onDisappear {
            handleViewDisappear()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            if let error = error {
                Text(error.localizedDescription)
            }
        }
        .actionSheet(isPresented: $showingReplyActions) {
            ActionSheet(
                title: Text("Message Actions"),
                buttons: [
                    .default(Text(LocalizedString("private-message.action-reply"))) {
                        replyToMessage()
                    },
                    .default(Text(LocalizedString("private-message.action-forward"))) {
                        forwardMessage()
                    },
                    .cancel()
                ]
            )
        }
        .themed()
    }
    
    private var messageContent: some View {
        ZStack {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(theme[uicolor: "listBackgroundColor"] ?? UIColor.systemBackground))
            } else {
                VStack {
                    if message.innerHTML?.isEmpty != false {
                        Text("Message content is empty or not loaded")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        MessageWebView(
                            message: message,
                            theme: theme,
                            onUserAction: { user, rect in
                                showUserActions(user: user, from: rect)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func showReplyActions() {
        if viewModel.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        showingReplyActions = true
    }
    
    private func replyToMessage() {
        Task {
            do {
                let bbcode = try await ForumsClient.shared.quoteBBcodeContents(of: message)
                let composeVC = MessageComposeViewController(regardingMessage: message, initialContents: bbcode)
                composeVC.restorationIdentifier = "Reply to private message"
                self.composeViewController = composeVC
                presentCompose(composeVC)
            } catch {
                self.error = error
                self.showingError = true
            }
        }
    }
    
    private func forwardMessage() {
        Task {
            do {
                let bbcode = try await ForumsClient.shared.quoteBBcodeContents(of: message)
                let composeVC = MessageComposeViewController(forwardingMessage: message, initialContents: bbcode)
                composeVC.restorationIdentifier = "Forward private message"
                self.composeViewController = composeVC
                presentCompose(composeVC)
            } catch {
                self.error = error
                self.showingError = true
            }
        }
    }
    
    private func presentCompose(_ composeVC: MessageComposeViewController) {
        // Find the current hosting controller that's presenting this SwiftUI view
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            // Find the topmost presented view controller
            var topController = window.rootViewController
            while let presentedController = topController?.presentedViewController {
                topController = presentedController
            }
            
            topController?.present(composeVC.enclosingNavigationController, animated: true)
        }
    }
    
    private func showUserActions(user: User, from rect: CGRect) {
        guard let coordinator = coordinator else { return }
        // Use coordinator to show user profile or other actions
        coordinator.presentUserProfile(userID: user.userID)
    }
    
    // MARK: - View Lifecycle
    
    private func handleViewAppear() {
        Task {
            await viewModel.loadMessageIfNeeded()
        }
        
        // Configure user activity for handoff
        if viewModel.handoffEnabled {
            configureUserActivity()
        }
    }
    
    private func handleViewDisappear() {
        // Clear user activity
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.userActivity = nil
        }
    }
    
    private func configureUserActivity() {
        guard viewModel.handoffEnabled else { return }
        
        let userActivity = NSUserActivity(activityType: Handoff.ActivityType.readingMessage)
        userActivity.route = .message(id: message.messageID)
        userActivity.title = message.subject?.isEmpty == false ? message.subject : LocalizedString("handoff.message-title")
        userActivity.needsSave = true
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.userActivity = userActivity
        }
    }
}

// MARK: - Message WebView

struct MessageWebView: UIViewRepresentable {
    let message: PrivateMessage
    let theme: Theme
    let onUserAction: (User, CGRect) -> Void
    
    func makeUIView(context: Context) -> RenderView {
        let renderView = RenderView()
        renderView.delegate = context.coordinator
        
        // Configure render view
        if let css = theme[string: "postsViewCSS"] {
            renderView.setThemeStylesheet(css)
        }
        
        return renderView
    }
    
    func updateUIView(_ uiView: RenderView, context: Context) {
        // Update theme if needed
        if let css = theme[string: "postsViewCSS"] {
            uiView.setThemeStylesheet(css)
        }
        
        // Render message content
        renderMessage(in: uiView)
    }
    
    private func renderMessage(in renderView: RenderView) {
        do {
            let model = RenderModel(message: message, stylesheet: theme[string: "postsViewCSS"])
            let rendering = try StencilEnvironment.shared.renderTemplate(.privateMessage, context: model)
            renderView.render(html: rendering, baseURL: ForumsClient.shared.baseURL)
        } catch {
            logger.error("failed to render private message: \(error)")
            renderView.render(html: "<h1>Rendering Error</h1><pre>\(error)</pre>", baseURL: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onUserAction: onUserAction)
    }
    
    class Coordinator: NSObject, RenderViewDelegate {
        let onUserAction: (User, CGRect) -> Void
        
        init(onUserAction: @escaping (User, CGRect) -> Void) {
            self.onUserAction = onUserAction
        }
        
        func didFinishRenderingHTML(in view: RenderView) {
            // HTML rendering completed
        }
        
        func didReceive(message: RenderViewMessage, in view: RenderView) {
            switch message {
            case _ as RenderView.BuiltInMessage.DidTapAuthorHeader:
                // Handle user tap - this would need the actual user object
                // For now, we'll handle this through other means
                break
            default:
                break
            }
        }
        
        func didTapLink(to url: URL, in view: RenderView) {
            if let route = try? AwfulRoute(url) {
                AppDelegate.instance.open(route: route)
            } else if url.opensInBrowser {
                // Use system default since we don't have a hosting view controller in this context
                UIApplication.shared.open(url)
            } else {
                UIApplication.shared.open(url)
            }
        }
        
        func renderProcessDidTerminate(in view: RenderView) {
            // Re-render if needed
        }
    }
}

// MARK: - Render Model

private struct RenderModel: StencilContextConvertible {
    let context: [String: Any]
    
    init(message: PrivateMessage, stylesheet: String?) {
        let showAvatars = FoilDefaultStorage(Settings.showAvatars).wrappedValue
        let hiddenAvataruRL = showAvatars ? nil : message.from?.avatarURL
        
        var htmlContents: String? {
            guard let originalHTML = message.innerHTML else { return nil }
            let document = HTMLDocument(string: originalHTML)
            document.addAttributeToBlueskyLinks()
            document.addAttributeToTweetLinks()
            if let username = FoilDefaultStorageOptional(Settings.username).wrappedValue {
                document.identifyQuotesCitingUser(named: username, shouldHighlight: true)
                document.identifyMentionsOfUser(named: username, shouldHighlight: true)
            }
            document.removeSpoilerStylingAndEvents()
            document.useHTML5VimeoPlayer()
            document.processImgTags(shouldLinkifyNonSmilies: !FoilDefaultStorage(Settings.loadImages).wrappedValue)
            if !FoilDefaultStorage(Settings.autoplayGIFs).wrappedValue {
                document.stopGIFAutoplay()
            }
            document.embedVideos()
            return document.bodyElement?.innerHTML
        }
        
        let visibleAvatarURL = showAvatars ? message.from?.avatarURL : nil
        
        context = [
            "fromUsername": message.fromUsername ?? "",
            "hiddenAvataruRL": hiddenAvataruRL as Any,
            "htmlContents": htmlContents as Any,
            "messageID": message.messageID,
            "regdate": message.from?.regdate as Any,
            "regdateRaw": message.from?.regdateRaw as Any,
            "seen": message.seen,
            "sentDate": message.sentDate as Any,
            "sentDateRaw": message.sentDateRaw as Any,
            "showAvatars": showAvatars,
            "stylesheet": stylesheet as Any,
            "visibleAvatarURL": visibleAvatarURL as Any
        ]
    }
}

struct SwiftUIMessageView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let context = CoreData.NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            let message = PrivateMessage(context: context)
            let _ = {
                message.messageID = "test"
                message.subject = "Test Message"
                message.rawFromUsername = "TestUser"
            }()
            
            SwiftUIMessageView(message: message, managedObjectContext: context)
                .themed()
        }
    }
}