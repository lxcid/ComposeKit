//
//  DataSourceMapping.swift
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

/// Maps global sections to local sections for a given data source
class DataSourceMapping : NSObject {
    let dataSource: DataSource
    
    var numberOfSections = 0
    fileprivate var globalToLocalSections = [Int : Int]()
    fileprivate var localToGlobalSections = [Int : Int]()
    
    
    required init(dataSource: DataSource) {
        self.dataSource = dataSource
    }
    
    convenience init(dataSource: DataSource, globalSectionIndex: Int) {
        self.init(dataSource: dataSource)
        self.updateMappingStartingAtGlobalSection(globalSectionIndex) { (globalSection) -> Void in
            // Do nothing…
        }
    }
    
    /// Return the local section for a global section
    func localSectionForGlobalSection(_ globalSection: Int) -> Int? {
        return self.globalToLocalSections[globalSection]
    }
    
    fileprivate func localSectionsForGlobalSections(_ globalSections: IndexSet) -> IndexSet {
        var localSections = IndexSet()
        globalSections.forEach { (globalSection) -> Void in
            if let localSection = self.globalToLocalSections[globalSection] {
                localSections.insert(localSection)
            }
        }
        return localSections
    }
    
    /// Return the global section for a local section
    func globalSectionForLocalSection(_ localSection: Int) -> Int {
        let globalSection = self.localToGlobalSections[localSection]
        precondition(globalSection != nil, "localSection \(localSection) not found in localToGlobalSections: \(self.localToGlobalSections)")
        return globalSection!
    }
    
    fileprivate func globalSectionsForLocalSections(_ localSections: IndexSet) -> IndexSet {
        var globalSections = IndexSet()
        localSections.forEach { (localSection) -> Void in
            if let globalSection = self.localToGlobalSections[localSection] {
                globalSections.insert(globalSection)
            } else {
                preconditionFailure("localSection \(localSection) not found in localToGlobalSections: \(self.localToGlobalSections)")
            }
        }
        return globalSections
    }
    
    /// Return a local index path for a global index path. Returns nil when the global indexPath does not map locally.
    func localIndexPathForGlobalIndexPath(_ globalIndexPath: IndexPath) -> IndexPath? {
        if let localSection = self.localSectionForGlobalSection(globalIndexPath.section) {
            return IndexPath(item: globalIndexPath.item, section: localSection)
        } else {
            return nil
        }
    }
    
    /// Return a global index path for a local index path
    func globalIndexPathForLocalIndexPath(_ localIndexPath: IndexPath) -> IndexPath {
        let globalSection = self.globalSectionForLocalSection(localIndexPath.section)
        return IndexPath(item: localIndexPath.item, section: globalSection)
    }
    
    /// Return an array of local index paths from an array of global index paths
    func localIndexPathsForGlobalIndexPaths(_ globalIndexPaths: [IndexPath]) -> [IndexPath] {
        var result = [IndexPath]()
        for globalIndexPath in globalIndexPaths {
            if let localIndexPath = self.localIndexPathForGlobalIndexPath(globalIndexPath) {
                result.append(localIndexPath)
            }
        }
        return result
    }
    
    /// Return an array of global index paths from an array of local index paths
    func globalIndexPathsForLocalIndexPaths(_ localIndexPaths: [IndexPath]) -> [IndexPath] {
        var result = [IndexPath]()
        for localIndexPath in localIndexPaths {
            let globalIndexPath = self.globalIndexPathForLocalIndexPath(localIndexPath)
            result.append(globalIndexPath)
        }
        return result
    }
    
    fileprivate func addMappingFromGlobalSection(_ globalSection: Int, toLocalSection localSection: Int) {
        assert(self.localToGlobalSections[localSection] == nil, "collision while trying to add to a mapping")
        self.globalToLocalSections[globalSection] = localSection
        self.localToGlobalSections[localSection] = globalSection
    }
    
    /// The block argument is called once for each mapped section and passed the global section index.
    func updateMappingStartingAtGlobalSection(_ globalSection: NSInteger, withBlock block: (_ globalSection: Int) -> Void) {
        var globalSection = globalSection
        self.numberOfSections = self.dataSource.numberOfSections
        self.globalToLocalSections.removeAll()
        self.localToGlobalSections.removeAll()
        
        for localSection in 0..<self.numberOfSections {
            self.addMappingFromGlobalSection(globalSection, toLocalSection: localSection)
            block(globalSection)
            globalSection += 1
        }
    }
}

extension DataSourceMapping : NSCopying {
    func copy(with zone: NSZone?) -> Any {
        let copy = type(of: self).init(dataSource: self.dataSource)
        copy.numberOfSections = self.numberOfSections
        copy.globalToLocalSections = self.globalToLocalSections
        copy.localToGlobalSections = self.localToGlobalSections
        return copy
    }
}
