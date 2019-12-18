//
//  SceneDelegate.swift
//  Plistor
//
//  Created by Adrian Labbé on 16-12-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit

/// The scene delegate.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    /// The document browser associated with this scene.
    var documentBrowserViewController: DocumentBrowserViewController? {
        return window?.rootViewController as? DocumentBrowserViewController
    }
    
    // MARK: - Scene delegate
    
    var window: UIWindow?
    
    @available(iOS 13.0, *)
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        if connectionOptions.urlContexts.count > 0 {
            self.scene(scene, openURLContexts: connectionOptions.urlContexts)
            return
        }
        
        if connectionOptions.userActivities.count > 0 {
            self.scene(scene, continue: connectionOptions.userActivities.first!)
            return
        }
        
        if let restorationActivity = session.stateRestorationActivity, let data = restorationActivity.userInfo?["bookmarkData"] as? Data {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
                
                (window?.rootViewController as? DocumentBrowserViewController)?.documentURL = url
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    @available(iOS 13.0, *)
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        
        let root = window?.rootViewController
        
        func runScript() {
            if let data = userActivity.userInfo?["filePath"] as? Data {
                do {
                    var isStale = false
                    let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
                    
                    if let arguments = userActivity.userInfo?["arguments"] as? String {
                        UserDefaults.standard.set(arguments, forKey: "arguments\(url.path.replacingOccurrences(of: "//", with: "/"))")
                    }
                    
                    _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
                        if let doc = self.documentBrowserViewController {
                            doc.revealDocument(at: url, importIfNeeded: true) { (url_, _) in
                                doc.presentDocument(at: url_ ?? url)
                            }
                            timer.invalidate()
                        }
                    })
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
        
        if root?.presentedViewController != nil {
            root?.dismiss(animated: true, completion: {
                runScript()
            })
        } else {
            runScript()
        }
    }
    
    @available(iOS 13.0, *)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        
        guard let inputURL = URLContexts.first?.url else {
            return
        }
                
        guard let documentBrowserViewController = documentBrowserViewController else {
            window?.rootViewController?.dismiss(animated: true, completion: {
                self.scene(scene, openURLContexts: URLContexts)
            })
            return
        }
        
        // Ensure the URL is a file URL
        guard inputURL.isFileURL else {
            return
        }
        
        _ = inputURL.startAccessingSecurityScopedResource()
        
        // Reveal / import the document at the URL
        
        documentBrowserViewController.revealDocument(at: inputURL, importIfNeeded: true, completion: { (url, _) in
            
            documentBrowserViewController.presentDocument(at: url ?? inputURL)
        })
    }
    
    // MARK: - State restoration
    
    @available(iOS 13.0, *)
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        if let url = ((documentBrowserViewController?.presentedViewController as? UINavigationController)?.viewControllers.first as? DocumentViewController)?.document?.fileURL {
            
            do {
                
                let bookmarkData = try url.bookmarkData()

                let activity = NSUserActivity(activityType: "stateRestoration")
                activity.userInfo?["bookmarkData"] = bookmarkData
                return activity
            } catch {
                return nil
            }
        }
        
        return nil
    }
}

