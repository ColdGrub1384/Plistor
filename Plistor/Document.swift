//
//  Document.swift
//  Plistor
//
//  Created by Adrian Labbé on 13-12-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit

/// A Plist or JSON document.
class Document: UIDocument {
    
    /// The top item. Can be a dictionnary or an array.
    var propertyList: Any = [String:Any]()
    
    /// The error while saving the document.
    var error: Error?
    
    // MARK: - Document
    
    override func contents(forType typeName: String) throws -> Any {
        // Encode your document with an instance of NSData or NSFileWrapper
        if typeName.contains("json"), propertyList is NSDictionary || propertyList is NSArray {
            return try JSONSerialization.data(withJSONObject: propertyList, options: JSONSerialization.WritingOptions.prettyPrinted)
        } else if typeName.contains("property-list") {
            
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tmp.plist")
            
            if let propertyListDict = propertyList as? [String:Any] {
                let dict = NSDictionary(dictionary: propertyListDict)
                try dict.write(to: url)
            } else if let propertyListArray = propertyList as? [Any] {
                let arr = NSArray(array: propertyListArray)
                try arr.write(to: url)
            }
            
            return try Data(contentsOf: url)
        } else {
            return Data()
        }
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        if fileURL.pathExtension.lowercased() == "plist" {
            propertyList = (NSDictionary(contentsOfFile: fileURL.path) ?? NSArray(contentsOf: fileURL)) ?? [String:Any]()
        } else if fileURL.pathExtension.lowercased() == "json" {
            let data = try Data(contentsOf: fileURL)
            propertyList = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        }
    }
    
    override func handleError(_ error: Error, userInteractionPermitted: Bool) {
        super.handleError(error, userInteractionPermitted: userInteractionPermitted)
        
        self.error = error
    }
    
    override func presentedItemDidChange() {
        super.presentedItemDidChange()
        
        #if !APP_EXTENSION
        do {
            if fileURL.pathExtension.lowercased() == "plist" {
                propertyList = (NSDictionary(contentsOfFile: fileURL.path) ?? NSArray(contentsOf: fileURL)) ?? [String:Any]()
            } else if fileURL.pathExtension.lowercased() == "json" {
                let data = try Data(contentsOf: fileURL)
                propertyList = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            }
            
            DispatchQueue.main.async {
                for scence in UIApplication.shared.connectedScenes {
                    let vcs = ((scence as? UIWindowScene)?.windows.first?.rootViewController?.presentedViewController as? UINavigationController)?.viewControllers ?? []
                    for vc in vcs {
                        if let vc = vc as? DocumentViewController {
                            
                            guard vc.document?.fileURL == self.fileURL else {
                                continue
                            }
                            
                            guard vc.syncsElement else {
                                vc.syncsElement = true
                                continue
                            }
                            
                            guard let key = vc.key else {
                                vc.save = false
                                vc.element = self.propertyList
                                vc.tableView.reloadData()
                                continue
                            }
                            
                            vc.syncsElement = false
                            if let arr = vc.parentElement?.element as? NSArray, let i = Int(key), arr.count > i  {
                                if let item = arr[i] as? NSArray, item != (vc.element as? NSArray) {
                                    vc.element = arr[i]
                                } else if let item = arr[i] as? NSDictionary, item != (vc.element as? NSDictionary) {
                                    vc.element = arr[i]
                                }
                            } else if let dict = vc.parentElement?.element as? NSDictionary {
                                if let item = dict[key] as? NSArray, item != (vc.element as? NSArray) {
                                    vc.element = dict[key] ?? vc.element
                                } else if let item = dict[key] as? NSDictionary, item != (vc.element as? NSDictionary) {
                                    vc.element = dict[key] ?? vc.element
                                }
                            } else {
                                vc.element = self.propertyList
                            }
                            vc.tableView.reloadData()
                            vc.syncsElement = true
                        }
                    }
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        #endif
    }
}

