# Legacy Code Documentation

## Overview

Awful.app contains approximately 10% Objective-C code from its 20-year history. This section documents legacy code, technical debt, and modernization opportunities.

## Contents

- [Objective-C Components](./objective-c-components.md) - Remaining Objective-C code
- [Technical Debt Analysis](./technical-debt-analysis.md) - Areas needing modernization
- [Vendor Dependencies](./vendor-dependencies.md) - Third-party legacy code
- [Migration Opportunities](./migration-opportunities.md) - Code that can be modernized
- [Compatibility Requirements](./compatibility-requirements.md) - Code that must remain unchanged
- [Refactoring Guidelines](./refactoring-guidelines.md) - Safe modernization practices
- [Testing Legacy Code](./testing-legacy-code.md) - Strategies for testing old code

## Legacy Code Categories

### Objective-C Code
- **Location**: Primarily in `Vendor/` directory
- **Status**: Mostly stable, minimal changes needed
- **Dependencies**: Third-party libraries not available via SPM
- **Migration Priority**: Low (if it works, don't fix it)

### Technical Debt Areas
- **Complex View Controllers**: Large, tightly-coupled controllers
- **Manual Memory Management**: Retain cycles and weak references
- **Delegate Chains**: Complex delegation patterns
- **String-based APIs**: Non-type-safe interfaces

### Vendor Dependencies
- **MRProgress**: Progress indicators
- **PSMenuItem**: Custom menu items
- **PullToRefresh**: Custom refresh controls
- **TUSafariActivity**: Safari activity sharing

## Modernization Strategy

### High Priority
1. **Swift Migration**: Convert critical Objective-C to Swift
2. **Memory Safety**: Fix retain cycles and memory leaks
3. **Type Safety**: Replace string-based APIs
4. **Error Handling**: Modernize error patterns

### Medium Priority
1. **View Controller Refactoring**: Break up large controllers
2. **Dependency Injection**: Reduce tight coupling
3. **Protocol-Based Design**: Improve testability
4. **Modern Concurrency**: Replace completion handlers

### Low Priority
1. **Code Style**: Update to modern Swift conventions
2. **Documentation**: Add comprehensive DocC comments
3. **Performance**: Micro-optimizations
4. **Accessibility**: Enhanced VoiceOver support

## Risk Assessment

### High Risk (Avoid Changes)
- Authentication system core logic
- Core Data model definitions
- HTML scraping parsers
- Theme system architecture

### Medium Risk (Careful Changes)
- View controller navigation logic
- Custom gesture recognizers
- Network request handling
- Image caching mechanisms

### Low Risk (Safe to Modernize)
- Utility functions and extensions
- UI layout code
- Settings management
- Logging and debugging code

## Compatibility Constraints

### Must Preserve
- **iOS 15+ Support**: During transition period
- **Core Data Schema**: Existing database compatibility
- **User Settings**: Preference migration paths
- **Authentication**: Cookie-based login system

### Can Modernize
- **Target iOS Version**: Move to 16.1+
- **Swift Version**: Use latest Swift features
- **API Usage**: Adopt modern iOS APIs
- **Architecture Patterns**: Implement modern patterns

## Legacy Code Guidelines

### When to Modernize
1. **Bug Fixes**: If touching code anyway
2. **Feature Additions**: When adding new functionality
3. **Performance Issues**: When optimization needed
4. **Security Concerns**: When vulnerabilities found

### When to Leave Alone
1. **Working Code**: If stable and bug-free
2. **Critical Paths**: Authentication and data integrity
3. **Complex Logic**: HTML parsing and forum scraping
4. **Time Constraints**: When migration timeline is tight

### Safe Modernization Practices
1. **Comprehensive Testing**: Before and after changes
2. **Incremental Updates**: Small, focused changes
3. **Code Reviews**: Multiple eyes on legacy changes
4. **Rollback Plans**: Easy way to revert changes

## Technical Debt Prioritization

### Critical (Fix Soon)
- Memory leaks affecting performance
- Crash-causing retain cycles
- Security vulnerabilities
- iOS compatibility issues

### Important (Fix Eventually)
- Large view controllers
- Complex delegation chains
- String-based APIs
- Manual layout code

### Nice to Have (Fix When Convenient)
- Code style inconsistencies
- Missing documentation
- Unused code removal
- Performance micro-optimizations

## Vendor Code Management

### Replacement Strategy
1. **Evaluate Alternatives**: Look for modern SPM packages
2. **Cost/Benefit Analysis**: Is replacement worth the effort?
3. **Migration Path**: Plan gradual replacement
4. **Testing Strategy**: Ensure behavior preservation

### Current Vendor Code Status
- **MRProgress**: Could replace with native progress views
- **PSMenuItem**: Could replace with iOS 13+ context menus
- **PullToRefresh**: Could replace with native refresh control
- **TUSafariActivity**: Still needed for sharing functionality

## Documentation Requirements

### Legacy Code Documentation
- Purpose and historical context
- Known issues and limitations
- Dependencies and relationships
- Migration considerations

### Technical Debt Documentation
- Problem description
- Impact assessment
- Potential solutions
- Migration timeline

## Measuring Progress

### Metrics to Track
- Lines of Objective-C code
- Number of technical debt items
- Test coverage percentage
- Performance benchmarks
- Crash rates and memory usage

### Success Criteria
- [ ] All critical technical debt addressed
- [ ] Zero Objective-C in core logic paths
- [ ] 90%+ test coverage on legacy code
- [ ] Performance maintained or improved
- [ ] No regression in functionality

## Future Considerations

### Long-term Goals
- 100% Swift codebase
- Modern architecture patterns
- Comprehensive test coverage
- Excellent performance
- Easy maintainability

### Incremental Approach
- Fix issues as encountered
- Modernize during feature work
- Regular technical debt sprints
- Continuous improvement mindset
