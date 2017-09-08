//  RenderView.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit
import WebKit

private let Log = Logger.get(level: .debug)


/**
 Renders announcements, posts, and private messages.
 
 While it's probably pretty clear that `RenderView` uses a web view to do its work, that fact shouldn't leak out into its public interface. In theory, we should be able to switch to something else completely (e.g. TextKit (hold me)) without breaking any callers.
 */
final class RenderView: UIView {
    weak var delegate: RenderViewDelegate?
    var scrollView: UIScrollView { return webView.scrollView }

    fileprivate var registeredMessages: [RenderViewMessage.Type] = []

    fileprivate lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()

        for filename in ["Announcement.js", "RenderView.js"] {
            let jsURL = Bundle(for: RenderView.self).url(forResource: filename, withExtension: nil) !! "Please include \(filename)"
            let js = try! String(contentsOf: jsURL)
            let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            configuration.userContentController.addUserScript(userScript)
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
        return webView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        webView.frame = CGRect(origin: .zero, size: self.frame.size)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(webView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(html: String, baseURL: URL?) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    /**
     Scrolls past `fractionalOffset` of the render view's content size.

     `scrollToFractionalOffset(_:)` works whenever directly setting the scroll view's `contentOffset` works, but in addition it may work even when the scroll view's `contentSize` is zero.

     - Seealso: `UIScrollView.fractionalContentOffset`.
     */
    func scrollToFractionalOffset(_ fractionalOffset: CGPoint) {
        let js = "window.scrollTo(document.body.scrollWidth * \(fractionalOffset.x), "
            + "document.body.scrollHeight * \(fractionalOffset.y))"
        webView.evaluateJavaScript(js, completionHandler: { result, error in
            if let error = error {
                Log.e("error attempting to scroll: \(error)")
            }
        })
    }
}

extension RenderView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == .linkActivated
            || navigationAction.isAttemptingToHijackWebView
            || navigationAction.targetFrame == nil else
        {
            return decisionHandler(.allow)
        }

        guard let url = navigationAction.request.url else {
            return decisionHandler(.allow)
        }

        decisionHandler(.cancel)

        delegate?.didTapLink(to: url, in: self)
    }
}

/**
 A message that can be sent from the render view. Allows communication from the web view to the native side of the app.
 */
protocol RenderViewMessage {

    /// The name of the message. JavaScript can send this message by calling `window.webkit.messageHandlers.messageName.postMessage`, replacing `messageName` with the value returned here.
    static var messageName: String { get }

    /// - Returns: `nil` if the required message body couldn't be read in `message`.
    init?(_ message: WKScriptMessage)
}

extension RenderView: WKScriptMessageHandler {
    func registerMessage(_ messageType: RenderViewMessage.Type) {
        registeredMessages.append(messageType)

        webView.configuration.userContentController.add(ScriptMessageHandlerWeakTrampoline(self), name: messageType.messageName)
    }

    func unregisterMessage(_ messageType: RenderViewMessage.Type) {
        guard let i = registeredMessages.index(where: { $0 == messageType }) else {
            return
        }

        let messageType = registeredMessages.remove(at: i)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: messageType.messageName)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Log.d("received message from JavaScript: \(message.name)")

        let messageType = registeredMessages.first { $0.messageName == message.name }
        if let message = messageType?.init(message) {
            delegate?.didReceive(message: message, in: self)
        }
        else {
            Log.w("ignoring unexpected message from JavaScript: \(message.name). Did you forget to register a message type with the RenderView?")
        }
    }

    /**
     Messages that are already present in `RenderView.js` and immediately available to be registered in a `RenderView`. You can add your own messages by conforming to `RenderViewMessage` and registering your message type with `RenderView`.

     - Seealso: `RenderViewMessage`
     - Seealso: `RenderView.registerMessage(_:)`
     - Seealso: `RenderView.unregisterMessage(_:)`
     */
    enum BuiltInMessage {

        /// Sent from the web view once the document has more or less loaded (`DOMContentLoaded`).
        struct DidRender: RenderViewMessage {
            static let messageName = "didRender"

            init?(_ message: WKScriptMessage) {
                assert(message.name == DidRender.messageName)
            }
        }

        /// Sent from the web view when the user taps the header in a post.
        struct DidTapAuthorHeader: RenderViewMessage {
            static let messageName = "didTapAuthorHeader"

            /// The frame of the tapped header, in the render view's scroll view's coordinate system.
            let frame: CGRect

            /// The index of the tapped post, where `0` is the first post in the render view.
            let postIndex: Int

            init?(_ message: WKScriptMessage) {
                assert(message.name == DidTapAuthorHeader.messageName)

                guard
                    let body = message.body as? [String: Any],
                    let frame = body["frame"] as? [String: Double],
                    let x = frame["x"],
                    let y = frame["y"],
                    let width = frame["width"],
                    let height = frame["height"],
                    let postIndex = body["postIndex"] as? Int
                    else { return nil }

                self.frame = CGRect(x: x, y: y, width: width, height: height)
                self.postIndex = postIndex
            }
        }

        /// Sent from the web view when the user taps the ⋯ button in a post.
        struct DidTapPostActionButton: RenderViewMessage {
            static let messageName = "didTapPostActionButton"

            /// The frame of the tapped button, in the render view's scroll view's coordinate system.
            let frame: CGRect

            /// The index of the tapped post, where `0` is the first post in the render view.
            let postIndex: Int

            init?(_ message: WKScriptMessage) {
                assert(message.name == DidTapPostActionButton.messageName)

                guard
                    let body = message.body as? [String: Any],
                    let frame = body["frame"] as? [String: Double],
                    let x = frame["x"],
                    let y = frame["y"],
                    let width = frame["width"],
                    let height = frame["height"],
                    let postIndex = body["postIndex"] as? Int
                    else { return nil }

                self.frame = CGRect(x: x, y: y, width: width, height: height)
                self.postIndex = postIndex
            }
        }
    }
}

protocol RenderViewDelegate: class {
    func didReceive(message: RenderViewMessage, in view: RenderView)
    func didTapLink(to url: URL, in view: RenderView)
}
