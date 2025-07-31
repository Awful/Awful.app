//  ListInteractionModifiers.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import AwfulTheming

// MARK: - List Row Press Effect Modifier

struct ListRowPressEffect: ViewModifier {
    @State private var isPressed = false
    @SwiftUI.Environment(\.theme) private var theme
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .background(
                (theme[color: "listSeparatorColor"] ?? Color.gray)
                    .opacity(isPressed ? 0.2 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isPressed)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: .infinity,
                pressing: { pressing in
                    isPressed = pressing
                },
                perform: action
            )
    }
}

extension View {
    func listRowPressEffect(action: @escaping () -> Void) -> some View {
        modifier(ListRowPressEffect(action: action))
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    @SwiftUI.Environment(\.theme) private var theme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                (theme[color: "listSeparatorColor"] ?? Color.gray)
                    .opacity(configuration.isPressed ? 0.2 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .onChange(of: configuration.isPressed) { pressed in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressed
                }
            }
    }
}

// MARK: - Press State Manager for Performance

class PressStateManager: ObservableObject {
    private var pressedStates: [UUID: Bool] = [:]
    
    func setPressedState(for id: UUID, isPressed: Bool) {
        if isPressed {
            pressedStates[id] = true
        } else {
            pressedStates.removeValue(forKey: id)
        }
        objectWillChange.send()
    }
    
    func isPressed(_ id: UUID) -> Bool {
        pressedStates[id] ?? false
    }
    
    func clearAll() {
        pressedStates.removeAll()
        objectWillChange.send()
    }
}

// MARK: - Transaction-based Animation Control

extension View {
    func navigationTransition(animated: Bool) -> some View {
        if animated {
            return AnyView(self)
        } else {
            return AnyView(self.transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            })
        }
    }
}

// MARK: - Navigation Helper for Coordinator

extension View {
    func navigateAnimated<T: Hashable>(
        to destination: T, 
        path: Binding<NavigationPath>, 
        animated: Bool = true
    ) -> some View {
        self.onTapGesture {
            if animated {
                withAnimation(.easeInOut(duration: 0.3)) {
                    path.wrappedValue.append(destination)
                }
            } else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    path.wrappedValue.append(destination)
                }
            }
        }
    }
}