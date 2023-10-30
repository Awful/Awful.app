//  URLSession+willRedirectTests.swift
//
//  Copyright 2023 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class URLSession_willRedirectTests: XCTestCase {
    func testStopRedirect() async throws {
        // This test is kinda silly. Occasionally we want to follow a redirect only to discover the destination URL, without actually loading the content. e.g. to locate the thread for a given post ID, we look for a redirect to showthread.php and then we can get the thread ID and page number from that URL. This test jumps through a bunch of hoops to verify the URLSession behavior when cancelling a redirect.
        let configuration = URLSessionConfiguration.ephemeral
        /// This protocol always redirects, incrementing a number each time.
        class RedirectProtocol: URLProtocol {
            override class func canInit(with task: URLSessionTask) -> Bool {
                task.originalRequest?.url?.scheme == "x-redirect"
            }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
            override func startLoading() {
                let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: true)!
                let i = Int(components.path)!
                let request = URLRequest(url: URL(string: "x-redirect:\(i + 1)")!)
                let response = HTTPURLResponse(url: components.url!, statusCode: 301, httpVersion: "1.1", headerFields: ["Location": request.url!.absoluteString])!
                client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
                // CFNetwork will make a new instance to load the redirect, so we need to cancel this one. Otherwise the URLSessionTask will never complete.
                client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
            }
            override func stopLoading() {}
        }
        configuration.protocolClasses = (configuration.protocolClasses ?? []) + [RedirectProtocol.self]
        let session = URLSession(configuration: configuration)
        let request = URLRequest(url: URL(string: "x-redirect:1")!)
        var responseURLs: [URL] = []
        var newRequestURLs: [URL] = []
        do {
            _ = try await session.data(for: request, willRedirect: { response, newRequest in
                responseURLs.append(response.url!)
                newRequestURLs.append(newRequest.url!)
                if URLComponents(url: newRequest.url!, resolvingAgainstBaseURL: true)!.path == "3" {
                    return nil
                } else {
                    return newRequest
                }
            })
        } catch URLError.cancelled {
            // yay
        }
        // Did we top getting responses once we cancelled?
        XCTAssertEqual(responseURLs, [1, 2].map { URL(string: "x-redirect:\($0)")! })
        // And did we get a look at the destination URLs we care about?
        XCTAssertEqual(newRequestURLs, [2, 3].map { URL(string: "x-redirect:\($0)")! })
    }
}
