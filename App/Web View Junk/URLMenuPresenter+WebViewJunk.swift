//  URLMenuPresenter.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

extension URLMenuPresenter {
    class func presentInterestingElements(_ info: [String: Any], fromViewController presentingViewController: UIViewController, fromWebView webView: UIWebView) -> Bool {
        var imageURL: URL? = nil
        if let imageURLString = info["spoiledImageURL"] as? String {
            imageURL = URL(string: imageURLString, relativeTo: ForumsClient.shared.baseURL)
        }
        
        if
            let linkInfo = info["spoiledLink"] as! [String: Any]?,
            let urlString = linkInfo["URL"] as? String,
            let baseURL = ForumsClient.shared.baseURL,
            let linkURL = URL(string: urlString, relativeTo: baseURL)
        {
            let presenter = URLMenuPresenter(linkURL: linkURL, imageURL: imageURL)
            let sourceRect = webView.rectForElementBoundingRect(linkInfo["rect"] as! String)
            presenter.present(fromViewController: presentingViewController, fromRect: sourceRect, inView: webView)
            return true
        }
        
        if let imageURL = imageURL {
            let preview = ImageViewController(imageURL: imageURL)
            preview.title = presentingViewController.title
            presentingViewController.present(preview, animated: true, completion: nil)
            return true
        }
        
        if
            let videoInfo = info["spoiledVideo"] as? [String: Any],
            let urlString = videoInfo["URL"] as? String,
            let videoURL = URL(string: urlString, relativeTo: ForumsClient.shared.baseURL),
            let rectString = videoInfo["rect"] as? String
        {
            let presenter = URLMenuPresenter(videoURL: videoURL)
            let sourceRect = webView.rectForElementBoundingRect(rectString)
            presenter.present(fromViewController: presentingViewController, fromRect: sourceRect, inView: webView)
            return true
        }
        
        return false
    }
}
