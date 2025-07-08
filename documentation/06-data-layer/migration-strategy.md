# Migration Strategy

## Overview

Awful.app's data migration strategy ensures seamless schema evolution while maintaining backward compatibility and data integrity. This system has handled 20+ years of schema changes and must continue to support both existing installations and future SwiftUI/SwiftData transitions.

## Migration Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Migration Framework                           │
├─────────────────────────────────────────────────────────────────┤
│  Schema Versioning                                              │
│  ├─ Model Version 1 (Legacy)                                   │
│  ├─ Model Version 2 (Current)                                  │
│  ├─ Model Version 3 (Planned)                                  │
│  └─ Model Version N (Future SwiftData)                         │
├─────────────────────────────────────────────────────────────────┤
│  Migration Types                                                │
│  ├─ Lightweight Migration (Automatic)                          │
│  ├─ Heavyweight Migration (Custom Logic)                       │
│  └─ Progressive Migration (Multi-step)                         │
├─────────────────────────────────────────────────────────────────┤
│  Migration Validation                                           │
│  ├─ Pre-migration Checks                                       │
│  ├─ Post-migration Validation                                  │
│  └─ Rollback Mechanisms                                        │
└─────────────────────────────────────────────────────────────────┘
```

## Core Data Migration Setup

### 1. Model Versioning Configuration

The Core Data stack is configured to handle automatic and manual migrations:

```swift
// DataStore.swift - Migration configuration
public final class DataStore: NSObject {
    static let model: NSManagedObjectModel = {
        guard let modelURL = Bundle.module.url(forResource: "Awful", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load Core Data model")
        }
        return model
    }()
    
    private func loadPersistentStore() {
        let storeURL = storeDirectoryURL.appendingPathComponent("AwfulCache.sqlite")
        
        // Migration options
        let options: [String: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
            
            // Custom migration options
            "com.awfulapp.migration.validation": true,
            "com.awfulapp.migration.progressCallback": migrationProgressCallback
        ]
        
        do {
            persistentStore = try storeCoordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: options
            )
            
            // Perform post-migration fixes if needed
            performPostMigrationTasks()
            
        } catch let error as NSError {
            handleMigrationError(error, storeURL: storeURL)
        }
    }
    
    private func handleMigrationError(_ error: NSError, storeURL: URL) {
        logger.error("Migration failed: \(error)")
        
        if error.domain == NSCocoaErrorDomain {
            switch error.code {
            case NSMigrationMissingSourceModelError:
                // Model too old, requires progressive migration
                performProgressiveMigration(storeURL: storeURL)
                
            case NSMigrationMissingMappingModelError:
                // Complex migration required
                performCustomMigration(storeURL: storeURL)
                
            case NSPersistentStoreIncompatibleVersionHashError:
                // Model version mismatch
                handleVersionMismatch(storeURL: storeURL)
                
            default:
                fatalError("Unhandled migration error: \(error)")
            }
        }
    }
}
```

### 2. Model Version Management

Track and manage model versions systematically:

```swift
// ModelVersionManager.swift - Version tracking
struct ModelVersionManager {
    enum ModelVersion: String, CaseIterable {
        case version1 = "Awful 1"
        case version2 = "Awful 2"
        case version3 = "Awful 3"
        case current = "Awful 4"
        
        var modelURL: URL? {
            return Bundle.main.url(forResource: "Awful.momd/\(rawValue)", withExtension: "mom")
        }
        
        var model: NSManagedObjectModel? {
            guard let url = modelURL else { return nil }
            return NSManagedObjectModel(contentsOf: url)
        }
    }
    
    static func currentVersion() -> ModelVersion {
        return .current
    }
    
    static func sourceVersion(for storeURL: URL) -> ModelVersion? {
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
            
            for version in ModelVersion.allCases {
                guard let model = version.model else { continue }
                if model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
                    return version
                }
            }
        } catch {
            logger.error("Failed to read store metadata: \(error)")
        }
        
        return nil
    }
    
    static func migrationPath(from source: ModelVersion, to destination: ModelVersion) -> [ModelVersion] {
        let allVersions = ModelVersion.allCases
        
        guard let sourceIndex = allVersions.firstIndex(of: source),
              let destinationIndex = allVersions.firstIndex(of: destination),
              sourceIndex < destinationIndex else {
            return []
        }
        
        return Array(allVersions[sourceIndex...destinationIndex])
    }
}
```

## Migration Types

### 1. Lightweight Migration

Automatic migration for simple schema changes:

```swift
// LightweightMigration.swift - Automatic migration support
extension DataStore {
    private func canPerformLightweightMigration(from sourceURL: URL) -> Bool {
        guard let sourceVersion = ModelVersionManager.sourceVersion(for: sourceURL) else {
            return false
        }
        
        // Check if lightweight migration is possible
        let destinationModel = Self.model
        
        do {
            let sourceMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: sourceURL,
                options: nil
            )
            
            return destinationModel.isConfiguration(
                withName: nil,
                compatibleWithStoreMetadata: sourceMetadata
            )
        } catch {
            logger.error("Failed to check lightweight migration compatibility: \(error)")
            return false
        }
    }
}

// Lightweight migration examples:
// - Adding new optional attributes
// - Adding new optional relationships
// - Changing relationship from optional to required (with default)
// - Renaming entities/attributes (with renaming identifier)
```

### 2. Heavyweight Migration

Custom migration for complex schema changes:

```swift
// HeavyweightMigration.swift - Custom migration logic
class HeavyweightMigrationManager {
    private let sourceModel: NSManagedObjectModel
    private let destinationModel: NSManagedObjectModel
    private let mappingModel: NSMappingModel
    
    init(sourceVersion: ModelVersionManager.ModelVersion, 
         destinationVersion: ModelVersionManager.ModelVersion) throws {
        
        guard let sourceModel = sourceVersion.model,
              let destinationModel = destinationVersion.model else {
            throw MigrationError.modelNotFound
        }
        
        self.sourceModel = sourceModel
        self.destinationModel = destinationModel
        
        // Try to infer mapping model, fallback to custom
        if let inferredMapping = try? NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        ) {
            self.mappingModel = inferredMapping
        } else {
            self.mappingModel = try createCustomMappingModel()
        }
    }
    
    func performMigration(sourceStoreURL: URL, destinationStoreURL: URL) throws {
        let migrationManager = NSMigrationManager(
            sourceModel: sourceModel,
            destinationModel: destinationModel
        )
        
        // Set up progress monitoring
        migrationManager.addObserver(
            self,
            forKeyPath: "migrationProgress",
            options: .new,
            context: nil
        )
        
        try migrationManager.migrateStore(
            from: sourceStoreURL,
            sourceType: NSSQLiteStoreType,
            options: nil,
            with: mappingModel,
            toDestinationURL: destinationStoreURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: nil
        )
        
        migrationManager.removeObserver(self, forKeyPath: "migrationProgress")
    }
    
    private func createCustomMappingModel() throws -> NSMappingModel {
        let mappingModel = NSMappingModel()
        
        // Create entity mappings for complex transformations
        let threadMapping = createThreadEntityMapping()
        let postMapping = createPostEntityMapping()
        
        mappingModel.entityMappings = [threadMapping, postMapping]
        
        return mappingModel
    }
    
    private func createThreadEntityMapping() -> NSEntityMapping {
        let mapping = NSEntityMapping()
        mapping.name = "ThreadToThread"
        mapping.mappingType = .transformEntityMappingType
        mapping.sourceEntityName = "Thread"
        mapping.destinationEntityName = "Thread"
        
        // Custom migration policy for complex transformations
        mapping.entityMigrationPolicyClassName = "ThreadMigrationPolicy"
        
        // Property mappings
        let threadIDMapping = NSPropertyMapping()
        threadIDMapping.name = "threadID"
        threadIDMapping.valueExpression = NSExpression(forKeyPath: "threadID")
        
        let titleMapping = NSPropertyMapping()
        titleMapping.name = "title"
        titleMapping.valueExpression = NSExpression(format: "FUNCTION($source, 'cleanTitle:')")
        
        mapping.attributeMappings = [threadIDMapping, titleMapping]
        
        return mapping
    }
}
```

### 3. Progressive Migration

Multi-step migration for large version gaps:

```swift
// ProgressiveMigration.swift - Multi-step migration
class ProgressiveMigrationManager {
    private let sourceStoreURL: URL
    private let destinationStoreURL: URL
    
    init(sourceStoreURL: URL, destinationStoreURL: URL) {
        self.sourceStoreURL = sourceStoreURL
        self.destinationStoreURL = destinationStoreURL
    }
    
    func performProgressiveMigration() throws {
        guard let sourceVersion = ModelVersionManager.sourceVersion(for: sourceStoreURL) else {
            throw MigrationError.unknownSourceVersion
        }
        
        let targetVersion = ModelVersionManager.currentVersion()
        let migrationPath = ModelVersionManager.migrationPath(
            from: sourceVersion,
            to: targetVersion
        )
        
        guard migrationPath.count > 1 else {
            throw MigrationError.noMigrationNeeded
        }
        
        // Create temporary URLs for intermediate migrations
        var currentStoreURL = sourceStoreURL
        
        for index in 1..<migrationPath.count {
            let fromVersion = migrationPath[index - 1]
            let toVersion = migrationPath[index]
            
            let isLastStep = index == migrationPath.count - 1
            let nextStoreURL = isLastStep ? 
                destinationStoreURL : 
                createTemporaryStoreURL(for: toVersion)
            
            logger.info("Migrating from \(fromVersion.rawValue) to \(toVersion.rawValue)")
            
            try performSingleMigrationStep(
                from: fromVersion,
                to: toVersion,
                sourceURL: currentStoreURL,
                destinationURL: nextStoreURL
            )
            
            // Clean up previous temporary store
            if currentStoreURL != sourceStoreURL {
                try cleanupTemporaryStore(at: currentStoreURL)
            }
            
            currentStoreURL = nextStoreURL
        }
    }
    
    private func performSingleMigrationStep(
        from sourceVersion: ModelVersionManager.ModelVersion,
        to destinationVersion: ModelVersionManager.ModelVersion,
        sourceURL: URL,
        destinationURL: URL
    ) throws {
        
        let migrationManager = try HeavyweightMigrationManager(
            sourceVersion: sourceVersion,
            destinationVersion: destinationVersion
        )
        
        try migrationManager.performMigration(
            sourceStoreURL: sourceURL,
            destinationStoreURL: destinationURL
        )
    }
    
    private func createTemporaryStoreURL(for version: ModelVersionManager.ModelVersion) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("Migration-\(version.rawValue).sqlite")
    }
}
```

## Custom Migration Policies

### 1. Thread Migration Policy

Handle complex thread data transformations:

```swift
// ThreadMigrationPolicy.swift - Custom migration logic
@objc(ThreadMigrationPolicy)
class ThreadMigrationPolicy: NSEntityMigrationPolicy {
    
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws -> Bool {
        
        // Get source thread data
        guard let sourceThread = sInstance as? NSManagedObject else {
            return false
        }
        
        // Create destination thread
        let destinationThread = NSEntityDescription.insertNewObject(
            forEntityName: mapping.destinationEntityName!,
            into: manager.destinationContext
        )
        
        // Migrate basic properties
        migrateBasicProperties(from: sourceThread, to: destinationThread)
        
        // Handle complex transformations
        try migrateThreadMetadata(from: sourceThread, to: destinationThread, manager: manager)
        try migrateThreadRelationships(from: sourceThread, to: destinationThread, manager: manager)
        
        // Associate source and destination
        manager.associate(sourceInstance: sInstance, withDestinationInstance: destinationThread, for: mapping)
        
        return true
    }
    
    private func migrateBasicProperties(from source: NSManagedObject, to destination: NSManagedObject) {
        // Direct property copies
        destination.setValue(source.value(forKey: "threadID"), forKey: "threadID")
        destination.setValue(source.value(forKey: "title"), forKey: "title")
        destination.setValue(source.value(forKey: "numberOfPosts"), forKey: "numberOfPosts")
        
        // Transform title (example: clean HTML entities)
        if let title = source.value(forKey: "title") as? String {
            let cleanTitle = title.replacingOccurrences(of: "&amp;", with: "&")
                                 .replacingOccurrences(of: "&lt;", with: "<")
                                 .replacingOccurrences(of: "&gt;", with: ">")
            destination.setValue(cleanTitle, forKey: "title")
        }
    }
    
    private func migrateThreadMetadata(
        from source: NSManagedObject,
        to destination: NSManagedObject,
        manager: NSMigrationManager
    ) throws {
        
        // Migrate read tracking with new schema
        if let seenPosts = source.value(forKey: "seenPosts") as? Int32,
           let totalPosts = source.value(forKey: "numberOfPosts") as? Int32 {
            
            destination.setValue(seenPosts, forKey: "seenPosts")
            destination.setValue(max(0, totalPosts - seenPosts), forKey: "totalUnreadPosts")
        }
        
        // Migrate bookmark status
        let isBookmarked = source.value(forKey: "isBookmarked") as? Bool ?? false
        destination.setValue(isBookmarked, forKey: "isBookmarked")
        
        // Set default values for new properties
        destination.setValue(false, forKey: "isPinned") // New property in destination
        destination.setValue(Date(), forKey: "lastModifiedDate")
    }
    
    private func migrateThreadRelationships(
        from source: NSManagedObject,
        to destination: NSManagedObject,
        manager: NSMigrationManager
    ) throws {
        
        // Forum relationship - will be handled by separate migration
        // Posts relationship - will be handled by PostMigrationPolicy
        // Author relationship - migrate user reference
        
        if let authorUserID = source.value(forKey: "authorUserID") as? String {
            destination.setValue(authorUserID, forKey: "authorUserID")
            // Actual User relationship will be resolved in a later pass
        }
    }
}
```

### 2. User Migration Policy

Handle user data consolidation:

```swift
// UserMigrationPolicy.swift - User data migration
@objc(UserMigrationPolicy)
class UserMigrationPolicy: NSEntityMigrationPolicy {
    
    // Cache to track already migrated users (prevent duplicates)
    private static var migratedUsers: [String: NSManagedObject] = [:]
    
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws -> Bool {
        
        guard let userID = sInstance.value(forKey: "userID") as? String else {
            return false
        }
        
        // Check if user already migrated (handle duplicates)
        if let existingUser = Self.migratedUsers[userID] {
            manager.associate(sourceInstance: sInstance, withDestinationInstance: existingUser, for: mapping)
            return true
        }
        
        // Create new destination user
        let destinationUser = NSEntityDescription.insertNewObject(
            forEntityName: mapping.destinationEntityName!,
            into: manager.destinationContext
        )
        
        // Migrate user data
        migrateUserProperties(from: sInstance, to: destinationUser)
        
        // Cache migrated user
        Self.migratedUsers[userID] = destinationUser
        
        manager.associate(sourceInstance: sInstance, withDestinationInstance: destinationUser, for: mapping)
        
        return true
    }
    
    private func migrateUserProperties(from source: NSManagedObject, to destination: NSManagedObject) {
        // Basic properties
        destination.setValue(source.value(forKey: "userID"), forKey: "userID")
        destination.setValue(source.value(forKey: "username"), forKey: "username")
        
        // Handle custom title HTML
        if let customTitle = source.value(forKey: "customTitleHTML") as? String {
            // Clean up malformed HTML in custom titles
            let cleanTitle = cleanHTMLTitle(customTitle)
            destination.setValue(cleanTitle, forKey: "customTitleHTML")
        }
        
        // Migrate avatar URL with validation
        if let avatarURL = source.value(forKey: "avatarURL") as? String,
           isValidAvatarURL(avatarURL) {
            destination.setValue(avatarURL, forKey: "avatarURL")
        }
        
        // Handle date migration
        if let regDate = source.value(forKey: "regdate") as? Date {
            destination.setValue(regDate, forKey: "regdate")
        }
        
        // Status flags
        destination.setValue(source.value(forKey: "administrator") ?? false, forKey: "administrator")
        destination.setValue(source.value(forKey: "moderator") ?? false, forKey: "moderator")
    }
    
    private func cleanHTMLTitle(_ html: String) -> String {
        // Remove dangerous HTML, preserve basic formatting
        return html.replacingOccurrences(of: "<script.*?</script>", with: "", options: .regularExpression)
                  .replacingOccurrences(of: "<iframe.*?>", with: "", options: .regularExpression)
    }
    
    private func isValidAvatarURL(_ url: String) -> Bool {
        guard let urlComponents = URLComponents(string: url) else { return false }
        return urlComponents.scheme == "https" && urlComponents.host != nil
    }
}
```

## Migration Validation

### 1. Pre-Migration Validation

Validate store state before migration:

```swift
// MigrationValidator.swift - Pre-migration validation
class MigrationValidator {
    
    func validatePreMigration(storeURL: URL) throws {
        // Check store file exists and is readable
        try validateStoreFile(storeURL)
        
        // Check store metadata
        try validateStoreMetadata(storeURL)
        
        // Check store size and available space
        try validateStorageSpace(storeURL)
        
        // Perform data integrity checks
        try validateDataIntegrity(storeURL)
    }
    
    private func validateStoreFile(_ storeURL: URL) throws {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            throw MigrationError.storeFileNotFound
        }
        
        guard FileManager.default.isReadableFile(atPath: storeURL.path) else {
            throw MigrationError.storeFileNotReadable
        }
        
        // Check for SQLite corruption
        let connection = sqlite3_open_v2(storeURL.path, nil, SQLITE_OPEN_READONLY, nil)
        defer { sqlite3_close(connection) }
        
        if connection == nil {
            throw MigrationError.storeFileCorrupted
        }
    }
    
    private func validateStoreMetadata(_ storeURL: URL) throws {
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
            
            // Validate required metadata keys
            guard metadata[NSStoreTypeKey] as? String == NSSQLiteStoreType else {
                throw MigrationError.invalidStoreType
            }
            
            // Check version hash
            guard metadata[NSStoreModelVersionHashesKey] != nil else {
                throw MigrationError.missingVersionHash
            }
            
        } catch {
            throw MigrationError.metadataReadFailed(error)
        }
    }
    
    private func validateStorageSpace(_ storeURL: URL) throws {
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
        let storeSize = fileAttributes[.size] as? UInt64 ?? 0
        
        // Check available space (need at least 2x store size for migration)
        let requiredSpace = storeSize * 2
        
        let resourceValues = try storeURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        let availableSpace = resourceValues.volumeAvailableCapacity ?? 0
        
        if UInt64(availableSpace) < requiredSpace {
            throw MigrationError.insufficientStorage(required: requiredSpace, available: UInt64(availableSpace))
        }
    }
}
```

### 2. Post-Migration Validation

Validate migrated data integrity:

```swift
// PostMigrationValidator.swift - Post-migration validation
class PostMigrationValidator {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func validatePostMigration() throws {
        try validateEntityCounts()
        try validateRelationshipIntegrity()
        try validateDataConsistency()
        try validateRequiredFields()
    }
    
    private func validateEntityCounts() throws {
        let entityCounts = [
            "Forum": Forum.fetchCount(in: context),
            "Thread": Thread.fetchCount(in: context),
            "Post": Post.fetchCount(in: context),
            "User": User.fetchCount(in: context)
        ]
        
        logger.info("Post-migration entity counts: \(entityCounts)")
        
        // Validate minimum expected counts
        guard entityCounts["Forum"]! > 0 else {
            throw ValidationError.noForumsFound
        }
        
        guard entityCounts["User"]! > 0 else {
            throw ValidationError.noUsersFound
        }
    }
    
    private func validateRelationshipIntegrity() throws {
        // Check for orphaned threads
        let orphanedThreads = Thread.fetch(in: context) {
            $0.predicate = NSPredicate(format: "forum == nil")
        }
        
        if !orphanedThreads.isEmpty {
            logger.warning("Found \(orphanedThreads.count) orphaned threads")
            // Could auto-fix by assigning to default forum
        }
        
        // Check for orphaned posts
        let orphanedPosts = Post.fetch(in: context) {
            $0.predicate = NSPredicate(format: "thread == nil")
        }
        
        if !orphanedPosts.isEmpty {
            throw ValidationError.orphanedPostsFound(count: orphanedPosts.count)
        }
        
        // Check circular forum references
        try validateForumHierarchy()
    }
    
    private func validateForumHierarchy() throws {
        let allForums = Forum.fetch(in: context) { _ in }
        
        for forum in allForums {
            var visited: Set<Forum> = []
            var current: Forum? = forum
            
            while let currentForum = current {
                if visited.contains(currentForum) {
                    throw ValidationError.circularForumReference(forumID: forum.forumID)
                }
                visited.insert(currentForum)
                current = currentForum.parentForum
            }
        }
    }
    
    private func validateDataConsistency() throws {
        // Validate thread post counts
        let threadsWithIncorrectCounts = Thread.fetch(in: context) {
            $0.predicate = NSPredicate(format: "numberOfPosts != posts.@count")
        }
        
        if !threadsWithIncorrectCounts.isEmpty {
            logger.warning("Found \(threadsWithIncorrectCounts.count) threads with incorrect post counts")
            
            // Auto-fix post counts
            for thread in threadsWithIncorrectCounts {
                thread.numberOfPosts = Int32(thread.posts.count)
            }
            
            try context.save()
        }
    }
}
```

## Error Recovery and Rollback

### 1. Migration Backup Strategy

Create backups before migration:

```swift
// MigrationBackupManager.swift - Backup management
class MigrationBackupManager {
    private let originalStoreURL: URL
    private let backupURL: URL
    
    init(storeURL: URL) {
        self.originalStoreURL = storeURL
        self.backupURL = storeURL.appendingPathExtension("backup")
    }
    
    func createBackup() throws {
        // Copy main store file
        try copyStoreFile()
        
        // Copy associated files (-wal, -shm)
        try copyAssociatedFiles()
        
        logger.info("Created migration backup at \(backupURL)")
    }
    
    func restoreBackup() throws {
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            throw MigrationError.backupNotFound
        }
        
        // Remove current store
        try removeCurrentStore()
        
        // Restore from backup
        try FileManager.default.copyItem(at: backupURL, to: originalStoreURL)
        
        // Restore associated files
        try restoreAssociatedFiles()
        
        logger.info("Restored from migration backup")
    }
    
    func cleanupBackup() {
        do {
            try FileManager.default.removeItem(at: backupURL)
            
            // Clean up associated backup files
            let walBackup = backupURL.appendingPathExtension("wal")
            let shmBackup = backupURL.appendingPathExtension("shm")
            
            if FileManager.default.fileExists(atPath: walBackup.path) {
                try FileManager.default.removeItem(at: walBackup)
            }
            
            if FileManager.default.fileExists(atPath: shmBackup.path) {
                try FileManager.default.removeItem(at: shmBackup)
            }
            
        } catch {
            logger.error("Failed to cleanup backup: \(error)")
        }
    }
    
    private func copyStoreFile() throws {
        if FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.removeItem(at: backupURL)
        }
        
        try FileManager.default.copyItem(at: originalStoreURL, to: backupURL)
    }
    
    private func copyAssociatedFiles() throws {
        let walURL = originalStoreURL.appendingPathExtension("wal")
        let shmURL = originalStoreURL.appendingPathExtension("shm")
        
        if FileManager.default.fileExists(atPath: walURL.path) {
            let walBackup = backupURL.appendingPathExtension("wal")
            try FileManager.default.copyItem(at: walURL, to: walBackup)
        }
        
        if FileManager.default.fileExists(atPath: shmURL.path) {
            let shmBackup = backupURL.appendingPathExtension("shm")
            try FileManager.default.copyItem(at: shmURL, to: shmBackup)
        }
    }
}
```

### 2. Migration Recovery

Handle failed migrations gracefully:

```swift
// MigrationRecoveryManager.swift - Recovery from failed migrations
class MigrationRecoveryManager {
    private let storeURL: URL
    private let backupManager: MigrationBackupManager
    
    init(storeURL: URL) {
        self.storeURL = storeURL
        self.backupManager = MigrationBackupManager(storeURL: storeURL)
    }
    
    func performSafeMigration() throws {
        do {
            // Create backup before migration
            try backupManager.createBackup()
            
            // Attempt migration
            try performMigration()
            
            // Validate migrated data
            try validateMigration()
            
            // Clean up backup on success
            backupManager.cleanupBackup()
            
        } catch {
            logger.error("Migration failed: \(error)")
            
            // Attempt recovery
            try recoverFromFailedMigration(error: error)
        }
    }
    
    private func recoverFromFailedMigration(error: Error) throws {
        logger.info("Attempting migration recovery...")
        
        switch error {
        case MigrationError.insufficientStorage:
            // Free up space and retry
            try freeUpSpaceAndRetry()
            
        case MigrationError.storeFileCorrupted:
            // Restore from backup
            try backupManager.restoreBackup()
            
        case ValidationError.orphanedPostsFound:
            // Attempt data repair
            try repairOrphanedData()
            
        default:
            // General recovery: restore backup
            try backupManager.restoreBackup()
            throw MigrationError.recoveryFailed(originalError: error)
        }
    }
    
    private func freeUpSpaceAndRetry() throws {
        // Clear temporary files
        clearTemporaryFiles()
        
        // Vacuum SQLite database
        try vacuumDatabase()
        
        // Retry migration with reduced memory usage
        try performMigrationWithReducedMemory()
    }
    
    private func repairOrphanedData() throws {
        // Load store for repair
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: DataStore.model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )
        
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        
        try context.performAndWait {
            // Remove orphaned posts
            let orphanedPosts = Post.fetch(in: context) {
                $0.predicate = NSPredicate(format: "thread == nil")
            }
            
            for post in orphanedPosts {
                context.delete(post)
            }
            
            try context.save()
        }
        
        // Retry validation
        let validator = PostMigrationValidator(context: context)
        try validator.validatePostMigration()
    }
}
```

## SwiftUI Migration Preparation

### 1. SwiftData Compatibility Layer

Prepare for eventual SwiftData migration:

```swift
// SwiftDataCompatibility.swift - Prepare for SwiftData migration
@available(iOS 17.0, *)
protocol DataModelProtocol {
    associatedtype Context
    associatedtype FetchDescriptor
    
    func createContext() -> Context
    func fetch<T>(_ descriptor: FetchDescriptor) async throws -> [T]
    func save(_ context: Context) async throws
}

// Core Data implementation
struct CoreDataModel: DataModelProtocol {
    typealias Context = NSManagedObjectContext
    typealias FetchDescriptor = NSFetchRequest<NSManagedObject>
    
    func createContext() -> NSManagedObjectContext {
        return DataStore.shared.mainManagedObjectContext
    }
    
    func fetch<T>(_ descriptor: NSFetchRequest<NSManagedObject>) async throws -> [T] {
        return try await withCheckedThrowingContinuation { continuation in
            let context = createContext()
            context.perform {
                do {
                    let results = try context.fetch(descriptor)
                    continuation.resume(returning: results as! [T])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func save(_ context: NSManagedObjectContext) async throws {
        try await context.perform {
            try context.save()
        }
    }
}

// Future SwiftData implementation
@available(iOS 17.0, *)
struct SwiftDataModel: DataModelProtocol {
    typealias Context = ModelContext
    typealias FetchDescriptor = SwiftData.FetchDescriptor<any PersistentModel>
    
    private let container: ModelContainer
    
    init() {
        // Configure SwiftData container
        container = try! ModelContainer(for: SwiftDataThread.self, SwiftDataPost.self)
    }
    
    func createContext() -> ModelContext {
        return ModelContext(container)
    }
    
    func fetch<T>(_ descriptor: SwiftData.FetchDescriptor<any PersistentModel>) async throws -> [T] {
        let context = createContext()
        return try context.fetch(descriptor) as! [T]
    }
    
    func save(_ context: ModelContext) async throws {
        try context.save()
    }
}
```

### 2. Dual Persistence Strategy

Support both Core Data and SwiftData during transition:

```swift
// DualPersistenceManager.swift - Support both persistence layers
@available(iOS 17.0, *)
class DualPersistenceManager {
    private let coreDataStore: DataStore
    private let swiftDataContainer: ModelContainer
    
    private var useSwiftData = false
    
    init() {
        self.coreDataStore = DataStore.shared
        self.swiftDataContainer = try! ModelContainer(for: SwiftDataThread.self)
    }
    
    func enableSwiftDataMigration() {
        useSwiftData = true
        startDualWrite()
    }
    
    private func startDualWrite() {
        // Write to both Core Data and SwiftData during transition
        // This ensures data consistency during migration
        
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: coreDataStore.mainManagedObjectContext,
            queue: .main
        ) { notification in
            Task {
                await self.syncToSwiftData(notification)
            }
        }
    }
    
    private func syncToSwiftData(_ notification: Notification) async {
        guard useSwiftData else { return }
        
        // Extract changes from Core Data
        guard let userInfo = notification.userInfo else { return }
        
        let context = ModelContext(swiftDataContainer)
        
        // Sync inserted objects
        if let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
            for object in insertedObjects {
                await syncObjectToSwiftData(object, context: context)
            }
        }
        
        // Sync updated objects
        if let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            for object in updatedObjects {
                await syncObjectToSwiftData(object, context: context)
            }
        }
        
        // Save SwiftData changes
        try? context.save()
    }
    
    private func syncObjectToSwiftData(_ object: NSManagedObject, context: ModelContext) async {
        // Convert Core Data objects to SwiftData objects
        switch object {
        case let thread as Thread:
            await syncThread(thread, to: context)
        case let post as Post:
            await syncPost(post, to: context)
        default:
            break
        }
    }
}
```

## Testing Migration

### 1. Migration Test Framework

Comprehensive testing for migration scenarios:

```swift
// MigrationTestFramework.swift - Migration testing
class MigrationTestFramework: XCTestCase {
    
    func testLightweightMigration() {
        // Create store with old schema
        let oldStoreURL = createTestStore(version: .version2)
        populateTestData(storeURL: oldStoreURL)
        
        // Perform migration
        let migrationExpectation = expectation(description: "Migration completion")
        
        DataStore.migrateStore(from: oldStoreURL, to: newStoreURL) { result in
            switch result {
            case .success:
                migrationExpectation.fulfill()
            case .failure(let error):
                XCTFail("Migration failed: \(error)")
            }
        }
        
        wait(for: [migrationExpectation], timeout: 30.0)
        
        // Validate migrated data
        validateMigratedData()
    }
    
    func testProgressiveMigration() {
        // Test migration from very old version
        let oldStoreURL = createTestStore(version: .version1)
        populateLegacyTestData(storeURL: oldStoreURL)
        
        let migrationManager = ProgressiveMigrationManager(
            sourceStoreURL: oldStoreURL,
            destinationStoreURL: newStoreURL
        )
        
        XCTAssertNoThrow(try migrationManager.performProgressiveMigration())
        
        validateProgressiveMigrationResult()
    }
    
    func testMigrationRecovery() {
        // Simulate migration failure
        let corruptedStoreURL = createCorruptedTestStore()
        
        let recoveryManager = MigrationRecoveryManager(storeURL: corruptedStoreURL)
        
        // Should recover gracefully
        XCTAssertNoThrow(try recoveryManager.performSafeMigration())
    }
    
    private func validateMigratedData() {
        let context = createTestContext()
        
        // Verify entity counts
        let threadCount = Thread.fetchCount(in: context)
        XCTAssertGreaterThan(threadCount, 0)
        
        // Verify relationships
        let threads = Thread.fetch(in: context) { _ in }
        for thread in threads {
            XCTAssertNotNil(thread.forum, "Thread should have forum relationship")
            XCTAssertFalse(thread.posts.isEmpty, "Thread should have posts")
        }
        
        // Verify data integrity
        let validator = PostMigrationValidator(context: context)
        XCTAssertNoThrow(try validator.validatePostMigration())
    }
}
```

The migration strategy ensures that Awful.app can evolve its data model while maintaining backward compatibility and preparing for future SwiftUI/SwiftData integration.