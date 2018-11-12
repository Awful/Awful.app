//  RenderView.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import PromiseKit
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
        
        if #available(iOS 11.0, *) {
            configuration.setURLSchemeHandler(ImageURLProtocol(), forURLScheme: ImageURLProtocol.scheme)
            configuration.setURLSchemeHandler(ResourceURLProtocol(), forURLScheme: ResourceURLProtocol.scheme)
        } else {
            registerURLProtocolsForWKWebView_iOS10AndBelow()
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.navigationDelegate = self
        webView.scrollView.backgroundColor = nil
        webView.scrollView.decelerationRate = .normal
        return webView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        webView.frame = CGRect(origin: .zero, size: self.bounds.size)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(webView)

        activityIndicatorManager = .init(webView: webView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /**
     Load HTML into the render view.
     
     - Parameter baseURL: The base URL of the document. Note that any `https` base URL is forcibly downgraded to be an `http` URL. See **Warning** for more info.
     
     - Warning: If an `https` `baseURL` is provided, it will be forcibly downgraded to an `http` URL. (`WKWebView` refuses to load from custom URL schemes, calling it "insecure content".) If you would like relative URLs to be resolved against an `https` URL, consider adding a `<base>` element.
     */
    func render(html: String, baseURL: URL?) {
        webView.loadHTMLString(html, baseURL: baseURL?.downgradedToInsecureHTTP())
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

/**
 Makes the URL protocols we use for rendering available in all instances of `WKWebView`. This function uses private API and should only be called on iOS 10 and below, where no equivalent public API is available.
 
 This function only needs to be called once, though it's safe to call it many times. The schemes are added only once; as we're touching private API, it seems prudent not to prod more than necessary.
 
 (This is a property holding a closure, instead of just a function, so we can call it like a function but enforce our "only add once" requirement.)
 
 - Note: `WKWebView` gained public API for using custom URL protocols in iOS 11. You should use `WKWebViewConfiguration.setURLSchemeHandler(…)` when it's available.
 */
private let registerURLProtocolsForWKWebView_iOS10AndBelow: () -> Void = {
    
    // We only want to register these schemes once, so we do that here when this top-level property lazily initializes.
    let schemes = [ImageURLProtocol.scheme, ResourceURLProtocol.scheme]
    for scheme in schemes {
        WKWebView.registerCustomURLScheme(scheme)
    }
    
    // After initialzation, and on all subsequent calls, we simply run an empty closure; our work here is done.
    return {}
}()

private extension URL {
    /// Returns an `http` version of this URL if it's an `https` URL; otherwise just returns `self`.
    func downgradedToInsecureHTTP() -> URL {
        guard
            let scheme = scheme,
            scheme.caseInsensitive == "https",
            var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
            else { return self }
        
        components.scheme = "http"
        return components.url!
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
        
        guard nearestViewController?.presentedViewController == nil else {
            Log.i("ignoring link tap as we're currently presenting something")
            return
        }

        delegate?.didTapLink(to: url, in: self)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        delegate?.didFinishRenderingHTML(in: self)
    }
}

// MARK: - Receiving messages from the render view

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
        
        /// Sent from the web view after any embedded tweets have loaded.
        struct DidFinishLoadingTweets: RenderViewMessage {
            static let messageName = "didFinishLoadingTweets"
            
            init?(_ message: WKScriptMessage) {
                assert(message.name == DidFinishLoadingTweets.messageName)
            }
        }

        /// Sent from the web view when the user taps the header in a post.
        struct DidTapAuthorHeader: RenderViewMessage {
            static let messageName = "didTapAuthorHeader"

            /// The frame of the tapped header, in the render view's coordinate system.
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

            /// The frame of the tapped button, in the render view's coordinate system.
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

// MARK: - Bossing around and retrieving information from the render view

extension RenderView {
    
    /// Turns any links that look like tweets into an actual tweet embed.
    func embedTweets() {
        webView.evaluateJavaScript("if (window.Awful) Awful.embedTweets()") { rawResult, error in
            if let error = error {
                Log.w("could not evaluate embedTweets: \(error)")
            }
        }
    }
    
    /// Removes all previously-loaded content.
    func eraseDocument() {
        // There's a bit of subtlety here. If we eval `document.open()`, we get console errors because we can't bring the document object back into the native-side of the app. And if we don't include a `<body>`, we can get console logs attempting to retrieve `document.body.scrollWidth`.
        webView.evaluateJavaScript("document.write('<body>')") { result, error in
            if let error = error {
                Log.e("could not remove content: \(error)")
            }
        }
    }
    
    /// - Seealso: RenderView.interestingElements(at:)
    enum InterestingElement {
        
        case spoiledImage(URL)
        
        /// - Parameter frame: The link element's frame expressed in the render view's coordinate system.
        case spoiledLink(frame: CGRect, url: URL)
        
        /// - Parameter frame: The link element's frame expressed in the render view's coordinate system.
        case spoiledVideo(frame: CGRect, url: URL)
        
        case unspoiledLink
    }
    
    /**
     Returns the promise of interesting elements in the render view.
     
     Interesting elements may include:
     
     * A link (spoiled or unspoiled).
     * An image (spoiled).
     * A video (spoiled).
     
      If something goes wrong during communication with the web view, an empty array is returned and a warning is logged. Any potential errors are internal to the RenderView and you would have no recourse, so we don't bother reporting them via a `Promise`.
     
     - Parameter point: The point of curiosity, expressed in the render view's coordinate system.
     - Returns: A guaranteed (though possibly empty) array of interesting elements.
     */
    func interestingElements(at point: CGPoint) -> Guarantee<[InterestingElement]> {
        let (guarantee, resolver) = Guarantee<[InterestingElement]>.pending()
        
        webView.evaluateJavaScript("if (window.Awful) Awful.interestingElementsAtPoint(\(point.x), \(point.y))") { rawResult, error in
            if let error = error {
                Log.w("could not evaluate interestingElementsAtPoint: \(error)")
                return resolver([])
            }
            
            guard let result = rawResult as? [String: Any] else {
                Log.w("expected interestingElementsAtPoint to return a dictionary but got \(rawResult as Any)")
                return resolver([])
            }
            
            var interesting: [InterestingElement] = []
            
            if let hasUnspoiledLink = result["hasUnspoiledLink"] as? Bool, hasUnspoiledLink {
                interesting.append(.unspoiledLink)
            }
            
            if
                let rawImageURL = result["spoiledImageURL"] as? String,
                let imageURL = URL(string: rawImageURL)
            {
                interesting.append(.spoiledImage(imageURL))
            }
            
            if
                let linkInfo = result["spoiledLink"] as? [String: Any],
                let rawFrame = linkInfo["frame"] as? [String: Double],
                let frame = CGRect(renderViewMessage: rawFrame),
                let rawURL = linkInfo["url"] as? String,
                let url = URL(string: rawURL)
            {
                interesting.append(.spoiledLink(frame: frame, url: url))
            }
            
            if
                let videoInfo = result["spoiledVideo"] as? [String: Any],
                let rawFrame = videoInfo["frame"] as? [String: Double],
                let frame = CGRect(renderViewMessage: rawFrame),
                let rawURL = videoInfo["url"] as? String,
                let url = URL(string: rawURL)
            {
                interesting.append(.spoiledVideo(frame: frame, url: url))
            }
            
            resolver(interesting)
        }
        
        return guarantee
    }
    
    /// Scrolls so the identified post begins at the top of the viewport.
    func jumpToPost(identifiedBy postID: String) {
        let escapedPostID: String
        do {
            escapedPostID = try escapeForEval(postID)
        } catch {
            Log.w("could not JSON-escape the post ID: \(error)")
            return
        }
        webView.evaluateJavaScript("if (window.Awful) Awful.jumpToPostWithID(\(escapedPostID))") { rawResult, error in
            if let error = error {
                Log.w("could not evaluate jumpToPostWithID: \(error)")
            }
        }
    }
    
    /// Turns each link with a `data-awful-linkified-image` attribute into a a proper `img` element.
    func loadLinkifiedImages() {
        webView.evaluateJavaScript("if (window.Awful) Awful.loadLinkifiedImages()") { rawResult, error in
            if let error = error {
                Log.w("could not evaluate loadLinkifiedImages: \(error)")
            }
        }
    }
    
    /// Sets the identified post, and all previous posts, to appear read; and sets all subsequent posts to appear unread.
    func markReadUpToPost(identifiedBy postID: String) {
        let escaped: String
        do {
            escaped = try escapeForEval(postID)
        } catch {
            Log.w("could not JSON-escape the post ID: \(error)")
            return
        }
        
        webView.evaluateJavaScript("if (window.Awful) Awful.markReadUpToPostWithID(\(escaped))") { rawResult, error in
            if let error = error {
                Log.w("could not evaluate markReadUpToPostWithID: \(error)")
            }
        }
    }
    
    /// Insert some newly-rendered posts above all existing rendered posts.
    func prependPostHTML(_ postHTML: String) {
        let escaped: String
        do {
            escaped = try escapeForEval(postHTML)
        } catch {
            Log.w("could not JSON-escape the post HTML: \(error)")
            return
        }
        
        webView.evaluateJavaScript("if (window.Awful) Awful.prependPosts(\(escaped))") { rawResult, error in
            if let error = error {
                Log.w("could not evaluate prependPosts: \(error)")
            }
        }
    }
    
    /// Replaces an existing post with a new rendering (e.g. after loading the contents of an ignored post).
    func replacePostHTML(_ postHTML: String, at i: Int) {
        let escaped: String
        do {
            escaped = try escapeForEval(postHTML)
        } catch {
            Log.w("could not JSON-escape the post HTML: \(error)")
            return
        }
        
        webView.evaluateJavaScript("if (window.Awful) Awful.setPostHTMLAtIndex(\(escaped), \(i))") { rawResult, error in
            if let error = error {
                Log.w("could not evaluate setPostHTMLAtIndex: \(error)")
            }
        }
    }
    
    /// Replaces the "external" CSS, which is hosted somewhere and can be changed without a full-on app update.
    func setExternalStylesheet(_ css: String) {
        let escaped: String
        do {
            escaped = try escapeForEval(css)
        } catch {
            Log.w("could not JSON-escape the CSS: \(error)")
            return
        }
        
        webView.evaluateJavaScript("if (window.Awful) Awful.setExternalStylesheet(\(escaped))") { rawResult, error in
            if let error = error {
                Log.w("could not evaluate setExternalStylesheet: \(error)")
            }
        }
    }
    
    /// Sets the font scale to the specified number of percentage points. e.g. for `font-scale: 50%` you would pass in `50`.
    func setFontScale(_ scale: Double) {
        webView.evaluateJavaScript("if (window.Awful) Awful.setFontScale(\(scale))") { rawResult, error in
            if let error = error {
                Log.w("could not evaluate setFontScale: \(error)")
            }
        }
    }
    
    func setFYADFlag(_ flag: FlagInfo?) {
        let escaped: String
        do {
            if let flag = flag {
                let data = try JSONEncoder().encode(flag)
                escaped = String(data: data, encoding: .utf8)!
            } else {
                escaped = "{}"
            }
        } catch {
            Log.w("could not JSON-escape the flag: \(error)")
            return
        }
        
        webView.evaluateJavaScript("if (window.Awful) Awful.fyadFlag.setFlag(\(escaped))") { rawResult, error in
            if let error = error {
                Log.w("could not evaluate setFYADFlag: \(error)")
            }
        }
    }
    
    struct FlagInfo: Encodable {
        let src: URL
        let title: String
    }
    
    /// Toggles the `highlight` class in all username mentions in post bodies, adding it when `true` or removing it when `false`.
    func setHighlightMentions(_ highlightMentions: Bool) {
        webView.evaluateJavaScript("if (window.Awful) Awful.setHighlightMentions(\(highlightMentions ? "true" : "false"))") { rawResult, error in
            if let error = error {
                Log.w("could not evaluate setHighlightMentions: \(error)")
            }
        }
    }
    
    /// Turns all avatars on (when `true`) or off (when `false`).
    func setShowAvatars(_ showAvatars: Bool) {
        webView.evaluateJavaScript("if (window.Awful) Awful.setShowAvatars(\(showAvatars ? "true" : "false"))") { rawResult, error in
            if let error = error {
                Log.w("could not evaluate setShowAvatars: \(error)")
            }
        }
    }
    
    /// Replaces the theme CSS.
    func setThemeStylesheet(_ css: String) {
        let escaped: String
        do {
            escaped = try escapeForEval(css)
        } catch {
            Log.w("could not JSON-escape the CSS: \(error)")
            return
        }
        
        webView.evaluateJavaScript("if (window.Awful) Awful.setThemeStylesheet(\(escaped))") { rawResult, error in
            if let error = error {
                Log.w("could not evaluate setThemeStylesheet: \(error)")
            }
        }
    }
    
    /**
     Returns a frame in the render view's coordinate system that encompasses the frames of all elements matching the selector.
     
     - Returns: A frame encompassing all elements matching the selector; or `CGRect.null` if there are no matching elements; or `CGRect.null` if there is an error.
     */
    func unionFrameOfElements(matchingSelector selector: String) -> Guarantee<CGRect> {
        let escapedSelector: String
        do {
            escapedSelector = try escapeForEval(selector)
        } catch {
            Log.w("could not JSON-encode selector \(selector): \(error)")
            return .value(.null)
        }
        
        let (guarantee, resolver) = Guarantee<CGRect>.pending()
        
        let js = """
            Awful.unionFrameOfElements(
                document.querySelectorAll(\(escapedSelector)));
            """
        webView.evaluateJavaScript(js) { rawResult, error in
            if let error = error {
                Log.w("could not evaluate unionFrameOfElements: \(error)")
                return resolver(.null)
            }
            
            guard let rect = CGRect(renderViewMessage: rawResult as? [String: Double]) else {
                Log.w("expected unionFrameOfElements to return a rect via dictionary but got \(rawResult as Any)")
                return resolver(.null)
            }
            
            resolver(rect)
        }
        
        return guarantee
    }
}

protocol RenderViewDelegate: class {
    func didFinishRenderingHTML(in view: RenderView)
    func didReceive(message: RenderViewMessage, in view: RenderView)
    func didTapLink(to url: URL, in view: RenderView)
}

private func escapeForEval(_ s: String) throws -> String {
    return String(data: try JSONEncoder().encode([s]), encoding: .utf8)! + "[0]"
}
