# Imgur Integration

Awful.app integrates with Imgur's API to provide image upload functionality for forum posts. The integration supports both anonymous and authenticated uploads with comprehensive error handling and rate limiting.

## Overview

The Imgur integration allows users to:
- Upload images from camera or photo library
- Choose between anonymous and authenticated uploads
- Handle rate limiting and error scenarios
- Store authentication tokens securely in Keychain

## Architecture

### Core Components

The integration is built around several key components:

#### ImgurAnonymousAPI Package
- **Location**: `ImgurAnonymousAPI/`
- **Purpose**: Standalone Swift package for Imgur API operations
- **Components**:
  - `ImgurUploader` - Main upload interface
  - `ImgurAuthInterface` - Authentication protocol
  - `ImageOperations` - Image processing and upload operations
  - `AsynchronousOperation` - Base operation class

#### ImgurAuthManager
- **Location**: `App/Extensions/ImgurAnonymousAPI+Shared.swift`
- **Purpose**: Manages authentication and token storage
- **Features**:
  - OAuth2 authentication flow
  - Keychain token storage
  - Rate limit handling
  - Authentication state management

#### Upload Integration
- **Location**: `App/Composition/UploadImageAttachments.swift`
- **Purpose**: Integrates uploads into the composition workflow
- **Features**:
  - Image attachment processing
  - Progress reporting
  - Error handling and retry logic

## Configuration

### Build Settings

Add your Imgur client ID to build configuration:

```xcconfig
// Local.xcconfig
IMGUR_CLIENT_ID = YOUR_CLIENT_ID_HERE
```

### Info.plist Configuration

The app's Info.plist includes:

```xml
<key>ImgurClientId</key>
<string>${IMGUR_CLIENT_ID}</string>

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>awful</string>
        </array>
    </dict>
</array>
```

### Privacy Permissions

Required privacy usage descriptions:

```xml
<key>NSCameraUsageDescription</key>
<string>Awful will upload to Imgur any photos you take and choose to include in your post when you tap Post</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Awful will upload to Imgur any photos you choose from your library when you tap Post</string>
```

## Upload Modes

### Anonymous Uploads
- No authentication required
- Limited to Imgur's anonymous rate limits
- Images not associated with user account
- Default mode for privacy

### Authenticated Uploads
- Requires OAuth2 authentication
- Higher rate limits
- Images associated with user's Imgur account
- Better error reporting and management

## Authentication Flow

### OAuth2 Implementation

The authentication uses ASWebAuthenticationSession:

```swift
// Authentication URL
https://api.imgur.com/oauth2/authorize?client_id={CLIENT_ID}&response_type=token&state=awful

// Callback URL scheme
awful://
```

### Token Management

Tokens are stored securely in Keychain:

```swift
private let keychain = Keychain(service: "com.awfulapp.Awful.imgur")

private enum KeychainKeys {
    static let bearerToken = "imgur_bearer_token"
    static let refreshToken = "imgur_refresh_token" 
    static let tokenExpiry = "imgur_token_expiry"
}
```

### Authentication State

The `ImgurAuthManager` tracks authentication state:

```swift
public var isAuthenticated: Bool {
    return keychain[KeychainKeys.bearerToken] != nil
}

public var needsAuthentication: Bool {
    return imgurUploadMode == .account && !isAuthenticated
}
```

## Error Handling

### Rate Limiting

The integration handles Imgur's rate limiting:

```swift
public enum DefaultsKeys {
    static let rateLimited = "imgur_rate_limited"
}

// Rate limit detection and handling
if case .rateLimited = authError {
    authLogger.error("Imgur rate limit exceeded")
    self.defaults.set(true, forKey: DefaultsKeys.rateLimited)
    // Clear after 1 hour
    DispatchQueue.global().asyncAfter(deadline: .now() + 3600) {
        self.defaults.set(false, forKey: DefaultsKeys.rateLimited)
    }
}
```

### Upload Errors

Common error scenarios:
- Network connectivity issues
- Authentication failures
- File size limitations
- Invalid image formats
- Rate limit exceeded

### Recovery Strategies

- Automatic retry for transient failures
- Fallback to anonymous uploads
- User notification for authentication issues
- Graceful degradation when service unavailable

## Image Processing

### Supported Formats

The integration supports standard iOS image formats:
- JPEG
- PNG
- HEIF (converted to JPEG for upload)
- GIF (animated support)

### Size Limitations

Imgur enforces file size limits:
- Anonymous uploads: 10MB maximum
- Authenticated uploads: 20MB maximum
- Automatic compression for oversized images

### Metadata Handling

- EXIF data is preserved or stripped based on privacy settings
- Image orientation is normalized
- Quality optimization for web delivery

## Settings Integration

### Upload Mode Selection

Users can choose upload mode in settings:

```swift
@FoilDefaultStorage(Settings.imgurUploadMode) private var imgurUploadMode

enum ImgurUploadMode: String, CaseIterable {
    case disabled = "Disabled"
    case anonymous = "Anonymous"
    case account = "Imgur Account"
}
```

### Settings UI

The settings interface provides:
- Upload mode selection
- Authentication status display
- Account management options
- Privacy information

## Development

### Testing

Create test configurations:

```swift
// Test with mock credentials
extension ImgurUploader {
    static var test: ImgurUploader {
        return ImgurUploader(authProvider: MockAuthProvider())
    }
}
```

### Debugging

Enable debug logging:

```swift
ImgurUploader.logger = { level, messageProvider in
    let message = messageProvider()
    switch level {
    case .debug:
        print("[DEBUG] \(message)")
    case .info:
        print("[INFO] \(message)")
    case .error:
        print("[ERROR] \(message)")
    }
}
```

### Local Development

For development without Imgur integration:
- Leave `IMGUR_CLIENT_ID` unset
- App will gracefully disable upload features
- UI will hide upload-related controls

## Security Considerations

### Token Storage
- Bearer tokens stored in Keychain (not UserDefaults)
- Automatic token expiry handling
- Secure token refresh flow

### Privacy
- Anonymous uploads by default
- Clear user consent for authenticated uploads
- Option to disable uploads entirely

### Network Security
- HTTPS-only communication
- Certificate pinning recommended for production
- Proper error message sanitization

## Monitoring and Analytics

### Success Metrics
- Upload completion rates
- Authentication success rates
- Error frequency by type
- Performance timing

### Error Tracking
- Failed upload attempts
- Authentication failures
- Rate limit encounters
- Network timeouts

## Future Enhancements

### Planned Features
- Batch upload support
- Progress indicators for large files
- Upload queue management
- Alternative service integration

### API Version Management
- Imgur API v3 currently supported
- Migration plan for future versions
- Backward compatibility considerations

## Troubleshooting

### Common Issues

**Authentication fails:**
- Check client ID configuration
- Verify URL scheme registration
- Test callback URL handling

**Uploads timeout:**
- Check network connectivity
- Verify file size limits
- Test with smaller images

**Rate limit errors:**
- Check authentication status
- Monitor request frequency
- Implement exponential backoff

### Debug Steps

1. Verify configuration in build settings
2. Check Info.plist values
3. Test authentication flow
4. Monitor network requests
5. Validate image processing

### Support Resources

- [Imgur API Documentation](https://apidocs.imgur.com/)
- [ImgurAnonymousAPI Package](../ImgurAnonymousAPI/README.md)
- Error logs in system console
- Network debugging with proxies