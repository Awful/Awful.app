//  ForumsOutageRedirectTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

/// When the Forums are down they either redirect every page to a status page on another host or serve their own "Database Unavailable" page. `FixtureURLProtocol.simulatedForumsOutage` fakes both, and `ForumsClient` must show the page once and then fail the request.
final class ForumsOutageRedirectTests: XCTestCase {

    private var storeDirectory: URL!
    private var dataStore: DataStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        FixtureURLProtocol.resetScripting()
        FixtureURLProtocol.simulatedForumsOutage = .redirectToStatusPage

        storeDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        dataStore = DataStore(storeDirectoryURL: storeDirectory)
        ForumsClient.shared.managedObjectContext = dataStore.mainManagedObjectContext
        ForumsClient.shared.baseURL = URL(string: "https://forums.somethingawful.com/")!
    }

    override func tearDownWithError() throws {
        FixtureURLProtocol.simulatedForumsOutage = .off
        ForumsClient.shared.forumsUnavailableHandler = nil
        ForumsClient.shared.baseURL = nil
        ForumsClient.shared.managedObjectContext = nil
        dataStore = nil
        try? FileManager.default.removeItem(at: storeDirectory)
        try super.tearDownWithError()
    }

    func testSimulatedOutageRedirectsOffTheForums() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureURLProtocol.self] + (config.protocolClasses ?? [])
        let session = URLSession(configuration: config)

        var location: URL?
        let (data, response) = try await session.data(for: URLRequest(url: URL(string: "https://forums.somethingawful.com/index.php")!)) { _, newRequest in
            location = newRequest.url
            return nil
        }
        XCTAssertEqual(location, FixtureURLProtocol.simulatedOutageStatusPageURL)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 302)
        XCTAssertTrue(data.isEmpty)
    }

    func testRedirectedRequestFailsWithoutAHandler() async {
        ForumsClient.shared.forumsUnavailableHandler = nil
        do {
            try await ForumsClient.shared.taxonomizeForums()
            XCTFail("expected the request to fail")
        } catch ServerError.forumsUnavailable(let statusPageURL) {
            XCTAssertEqual(statusPageURL, FixtureURLProtocol.simulatedOutageStatusPageURL)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testConcurrentRequestsShowTheStatusPageOnce() async {
        let shown = Counter()
        ForumsClient.shared.forumsUnavailableHandler = { statusPageURL in
            XCTAssertEqual(statusPageURL, FixtureURLProtocol.simulatedOutageStatusPageURL)
            await shown.increment()
            // Long enough for every request below to arrive while the sheet is up.
            try? await Task.sleep(nanoseconds: 300_000_000)
            return true
        }

        let failures = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    do {
                        try await ForumsClient.shared.taxonomizeForums()
                        return false
                    } catch ServerError.forumsUnavailable {
                        return true
                    } catch {
                        return false
                    }
                }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }

        let count = await shown.value
        XCTAssertEqual(count, 1, "every request should wait on the one sheet")
        XCTAssertEqual(failures, 5, "the retry after the sheet closes is still redirected, so each request fails")
    }

    func testDatabaseUnavailablePageShowsTheRequestURLThenFailsAsDatabaseUnavailable() async {
        FixtureURLProtocol.simulatedForumsOutage = .databaseUnavailable
        let shown = Counter()
        ForumsClient.shared.forumsUnavailableHandler = { statusPageURL in
            XCTAssertEqual(statusPageURL.host, "forums.somethingawful.com")
            XCTAssertEqual(statusPageURL.path, "/index.php")
            await shown.increment()
            return true
        }

        do {
            try await ForumsClient.shared.taxonomizeForums()
            XCTFail("expected the request to fail")
        } catch ServerError.databaseUnavailable(let title, _) {
            XCTAssertEqual(title, "Database Unavailable!")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        let count = await shown.value
        XCTAssertEqual(count, 1)
    }

    func testDatabaseUnavailableDetectionNeedsTheRealPage() throws {
        let fixtureURL = try XCTUnwrap(Bundle.module.url(forResource: "database-unavailable", withExtension: "html", subdirectory: "Fixtures"))
        let realPage = try Data(contentsOf: fixtureURL)
        let detected = try XCTUnwrap(ForumsClient.databaseUnavailablePage(in: realPage, contentType: "text/html; charset=utf-8"))
        XCTAssertEqual(detected.title, "Database Unavailable!")

        // A post quoting the page's markup is still an ordinary posts page.
        let postMentioningIt = Data("""
            <html><body id="something_awful" class="thread">
            <div id="content"><div class="postbody">Got the &lt;body class="database_error"&gt; page again, anyone else?</div></div>
            </body></html>
            """.utf8)
        XCTAssertNil(ForumsClient.databaseUnavailablePage(in: postMentioningIt, contentType: "text/html; charset=utf-8"))

        let json = Data(#"{"forums": [], "note": "database_error"}"#.utf8)
        XCTAssertNil(ForumsClient.databaseUnavailablePage(in: json, contentType: "application/json"))
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}
