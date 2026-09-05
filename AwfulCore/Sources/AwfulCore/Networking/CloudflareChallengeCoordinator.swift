//  CloudflareChallengeCoordinator.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/**
 Makes sure only one Cloudflare challenge is shown at a time.

 App launch fires several requests together (forum list, announcements, inbox), and a challenge stops all of them. Whichever request notices first runs the handler; the rest join the same in-flight resolution and share its outcome instead of stacking sheets. Responses that were already on the wire before a clearance landed are told to simply retry.
 */
public actor CloudflareChallengeCoordinator {

    /// Presents the challenge to the user and returns `true` once it's cleared (with the clearance cookie in the shared cookie storage), or `false` if the user gave up.
    public typealias Handler = @MainActor @Sendable (CloudflareChallenge) async -> Bool

    private var inFlight: Task<Bool, Never>?
    private var lastClearedAt: Date?
    private var lastCancelledAt: Date?

    /// After the user cancels, challenges that arrive within this window fail immediately rather than re-presenting the sheet for each of the requests that were already in flight.
    let cancelCooldown: TimeInterval

    init(cancelCooldown: TimeInterval = 5) {
        self.cancelCooldown = cancelCooldown
    }

    /**
     Resolves a challenge, presenting it via `handler` if nothing else already is.

     - Parameter requestStartedAt: When the challenged request was sent. If a challenge was cleared after that, the response merely predates the clearance and the caller can retry without any UI.
     - Returns: `true` when the caller should retry its request.
     */
    func resolve(
        _ challenge: CloudflareChallenge,
        requestStartedAt: Date,
        handler: Handler?
    ) async -> Bool {
        if let lastClearedAt, lastClearedAt > requestStartedAt {
            return true
        }
        if let inFlight {
            return await inFlight.value
        }
        guard let handler else { return false }
        if let lastCancelledAt, Date().timeIntervalSince(lastCancelledAt) < cancelCooldown {
            return false
        }

        // Unstructured on purpose: one caller's cancellation (e.g. a page load being abandoned) mustn't tear the sheet down for everyone else waiting on it.
        let task = Task { await handler(challenge) }
        inFlight = task
        let cleared = await task.value
        inFlight = nil
        if cleared {
            lastClearedAt = Date()
        } else {
            lastCancelledAt = Date()
        }
        return cleared
    }
}
