//  URLMenuPresenter.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

extension URLMenuPresenter {
    class func presentInterestingElements(info: [String: AnyObject], fromViewController presentingViewController: UIViewController, fromWebView webView: UIWebView) -> Bool {
        var imageURL: NSURL? = nil
        if let imageURLString = info["spoiledImageURL"] as! String? {
            imageURL = NSURL(string: imageURLString, relativeToURL: AwfulForumsClient.sharedClient().baseURL)
        }
        
        if let linkInfo = info["spoiledLink"] as! [String: AnyObject]? {
            let linkURL = NSURL(string: linkInfo["URL"] as! String, relativeToURL: AwfulForumsClient.sharedClient().baseURL)!
            let presenter = URLMenuPresenter(linkURL: linkURL, imageURL: imageURL)
            let sourceRect = webView.rectForElementBoundingRect(linkInfo["rect"] as! String)
            presenter.present(fromViewController: presentingViewController, fromRect: sourceRect, inView: webView)
            return true
        }
        
        if let imageURL = imageURL {
            let preview = ImageViewController(imageURL: imageURL)
            preview.title = presentingViewController.title
            presentingViewController.presentViewController(preview, animated: true, completion: nil)
            return true
        }
        
        if let videoInfo = info["spoiledVideo"] as! [String: AnyObject]? {
            let videoURL = NSURL(string: videoInfo["URL"] as! String, relativeToURL: AwfulForumsClient.sharedClient().baseURL)!
            let presenter = URLMenuPresenter(videoURL: videoURL)
            let sourceRect = webView.rectForElementBoundingRect(videoInfo["rect"] as! String)
            presenter.present(fromViewController: presentingViewController, fromRect: sourceRect, inView: webView)
            return true
        }
        
        return false
    }
}
