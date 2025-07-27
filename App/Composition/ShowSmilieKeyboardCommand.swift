//  ShowSmilieKeyboardCommand.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import os
import Smilies
import SwiftUI
import UIKit
import AwfulSettings
import AwfulTheming

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ShowSmilieKeyboardCommand")

final class ShowSmilieKeyboardCommand: NSObject {
    fileprivate let textView: UITextView
    private weak var presentingViewController: UIViewController?
    
    init(textView: UITextView) {
        self.textView = textView
        super.init()
    }
    
    fileprivate lazy var smilieKeyboard: SmilieKeyboard = {
        let keyboard = SmilieKeyboard()
        keyboard.delegate = self
        keyboard.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return keyboard
        }()
    
    fileprivate var showingSmilieKeyboard: Bool = false
    
    func execute() {
        if UserDefaults.standard.defaultingValue(for: Settings.useNewSmiliePicker) {
            showNewSmiliePicker()
        } else {
            showLegacySmilieKeyboard()
        }
    }
    
    private func showLegacySmilieKeyboard() {
        showingSmilieKeyboard = !showingSmilieKeyboard
        
        if showingSmilieKeyboard && textView.inputView == nil {
            textView.inputView = smilieKeyboard.view
            textView.reloadInputViews()
        } else if !showingSmilieKeyboard && textView.inputView != nil {
            textView.inputView = nil
            textView.reloadInputViews()
        }
        
        if !showingSmilieKeyboard {
            justInsertedSmilieText = nil
        }
    }
    
    private func showNewSmiliePicker() {
        guard var viewController = textView.window?.rootViewController else { return }
        
        // Find the topmost presented view controller
        while let presented = viewController.presentedViewController {
            viewController = presented
        }
        
        // Check if smilie picker is already being presented
        if viewController is UIHostingController<SmiliePickerView> {
            return
        }
        
        // Dismiss keyboard before showing smilie picker
        textView.resignFirstResponder()
        
        // Get the current theme
        let currentTheme = Theme.defaultTheme()
        
        weak var weakTextView = textView
        let pickerView = SmiliePickerView(dataStore: smilieKeyboard.dataStore) { [weak self] smilieData in
            self?.insertSmilieData(smilieData)
            // Delay keyboard reactivation to ensure smooth animation after sheet dismissal
            // Without this delay, the keyboard animation can conflict with sheet dismissal
            DispatchQueue.main.async {
                weakTextView?.becomeFirstResponder()
            }
        }
        .onDisappear {
            // Delay keyboard reactivation when view disappears (handles Done button case)
            // This ensures the sheet dismissal animation completes before keyboard appears
            DispatchQueue.main.async {
                weakTextView?.becomeFirstResponder()
            }
        }
        .environment(\.theme, currentTheme)
        
        let hostingController = UIHostingController(rootView: pickerView)
        hostingController.modalPresentationStyle = .pageSheet
        
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
            sheet.delegate = self
        }
        
        presentingViewController = viewController
        viewController.present(hostingController, animated: true)
    }
    
    private func insertSmilieData(_ smilieData: SmilieData) {
        textView.insertText(smilieData.text)
        justInsertedSmilieText = smilieData.text
    }
    
    fileprivate var justInsertedSmilieText: String?
}

extension ShowSmilieKeyboardCommand: SmilieKeyboardDelegate {
    func advanceToNextInputMode(for keyboard: SmilieKeyboard) {
        execute()
    }
    
    func deleteBackward(for keyboard: SmilieKeyboard) {
        if let justInserted = justInsertedSmilieText {
            justInsertedSmilieText = nil
            
            if let selectedTextRange = textView.selectedTextRange {
                let startPosition = textView.position(from: selectedTextRange.start, offset: -(justInserted as NSString).length)
                let range = textView.textRange(from: startPosition!, to: selectedTextRange.start)
                if textView.text(in: range!) == justInserted {
                    return textView.replace(range!, withText: "")
                }
            }
        }
        
        textView.deleteBackward()
    }
    
    func smilieKeyboard(_ keyboard: SmilieKeyboard, didTap smilie: Smilie) {
        textView.insertText(smilie.text)
        justInsertedSmilieText = smilie.text
        
        smilie.managedObjectContext?.perform {
            smilie.metadata.lastUsedDate = Date()
            do {
                try smilie.managedObjectContext!.save()
            }
            catch {
                logger.error("error saving: \(error)")
            }
        }
    }
    
    func smilieKeyboard(_ keyboard: SmilieKeyboard, insertNumberOrDecimal numberOrDecimal: String) {
        textView.insertText(numberOrDecimal)
    }
}

extension ShowSmilieKeyboardCommand: UISheetPresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // Reactivate keyboard after sheet dismissal (swipe down or Done button)
        textView.becomeFirstResponder()
    }
}
