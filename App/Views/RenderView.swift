//  RenderView.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit
import WebKit

private let Log = Logger.get()

/**
 Renders announcements, posts, profiles, and private messages.
 
 The bundled file `RenderView.js` is automatically included in all rendered HTML documents. There are handy, type-safe methods for receiving messages from the document's JavaScript. The network activity indicator is handled for you. It's all here.
 
 While it's probably pretty clear that `RenderView` uses a web view to do its work, that fact shouldn't leak out into its public interface. In theory, we should be able to switch to something else completely (e.g. TextKit (hold me)) without breaking any callers.
 */
final class RenderView: UIView {
    
    private var activityIndicatorManager: WebViewActivityIndicatorManager?
    weak var delegate: RenderViewDelegate?
    
    var scrollView: UIScrollView { return webView.scrollView }

    private var registeredMessages: [String: RenderViewMessage.Type] = [:]

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        let jsURL = Bundle(for: RenderView.self).url(forResource: "RenderView.js", withExtension: nil)!
        let js = try! String(contentsOf: jsURL)
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.scrollView.decelerationRate = UIScrollView.DecelerationRate.normal
        return webView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        webView.frame = CGRect(origin: .zero, size: self.frame.size)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(webView)

        activityIndicatorManager = .init(webView: webView)
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
        webView.evaluateJavaScript("""
            window.scrollTo(
                document.body.scrollWidth * \(fractionalOffset.x),
                document.body.scrollHeight * \(fractionalOffset.y));
            """, completionHandler: { result, error in
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
        registeredMessages[messageType.messageName] = messageType

        webView.configuration.userContentController.add(ScriptMessageHandlerWeakTrampoline(self), name: messageType.messageName)
    }

    func unregisterMessage(_ messageType: RenderViewMessage.Type) {
        if registeredMessages.removeValue(forKey: messageType.messageName) != nil {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: messageType.messageName)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive rawMessage: WKScriptMessage) {
        Log.d("received message from JavaScript: \(rawMessage.name)")

        guard let messageType = registeredMessages[rawMessage.name] else {
            Log.w("ignoring unexpected message from JavaScript: \(rawMessage.name). Did you forget to register a message type with the RenderView?")
            return
        }
        
        guard let message = messageType.init(rawMessage) else {
            Log.w("could not deserialize \(messageType) (registered as \(rawMessage.name)) from JavaScript. Does the initializer look right?")
            return
        }
        
        delegate?.didReceive(message: message, in: self)
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
                    let frame = CGRect(renderViewMessage: body["frame"] as? [String: Double]),
                    let postIndex = body["postIndex"] as? Int
                    else { return nil }

                self.frame = frame
                self.postIndex = postIndex
            }
        }
    }
}

extension CGRect {
    init?(renderViewMessage body: [String: Double]?) {
        guard
            let x = body?["x"],
            let y = body?["y"],
            let width = body?["width"],
            let height = body?["height"]
            else { return nil }
        
        self.init(x: x, y: y, width: width, height: height)
    }
}

protocol RenderViewDelegate: class {
    func didReceive(message: RenderViewMessage, in view: RenderView)
    func didTapLink(to url: URL, in view: RenderView)
}
