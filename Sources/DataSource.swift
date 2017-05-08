//
//  DataSource.swift
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

@objc public protocol DataSourceDelegate : NSObjectProtocol {
    @objc optional func dataSource(_ dataSource: DataSource, didInsertItemsAtIndexPaths indexPaths: [IndexPath])
    @objc optional func dataSource(_ dataSource: DataSource, didRemoveItemsAtIndexPaths indexPaths: [IndexPath])
    @objc optional func dataSource(_ dataSource: DataSource, didRefreshItemsAtIndexPaths indexPaths: [IndexPath])
    @objc optional func dataSource(_ dataSource: DataSource, didMoveItemAtIndexPath fromIndexPath: IndexPath, toIndexPath newIndexPath: IndexPath)
    
    @objc optional func dataSource(_ dataSource: DataSource, didInsertSections sections: IndexSet)
    @objc optional func dataSource(_ dataSource: DataSource, didRemoveSections sections: IndexSet)
    @objc optional func dataSource(_ dataSource: DataSource, didRefreshSections sections: IndexSet)
    @objc optional func dataSource(_ dataSource: DataSource, didMoveSection section: Int, toSection newSection: Int)
    
    @objc optional func dataSourceDidReloadData(_ dataSource: DataSource)
    
    /// Called just before a datasource begins loading its content.
    @objc optional func dataSourceWillLoadContent(_ dataSource: DataSource)
    /// If the content was loaded successfully, the error will be nil.
    @objc optional func dataSource(_ dataSource: DataSource, didLoadContentWithError error: NSError?)
    
    @objc optional func dataSource(_ dataSource: DataSource, performBatchUpdate update: (() -> Void)?, complete: (() -> Void)?)
}

open class DataSource : NSObject {
    public typealias ItemType = AnyObject
    
    weak open var delegate: DataSourceDelegate?
    
    /// The title of this data source. This value is used to populate section headers and the segmented control tab.
    open var title: String?
    
    open var allowsSelection: Bool {
        return true
    }
    
    /// The number of sections in this data source.
    open var numberOfSections: Int {
        return 1
    }
    
    /// Return the number of items in a specific section. Implement this instead of the UICollectionViewDataSource method.
    open func numberOfItemsInSection(_ sectionIndex: Int) -> Int {
        return 0
    }
    
    /// Find the index paths of the specified item in the data source. An item may appear more than once in a given data source.
    open func indexPathsForItem(_ item: ItemType) -> [IndexPath] {
        fatalError("Should be implemented by subclasses")
    }
    
    /// Find the item at the specified index path. Returns nil when indexPath does not specify a valid item in the data source.
    open func itemAtIndexPath(_ indexPath: IndexPath) -> ItemType? {
        fatalError("Should be implemented by subclasses")
    }
    
    /// Remove an item from the data source. This method should only be called as the result of a user action, such as tapping the "Delete" button in a swipe-to-delete gesture. Automatic removal of items due to outside changes should instead be handled by the data source itself — not the controller. Data sources must implement this to support swipe-to-delete.
    open func removeItemAtIndexPath(_ indexPath: IndexPath) {
        fatalError("Should be implemented by subclasses")
    }
    
    /// Find the data source for the given section. Default implementation returns self.
    open func dataSourceForSectionAtIndex(_ sectionIndex: Int) -> DataSource {
        return self
    }
    
    /// Get an index path for the data source represented by the global index path. This works with `dataSourceForSectionAtIndex(Int)`.
    fileprivate func localIndexPathForGlobalIndexPath(_ globalIndexPath: IndexPath) -> IndexPath {
        return globalIndexPath
    }
    
    //primaryActionsForItemAtIndexPath
    //secondaryActionsForItemAtIndexPath
    
    /// Register reusable views needed by this data source
    open func registerReusableViewsWithCollectionView(_ collectionView: UICollectionView) {
        
    }
    
    /// Register reusable views needed by this data source
    open func registerReusableViewsWithTableView(_ tableView: UITableView) {
        
    }
    
    // MARK: Content loading
    
    /// Signal that the datasource should reload its content
    open func setNeedsLoadContent() {
        let loadContentSelector = #selector(DataSource.loadContent)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: loadContentSelector, object: nil)
        self.perform(loadContentSelector, with: nil, afterDelay: 0.0)
    }
    
    /// Reset the content and loading state.
    open func resetContent() {
    }
    
    /// Load the content of this data source.
    open func loadContent() {
    }
    
    func whenLoaded(_ closure: () -> Void) {
        // FIXME: (khinboon@d--buzz.com)
    }
    
    // MARK: Data Source Life Cycle
    
    /// Called when a data source becomes active in a collection view. If the data source is in the `AAPLLoadStateInitial` state, it will be sent a `-loadContent` message.
    open func didBecomeActive() {
        // TODO: (khinboon@d--buzz.com) If state is initial, set needs load content.
    }
    
    /// Called when a data source becomes inactive in a collection view
    open func willResignActive() {
        
    }
    
    // MARK: Update Coalescing
    
    public typealias GenericClosure = () -> Void
    internal var pendingUpdate: GenericClosure?
    
    open func performUpdate(_ update: GenericClosure?, complete: GenericClosure? = nil) {
        assert(Thread.isMainThread, "This method must be called on the main thread")
        // FIXME: (khinboon@d--buzz.com) If this data source is loading, wait until we're done before we execute the update
        self.internalPerformUpdate(update, complete: complete)
    }
    
    internal func internalPerformUpdate(_ update: GenericClosure?, complete: GenericClosure? = nil) {
        // NOTE: (khinboon@d--buzz.com) Establish a marker that we're in an update block. This will be used by the AAPL_ASSERT_IN_DATASOURCE_UPDATE to ensure things will update correctly.
        
        if self.delegate?.dataSource?(self, performBatchUpdate: update, complete: complete) == nil {
            update?()
            complete?()
        }
    }
    
    internal func enqueueUpdate(_ update: @escaping GenericClosure) {
        if let pendingUpdate = self.pendingUpdate {
            self.pendingUpdate = {
                pendingUpdate()
                update()
            }
        } else {
            self.pendingUpdate = update
        }
    }
    
    // MARK: Notifications
    
    /// Notify the parent data source and the collection view that new items have been inserted at positions represented by insertedIndexPaths.
    open func notifyItemsInsertedAtIndexPaths(_ insertedIndexPaths: [IndexPath]) {
        assert(Thread.isMainThread, "This method must be called on the main thread")
        self.delegate?.dataSource?(self, didInsertItemsAtIndexPaths: insertedIndexPaths)
    }
    
    /// Notify the parent data source and collection view that the items represented by removedIndexPaths have been removed from this data source.
    open func notifyItemsRemovedAtIndexPaths(_ removedIndexPaths: [IndexPath]) {
        assert(Thread.isMainThread, "This method must be called on the main thread")
        self.delegate?.dataSource?(self, didRemoveItemsAtIndexPaths: removedIndexPaths)
    }
    
    /// Notify the parent data sources and collection view that the items represented by refreshedIndexPaths have been updated and need redrawing.
    open func notifyItemsRefreshedAtIndexPaths(_ refreshedIndexPaths: [IndexPath]) {
        assert(Thread.isMainThread, "This method must be called on the main thread")
        self.delegate?.dataSource?(self, didRefreshItemsAtIndexPaths: refreshedIndexPaths)
    }
    
    /// Alert parent data sources and the collection view that the item at indexPath was moved to newIndexPath.
    open func notifyItemMovedFromIndexPath(_ indexPath: IndexPath, toIndexPaths newIndexPath: IndexPath) {
        assert(Thread.isMainThread, "This method must be called on the main thread")
        self.delegate?.dataSource?(self, didMoveItemAtIndexPath: indexPath, toIndexPath: newIndexPath)
    }
    
    /// Notify parent data sources and the collection view that the sections were inserted.
    open func notifySectionsInserted(_ sections: IndexSet) {
        assert(Thread.isMainThread, "This method must be called on the main thread")
        self.delegate?.dataSource?(self, didInsertSections: sections)
    }
    
    /// Notify parent data sources and (eventually) the collection view that the sections were removed.
    open func notifySectionsRemoved(_ sections: IndexSet) {
        assert(Thread.isMainThread, "This method must be called on the main thread")
        self.delegate?.dataSource?(self, didRemoveSections: sections)
    }
    
    /// Notify parent data sources and the collection view that the section at oldSectionIndex was moved to newSectionIndex.
    open func notifySectionMovedFrom(_ oldSectionIndex: Int, to newSectionIndex: Int) {
        assert(Thread.isMainThread, "This method must be called on the main thread")
        self.delegate?.dataSource?(self, didMoveSection: oldSectionIndex, toSection: newSectionIndex)
    }
    
    /// Notify parent data sources and ultimately the collection view the specified sections were refreshed.
    open func notifySectionsRefreshed(_ sections: IndexSet) {
        assert(Thread.isMainThread, "This method must be called on the main thread")
        self.delegate?.dataSource?(self, didRefreshSections: sections)
    }
    
    /// Notify parent data sources and ultimately the collection view that the data in this data source has been reloaded.
    open func notifyDidReloadData() {
        assert(Thread.isMainThread, "This method must be called on the main thread")
        self.delegate?.dataSourceDidReloadData?(self)
    }
    
    /// Notify the parent data source that this data source will load its content. Unlike other notifications, this notification will not be propagated past the parent data source.
    open func notifyWillLoadContent() {
        assert(Thread.isMainThread, "This method must be called on the main thread")
        self.delegate?.dataSourceWillLoadContent?(self)
    }
    
    /// Notify the parent data source that this data source has finished loading its content with the given error (nil if no error). Unlike other notifications, this notification will not propagate past the parent data source.
    open func notifyContentLoadedWithError(_ error: NSError?) {
        assert(Thread.isMainThread, "This method must be called on the main thread")
        // FIXME: (stan@trifia.com) Executes loading completion block (a stored property) if available…
        self.delegate?.dataSource?(self, didLoadContentWithError: error)
    }
}

extension DataSource : UICollectionViewDataSource {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.numberOfSections
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // When we're showing a placeholder, we have to lie to the collection view about the number of items we have. Otherwise, it will ask for layout attributes that we don't have.
        // FIXME: (khinboon@d--buzz.com) return self.placeholder ? 0 : self.numberOfItemsInSection(section)
        return self.numberOfItemsInSection(section)
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        fatalError("Should be implemented by subclasses")
    }
}

extension DataSource : UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return self.numberOfSections
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // When we're showing a placeholder, we have to lie to the collection view about the number of items we have. Otherwise, it will ask for layout attributes that we don't have.
        // FIXME: (khinboon@d--buzz.com) return self.placeholder ? 0 : self.numberOfItemsInSection(section)
        return self.numberOfItemsInSection(section)
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        fatalError("Should be implemented by subclasses")
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.title
    }
    
    public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }
}

extension DataSource : UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    public func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}
