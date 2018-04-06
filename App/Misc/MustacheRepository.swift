//  MustacheRepository.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Mustache

/**
 Mustache templates in the main bundle.

 These templates are rendered with some extra context, so there's no need to include these yourself:

 - fontScalePercentage
 - javascriptEscape
 - postDateFormatter
 - regdateFormatter
 - sentDateFormatter
 - userInterfaceIdiom (either `ipad` or `iphone`)
 - version (e.g. `3.35`)
 */
struct MustacheTemplate {

    // Known templates:
    static let acknowledgements = MustacheTemplate(name: "Acknowledgements")
    static let post = MustacheTemplate(name: "Post")
    static let postPreview = MustacheTemplate(name: "PostPreview")
    static let postsView = MustacheTemplate(name: "PostsView")
    static let privateMessage = MustacheTemplate(name: "PrivateMessage")
    static let profile = MustacheTemplate(name: "Profile")

    /// Renders a known template (see `MustacheRepository.swift` for a list of known templates). `value` might be a dictionary or a `MustacheBoxable`.
    static func render(_ template: MustacheTemplate, value: Any?) throws -> String {
        let template = try repository.template(named: template.name)
        return try template.render(value)
    }

    private let name: String
}

private let repository: TemplateRepository = {
    let repo = TemplateRepository(bundle: .main)

    let fontScale: RenderFunction = { info in
        return Rendering("\(AwfulSettings.shared().fontScale)")
    }

    repo.configuration.extendBaseContext([
        "fontScalePercentage": fontScale,
        "javascriptEscape": StandardLibrary.javascriptEscape,
        "postDateFormat": DateFormatter.postDateFormatter,
        "regdateFormat": DateFormatter.regDateFormatter,
        "sentDateFormat": DateFormatter.postDateFormatter,
        "userInterfaceIdiom": { () -> String in
            switch UIDevice.current.userInterfaceIdiom {
            case .pad:
                return "ipad"
            default:
                return "iphone"
            }
        }(),
        "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String])
    return repo
}()
