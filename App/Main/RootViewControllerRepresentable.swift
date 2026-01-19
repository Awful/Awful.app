//  RootViewControllerRepresentable.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import SwiftUI
import UIKit

struct RootViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        guard let appDelegate = AppDelegate.instance else {
            fatalError("AppDelegate not initialized")
        }

        let rootVC: UIViewController
        if ForumsClient.shared.isLoggedIn {
            rootVC = appDelegate.rootViewControllerStack.rootViewController
            appDelegate.rootViewControllerStack.didAppear()
        } else {
            rootVC = appDelegate.loginViewController.enclosingNavigationController
        }

        appDelegate.setupOpenCopiedURLController()

        return rootVC
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
}
