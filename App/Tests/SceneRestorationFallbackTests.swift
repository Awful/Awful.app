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
