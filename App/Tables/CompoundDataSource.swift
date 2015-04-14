//  CompoundDataSource.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class CompoundDataSource: NSObject {
    private let dataSources = NSMutableOrderedSet()
    private var startingGlobalSections = [Int]()
    
    var numberOfSections: Int {
        get {
            if let lastStart = startingGlobalSections.last {
                return lastStart + (dataSources.lastObject as! DataSource).numberOfSections
            } else {
                return 0
            }
        }
    }

    func addDataSource(dataSource: DataSource) {
        assert(!dataSources.containsObject(dataSource), "data source \(dataSource) is already here")
        let firstNewGlobalSection = numberOfSections
        startingGlobalSections.append(firstNewGlobalSection)
        dataSources.addObject(dataSource)
        dataSource.delegate = self
        let newSections = NSIndexSet(indexesInRange: NSRange(location: firstNewGlobalSection, length: dataSource.numberOfSections))
        delegate?.dataSource?(self, didInsertSections: newSections)
    }
    
    func removeDataSource(dataSource: DataSource) {
        let index = dataSources.indexOfObject(dataSource)
        assert(index != NSNotFound, "data source \(dataSource) was never here")
        let firstOldGlobalSection = startingGlobalSections.removeAtIndex(index)
        dataSources.removeObjectAtIndex(index)
        dataSource.delegate = nil
        let oldSections = NSIndexSet(indexesInRange: NSRange(location: firstOldGlobalSection, length: dataSource.numberOfSections))
        delegate?.dataSource?(self, didRemoveSections: oldSections)
    }
    
    weak var delegate: DataSourceDelegate?
}

// MARK: - Helpers

extension CompoundDataSource {
    convenience init(_ newDataSources: DataSource...) {
        self.init()
        for dataSource in newDataSources {
            addDataSource(dataSource)
        }
    }
    
    private func dataSourceForGlobalSection(globalSection: Int) -> (DataSource, localSection: Int) {
        assert(globalSection < numberOfSections)
        let index = nearestStartingGlobalSectionForGlobalSection(globalSection)
        return (dataSources.objectAtIndex(index) as! DataSource, localSection: globalSection - startingGlobalSections[index])
    }
    
    private func nearestStartingGlobalSectionForGlobalSection(globalSection: Int) -> Int {
        for (i, section) in enumerate(self.startingGlobalSections) {
            if section > globalSection {
                return i - 1
            }
            // Don't try to return early here if section == globalSection. Some data sources may have zero sections and we need to skip over those.
        }
        return startingGlobalSections.count - 1
    }
    
    private func dataSourceForGlobalIndexPath(indexPath: NSIndexPath) -> (DataSource, localIndexPath: NSIndexPath) {
        let (dataSource, localSection) = dataSourceForGlobalSection(indexPath.section)
        return (dataSource, localIndexPath: NSIndexPath(forRow: indexPath.row, inSection: localSection))
    }
    
    private func startingGlobalSectionForDataSource(dataSource: DataSource) -> Int {
        let index = dataSources.indexOfObject(dataSource)
        assert(index != NSNotFound)
        return startingGlobalSections[index]
    }
    
    private func globalize(localDataSource: DataSource, _ localIndexPaths: [NSIndexPath]) -> [NSIndexPath] {
        let globalOffset = startingGlobalSectionForDataSource(localDataSource)
        return localIndexPaths.map { NSIndexPath(forRow: $0.row, inSection: $0.section + globalOffset) }
    }

    private func globalize(localDataSource: DataSource, _ localIndexPath: NSIndexPath) -> NSIndexPath {
        return globalize(localDataSource, [localIndexPath]).first!
    }
    
    private func globalize(localDataSource: DataSource, _ localSections: NSIndexSet) -> NSIndexSet {
        let globalSections = NSMutableIndexSet(indexSet: localSections)
        let globalOffset = startingGlobalSectionForDataSource(localDataSource)
        globalSections.shiftIndexesStartingAtIndex(globalSections.firstIndex, by: globalOffset)
        return globalSections
    }
    
    private func globalize(localDataSource: DataSource, _ localSection: Int) -> Int {
        return globalize(localDataSource, NSIndexSet(index: localSection)).firstIndex
    }
    
    private func numberOfGlobalSectionsForDataSource(localDataSource: DataSource) -> Int {
        let index = dataSources.indexOfObject(localDataSource)
        assert(index != NSNotFound)
        if index + 1 == dataSources.count {
            return numberOfSections - startingGlobalSectionForDataSource(localDataSource)
        } else {
            let nextDataSource = dataSources.objectAtIndex(index + 1) as! DataSource
            return startingGlobalSectionForDataSource(nextDataSource) - startingGlobalSectionForDataSource(localDataSource)
        }
    }
    
    private func shiftStartingGlobalSectionsStartingAfterDataSource(localDataSource: DataSource, by: Int) {
        let index = dataSources.indexOfObject(localDataSource)
        for var i = index + 1; i < startingGlobalSections.count; i++ {
            startingGlobalSections[i] += by
        }
    }
}

// MARK: - DataSource

extension CompoundDataSource: DataSource {
    func itemAtIndexPath(globalIndexPath: NSIndexPath) -> AnyObject {
        let (dataSource, localIndexPath) = dataSourceForGlobalIndexPath(globalIndexPath)
        return dataSource.itemAtIndexPath(localIndexPath)
    }
    
    func indexPathsForItem(item: AnyObject) -> [NSIndexPath] {
        let typedDataSources = self.dataSources.array as! [DataSource]
        return typedDataSources.reduce([]) { $0 + self.globalize($1, $1.indexPathsForItem(item)) }
    }
    
    func tableView(tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath globalIndexPath: NSIndexPath) -> String {
        let (dataSource, localIndexPath) = dataSourceForGlobalIndexPath(globalIndexPath)
        return dataSource.tableView?(tableView, titleForDeleteConfirmationButtonForRowAtIndexPath: localIndexPath) ?? "Delete"
    }
}

extension CompoundDataSource: UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return numberOfSections
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection globalSection: Int) -> Int {
        let (dataSource, localSection) = dataSourceForGlobalSection(globalSection)
        return dataSource.tableView(tableView, numberOfRowsInSection: localSection)
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath globalIndexPath: NSIndexPath) -> UITableViewCell {
        let (dataSource, localIndexPath) = dataSourceForGlobalIndexPath(globalIndexPath)
        return dataSource.tableView(tableView, cellForRowAtIndexPath: localIndexPath)
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection globalSection: Int) -> String? {
        let (dataSource, localSection) = dataSourceForGlobalSection(globalSection)
        return dataSource.tableView?(tableView, titleForHeaderInSection: localSection)
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath globalIndexPath: NSIndexPath) -> Bool {
        let (dataSource, localIndexPath) = dataSourceForGlobalIndexPath(globalIndexPath)
        if let canEdit = dataSource.tableView?(tableView, canEditRowAtIndexPath: localIndexPath) {
            return canEdit
        } else {
            return false
        }
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath globalIndexPath: NSIndexPath) {
        let (dataSource, localIndexPath) = dataSourceForGlobalIndexPath(globalIndexPath)
        dataSource.tableView?(tableView, commitEditingStyle: editingStyle, forRowAtIndexPath: localIndexPath)
    }
    
    func tableView(tableView: UITableView, canMoveRowAtIndexPath globalIndexPath: NSIndexPath) -> Bool {
        let (dataSource, localIndexPath) = dataSourceForGlobalIndexPath(globalIndexPath)
        if let canMove = dataSource.tableView?(tableView, canMoveRowAtIndexPath: localIndexPath) {
            return canMove
        } else {
            return dataSource.respondsToSelector("tableView:moveRowAtIndexPath:toIndexPath:")
        }
    }
    
    func tableView(tableView: UITableView, targetIndexPathForMoveFromRowAtIndexPath globalFromIndexPath: NSIndexPath, toProposedIndexPath globalToIndexPath: NSIndexPath) -> NSIndexPath {
        let (fromDataSource, localFromIndexPath) = dataSourceForGlobalIndexPath(globalFromIndexPath)
        let (toDataSource, localToIndexPath) = dataSourceForGlobalIndexPath(globalToIndexPath)
        if !fromDataSource.isEqual(toDataSource) {
            if globalFromIndexPath.section < globalToIndexPath.section {
                // We're dragging above the fromDataSource; pin to the top.
                return globalize(fromDataSource, NSIndexPath(forRow: 0, inSection: 0))
            } else {
                // We're dragging below the fromDataSource; pin to the bottom.
                let lastSection = fromDataSource.numberOfSections - 1
                let lastRow = fromDataSource.tableView(tableView, numberOfRowsInSection: lastSection)
                return globalize(fromDataSource, NSIndexPath(forRow: lastRow, inSection: lastSection))
            }
        } else if let target = toDataSource.tableView?(tableView, targetIndexPathForMoveFromRowAtIndexPath: localFromIndexPath, toProposedIndexPath: localToIndexPath) {
            return target
        } else {
            return globalToIndexPath
        }
    }
    
    func tableView(tableView: UITableView, moveRowAtIndexPath globalFromIndexPath: NSIndexPath, toIndexPath globalToIndexPath: NSIndexPath) {
        let (fromDataSource, localFromIndexPath) = dataSourceForGlobalIndexPath(globalFromIndexPath)
        let (toDataSource, localToIndexPath) = dataSourceForGlobalIndexPath(globalToIndexPath)
        assert(fromDataSource.isEqual(toDataSource), "cannot move between data sources")
        fromDataSource.tableView!(tableView, moveRowAtIndexPath: localFromIndexPath, toIndexPath: localToIndexPath)
    }
}

// MARK: - DataSourceDelegate

extension CompoundDataSource: DataSourceDelegate {
    func dataSource(localDataSource: DataSource, didInsertItemsAtIndexPaths localIndexPaths: [NSIndexPath]) {
        delegate?.dataSource?(self, didInsertItemsAtIndexPaths: globalize(localDataSource, localIndexPaths))
    }
    
    func dataSource(localDataSource: DataSource, didRemoveItemsAtIndexPaths localIndexPaths: [NSIndexPath]) {
        delegate?.dataSource?(self, didRemoveItemsAtIndexPaths: globalize(localDataSource, localIndexPaths))
    }
    
    func dataSource(localDataSource: DataSource, didRefreshItemsAtIndexPaths localIndexPaths: [NSIndexPath]) {
        delegate?.dataSource?(self, didRefreshItemsAtIndexPaths: globalize(localDataSource, localIndexPaths))
    }

    func dataSource(localDataSource: DataSource, didMoveItemAtIndexPath fromLocalIndexPath: NSIndexPath, toIndexPath toLocalIndexPath: NSIndexPath) {
        delegate?.dataSource?(self, didMoveItemAtIndexPath: globalize(localDataSource, fromLocalIndexPath), toIndexPath: globalize(localDataSource, toLocalIndexPath))
    }
    
    func dataSource(localDataSource: DataSource, didInsertSections localSections: NSIndexSet) {
        shiftStartingGlobalSectionsStartingAfterDataSource(localDataSource, by: localSections.count)
        delegate?.dataSource?(self, didInsertSections: globalize(localDataSource, localSections))
    }
    
    func dataSource(localDataSource: DataSource, didRemoveSections localSections: NSIndexSet) {
        shiftStartingGlobalSectionsStartingAfterDataSource(localDataSource, by: -localSections.count)
        delegate?.dataSource?(self, didRemoveSections: globalize(localDataSource, localSections))
    }
    
    func dataSource(localDataSource: DataSource, didRefreshSections localSections: NSIndexSet) {
        delegate?.dataSource?(self, didRefreshSections: globalize(localDataSource, localSections))
    }
    
    func dataSource(localDataSource: DataSource, didMoveSection fromLocalSection: Int, toSection toLocalSection: Int) {
        delegate?.dataSource?(self, didMoveSection: globalize(localDataSource, fromLocalSection), toSection: globalize(localDataSource, toLocalSection))
    }
    
    func dataSourceDidReloadData(localDataSource: DataSource) {
        // Reload the sections that stayed; insert/remove any sections beyond.
        let oldNumberOfSections = numberOfGlobalSectionsForDataSource(localDataSource)
        let newNumberOfSections = localDataSource.numberOfSections
        let localRefreshSections = NSIndexSet(indexesInRange: NSRange(location: 0, length: min(oldNumberOfSections, newNumberOfSections)))
        let deltaSections = newNumberOfSections - oldNumberOfSections
        var otherRange = NSRange(location: oldNumberOfSections, length: abs(deltaSections))
        dataSource(localDataSource, performBatchUpdates: {
            self.dataSource(localDataSource, didRefreshSections: localRefreshSections)
            if deltaSections < 0 {
                otherRange.location += deltaSections
                self.dataSource(localDataSource, didRemoveSections: NSIndexSet(indexesInRange: otherRange))
            } else if deltaSections > 0 {
                self.dataSource(localDataSource, didInsertSections: NSIndexSet(indexesInRange: otherRange))
            }
        }, completion: nil)
    }
    
    func dataSource(localDataSource: DataSource, performBatchUpdates updates: () -> Void, completion: (() -> Void)?) {
        delegate?.dataSource?(self, performBatchUpdates: updates, completion: completion)
    }
}
