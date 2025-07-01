import SwiftUI
import AwfulCore
import AwfulTheming
import AwfulSettings
import UIKit

/// SwiftUI replacement for the posts view toolbar
struct PostsToolbar: View {
    let thread: AwfulThread
    let author: User?
    let page: ThreadPage?
    let numberOfPages: Int
    let isLoadingViewVisible: Bool
    
    let onSettingsTapped: () -> Void
    let onBackTapped: () -> Void
    let onForwardTapped: () -> Void
    let onActionsTapped: () -> Void
    let onPageSelected: (ThreadPage) -> Void
    let onGoToLastPost: () -> Void
    
    @SwiftUI.Environment(\.theme) private var theme
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @State private var showingPagePicker = false
    
    private var currentPageNumber: Int {
        guard case .specific(let pageNumber) = page else {
            // This should not happen if the button is correctly disabled.
            return 1
        }
        return pageNumber
    }
    
    private var currentPageText: String {
        if case .specific(let pageNumber) = page, numberOfPages > 0 {
            return "\(pageNumber) / \(numberOfPages)"
        } else {
            return ""
        }
    }
    
    private var isBackEnabled: Bool {
        switch page {
        case .specific(let pageNumber)?:
            return pageNumber > 1
        case .last?, .nextUnread?, nil:
            return false
        }
    }
    
    private var isForwardEnabled: Bool {
        switch page {
        case .specific(let pageNumber)?:
            return pageNumber < numberOfPages
        case .last?, .nextUnread?, nil:
            return false
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Settings button
            Button(action: {
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                onSettingsTapped()
            }) {
                Image("page-settings")
                    .renderingMode(.template)
                    .foregroundColor(toolbarTextColor)
            }
            .accessibilityLabel("Settings")
            
            Spacer()
            
            // Navigation controls
            HStack(spacing: 12) {
                // Back button
                Button(action: {
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    onBackTapped()
                }) {
                    Image("arrowleft")
                        .renderingMode(.template)
                        .foregroundColor(isBackEnabled ? toolbarTextColor : disabledToolbarTextColor)
                }
                .disabled(!isBackEnabled)
                .accessibilityLabel("Previous page")
                
                // Current page picker
                Button(action: {
                    guard !currentPageText.isEmpty else { 
                        print("🔴 Page picker tapped but no page info available")
                        return 
                    }
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    print("🟢 Page picker tapped - Page: \(currentPageText)")
                    showingPagePicker = true
                }) {
                    Text(currentPageText.isEmpty ? "..." : currentPageText)
                        .font(.body.weight(.medium))
                        .foregroundColor(toolbarTextColor)
                        .frame(minWidth: 60) // Ensure consistent width
                }
                .disabled(currentPageText.isEmpty)
                .accessibilityLabel(currentPageAccessibilityLabel)
                .accessibilityHint("Opens page picker")
                .popover(isPresented: $showingPagePicker) {
                    if #available(iOS 16.4, *) {
                        PostsPagePicker(
                            thread: thread,
                            numberOfPages: numberOfPages,
                            currentPage: currentPageNumber,
                            onPageSelected: { selectedPage in
                                onPageSelected(selectedPage)
                                showingPagePicker = false
                            },
                            onGoToLastPost: {
                                onGoToLastPost()
                                showingPagePicker = false
                            }
                        )
                        .presentationCompactAdaptation(.popover)
                    } else {
                        PostsPagePicker(
                            thread: thread,
                            numberOfPages: numberOfPages,
                            currentPage: currentPageNumber,
                            onPageSelected: { selectedPage in
                                onPageSelected(selectedPage)
                                showingPagePicker = false
                            },
                            onGoToLastPost: {
                                onGoToLastPost()
                                showingPagePicker = false
                            }
                        )
                    }
                }
                
                // Forward button
                Button(action: {
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    onForwardTapped()
                }) {
                    Image("arrowright")
                        .renderingMode(.template)
                        .foregroundColor(isForwardEnabled ? toolbarTextColor : disabledToolbarTextColor)
                }
                .disabled(!isForwardEnabled)
                .accessibilityLabel("Next page")
            }
            
            Spacer()
            
            // Actions/hamburger menu
            Button(action: {
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                onActionsTapped()
            }) {
                Image("steamed-ham")
                    .renderingMode(.template)
                    .foregroundColor(toolbarTextColor)
            }
            .accessibilityLabel("Menu")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(toolbarBackgroundColor)
        .overlay(
            // Top border
            Rectangle()
                .fill(topBorderColor)
                .frame(height: 1.0 / UIScreen.main.scale)
                .frame(maxHeight: .infinity, alignment: .top)
        )
    }
    
    private var currentPageAccessibilityLabel: String {
        if case .specific(let pageNumber) = page, numberOfPages > 0 {
            return "Page \(pageNumber) of \(numberOfPages)"
        } else {
            return ""
        }
    }
    
    private var toolbarTextColor: Color {
        Color(theme[uicolor: "toolbarTextColor"] ?? UIColor.systemBlue)
    }
    
    private var disabledToolbarTextColor: Color {
        toolbarTextColor.opacity(0.5)
    }
    
    private var toolbarBackgroundColor: Color {
        Color(theme[uicolor: "toolbarBackgroundColor"] ?? UIColor.systemBackground)
    }
    
    private var topBorderColor: Color {
        Color(theme[uicolor: "bottomBarTopBorderColor"] ?? UIColor.separator)
    }
}

#Preview {
    let thread = AwfulThread()
    thread.title = "Sample Thread"
    
    return PostsToolbar(
        thread: thread,
        author: nil,
        page: .specific(5),
        numberOfPages: 10,
        isLoadingViewVisible: false,
        onSettingsTapped: {},
        onBackTapped: {},
        onForwardTapped: {},
        onActionsTapped: {},
        onPageSelected: { _ in },
        onGoToLastPost: {}
    )
    .environment(\.theme, Theme.defaultTheme())
} 
