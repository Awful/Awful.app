//  ReplyWorkspaceView.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import SwiftUI
import UIKit

struct ReplyWorkspaceView: UIViewControllerRepresentable {
    let workspace: ReplyWorkspace
    let onDismiss: (ReplyWorkspace.CompletionResult) -> Void
    
    @SwiftUI.Environment(\.theme) private var theme
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = workspace.viewController
        
        // Set up the completion handler
        workspace.completion = { result in
            onDismiss(result)
        }
        
        // Apply theme to the navigation controller and its content
        applyTheme(to: viewController)
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update theme if needed
        applyTheme(to: uiViewController)
    }
    
    private func applyTheme(to viewController: UIViewController) {
        // Apply theme to navigation controller
        if let navController = viewController as? UINavigationController {
            navController.view.backgroundColor = theme[uicolor: "backgroundColor"]
            navController.navigationBar.barTintColor = theme[uicolor: "navigationBarTintColor"]
            navController.navigationBar.tintColor = theme[uicolor: "navigationBarTextColor"]
            navController.navigationBar.titleTextAttributes = [
                .foregroundColor: theme[uicolor: "navigationBarTextColor"] ?? UIColor.label
            ]
            
            // Apply theme to the root view controller (CompositionViewController)
            if let compositionVC = navController.topViewController as? ViewController {
                compositionVC.themeDidChange()
            }
        }
        
        // Apply theme if it's a themed view controller
        if let themedViewController = viewController as? ViewController {
            themedViewController.themeDidChange()
        }
    }
}