//
//  ComposedDataSource.swift
//  ComposeKit
//
//  Copyright (c) 2017 Stan Chang Khin Boon (http://lxcid.com/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import UIKit

open class ComposedDataSource : DataSource {
    var mappings = [DataSourceMapping]()
    let dataSourceToMappings = NSMapTable<DataSource, DataSourceMapping>(keyOptions: [.objectPointerPersonality], valueOptions: [.strongMemory], capacity: 1)
    var globalSectionToMappings = [Int : DataSourceMapping]()
    
    fileprivate var _numberOfSections: Int = 0
    override open var numberOfSections: Int {
        self.updateMappings()
        return _numberOfSections
    }
    
    fileprivate func updateMappings() {
        self._numberOfSections = 0
        self.globalSectionToMappings.removeAll()
        
        for mapping in self.mappings {
            mapping.updateMappingStartingAtGlobalSection(self._numberOfSections) { (globalSection) in
                self.globalSectionToMappings[globalSection] = mapping
            }
            self._numberOfSections += mapping.numberOfSections
        }
    }
    
    func sectionForDataSource(_ dataSource: DataSource) -> Int {
        let mapping = self.mappingForDataSource(dataSource)!
        return mapping.globalSectionForLocalSection(0)
    }
    
    func localIndexPathForGlobalIndexPath(_ globalIndexPath: IndexPath) -> IndexPath? {
        let mapping = self.mappingForGlobalSection(globalIndexPath.section)
        return mapping?.localIndexPathForGlobalIndexPath(globalIndexPath)
    }
    
    func mappingForGlobalSection(_ globalSection: Int) -> DataSourceMapping? {
        let mapping = self.globalSectionToMappings[globalSection]
        return mapping
    }
    
    func mappingForDataSource(_ dataSource: DataSource) -> DataSourceMapping? {
        let mapping = self.dataSourceToMappings.object(forKey: dataSource)
        return mapping
    }
    
    func globalSectionsForLocalSections(_ localSections: IndexSet, dataSource: DataSource) -> IndexSet {
        var result = IndexSet()
        let mapping = self.mappingForDataSource(dataSource)!
        localSections.forEach { (localSection) -> Void in
            let globalSection = mapping.globalSectionForLocalSection(localSection)
            result.insert(globalSection)
        }
        return result
    }
    
    func globalIndexPathsForLocalIndexPaths(_ localIndexPaths: [IndexPath], dataSource: DataSource) -> [IndexPath] {
        var result = [IndexPath]()
        let mapping = self.mappingForDataSource(dataSource)!
        for localIndexPath in localIndexPaths {
            let globalIndexPath = mapping.globalIndexPathForLocalIndexPath(localIndexPath)
            result.append(globalIndexPath)
        }
        return result
    }
    
    func enumerateDataSourcesWithBlock(_ block: (DataSource, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop = ObjCBool(false)
        let enumerator = self.dataSourceToMappings.keyEnumerator()
        
        while let key = enumerator.nextObject() as! DataSource? {
            let mapping = self.dataSourceToMappings.object(forKey: key)!
            block(mapping.dataSource, &stop)
            if stop.boolValue {
                break
            }
        }
    }
    
    // MARK: Overrides
    
    override open func numberOfItemsInSection(_ sectionIndex: Int) -> Int {
        self.updateMappings()
        
        let mapping = self.mappingForGlobalSection(sectionIndex)!
        let localSection = mapping.localSectionForGlobalSection(sectionIndex)!
        assert(localSection < mapping.dataSource.numberOfSections, "local section \(localSection) is out of bounds for composed data source \(numberOfSections)")
        return mapping.dataSource.numberOfItemsInSection(localSection)
    }
    
    override open func itemAtIndexPath(_ indexPath: IndexPath) -> ItemType? {
        if let mapping = self.mappingForGlobalSection(indexPath.section), let mappedIndexPath = mapping.localIndexPathForGlobalIndexPath(indexPath) {
            return mapping.dataSource.itemAtIndexPath(mappedIndexPath)
        } else {
            return nil
        }
    }
    
    override open func indexPathsForItem(_ item: ItemType) -> [IndexPath] {
        var results = [IndexPath]()
        self.enumerateDataSourcesWithBlock { (dataSource, stop) in
            let mapping = self.mappingForDataSource(dataSource)!
            let localIndexPaths = dataSource.indexPathsForItem(item)
            if localIndexPaths.isEmpty {
                return;
            }
            for localIndexPath in localIndexPaths {
                let globalIndexPath = mapping.globalIndexPathForLocalIndexPath(localIndexPath)
                results.append(globalIndexPath)
            }
        }
        return results
    }
    
    override open func didBecomeActive() {
        super.didBecomeActive()
        self.enumerateDataSourcesWithBlock { (dataSource, stop) in
            dataSource.didBecomeActive()
        }
    }
    
    override open func willResignActive() {
        super.willResignActive()
        self.enumerateDataSourcesWithBlock { (dataSource, stop) in
            dataSource.willResignActive()
        }
    }
    
    override open func dataSourceForSectionAtIndex(_ sectionIndex: Int) -> DataSource {
        let mapping = self.globalSectionToMappings[sectionIndex]!
        return mapping.dataSource
    }
    
    override open func registerReusableViewsWithCollectionView(_ collectionView: UICollectionView) {
        super.registerReusableViewsWithCollectionView(collectionView)
        self.enumerateDataSourcesWithBlock { (dataSource, stop) in
            dataSource.registerReusableViewsWithCollectionView(collectionView)
        }
    }
    
    override open func registerReusableViewsWithTableView(_ tableView: UITableView) {
        super.registerReusableViewsWithTableView(tableView)
        self.enumerateDataSourcesWithBlock { (dataSource, stop) -> Void in
            dataSource.registerReusableViewsWithTableView(tableView)
        }
    }
    
    // MARK: Content Loading
    
    override open func loadContent() {
        super.loadContent()
        self.enumerateDataSourcesWithBlock { (dataSource, stop) in
            dataSource.loadContent()
        }
    }
    
    override open func resetContent() {
        super.resetContent()
        self.enumerateDataSourcesWithBlock { (dataSource, stop) in
            dataSource.resetContent()
        }
    }
    
    // MARK : UICollectionViewDataSource
    
    override open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        //self.updateMappings()
        
        // FIXME: (khinboon@d--buzz.com) When we're showing a placeholder, we have to lie to the collection view about the number of items we have. Otherwise, it will ask for layout attributes that we don't have.
        //if self.shouldShowPlaceholder {
        //    return 0
        //}
        
        let mapping = self.mappingForGlobalSection(section)!
        let dataSource = mapping.dataSource
        let localSection = mapping.localSectionForGlobalSection(section)!
        return dataSource.collectionView(collectionView, numberOfItemsInSection: localSection)
    }
    
    override open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let mapping = self.mappingForGlobalSection(indexPath.section)!
        let dataSource = mapping.dataSource
        let localIndexPath = mapping.localIndexPathForGlobalIndexPath(indexPath)!
        return dataSource.collectionView(collectionView, cellForItemAt: localIndexPath)
    }
    
    // MARK: UITableViewDataSource
    
    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //self.updateMappings()
        
        // FIXME: (khinboon@d--buzz.com) When we're showing a placeholder, we have to lie to the collection view about the number of items we have. Otherwise, it will ask for layout attributes that we don't have.
        //if self.shouldShowPlaceholder {
        //    return 0
        //}
        
        let mapping = self.mappingForGlobalSection(section)!
        let dataSource = mapping.dataSource
        let localSection = mapping.localSectionForGlobalSection(section)!
        return dataSource.tableView(tableView, numberOfRowsInSection: localSection)
    }
    
    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let mapping = self.mappingForGlobalSection(indexPath.section)!
        let dataSource = mapping.dataSource
        let localIndexPath = mapping.localIndexPathForGlobalIndexPath(indexPath)!
        return dataSource.tableView(tableView, cellForRowAt: localIndexPath)
    }
    
    override open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let mapping = self.mappingForGlobalSection(section)!
        let dataSource = mapping.dataSource
        let localSection = mapping.localSectionForGlobalSection(section)!
        return dataSource.tableView(tableView, titleForHeaderInSection: localSection)
    }
    
    override open func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let mapping = self.mappingForGlobalSection(section)!
        let dataSource = mapping.dataSource
        let localSection = mapping.localSectionForGlobalSection(section)!
        return dataSource.tableView(tableView, titleForFooterInSection: localSection)
    }
    
    // MARK: UITableViewDelegate
    
    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let mapping = self.mappingForGlobalSection(indexPath.section)!
        let dataSource = mapping.dataSource
        let localIndexPath = mapping.localIndexPathForGlobalIndexPath(indexPath)!
        return dataSource.tableView(tableView, didSelectRowAt: localIndexPath)
    }
    
    override open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let mapping = self.mappingForGlobalSection(section)!
        let dataSource = mapping.dataSource
        let localSection = mapping.localSectionForGlobalSection(section)!
        return dataSource.tableView(tableView, viewForHeaderInSection: localSection)
    }
    
    override open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let mapping = self.mappingForGlobalSection(section)!
        let dataSource = mapping.dataSource
        let localSection = mapping.localSectionForGlobalSection(section)!
        return dataSource.tableView(tableView, heightForHeaderInSection: localSection)
    }
    
    override open func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let mapping = self.mappingForGlobalSection(indexPath.section)!
        let dataSource = mapping.dataSource
        let localIndexPath = mapping.localIndexPathForGlobalIndexPath(indexPath)!
        return dataSource.tableView(tableView, shouldHighlightRowAt: localIndexPath)
    }
    
    // MARK: Public
    
    open func addDataSource(_ dataSource: DataSource) {
        dataSource.delegate = self
        
        assert(self.dataSourceToMappings.object(forKey: dataSource) == nil, "tried to add data source more than once: \(dataSource)")
        
        let mappingForDataSource = DataSourceMapping(dataSource: dataSource)
        self.mappings.append(mappingForDataSource)
        self.dataSourceToMappings.setObject(mappingForDataSource, forKey: dataSource)
        
        self.updateMappings()
        var addedSections = IndexSet()
        let numberOfSections = dataSource.numberOfSections
        
        for localSection in 0..<numberOfSections {
            let globalSection = mappingForDataSource.globalSectionForLocalSection(localSection)
            addedSections.insert(globalSection)
        }
        self.notifySectionsInserted(addedSections)
    }
    
    open func removeDataSource(_ dataSource: DataSource) {
        if let mappingForDataSource = self.dataSourceToMappings.object(forKey: dataSource) {
            var removedSections = IndexSet()
            let numberOfSections = dataSource.numberOfSections
            
            for localSection in 0..<numberOfSections {
                let globalSection = mappingForDataSource.globalSectionForLocalSection(localSection)
                removedSections.insert(globalSection)
            }
            
            self.dataSourceToMappings.removeObject(forKey: dataSource)
            let index = self.mappings.index(of: mappingForDataSource)!
            self.mappings.remove(at: index)
            
            dataSource.delegate = nil
            
            self.updateMappings()
            self.notifySectionsRemoved(removedSections)
        } else {
            assertionFailure("Data source not found in mapping")
        }
    }
}

extension ComposedDataSource : DataSourceDelegate {
    public func dataSource(_ dataSource: DataSource, didInsertItemsAtIndexPaths indexPaths: [IndexPath]) {
        let mapping = self.mappingForDataSource(dataSource)!
        let globalIndexPaths = mapping.globalIndexPathsForLocalIndexPaths(indexPaths)
        self.notifyItemsInsertedAtIndexPaths(globalIndexPaths)
    }
    
    public func dataSource(_ dataSource: DataSource, didRemoveItemsAtIndexPaths indexPaths: [IndexPath]) {
        let mapping = self.mappingForDataSource(dataSource)!
        let globalIndexPaths = mapping.globalIndexPathsForLocalIndexPaths(indexPaths)
        self.notifyItemsRemovedAtIndexPaths(globalIndexPaths)
    }
    
    public func dataSource(_ dataSource: DataSource, didRefreshItemsAtIndexPaths indexPaths: [IndexPath]) {
        let mapping = self.mappingForDataSource(dataSource)!
        let globalIndexPaths = mapping.globalIndexPathsForLocalIndexPaths(indexPaths)
        self.notifyItemsRefreshedAtIndexPaths(globalIndexPaths)
    }
    
    public func dataSource(_ dataSource: DataSource, didInsertSections sections: IndexSet) {
        let mapping = self.mappingForDataSource(dataSource)!
        // TODO: (khinboon@d--buzz.com) If we nest segmented data source in this composed data source, switching between segment seems to cause mapping to go out of sync. This step is necessary to prevent crashes. When we have time, investigate further.
        self.updateMappings()
        var globalSections = IndexSet()
        sections.forEach { (localSectionIndex) -> Void in
            let globalSectionIndex = mapping.globalSectionForLocalSection(localSectionIndex)
            globalSections.insert(globalSectionIndex)
        }
        self.notifySectionsInserted(globalSections)
    }
    
    public func dataSource(_ dataSource: DataSource, didRemoveSections sections: IndexSet) {
        let mapping = self.mappingForDataSource(dataSource)!
        // In a setup like Composed 1 -> Segmented -> Composed 2, if we remove something from Composed 2, updating mappings here (early) will cause the data source to go out of sync…
        // TODO: (khinboon@d--buzz.com) If we nest segmented data source in this composed data source, switching between segment seems to cause mapping to go out of sync. This step is necessary to prevent crashes. When we have time, investigate further.
        //self.updateMappings()
        var globalSections = IndexSet()
        sections.forEach { (localSectionIndex) -> Void in
            let globalSectionIndex = mapping.globalSectionForLocalSection(localSectionIndex)
            globalSections.insert(globalSectionIndex)
        }
        // We update the mappings here instead.
        self.updateMappings()
        self.notifySectionsRemoved(globalSections)
    }
    
    public func dataSource(_ dataSource: DataSource, didRefreshSections sections: IndexSet) {
        let mapping = self.mappingForDataSource(dataSource)!
        var globalSections = IndexSet()
        sections.forEach { (localSectionIndex) in
            let globalSectionIndex = mapping.globalSectionForLocalSection(localSectionIndex)
            globalSections.insert(globalSectionIndex)
        }
        self.notifySectionsRefreshed(globalSections)
        // TODO: (khinboon@d--buzz.com) We blindly follow the reference implementation. When we have time, investigate further.
        self.updateMappings()
    }
    
    public func dataSourceWillLoadContent(_ dataSource: DataSource) {
        // FIXME: (khinboon@d--buzz.com) Do we need to notify will load content?
    }
    
    public func dataSourceDidReloadData(_ dataSource: DataSource) {
        // FIXME: (khinboon@d--buzz.com) Do we need to do more to notify reload data?
        self.notifyDidReloadData()
    }
    
    public func dataSource(_ dataSource: DataSource, performBatchUpdate update: (() -> Void)?, complete: (() -> Void)?) {
        self.performUpdate(update, complete: complete)
    }
}

extension ComposedDataSource : UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let mapping = self.mappingForGlobalSection(indexPath.section), let localIndexPath = self.localIndexPathForGlobalIndexPath(indexPath), let dataSource = mapping.dataSource.dataSourceForSectionAtIndex(localIndexPath.section) as? UICollectionViewDelegateFlowLayout {
            return dataSource.collectionView!(collectionView, layout: collectionViewLayout, sizeForItemAt: indexPath)
        } else {
            return CGSize.zero
        }
    }
}
