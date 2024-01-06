//  WKWebView+eval.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import WebKit

extension WKWebView {
    /**
     Evaluates the specified JavaScript string.

     The async-await version of `evaluateJavaScript(_:)` in the overlay assumes a non-`nil` result of evaluating `javaScript`. This async-await version does not make that assumption.
     */
    @discardableResult
    func eval(_ javaScript: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(javaScript, completionHandler: { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            })
        }
    }
}
