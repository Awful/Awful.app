//  FrogPullToRefresh.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import SwiftUI

struct FrogPullToRefresh: ViewModifier {
    let theme: Theme
    let onRefresh: () async -> Void
    
    @State private var refreshState: FrogRefreshAnimation.RefreshState = .ready
    @State private var isRefreshing = false
    @State private var pullOffset: CGFloat = 0
    @FoilDefaultStorage(Settings.frogAndGhostEnabled) private var frogAndGhostEnabled
    
    private let triggerThreshold: CGFloat = 60
    
    func body(content: Content) -> some View {
        if frogAndGhostEnabled {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Frog animation at the top
                            if refreshState != .disabled {
                                FrogRefreshAnimation(theme: theme, refreshState: $refreshState)
                                    .frame(width: 60, height: 60)
                                    .opacity(pullOffset > 0 ? min(1.0, pullOffset / 30) : 0)
                                    .animation(.easeInOut(duration: 0.2), value: refreshState)
                                    .padding(.top, 10)
                            }
                            
                            content
                        }
                        .background(
                            GeometryReader { contentGeometry in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: contentGeometry.frame(in: .named("scroll")).minY
                                    )
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        handleScrollOffset(offset)
                    }
                    .refreshable {
                        await performRefresh()
                    }
                }
            }
        } else {
            content
                .refreshable {
                    await performRefresh()
                }
        }
    }
    
    private func handleScrollOffset(_ offset: CGFloat) {
        guard !isRefreshing else { return }
        
        let newPullOffset = max(0, offset)
        
        if newPullOffset != pullOffset {
            pullOffset = newPullOffset
            
            if pullOffset > triggerThreshold {
                if refreshState != .triggered {
                    refreshState = .triggered
                }
            } else if pullOffset > 10 {
                let fraction = min(1.0, pullOffset / triggerThreshold)
                refreshState = .pulling(fraction: fraction)
            } else {
                refreshState = .ready
            }
        }
    }
    
    private func performRefresh() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        refreshState = .refreshing
        
        await onRefresh()
        
        // Small delay to show completion
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        isRefreshing = false
        refreshState = .ready
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func frogPullToRefresh(theme: Theme, onRefresh: @escaping () async -> Void) -> some View {
        modifier(FrogPullToRefresh(theme: theme, onRefresh: onRefresh))
    }
}

#Preview {
    let theme = Theme.defaultTheme()
    
    return VStack {
        Text("Pull down to see the frog!")
            .padding()
        
        LazyVStack {
            ForEach(0..<50, id: \.self) { index in
                Text("Item \(index)")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
            }
        }
    }
    .frogPullToRefresh(theme: theme) {
        // Simulate network request
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        print("Refresh completed!")
    }
}