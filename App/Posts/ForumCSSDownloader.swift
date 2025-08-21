//  ForumCSSDownloader.swift
//
//  Copyright 2025 Awful Contributors.

import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ForumCSSDownloader")

/// Represents background images extracted from forum CSS
struct ForumBackgrounds {
    let mainBackground: String?
    let bottomBackground: String?
    
    var hasAnyBackground: Bool {
        return mainBackground != nil || bottomBackground != nil
    }
}

/// Downloads and caches forum-specific CSS files from i.somethingawful.com to extract background images
final class ForumCSSDownloader: @unchecked Sendable {
    
    static let shared = ForumCSSDownloader()
    
    private let urlSession: URLSession
    private var cssCache: [String: String] = [:]
    private var failedForums: Set<String> = []
    private let cacheQueue = DispatchQueue(label: "com.awful.css-cache", attributes: .concurrent)
    
    private init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 10
        self.urlSession = URLSession(configuration: config)
    }
    
    /// Downloads CSS for the specified forum ID and extracts background images
    /// - Parameter forumID: The forum ID to download CSS for
    /// - Returns: ForumBackgrounds containing main and bottom background URLs
    func getForumBackgrounds(forumID: String) async -> ForumBackgrounds {
        logger.debug("Attempting to get background image for forum \(forumID)")
        
        // Check if we already know this forum has no CSS
        if await isForumKnownToHaveNoCSS(forumID: forumID) {
            logger.debug("Forum \(forumID) is known to have no CSS")
            return ForumBackgrounds(mainBackground: nil, bottomBackground: nil)
        }
        
        // Check cache first
        if let cachedCSS = await getCachedCSS(forumID: forumID) {
            logger.debug("Using cached CSS for forum \(forumID)")
            return extractBackgroundImages(from: cachedCSS)
        }
        
        // Download CSS
        guard let css = await downloadCSS(forumID: forumID) else {
            await markForumAsHavingNoCSS(forumID: forumID)
            return ForumBackgrounds(mainBackground: nil, bottomBackground: nil)
        }
        
        // Cache the result
        await cacheCSS(forumID: forumID, css: css)
        
        // Extract and return background images
        return extractBackgroundImages(from: css)
    }
    
    private func downloadCSS(forumID: String) async -> String? {
        // Special case for impzone forum which uses a different filename
        let cssFileName = (forumID == "267") ? "impzone.css" : "\(forumID).css"
        let cssURL = "https://i.somethingawful.com/css/\(cssFileName)"
        logger.debug("Downloading CSS from \(cssURL)")
        
        guard let url = URL(string: cssURL) else {
            logger.error("Invalid CSS URL: \(cssURL)")
            return nil
        }
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("CSS download response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    logger.debug("Forum \(forumID) has no CSS file (404)")
                    return nil
                }
                
                if httpResponse.statusCode != 200 {
                    logger.warning("Unexpected status code \(httpResponse.statusCode) for forum \(forumID)")
                    return nil
                }
            }
            
            let cssString = String(data: data, encoding: .utf8)
            logger.debug("Successfully downloaded \(data.count) bytes of CSS for forum \(forumID)")
            return cssString
            
        } catch {
            logger.error("Failed to download CSS for forum \(forumID): \(error)")
            return nil
        }
    }
    
    private func extractBackgroundImages(from css: String) -> ForumBackgrounds {
        logger.debug("Extracting background images from CSS (\(css.count) characters)")
        
        let bodyBackground = extractBackgroundFromSelector(css: css, selector: "body")
        let containerBackground = extractBackgroundFromSelector(css: css, selector: "#container")
        
        // If only one background is found, use it as the main background
        // Only use dual backgrounds when BOTH are found
        let mainBackground: String?
        let bottomBackground: String?
        
        if bodyBackground != nil && containerBackground != nil {
            // Both found - use body as main, container as bottom (impzone case)
            mainBackground = bodyBackground
            bottomBackground = containerBackground
        } else if let singleBackground = bodyBackground ?? containerBackground {
            // Only one found - use it as the main background (CSPAM case)
            mainBackground = singleBackground
            bottomBackground = nil
        } else {
            // None found
            mainBackground = nil
            bottomBackground = nil
        }
        
        logger.debug("Found main background: \(mainBackground ?? "none"), bottom background: \(bottomBackground ?? "none")")
        
        // Debug: log a snippet of the CSS to help troubleshoot
        if css.count > 0 {
            let snippet = String(css.prefix(500))
            logger.debug("CSS snippet: \(snippet)")
        }
        
        return ForumBackgrounds(mainBackground: mainBackground, bottomBackground: bottomBackground)
    }
    
    /// Backward compatibility method for single background extraction
    /// - Parameter forumID: The forum ID to download CSS for
    /// - Returns: Main background image URL string if found, nil otherwise
    func getForumBackgroundImage(forumID: String) async -> String? {
        let backgrounds = await getForumBackgrounds(forumID: forumID)
        return backgrounds.mainBackground
    }
    
    private func extractBackgroundFromSelector(css: String, selector: String) -> String? {
        // Look for background declarations in the specified selector
        // Handle body selector (no #) vs ID selectors (with #)
        let selectorPattern = selector.hasPrefix("#") ? "\\#" + selector.dropFirst() : selector
        
        logger.debug("Looking for selector: \(selector), pattern will be: \(selectorPattern)")
        
        let patterns = [
            // Pattern 1: selector { background-image: url(...) } - handles newlines
            #"(SELECTOR)\s*\{[^}]*background-image\s*:\s*url\s*\(\s*['""]?([^'"")\s!]+)['""]?\s*\)"#,
            // Pattern 2: selector { background: ... url(...) } - handles newlines  
            #"(SELECTOR)\s*\{[^}]*background\s*:[^}]*url\s*\(\s*['""]?([^'"")\s!]+)['""]?\s*\)"#
        ]
        
        for (index, patternTemplate) in patterns.enumerated() {
            let pattern = patternTemplate.replacingOccurrences(of: "(SELECTOR)", with: selectorPattern)
            logger.debug("Trying pattern \(index): \(pattern)")
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: css, options: [], range: NSRange(css.startIndex..., in: css)),
               let urlRange = Range(match.range(at: 1), in: css) {
                
                var imageURL = String(css[urlRange])
                logger.debug("Found \(selector) background image URL: \(imageURL)")
                
                // Convert relative URLs to absolute URLs
                if !imageURL.hasPrefix("http") {
                    // Handle protocol-relative URLs (//domain.com/image.jpg)
                    if imageURL.hasPrefix("//") {
                        imageURL = "https:" + imageURL
                    } else if imageURL.hasPrefix("/") {
                        imageURL = "https://i.somethingawful.com" + imageURL
                    } else {
                        imageURL = "https://i.somethingawful.com/" + imageURL
                    }
                    logger.debug("Converted to absolute URL: \(imageURL)")
                }
                
                return imageURL
            }
        }
        
        logger.debug("No match found for selector: \(selector)")
        return nil
    }
    
    // MARK: - Cache management methods
    
    private func getCachedCSS(forumID: String) async -> String? {
        return await withCheckedContinuation { continuation in
            cacheQueue.async {
                continuation.resume(returning: self.cssCache[forumID])
            }
        }
    }
    
    private func cacheCSS(forumID: String, css: String) async {
        await withCheckedContinuation { continuation in
            cacheQueue.async(flags: .barrier) {
                self.cssCache[forumID] = css
                continuation.resume()
            }
        }
    }
    
    private func isForumKnownToHaveNoCSS(forumID: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            cacheQueue.async {
                continuation.resume(returning: self.failedForums.contains(forumID))
            }
        }
    }
    
    private func markForumAsHavingNoCSS(forumID: String) async {
        await withCheckedContinuation { continuation in
            cacheQueue.async(flags: .barrier) {
                self.failedForums.insert(forumID)
                continuation.resume()
            }
        }
    }
    
    /// Clears all cached CSS data (useful for testing or memory pressure)
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cssCache.removeAll()
            self.failedForums.removeAll()
        }
    }
}
