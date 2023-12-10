//  URLSession+willRedirect.swift
//
//  Copyright 2023 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension URLSession {
    /**
     Downloads the contents of a URL based on the specified URL request and delivers the data asynchronously, with control over redirects.

     Calls `data(for:delegate:)` with a delegate that trampolines `urlSession(_:task:willPerformHTTPRedirection:newRequest:)` to the `willRedirect` parameter.

     `willRedirect` should return "either the value of the request parameter, a modified URL request object, or [`nil`] to refuse the redirect and return the body of the redirect response."
     */
    func data(
        for request: URLRequest,
        willRedirect: @escaping (_ response: HTTPURLResponse, _ newRequest: URLRequest) async -> URLRequest?
    ) async throws -> (Data, URLResponse) {
        let delegate = Delegate(willRedirect)
        return try await data(for: request, delegate: delegate)
    }

    private class Delegate: NSObject, URLSessionTaskDelegate {
        let willRedirect: (_ response: HTTPURLResponse, _ newRequest: URLRequest) async -> URLRequest?
        init(_ willRedirect: @escaping (_ response: HTTPURLResponse, _ newRequest: URLRequest) async -> URLRequest?) {
            self.willRedirect = willRedirect
        }
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest
        ) async -> URLRequest? {
            await willRedirect(response, request)
        }
    }
}
