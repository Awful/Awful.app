//  SceneRestorationFallbackTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest

/// `NSUserActivity.userInfo` is a property-list-restricted dictionary; non-PLIST values
/// (Codable structs, NSCoding objects, CGPoint/CGRect) crash at persist time. These tests
/// guard the round-trip and PLIST-safety of every key SceneDelegate writes.
final class SceneRestorationFallbackTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearFallbackRestorationActivity()
    }

    override func tearDown() {
        clearFallbackRestorationActivity()
        super.tearDown()
    }

    func testFullPayloadRoundTrips() {
        let activity = NSUserActivity(activityType: restorationActivityType)
        activity.addUserInfoEntries(from: [
            restorationPrimaryRouteKey: "https://forums.somethingawful.com/showthread.php?threadid=42&pagenumber=3",
            restorationSidebarTabKey: "https://forums.somethingawful.com/bookmarkthreads.php",
            restorationPrimaryDeepRouteKey: "https://forums.somethingawful.com/forumdisplay.php?forumid=1",
            restorationScrollFractionKey: 0.42,
            restorationHiddenPostsKey: 5,
            restorationAnchorPostIDKey: "post123456",
            restorationAnchorDeltaKey: 17.5,
            restorationUnpopRoutesKey: [
                "https://forums.somethingawful.com/forumdisplay.php?forumid=1",
                "https://forums.somethingawful.com/bookmarkthreads.php",
            ],
        ])

        saveFallbackRestorationActivity(activity)
        guard let restored = loadFallbackRestorationActivity() else {
            return XCTFail("loadFallbackRestorationActivity returned nil after a save")
        }

        XCTAssertEqual(restored.activityType, restorationActivityType)
        XCTAssertEqual(restored.userInfo?[restorationPrimaryRouteKey] as? String,
                       "https://forums.somethingawful.com/showthread.php?threadid=42&pagenumber=3")
        XCTAssertEqual(restored.userInfo?[restorationSidebarTabKey] as? String,
                       "https://forums.somethingawful.com/bookmarkthreads.php")
        XCTAssertEqual(restored.userInfo?[restorationPrimaryDeepRouteKey] as? String,
                       "https://forums.somethingawful.com/forumdisplay.php?forumid=1")
        XCTAssertEqual(restored.userInfo?[restorationScrollFractionKey] as? Double, 0.42)
        XCTAssertEqual(restored.userInfo?[restorationHiddenPostsKey] as? Int, 5)
        XCTAssertEqual(restored.userInfo?[restorationAnchorPostIDKey] as? String, "post123456")
        XCTAssertEqual(restored.userInfo?[restorationAnchorDeltaKey] as? Double, 17.5)
        XCTAssertEqual(restored.userInfo?[restorationUnpopRoutesKey] as? [String], [
            "https://forums.somethingawful.com/forumdisplay.php?forumid=1",
            "https://forums.somethingawful.com/bookmarkthreads.php",
        ])
    }

    func testSparsePayloadRoundTrips() {
        let activity = NSUserActivity(activityType: restorationActivityType)
        activity.addUserInfoEntries(from: [
            restorationPrimaryRouteKey: "https://forums.somethingawful.com/bookmarkthreads.php",
        ])

        saveFallbackRestorationActivity(activity)
        guard let restored = loadFallbackRestorationActivity() else {
            return XCTFail("loadFallbackRestorationActivity returned nil after a save")
        }

        XCTAssertEqual(restored.userInfo?[restorationPrimaryRouteKey] as? String,
                       "https://forums.somethingawful.com/bookmarkthreads.php")
        XCTAssertNil(restored.userInfo?[restorationScrollFractionKey])
        XCTAssertNil(restored.userInfo?[restorationAnchorPostIDKey])
        XCTAssertNil(restored.userInfo?[restorationUnpopRoutesKey])
    }

    func testPersistedPayloadIsPLISTSafe() {
        let activity = NSUserActivity(activityType: restorationActivityType)
        activity.addUserInfoEntries(from: [
            restorationPrimaryRouteKey: "https://forums.somethingawful.com/bookmarkthreads.php",
            restorationScrollFractionKey: 0.5,
            restorationAnchorPostIDKey: "post1",
            restorationAnchorDeltaKey: 10.0,
            restorationHiddenPostsKey: 3,
            restorationUnpopRoutesKey: ["https://forums.somethingawful.com/forumdisplay.php?forumid=1"],
        ])
        saveFallbackRestorationActivity(activity)

        guard let payload = UserDefaults.standard.dictionary(forKey: restorationFallbackDefaultsKey) else {
            return XCTFail("nothing persisted under the fallback key")
        }
        for (key, value) in payload {
            XCTAssertTrue(isPLISTSafe(value), "value for key \(key) is not PLIST-safe: \(type(of: value))")
        }
    }

    func testSavedAtTimestampRoundTrips() {
        let savedAt = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let activity = NSUserActivity(activityType: restorationActivityType)
        activity.addUserInfoEntries(from: [
            restorationPrimaryRouteKey: "https://forums.somethingawful.com/bookmarkthreads.php",
            restorationSavedAtKey: savedAt,
        ])

        saveFallbackRestorationActivity(activity)
        guard let restored = loadFallbackRestorationActivity() else {
            return XCTFail("loadFallbackRestorationActivity returned nil after a save")
        }

        XCTAssertEqual(restored.userInfo?[restorationSavedAtKey] as? Date, savedAt)
    }

    func testFreshestActivityPrefersNewestTimestamp() {
        let stale = makeActivity(route: "a", savedAt: Date(timeIntervalSinceNow: -86_400))
        let fresh = makeActivity(route: "b", savedAt: Date())

        XCTAssertTrue(freshestRestorationActivity(among: [stale, fresh]) === fresh)
        XCTAssertTrue(freshestRestorationActivity(among: [fresh, stale]) === fresh)
    }

    func testFreshestActivityStampedBeatsUnstamped() {
        // Even an old stamp beats an unstamped payload: unstamped means UIKit has been
        // serving it since before the timestamp existed, so it's at least as old.
        let unstamped = makeActivity(route: "a", savedAt: nil)
        let stamped = makeActivity(route: "b", savedAt: Date(timeIntervalSinceNow: -86_400))

        XCTAssertTrue(freshestRestorationActivity(among: [unstamped, stamped]) === stamped)
        XCTAssertTrue(freshestRestorationActivity(among: [stamped, unstamped]) === stamped)
    }

    func testFreshestActivityTieKeepsEarlierCandidate() {
        // All-unstamped ties preserve the legacy source priority (the caller's ordering).
        let first = makeActivity(route: "a", savedAt: nil)
        let second = makeActivity(route: "b", savedAt: nil)

        XCTAssertTrue(freshestRestorationActivity(among: [first, second]) === first)
    }

    func testFreshestActivitySkipsNilCandidates() {
        let only = makeActivity(route: "a", savedAt: nil)

        XCTAssertTrue(freshestRestorationActivity(among: [nil, only, nil]) === only)
        XCTAssertNil(freshestRestorationActivity(among: [nil, nil]))
    }

    private func makeActivity(route: String, savedAt: Date?) -> NSUserActivity {
        let activity = NSUserActivity(activityType: restorationActivityType)
        var userInfo: [AnyHashable: Any] = [restorationPrimaryRouteKey: route]
        if let savedAt {
            userInfo[restorationSavedAtKey] = savedAt
        }
        activity.addUserInfoEntries(from: userInfo)
        return activity
    }

    func testEmptyActivityClearsFallback() {
        let seed = NSUserActivity(activityType: restorationActivityType)
        seed.addUserInfoEntries(from: [restorationPrimaryRouteKey: "x"])
        saveFallbackRestorationActivity(seed)
        XCTAssertNotNil(UserDefaults.standard.dictionary(forKey: restorationFallbackDefaultsKey))

        let empty = NSUserActivity(activityType: restorationActivityType)
        saveFallbackRestorationActivity(empty)
        XCTAssertNil(UserDefaults.standard.dictionary(forKey: restorationFallbackDefaultsKey))
    }

    /// Recursively checks that `value` is one of the property-list-allowed types.
    /// (`NSArray`, `NSData`, `NSDate`, `NSDictionary`, `NSNumber`, `NSString`. `NSNull` and
    /// `NSURL` are also documented as safe by Apple but we don't currently emit them.)
    private func isPLISTSafe(_ value: Any) -> Bool {
        if value is String || value is NSNumber || value is Date || value is Data || value is URL || value is NSNull {
            return true
        }
        if let array = value as? [Any] {
            return array.allSatisfy(isPLISTSafe)
        }
        if let dict = value as? [String: Any] {
            return dict.values.allSatisfy(isPLISTSafe)
        }
        return false
    }
}
