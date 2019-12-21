//
//  ConsoleViewController.swift
//  Plistor
//
//  Created by Adrian Labbé on 19-12-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit
import JavaScriptCore

/// A JavaScript console for changing values programatically.
class ConsoleViewController: UIViewController {
    
    /// The text view showing results.
    var textView: UITextView!
    
    /// The text field where the code is typed.
    var movableTextField: MovableTextField!
    
    /// The JavaScript context.
    var context: JSContext! {
        didSet {
            context.setObject(NSNull(), forKeyedSubscript: "console" as NSCopying & NSObjectProtocol)
        }
    }
    
    /// The editor from where the view controller is presented.
    var editor: DocumentViewController?
    
    /// The key of the edited value.
    var key: String?
    
    /// Closes the view controller
    @objc func done() {
        dismiss(animated: true, completion: nil)
    }
    
    /// Returns an escaped description from a JavaScript value.
    ///
    /// - Parameters:
    ///     - value: The JavaScript value to descript.
    ///
    /// - Returns: An escaped description.
    func description(value: JSValue) -> String {
        let description: String
        
        if value.isNull {
            description = "null"
        } else if value.isArray || value.isObject {
            description = "\(String(data: (try? JSONSerialization.data(withJSONObject: value.toObject() ?? NSArray(), options: .prettyPrinted)) ?? Data(), encoding: .utf8) ?? "")"
        } else if value.isString, let str = value.toString() {
            description = "\"\(str.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\"", with: "\\\""))\""
        } else if value.isNumber, let number = value.toNumber() {
            description = "\(number)"
        } else if value.isBoolean {
            description = value.isBoolean ? "true" : "false"
        } else if value.isDate, let date = value.toDate() {
            description = "\(date)"
        } else {
            description = ""
        }
        
        return description
    }
    
    // MARK: - View controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "JavaScript Console"
        
        edgesForExtendedLayout = []
        
        view.backgroundColor = .systemBackground
        
        textView = UITextView()
        textView.isEditable = false
        textView.font = UIFont(name: "Menlo", size: UIFont.systemFontSize)
        
        textView.text = "The 'value' variable will be saved to disk replacing the old value.\n\nvalue = \(description(value: context?.evaluateScript("value") ?? JSValue()))"
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.frame.size.height = view.frame.height
        
        view.addSubview(textView)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name:UIResponder.keyboardWillHideNotification, object: nil)
        
        movableTextField = MovableTextField(console: self)
        movableTextField?.placeholder = "> "
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        
        context.exceptionHandler = { context, error in
            self.textView.text += "\n\(error ?? JSValue())"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        textView.frame = view.safeAreaLayoutGuide.layoutFrame
        textView.frame.size.height -= 44
        textView.frame.origin.y = view.safeAreaLayoutGuide.layoutFrame.origin.y
        
        movableTextField.focus()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        movableTextField?.toolbar.removeFromSuperview()
        movableTextField = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.isTranslucent = false
        
        if movableTextField == nil {
            movableTextField = MovableTextField(console: self)
            movableTextField?.placeholder = "> "
        }
        movableTextField?.show()
        movableTextField?.handler = { text in
            self.textView.text += "\n> \(text)"
            if let result = self.context.evaluateScript(text) {
                self.textView.text += "\n\(self.description(value: result))"
            }
            
            self.movableTextField?.focus()
            
            guard let value = self.context.evaluateScript("value"), let editor = self.editor else {
                return
            }
                   
            var newValue: Any = NSNull()
                   
            if value.isNull, editor.document?.fileURL.pathExtension.lowercased() == "json"  {
                newValue = NSNull()
            } else if value.isArray || value.isObject {
                if value.isArray {
                    newValue = value.toArray() ?? NSArray()
                } else if value.isObject {
                    newValue = value.toDictionary() ?? NSDictionary()
                }
            } else if value.isString, let str = value.toString() {
                newValue = str
            } else if value.isNumber, let number = value.toNumber() {
                newValue = number
            } else if value.isBoolean {
                newValue = value.toBool()
            } else if value.isDate, let date = value.toDate(), editor.document?.fileURL.pathExtension.lowercased() == "plist" {
                newValue = date
            } else {
                newValue = self.description(value: value)
            }
            
            guard let key = self.key else {
                editor.element = newValue
                editor.tableView.reloadData()
                return
            }
            
            if let dict = editor.element as? NSDictionary {
                let mutable = NSMutableDictionary(dictionary: dict)
                mutable[key] = newValue
                editor.element = mutable
            } else if let arr = editor.element as? NSArray, let i = Int(key) {
                let mutable = NSMutableArray(array: arr)
                mutable.removeObject(at: i)
                mutable.insert(newValue, at: i)
                editor.element = mutable
            }
            
            editor.tableView.reloadData()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let wasFirstResponder = movableTextField?.textField.isFirstResponder ?? false
        movableTextField?.textField.resignFirstResponder()
        movableTextField?.toolbar.frame.size.width = view.safeAreaLayoutGuide.layoutFrame.width
        movableTextField?.toolbar.frame.origin.x = view.safeAreaInsets.left
        textView.frame = view.safeAreaLayoutGuide.layoutFrame
        textView.frame.size.height = view.safeAreaLayoutGuide.layoutFrame.height-44
        textView.frame.origin.y = view.safeAreaLayoutGuide.layoutFrame.origin.y
        if wasFirstResponder {
            movableTextField?.textField.becomeFirstResponder()
        }
        movableTextField?.toolbar.isHidden = (view.frame.size.height == 0)
    }
    
    // MARK: - Keyboard
    
    @objc func keyboardWillShow(_ notification:Notification) {
        if parent?.parent?.modalPresentationStyle != .popover || parent?.parent?.view.frame.width != parent?.parent?.preferredContentSize.width {
            let d = notification.userInfo!
            let r = d[UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
            
            let point = (view.window)?.convert(r.origin, to: view) ?? r.origin
            
            textView.frame.size.height = point.y-44
        } else {
            textView.frame.size.height = view.safeAreaLayoutGuide.layoutFrame.height-44
        }
        
        textView.frame.origin.y = view.safeAreaLayoutGuide.layoutFrame.origin.y
        
        textView.scrollToBottom()
        
        movableTextField?.placeholder = "> "
    }
    
    @objc func keyboardWillHide(_ notification:Notification) {
        textView.frame.size.height = view.safeAreaLayoutGuide.layoutFrame.height-44
        textView.frame.origin.y = view.safeAreaLayoutGuide.layoutFrame.origin.y
    }
}
