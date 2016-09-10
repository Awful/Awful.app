//  CompoundDataSource.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class CompoundDataSource: NSObject {
    fileprivate let dataSources = NSMutableOrderedSet()
    
    var numberOfSections: Int {
        return (dataSources.array as! [DataSource]).reduce(0) { $0 + $1.numberOfSections }
    }

    func addDataSource(_ dataSource: DataSource) {
        assert(!dataSources.contains(dataSource), "data source \(dataSource) is already here")
        let firstNewGlobalSection = numberOfSections
        dataSources.add(dataSource)
        dataSource.delegate = self
        let newSections = IndexSet(integersIn: NSRange(location: firstNewGlobalSection, length: dataSource.numberOfSections).toRange() ?? 0..<0)
        delegate?.dataSource?(self, didInsertSections: newSections)
    }
    
    func removeDataSource(_ dataSource: DataSource) {
        let index = dataSources.index(of: dataSource)
        assert(index != NSNotFound, "data source \(dataSource) was never here")
        let firstOldGlobalSection = (dataSources.array as! [DataSource])[0..<index].reduce(0) { $0 + $1.numberOfSections }
        dataSources.removeObject(at: index)
        dataSource.delegate = nil
        let oldSections = IndexSet(integersIn: NSRange(location: firstOldGlobalSection, length: dataSource.numberOfSections).toRange() ?? 0..<0)
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
    
    fileprivate func dataSourceForGlobalSection(_ globalSection: Int) -> (DataSource, localSection: Int) {
        assert(globalSection < numberOfSections)
        let index = nearestStartingGlobalSectionForGlobalSection(globalSection)
        let sectionsBeforeDataSource = (dataSources.array as! [DataSource])[0..<index].reduce(0) { $0 + $1.numberOfSections }
        return (dataSources.object(at: index) as! DataSource, localSection: globalSection - sectionsBeforeDataSource)
    }
    
    fileprivate func nearestStartingGlobalSectionForGlobalSection(_ globalSection: Int) -> Int {
        var sectionsSoFar = 0
        for (i, dataSource) in (dataSources.array as! [DataSource]).enumerated() {
            sectionsSoFar += dataSource.numberOfSections
            if sectionsSoFar > globalSection {
                return i
            }
        }
        return 0
    }
    
    fileprivate func dataSourceForGlobalIndexPath(_ indexPath: IndexPath) -> (DataSource, localIndexPath: IndexPath) {
        let (dataSource, localSection) = dataSourceForGlobalSection((indexPath as NSIndexPath).section)
        return (dataSource, localIndexPath: IndexPath(row: (indexPath as NSIndexPath).row, section: localSection))
    }
    
    fileprivate func startingGlobalSectionForDataSource(_ dataSource: DataSource) -> Int {
        let index = dataSources.index(of: dataSource)
        assert(index != NSNotFound)
        return (dataSources.array as! [DataSource])[0..<index].reduce(0) { $0 + $1.numberOfSections }
    }
    
    fileprivate func globalize(_ localDataSource: DataSource, _ localIndexPaths: [IndexPath]) -> [IndexPath] {
        let globalOffset = startingGlobalSectionForDataSource(localDataSource)
        return localIndexPaths.map { IndexPath(row: $0.row, section: $0.section + globalOffset) }
    }

    fileprivate func globalize(_ localDataSource: DataSource, _ localIndexPath: IndexPath) -> IndexPath {
        return globalize(localDataSource, [localIndexPath]).first!
    }
    
    fileprivate func globalize(_ localDataSource: DataSource, _ localSections: IndexSet) -> IndexSet {
        var globalSections = localSections
        let globalOffset = startingGlobalSectionForDataSource(localDataSource)
        globalSections.shift(startingAt: globalSections.first!, by: globalOffset)
        return globalSections
    }
    
    fileprivate func globalize(_ localDataSource: DataSource, _ localSection: Int) -> Int {
        return globalize(localDataSource, IndexSet(integer: localSection)).first!
    }
    
    fileprivate func numberOfGlobalSectionsForDataSource(_ localDataSource: DataSource) -> Int {
        let index = dataSources.index(of: localDataSource)
        assert(index != NSNotFound)
        if index + 1 == dataSources.count {
            return numberOfSections - startingGlobalSectionForDataSource(localDataSource)
        } else {
            let nextDataSource = dataSources.object(at: index + 1) as! DataSource
            return startingGlobalSectionForDataSource(nextDataSource) - startingGlobalSectionForDataSource(localDataSource)
        }
    }
}

// MARK: - DataSource

extension CompoundDataSource: DataSource {
    func itemAtIndexPath(_ globalIndexPath: IndexPath) -> AnyObject {
        let (dataSource, localIndexPath) = dataSourceForGlobalIndexPath(globalIndexPath)
        return dataSource.itemAtIndexPath(localIndexPath)
    }
    
    func indexPathsForItem(_ item: AnyObject) -> [IndexPath] {
        let typedDataSources = self.dataSources.array as! [DataSource]
        return typedDataSources.reduce([]) { $0 + self.globalize($1, $1.indexPathsForItem(item)) }
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath globalIndexPath: IndexPath) -> String {
        let (dataSource, localIndexPath) = dataSourceForGlobalIndexPath(globalIndexPath)
        return dataSource.tableView?(tableView, titleForDeleteConfirmationButtonForRowAtIndexPath: localIndexPath) ?? "Delete"
    }
}

extension CompoundDataSource: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return numberOfSections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection globalSection: Int) -> Int {
        let (dataSource, localSection) = dataSourceForGlobalSection(globalSection)
        return dataSource.tableView(tableView, numberOfRowsInSection: localSection)
    }

    func tableView(_ tableView: UITableView, cellForRowAt globalIndexPath: IndexPath) -> UITableViewCell {
        let (dataSource, localIndexPath) = dataSourceForGlobalIndexPath(globalIndexPath)
        return dataSource.tableView(tableView, cellForRowAt: localIndexPath)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection globalSection: Int) -> String? {
        let (dataSource, localSection) = dataSourceForGlobalSection(globalSection)
        return dataSource.tableView?(tableView, titleForHeaderInSection: localSection)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt globalIndexPath: IndexPath) -> Bool {
        let (dataSource, localIndexPath) = dataSourceForGlobalIndexPath(globalIndexPath)
        if let canEdit = dataSource.tableView?(tableView, canEditRowAt: localIndexPath) {
            return canEdit
        } else {
            return false
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt globalIndexPath: IndexPath) {
        let (dataSource, localIndexPath) = dataSourceForGlobalIndexPath(globalIndexPath)
        dataSource.tableView?(tableView, commit: editingStyle, forRowAt: localIndexPath)
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt globalIndexPath: IndexPath) -> Bool {
        let (dataSource, localIndexPath) = dataSourceForGlobalIndexPath(globalIndexPath)
        if let canMove = dataSource.tableView?(tableView, canMoveRowAt: localIndexPath) {
            return canMove
        } else {
            return dataSource.responds(to: #selector(UITableViewDataSource.tableView(_:moveRowAt:to:)))
        }
    }
    
    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAtIndexPath globalFromIndexPath: IndexPath, toProposedIndexPath globalToIndexPath: IndexPath) -> IndexPath {
        let (fromDataSource, localFromIndexPath) = dataSourceForGlobalIndexPath(globalFromIndexPath)
        let (toDataSource, localToIndexPath) = dataSourceForGlobalIndexPath(globalToIndexPath)
        if !fromDataSource.isEqual(toDataSource) {
            if (globalFromIndexPath as NSIndexPath).section < (globalToIndexPath as NSIndexPath).section {
                // We're dragging above the fromDataSource; pin to the top.
                return globalize(fromDataSource, IndexPath(row: 0, section: 0))
            } else {
                // We're dragging below the fromDataSource; pin to the bottom.
                let lastSection = fromDataSource.numberOfSections - 1
                let lastRow = fromDataSource.tableView(tableView, numberOfRowsInSection: lastSection)
                return globalize(fromDataSource, IndexPath(row: lastRow, section: lastSection))
            }
        } else if let target = toDataSource.tableView?(tableView, targetIndexPathForMoveFromRowAtIndexPath: localFromIndexPath, toProposedIndexPath: localToIndexPath) {
            return target
        } else {
            return globalToIndexPath
        }
    }
    
    func tableView(_ tableView: UITableView, moveRowAt globalFromIndexPath: IndexPath, to globalToIndexPath: IndexPath) {
        let (fromDataSource, localFromIndexPath) = dataSourceForGlobalIndexPath(globalFromIndexPath)
        let (toDataSource, localToIndexPath) = dataSourceForGlobalIndexPath(globalToIndexPath)
        assert(fromDataSource.isEqual(toDataSource), "cannot move between data sources")
        fromDataSource.tableView!(tableView, moveRowAt: localFromIndexPath, to: localToIndexPath)
    }
}

// MARK: - DataSourceDelegate

extension CompoundDataSource: DataSourceDelegate {
    func dataSource(_ localDataSource: DataSource, didInsertItemsAtIndexPaths localIndexPaths: [IndexPath]) {
        delegate?.dataSource?(self, didInsertItemsAtIndexPaths: globalize(localDataSource, localIndexPaths))
    }
    
    func dataSource(_ localDataSource: DataSource, didRemoveItemsAtIndexPaths localIndexPaths: [IndexPath]) {
        delegate?.dataSource?(self, didRemoveItemsAtIndexPaths: globalize(localDataSource, localIndexPaths))
    }
    
    func dataSource(_ localDataSource: DataSource, didRefreshItemsAtIndexPaths localIndexPaths: [IndexPath]) {
        delegate?.dataSource?(self, didRefreshItemsAtIndexPaths: globalize(localDataSource, localIndexPaths))
    }

    func dataSource(_ localDataSource: DataSource, didMoveItemAtIndexPath fromLocalIndexPath: IndexPath, toIndexPath toLocalIndexPath: IndexPath) {
        delegate?.dataSource?(self, didMoveItemAtIndexPath: globalize(localDataSource, fromLocalIndexPath), toIndexPath: globalize(localDataSource, toLocalIndexPath))
    }
    
    func dataSource(_ localDataSource: DataSource, didInsertSections localSections: IndexSet) {
        delegate?.dataSource?(self, didInsertSections: globalize(localDataSource, localSections))
    }
    
    func dataSource(_ localDataSource: DataSource, didRemoveSections localSections: IndexSet) {
        delegate?.dataSource?(self, didRemoveSections: globalize(localDataSource, localSections))
    }
    
    func dataSource(_ localDataSource: DataSource, didRefreshSections localSections: IndexSet) {
        delegate?.dataSource?(self, didRefreshSections: globalize(localDataSource, localSections))
    }
    
    func dataSource(_ localDataSource: DataSource, didMoveSection fromLocalSection: Int, toSection toLocalSection: Int) {
        delegate?.dataSource?(self, didMoveSection: globalize(localDataSource, fromLocalSection), toSection: globalize(localDataSource, toLocalSection))
    }
    
    func dataSourceDidReloadData(_ localDataSource: DataSource) {
        // Reload the sections that stayed; insert/remove any sections beyond.
        let oldNumberOfSections = numberOfGlobalSectionsForDataSource(localDataSource)
        let newNumberOfSections = localDataSource.numberOfSections
        let localRefreshSections = IndexSet(integersIn: NSRange(location: 0, length: min(oldNumberOfSections, newNumberOfSections)).toRange() ?? 0..<0)
        let deltaSections = newNumberOfSections - oldNumberOfSections
        var otherRange = NSRange(location: oldNumberOfSections, length: abs(deltaSections))
        dataSource(localDataSource, performBatchUpdates: {
            self.dataSource(localDataSource, didRefreshSections: localRefreshSections)
            if deltaSections < 0 {
                otherRange.location += deltaSections
                self.dataSource(localDataSource, didRemoveSections: IndexSet(integersIn: otherRange.toRange() ?? 0..<0))
            } else if deltaSections > 0 {
                self.dataSource(localDataSource, didInsertSections: IndexSet(integersIn: otherRange.toRange() ?? 0..<0))
            }
        }, completion: nil)
    }
    
    func dataSource(_ localDataSource: DataSource, performBatchUpdates updates: () -> Void, completion: (() -> Void)?) {
        delegate?.dataSource?(self, performBatchUpdates: updates, completion: completion)
    }
}
