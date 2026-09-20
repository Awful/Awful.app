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
        
        // A minimized keyboard (see `UITextView.setKeyboardMinimized`) is also a custom input
        // view; the smilie keyboard takes its place and leaves the system keyboard on the way out.
        if showingSmilieKeyboard && textView.inputView !== smilieKeyboard.view {
            textView.inputView = smilieKeyboard.view
            textView.reloadInputViews()
        } else if !showingSmilieKeyboard && textView.inputView === smilieKeyboard.view {
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
        if viewController is SmiliePickerHost {
            return
        }
        
        // Dismiss keyboard before showing smilie picker
        textView.resignFirstResponder()

        let pickerView = SmiliePickerView(dataStore: smilieKeyboard.dataStore) { [weak self, weak textView] smilie in
            self?.insertSmilie(smilie)
            // Delay keyboard reactivation to ensure smooth animation after sheet dismissal
            // Without this delay, the keyboard animation can conflict with sheet dismissal
            DispatchQueue.main.async {
                textView?.becomeFirstResponder()
            }
        }
        .onDisappear { [weak textView] in
            // Delay keyboard reactivation when view disappears (handles Done button case)
            // This ensures the sheet dismissal animation completes before keyboard appears
            DispatchQueue.main.async {
                textView?.becomeFirstResponder()
            }
        }
        .themed()

        let hostingController = SmiliePickerHostingController(rootView: pickerView)
        hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [UISheetPresentationController.Detent.medium(), UISheetPresentationController.Detent.large()]
            // The medium-detent sheet is too small on iPad; start at full height there
            if UIDevice.current.userInterfaceIdiom == .pad {
                sheet.selectedDetentIdentifier = .large
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
            sheet.delegate = self
        }
        
        viewController.present(hostingController, animated: true)
    }
    
    private func insertSmilie(_ smilie: Smilie) {
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
    
    fileprivate var justInsertedSmilieText: String?
}

/// Marks the presented smilie picker so it can be recognised by type check. The root view is a
/// `ModifiedContent<…>` once `.onDisappear` and `.themed()` are applied, so a check against
/// `UIHostingController<SmiliePickerView>` can never succeed.
private protocol SmiliePickerHost: AnyObject {}

private final class SmiliePickerHostingController<Content: View>: UIHostingController<Content>, SmiliePickerHost {}

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
