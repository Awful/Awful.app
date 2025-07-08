# Runtime Issues

## Overview

This document covers app crashes, unexpected behavior, and runtime errors that occur when running Awful.app.

## Crash Diagnostics

### App Crashes on Launch
**Problem**: App crashes immediately after launch
**Common Causes**:
- Core Data model incompatibility
- Missing required resources
- Corrupted user preferences
- Invalid theme configuration
- Memory issues

**Diagnostic Steps**:
1. Check crash logs in Console.app
2. Enable exception breakpoints in Xcode
3. Run with Address Sanitizer
4. Check for missing files or resources

**Solutions**:
```bash
# Reset simulator data
xcrun simctl erase all

# Clear app data on device
# Settings → General → iPhone Storage → Awful → Offload App
```

### Crash Log Analysis
**Finding Crash Logs**:
- macOS: Console.app → Crash Reports
- iOS Device: Settings → Privacy & Security → Analytics & Improvements → Analytics Data
- Xcode: Window → Devices and Simulators → Device → View Device Logs

**Key Information**:
- Exception type (EXC_BAD_ACCESS, EXC_CRASH, etc.)
- Thread information
- Stack trace
- Memory addresses
- Register states

**Common Crash Patterns**:
```
Exception Type: EXC_BAD_ACCESS (SIGSEGV)
Exception Codes: KERN_INVALID_ADDRESS
Exception Subtype: KERN_INVALID_ADDRESS
```

### Memory-Related Crashes
**Problem**: Crashes due to memory issues
**Types**:
- EXC_BAD_ACCESS: Invalid memory access
- EXC_RESOURCE: Memory limit exceeded
- SIGABRT: Assertion failures

**Debugging**:
1. Enable Address Sanitizer:
   - Edit Scheme → Run → Diagnostics → Address Sanitizer
2. Use malloc stack logging:
   ```bash
   export MallocStackLogging=1
   ```
3. Profile with Instruments (Leaks, Zombies)

## Application State Issues

### App Doesn't Respond to Touch
**Problem**: UI elements don't respond to user interaction
**Common Causes**:
- Main thread blocked
- Overlapping transparent views
- Modal presentation issues
- Gesture recognizer conflicts

**Debugging**:
1. Check main thread usage:
   ```swift
   DispatchQueue.main.async {
       // Ensure UI updates are on main thread
   }
   ```
2. Use View Debugger to check view hierarchy
3. Enable slow animations to observe transitions
4. Check for modal presentation issues

### Background App Crashes
**Problem**: App crashes when backgrounded or resumed
**Common Causes**:
- Background task expiration
- Invalid background operations
- Memory warnings while backgrounded
- State restoration issues

**Solutions**:
1. Implement proper background task handling:
   ```swift
   var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
   
   func beginBackgroundTask() {
       backgroundTaskID = UIApplication.shared.beginBackgroundTask {
           self.endBackgroundTask()
       }
   }
   
   func endBackgroundTask() {
       UIApplication.shared.endBackgroundTask(backgroundTaskID)
       backgroundTaskID = .invalid
   }
   ```

2. Handle memory warnings:
   ```swift
   override func didReceiveMemoryWarning() {
       super.didReceiveMemoryWarning()
       // Clear caches, release resources
   }
   ```

## Core Data Runtime Issues

### Core Data Crashes
**Problem**: App crashes during Core Data operations
**Common Errors**:
- NSInvalidArgumentException
- NSInternalInconsistencyException
- Threading violations
- Memory corruption

**Debugging**:
1. Enable Core Data debugging:
   ```bash
   -com.apple.CoreData.SQLDebug 1
   -com.apple.CoreData.Logging.stderr 1
   ```

2. Check for threading violations:
   ```swift
   // Always access Core Data on correct queue
   persistentContainer.viewContext.perform {
       // Core Data operations
   }
   ```

3. Monitor fetch requests:
   ```swift
   // Add debugging to fetch requests
   request.includesPropertyValues = false
   request.includesSubentities = false
   ```

### Migration Issues
**Problem**: App crashes during Core Data migration
**Symptoms**:
- Crash on first launch after update
- Data corruption errors
- Migration timeout errors

**Solutions**:
1. Test migrations thoroughly:
   ```swift
   // Enable migration debugging
   options[NSMigratePersistentStoresAutomaticallyOption] = true
   options[NSInferMappingModelAutomaticallyOption] = true
   ```

2. Implement progressive migration for complex changes
3. Provide fallback for migration failures
4. Test with various data states

## Network-Related Runtime Issues

### Network Request Failures
**Problem**: App crashes or hangs during network operations
**Common Causes**:
- Network timeout handling
- Invalid response parsing
- Memory issues with large responses
- Concurrent request management

**Solutions**:
1. Implement proper timeout handling:
   ```swift
   let configuration = URLSessionConfiguration.default
   configuration.timeoutIntervalForRequest = 30.0
   configuration.timeoutIntervalForResource = 60.0
   ```

2. Handle response parsing errors:
   ```swift
   do {
       let data = try JSONSerialization.jsonObject(with: responseData)
   } catch {
       // Handle parsing error gracefully
   }
   ```

3. Manage concurrent requests:
   ```swift
   let semaphore = DispatchSemaphore(value: 5) // Limit concurrent requests
   ```

### HTML Parsing Crashes
**Problem**: App crashes when parsing Something Awful HTML
**Common Causes**:
- Malformed HTML
- Unexpected HTML structure changes
- Memory issues with large documents
- XPath/CSS selector failures

**Solutions**:
1. Add defensive parsing:
   ```swift
   guard let element = document.firstNode(matchingSelector: "selector") else {
       return // Handle missing element gracefully
   }
   ```

2. Implement error boundaries:
   ```swift
   do {
       let result = try parseHTML(html)
   } catch {
       // Log error and use fallback
       logger.error("HTML parsing failed: \(error)")
   }
   ```

## UI-Related Runtime Issues

### View Controller Lifecycle Issues
**Problem**: Crashes related to view controller lifecycle
**Common Causes**:
- Accessing views before viewDidLoad
- Deallocated view controllers
- Improper navigation stack management
- Memory leaks in view controllers

**Solutions**:
1. Check view loading state:
   ```swift
   override func viewDidLoad() {
       super.viewDidLoad()
       // Safe to access view properties
   }
   ```

2. Implement proper cleanup:
   ```swift
   deinit {
       // Remove observers, cancel operations
       NotificationCenter.default.removeObserver(self)
   }
   ```

### Table View Crashes
**Problem**: Crashes in table view operations
**Common Causes**:
- Invalid index paths
- Data source inconsistencies
- Animation conflicts
- Cell reuse issues

**Solutions**:
1. Validate index paths:
   ```swift
   guard indexPath.row < dataSource.count else { return }
   ```

2. Batch table updates:
   ```swift
   tableView.performBatchUpdates({
       // All updates together
   }, completion: nil)
   ```

3. Handle cell reuse properly:
   ```swift
   override func prepareForReuse() {
       super.prepareForReuse()
       // Reset cell state
   }
   ```

## Theme System Runtime Issues

### Theme Loading Failures
**Problem**: App crashes when loading themes
**Common Causes**:
- Invalid theme file format
- Missing parent themes
- Circular theme dependencies
- Resource loading failures

**Solutions**:
1. Validate theme files:
   ```swift
   func validateTheme(_ theme: Theme) -> Bool {
       // Check required properties
       guard theme.name != nil, theme.colors != nil else {
           return false
       }
       return true
   }
   ```

2. Handle missing themes gracefully:
   ```swift
   let theme = themeManager.theme(named: themeName) ?? themeManager.defaultTheme
   ```

### CSS Compilation Issues
**Problem**: Crashes during CSS compilation
**Solutions**:
1. Catch compilation errors:
   ```swift
   do {
       let compiledCSS = try lessCompiler.compile(lessSource)
   } catch {
       // Use fallback CSS
   }
   ```

2. Test CSS with various content types
3. Validate CSS syntax before compilation

## Performance-Related Runtime Issues

### Memory Warnings
**Problem**: App receives memory warnings and crashes
**Solutions**:
1. Implement memory warning handling:
   ```swift
   override func didReceiveMemoryWarning() {
       super.didReceiveMemoryWarning()
       
       // Clear image caches
       imageCache.removeAll()
       
       // Clear unnecessary view controllers
       navigationController?.viewControllers = [rootViewController]
   }
   ```

2. Monitor memory usage:
   ```swift
   let memoryUsage = getMemoryUsage()
   if memoryUsage > threshold {
       // Proactive cleanup
   }
   ```

### Main Thread Blocking
**Problem**: App becomes unresponsive
**Common Causes**:
- Heavy computations on main thread
- Synchronous network requests
- Large data processing
- Infinite loops

**Solutions**:
1. Move heavy work to background:
   ```swift
   DispatchQueue.global(qos: .userInitiated).async {
       // Heavy computation
       DispatchQueue.main.async {
           // Update UI
       }
   }
   ```

2. Use async/await for better thread management:
   ```swift
   Task {
       let result = await heavyComputation()
       await updateUI(with: result)
   }
   ```

## Debug Techniques

### Runtime Debugging
1. **Enable Debug Logging**:
   ```swift
   UserDefaults.standard.set(true, forKey: "AwfulDebugLogging")
   ```

2. **Use Breakpoints Effectively**:
   - Exception breakpoints
   - Symbolic breakpoints
   - Conditional breakpoints

3. **Instruments Profiling**:
   - Time Profiler for performance
   - Leaks for memory issues
   - Zombies for deallocated objects

### Console Debugging
```bash
# View device logs
xcrun simctl spawn booted log stream --predicate 'process == "Awful"'

# Monitor memory usage
xcrun simctl spawn booted vm_stat

# Check crash logs
log show --predicate 'process == "Awful"' --info --last 1h
```

### Xcode Debugging Features
1. **Memory Graph Debugger**:
   - Identify retain cycles
   - Find memory leaks
   - Analyze object relationships

2. **View Hierarchy Debugger**:
   - Inspect view layout
   - Check view properties
   - Identify UI issues

3. **Thread Sanitizer**:
   - Detect threading issues
   - Find race conditions
   - Identify data races

## Recovery Strategies

### Graceful Error Handling
```swift
func handleError(_ error: Error) {
    logger.error("Runtime error: \(error)")
    
    // Show user-friendly message
    showAlert(message: "Something went wrong. Please try again.")
    
    // Attempt recovery
    resetToKnownGoodState()
}
```

### State Recovery
```swift
// Save state before risky operations
func saveApplicationState() {
    let state = ApplicationState(
        currentViewController: getCurrentViewController(),
        userData: getUserData()
    )
    try? stateManager.save(state)
}

// Restore state after crash
func restoreApplicationState() {
    guard let state = try? stateManager.load() else { return }
    restoreViewController(state.currentViewController)
    restoreUserData(state.userData)
}
```

### Fallback Mechanisms
1. **Default Values**: Always provide sensible defaults
2. **Offline Mode**: Handle network failures gracefully
3. **Progressive Enhancement**: Core functionality works without advanced features
4. **User Communication**: Inform users when things go wrong

## Prevention Best Practices

### Code Quality
1. **Defensive Programming**:
   - Validate inputs
   - Handle edge cases
   - Check preconditions

2. **Error Handling**:
   - Use proper exception handling
   - Provide meaningful error messages
   - Implement retry mechanisms

3. **Testing**:
   - Unit tests for critical paths
   - Integration tests for complex flows
   - Stress testing with edge cases

### Monitoring
1. **Crash Reporting**:
   - Implement crash reporting service
   - Monitor crash rates
   - Analyze crash patterns

2. **Performance Monitoring**:
   - Track app performance metrics
   - Monitor memory usage
   - Identify performance regressions

3. **User Feedback**:
   - Collect user reports
   - Implement feedback mechanisms
   - Monitor app store reviews

## Emergency Procedures

### Critical Runtime Issues
1. **Immediate Response**:
   - Identify affected users
   - Implement temporary workarounds
   - Prepare hotfix

2. **Communication**:
   - Notify stakeholders
   - Communicate with users
   - Provide status updates

3. **Resolution**:
   - Develop and test fix
   - Deploy update
   - Monitor resolution effectiveness

### Data Recovery
1. **Backup Systems**:
   - Regular data backups
   - Cloud synchronization
   - Export capabilities

2. **Recovery Procedures**:
   - Data restoration tools
   - Manual recovery options
   - User guidance for recovery