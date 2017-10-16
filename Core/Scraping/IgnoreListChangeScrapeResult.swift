//  IgnoreListChangeScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import HTMLReader

/**
 Scrapes the page shown after submitting the ignore list form.
 
 This is the page that usually redirects you back to the user control panel after submitting the ignore list.
 */
public enum IgnoreListChangeScrapeResult: ScrapeResult {
    
    /// The ignore list changed successfully.
    case success
    
    /// The ignore list could not be changed, probably because at least one user in the list is a moderator or admin and thus cannot be ignored. If known, this username is available as `rejectedUsername`.
    case failure(error: StandardErrorScrapeResult, rejectedUsername: String?)
    
    /// Neither the success page nor the standard error page appeared. Probably safe to assume failure here.
    case unknown(Error)
    
    
    // MARK: ScrapeResult
    
    public init(_ html: HTMLNode, url: URL?) throws {
        if let error = try? StandardErrorScrapeResult(html, url: url) {
            let username = { () -> String? in
                let scanner = Scanner.makeForScraping(error.message)
                guard scanner.scanUpToAndPast("Sorry ") else { return nil }
                
                // We want to test enough of the string after the username to avoid some silly goose adding e.g. "is a mod" to their username then becoming a mod, which would be confusing. But the longer we go, the more we tempt fate when some well-meaning soul edits the copy in the error message. This seems to be just beyond the character limit for a name, hopefully it's ok.
                return scanner.scanUpTo(" is a moderator/admin and you")
            }()
            
            self = .failure(error: error, rejectedUsername: username)
        }
        else {
            do {
                let inner = try html.requiredNode(matchingSelector: "div.inner")
                if inner.textContent.contains("Your ignore list has been updated") {
                    self = .success
                }
                else {
                    throw ScrapingError.missingExpectedElement("div.inner:text('Your ignore list has been updated')")
                }
            }
            catch {
                self = .unknown(error)
            }
        }
    }
}
