//  StencilEnvironment.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import Stencil
import UIKit

/// An entrypoint for Stencil templates without having to `import Stencil` everywhere.
final class StencilEnvironment {
    
    /// Templates available in the app bundle.
    enum Template: String {
        case acknowledgements = "Acknowledgements.html.stencil"
        case announcement = "Announcement.html.stencil"
        case post = "Post.html.stencil"
        case postPreview = "PostPreview.html.stencil"
        case postsView = "PostsView.html.stencil"
        case privateMessage = "PrivateMessage.html.stencil"
        case profile = "Profile.html.stencil"
    }
    
    /**
     A shared Stencil environment that loads templates from the app bundle.
     
     The following custom filters are available:
     - `formatAnnouncementDate`
     - `formatPostDate`
     - `formatRegdate`
     - `formatSentDate`
     - `htmlEscape`
     
     And the following custom tags are available:
     - `fontScaleStyle`
     
     - Seealso: `Stencil.Environment.renderTemplate(_:context:)`.
     */
    static let shared: Stencil.Environment = {
        let ext = Extension()
        
        ext.registerFilter("formatAnnouncementDate", filter: makeDateFormatFilter(.announcement))
        ext.registerFilter("formatPostDate", filter: makeDateFormatFilter(.postDate))
        ext.registerFilter("formatRegdate", filter: makeDateFormatFilter(.regdate))
        ext.registerFilter("formatSentDate", filter: makeDateFormatFilter(.sentDate))
        ext.registerFilter("htmlEscape", filter: htmlEscape)
        
        ext.registerSimpleTag("fontScaleStyle", handler: fontScaleStyle)

        let loader = BundleResourceLoader(bundle: Bundle(for: StencilEnvironment.self))
        return .init(loader: loader, extensions: [ext])
    }()
    
    // Only reason we're using a class is so we can locate the bundle; we don't want anyone to instantiate this.
    private init() {}
}

protocol StencilContextConvertible {
    var context: [String: Any] { get }
}

/// Loads templates from a bundle's Resources directory. Unlike `FileSystemLoader`, this loader does not assume that resources are in the root of the bundle.
class BundleResourceLoader: Loader {
    private let resourceURL: URL?

    init(bundle: Bundle) {
        resourceURL = bundle.resourceURL
    }

    func loadTemplate(name: String, environment: Stencil.Environment) throws -> Template {
        guard let url = URL(string: name, relativeTo: resourceURL) else {
            throw TemplateDoesNotExist(templateNames: [name], loader: self)
        }
        let content = try String(contentsOf: url, encoding: .utf8)
        return environment.templateClass.init(templateString: content, environment: environment, name: name)
    }

    func loadTemplate(names: [String], environment: Stencil.Environment) throws -> Template {
        for name in names {
            guard let url = URL(string: name, relativeTo: resourceURL) else {
                continue
            }
            let content = try String(contentsOf: url, encoding: .utf8)
            return environment.templateClass.init(templateString: content, environment: environment, name: name)
        }

        throw TemplateDoesNotExist(templateNames: names, loader: self)
    }
}

extension Stencil.Environment {
    
    /**
     Renders a known template.
     
     By default, the context includes values for these keys:
     - `baseURL`
     - `userInterfaceIdiom`
     - `version`
     
     - Seealso: `StencilEnvironment.shared`, which describes some custom filters and tags made available when using that environment to render templates.
     */
    func renderTemplate(_ template: StencilEnvironment.Template, context: StencilContextConvertible) throws -> String {
        return try renderTemplate(template, context: context.context)
    }
    
    /**
     Renders a known template.
     
     By default, the context includes values for these keys:
     - `baseURL`
     - `userInterfaceIdiom`
     - `version`
     
     - Seealso: `StencilEnvironment.shared`, which describes some custom filters and tags made available when using that environment to render templates.
     */
    func renderTemplate(_ template: StencilEnvironment.Template, context: [String: Any]) throws -> String {
        let context = contextDefaults.merging(context, uniquingKeysWith: { $1 })
        return try renderTemplate(name: template.rawValue, context: context)
    }
    
    private var contextDefaults: [String: Any] {
        return [
            "baseURL": ForumsClient.shared.baseURL?.absoluteString ?? "",
            "userInterfaceIdiom": UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone",
            "version": Bundle.main.shortVersionString ?? ""]
    }
}

// MARK: - Custom filters and tags

private func fontScaleStyle(_ context: Context) -> String {
    let fontScale = NumberFormatter.localizedString(from: FoilDefaultStorage(Settings.fontScale).wrappedValue as NSNumber, number: .none)
    return """
        <style id="awful-font-scale-style">
        .nameanddate, .postbody, footer {
            font-size: \(fontScale)%;
        }
        </style>
        """
}

private func makeDateFormatFilter(_ dateFormatter: DateFormatter)
    -> (_ value: Any?) throws -> Any?
{
    return { value in
        guard let date = value as? Date else { return value }
        return dateFormatter.string(from: date)
    }
}

private func htmlEscape(_ value: Any?) throws -> Any? {
    let stringified = stringify(value)
    var escaped = ""
    escaped.reserveCapacity(stringified.count)
    for c in stringified {
        switch c {
        case "<": escaped += "&lt;"
        case ">": escaped += "&gt;"
        case "&": escaped += "&amp;"
        case "'": escaped += "&apos;"
        case "\"": escaped += "&quot;"
        default: escaped.append(c)
        }
    }
    return escaped
}

// MARK: - Internal Stencil functions

private func stringify(_ result: Any?) -> String {
    if let result = result as? String {
        return result
    } else if let array = result as? [Any?] {
        return unwrap(array).description
    } else if let result = result as? CustomStringConvertible {
        return result.description
    } else if let result = result as? NSObject {
        return result.description
    } else {
        return ""
    }
}

private func unwrap(_ array: [Any?]) -> [Any] {
    return array.map { (item: Any?) -> Any in
        if let item = item {
            if let items = item as? [Any?] {
                return unwrap(items)
            } else {
                return item
            }
        } else {
            return item as Any
        }
    }
}
