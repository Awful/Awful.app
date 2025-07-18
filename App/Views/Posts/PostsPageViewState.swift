//  PostsPageViewState.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import SwiftUI
import Foundation

/// Centralized state management for SwiftUIPostsPageView
/// Consolidates multiple @State variables into a single ObservableObject
@MainActor
public class PostsPageViewState: ObservableObject {
    
    // MARK: - Loading State
    @Published public var isLoadingSpinnerVisible: Bool = false
    
    // MARK: - Pull Gesture State
    @Published public var arrowPullProgress: CGFloat = 0.0
    @Published public var wasArrowTriggered: Bool = false
    @Published public var nigglyPullProgress: CGFloat = 0.0
    @Published public var wasNigglyTriggered: Bool = false
    @Published public var isNigglyRefreshing: Bool = false
    @Published var frogRefreshState: FrogRefreshAnimation.RefreshState = .ready
    @Published public var wasFrogTriggered: Bool = false
    @Published public var isFrogRefreshing: Bool = false
    
    // MARK: - Presentation State
    @Published public var showingSettings = false
    @Published public var showingPagePicker = false
    @Published var messageViewController: MessageComposeViewController?
    @Published public var replyWorkspace: IdentifiableReplyWorkspace?
    @Published public var presentedImageURL: URL?
    @Published public var showingImageViewer = false
    
    // MARK: - Scroll State
    @Published public var currentScrollFraction: CGFloat = 0.0
    @Published public var pendingScrollFraction: CGFloat?
    @Published public var pendingJumpToPostID: String?
    @Published public var specificPageToLoad: ThreadPage?
    
    // MARK: - Reset Methods
    public func resetPullStates() {
        arrowPullProgress = 0.0
        wasArrowTriggered = false
        nigglyPullProgress = 0.0
        wasNigglyTriggered = false
        isNigglyRefreshing = false
        frogRefreshState = .ready
        wasFrogTriggered = false
        isFrogRefreshing = false
    }
    
    public func resetPresentationStates() {
        showingSettings = false
        showingPagePicker = false
        messageViewController = nil
        replyWorkspace = nil
        presentedImageURL = nil
        showingImageViewer = false
    }
    
    public func resetScrollStates() {
        currentScrollFraction = 0.0
        pendingScrollFraction = nil
        pendingJumpToPostID = nil
        specificPageToLoad = nil
    }
    
    public func resetAll() {
        resetPullStates()
        resetPresentationStates()
        resetScrollStates()
        isLoadingSpinnerVisible = false
    }
}

/// Identifiable wrapper for ReplyWorkspace to work with SwiftUI sheets
public struct IdentifiableReplyWorkspace: Identifiable {
    public let id = UUID()
    let workspace: ReplyWorkspace
    
    init(workspace: ReplyWorkspace) {
        self.workspace = workspace
    }
}