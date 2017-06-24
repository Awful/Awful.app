//  ForumsURLSession.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import OMGHTTPURLRQ
import PromiseKit

/**
 A promise-based interface to URLSession with block-based redirect handlers and win1252 request serialization.
 
 We need to use a URLSessionDelegate method or two that requires being a URLSessionDelegate. Since that means we can't use the completion block-based URLSessionTask methods, might as well wrap some promise-making and request-serializing functionality here too.
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
            case .get:
                request = try OMGHTTPURLRQ.get(url.absoluteString, parameters) as URLRequest

            case .post:
                var mutableRequest = URLRequest(url: url)
                mutableRequest.httpMethod = "POST"
                try mutableRequest.setMultipartFormData(parameters ?? [:], encoding: .windowsCP1252)
                request = mutableRequest
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

private struct EncodingError: Error {
    let what: String
}

private extension URLRequest {

    /**
     Configures the URL request for `multipart/form-data`. The request's `httpBody` is set, and a value is set for the HTTP header field `Content-Type`.
     
     - Parameter parameters: The form data to set.
     - Parameter encoding: The encoding to use for the keys and values.
     
     - Throws: `EncodingError` if any keys or values in `parameters` are not entirely in `encoding`.
     
     - Note: The default `httpMethod` is `GET`, and `GET` requests do not typically have a response body. Remember to set the `httpMethod` to e.g. `POST` before sending the request.
     */
    mutating func setMultipartFormData(_ parameters: [String: String], encoding: String.Encoding) throws {
        let boundary = String(format: "------------------------%08X%08X", arc4random(), arc4random())

        let contentType: String = try {
            guard let charset = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(encoding.rawValue)) else {
                throw EncodingError(what: "charset")
            }
            return "multipart/form-data; charset=\(charset); boundary=\(boundary)"
        }()
        addValue(contentType, forHTTPHeaderField: "Content-Type")

        httpBody = try {
            var body = Data()

            for (rawName, rawValue) in parameters {
                if !body.isEmpty {
                    body.append("\r\n".data(using: .utf8)!)
                }

                body.append("--\(boundary)\r\n".data(using: .utf8)!)

                guard
                    rawName.canBeConverted(to: encoding),
                    let disposition = "Content-Disposition: form-data; name=\"\(rawName)\"\r\n".data(using: .utf8) else {
                    throw EncodingError(what: "name")
                }
                body.append(disposition)

                body.append("\r\n".data(using: .utf8)!)

                guard let value = rawValue.data(using: encoding) else {
                    throw EncodingError(what: "value")
                }

                body.append(value)
            }

            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

            return body
        }()
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
