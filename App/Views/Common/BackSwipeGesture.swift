//  BackSwipeGesture.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI

// MARK: - Standard Back Swipe Gesture

struct BackSwipeGesture: ViewModifier {
    let coordinator: (any MainCoordinator)?
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let edgeThreshold: CGFloat = 20  // Left edge detection
    private let completionThreshold: CGFloat = 100  // Distance to trigger back
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .offset(x: isDragging ? dragOffset * 0.3 : 0)
                .opacity(isDragging ? max(0.7, 1 - (dragOffset / 400)) : 1)
                .gesture(backSwipeGesture(geometry: geometry))
        }
    }
    
    private func backSwipeGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                let startX = value.startLocation.x
                let translation = value.translation
                
                // Only detect swipes starting from left edge
                guard startX < edgeThreshold else { return }
                
                // Only accept rightward swipes (positive translation.width)
                guard translation.width > 0 else { return }
                
                if !isDragging {
                    isDragging = true
                }
                
                dragOffset = max(0, min(translation.width, 200))
            }
            .onEnded { value in
                guard isDragging else { return }
                
                let shouldComplete = dragOffset > completionThreshold
                
                if shouldComplete {
                    // Trigger back navigation
                    if let mainCoordinator = coordinator as? MainCoordinatorImpl {
                        mainCoordinator.goBack()
                    }
                }
                
                withAnimation(.interactiveSpring()) {
                    isDragging = false
                    dragOffset = 0
                }
            }
    }
}

extension View {
    func backSwipeGesture(coordinator: (any MainCoordinator)?) -> some View {
        modifier(BackSwipeGesture(coordinator: coordinator))
    }
}