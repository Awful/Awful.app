# Imgur Integration

The application integrates with Imgur to handle image attachments in posts and private messages. When a user embeds an image in the text composer, the app uploads it to Imgur and replaces the image data with a BBcode tag pointing to the new Imgur URL. This is necessary because the forums do not support direct binary image uploads.

## Components

-   **`ImgurAnonymousAPI` (Swift Package)**: A self-contained Swift package located in the `ImgurAnonymousAPI/` directory. It provides a lightweight, focused client for Imgur's v3 API.
    -   **`ImgurUploader`**: The main class within the package responsible for performing the image upload. It handles image resizing to meet Imgur's limits, creating the `multipart/form-data` request, and networking.
    -   **`ImgurAuthManager`**: A singleton class that manages the OAuth2 flow for authenticated Imgur uploads. It uses `ASWebAuthenticationSession` to handle the login process.
-   **`ImgurAnonymousAPI+Shared.swift`**: An extension in the main app target that creates and configures a shared singleton instance of the `ImgurUploader`.
-   **`UploadImageAttachments.swift`**: This file contains the core logic that connects the post composition process with the `ImgurAnonymousAPI` package.

## Upload Workflow

The image upload process is initiated when a user creates a post or private message that contains embedded images.

1.  **Image Extraction**: The main function `uploadImages(attachedTo:completion:)` is called. It scans the `NSAttributedString` of the text field and extracts all `NSTextAttachment` objects that represent local images.
2.  **Authentication Check**: It checks the user's preference in settings. If the user has opted for authenticated uploads, it uses `ImgurAuthManager` to ensure a valid OAuth token is present. If the token is missing or expired, the upload process is halted, and the user is prompted to log in to Imgur.
3.  **Concurrent Uploads**: The app uploads all images concurrently to improve performance. It uses a `DispatchGroup` to wait for all upload operations to complete.
4.  **API Request**: For each image, it calls `ImgurUploader.shared.upload()`. The `ImgurAnonymousAPI` package automatically handles:
    -   Resizing the image if it exceeds Imgur's file size limits.
    -   Converting the image data into the correct format.
    -   Sending the `multipart/form-data` request to the Imgur API.
5.  **BBcode Replacement**: Upon receiving a successful response from Imgur for each image, the uploader gets back a URL. The app then replaces the original `NSTextAttachment` in the text field with the appropriate BBcode tag (`[img]` or `[timg]`) containing the new Imgur URL.
6.  **Submission**: Once all images are replaced with their corresponding URLs, the final plain text is submitted to the Something Awful forums.

## Modernization Plan

The Imgur integration is already implemented in a fairly modern and robust way, using a dedicated Swift package and `async/await`. Further improvements would be minor.

-   **Swift Concurrency**: While it uses `DispatchGroup` for concurrency, the `uploadImages(fromSources:completion:)` function could be refactored to use a `TaskGroup` for a more modern Swift Concurrency approach. This would make the code for handling concurrent uploads and their results slightly cleaner and more readable.
-   **Error Handling**: The error handling could be improved by creating more specific, typed errors instead of relying on `NSError` in some places, which would improve clarity and compile-time safety. 