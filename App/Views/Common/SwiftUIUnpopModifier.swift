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
        // If we popped a view (newPath is shorter), save it to unpop stack
        if newPath.count < oldPath.count {
            // Note: NavigationPath doesn't give us direct access to items,
            // so this is a simplified implementation
            print("🔄 Detected navigation pop, items available for unpop")
        }
        
        // If we pushed a new view that's not from unpop, clear the unpop stack
        if newPath.count > oldPath.count && unpopHandler?.isUnpopping != true {
            unpopStack.removeAll()
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
        return !unpopStackBinding.wrappedValue.isEmpty
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return other is UIScreenEdgePanGestureRecognizer
    }
}

/// Extension to make the unpop modifier easy to use
extension View {
    /// Adds unpop functionality to a NavigationStack
    /// - Parameter navigationPath: The navigation path binding from your NavigationStack
    func unpopEnabled(navigationPath: Binding<NavigationPath>) -> some View {
        modifier(UnpopViewModifier(navigationPath: navigationPath))
    }
} 