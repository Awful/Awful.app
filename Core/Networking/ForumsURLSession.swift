//  ForumsURLSession.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import OMGHTTPURLRQ
import PromiseKit

/**
 We need to use a URLSessionDelegate method or two that requires being a URLSessionDelegate. Since that means we can't use the completion block-based URLSessionTask methods, might as well wrap some promise-making and request-serializing functionality here too
 */
internal final class ForumsURLSession {
    private let baseURL: URL
    private let sessionDelegate = SessionDelegate()
    private let urlSession: URLSession

    init(baseURL: URL) {
        self.baseURL = baseURL

        let config: URLSessionConfiguration = {
            let config = URLSessionConfiguration.default
            var headers = config.httpAdditionalHeaders ?? [:]
            headers["User-Agent"] = OMGUserAgent()
            config.httpAdditionalHeaders = headers
            return config
        }()
        urlSession = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: sessionDelegate.queue)
    }

    deinit {
        urlSession.invalidateAndCancel()
    }

    var httpCookieStorage: HTTPCookieStorage? {
        return urlSession.configuration.httpCookieStorage
    }

    internal enum Method: String {
        case get = "GET"
        case post = "POST"
    }

    typealias WillRedirectCallback = (_ task: URLSessionTask, _ response: HTTPURLResponse, _ newRequest: URLRequest) -> URLRequest?

    typealias PromiseType = Promise<(data: Data, response: URLResponse)>

    internal func fetch(
        method: Method,
        urlString: String,
        parameters: [String: Any]?,
        redirectBlock: WillRedirectCallback? = nil)
        -> (promise: PromiseType, cancellable: Cancellable)
    {
        guard let url = URL(string: urlString, relativeTo: baseURL) else {
            return (Promise(error: ForumsClient.PromiseError.invalidBaseURL), Operation())
        }

        let parameters = parameters.map(win1252Escaped)

        let request: URLRequest
        do {
            switch method {
            case .get: request = try OMGHTTPURLRQ.get(url.absoluteString, parameters) as URLRequest
            case .post: request = try OMGHTTPURLRQ.post(url.absoluteString, parameters) as URLRequest
            }
        }
        catch {
            return (Promise(error: error), Operation())
        }

        let task: URLSessionDataTask = urlSession.dataTask(with: request)
        let promise = sessionDelegate.register(task, redirectBlock: redirectBlock)
        task.resume()
        return (promise: promise, cancellable: task)
    }
}

private class SessionDelegate: NSObject, URLSessionDataDelegate {
    let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "ForumsURLSession delegate"
        return queue
    }()

    private var incomingData: [Int: [Data]] = [:]
    private var promises: [Int: PromiseType.PendingTuple] = [:]
    private var redirectBlocks: [Int: ForumsURLSession.WillRedirectCallback] = [:]
    private var responses: [Int: URLResponse] = [:]

    typealias PromiseType = ForumsURLSession.PromiseType

    func register(_ task: URLSessionTask, redirectBlock: ForumsURLSession.WillRedirectCallback?) -> PromiseType {
        let pending = PromiseType.pending()

        queue.addOperation {
            self.promises[task.taskIdentifier] = pending

            if let block = redirectBlock {
                self.redirectBlocks[task.taskIdentifier] = block
            }
        }

        return pending.promise
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {

        let request: URLRequest?
        if let block = redirectBlocks[task.taskIdentifier] {
            request = block(task, response, newRequest)
        }
        else {
            request = newRequest
        }
        completionHandler(request)
    }

    func urlSession(_ session: URLSession, dataTask task: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        responses[task.taskIdentifier] = response
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask task: URLSessionDataTask, didReceive data: Data) {
        var components = incomingData[task.taskIdentifier] ?? []
        components.append(data)
        incomingData[task.taskIdentifier] = components
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {

        /*
         NSURLConnection will, absent relevant HTTP headers, cache responses for an unknown and unfortunately long time. I haven't checked but I'm guessing URLSession works the same.

         http://blackpixel.com/blog/2012/05/caching-and-nsurlconnection.html

         This came up when using Awful from some public wi-fi that redirected to a login page. Six hours and a different network later, the same login page was being served up from the cache.
         */

        let response: CachedURLResponse?
        if
            let request = dataTask.currentRequest,
            request.httpMethod?.uppercased() == "GET",
            request.cachePolicy == .useProtocolCachePolicy,
            let httpResponse = proposedResponse.response as? HTTPURLResponse,
            httpResponse.allHeaderFields["Cache-Control"] == nil,
            httpResponse.allHeaderFields["Expires"] == nil
        {
            print("\(#function) refusing to cache response to \(String(describing: request.url)) because its response has no cache headers")
            response = nil
        }
        else {
            response = proposedResponse
        }

        completionHandler(response)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let (promise, fulfill, reject) = promises.removeValue(forKey: task.taskIdentifier) else {
            fatalError("unexpected task")
        }

        defer { redirectBlocks.removeValue(forKey: task.taskIdentifier) }

        if let error = error {
            return reject(error)
        }

        guard let response = responses.removeValue(forKey: task.taskIdentifier) else {
            fatalError("expected a response for a successful task")
        }

        let dataComponents = incomingData.removeValue(forKey: task.taskIdentifier) ?? []
        let totalSize = dataComponents.map { $0.count }.reduce(0, +)
        var data = Data(capacity: totalSize)
        for component in dataComponents {
            data.append(component)
        }
        fulfill((data, response))
    }
}

/// Turns parameter values into strings, then turns everything in parameter key/values outside win1252 into HTML entities.
private func win1252Escaped(_ parameters: [String: Any]) -> [String: String] {
    func iswin1252(c: UnicodeScalar) -> Bool {
        // http://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WindowsBestFit/bestfit1252.txt
        switch c.value {
        case 0...0x7f, 0x81, 0x8d, 0x8f, 0x90, 0x9d, 0xa0...0xff, 0x152, 0x153, 0x160, 0x161, 0x178, 0x17d, 0x17e, 0x192, 0x2c6, 0x2dc, 0x2013, 0x2014, 0x2018...0x201a, 0x201c...0x201e, 0x2020...0x2022, 0x2026, 0x2030, 0x2039, 0x203a, 0x20ac, 0x2122:
            return true
        default:
            return false
        }
    }

    func escape(_ s: String) -> String {
        let scalars = s.unicodeScalars.flatMap { (c: UnicodeScalar) -> [UnicodeScalar] in
            if iswin1252(c: c) {
                return [c]
            } else {
                return Array("&#\(c.value);".unicodeScalars)
            }
        }
        return String(String.UnicodeScalarView(scalars))
    }

    var escapedParameters: [String: String] = [:]
    for (key, value) in parameters {
        escapedParameters[escape(key)] = escape("\(value)")
    }
    return escapedParameters
}
