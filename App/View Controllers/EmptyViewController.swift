//  EmptyViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// An EmptyViewController sets its view's background color per its theme, and opens the split view's primary view controller when it first appears.
final class EmptyViewController: ViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        splitViewController?.showPrimaryViewController()
    }
}
