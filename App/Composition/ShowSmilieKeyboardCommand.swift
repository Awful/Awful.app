//  ShowSmilieKeyboardCommand.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Smilies
import UIKit

final class ShowSmilieKeyboardCommand: NSObject {
    private let textView: UITextView
    
    init(textView: UITextView) {
        self.textView = textView
        super.init()
    }
    
    private lazy var smilieKeyboard: SmilieKeyboard = {
        let keyboard = SmilieKeyboard()
        keyboard.delegate = self
        keyboard.view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        return keyboard
        }()
    
    private var showingSmilieKeyboard: Bool = false
    
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
    
    private var justInsertedSmilieText: String?
}

extension ShowSmilieKeyboardCommand: SmilieKeyboardDelegate {
    func advanceToNextInputModeForSmilieKeyboard(keyboard: SmilieKeyboard) {
        execute()
    }
    
    func deleteBackwardForSmilieKeyboard(keyboard: SmilieKeyboard) {
        if let justInserted = justInsertedSmilieText {
            justInsertedSmilieText = nil
            
            if let selectedTextRange = textView.selectedTextRange {
                let startPosition = textView.positionFromPosition(selectedTextRange.start, offset: -(justInserted as NSString).length)
                let range = textView.textRangeFromPosition(startPosition!, toPosition: selectedTextRange.start)
                if textView.textInRange(range!) == justInserted {
                    return textView.replaceRange(range!, withText: "")
                }
            }
        }
        
        textView.deleteBackward()
    }
    
    func smilieKeyboard(keyboard: SmilieKeyboard, didTapSmilie smilie: Smilie) {
        textView.insertText(smilie.text)
        justInsertedSmilieText = smilie.text
        
        smilie.managedObjectContext?.performBlock {
            smilie.metadata.lastUsedDate = NSDate()
            do {
                try smilie.managedObjectContext!.save()
            }
            catch {
                NSLog("[\(Mirror(reflecting:self)) \(#function)] error saving: \(error)")
            }
        }
    }
    
    func smilieKeyboard(keyboard: SmilieKeyboard, insertNumberOrDecimal numberOrDecimal: String) {
        textView.insertText(numberOrDecimal)
    }
}
