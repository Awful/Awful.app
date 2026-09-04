//  CachebustingSessionDelegate.swift
//
//  Copyright 2023 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import os

/// Changes the default caching policy for HTTP responses that have no cache headers to "do not cache".
final class CachebustingSessionDelegate: NSObject, URLSessionDataDelegate {

#if DEBUG
    /// Tasks with their own delegate (see `URLSession.data(for:willRedirect:)`) report metrics there instead.
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        logRequestMetrics(task: task, metrics: metrics)
    }
#endif
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        willCacheResponse proposedResponse: CachedURLResponse
    ) async -> CachedURLResponse? {
        /*
         NSURLConnection will, absent relevant HTTP headers, cache responses for an unknown and unfortunately long time. I haven't checked but I'm guessing URLSession works the same.

         http://blackpixel.com/blog/2012/05/caching-and-nsurlconnection.html

         This came up when using Awful from some public wi-fi that redirected to a login page. Six hours and a different network later, the same login page was being served up from the cache.
         */
        if let request = dataTask.currentRequest,
           request.httpMethod?.uppercased() == "GET",
           request.cachePolicy == .useProtocolCachePolicy,
           let httpResponse = proposedResponse.response as? HTTPURLResponse,
           case let headers = httpResponse.allHeaderFields,
           headers["Cache-Control"] == nil,
           headers["Expires"] == nil
        {
            return nil
        }
        
        return proposedResponse
    }
}

#if DEBUG
private let metricsLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "RequestMetrics")

/// Logs how long a request spent queued/connecting versus transferring, and which HTTP version
/// carried it, so contention between page requests and attachment downloads is visible in Console.
func logRequestMetrics(task: URLSessionTask, metrics: URLSessionTaskMetrics) {
    guard let url = task.originalRequest?.url else { return }
    let path = url.path.isEmpty ? url.absoluteString : url.path
    let total = metrics.taskInterval.duration * 1000
    guard let transaction = metrics.transactionMetrics.last else {
        metricsLogger.debug("\(path): \(total, format: .fixed(precision: 0)) ms total, no transaction metrics")
        return
    }
    func ms(_ from: Date?, _ to: Date?) -> String {
        guard let from, let to else { return "?" }
        return String(format: "%.0f", to.timeIntervalSince(from) * 1000)
    }
    let queued = ms(metrics.taskInterval.start, transaction.fetchStartDate)
    let connecting = ms(transaction.fetchStartDate, transaction.requestStartDate)
    let waiting = ms(transaction.requestEndDate, transaction.responseStartDate)
    let transfer = ms(transaction.responseStartDate, transaction.responseEndDate)
    let protocolName = transaction.networkProtocolName ?? "?"
    metricsLogger.debug("\(path): \(total, format: .fixed(precision: 0)) ms total; queued \(queued), connect \(connecting), server \(waiting), transfer \(transfer) ms; \(protocolName); reused connection: \(transaction.isReusedConnection)")
}
#endif
