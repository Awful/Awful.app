# Local Storage Security

## Overview

Awful.app implements comprehensive local storage security measures to protect user data at rest, manage secure data persistence, and ensure proper data isolation. All sensitive data is encrypted using iOS Data Protection APIs.

## Storage Architecture

### Data Store Structure

#### Core Data Stack
```swift
public final class DataStore: NSObject {
    /// Main context for UI operations
    public let mainManagedObjectContext: NSManagedObjectContext
    
    /// Background context for data imports
    private let backgroundManagedObjectContext: NSManagedObjectContext
    
    /// Persistent store coordinator with security options
    private let storeCoordinator: NSPersistentStoreCoordinator
    
    /// Store directory excluded from backups
    let storeDirectoryURL: URL
}
```

#### Database Location
```swift
// Secure database location
let storeURL = storeDirectoryURL.appendingPathComponent("AwfulCache.sqlite")

// Exclude from backups for privacy
var resourceValues = URLResourceValues()
resourceValues.isExcludedFromBackup = true
try storeDirectoryURL.setResourceValues(resourceValues)
```

### File Protection Levels

#### Data Protection Classes
```swift
// Configure file protection for sensitive data
let options: [String: Any] = [
    NSPersistentStoreFileProtectionKey: FileProtectionType.complete,
    NSMigratePersistentStoresAutomaticallyOption: true,
    NSInferMappingModelAutomaticallyOption: true
]

try storeCoordinator.addPersistentStore(
    ofType: NSSQLiteStoreType,
    configurationName: nil,
    at: storeURL,
    options: options
)
```

#### Protection Levels by Data Type

| Data Type | Protection Level | Justification |
|-----------|------------------|---------------|
| Private Messages | `.complete` | Most sensitive user data |
| Authentication Cookies | `.complete` | Session security critical |
| User Settings | `.completeUnlessOpen` | Frequent access needed |
| Public Forum Data | `.completeUntilFirstAuthentication` | Cached public content |
| Images/Media | `.completeUnlessOpen` | Performance optimization |

## Data Encryption

### iOS Data Protection

#### Automatic Encryption
```swift
// iOS automatically encrypts files with Data Protection
class SecureFileManager {
    static func createSecureFile(at url: URL, data: Data) throws {
        // Set protection level before writing
        try data.write(
            to: url,
            options: [.atomic, .completeFileProtection]
        )
        
        // Verify protection level
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.protectionKey] as? FileProtectionType == .complete else {
            throw SecurityError.fileProtectionFailed
        }
    }
}
```

#### Encryption Keys
- **Hardware Encryption**: AES-256 with hardware acceleration
- **Secure Enclave**: Key derivation using device UID
- **Per-File Keys**: Unique encryption key per file
- **Key Management**: Automatic key rotation by iOS

### Database Encryption

#### SQLite Encryption
```swift
// Core Data with file-level encryption
class EncryptedDataStore {
    private func configureEncryption() -> [String: Any] {
        var options = [String: Any]()
        
        // Enable file protection
        options[NSPersistentStoreFileProtectionKey] = FileProtectionType.complete
        
        // Enable automatic migrations
        options[NSMigratePersistentStoresAutomaticallyOption] = true
        options[NSInferMappingModelAutomaticallyOption] = true
        
        // Optimize for security
        options[NSSQLitePragmasOption] = [
            "journal_mode": "WAL",
            "synchronous": "FULL",
            "secure_delete": "ON"
        ]
        
        return options
    }
}
```

#### Write-Ahead Logging Security
```sql
-- SQLite pragmas for security
PRAGMA journal_mode = WAL;          -- Write-ahead logging
PRAGMA synchronous = FULL;          -- Full synchronous mode
PRAGMA secure_delete = ON;          -- Secure deletion
PRAGMA auto_vacuum = FULL;          -- Automatic vacuuming
```

## Secure Data Operations

### Data Creation

#### Validated Input Storage
```swift
extension NSManagedObject {
    func securelySetValue(_ value: Any?, forKey key: String) {
        // Validate input before storage
        guard let validatedValue = validateInput(value, forKey: key) else {
            throw ValidationError.invalidInput
        }
        
        // Store with security context
        setValue(validatedValue, forKey: key)
        
        // Log access for audit (no sensitive data)
        SecurityLogger.logDataAccess(entity: entity.name!, operation: .write)
    }
    
    private func validateInput(_ value: Any?, forKey key: String) -> Any? {
        // Implement validation logic
        // Check data types, lengths, formats
        // Sanitize strings
        // Validate URLs
        return value
    }
}
```

#### Secure Context Management
```swift
class SecureContextManager {
    func performSecureOperation<T>(_ operation: @escaping () throws -> T) throws -> T {
        let context = backgroundManagedObjectContext
        
        var result: Result<T, Error>!
        context.performAndWait {
            do {
                let value = try operation()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
        }
        
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
```

### Data Reading

#### Secure Data Access
```swift
class SecureDataAccess {
    func fetchData<T: NSManagedObject>(
        _ type: T.Type,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = []
    ) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        // Set fetch limits for security
        request.fetchLimit = 1000
        request.fetchBatchSize = 50
        
        // Perform secure fetch
        let context = mainManagedObjectContext
        return try context.fetch(request)
    }
}
```

#### Memory Security
```swift
extension Data {
    func securelyProcessed<T>(_ processor: (Data) throws -> T) throws -> T {
        defer {
            // Zero out memory after use
            self.withUnsafeMutableBytes { bytes in
                bytes.bindMemory(to: UInt8.self).initialize(repeating: 0)
            }
        }
        
        return try processor(self)
    }
}
```

### Data Deletion

#### Secure Data Removal
```swift
class SecureDataRemoval {
    func securelyDeleteUserData() throws {
        let context = backgroundManagedObjectContext
        
        try context.performAndWait {
            // Delete Core Data entities
            try deleteAllEntities(context)
            
            // Clear derived data
            try clearDerivedData()
            
            // Clear caches
            try clearCaches()
            
            // Clear cookies
            clearHTTPCookies()
            
            // Clear user defaults
            clearUserDefaults()
            
            // Save changes
            try context.save()
        }
    }
    
    private func deleteAllEntities(_ context: NSManagedObjectContext) throws {
        let entityNames = ["User", "Thread", "Post", "PrivateMessage", "Forum"]
        
        for entityName in entityNames {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        }
    }
}
```

#### Secure File Deletion
```swift
class SecureFileManager {
    static func securelyDeleteFile(at url: URL) throws {
        // Overwrite file with random data before deletion
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as! Int
        let randomData = Data((0..<fileSize).map { _ in UInt8.random(in: 0...255) })
        
        try randomData.write(to: url)
        try FileManager.default.removeItem(at: url)
        
        // Verify deletion
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw SecurityError.fileDeletionFailed
        }
    }
}
```

## UserDefaults Security

### Secure Settings Storage

#### Type-Safe Settings
```swift
// Secure settings with Foil framework
@FoilDefaultStorage(Settings.userID) 
private var userID: Int?

@FoilDefaultStorage(Settings.canSendPrivateMessages) 
private var canSendPrivateMessages: Bool

// Custom secure storage
extension UserDefaults {
    func securelySet<T: Codable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            set(data, forKey: key)
        } catch {
            Logger.security.error("Failed to encode secure setting: \(error)")
        }
    }
    
    func securelyGet<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Logger.security.error("Failed to decode secure setting: \(error)")
            return nil
        }
    }
}
```

#### Settings Validation
```swift
struct SettingsValidator {
    static func validateUserSetting<T>(_ value: T, forKey key: String) -> Bool {
        switch key {
        case "font_scale":
            guard let scale = value as? Double else { return false }
            return 50...200 ~= scale
            
        case "default_browser":
            guard let browser = value as? String else { return false }
            return DefaultBrowser.allCases.map(\.rawValue).contains(browser)
            
        default:
            return true
        }
    }
}
```

### Settings Migration

#### Secure Migration
```swift
class SettingsMigrator {
    func migrateSettings(from oldVersion: Int, to newVersion: Int) {
        guard oldVersion < newVersion else { return }
        
        let migrations = availableMigrations.filter { migration in
            migration.fromVersion >= oldVersion && migration.toVersion <= newVersion
        }
        
        for migration in migrations.sorted(by: { $0.fromVersion < $1.fromVersion }) {
            migration.perform()
        }
        
        // Clear old settings that are no longer needed
        cleanupObsoleteSettings()
    }
    
    private func cleanupObsoleteSettings() {
        let obsoleteKeys = ["old_setting_key", "deprecated_preference"]
        obsoleteKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}
```

## Cache Security

### Image Cache Protection

#### Secure Image Storage
```swift
class SecureImageCache {
    private let cacheDirectory: URL
    
    init() {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesURL.appendingPathComponent("SecureImages")
        
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
        )
    }
    
    func store(image: UIImage, forKey key: String) throws {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw CacheError.imageCompressionFailed
        }
        
        let url = cacheDirectory.appendingPathComponent(key.sha256)
        try data.write(to: url, options: .completeFileProtection)
    }
    
    func retrieveImage(forKey key: String) -> UIImage? {
        let url = cacheDirectory.appendingPathComponent(key.sha256)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
```

#### Cache Cleanup
```swift
class CacheManager {
    func pruneExpiredCache() {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: []
            )
            
            for url in contents {
                let attributes = try url.resourceValues(forKeys: [.contentModificationDateKey])
                if let modificationDate = attributes.contentModificationDate,
                   modificationDate < cutoffDate {
                    try FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            Logger.security.error("Cache pruning failed: \(error)")
        }
    }
}
```

### Network Cache Security

#### Response Cache Validation
```swift
class SecureResponseCache {
    func cacheResponse(_ response: URLResponse, data: Data, for request: URLRequest) {
        // Only cache non-sensitive responses
        guard isSafeToCacheRequest(request) else { return }
        
        // Validate response before caching
        guard validateResponse(response) else { return }
        
        // Store with appropriate protection level
        let cachedResponse = CachedURLResponse(
            response: response,
            data: data,
            userInfo: nil,
            storagePolicy: .allowedInMemoryOnly
        )
        
        URLCache.shared.storeCachedResponse(cachedResponse, for: request)
    }
    
    private func isSafeToCacheRequest(_ request: URLRequest) -> Bool {
        // Don't cache authentication requests
        guard !request.url?.path.contains("login") ?? true else { return false }
        
        // Don't cache private message requests
        guard !request.url?.path.contains("private") ?? true else { return false }
        
        return true
    }
}
```

## Backup Exclusion

### iCloud and iTunes Backup

#### Backup Exclusion Configuration
```swift
class BackupManager {
    func configureBackupExclusion() throws {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        
        // Exclude sensitive directories from backup
        let sensitiveDirectories = [
            documentsURL.appendingPathComponent("Database"),
            cacheURL.appendingPathComponent("Images"),
            cacheURL.appendingPathComponent("Cookies")
        ]
        
        for directory in sensitiveDirectories {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try directory.setResourceValues(resourceValues)
        }
    }
    
    func verifyBackupExclusion(for url: URL) -> Bool {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
            return resourceValues.isExcludedFromBackup == true
        } catch {
            return false
        }
    }
}
```

## App Groups Security

### Shared Container Security

#### Secure App Group Configuration
```swift
class AppGroupManager {
    private let appGroupIdentifier = "group.com.awful.app"
    
    var sharedContainerURL: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    func configureSharedSecurity() throws {
        guard let containerURL = sharedContainerURL else {
            throw SecurityError.appGroupNotConfigured
        }
        
        // Set protection level for shared container
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try containerURL.setResourceValues(resourceValues)
        
        // Create secure subdirectories
        let secureDirectories = ["Smilies", "SharedData"]
        for directory in secureDirectories {
            let directoryURL = containerURL.appendingPathComponent(directory)
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        }
    }
}
```

#### Inter-App Data Sharing
```swift
class SecureSharedData {
    func shareSmilieData(_ smilies: [Smilie]) throws {
        guard let containerURL = AppGroupManager().sharedContainerURL else {
            throw SecurityError.appGroupNotConfigured
        }
        
        let smiliesURL = containerURL.appendingPathComponent("Smilies/smilies.plist")
        let data = try PropertyListEncoder().encode(smilies)
        
        try data.write(to: smiliesURL, options: .completeFileProtection)
    }
    
    func loadSharedSmilieData() throws -> [Smilie] {
        guard let containerURL = AppGroupManager().sharedContainerURL else {
            throw SecurityError.appGroupNotConfigured
        }
        
        let smiliesURL = containerURL.appendingPathComponent("Smilies/smilies.plist")
        let data = try Data(contentsOf: smiliesURL)
        
        return try PropertyListDecoder().decode([Smilie].self, from: data)
    }
}
```

## Security Testing

### Storage Security Tests

#### File Protection Tests
```swift
class StorageSecurityTests: XCTestCase {
    func testDatabaseFileProtection() throws {
        let dataStore = DataStore(storeDirectoryURL: testDirectory)
        let databaseURL = testDirectory.appendingPathComponent("AwfulCache.sqlite")
        
        // Verify database exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
        
        // Verify file protection level
        let attributes = try FileManager.default.attributesOfItem(atPath: databaseURL.path)
        XCTAssertEqual(
            attributes[.protectionKey] as? FileProtectionType,
            FileProtectionType.complete
        )
    }
    
    func testBackupExclusion() throws {
        let testURL = testDirectory.appendingPathComponent("test.db")
        try Data().write(to: testURL)
        
        // Set backup exclusion
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try testURL.setResourceValues(resourceValues)
        
        // Verify exclusion
        let retrievedValues = try testURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertTrue(retrievedValues.isExcludedFromBackup ?? false)
    }
}
```

#### Data Validation Tests
```swift
class DataValidationTests: XCTestCase {
    func testSecureDataInsertion() {
        let context = dataStore.mainManagedObjectContext
        
        // Test input validation
        let user = User(context: context)
        XCTAssertThrowsError(try user.securelySetValue("invalid_email", forKey: "email"))
        XCTAssertNoThrow(try user.securelySetValue("user@example.com", forKey: "email"))
    }
    
    func testSecureDataDeletion() {
        // Create test data
        createTestData()
        
        // Perform secure deletion
        try secureDataRemoval.securelyDeleteUserData()
        
        // Verify all data is removed
        let userCount = try dataStore.mainManagedObjectContext.count(for: User.fetchRequest())
        XCTAssertEqual(userCount, 0)
    }
}
```

## Migration Considerations

### SwiftUI Storage Security

#### State Management Security
```swift
// Secure SwiftUI state management
@MainActor
class SecureDataModel: ObservableObject {
    @Published private(set) var sensitiveData: [SensitiveItem] = []
    
    private let dataStore: DataStore
    
    func loadSecureData() async {
        do {
            let data = try await dataStore.fetchSecureData()
            await MainActor.run {
                self.sensitiveData = data
            }
        } catch {
            // Handle error securely
            await MainActor.run {
                self.sensitiveData = []
            }
        }
    }
}
```

#### Core Data with SwiftUI
```swift
// Secure Core Data environment
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            SecureListView()
        }
        .environment(\.managedObjectContext, secureContext)
    }
    
    private var secureContext: NSManagedObjectContext {
        let context = viewContext
        context.automaticallyMergesChangesFromParent = true
        return context
    }
}
```

## Future Enhancements

### Short-term Improvements

1. **Advanced Encryption**: Additional encryption layers
2. **Secure Enclaves**: Hardware security module integration
3. **Key Rotation**: Automatic encryption key rotation
4. **Audit Logging**: Enhanced security audit trails

### Long-term Goals

1. **Zero-Knowledge Storage**: Client-side encryption
2. **Homomorphic Encryption**: Encrypted computation
3. **Blockchain Storage**: Immutable audit trails
4. **Quantum-Resistant Encryption**: Post-quantum cryptography