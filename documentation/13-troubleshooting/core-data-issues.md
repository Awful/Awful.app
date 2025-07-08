# Core Data Issues

## Overview

This document covers Core Data problems, migration issues, and database-related debugging in Awful.app.

## Core Data Architecture

### Stack Overview
**Components**:
- `NSPersistentContainer` - Main container
- `NSManagedObjectContext` - Main and background contexts
- `NSManagedObjectModel` - Data model
- `NSPersistentStore` - SQLite storage

**Context Hierarchy**:
```
NSPersistentContainer
├── viewContext (Main Queue)
├── backgroundContext (Private Queue)
└── importContext (Private Queue)
```

### Data Model Structure
**Key Entities**:
- `Forum` - Forum hierarchy
- `Thread` - Discussion threads
- `Post` - Individual posts
- `User` - User information
- `PrivateMessage` - Private messages

## Common Core Data Issues

### Context Threading Violations
**Problem**: Core Data crashes due to threading issues
**Error Messages**:
- "Core Data could not fulfill a fault"
- "NSManagedObjectContext was accessed from a thread other than the one it was created on"
- "Illegal attempt to establish a relationship"

**Solutions**:
1. Always use correct context queue:
   ```swift
   // Correct way
   persistentContainer.viewContext.perform {
       // Core Data operations
   }
   
   // Background context
   let backgroundContext = persistentContainer.newBackgroundContext()
   backgroundContext.perform {
       // Background operations
   }
   ```

2. Use objectID for cross-context operations:
   ```swift
   // Pass objectID between contexts
   let objectID = managedObject.objectID
   
   backgroundContext.perform {
       let backgroundObject = backgroundContext.object(with: objectID)
       // Work with backgroundObject
   }
   ```

3. Enable Core Data concurrency debugging:
   ```swift
   // In AppDelegate or SceneDelegate
   let storeContainer = NSPersistentContainer(name: "DataModel")
   storeContainer.viewContext.automaticallyMergesChangesFromParent = true
   
   // Enable debugging
   storeContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
   ```

### Migration Problems
**Problem**: App crashes during Core Data migration
**Common Causes**:
- Incompatible model versions
- Missing mapping models
- Complex data transformations
- Large datasets

**Debugging Migration**:
1. Enable migration debugging:
   ```swift
   let options = [
       NSMigratePersistentStoresAutomaticallyOption: true,
       NSInferMappingModelAutomaticallyOption: true,
       NSSQLitePragmasOption: ["journal_mode": "DELETE"]
   ]
   
   do {
       try persistentStoreCoordinator.addPersistentStore(
           ofType: NSSQLiteStoreType,
           configurationName: nil,
           at: storeURL,
           options: options
       )
   } catch {
       print("Migration failed: \(error)")
   }
   ```

2. Check migration necessity:
   ```swift
   func needsMigration(storeURL: URL, modelURL: URL) -> Bool {
       guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
           ofType: NSSQLiteStoreType,
           at: storeURL
       ) else {
           return false
       }
       
       let model = NSManagedObjectModel(contentsOf: modelURL)
       return !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
   }
   ```

3. Progressive migration:
   ```swift
   func migrateStore(from sourceURL: URL, to destinationURL: URL) throws {
       let migrationManager = NSMigrationManager(
           sourceModel: sourceModel,
           destinationModel: destinationModel
       )
       
       try migrationManager.migrateStore(
           from: sourceURL,
           sourceType: NSSQLiteStoreType,
           options: nil,
           with: mappingModel,
           toDestinationURL: destinationURL,
           destinationType: NSSQLiteStoreType,
           destinationOptions: nil
       )
   }
   ```

### Data Corruption Issues
**Problem**: Core Data store becomes corrupted
**Symptoms**:
- Frequent crashes
- Inconsistent data
- Validation errors
- SQLite corruption messages

**Solutions**:
1. Implement corruption detection:
   ```swift
   func checkStoreIntegrity() -> Bool {
       let request = NSFetchRequest<NSManagedObject>(entityName: "Thread")
       request.fetchLimit = 1
       
       do {
           _ = try persistentContainer.viewContext.fetch(request)
           return true
       } catch {
           print("Store integrity check failed: \(error)")
           return false
       }
   }
   ```

2. Store recovery:
   ```swift
   func recoverCorruptedStore() {
       let coordinator = persistentContainer.persistentStoreCoordinator
       
       // Remove corrupted store
       if let store = coordinator.persistentStores.first {
           try? coordinator.remove(store)
       }
       
       // Delete store file
       if FileManager.default.fileExists(atPath: storeURL.path) {
           try? FileManager.default.removeItem(at: storeURL)
       }
       
       // Recreate store
       setupPersistentStore()
   }
   ```

3. Data validation:
   ```swift
   func validateManagedObject(_ object: NSManagedObject) -> Bool {
       do {
           try object.validateForUpdate()
           return true
       } catch {
           print("Validation failed: \(error)")
           return false
       }
   }
   ```

## Debugging Techniques

### Enable Core Data Logging
```swift
// SQL debugging
UserDefaults.standard.set(1, forKey: "com.apple.CoreData.SQLDebug")

// Verbose logging
UserDefaults.standard.set(1, forKey: "com.apple.CoreData.Logging.stderr")

// Migration debugging
UserDefaults.standard.set(1, forKey: "com.apple.CoreData.MigrationDebug")
```

### Launch Arguments
```
-com.apple.CoreData.SQLDebug 1
-com.apple.CoreData.Logging.stderr 1
-com.apple.CoreData.MigrationDebug 1
-com.apple.CoreData.ConcurrencyDebug 1
```

### Custom Logging
```swift
extension NSManagedObjectContext {
    func logChanges() {
        if hasChanges {
            print("=== Context Changes ===")
            print("Inserted: \(insertedObjects.count)")
            print("Updated: \(updatedObjects.count)")
            print("Deleted: \(deletedObjects.count)")
            
            for object in insertedObjects {
                print("+ \(object.entity.name ?? "Unknown"): \(object.objectID)")
            }
            
            for object in updatedObjects {
                print("~ \(object.entity.name ?? "Unknown"): \(object.objectID)")
                print("  Changed keys: \(object.changedValues().keys)")
            }
            
            for object in deletedObjects {
                print("- \(object.entity.name ?? "Unknown"): \(object.objectID)")
            }
        }
    }
}
```

## Performance Issues

### Slow Fetch Requests
**Problem**: Fetch requests take too long
**Solutions**:
1. Analyze fetch request performance:
   ```swift
   func benchmarkFetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) {
       let startTime = CFAbsoluteTimeGetCurrent()
       
       do {
           let results = try persistentContainer.viewContext.fetch(request)
           let endTime = CFAbsoluteTimeGetCurrent()
           let duration = endTime - startTime
           
           print("Fetch completed in \(duration)s, returned \(results.count) objects")
       } catch {
           print("Fetch failed: \(error)")
       }
   }
   ```

2. Optimize fetch requests:
   ```swift
   // Use predicates to limit results
   request.predicate = NSPredicate(format: "lastUpdate > %@", Date().addingTimeInterval(-86400))
   
   // Limit fetched properties
   request.propertiesToFetch = ["threadID", "title", "lastUpdate"]
   
   // Use batch fetching
   request.fetchBatchSize = 20
   
   // Disable faulting for frequently accessed properties
   request.relationshipKeyPathsForPrefetching = ["author", "forum"]
   ```

3. Use background contexts for heavy operations:
   ```swift
   func performHeavyFetch() {
       let backgroundContext = persistentContainer.newBackgroundContext()
       
       backgroundContext.perform {
           let request = NSFetchRequest<Thread>(entityName: "Thread")
           // Configure request
           
           do {
               let results = try backgroundContext.fetch(request)
               
               DispatchQueue.main.async {
                   // Update UI with results
               }
           } catch {
               print("Background fetch failed: \(error)")
           }
       }
   }
   ```

### Memory Usage Issues
**Problem**: Core Data consuming excessive memory
**Solutions**:
1. Monitor memory usage:
   ```swift
   func logMemoryUsage() {
       let context = persistentContainer.viewContext
       print("Registered objects: \(context.registeredObjects.count)")
       print("Inserted objects: \(context.insertedObjects.count)")
       print("Updated objects: \(context.updatedObjects.count)")
       print("Deleted objects: \(context.deletedObjects.count)")
   }
   ```

2. Clear caches periodically:
   ```swift
   func clearCaches() {
       let context = persistentContainer.viewContext
       context.reset() // Clears all managed objects
       context.refreshAllObjects() // Refreshes existing objects
   }
   ```

3. Use faulting appropriately:
   ```swift
   // Turn objects into faults to save memory
   context.refresh(managedObject, mergeChanges: false)
   
   // Check if object is fault
   if managedObject.isFault {
       print("Object is a fault")
   }
   ```

## Data Consistency Issues

### Duplicate Data
**Problem**: Duplicate records in database
**Solutions**:
1. Implement unique constraints:
   ```swift
   // In Core Data model
   // Set "Unique" constraint on threadID attribute
   
   // Or programmatically
   func findOrCreateThread(threadID: String) -> Thread {
       let request = NSFetchRequest<Thread>(entityName: "Thread")
       request.predicate = NSPredicate(format: "threadID == %@", threadID)
       
       do {
           let results = try context.fetch(request)
           if let existingThread = results.first {
               return existingThread
           }
       } catch {
           print("Error finding thread: \(error)")
       }
       
       // Create new thread
       let newThread = Thread(context: context)
       newThread.threadID = threadID
       return newThread
   }
   ```

2. Batch operations for data cleanup:
   ```swift
   func removeDuplicateThreads() {
       let request = NSFetchRequest<Thread>(entityName: "Thread")
       request.propertiesToFetch = ["threadID"]
       
       do {
           let threads = try context.fetch(request)
           var seenThreadIDs = Set<String>()
           var duplicates = [Thread]()
           
           for thread in threads {
               if seenThreadIDs.contains(thread.threadID) {
                   duplicates.append(thread)
               } else {
                   seenThreadIDs.insert(thread.threadID)
               }
           }
           
           for duplicate in duplicates {
               context.delete(duplicate)
           }
           
           try context.save()
       } catch {
           print("Error removing duplicates: \(error)")
       }
   }
   ```

### Relationship Issues
**Problem**: Broken or inconsistent relationships
**Solutions**:
1. Validate relationships:
   ```swift
   func validateThreadRelationships(_ thread: Thread) {
       // Check forum relationship
       if thread.forum == nil {
           print("Warning: Thread \(thread.threadID) has no forum")
       }
       
       // Check posts relationship
       if thread.posts.isEmpty {
           print("Warning: Thread \(thread.threadID) has no posts")
       }
       
       // Check inverse relationships
       for post in thread.posts {
           if post.thread != thread {
               print("Error: Post \(post.postID) has incorrect thread relationship")
           }
       }
   }
   ```

2. Fix broken relationships:
   ```swift
   func fixBrokenRelationships() {
       let request = NSFetchRequest<Post>(entityName: "Post")
       request.predicate = NSPredicate(format: "thread == nil")
       
       do {
           let orphanedPosts = try context.fetch(request)
           for post in orphanedPosts {
               // Try to find correct thread
               if let threadID = post.threadID {
                   let thread = findThread(threadID: threadID)
                   post.thread = thread
               }
           }
           
           try context.save()
       } catch {
           print("Error fixing relationships: \(error)")
       }
   }
   ```

## Import/Export Issues

### Batch Import Performance
**Problem**: Slow data import operations
**Solutions**:
1. Use batch operations:
   ```swift
   func batchImportThreads(_ threadsData: [ThreadData]) {
       let backgroundContext = persistentContainer.newBackgroundContext()
       
       backgroundContext.perform {
           let batchSize = 100
           
           for (index, threadData) in threadsData.enumerated() {
               let thread = Thread(context: backgroundContext)
               thread.configure(with: threadData)
               
               // Save in batches
               if index % batchSize == 0 {
                   do {
                       try backgroundContext.save()
                   } catch {
                       print("Batch save failed: \(error)")
                   }
               }
           }
           
           // Final save
           do {
               try backgroundContext.save()
           } catch {
               print("Final save failed: \(error)")
           }
       }
   }
   ```

2. Use Core Data batch operations:
   ```swift
   func batchUpdateLastRead() {
       let request = NSBatchUpdateRequest(entityName: "Thread")
       request.predicate = NSPredicate(format: "lastReadDate < %@", Date().addingTimeInterval(-86400))
       request.propertiesToUpdate = ["needsUpdate": true]
       
       do {
           try persistentContainer.viewContext.execute(request)
       } catch {
           print("Batch update failed: \(error)")
       }
   }
   ```

### Data Export Issues
**Problem**: Exporting large datasets
**Solutions**:
1. Streaming export:
   ```swift
   func exportThreads(to url: URL) {
       let request = NSFetchRequest<Thread>(entityName: "Thread")
       request.fetchBatchSize = 50
       
       do {
           let threads = try persistentContainer.viewContext.fetch(request)
           let encoder = JSONEncoder()
           let outputStream = OutputStream(url: url, append: false)
           outputStream?.open()
           
           for thread in threads {
               let data = try encoder.encode(thread.exportData)
               outputStream?.write(data.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }, 
                                  maxLength: data.count)
           }
           
           outputStream?.close()
       } catch {
           print("Export failed: \(error)")
       }
   }
   ```

## Testing Core Data

### Unit Testing Setup
```swift
class CoreDataTestCase: XCTestCase {
    var persistentContainer: NSPersistentContainer!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory store for testing
        persistentContainer = NSPersistentContainer(name: "DataModel")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Test store creation failed: \(error)")
            }
        }
        
        context = persistentContainer.viewContext
    }
    
    override func tearDown() {
        persistentContainer = nil
        context = nil
        super.tearDown()
    }
}
```

### Test Data Creation
```swift
func createTestThread() -> Thread {
    let thread = Thread(context: context)
    thread.threadID = "test-thread-1"
    thread.title = "Test Thread"
    thread.createdDate = Date()
    
    let post = Post(context: context)
    post.postID = "test-post-1"
    post.content = "Test content"
    post.thread = thread
    
    return thread
}
```

## Recovery Strategies

### Automatic Recovery
```swift
class CoreDataRecoveryManager {
    func attemptRecovery() {
        if !checkStoreIntegrity() {
            print("Store integrity check failed, attempting recovery...")
            
            // Try to recover from backup
            if let backupURL = getBackupStoreURL() {
                if restoreFromBackup(backupURL) {
                    print("Recovered from backup")
                    return
                }
            }
            
            // Last resort: recreate store
            recreateStore()
        }
    }
    
    func createBackup() {
        let coordinator = persistentContainer.persistentStoreCoordinator
        let backupURL = getBackupStoreURL()
        
        do {
            try coordinator.migratePersistentStore(
                coordinator.persistentStores.first!,
                to: backupURL!,
                options: nil,
                withType: NSSQLiteStoreType
            )
        } catch {
            print("Backup creation failed: \(error)")
        }
    }
}
```

### Manual Recovery Tools
```swift
// Debug tools for manual recovery
func analyzeStore() {
    let entities = persistentContainer.managedObjectModel.entities
    
    for entity in entities {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity.name!)
        
        do {
            let count = try persistentContainer.viewContext.count(for: request)
            print("\(entity.name!): \(count) objects")
        } catch {
            print("Error counting \(entity.name!): \(error)")
        }
    }
}

func repairStore() {
    // Attempt various repair strategies
    // 1. Validate all objects
    // 2. Fix broken relationships
    // 3. Remove corrupted objects
    // 4. Rebuild indexes
}
```

## Best Practices

### Prevention Strategies
1. **Regular Backups**: Implement automatic backup system
2. **Validation**: Add comprehensive data validation
3. **Testing**: Thorough testing of migrations and operations
4. **Monitoring**: Track Core Data performance metrics
5. **Error Handling**: Robust error handling and recovery

### Performance Optimization
1. **Batch Operations**: Use batch processing for large datasets
2. **Background Contexts**: Perform heavy operations in background
3. **Fetch Optimization**: Use appropriate fetch request settings
4. **Memory Management**: Monitor and control memory usage
5. **Index Optimization**: Add indexes for frequently queried attributes

### Development Guidelines
1. **Context Management**: Always use correct context queues
2. **Object Lifecycle**: Understand managed object lifecycle
3. **Relationship Management**: Properly configure relationships
4. **Migration Planning**: Plan migrations carefully
5. **Testing Strategy**: Comprehensive testing approach