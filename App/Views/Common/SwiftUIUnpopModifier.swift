//  SwiftUIUnpopModifier.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import UIKit

/// A SwiftUI view modifier that provides the unpop functionality for NavigationStack
/// This allows users to swipe from the right edge to restore previously visited views
struct UnpopViewModifier: ViewModifier {
    @Binding var navigationPath: NavigationPath
    @State private var unpopStack: [AnyHashable] = []
    @State private var unpopHandler: SwiftUIUnpopHandler?
    @State private var previousPath: NavigationPath = NavigationPath()
    @State private var navigationHistory: [AnyHashable] = []
    
    func body(content: Content) -> some View {
        content
            .background(
                UnpopGestureView(
                    navigationPath: $navigationPath,
                    unpopStack: $unpopStack,
                    unpopHandler: $unpopHandler
                )
            )
            .onChange(of: navigationPath) { newPath in
                handleNavigationChange(oldPath: previousPath, newPath: newPath)
                previousPath = newPath
            }
    }
    
    private func handleNavigationChange(oldPath: NavigationPath, newPath: NavigationPath) {
        let oldCount = oldPath.count
        let newCount = newPath.count
        
        // If we popped a view (newPath is shorter), save the last item to unpop stack
        if newCount < oldCount && unpopHandler?.isUnpopping != true {
            let itemsPopped = oldCount - newCount
            // Move the last `itemsPopped` items from history to unpop stack
            let itemsToMove = Array(navigationHistory.suffix(itemsPopped))
            unpopStack.append(contentsOf: itemsToMove)
            // Remove those items from history
            navigationHistory.removeLast(min(itemsPopped, navigationHistory.count))
            
            print("🔄 Detected navigation pop, \(itemsPopped) item(s) moved to unpop stack. Unpop stack now has \(unpopStack.count) items")
        }
        
        // If we pushed a new view that's not from unpop, clear the unpop stack and update history
        if newCount > oldCount && unpopHandler?.isUnpopping != true {
            unpopStack.removeAll()
            // We can't directly access NavigationPath items, so we'll rely on coordinator tracking
            print("🔄 Detected new navigation push, unpop stack cleared")
        }
    }
}

/// UIViewRepresentable that handles the gesture recognition for unpop
private struct UnpopGestureView: UIViewRepresentable {
    @Binding var navigationPath: NavigationPath
    @Binding var unpopStack: [AnyHashable]
    @Binding var unpopHandler: SwiftUIUnpopHandler?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let handler = SwiftUIUnpopHandler(
            navigationPath: $navigationPath,
            unpopStack: $unpopStack
        )
        unpopHandler = handler
        view.addGestureRecognizer(handler.panRecognizer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update bindings if needed
        unpopHandler?.updateBindings(
            navigationPath: $navigationPath,
            unpopStack: $unpopStack
        )
    }
}

/// Handler for the unpop gesture in SwiftUI
private class SwiftUIUnpopHandler: NSObject {
    private var navigationPathBinding: Binding<NavigationPath>
    private var unpopStackBinding: Binding<[AnyHashable]>
    private var gestureStartPointX: CGFloat = 0
    private(set) var isUnpopping = false
    
    lazy var panRecognizer: UIScreenEdgePanGestureRecognizer = {
        let pan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.edges = .right
        pan.delegate = self
        return pan
    }()
    
    init(navigationPath: Binding<NavigationPath>, unpopStack: Binding<[AnyHashable]>) {
        self.navigationPathBinding = navigationPath
        self.unpopStackBinding = unpopStack
        super.init()
    }
    
    func updateBindings(navigationPath: Binding<NavigationPath>, unpopStack: Binding<[AnyHashable]>) {
        self.navigationPathBinding = navigationPath
        self.unpopStackBinding = unpopStack
    }
    
    @objc private func handlePan(_ sender: UIScreenEdgePanGestureRecognizer) {
        let location = sender.location(in: sender.view)
        
        switch sender.state {
        case .began:
            guard !unpopStackBinding.wrappedValue.isEmpty else { break }
            isUnpopping = true
            gestureStartPointX = location.x
            
        case .changed:
            guard isUnpopping else { break }
            // Visual feedback could be implemented here
            
        case .cancelled, .ended:
            guard isUnpopping else { break }
            let percent = (gestureStartPointX - location.x) / gestureStartPointX
            
            if percent > 0.3 && !unpopStackBinding.wrappedValue.isEmpty {
                // Perform unpop
                if let lastItem = unpopStackBinding.wrappedValue.last {
                    unpopStackBinding.wrappedValue.removeLast()
                    navigationPathBinding.wrappedValue.append(lastItem)
                }
            }
            
            gestureStartPointX = 0
            isUnpopping = false
            
        case .failed, .possible:
            break
            
        @unknown default:
            break
        }
    }
}

extension SwiftUIUnpopHandler: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !unpopStackBinding.wrappedValue.isEmpty else { return false }
        
        // Only begin if it's a horizontal gesture from the right edge
        if let panGesture = gestureRecognizer as? UIScreenEdgePanGestureRecognizer {
            let velocity = panGesture.velocity(in: panGesture.view)
            let location = panGesture.location(in: panGesture.view)
            
            // Check if we're truly at the right edge (within 20 points)
            guard let view = panGesture.view, 
                  location.x >= view.bounds.width - 20 else { return false }
            
            // Only begin if horizontal velocity is much greater than vertical
            return abs(velocity.x) > abs(velocity.y) * 2
        }
        
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        // Don't allow simultaneous recognition with scroll views to avoid conflicts
        if other.view is UIScrollView || other.view?.superview is UIScrollView {
            return false
        }
        
        return other is UIScreenEdgePanGestureRecognizer
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf other: UIGestureRecognizer) -> Bool {
        // Let scroll views take precedence for vertical gestures
        if other.view is UIScrollView || other.view?.superview is UIScrollView {
            return false
        }
        return false
    }
}

// MARK: - Coordinator-based Unpop Modifier

/// A SwiftUI view modifier that provides unpop functionality using MainCoordinatorImpl
/// This integrates directly with the coordinator's navigation tracking
struct CoordinatorUnpopViewModifier: ViewModifier {
    @ObservedObject var coordinator: MainCoordinatorImpl
    @State private var unpopHandler: CoordinatorUnpopHandler?
    @State private var previousPathCount: Int = 0
    
    func body(content: Content) -> some View {
        content
            .background(
                CoordinatorUnpopGestureView(
                    coordinator: coordinator,
                    unpopHandler: $unpopHandler
                )
            )
            .onChange(of: coordinator.path.count) { newCount in
                handlePathCountChange(oldCount: previousPathCount, newCount: newCount)
                previousPathCount = newCount
            }
    }
    
    private func handlePathCountChange(oldCount: Int, newCount: Int) {
        // If we popped a view (newCount is smaller), the coordinator should handle it
        // Only handle if the difference is meaningful (at least 1) and we're not in the middle of an unpop
        if newCount < oldCount && unpopHandler?.isUnpopping != true {
            let itemsPopped = oldCount - newCount
            if itemsPopped > 0 {
                coordinator.handleNavigationPop()
            }
        }
    }
}

/// UIViewRepresentable for coordinator-based unpop gestures
private struct CoordinatorUnpopGestureView: UIViewRepresentable {
    @ObservedObject var coordinator: MainCoordinatorImpl
    @Binding var unpopHandler: CoordinatorUnpopHandler?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let handler = CoordinatorUnpopHandler(coordinator: coordinator)
        unpopHandler = handler
        view.addGestureRecognizer(handler.panRecognizer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update coordinator reference if needed
        unpopHandler?.coordinator = coordinator
    }
}

/// Handler for coordinator-based unpop gestures
private class CoordinatorUnpopHandler: NSObject {
    var coordinator: MainCoordinatorImpl
    private var gestureStartPointX: CGFloat = 0
    private(set) var isUnpopping = false
    
    lazy var panRecognizer: UIScreenEdgePanGestureRecognizer = {
        let pan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.edges = .right
        pan.delegate = self
        return pan
    }()
    
    init(coordinator: MainCoordinatorImpl) {
        self.coordinator = coordinator
        super.init()
    }
    
    @objc private func handlePan(_ sender: UIScreenEdgePanGestureRecognizer) {
        let location = sender.location(in: sender.view)
        
        switch sender.state {
        case .began:
            guard !coordinator.unpopStack.isEmpty else { break }
            isUnpopping = true
            gestureStartPointX = location.x
            print("🔄 Unpop gesture began")
            
        case .changed:
            guard isUnpopping else { break }
            // Visual feedback could be implemented here
            
        case .cancelled, .ended:
            guard isUnpopping else { break }
            let percent = (gestureStartPointX - location.x) / gestureStartPointX
            
            if percent > 0.3 && !coordinator.unpopStack.isEmpty {
                // Perform unpop through coordinator
                coordinator.performUnpop()
                print("🔄 Unpop gesture completed")
            } else {
                print("🔄 Unpop gesture cancelled")
            }
            
            gestureStartPointX = 0
            isUnpopping = false
            
        case .failed, .possible:
            break
            
        @unknown default:
            break
        }
    }
}

extension CoordinatorUnpopHandler: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !coordinator.unpopStack.isEmpty else { return false }
        
        // Only begin if it's a horizontal gesture from the right edge
        if let panGesture = gestureRecognizer as? UIScreenEdgePanGestureRecognizer {
            let velocity = panGesture.velocity(in: panGesture.view)
            let location = panGesture.location(in: panGesture.view)
            
            // Check if we're truly at the right edge (within 20 points)
            guard let view = panGesture.view, 
                  location.x >= view.bounds.width - 20 else { return false }
            
            // Only begin if horizontal velocity is much greater than vertical
            return abs(velocity.x) > abs(velocity.y) * 2
        }
        
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        // Don't allow simultaneous recognition with scroll views to avoid conflicts
        if other.view is UIScrollView || other.view?.superview is UIScrollView {
            return false
        }
        
        return other is UIScreenEdgePanGestureRecognizer
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf other: UIGestureRecognizer) -> Bool {
        // Let scroll views take precedence for vertical gestures
        if other.view is UIScrollView || other.view?.superview is UIScrollView {
            return false
        }
        return false
    }
}

/// Extension to make the unpop modifier easy to use
extension View {
    /// Adds unpop functionality to a NavigationStack
    /// - Parameter navigationPath: The navigation path binding from your NavigationStack
    func unpopEnabled(navigationPath: Binding<NavigationPath>) -> some View {
        modifier(UnpopViewModifier(navigationPath: navigationPath))
    }
    
    /// Adds unpop functionality to a NavigationStack with coordinator support
    /// - Parameter coordinator: The MainCoordinatorImpl that manages navigation
    func unpopEnabled(coordinator: MainCoordinatorImpl) -> some View {
        modifier(CoordinatorUnpopViewModifier(coordinator: coordinator))
    }
} 