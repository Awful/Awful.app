//  Tweaks.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftTweaks

/**
 Tweaks that are accessible in debug, simulator, and TestFlight builds by shaking the device.
 
 To add a new tweak:
 
 1. Add a static property between the indicated lines. (Feel free to use a handy caseless enum as a namespace to match the tweak section.)
 2. Add the newly-created property to the `tweaks` array in `defaultStore` near the bottom of this file.
 */
struct Tweaks: TweakLibraryType {
    
    // ▼▼▼ New tweaks go below this line (don't forget to add to `tweaks` array in `defaultStore`!) ▼▼▼
    
    
    enum posts {
        static let pullForNextExtraDistance = Tweak<CGFloat>("Posts", "Pull-for-next", "Extra distance", defaultValue: 45, min: 0, max: 500)
    }
    
    
    // ▲▲▲ New tweaks go above this line (don't forget to add to `tweaks` array in `defaultStore`!) ▲▲▲
    
    static let defaultStore: TweakStore = {
        var tweaks: [TweakClusterType] = [
            
            // ▼▼▼ Add all new tweaks here or they won't show up! ▼▼▼
            
            
            posts.pullForNextExtraDistance,
            
            
            // ▲▲▲ Add all new tweaks here or they won't show up! ▲▲▲
        ]
        
        var isEnabled: Bool {
            #if DEBUG
                return true
            #elseif targetEnvironment(simulator)
                return true
            #else
                let receiptPathComponents = Bundle.main.appStoreReceiptURL?.pathComponents ?? []
                return receiptPathComponents.contains("sandboxReceipt") // TestFlight build
            #endif
        }
        
        return TweakStore(tweaks: tweaks, enabled: isEnabled)
    }()
}
