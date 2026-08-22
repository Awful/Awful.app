//  TrackingParameterRemoverTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import XCTest

final class TrackingParameterRemoverTests: XCTestCase {

    private func cleaned(_ urlString: String) -> String? {
        TrackingParameterRemover.cleanedURL(URL(string: urlString)!)?.absoluteString
    }

    // MARK: Generic trackers

    func testStripsUTMKeepingOtherParams() {
        XCTAssertEqual(
            cleaned("https://example.com/a?utm_source=x&utm_medium=y&id=5"),
            "https://example.com/a?id=5"
        )
    }

    func testDropsQueryEntirelyWhenAllParamsStripped() {
        XCTAssertEqual(
            cleaned("https://example.com/a?fbclid=abc"),
            "https://example.com/a"
        )
    }

    func testStripsGenericClickIDs() {
        XCTAssertEqual(
            cleaned("https://example.com/?gclid=1&msclkid=2&mc_eid=3&keep=yes"),
            "https://example.com/?keep=yes"
        )
    }

    func testCaseInsensitiveParameterNames() {
        XCTAssertEqual(
            cleaned("https://example.com/?FBCLID=abc&UTM_Source=x&id=5"),
            "https://example.com/?id=5"
        )
    }

    // MARK: No change

    func testCleanURLReturnsNil() {
        XCTAssertNil(cleaned("https://example.com/a?id=5"))
        XCTAssertNil(cleaned("https://example.com/a"))
        XCTAssertNil(cleaned("https://example.com/a?"))
    }

    func testNonHTTPSchemesUntouched() {
        XCTAssertNil(cleaned("mailto:someone@example.com"))
        XCTAssertNil(cleaned("awful://posts/123?utm_source=x"))
    }

    // MARK: YouTube

    func testYouTubeShortLinkKeepsTimestamp() {
        XCTAssertEqual(
            cleaned("https://youtu.be/iRpyVEMnYTc?si=AbCdEfGh123&t=29"),
            "https://youtu.be/iRpyVEMnYTc?t=29"
        )
    }

    func testYouTubeWatchKeepsVideoAndPlaylistParams() {
        XCTAssertEqual(
            cleaned("https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL123&index=2&si=AAA&pp=xyz&feature=share"),
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL123&index=2"
        )
    }

    func testYouTubeMusicMatchesViaSuffix() {
        XCTAssertEqual(
            cleaned("https://music.youtube.com/watch?v=abc&si=XYZ"),
            "https://music.youtube.com/watch?v=abc"
        )
    }

    func testSimilarHostNameIsNotStripped() {
        XCTAssertNil(cleaned("https://notyoutube.com/?si=x"))
        XCTAssertNil(cleaned("https://example.com/?si=x"))
    }

    // MARK: Twitter/X

    func testXStatusShareParamsStripped() {
        XCTAssertEqual(
            cleaned("https://x.com/user/status/123456?s=46&t=ZZZtokenZZZ"),
            "https://x.com/user/status/123456"
        )
        XCTAssertEqual(
            cleaned("https://twitter.com/user/status/123456?s=20&ref_src=twsrc%5Etfw"),
            "https://twitter.com/user/status/123456"
        )
    }

    func testTwitterSearchKeepsQuery() {
        XCTAssertEqual(
            cleaned("https://twitter.com/search?q=foo&s=1"),
            "https://twitter.com/search?q=foo"
        )
    }

    // MARK: Instagram

    func testInstagramKeepsCarouselIndex() {
        XCTAssertEqual(
            cleaned("https://www.instagram.com/p/ABC123/?igsh=xyzzy&img_index=2"),
            "https://www.instagram.com/p/ABC123/?img_index=2"
        )
    }

    // MARK: TikTok

    func testTikTokShareLink() {
        XCTAssertEqual(
            cleaned("https://www.tiktok.com/@user/video/7123456789?is_from_webapp=1&sender_device=pc&web_id=999&u_code=abc&_r=1&_t=8xyz&lang=en"),
            "https://www.tiktok.com/@user/video/7123456789?lang=en"
        )
    }

    func testTikTokShortLinkPassesThrough() {
        XCTAssertNil(cleaned("https://vm.tiktok.com/ZM123abc/"))
    }

    // MARK: Bluesky

    func testBlueskyEmbedReferrerStripped() {
        XCTAssertEqual(
            cleaned("https://bsky.app/profile/user.bsky.social/post/abc123?ref_src=embed&ref_url=https%3A%2F%2Fexample.com"),
            "https://bsky.app/profile/user.bsky.social/post/abc123"
        )
    }

    // MARK: Reddit

    func testRedditKeepsContextAndStripsEncodedDollarNames() {
        XCTAssertEqual(
            cleaned("https://www.reddit.com/r/foo/comments/abc/thing/xyz/?share_id=X&context=3&%24deep_link=Y"),
            "https://www.reddit.com/r/foo/comments/abc/thing/xyz/?context=3"
        )
    }

    // MARK: Spotify

    func testSpotifyKeepsContextWithOriginalPercentEncoding() {
        XCTAssertEqual(
            cleaned("https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC?si=abc123&context=spotify%3Aplaylist%3A37i9dQ"),
            "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC?context=spotify%3Aplaylist%3A37i9dQ"
        )
    }

    // MARK: Amazon

    func testAmazonRefPathAndTrackingParams() {
        XCTAssertEqual(
            cleaned("https://www.amazon.com/Thing/dp/B0ABC123/ref=sr_1_5?keywords=x&qid=1700000000&sr=8-5&k=query&th=1"),
            "https://www.amazon.com/Thing/dp/B0ABC123?k=query&th=1"
        )
    }

    func testAmazonRefPathWithNoQuery() {
        XCTAssertEqual(
            cleaned("https://www.amazon.com/dp/B0ABC123/ref=cm_sw_r_cp_api"),
            "https://www.amazon.com/dp/B0ABC123"
        )
    }

    func testAmazonInternationalTLDs() {
        XCTAssertEqual(
            cleaned("https://www.amazon.co.uk/dp/B0ABC123?tag=affiliate-21&psc=1"),
            "https://www.amazon.co.uk/dp/B0ABC123?psc=1"
        )
        XCTAssertEqual(
            cleaned("https://www.amazon.com.au/dp/B0ABC123?pf_rd_r=XYZ&node=123"),
            "https://www.amazon.com.au/dp/B0ABC123?node=123"
        )
    }

    // MARK: Encoding & structure preservation

    func testRetainedParamValueEncodingPreserved() {
        XCTAssertEqual(
            cleaned("https://example.com/?a=1%2B1&utm_source=x"),
            "https://example.com/?a=1%2B1"
        )
    }

    func testFragmentPreserved() {
        XCTAssertEqual(
            cleaned("https://example.com/page?utm_source=x#section-2"),
            "https://example.com/page#section-2"
        )
    }

    func testValuelessParams() {
        XCTAssertEqual(
            cleaned("https://example.com/?a&utm_source=x"),
            "https://example.com/?a"
        )
    }

    // MARK: cleanedText

    func testCleanedTextWholeStringURL() {
        let result = TrackingParameterRemover.cleanedText("https://youtu.be/iRpyVEMnYTc?si=AAA&t=29")
        XCTAssertTrue(result.didChange)
        XCTAssertEqual(result.cleanedText, "https://youtu.be/iRpyVEMnYTc?t=29")
        XCTAssertEqual(result.replacements.count, 1)
        XCTAssertEqual(result.replacements[0].original, "https://youtu.be/iRpyVEMnYTc?si=AAA&t=29")
        XCTAssertEqual(result.replacements[0].cleaned, "https://youtu.be/iRpyVEMnYTc?t=29")
        XCTAssertEqual(result.replacements[0].range, NSRange(location: 0, length: 33))
    }

    func testCleanedTextEmbeddedURLs() {
        let input = "check this https://x.com/a/status/1?s=46 and also https://example.com/ok?id=1 out"
        let result = TrackingParameterRemover.cleanedText(input)
        XCTAssertEqual(result.cleanedText, "check this https://x.com/a/status/1 and also https://example.com/ok?id=1 out")
        XCTAssertEqual(result.replacements.count, 1)
        let replacement = result.replacements[0]
        XCTAssertEqual(replacement.cleaned, "https://x.com/a/status/1")
        let extracted = (result.cleanedText as NSString).substring(with: replacement.range)
        XCTAssertEqual(extracted, replacement.cleaned)
    }

    func testCleanedTextMultipleDirtyURLs() {
        let input = "a https://example.com/?utm_source=x b https://youtu.be/ID123ABCDEF?si=Q&t=5 c"
        let result = TrackingParameterRemover.cleanedText(input)
        XCTAssertEqual(result.cleanedText, "a https://example.com/ b https://youtu.be/ID123ABCDEF?t=5 c")
        XCTAssertEqual(result.replacements.count, 2)
        for replacement in result.replacements {
            let extracted = (result.cleanedText as NSString).substring(with: replacement.range)
            XCTAssertEqual(extracted, replacement.cleaned)
        }
    }

    func testCleanedTextNoURLs() {
        let result = TrackingParameterRemover.cleanedText("hello world, no links here")
        XCTAssertFalse(result.didChange)
        XCTAssertEqual(result.cleanedText, "hello world, no links here")
    }

    func testCleanedTextSchemelessURLUntouched() {
        let input = "see www.example.com?utm_source=x for details"
        let result = TrackingParameterRemover.cleanedText(input)
        XCTAssertFalse(result.didChange)
        XCTAssertEqual(result.cleanedText, input)
    }
}
