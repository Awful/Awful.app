//  NavigationStackExample.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI

/// Example of how to use the unpop functionality with SwiftUI NavigationStack
/// This demonstrates the correct way to integrate the unpop feature into your navigation
struct NavigationStackWithUnpopExample: View {
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                Text("Root View")
                NavigationLink("Go to Forums", value: "forums")
                NavigationLink("Go to Messages", value: "messages")
            }
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "forums":
                    ForumsView(navigationPath: $navigationPath)
                case "messages":
                    MessagesView(navigationPath: $navigationPath)
                default:
                    Text("Unknown destination")
                }
            }
        }
        // Add the unpop functionality here
        .unpopEnabled(navigationPath: $navigationPath)
    }
}

private struct ForumsView: View {
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        VStack {
            Text("Forums View")
            NavigationLink("Go to Thread", value: "thread")
        }
        .navigationDestination(for: String.self) { destination in
            ThreadView(navigationPath: $navigationPath)
        }
    }
}

private struct MessagesView: View {
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        Text("Messages View")
    }
}

private struct ThreadView: View {
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        Text("Thread View")
    }
}

#Preview {
    NavigationStackWithUnpopExample()
} 