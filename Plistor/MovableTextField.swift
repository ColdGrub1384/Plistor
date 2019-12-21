//
//  MovableTextField.swift
//  MovableTextField
//
//  Created by Adrian Labbé on 3/30/19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit

/// A class for managing a movable text field.
class MovableTextField: NSObject, UITextFieldDelegate {
    
    /// The view containing this text field.
    let console: ConsoleViewController
    
    /// The placeholder of the text field.
    var placeholder = "" {
        didSet {
            textField.placeholder = placeholder
        }
    }
    
    /// The toolbar containing the text field
    let toolbar: UIToolbar
    
    /// The text field.
    let textField: UITextField
    
    /// Initializes the manager.
    ///
    /// - Parameters:
    ///     - console: The console containing the text field.
    init(console: ConsoleViewController) {
        self.console = console
        toolbar = Bundle(for: MovableTextField.self).loadNibNamed("TextField", owner: nil, options: nil)?.first as! UIToolbar
        textField = toolbar.items!.first!.customView as! UITextField
        
        super.init()
        
        #if MAIN
        applyTheme()
        #endif
        
        textField.delegate = self
        if #available(iOS 13.0, *) {
            textField.textColor = UIColor.label
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidHide(_:)), name: UIResponder.keyboardDidHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    /// Shows the text field.
    func show() {
        toolbar.frame.size.width = console.view.safeAreaLayoutGuide.layoutFrame.width
        toolbar.frame.origin.x = console.view.safeAreaInsets.left
        toolbar.frame.origin.y = console.view.safeAreaLayoutGuide.layoutFrame.height-toolbar.frame.height
        toolbar.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin, .flexibleTopMargin]
        console.view.clipsToBounds = false
        console.view.addSubview(toolbar)
    }
    
    /// Shows keyboard.
    func focus() {
        DispatchQueue.main.asyncAfter(deadline: .now()+0.25) {
            self.textField.becomeFirstResponder()
        }
    }
    
    /// Code called when text is sent. Receives the text.
    var handler: ((String) -> Void)?
    
    // MARK: - Keyboard
    
    @objc private func keyboardDidShow(_ notification: NSNotification) {
        
        // That's the typical code you just cannot understand when you are playing Clash Royale while coding
        // So please, open iTunes, play your playlist, focus and then go back.
        
        if console.parent?.parent?.modalPresentationStyle != .popover || console.parent?.parent?.view.frame.width != console.parent?.parent?.preferredContentSize.width {
            
            var r = notification.userInfo![UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
            r = console.textView.convert(r, from:nil)
            toolbar.frame.origin.y = console.view.frame.height-r.height-toolbar.frame.height
        }
        
        UIView.animate(withDuration: 0.5) {
            self.toolbar.alpha = 1
        }
        
        console.textView.scrollToBottom()
    }
    
    @objc private func keyboardDidHide(_ notification: NSNotification) {
        toolbar.frame.origin.y = console.view.safeAreaLayoutGuide.layoutFrame.height-toolbar.frame.height
        
        if textField.isFirstResponder { // Still editing, but with a hardware keyboard
            keyboardDidShow(notification)
        }
        
        UIView.animate(withDuration: 0.5) {
            self.toolbar.alpha = 1
        }
    }
    
    @objc private func keyboardWillHide(_ notification: NSNotification) {
        UIView.animate(withDuration: 0.5) {
            self.toolbar.alpha = 0
        }
    }
    
    @objc private func keyboardWillShow(_ notification: NSNotification) {
        UIView.animate(withDuration: 0.5) {
            self.toolbar.alpha = 0
        }
    }
    
    // MARK: - Text field delegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        textField.resignFirstResponder()
        
        defer {
            handler?(textField.text ?? "")
            placeholder = ""
            
            #if MAIN
            if let text = textField.text, !text.isEmpty {
                if let i = history.firstIndex(of: text) {
                    history.remove(at: i)
                }
                history.insert(text, at: 0)
                historyIndex = -1
            }
            currentInput = nil
            #endif
            
            textField.text = ""
        }
        
        return true
    }
    
    // MARK: - History
    
    /// The current command that is not in the history.
    var currentInput: String?
    
    /// The index of current input in the history. `-1` if the command is not in the history.
    var historyIndex = -1 {
        didSet {
            if historyIndex == -1 {
                textField.text = currentInput
            } else if history.indices.contains(historyIndex) {
                textField.text = history[historyIndex]
            }
        }
    }
    
    /// The history of input. This array is reversed. The first command in the history is the last in this array.
    var history: [String] {
        get {
            return (UserDefaults.standard.array(forKey: "inputHistory") as? [String]) ?? []
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "inputHistory")
            UserDefaults.standard.synchronize() // Yes, I know, that's not needed, but I call it BECAUSE I WANT, I CALL THIS FUNCTION BECAUSE I WANT OK
        }
    }
    
    /// Scrolls down on the history.
    @objc func down() {
        if historyIndex > -1 {
            historyIndex -= 1
        }
    }
    
    /// Scrolls up on the history.
    @objc func up() {
        if history.indices.contains(historyIndex+1) {
            historyIndex += 1
        }
    }
}

