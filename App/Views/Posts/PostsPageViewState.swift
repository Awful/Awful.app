//  PostsPageViewState.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import SwiftUI
import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PostsPageViewState")

/// Centralized state management for SwiftUIPostsPageView
/// Consolidates multiple @State variables into a single ObservableObject
@MainActor
public class PostsPageViewState: ObservableObject {
    
    // MARK: - Loading State
    @Published public var isLoadingSpinnerVisible: Bool = false
    
    // MARK: - Advanced Refresh Control State Machine
    public enum RefreshControlState: CustomStringConvertible {
        case idle
        case pulling(fraction: CGFloat)
        case triggered
        case refreshing
        case completing
        case cooldown(remainingTime: TimeInterval)
        
        public var description: String {
            switch self {
            case .idle:
                return "idle"
            case .pulling(let fraction):
                return "pulling(\(String(format: "%.2f", fraction)))"
            case .triggered:
                return "triggered"
            case .refreshing:
                return "refreshing"
            case .completing:
                return "completing"
            case .cooldown(let remainingTime):
                return "cooldown(\(String(format: "%.1f", remainingTime))s)"
            }
        }
    }
    
    @Published public var nigglyRefreshState: RefreshControlState = .idle
    @Published public var arrowRefreshState: RefreshControlState = .idle
    @Published var frogRefreshState: FrogRefreshAnimation.RefreshState = .ready
    
    // Legacy properties for backwards compatibility
    @Published public var arrowPullProgress: CGFloat = 0.0
    @Published public var wasArrowTriggered: Bool = false
    @Published public var nigglyPullProgress: CGFloat = 0.0
    @Published public var wasNigglyTriggered: Bool = false
    @Published public var isNigglyRefreshing: Bool = false
    @Published public var wasFrogTriggered: Bool = false
    @Published public var isFrogRefreshing: Bool = false
    
    // MARK: - Presentation State
    @Published public var showingSettings = false
    @Published public var showingPagePicker = false
    @Published var messageViewController: MessageComposeViewController?
    @Published public var replyWorkspace: IdentifiableReplyWorkspace?
    @Published public var presentedImageURL: URL?
    @Published public var showingImageViewer = false
    @Published public var showingVoteSheet = false
    @Published public var alertTitle: String?
    @Published public var alertMessage: String?
    
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
        showingVoteSheet = false
        alertTitle = nil
        alertMessage = nil
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
    
    // MARK: - Advanced Refresh Control State Management
    public func updateNigglyRefreshState(_ newState: RefreshControlState) {
        logger.debug("🔄 Niggly refresh state: \(self.nigglyRefreshState) → \(newState)")
        nigglyRefreshState = newState
        
        // Update legacy properties for compatibility
        switch newState {
        case .idle:
            nigglyPullProgress = 0.0
            wasNigglyTriggered = false
            isNigglyRefreshing = false
        case .pulling(let fraction):
            nigglyPullProgress = fraction
            wasNigglyTriggered = false
            isNigglyRefreshing = false
        case .triggered:
            wasNigglyTriggered = true
            isNigglyRefreshing = false
        case .refreshing:
            isNigglyRefreshing = true
        case .completing:
            isNigglyRefreshing = true
        case .cooldown(_):
            nigglyPullProgress = 0.0
            wasNigglyTriggered = false
            isNigglyRefreshing = false
        }
    }
    
    public func updateArrowRefreshState(_ newState: RefreshControlState) {
        logger.debug("🏹 Arrow refresh state: \(self.arrowRefreshState) → \(newState)")
        arrowRefreshState = newState
        
        // Update legacy properties for compatibility
        switch newState {
        case .idle:
            arrowPullProgress = 0.0
            wasArrowTriggered = false
        case .pulling(let fraction):
            arrowPullProgress = fraction
            wasArrowTriggered = false
        case .triggered:
            wasArrowTriggered = true
        case .refreshing, .completing, .cooldown(_):
            arrowPullProgress = 0.0
            wasArrowTriggered = false
        }
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