# Less & CSS Compilation

The application uses the [Less](https://lesscss.org/) CSS pre-processor to create the stylesheets for the web-based views (primarily the posts view and user profiles). This allows for the use of variables, mixins, and other conveniences to manage the complex styling required for different themes.

The entire compilation process is handled by a custom Swift Package located in the `LessStylesheet/` directory.

## Components

-   **`LessStylesheet` (Swift Package)**: A self-contained package that provides a SwiftPM Build Tool Plugin to automatically find and compile `.less` files.

-   **`lessc` (Custom Executable)**: The build tool plugin invokes a custom command-line tool named `lessc`, also defined within the package. This is not the standard Node.js compiler. Instead, it's a Swift executable that wraps the official `less.js` browser script and executes it using Apple's `JavaScriptCore` framework. This is a clever design that removes the need for Node.js as a build dependency.

-   **`AwfulTheming` (Swift Package)**: This package contains all the source `.less` files in its `Sources/AwfulTheming/Stylesheets/` directory. The compiled `.css` files are bundled as resources within this package.

## Compilation Workflow

1.  **File Discovery**: At build time, the `LessStylesheet` plugin scans the `AwfulTheming` target for `.less` files.
2.  **File Naming Convention**: The plugin adheres to a specific naming convention:
    -   Files starting with a leading underscore (e.g., `_variables.less`, `_spoilers.less`) are treated as "partials" or "imports." They do not produce a direct output file.
    -   All other `.less` files (e.g., `posts-view.less`, `posts-view-dark.less`) are treated as main entry points.
3.  **Compilation**: For each main `.less` file, the plugin invokes the `lessc` executable. This tool compiles the Less code into standard CSS, creating a corresponding `.css` file (e.g., `posts-view.less` becomes `posts-view.css`).
4.  **Resource Bundling**: The resulting `.css` files are included as resources in the final compiled `AwfulTheming` package, making them available to the application at runtime.

## Runtime Usage

1.  **Theme Definition**: The app's `Themes.plist` file defines the properties for each available theme. Each theme definition includes a key that specifies the name of the CSS file to use (e.g., `"stylesheet": "posts-view-dark"`).
2.  **Stylesheet Loading**: When a theme is activated, the `Theme` object reads the `stylesheet` key and loads the content of the corresponding `.css` file from the `AwfulTheming` resource bundle into a string.
3.  **HTML Injection**: When a `PostsPageViewController` renders a page, it fetches the stylesheet string from the current `Theme` object and injects it directly into a `<style>` block in the HTML that is loaded into the `WKWebView`.

## Modernization Plan

This build-time compilation system is very effective and does not require modernization. It's self-contained, doesn't rely on external dependencies like Node.js, and integrates cleanly with the Swift Package Manager.

If the posts view were to be fully modernized into a native SwiftUI view, this entire CSS compilation pipeline would no longer be necessary for that feature, as styling would be handled by SwiftUI modifiers. However, for any part of the app that continues to use `WKWebView` to render themed HTML content, this system remains an excellent solution. 