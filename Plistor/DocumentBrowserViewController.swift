//
//  DocumentBrowserViewController.swift
//  Plistor
//
//  Created by Adrian Labbé on 13-12-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit
#if APP_EXTENSION
import MobileCoreServices
#endif

/// The main document browser view controller.
class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate, UIViewControllerTransitioningDelegate {
    
    /// The URL of the document to open.
    var documentURL: URL?
    
    // MARK: - Document browser view controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        
        allowsDocumentCreation = true
        allowsPickingMultipleItems = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        #if APP_EXTENSION
        let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem
        let itemProvider = extensionItem?.attachments?.first
        let propertyList = String(kUTTypePropertyList)
        if itemProvider?.hasItemConformingToTypeIdentifier(propertyList) == true {
            itemProvider?.loadItem(forTypeIdentifier: propertyList, options: nil, completionHandler: { (item, error) -> Void in
                let dictionary = item as? NSDictionary
                OperationQueue.main.addOperation {
                    let results = dictionary?[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary
                    
                    let title = (results?["name"] as? String) ?? "Property List"
                    
                    if let content = results?["content"] as? String {
                        if (try? JSONSerialization.jsonObject(with: content.data(using: .utf8) ?? Data(), options: [])) != nil {
                            var tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(title)
                            if NSString(string: title).pathExtension.lowercased() != "json" {
                                tmpURL = tmpURL.appendingPathExtension("json")
                            }
                            try? content.write(to: tmpURL, atomically: true, encoding: .utf8)
                            self.presentDocument(at: tmpURL)
                        } else {
                            var tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(title)
                            if NSString(string: title).pathExtension.lowercased() != "plist" {
                                tmpURL = tmpURL.appendingPathExtension("plist")
                            }
                            try? content.write(to: tmpURL, atomically: true, encoding: .utf8)
                            self.presentDocument(at: tmpURL)
                        }
                    }
                    
                }
            })
        }
        #endif
        
        if let doc = documentURL {
            documentURL = nil
            presentDocument(at: doc)
        }
    }
    
    // MARK: Document browser view controller delegate
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            importHandler(nil, .none)
        }))
        
        alert.addAction(UIAlertAction(title: "JSON", style: .default, handler: { (_) in
            let newDocumentURL = Bundle.main.url(forResource: "Property List", withExtension: "json")
            
            if newDocumentURL != nil {
                importHandler(newDocumentURL, .copy)
            } else {
                importHandler(nil, .none)
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Plist", style: .default, handler: { (_) in
            let newDocumentURL = Bundle.main.url(forResource: "Property List", withExtension: "plist")
            
            if newDocumentURL != nil {
                importHandler(newDocumentURL, .copy)
            } else {
                importHandler(nil, .none)
            }
        }))
        
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(x: view.frame.width/2, y: view.frame.height/2, width: 1, height: 1)
        
        present(alert, animated: true, completion: nil)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
        guard let sourceURL = documentURLs.first else { return }
        
        // Present the Document View Controller for the first document that was picked.
        // If you support picking multiple items, make sure you handle them all.
        presentDocument(at: sourceURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
        // Present the Document View Controller for the new newly created document
        presentDocument(at: destinationURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?) {
        // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
    }
    
    // MARK: Document Presentation
    
    /// Edits the given document.
    ///
    /// - Parameters:
    ///     - documentURL: The URL of a Plist or JSON document.
    func presentDocument(at documentURL: URL) {
        
        let doc = Document(fileURL: documentURL)
        
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let navVC = storyBoard.instantiateViewController(withIdentifier: "editor") as! UINavigationController
        let documentViewController = navVC.viewControllers.first as! DocumentViewController
        documentViewController.document = doc
        navVC.modalPresentationStyle = .fullScreen
        
        #if !APP_EXTENSION
        transitionController = transitionController(forDocumentAt: documentURL)
        transitionController?.loadingProgress = doc.progress
        transitionController?.targetView = navVC.view
        
        navVC.transitioningDelegate = self
        #endif
        
        present(navVC, animated: true, completion: nil)
    }
    
    // MARK: - Animation
    
    /// Transition controller for presenting and dismissing View controllers.
    var transitionController: UIDocumentBrowserTransitionController?
    
    // MARK: - View controller transition delegate
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return transitionController
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return transitionController
    }
}

