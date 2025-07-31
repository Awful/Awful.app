//  NavigationStateManager.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import SwiftUI
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "UnpopStateManager")

// MARK: - Unpop State Storage

class UnpopStateManager: ObservableObject {
    private var unpopStack: [(Any, Date)] = []
    private let maxUnpopDepth = 5
    private let unpopTTL: TimeInterval = 30
    
    @Published var canUnpop: Bool = false
    
    func storeForUnpop(_ element: Any) {
        logger.info("📦 Storing navigation element for unpop")
        unpopStack.append((element, Date()))
        cleanExpiredItems()
        
        if unpopStack.count > maxUnpopDepth {
            unpopStack.removeFirst()
        }
        
        updateCanUnpopState()
    }
    
    func unpopElement() -> Any? {
        guard let (element, _) = unpopStack.last else {
            logger.info("📦 No elements available for unpop")
            return nil
        }
        
        unpopStack.removeLast()
        updateCanUnpopState()
        logger.info("📦 Restored navigation element from unpop stack")
        return element
    }
    
    private func cleanExpiredItems() {
        let cutoffDate = Date().addingTimeInterval(-unpopTTL)
        let originalCount = self.unpopStack.count
        self.unpopStack.removeAll { $0.1 < cutoffDate }
        
        if self.unpopStack.count != originalCount {
            logger.info("📦 Cleaned \(originalCount - self.unpopStack.count) expired unpop items")
        }
    }
    
    private func updateCanUnpopState() {
        cleanExpiredItems()
        canUnpop = !unpopStack.isEmpty
    }
    
    func clearAll() {
        unpopStack.removeAll()
        updateCanUnpopState()
        logger.info("📦 Cleared all unpop states")
    }
}

// MARK: - Interactive Transition Manager

class InteractiveTransitionManager: ObservableObject {
    @Published var transitionProgress: CGFloat = 0
    @Published var isInteracting = false
    
    private let completionThreshold: CGFloat = 0.4
    private let velocityThreshold: CGFloat = 500
    
    func updateTransition(translation: CGSize, in geometry: GeometryProxy) {
        let progress = abs(translation.width) / geometry.size.width
        transitionProgress = min(1, max(0, progress))
        isInteracting = true
    }
    
    func finishTransition(translation: CGSize, velocity: CGSize, completion: @escaping (Bool) -> Void) {
        let shouldComplete = transitionProgress > completionThreshold || velocity.width > velocityThreshold
        
        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8)) {
            transitionProgress = shouldComplete ? 1 : 0
            isInteracting = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(shouldComplete)
        }
    }
    
    func resetTransition() {
        withAnimation(.easeInOut(duration: 0.3)) {
            transitionProgress = 0
            isInteracting = false
        }
    }
}

// MARK: - Unpop Gesture Modifier

struct UnpopGestureModifier: ViewModifier {
    @ObservedObject var stateManager: UnpopStateManager
    @ObservedObject var transitionManager: InteractiveTransitionManager
    @Binding var navigationPath: NavigationPath
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let edgeThreshold: CGFloat = 30
    private let completionThreshold: CGFloat = 80
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .offset(x: isDragging ? dragOffset * 0.5 : 0)
                .opacity(isDragging ? max(0.3, 1 - (dragOffset / 300)) : 1)
                .scaleEffect(isDragging ? max(0.95, 1 - (dragOffset / 1000)) : 1)
                .overlay(
                    unpopVisualIndicator(geometry: geometry),
                    alignment: .trailing
                )
                .gesture(unpopGesture(geometry: geometry))
        }
    }
    
    private func unpopGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard stateManager.canUnpop else { return }
                
                let startX = value.startLocation.x
                let screenWidth = geometry.size.width
                
                guard startX > screenWidth - edgeThreshold else { return }
                
                if !isDragging {
                    isDragging = true
                }
                
                dragOffset = max(0, min(value.translation.width, 200))
                transitionManager.updateTransition(translation: value.translation, in: geometry)
            }
            .onEnded { value in
                guard isDragging else { return }
                
                let shouldComplete = dragOffset > completionThreshold
                
                if shouldComplete, let element = stateManager.unpopElement() {
                    withAnimation(.interactiveSpring()) {
                        if let hashableElement = element as? any Hashable {
                            navigationPath.append(hashableElement)
                        }
                    }
                }
                
                transitionManager.finishTransition(
                    translation: value.translation,
                    velocity: value.velocity
                ) { completed in
                    // Transition completed
                }
                
                withAnimation(.interactiveSpring()) {
                    isDragging = false
                    dragOffset = 0
                }
            }
    }
    
    @ViewBuilder
    private func unpopVisualIndicator(geometry: GeometryProxy) -> some View {
        if isDragging && stateManager.canUnpop {
            HStack {
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundColor(.white)
                    .opacity(dragOffset / completionThreshold)
                    .scaleEffect(1 + (dragOffset / 200))
            }
            .padding(.trailing, 30)
        }
    }
}

// MARK: - Simplified View Modifier for Coordinator Integration

struct UnpopGestureViewModifier: ViewModifier {
    let coordinator: (any MainCoordinator)?
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let edgeThreshold: CGFloat = 30
    private let completionThreshold: CGFloat = 80
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .offset(x: isDragging ? -dragOffset * 0.3 : 0) // Negative offset for leftward drag
                .opacity(isDragging ? max(0.5, 1 - (dragOffset / 300)) : 1)
                .scaleEffect(isDragging ? max(0.97, 1 - (dragOffset / 1000)) : 1)
                .overlay(unpopVisualIndicator, alignment: .trailing)
                .gesture(unpopGesture(geometry: geometry))
        }
    }
    
    private func unpopGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard let mainCoordinator = coordinator as? MainCoordinatorImpl,
                      mainCoordinator.unpopStateManager.canUnpop else { 
                    print("🚫 Cannot unpop - no coordinator or no unpop state available")
                    return 
                }
                
                let startX = value.startLocation.x
                let screenWidth = geometry.size.width
                let translation = value.translation
                
                print("📱 Gesture: startX=\(startX), screenWidth=\(screenWidth), translation=\(translation)")
                
                guard startX > screenWidth - edgeThreshold else { 
                    print("🚫 Gesture not from right edge: \(startX) vs \(screenWidth - edgeThreshold)")
                    return 
                }
                
                // Only accept leftward swipes (negative translation.x) from right edge
                guard translation.width < 0 else {
                    print("🚫 Not a leftward swipe: \(translation.width)")
                    return
                }
                
                if !isDragging {
                    isDragging = true
                    print("✅ Started unpop gesture from right edge")
                }
                
                // Convert negative translation to positive offset
                let positiveOffset = abs(translation.width)
                dragOffset = max(0, min(positiveOffset, 200))
                print("📏 dragOffset updated to: \(dragOffset)")
            }
            .onEnded { value in
                guard isDragging else { return }
                
                let shouldComplete = dragOffset > completionThreshold  
                print("🎯 Unpop gesture ended - shouldComplete: \(shouldComplete), dragOffset: \(dragOffset), threshold: \(completionThreshold)")
                
                if shouldComplete, let mainCoordinator = coordinator as? MainCoordinatorImpl {
                    let success = mainCoordinator.unpopView()
                    print("📱 Unpop result: \(success)")
                }
                
                withAnimation(.interactiveSpring()) {
                    isDragging = false
                    dragOffset = 0
                }
            }
    }
    
    @ViewBuilder
    private var unpopVisualIndicator: some View {
        if isDragging {
            HStack {
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundColor(.white)
                    .opacity(dragOffset / completionThreshold)
                    .scaleEffect(1 + (dragOffset / 200))
            }
            .padding(.trailing, 30)
        }
    }
}

extension View {
    func unpopGesture(
        stateManager: UnpopStateManager,
        transitionManager: InteractiveTransitionManager,
        navigationPath: Binding<NavigationPath>
    ) -> some View {
        modifier(UnpopGestureModifier(
            stateManager: stateManager,
            transitionManager: transitionManager,
            navigationPath: navigationPath
        ))
    }
}