# Lottie Animations

The application uses the Lottie library to display high-quality, scalable vector animations. These animations are used in two primary ways: as native UI components and as dynamic content embedded within the web-based posts view.

The Lottie animation files are stored as JSON files in the `App/Resources/Lotties/` directory.

## Native UI Animations

Lottie is used for key loading and refreshing indicators in the native UIKit parts of the application.

### 1. General Loading Indicator

-   **View**: `LoadingView.swift`
-   **Animation File**: `mainthrobber60.json`

A `DefaultLoadingView` class (a subclass of `LoadingView`) uses `LottieAnimationView` to display a generic loading "throbber". This view is used as a default loading indicator throughout the app.

Interestingly, `LoadingView` is a factory that can produce different kinds of loading views based on the selected theme. While the default theme uses the Lottie animation, other themes (like `YOSPOS` or `Macinyos`) can specify a different `postsLoadingViewType` to use custom, retro-style loading indicators built with `Timer` or animated GIFs instead.

### 2. Pull-to-Refresh Spinner

-   **View**: `GetOutFrogRefreshSpinnerView.swift`
-   **Animation File**: `frogrefresh60.json`

This view provides the custom pull-to-refresh animation for the posts screen. It uses the "Get Out Frog" Lottie animation. This implementation demonstrates a more advanced use of the Lottie library, using `ColorValueProvider` to dynamically change the colors of the animation's layers at runtime to match the current app theme.

## In-Post Web Animations

Lottie is also used to render animations directly inside the `WKWebView` that displays forum posts.

-   **Trigger**: `PostsPageViewController.swift` and `RenderView.swift`
-   **JavaScript**: A `lottie-player.js` file is used to power these animations.

When the posts view loads, it can call a JavaScript function (`Awful.loadLotties()`) inside the web view. This function finds placeholders in the HTML and replaces them with Lottie animations. This allows for:

-   **Animated Smilies**: Custom animated smilies like `niggly.json` and `toot60.json` can be rendered as part of a post's content.
-   **Loading Indicators**: An animation can be used as a placeholder for an image that is still being downloaded.

This dual native/web approach allows the app to leverage Lottie for both enhancing the core application UI and enriching the dynamic web content presented to the user. 