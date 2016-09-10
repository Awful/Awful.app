//  ShowSmilieKeyboardCommand.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Smilies
import UIKit

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
                NSLog("[\(Mirror(reflecting:self)) \(#function)] error saving: \(error)")
            }
        }
    }
    
    func smilieKeyboard(_ keyboard: SmilieKeyboard, insertNumberOrDecimal numberOrDecimal: String) {
        textView.insertText(numberOrDecimal)
    }
}
