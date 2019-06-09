//  Tweaks.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftTweaks

/**
 Tweaks that are accessible in debug, simulator, and TestFlight builds by shaking the device.
 
 To add a new tweak:

 1. Add your to-be-created property to the `allTweaks` array between the indicated lines.
 2. Add a static property for your tweak between the indicated lines. (Feel free to use a handy caseless enum as a namespace to match the tweak section.)
 */
struct Tweaks: TweakLibraryType {

    private static let allTweaks: [TweakClusterType] = [

        // ▼▼▼ Add all new tweaks here or they won't show up! ▼▼▼

        launch.offerToOpenSameCopiedURL,
        posts.delayBeforePullForNext,
        posts.pullForNextExtraDistance,
        posts.showCopyAsMarkdownAction,

        // ▲▲▲ Add all new tweaks here or they won't show up! ▲▲▲
    ]

    // ▼▼▼ New tweaks go below this line (don't forget to add to `tweaks` array in `defaultStore`!) ▼▼▼
    
    enum launch {
        static let offerToOpenSameCopiedURL = Tweak("Launch", "Open Copied URL", "Re-offer same", false)
    }
    
    enum posts {
        static let delayBeforePullForNext = Tweak<TimeInterval>("Posts", "Pull-for-next", "Delay (s)", defaultValue: 0, min: 0, max: 10)
        static let pullForNextExtraDistance = Tweak<CGFloat>("Posts", "Pull-for-next", "Extra distance", defaultValue: 45, min: 0, max: 500)
        static let showCopyAsMarkdownAction = Tweak("Posts", "Extra Actions", "Copy as Markdown", false)
    }

    // ▲▲▲ New tweaks go above this line (don't forget to add to `tweaks` array in `defaultStore`!) ▲▲▲


    static var isEnabled: Bool {
        return Environment.isDebugBuild || Environment.isSimulator || Environment.isInstalledViaTestFlight
    }
    
    static let defaultStore: TweakStore = {
        return TweakStore(tweaks: allTweaks, enabled: Tweaks.isEnabled)
    }()
}
