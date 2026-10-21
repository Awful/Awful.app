//  SharedPromptCoordinator.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/**
 Makes sure only one prompt of a kind (a Cloudflare challenge, the Forums' outage page) is shown at a time.

 App launch fires several requests together (forum list, announcements, inbox), and whatever stopped one of them stops all of them. Whichever request notices first runs the handler; the rest join the same in-flight resolution and share its outcome instead of stacking sheets. Responses that were already on the wire before the prompt was answered are told to simply retry.
 */
public actor SharedPromptCoordinator<Prompt: Sendable> {

    /// Presents the prompt to the user and returns `true` once the caller should retry its request, or `false` if the user gave up.
    public typealias Handler = @MainActor @Sendable (Prompt) async -> Bool

    private var inFlight: Task<Bool, Never>?
    private var lastClearedAt: Date?
    private var lastCancelledAt: Date?

    /// After the user cancels, prompts that arrive within this window fail immediately rather than re-presenting the sheet for each of the requests that were already in flight.
    let cancelCooldown: TimeInterval

    init(cancelCooldown: TimeInterval = 5) {
        self.cancelCooldown = cancelCooldown
    }

    /**
     Resolves a prompt, presenting it via `handler` if nothing else already is.

     - Parameter requestStartedAt: When the stopped request was sent. If a prompt was cleared after that, the response merely predates the clearance and the caller can retry without any UI.
     - Returns: `true` when the caller should retry its request.
     */
    func resolve(
        _ prompt: Prompt,
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
        let task = Task { await handler(prompt) }
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

/// The coordinator for Cloudflare challenges. See ``SharedPromptCoordinator``.
public typealias CloudflareChallengeCoordinator = SharedPromptCoordinator<CloudflareChallenge>
