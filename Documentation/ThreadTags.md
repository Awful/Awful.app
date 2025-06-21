# Thread Tags

Thread tags are small icons that appear next to a thread's title, providing a quick, visual indication of the thread's primary subject matter (e.g., a flame for a heated discussion, a camera for a thread about movies).

The system is designed to be flexible, allowing the app to use a set of tags that are bundled with the application while also being able to dynamically download new or updated tags from the Something Awful servers without requiring an app update.

## Components

-   **`NamedThreadTag.swift`**: A `enum` that acts as a view model for a thread tag. It describes whether a tag should be an image, a spacer, or nothing, and provides the tag's image name and placeholder information.

-   **`ThreadTagLoader.swift`**: The main, high-level API for loading thread tag images. It's a singleton that orchestrates the entire loading process. It is built on top of the [Nuke](https://github.com/kean/Nuke) image loading library and is responsible for:
    -   Constructing the full URL for a given tag's image name.
    -   Providing complex, theme-aware placeholder images to be displayed while the real image is loading.
    -   Initiating the load request through a custom Nuke `ImagePipeline`.

-   **`ThreadTagDataLoader.swift`**: A custom Nuke `DataLoading` component that implements a "bundle-first" loading strategy. This is the core of the dynamic loading system.

-   **`PotentiallyObjectionableThreadTags.plist`**: A simple `.plist` file containing a list of image names for tags that should be filtered out and not displayed by the app.

-   **`SecondaryTags.plist`**: A `.plist` file that defines a list of secondary thread tags. These are likely used in the thread creation UI.

## Data Flow: Loading a Tag Image

The process for loading a single thread tag is a collaboration between the `ThreadTagLoader` and the `ThreadTagDataLoader`.

1.  A view (e.g., a `ThreadListCell`) calls `ThreadTagLoader.shared.loadImage(...)` with a tag's image name.
2.  The request is passed to the custom `ImagePipeline`, which hands it to the `ThreadTagDataLoader`.
3.  **Objectionable Content Check**: The loader first checks if the image name exists in `PotentiallyObjectionableThreadTags.plist`. If it does, the request is immediately terminated.
4.  **Check App Bundle**: The loader then checks if an image with the given name exists in the `App/Resources/Thread Tags/` directory within the app's bundle.
5.  **Bundle Hit**: If the image is found locally, its data is loaded from the file, wrapped in a fake `HTTPURLResponse`, and returned to the Nuke pipeline. The `Cache-Control` header is set to `no-store` to prevent Nuke from creating a redundant copy in its own disk cache.
6.  **Bundle Miss**: If the image is not found in the app bundle, the `ThreadTagDataLoader` passes the request on to Nuke's default network data loader.
7.  **Network Fetch**: The default loader fetches the image from the base URL defined in the app's `Info.plist`.
8.  **Caching & Display**: The Nuke pipeline receives the image data (either from the bundle or the network), decompresses it, caches it (in memory and, for network requests, on disk), and displays it in the target image view.

## Modernization Plan

This system is already very well-designed and modern. It uses a popular third-party library (`Nuke`) and follows best practices for efficient image loading. There is very little that needs to be "modernized" here.

-   **SwiftUI Integration**: When moving to a SwiftUI-based thread list, this system can be used almost as-is. `Nuke` provides excellent SwiftUI support via the `NukeUI` package. A new view would simply use `LazyImage` from `NukeUI` and pass it the URL constructed by `ThreadTagLoader`. The underlying bundle-first, caching, and filtering logic would all continue to work without modification. 