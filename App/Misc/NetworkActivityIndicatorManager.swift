//  NetworkActivityIndicatorManager.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import PromiseKit
import UIKit

/**
 Shows and hides the network activity manager (lil spinner/animation in the status bar).

 Follows the HIG's recommendation to "show this indicator only for network operations lasting more than a few seconds", and also introduces a brief delay before hiding so there's no flashes.

 Usage:

     NetworkActivityIndicatorManager.shared.incrementActivityCount()
     startRequest(completion: { (error: Error?) in
         NetworkActivityIndicatorManager.shared.decrementActivityCount()
     })
 */
final class NetworkActivityIndicatorManager {
    private var activityCount = 0
    private let queue = DispatchQueue(label: "NetworkActivityIndicatorManager")

    static let shared = NetworkActivityIndicatorManager()
    private init() {}

    /// Shows the network activity indicator if it's not already visible. Call `decrementActivityCount()` when the request is finished, or the indicator will stay visible forever!
    func incrementActivityCount() {
        queue.sync { changeActivityCount(+1) }
    }

    /// Hides the network activity indicator if there are no more outstanding requests.
    func decrementActivityCount() {
        queue.sync { changeActivityCount(-1) }
    }

    private func changeActivityCount(_ delta: Int) {
        let oldCount = activityCount
        let newCount = max(0, oldCount + delta)
        activityCount = newCount

        if oldCount == 0 {
            _ = after(.seconds(3))
                .map(on: queue) {
                    guard self.activityCount > 0 else {
                        throw IndicatorUpdateUnnecessary()
                    }
                }.done(on: .main) {
                    #if !targetEnvironment(macCatalyst)
                    UIApplication.shared.isNetworkActivityIndicatorVisible = true
                    #endif
            }
        } else if newCount == 0 {
            _ = after(.milliseconds(300))
                .map(on: queue) {
                    guard self.activityCount == 0 else {
                        throw IndicatorUpdateUnnecessary()
                    }
                }
                .done(on: .main) {
                    #if !targetEnvironment(macCatalyst)
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    #endif
            }
        }
    }
}

private struct IndicatorUpdateUnnecessary: Error {}
