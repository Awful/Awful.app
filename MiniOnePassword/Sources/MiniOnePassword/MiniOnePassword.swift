import CoreServices
import UIKit

/*
 Roughly ported from https://github.com/agilebits/onepassword-app-extension, which is unusable from UIKit for Mac because of its references to `UIWebView`. This code is not meaningfully different from that code, so here's its license and you should adhere to it:

 Copyright (c) 2014 AgileBits Inc.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

/// Asks 1Password (or other compliant password managers) to supply a username and password.
public enum OnePassword {

    /// Checks if the 1Password extension (or similar) is available. You might hide the 1Password button if this returns `false`.
    public static var isAvailable: Bool {
        return UIApplication.shared.canOpenURL(URL(string: "org-appextension-feature-password-management://")!)
    }

    /**
     Finds the first available login among all logins matching the domain of `urlString` by using the system share sheet.

     For example, passing a `urlString` of `https://example.com` will match logins for both `spiffy.example.com` and `excellent.example.com`.

     1Password will show a "Show All Logins" button if no logins are found matching `urlString`.

     - Parameter urlString: A domain filter for the logins shown by 1Password. Only the domain is considered, and subdomains are included. Passing `https://example.com` will match logins for all of `example.com`, `spiffy.example.com`, and `excellent.example.com`.
     - Parameter sender: Where the share sheet popover should point. Note that `.none` is likely to crash on non-phone devices.
     - Parameter completion: A block to call after attempting to find login info. The block is called on the main queue.

     - Note: Must be called on the main queue.
     */
    public static func findLogin(
        urlString: String,
        presentingViewController: UIViewController,
        sender: Sender,
        completion: @escaping FindLoginCompletion)
    {
        guard isAvailable else {
            return completion(.failure(.cannotOpenExtensionURL))
        }

        let item: [String: Any] = ["version_number": 184, "url_string": urlString]
        let itemProvider = NSItemProvider(item: item as NSDictionary, typeIdentifier: "org.appextension.find-login-action")
        let extensionItem = NSExtensionItem()
        extensionItem.attachments = [itemProvider]
        let activityVC = UIActivityViewController(activityItems: [extensionItem], applicationActivities: nil)

        activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, activityError in
            guard let returnedItem = returnedItems?.first else {
                let error = activityError.map { OnePasswordError.activityError($0) }
                    ?? .userCancelled
                return completion(.failure(error))
            }

            processReturnedItem(returnedItem, completion: completion)
        }

        presentingViewController.present(activityVC, animated: true)

        switch sender {
        case let .barButton(button):
            activityVC.popoverPresentationController?.barButtonItem = button

        case let .view(view):
            activityVC.popoverPresentationController?.sourceView = view
            activityVC.popoverPresentationController?.sourceRect = view.bounds

        case .none where UIDevice.current.userInterfaceIdiom != .phone:
            print("The sender parameter passed to OnePassword.findLogin(…) is likely required to not be .none; if you see a UIKit exception shortly, this might be why")

        case .none:
            break // ok
        }
    }

    private static func processReturnedItem(
        _ returnedItem: Any,
        completion: @escaping FindLoginCompletion)
    {
        guard
            let extensionItem = returnedItem as? NSExtensionItem,
            let itemProvider = extensionItem.attachments?.first,
            itemProvider.hasItemConformingToTypeIdentifier(kUTTypePropertyList as String) else
        {
            return completion(.failure(.noPropertyListAttachment))
        }

        itemProvider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil, completionHandler: {
            rawItemDictionary, itemProviderError in
            DispatchQueue.main.async {
                guard let itemDictionary = rawItemDictionary as? [String: Any] else {
                    return completion(.failure(.missingPropertyList(itemProviderError)))
                }

                guard
                    let username = itemDictionary["username"] as? String,
                    let password = itemDictionary["password"] as? String else
                {
                    return completion(.failure(.missingKeyInPropertyListAttachment))
                }

                completion(.success(.init(username: username, password: password)))
            }
        })
    }

    /// - Seealso: `findLogin(urlString:presentingViewController:sender:completion:)`.
    public typealias FindLoginCompletion = (Result<LoginInfo, OnePasswordError>) -> Void

    /**
     Login info provided by 1Password. Use this to fill in your login form automatically for the user.

     - Seealso: `findLogin(urlString:presentingViewController:sender:completion:)`.
     */
    public struct LoginInfo {
        public let username: String
        public let password: String
    }

    /**
     Where the share sheet popover should point.

     - Seealso: `findLogin(urlString:presentingViewController:sender:completion:)`.
     */
    public enum Sender {
        case barButton(UIBarButtonItem)
        case view(UIView)

        /// Will likely crash with a UIKit exception on non-phones.
        case none
    }
}

public enum OnePasswordError: Error {

    /// The system share sheet failed for some reason, and it wasn't because the user cancelled (that's `.userCancelled`).
    case activityError(Error)

    /// No app seems to be installed that acts as a password manager.
    case cannotOpenExtensionURL

    /// The password manager's provided login was missing either `username` or `password`.
    case missingKeyInPropertyListAttachment

    /// The password manager did not return a dictionary property list.
    case missingPropertyList(Error?)

    /// The share provider did not include any attachments.
    case noAttachments

    /// The share provider did not include a property list among the attachments.
    case noPropertyListAttachment

    /// The user decided not to find a login in their password manager.
    case userCancelled
}
