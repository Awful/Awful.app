//  NigglyPullToRefresh.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import SwiftUI

struct NigglyPullToRefresh: ViewModifier {
    let theme: Theme
    let onRefresh: () async -> Void
    
    @State private var isRefreshing = false
    @State private var pullOffset: CGFloat = 0
    @State private var pullProgress: CGFloat = 0
    
    private let triggerThreshold: CGFloat = 60
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Niggly animation at the top - only visible when pulling
                        if pullOffset > 0 {
                            SwiftUINigglyPullControl(
                                theme: theme,
                                pullProgress: pullProgress,
                                isVisible: true,
                                isRefreshing: isRefreshing,
                                onRefreshTriggered: {}
                            )
                            .opacity(min(1.0, pullOffset / 30))
                            .animation(.easeInOut(duration: 0.2), value: isRefreshing)
                            .animation(.easeInOut(duration: 0.2), value: pullProgress)
                            .padding(.top, 10)
                        }
                        
                        content
                            .id("content")
                    }
                    .background(
                        GeometryReader { contentGeometry in
                            Color.clear
                                .preference(
                                    key: NigglyScrollOffsetPreferenceKey.self,
                                    value: contentGeometry.frame(in: .named("scroll")).minY
                                )
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(NigglyScrollOffsetPreferenceKey.self) { offset in
                    handleScrollOffset(offset)
                }
                .refreshable {
                    await performRefresh()
                }
            }
        }
    }
    
    private func handleScrollOffset(_ offset: CGFloat) {
        guard !isRefreshing else { return }
        
        let newPullOffset = max(0, offset)
        
        if newPullOffset != pullOffset {
            pullOffset = newPullOffset
            pullProgress = min(1.0, pullOffset / triggerThreshold)
        }
    }
    
    private func performRefresh() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        
        await onRefresh()
        
        // Small delay to show completion
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        isRefreshing = false
        pullOffset = 0
        pullProgress = 0
    }
}

struct NigglyScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func nigglyPullToRefresh(theme: Theme, onRefresh: @escaping () async -> Void) -> some View {
        modifier(NigglyPullToRefresh(theme: theme, onRefresh: onRefresh))
    }
}

#Preview {
    let theme = Theme.defaultTheme()
    
    return VStack {
        Text("Pull down to see niggly!")
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
    .nigglyPullToRefresh(theme: theme) {
        // Simulate network request
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        print("Refresh completed!")
    }
}