//
//  SegmentedDataSource.swift
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

/** A subclass of `DataSource` with multiple child data sources of which only one will be active at a time.

Only the selected data source will become active. When a new data source is selected, the previously selected data source will receive a `willResignActive()` message before the new data source receives a `didBecomeActive()` message.
*/
open class SegmentedDataSource : DataSource {
    var dataSources = [DataSource]()
    var selectedDataSource: DataSource!
    
    /// The index of the selected data source in the collection.
    open var selectedDataSourceIndex: Int {
        get {
            return self.dataSources.index(of: self.selectedDataSource)!
        }
        set {
            self.setSelectedDataSourceIndex(newValue, animated: false)
        }
    }
    
    override open var allowsSelection: Bool {
        return self.selectedDataSource.allowsSelection
    }
    
    override open var numberOfSections: Int {
        return self.selectedDataSource.numberOfSections
    }
    
    override open func numberOfItemsInSection(_ sectionIndex: Int) -> Int {
        return self.selectedDataSource.numberOfItemsInSection(sectionIndex)
    }
    
    /// Add a data source to the end of the collection. The title property of the data source will be used to populate a new segment in the `UISegmentedControl` associated with this data source.
    open func addDataSource(_ dataSource: DataSource) {
        let firstDataSourceToBeAdded = self.dataSources.isEmpty
        self.dataSources.append(dataSource)
        dataSource.delegate = self
        if firstDataSourceToBeAdded {
            self.selectedDataSource = dataSource
        }
    }
    
    /// Remove the data source from the collection.
    open func removeDataSource(_ dataSource: DataSource) {
        if let index = self.dataSources.index(of: dataSource) {
            self.dataSources.remove(at: index)
        }
        if dataSource.delegate === self {
            dataSource.delegate = nil
        }
    }
    
    /// Clear the collection of data sources.
    open func removeAllDataSources() {
        for dataSource in self.dataSources {
            if dataSource.delegate === self {
                dataSource.delegate = nil
            }
        }
        self.dataSources.removeAll()
        self.selectedDataSource = nil
    }
    
    func dataSourceAtIndex(_ dataSourceIndex: Int) -> DataSource {
        return self.dataSources[dataSourceIndex]
    }
    
    func setSelectedDataSourceIndex(_ selectedDataSourceIndex: Int, animated: Bool) {
        let selectedDataSource = self.dataSources[selectedDataSourceIndex]
        self.setSelectedDataSource(selectedDataSource, animated: animated, completionHandler: nil)
    }
    
    func setSelectedDataSource(_ selectedDataSource: DataSource, animated: Bool, completionHandler: (() -> Void)?) {
        if self.selectedDataSource === selectedDataSource {
            completionHandler?()
            return
        }
        
        assert(self.dataSources.contains(selectedDataSource), "selected data source must be contained in this data source")
        
        let prevSelectedDataSource = self.selectedDataSource
        let numberOfSectionsToBeRemoved = prevSelectedDataSource?.numberOfSections ?? 0
        let numberOfSectionsToBeInserted = selectedDataSource.numberOfSections
        
        // NOTE: (khinboon@d--buzz.com) Decides the animation here
        
        let optRemovedSet: IndexSet? = (numberOfSectionsToBeRemoved > 0) ? IndexSet(integersIn: NSMakeRange(0, numberOfSectionsToBeRemoved).toRange()!) : nil
        let optInsertedSet: IndexSet? = (numberOfSectionsToBeInserted > 0) ? IndexSet(integersIn: NSMakeRange(0, numberOfSectionsToBeInserted).toRange()!) : nil
        
        // Update the sections all at once.
        self.performUpdate({
            prevSelectedDataSource?.willResignActive()
            
            if let removedSet = optRemovedSet {
                self.notifySectionsRemoved(removedSet)
            }
            
            // NOTE: (khinboon@d--buzz.com) KVO will change for `selectedDataSource` and `selectedDataSourceIndex`
            self.selectedDataSource = selectedDataSource
            // NOTE: (khinboon@d--buzz.com) KVO did change for `selectedDataSource` and `selectedDataSourceIndex`
            
            if let insertedSet = optInsertedSet {
                self.notifySectionsInserted(insertedSet)
            }
            
            selectedDataSource.didBecomeActive()
        }, complete: completionHandler)
    }
    
    override open func indexPathsForItem(_ item: ItemType) -> [IndexPath] {
        return self.selectedDataSource.indexPathsForItem(item)
    }
    
    override open func itemAtIndexPath(_ indexPath: IndexPath) -> ItemType? {
        return self.selectedDataSource.itemAtIndexPath(indexPath)
    }
    
    override open func removeItemAtIndexPath(_ indexPath: IndexPath) {
        self.selectedDataSource.removeItemAtIndexPath(indexPath)
    }
    
    override open func didBecomeActive() {
        super.didBecomeActive()
        self.selectedDataSource.didBecomeActive()
    }
    
    override open func willResignActive() {
        super.willResignActive()
        self.selectedDataSource.willResignActive()
    }
    
    open func configureSegmentedControl(_ segmentedControl: UISegmentedControl) {
        let titles = self.dataSources.map { $0.title ?? "NULL" }
        
        segmentedControl.removeAllSegments()
        for (index, title) in titles.enumerated() {
            segmentedControl.insertSegment(withTitle: title, at: index, animated: false)
        }
        segmentedControl.addTarget(self, action: #selector(SegmentedDataSource.selectedSegmentIndexChanged(_:)), for: .valueChanged)
        segmentedControl.selectedSegmentIndex = self.selectedDataSourceIndex;
        segmentedControl.selectedSegmentIndex = self.selectedDataSourceIndex
    }
    
    override open func registerReusableViewsWithCollectionView(_ collectionView: UICollectionView) {
        super.registerReusableViewsWithCollectionView(collectionView)
        for dataSource in self.dataSources {
            dataSource.registerReusableViewsWithCollectionView(collectionView)
        }
    }
    
    override open func registerReusableViewsWithTableView(_ tableView: UITableView) {
        super.registerReusableViewsWithTableView(tableView)
        for dataSource in self.dataSources {
            dataSource.registerReusableViewsWithTableView(tableView)
        }
    }
    
    override open func dataSourceForSectionAtIndex(_ sectionIndex: Int) -> DataSource {
        return self.selectedDataSource.dataSourceForSectionAtIndex(sectionIndex)
    }
    
    override open func loadContent() {
        self.selectedDataSource.loadContent()
    }
    
    // MARK : Actions
    
    func selectedSegmentIndexChanged(_ sender: AnyObject) {
        guard let segmentedControl = sender as? UISegmentedControl else {
            return
        }
        
        segmentedControl.isUserInteractionEnabled = false
        let selectedSegmentIndex = segmentedControl.selectedSegmentIndex
        let dataSource = self.dataSources[selectedSegmentIndex]
        self.setSelectedDataSource(dataSource, animated: true) {
            segmentedControl.isUserInteractionEnabled = true
        }
    }
    
    // MARK : UICollectionViewDataSource
    
    override open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // NOTE: (khinboon@d--buzz.com) When we're showing a placeholder, we have to lie to the collection view about the number of items we have. Otherwise, it will ask for layout attributes that we don't have.
        return self.selectedDataSource.collectionView(collectionView, numberOfItemsInSection: section)
    }
    
    override open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return self.selectedDataSource.collectionView(collectionView, cellForItemAt: indexPath)
    }
    
    // MARK: UITableViewDataSource
    
    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // NOTE: (khinboon@d--buzz.com) When we're showing a placeholder, we have to lie to the collection view about the number of items we have. Otherwise, it will ask for layout attributes that we don't have.
        return self.selectedDataSource.tableView(tableView, numberOfRowsInSection: section)
    }
    
    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return self.selectedDataSource.tableView(tableView, cellForRowAt: indexPath)
    }
    
    // MARK: UITableViewDelegate
    
    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedDataSource.tableView(tableView, didSelectRowAt: indexPath)
    }
    
    override open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return self.selectedDataSource.tableView(tableView, viewForHeaderInSection: section)
    }
    
    override open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return self.selectedDataSource.tableView(tableView, heightForHeaderInSection: section)
    }
    
    override open func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return self.selectedDataSource.tableView(tableView, shouldHighlightRowAt: indexPath)
    }
}

extension SegmentedDataSource : DataSourceDelegate {
    public func dataSource(_ dataSource: DataSource, didInsertItemsAtIndexPaths indexPaths: [IndexPath]) {
        guard dataSource === self.selectedDataSource else {
            return
        }
        self.notifyItemsInsertedAtIndexPaths(indexPaths)
    }
    
    public func dataSource(_ dataSource: DataSource, didRemoveItemsAtIndexPaths indexPaths: [IndexPath]) {
        guard dataSource === self.selectedDataSource else {
            return
        }
        self.notifyItemsRemovedAtIndexPaths(indexPaths)
    }
    
    public func dataSource(_ dataSource: DataSource, didRefreshItemsAtIndexPaths indexPaths: [IndexPath]) {
        guard dataSource === self.selectedDataSource else {
            return
        }
        self.notifyItemsRefreshedAtIndexPaths(indexPaths)
    }
    
    public func dataSource(_ dataSource: DataSource, didInsertSections sections: IndexSet) {
        guard dataSource === self.selectedDataSource else {
            return
        }
        self.notifySectionsInserted(sections)
    }
    
    public func dataSource(_ dataSource: DataSource, didRemoveSections sections: IndexSet) {
        guard dataSource === self.selectedDataSource else {
            return
        }
        self.notifySectionsRemoved(sections)
    }
    
    public func dataSource(_ dataSource: DataSource, didRefreshSections sections: IndexSet) {
        guard dataSource === self.selectedDataSource else {
            return
        }
        self.notifySectionsRefreshed(sections)
    }
    
    public func dataSourceWillLoadContent(_ dataSource: DataSource) {
        // FIXME: (khinboon@d--buzz.com) Do we need to notify will load content?
    }
    
    public func dataSourceDidReloadData(_ dataSource: DataSource) {
        guard dataSource === self.selectedDataSource else {
            return
        }
        self.notifyDidReloadData()
    }
    
    public func dataSource(_ dataSource: DataSource, performBatchUpdate update: (() -> Void)?, complete: (() -> Void)?) {
        if dataSource === self.selectedDataSource {
            self.performUpdate(update, complete: complete)
        } else {
            // This isn't the active data source, so just go ahead and update it, because the changes won't be reflected in the collection view.
            update?()
            complete?()
        }
    }
}

extension SegmentedDataSource : UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let dataSource = self.selectedDataSource.dataSourceForSectionAtIndex(indexPath.section) as? UICollectionViewDelegateFlowLayout {
            return dataSource.collectionView!(collectionView, layout: collectionViewLayout, sizeForItemAt: indexPath)
        } else {
            return CGSize.zero
        }
    }
}
