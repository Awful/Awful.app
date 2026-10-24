# Quote-jump scenario tests

Tapping a quote should land the reader on the quoted post. If that post is on the page already showing, the page scrolls to it; if it's on another page, that page loads and then scrolls to it. These tests exercise every variation of that against a real `WKWebView`, inside the hosted `AwfulTests` bundle, so the assertions are about what the reader would actually see on screen.

## What's here

| File | Role |
|---|---|
| `PostsPageTestHarness.swift` | Builds a `PostsPageViewController` in a window, points `ForumsClient` at the scripted fixture thread, runs the local image server, and provides the actions (tap a quote, open a post route, fire the "tweets loaded" event, drag) and probes (where a post sits on screen, which post is at the top, scroll metrics). `assertLanded(on:in:)` is the one assertion every scenario ends with. |
| `QuoteJumpFixture.swift` | Knows the fixture thread: its ID, how post indexes map to post IDs, and how to load the pages into `FixtureURLProtocol.scriptedThreads`. |
| `LocalImageServer.swift` | A loopback HTTP server answering `GET /img/<name>.png?delay=<ms>&h=<px>` with a solid PNG after the given delay. This is how a scenario controls when media above a target finishes loading, and by how much it grows. `WKWebView` can't be served by a `URLProtocol`, hence a real socket. |
| `QuoteJumpSamePageTests.swift` | Quotes of posts on the page already showing. Scenario table at the top of the file. |
| `QuoteJumpCrossPageTests.swift` | Quotes of posts on other pages, driven the way `AwfulURLRouter` and `PostLocator` do it. Scenario table at the top of the file. |
| `PageOpenRestsAtTopTests.swift` | Opening a page lands at its top rather than with the first post behind the bars: a cached page re-rendered shorter once the fetch hides read posts, a refresh at rest, a thread-list open at the next unread page, pages rendered before they are in a window (as restoration does), a saved restoration anchor restored, the reload after posting a reply from the compose sheet, and a page that WebKit leaves scrolled down or moves back to its scroll position zero. Scenario table at the top of the file. |
| `PageOpenNotPastBottomTests.swift` | Opening a page near its end never leaves it scrolled past the end: the Last Post button, a restored fraction or anchor near the end, and a route to a post two from the end. Scenario table at the top of the file. |

Supporting pieces elsewhere:

- `Scripts/make-quotejump-fixtures.py` generates the fixture thread: `AwfulCore/Tests/AwfulCoreTests/Fixtures/quotejump-p1.html`, `-p2.html`, `-p3.html`, `-p3-seen109.html` and `-p3-seen119.html`. Three pages of forty posts with quotes, slow images and a tweet placed where each scenario needs them; the script's doc comment lists which post does what. Edit the script, not the HTML, then rerun it. The posters are invented.
- `QuoteJumpFixtureScrapingTests` (in `AwfulCoreTests`) checks the generated pages scrape exactly as the harness assumes, so the post numbering can't drift.
- `FixtureURLProtocol` (in AwfulCore, debug builds only) has a scripted-thread mode that serves these pages to `ForumsClient`, including the `goto=post` redirects the Forums send, which is how `locatePost` finds a post's page. `FixtureURLProtocolScriptedThreadTests` covers it.
- `Scripts/add-quotejump-tests.rb` adds any new `*.swift` file in this folder, and any new fixture variant, to the `AwfulTests` target. Run it after adding a scenario file.

## Running

From the repo root:

```
xcodebuild -project Awful.xcodeproj -scheme Awful -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -parallel-testing-enabled NO \
  -only-testing:AwfulTests/QuoteJumpSamePageTests \
  -only-testing:AwfulTests/QuoteJumpCrossPageTests test
```

Keep parallel testing off for these. Each scenario drives a live web view and waits on real layout and image timing; simulator clones have wedged a run before. In Xcode, run the two classes from the test navigator as usual.

A scenario that times out rather than failing usually means an `await` on the web view never came back; the harness's `waitForRender` gives up after 15 seconds, and the suites are meant to be run with a per-test time allowance (`-test-timeouts-enabled YES -default-test-execution-time-allowance 120`) as a backstop.

## Known defects and `XCTExpectFailure`

A scenario that documents a known defect is marked `XCTExpectFailure` with a message naming the cause. The marker is strict: the test passes while the defect stands and fails the moment a fix lands, which is the cue to remove the marker. None is marked at the moment; the defects the suites were written against are fixed. (S3, revealing hidden posts and jumping to one of them, used to be intermittent and carried a non-strict marker; the reveal and the jump are now one ordered operation, so it asserts like the rest. S3b and S9, media above the target finishing after the jump, used to be marked too: `RenderView.js` now holds a jumped-to post in place while content above it loads, since WebKit's scroll anchoring doesn't correct for posts redrawn above the viewport. C7, the `goto=post` request omitting `perpage=40`, is fixed in `ForumsClient.locatePost`.) The failure message of `assertLanded` carries the observed landing (the target's offset from the top inset, which post was actually at the top, scroll position, `location.hash`, and how many images had loaded), so a failing scenario says what happened without a debugger.

## Adding a scenario

1. If it needs posts the fixture doesn't have (a quote in a particular place, media of a particular size or delay), add them in `make-quotejump-fixtures.py`, regenerate, and extend `QuoteJumpFixtureScrapingTests` to pin the new posts.
2. Write the test with the harness: open a page (`openPage` or `openViaPostRoute`), act (`tapQuote`, `click`, `fireTweetsLoaded`, `drag`), let media settle (`settle(milliseconds:in:)`), then `assertLanded`.
3. Add a row to the scenario table at the top of the test file.
4. If it's a new file, run `ruby Scripts/add-quotejump-tests.rb`.

## Limits

- Taps are modelled by calling `PostsPageViewController.didTapLink(to:in:)` directly; the step before it, `WKNavigationDelegate`, is WebKit's. S11 covers that step once with a synthetic click on a rendered quote link.
- Twitter's widgets script is never loaded (tweet embedding is off by default in the harness); `fireTweetsLoaded` posts the same message the script would.
- Hosted tests run without the app's `AppDelegate`, so the harness records the routes a controller hands off (`openRoute`) instead of letting the app's router push a page, then opens them the way the router would.
