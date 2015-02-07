//  Acknowledgements.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class AcknowledgementsViewController: AwfulViewController {
    private var webView: WKWebView { return view as WKWebView }
    private var backgroundColor: UIColor {
        return theme["backgroundColor"] as UIColor? ?? UIColor.whiteColor()
    }
    private var textColor: UIColor {
        return theme["listTextColor"] as UIColor? ?? UIColor.blackColor()
    }
    
    override init() {
        super.init(nibName: nil, bundle: nil)
        
        title = "Acknowledgements"
        modalPresentationStyle = .FormSheet
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBAction private func didTapDone() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func loadView() {
        view = WKWebView()
        webView.navigationDelegate = self
        
        // Avoids flash of white when first presented.
        view.opaque = false
        view.backgroundColor = UIColor.clearColor()
        
        let context = [
            "backgroundColor": backgroundColor.awful_hexCode,
            "textColor": textColor.awful_hexCode
        ]
        let bundle = NSBundle(forClass: AcknowledgementsViewController.self)
        var error: NSError?
        let HTML = GRMustacheTemplate.renderObject(context, fromResource: "Acknowledgements", bundle: bundle, error: &error)
        webView.loadHTMLString(HTML, baseURL: nil)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        let js = "var s=document.body.style; s.backgroundColor='\(backgroundColor.awful_hexCode)'; s.color='\(textColor.awful_hexCode)'"
        webView.evaluateJavaScript(js, completionHandler: { result, error in
            if let error = error {
                NSLog("%@ error running script `%@` in acknowledgements screen: %@", __FUNCTION__, js, error)
            }
        })
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if navigationController == nil {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "didTapDone")
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        webView.scrollView.flashScrollIndicators()
    }
}

extension AcknowledgementsViewController: WKNavigationDelegate {
    func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .LinkActivated {
            UIApplication.sharedApplication().openURL(navigationAction.request.URL)
            decisionHandler(.Cancel)
        } else {
            decisionHandler(.Allow)
        }
    }
}
