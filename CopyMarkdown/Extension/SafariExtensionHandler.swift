//  SafariExtensionHandler.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AppKit
import SafariServices

class SafariExtensionHandler: SFSafariExtensionHandler {

    enum Command: String {
        case copyMarkdown = "CopyMarkdown"
    }

    override func validateContextMenuItem(
        withCommand command: String,
        in page: SFSafariPage,
        userInfo: [String : Any]? = nil,
        validationHandler: @escaping (Bool, String?) -> Void
    ) {
        switch Command(rawValue: command) {
        case .copyMarkdown:
            page.getPropertiesWithCompletionHandler { props in
                switch props?.url?.lastPathComponent.lowercased() {
                case "announcement.php", "showthread.php":
                    validationHandler(false, nil)
                default:
                    validationHandler(true, nil)
                }
            }

        default:
            fatalError("Unexpected command \(command)")
        }
    }

    enum ScriptMessageName: String {
        case copyMarkdown
    }

    override func contextMenuItemSelected(
        withCommand command: String,
        in page: SFSafariPage,
        userInfo: [String : Any]? = nil
    ) {
        switch Command(rawValue: command) {
        case .copyMarkdown:
            page.dispatchMessageToScript(withName: ScriptMessageName.copyMarkdown.rawValue)

        default:
            fatalError("Unexpected command \(command)")
        }
    }

    enum ExtensionMessageName: String {
        case setPasteboard
    }

    override func messageReceived(
        withName messageName: String,
        from page: SFSafariPage,
        userInfo: [String: Any]? = nil
    ) {
        switch ExtensionMessageName(rawValue: messageName) {
        case .setPasteboard:
            let pboard = NSPasteboard.general
            pboard.declareTypes([.string], owner: self)
            let ok = pboard.setString(userInfo!["text"] as! String, forType: .string)
            print("ok: \(ok)")

        default:
            fatalError("Unexpected message \(messageName)")
        }
    }
}
