//  CloudflareChallengeCoordinatorTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class CloudflareChallengeCoordinatorTests: XCTestCase {

    private var challenge: CloudflareChallenge {
        let url = URL(string: "https://forums.somethingawful.com/")!
        let response = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: ["cf-mitigated": "challenge"])!
        return CloudflareChallenge(request: URLRequest(url: url), response: response, data: Data())!
    }

    func testConcurrentRequestsShareOnePresentation() async {
        let coordinator = CloudflareChallengeCoordinator()
        let gate = Gate()
        let calls = Counter()
        let handler: CloudflareChallengeCoordinator.Handler = { _ in
            await calls.increment()
            await gate.wait()
            return true
        }

        let challenge = self.challenge
        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await coordinator.resolve(challenge, requestStartedAt: Date(), handler: handler)
                }
            }
            // Give every task a chance to reach the coordinator before letting the handler return.
            try? await Task.sleep(nanoseconds: 200_000_000)
            await gate.open()
            return await group.reduce(into: []) { $0.append($1) }
        }

        XCTAssertEqual(results.count, 10)
        XCTAssertTrue(results.allSatisfy { $0 })
        let count = await calls.value
        XCTAssertEqual(count, 1, "only one caller should present the challenge")
    }

    func testResponseFromBeforeClearanceJustRetries() async {
        let coordinator = CloudflareChallengeCoordinator()
        let calls = Counter()
        let handler: CloudflareChallengeCoordinator.Handler = { _ in
            await calls.increment()
            return true
        }

        let first = await coordinator.resolve(challenge, requestStartedAt: Date(), handler: handler)
        XCTAssertTrue(first)

        // Sent before the clearance landed, so its challenge is stale news.
        let stale = await coordinator.resolve(challenge, requestStartedAt: .distantPast, handler: handler)
        XCTAssertTrue(stale)

        let count = await calls.value
        XCTAssertEqual(count, 1)
    }

    func testCancelCooldownSuppressesRepeatPresentation() async {
        let coordinator = CloudflareChallengeCoordinator(cancelCooldown: 60)
        let calls = Counter()
        let handler: CloudflareChallengeCoordinator.Handler = { _ in
            await calls.increment()
            return false
        }

        let first = await coordinator.resolve(challenge, requestStartedAt: Date(), handler: handler)
        XCTAssertFalse(first)
        let second = await coordinator.resolve(challenge, requestStartedAt: Date(), handler: handler)
        XCTAssertFalse(second)

        let count = await calls.value
        XCTAssertEqual(count, 1, "a challenge right after a cancel should fail fast, not re-present")
    }

    func testPresentsAgainOnceCooldownPasses() async {
        let coordinator = CloudflareChallengeCoordinator(cancelCooldown: 0)
        let calls = Counter()
        let handler: CloudflareChallengeCoordinator.Handler = { _ in
            await calls.increment()
            return false
        }

        _ = await coordinator.resolve(challenge, requestStartedAt: Date(), handler: handler)
        _ = await coordinator.resolve(challenge, requestStartedAt: Date(), handler: handler)

        let count = await calls.value
        XCTAssertEqual(count, 2)
    }

    func testNoHandlerMeansNoRetry() async {
        let coordinator = CloudflareChallengeCoordinator()
        let result = await coordinator.resolve(challenge, requestStartedAt: Date(), handler: nil)
        XCTAssertFalse(result)
    }
}

private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let waiters = self.waiters
        self.waiters = []
        waiters.forEach { $0.resume() }
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}
