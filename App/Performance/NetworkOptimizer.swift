import UIKit
import WebKit

/// Optimizes network operations to prevent main thread blocking during WebView loading
/// Addresses the 3+ second hangs seen during post loading operations
final class NetworkOptimizer {
    static let shared = NetworkOptimizer()
    
    private let networkQueue = DispatchQueue(
        label: "com.awful.network-optimizer",
        qos: .userInitiated,
        attributes: .concurrent
    )
    
    private init() {}
    
    /// Preload WebView process to avoid 1.2+ second launch delays
    static func preloadWebViewProcess() {
        // WebView MUST be created on main thread
        DispatchQueue.main.async {
            // Create a minimal WebView to initialize the WebContent process
            // Note: WKProcessPool is deprecated in iOS 15.0+, system manages process pools automatically
            let config = WKWebViewConfiguration()
            
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
            webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
            
            // Keep reference briefly to ensure process starts, then release
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                _ = webView // Release reference after process is initialized
            }
        }
    }
    
    /// Optimize URLSession configuration for faster requests
    static func optimizedURLSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        
        // Reduce timeouts for faster failure detection
        config.timeoutIntervalForRequest = 15.0 // Down from 60s default
        config.timeoutIntervalForResource = 30.0 // Down from 7 days default
        
        // Optimize connection reuse
        config.httpMaximumConnectionsPerHost = 4
        config.httpShouldUsePipelining = true
        config.httpShouldSetCookies = true
        
        // Enable compression
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        return config
    }
    
    /// Defer heavy operations to prevent main thread blocking
    func deferHeavyOperation<T>(_ operation: @escaping () throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            networkQueue.async {
                do {
                    let result = try operation()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Optimize image loading to prevent UI blocking
    func optimizeImageLoading(for webView: WKWebView) {
        // Inject JavaScript to defer image loading until after initial render
        let script = """
        document.addEventListener('DOMContentLoaded', function() {
            const images = document.querySelectorAll('img[data-src]');
            const imageObserver = new IntersectionObserver((entries, observer) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        const img = entry.target;
                        img.src = img.dataset.src;
                        img.removeAttribute('data-src');
                        imageObserver.unobserve(img);
                    }
                });
            });
            
            images.forEach(img => imageObserver.observe(img));
        });
        """
        
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        
        webView.configuration.userContentController.addUserScript(userScript)
    }
}

/// UIApplication extension to preload WebView process at app launch
extension UIApplication {
    func preloadWebViewProcess() {
        NetworkOptimizer.preloadWebViewProcess()
    }
}