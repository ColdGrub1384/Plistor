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
}

