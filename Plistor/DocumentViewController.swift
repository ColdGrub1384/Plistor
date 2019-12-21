//
//  DocumentViewController.swift
//  Plistor
//
//  Created by Adrian Labbé on 13-12-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit
import JavaScriptCore

/// The Plist / JSON editor.
class DocumentViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, UIContextMenuInteractionDelegate {
    
    /// The color for representing String values.
    static let stringColor = UIColor.systemRed
    
    /// The color for representing Number values.
    static let numberColor = UIColor.systemPurple
    
    /// The color for representing Boolean values.
    static let boolColor = UIColor.systemGreen
    
    /// The color for representing Data values.
    static let dataColor = UIColor.systemTeal
    
    /// The color for representing Date values.
    static let dateColor = UIColor.systemYellow
    
    /// The color for representing Dictionary values.
    static let dictColor = UIColor.systemPink
    
    /// The color for representing Array values.
    static let arrayColor = UIColor.systemIndigo
    
    private func isBoolNumber(num:NSNumber) -> Bool {
        let boolID = CFBooleanGetTypeID() // the type ID of CFBoolean
        let numID = CFGetTypeID(num) // the type ID of num
        return numID == boolID
    }
    
    private func color(for element: Any) -> UIColor {
        if element is NSString {
            return DocumentViewController.stringColor
        } else if let num = element as? NSNumber, isBoolNumber(num: num) {
            return DocumentViewController.boolColor
        } else if element is NSNumber {
            return DocumentViewController.numberColor
        } else if element is NSDate {
            return DocumentViewController.dateColor
        } else if element is NSData {
            return DocumentViewController.dataColor
        } else if element is NSDictionary {
            return DocumentViewController.dictColor
        } else if element is NSArray {
            return DocumentViewController.arrayColor
        } else {
            return .label
        }
    }
    
    private func type(of element: Any) -> String {
        if element is NSString {
            return "String"
        } else if let num = element as? NSNumber, isBoolNumber(num: num) {
            return "Boolean"
        } else if element is NSNumber {
            return "Number"
        } else if element is NSDate {
            return "Date"
        } else if element is NSData {
            return "Data"
        } else if element is NSDictionary {
            return "Dictionary"
        } else if element is NSArray {
            return "Array"
        } else {
            return "Null"
        }
    }
    
    /// The Plist or JSON document.
    var document: Document?
    
    /// The key for current value.
    var key: String?
    
    /// A boolean indicating whether the file should be saved after setting `element`.
    var save = true
    
    /// A boolean indicating whether the root element should be synced.
    var syncsElement = true
    
    /// The object represented by the editor. May not be the root object,
    var element: Any = [String:Any]() {
        didSet {
            
            let pathExtension = document?.fileURL.pathExtension.lowercased()
            if pathExtension == "json", element is NSDictionary || element is NSArray {
                if let data = try? JSONSerialization.data(withJSONObject: element, options: JSONSerialization.WritingOptions.prettyPrinted), let str = String(data: data, encoding: .utf8) {
                    textView.text = str
                } else {
                    textView.text = ""
                }
            } else if pathExtension == "plist" {
                
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tmp.plist")
                
                if let propertyListDict = element as? [String:Any] {
                    let dict = NSDictionary(dictionary: propertyListDict)
                    try? dict.write(to: url)
                } else if let propertyListArray = element as? [Any] {
                    let arr = NSArray(array: propertyListArray)
                    try? arr.write(to: url)
                }
                
                textView.text = (try? String(contentsOf: url)) ?? ""
            }
            
            guard save else {
                save = true
                return
            }
            
            guard let key = key else {
                
                guard let doc = document else {
                    return
                }
                
                guard title?.isEmpty == false else {
                    return
                }
                
                doc.propertyList = element
                doc.save(to: doc.fileURL, for: .forOverwriting) { (success) in
                    if !success {
                        let alert = UIAlertController(title: "Error writing to file", message: nil, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
                
                return
            }
            
            if let _dict = parentElement?.element as? [String:Any] {
                let dict = NSMutableDictionary(dictionary: _dict)
                dict[key] = element
                parentElement?.element = dict
            } else if let i = Int(key), let _arr = parentElement?.element as? [Any] {
                let arr = NSMutableArray(array: _arr)
                arr[i] = element
                parentElement?.element = arr
            }
        }
    }
    
    /// The parent editor that presented the current editor. This editor contains the parent element of the current value.
    var parentElement: DocumentViewController?
    
    private var isDocOpen = false
    
    /// Updates the display mode.
    func checkDisplayMode() {
        if traitCollection.horizontalSizeClass == .compact {
            if mode == 0 {
                tableView.isHidden = false
                accessoryView.isHidden = true
            } else {
                tableView.isHidden = true
                accessoryView.isHidden = false
            }
        } else {
            tableView.isHidden = false
            accessoryView.isHidden = false
            segmentedControl.selectedSegmentIndex = 0
        }
    }
    
    /// Dismisses the editor.
    @IBAction func dismissDocumentViewController() {
        dismiss(animated: true) {
            self.document?.close(completionHandler: nil)
        }
    }

    /// Adds an item to the current Dictionary or Array.
    @IBAction func addItem(_ sender: UIBarButtonItem) {
        let types = ["Dictionary", "Array", "String", "Number", "Boolean"]+(document?.fileURL.pathExtension.lowercased() == "plist" ? ["Data", "Date"] : ["Null"])
        
        let alert = UIAlertController(title: "New item", message: "Select the new item's type", preferredStyle: .actionSheet)
        
        for type in types {
            alert.addAction(UIAlertAction(title: type, style: .default, handler: { (_) in
                
                func setValue(_ value: Any, forKey key: String? = nil) {
                    if let arr = self.element as? NSArray {
                        let mutable = NSMutableArray(array: arr)
                        mutable.add(value)
                        self.element = mutable
                    } else if let key = key, let dict = self.element as? NSDictionary {
                        let mutable = NSMutableDictionary(dictionary: dict)
                        mutable[key] = value
                        self.element = mutable
                    }
                    self.tableView.reloadData()
                }
                                
                if self.element is NSDictionary {
                    let keyAlert = UIAlertController(title: "New item", message: "Type the new item's key", preferredStyle: .alert)
                    
                    var textField: UITextField?
                    
                    keyAlert.addTextField { (_textField) in
                        _textField.placeholder = "New key"
                        textField = _textField
                    }
                    
                    keyAlert.addAction(UIAlertAction(title: "Confirm", style: .default, handler: { (_) in
                        if let newKey = textField?.text, !newKey.isEmpty {
                            
                            func _setValue(_ value: Any) {
                                setValue(value, forKey: newKey)
                            }
                            
                            switch type {
                            case "Dictionary":
                                _setValue(NSDictionary())
                            case "Array":
                                _setValue(NSArray())
                            case "String":
                                _setValue(NSString())
                            case "Number":
                                _setValue(NSNumber(0))
                            case "Boolean":
                                _setValue(Bool())
                            case "Data":
                                _setValue(NSData())
                            case "Date":
                                _setValue(NSDate())
                            case "Null":
                                _setValue(NSNull())
                            default:
                                break
                            }
                            
                        } else {
                            self.addItem(sender)
                        }
                    }))
                    
                    keyAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                        self.addItem(sender)
                    }))
                    
                    self.present(keyAlert, animated: true, completion: nil)
                } else {
                    switch type {
                    case "Dictionary":
                        setValue(NSDictionary())
                    case "Array":
                        setValue(NSArray())
                    case "String":
                        setValue(NSString())
                    case "Number":
                        setValue(NSNumber(0))
                    case "Boolean":
                        setValue(Bool())
                    case "Data":
                        setValue(Data())
                    case "Date":
                        setValue(Date())
                    case "Null":
                        setValue(NSNull())
                    default:
                        break
                    }
                }
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        alert.popoverPresentationController?.barButtonItem = sender
        
        present(alert, animated: true, completion: nil)
    }
    
    /// The table view containing values.
    @IBOutlet weak var tableView: UITableView!
    
    /// The Text View containing source code.
    var textView: UITextView!
    
    /// A view displayed at right or from a segmented control on compact views.
    @IBOutlet weak var accessoryView: UIView!
    
    /// A view for switching from Property List mode and Source Code mode on compact views.
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    /// Switches from Property List mode and Source Code mode.
    @IBAction func switchMode(_ sender: Any) {
        if mode == 0 {
            tableView.isHidden = false
            accessoryView.isHidden = true
        } else {
            tableView.isHidden = true
            accessoryView.isHidden = false
        }
    }
    
    /// Inspects the current element with JavaScript.
    @IBAction func inspectWithJS() {
        
        guard let context = JSContext() else {
            return
        }
        context.setObject(element, forKeyedSubscript: "value" as NSCopying & NSObjectProtocol)
        
        let console = ConsoleViewController()
        console.context = context
        console.editor = self
        let navVC = UINavigationController(rootViewController: console)
        navVC.modalPresentationStyle = .fullScreen
        self.present(navVC, animated: true, completion: nil)
    }
    
    private var mode: Int {
        return segmentedControl.selectedSegmentIndex
    }
    
    // MARK: - Document view controller
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: true)
        tableView.setEditing(!tableView.isEditing, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItems?.append(editButtonItem)
        navigationItem.leftItemsSupplementBackButton = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        textView = UITextView(frame: accessoryView.bounds)
        textView.delegate = self
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.font = UIFont(name: "Menlo", size: UIFont.smallSystemFontSize)
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        accessoryView.addSubview(textView)
        
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        ]
        textView.inputAccessoryView = toolbar
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Access the document
        if !isDocOpen {
            document?.open(completionHandler: { (success) in
                
                self.isDocOpen = true
                
                if success {
                    // Display the content of the document, e.g.:
                    
                    if self.key == nil {
                        self.element = self.document?.propertyList ?? [String:Any]()
                    }
                    
                    self.title = self.document?.fileURL.lastPathComponent
                    
                    self.tableView.reloadData()
                } else {
                    let alert = UIAlertController(title: "Error opening file", message: self.document?.error?.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                        self.dismiss(animated: true, completion: nil)
                    }))
                    self.present(alert, animated: true, completion: nil)
                }
            })
        } else {
            title = document?.fileURL.lastPathComponent
            self.tableView.reloadData()
        }
        
        checkDisplayMode()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        checkDisplayMode()
    }
    
    // MARK: - Keyboard
    
    /// Dismisses keyboard from text view.
    @objc func dismissKeyboard() {
        textView.resignFirstResponder()
    }
    
    /// Resizes `textView`.
    @objc func keyboardDidShow(_ notification:Notification) {
        let d = notification.userInfo!
        let r = d[UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
        let point = (view.window)?.convert(r.origin, to: textView) ?? r.origin
        
        textView.contentInset.bottom = (point.y >= textView.frame.height ? 0 : textView.frame.height-point.y)
        textView.verticalScrollIndicatorInsets.bottom = textView.contentInset.bottom
    }
    
    /// Set `textView` to the default size.
    @objc func keyboardWillHide(_ notification:Notification) {
        textView.contentInset = .zero
        textView.scrollIndicatorInsets = .zero
    }
    
    // MARK: - Table view data source
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ((element as? NSDictionary)?.count ?? (element as? NSArray)?.count ?? -1)+1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard indexPath.row > 0 else {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            
            let attrString = NSMutableAttributedString(string: key ?? "Root", attributes: [.font : cell.detailTextLabel?.font ?? UIFont.systemFont(ofSize: UIFont.systemFontSize), .foregroundColor : UIColor.label])
            attrString.append(NSAttributedString(string: " \(type(of: element))", attributes: [.font : UIFont.boldSystemFont(ofSize: UIFont.systemFontSize), .foregroundColor : color(for: element)]))
            
            cell.textLabel?.attributedText = attrString
            cell.detailTextLabel?.text = "▿"
            
            cell.addInteraction(UIContextMenuInteraction(delegate: self))
            return cell
        }
        
        if let element = element as? NSDictionary {
            guard let key = (element.allKeys as? [String])?[indexPath.row-1] else {
                return UITableViewCell()
            }
            
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            
            
            let attrString = NSMutableAttributedString(string: "  "+key, attributes: [.font : cell.detailTextLabel?.font ?? UIFont.systemFont(ofSize: UIFont.systemFontSize), .foregroundColor : UIColor.label])
            attrString.append(NSAttributedString(string: " \(type(of: element[key] ?? NSObject()))", attributes: [.font : UIFont.boldSystemFont(ofSize: UIFont.systemFontSize), .foregroundColor : color(for: element[key] ?? NSObject())]))
            
            cell.textLabel?.attributedText = attrString
            
            if element[key] is NSArray || element[key] is NSDictionary {
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.accessoryType = .none
                if let bool = element[key] as? NSNumber, isBoolNumber(num: bool) {
                    cell.detailTextLabel?.text = "\(bool.boolValue ? "YES" : "NO")"
                } else {
                    cell.detailTextLabel?.text = "\(element[key] ?? "")"
                }
            }
            
            cell.addInteraction(UIContextMenuInteraction(delegate: self))
            return cell
        } else if let element = element as? NSArray {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            
            let attrString = NSMutableAttributedString(string: "  \(indexPath.row-1)", attributes: [.font : cell.detailTextLabel?.font ?? UIFont.systemFont(ofSize: UIFont.systemFontSize), .foregroundColor : UIColor.label])
            attrString.append(NSAttributedString(string: " \(type(of: element[indexPath.row-1]))", attributes: [.font : UIFont.boldSystemFont(ofSize: UIFont.systemFontSize), .foregroundColor : color(for: element[indexPath.row-1])]))
            
            cell.textLabel?.attributedText = attrString
            
            if element[indexPath.row-1] is NSArray || element[indexPath.row-1] is NSDictionary {
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.accessoryType = .none
                if let bool = element[indexPath.row-1] as? NSNumber, isBoolNumber(num: bool) {
                    cell.detailTextLabel?.text = "\(bool.boolValue ? "YES" : "NO")"
                } else {
                    cell.detailTextLabel?.text = "\(element[indexPath.row-1])"
                }
            }
            
            cell.addInteraction(UIContextMenuInteraction(delegate: self))
            return cell
        } else {
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row != 0
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if let arr = element as? NSArray {
                let mutable = NSMutableArray(array: arr)
                mutable.removeObject(at: indexPath.row-1)
                self.element = mutable
            } else if let dict = element as? NSDictionary, let key = dict.allKeys[indexPath.row-1] as? String {
                let mutable = NSMutableDictionary(dictionary: dict)
                mutable.removeObject(forKey: key)
                self.element = mutable
            }
            
            tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return element is NSArray && indexPath.row != 0
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if let arr = element as? NSArray {
            let mutable = NSMutableArray(array: arr)
            let item = mutable[sourceIndexPath.row-1]
            mutable.removeObject(at: sourceIndexPath.row-1)
            mutable.insert(item, at: destinationIndexPath.row-1)
            element = mutable
            
            tableView.reloadData()
        }
    }
    
    // MARK: - Table view delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let isPresentedFromContextMenu = tableView.indexPathForSelectedRow == nil // If there is no selected row, this function is called manually
        tableView.deselectRow(at: indexPath, animated: true)
        
        var key: String?
        
        if indexPath.row != 0 {
            key = (element as? NSDictionary)?.allKeys[indexPath.row-1] as? String
        } else if element is NSArray && indexPath.row != 0 {
            key = nil
        } else {
            key = self.key ?? "Root"
        }
        
        var _value: Any?
        
        if let key = key, let element = self.element as? [String:Any] {
            _value = element[key]
        } else if let element = self.element as? [Any], indexPath.row != 0 {
            _value = element[indexPath.row-1]
        } else {
            _value = nil
        }
        
        func showSheet() {
                        
            if indexPath.row != 0 {
                key = (element as? NSDictionary)?.allKeys[indexPath.row-1] as? String
            } else if element is NSArray && indexPath.row != 0 {
                key = nil
            } else {
                key = self.key ?? "Root"
            }
                        
            if let key = key, let element = self.element as? [String:Any] {
                _value = element[key]
            } else if let element = self.element as? [Any], indexPath.row != 0 {
                _value = element[indexPath.row-1]
            } else {
                _value = nil
            }
            
            let alert = UIAlertController(title: key ?? "\(indexPath.row-1)", message: nil, preferredStyle: .actionSheet)
            
            func setValue(_ value: Any) {
                if let key = key, let dict = self.element as? [String:Any] {
                    let nsDict = NSMutableDictionary(dictionary: dict)
                    nsDict[key] = value
                    self.element = nsDict
                } else if let arr =  self.element as? [Any] {
                    let nsArr = NSMutableArray(array: arr)
                    nsArr.removeObject(at: indexPath.row-1)
                    nsArr.insert(value, at: indexPath.row-1)
                    self.element = nsArr
                }
                
                tableView.reloadData()
            }
            
            func selectType() {
                
                let value: Any
                if indexPath.row != 0 {
                    if _value == nil {
                        return
                    }
                    value = _value!
                } else {
                    value = element
                }
                
                let typesAlert = UIAlertController(title: "Select a type", message: nil, preferredStyle: .actionSheet)
                
                let types = indexPath.row == 0 ? ["Dictionary", "Array"] : ["String", "Number", "Boolean"]+(self.document?.fileURL.pathExtension.lowercased() == "plist" ? ["Data", "Date"] : ["Null"])
                
                for type in types {
                    typesAlert.addAction(UIAlertAction(title: type, style: .default, handler: { (_) in
                        
                        switch type {
                        case "String":
                            setValue("\(value)")
                        case "Number":
                            setValue(NSNumber(value: Float("\(value)") ?? 0))
                        case "Boolean":
                            setValue(Bool(truncating: NSNumber(value: Float("\(value)") ?? 0)))
                         case "Data":
                            setValue("\(value)".data(using: .utf8) ?? Data())
                        case "Date":
                            setValue(Date())
                        case "Null":
                            setValue(NSNull())
                        case "Dictionary":
                            if let arr = self.element as? NSArray {
                                let dict = NSMutableDictionary()
                                
                                var i = 0
                                for obj in arr {
                                    dict["\(i)"] = obj
                                    i += 1
                                }
                                
                                self.element = dict
                                
                                tableView.reloadData()
                            }
                            
                            return
                        case "Array":
                            if let dict = self.element as? NSDictionary {
                                
                                let arr = NSMutableArray()
                                
                                for (_, value) in dict {
                                    arr.add(value)
                                }
                                
                                self.element = arr
                                
                                tableView.reloadData()
                                
                                return
                            }
                        default:
                            break
                        }
                        
                        showSheet()
                    }))
                }
                
                typesAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                    showSheet()
                }))
                
                typesAlert.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
                typesAlert.popoverPresentationController?.sourceRect = tableView.cellForRow(at: indexPath)?.bounds ?? .zero
                
                self.present(typesAlert, animated: true, completion: nil)
            }
            
            func changeValue() {
                guard let value = _value else {
                    return
                }
                
                let valueAlert = UIAlertController(title: alert.title, message: nil, preferredStyle: .actionSheet)
                
                let description = "\((value is NSNumber && self.isBoolNumber(num: value as! NSNumber)) ? ((value as! Bool) ? "YES" : "NO") : value)"
                if !(value is NSNull) {
                    valueAlert.addAction(UIAlertAction(title: "\(description)".isEmpty ? "Set" : "\(description)", style: .default, handler: { (_) in
                        
                        if let num = value as? NSNumber, self.isBoolNumber(num: num) {
                            let alert = UIAlertController(title: key, message: "Change value", preferredStyle: .alert)
                            
                            let _switch = UISwitch()
                            _switch.isOn = (value as? Bool) ?? false

                            let controller = UIViewController()

                            _switch.center = controller.view.center
                            _switch.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
                            controller.view.addSubview(_switch)

                            alert.setValue(controller, forKey: "contentViewController")
                            
                            alert.addAction(UIAlertAction(title: "Confirm", style: .default, handler: { (_) in
                                setValue(_switch.isOn)
                            }))

                            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                                showSheet()
                            }))
                            
                            self.present(alert, animated: true, completion: nil)
                        } else if value is NSNumber {
                            let alert = UIAlertController(title: key, message: "Change value", preferredStyle: .alert)
                            
                            var textField: UITextField?
                            
                            alert.addTextField { (_textField) in
                                _textField.keyboardType = .decimalPad
                                _textField.text = "\(value)"
                                textField = _textField
                            }
                            
                            alert.addAction(UIAlertAction(title: "Confirm", style: .default, handler: { (_) in
                                if let text = textField?.text?.replacingOccurrences(of: ",", with: "."), !text.isEmpty {
                                    setValue(NSNumber(value: Float(text) ?? 0))
                                } else {
                                    showSheet()
                                }
                            }))
                            
                            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                                showSheet()
                            }))
                            
                            self.present(alert, animated: true, completion: nil)
                        } else if value is NSString {
                            let alert = UIAlertController(title: key, message: "Change value", preferredStyle: .alert)
                            
                            let textView = UITextView()
                            textView.text = value as? String
                            textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

                            let controller = UIViewController()

                            textView.frame = controller.view.frame
                            controller.view.addSubview(textView)

                            alert.setValue(controller, forKey: "contentViewController")

                            let height: NSLayoutConstraint = NSLayoutConstraint(item: alert.view ?? UIView(), attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: self.view.frame.height * 0.8)
                            alert.view.addConstraint(height)
                            
                            alert.addAction(UIAlertAction(title: "Confirm", style: .default, handler: { (_) in
                                setValue(textView.text ?? "")
                            }))

                            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                                showSheet()
                            }))
                            
                            self.present(alert, animated: true, completion: {
                                textView.becomeFirstResponder()
                            })
                        } else if let date = value as? Date {
                            let alert = UIAlertController(title: key, message: "Change value", preferredStyle: .alert)
                            
                            let picker = UIDatePicker()
                            picker.datePickerMode = .dateAndTime
                            picker.date = date

                            let controller = UIViewController()
                            picker.center = controller.view.center
                            picker.autoresizingMask = [.flexibleBottomMargin, .flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
                            controller.view.addSubview(picker)

                            alert.setValue(controller, forKey: "contentViewController")
                            alert.addAction(UIAlertAction(title: "Confirm", style: .default, handler: { (_) in
                                setValue(picker.date)
                            }))

                            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                                showSheet()
                            }))
                            
                            self.present(alert, animated: true, completion: nil)
                        } else if let data = value as? Data {
                            let alert = UIAlertController(title: key, message: "Change value\nPaste a base 64 encoded string", preferredStyle: .alert)
                            
                            let textView = UITextView()
                            textView.text = data.base64EncodedString()
                            textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

                            let controller = UIViewController()

                            textView.frame = controller.view.frame
                            controller.view.addSubview(textView)

                            alert.setValue(controller, forKey: "contentViewController")

                            let height: NSLayoutConstraint = NSLayoutConstraint(item: alert.view ?? UIView(), attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: self.view.frame.height * 0.8)
                            alert.view.addConstraint(height)
                            
                            alert.addAction(UIAlertAction(title: "Confirm", style: .default, handler: { (_) in
                                var components = textView.text.components(separatedBy: "base64,")
                                if components.count > 1 {
                                    components.remove(at: 0)
                                }
                                setValue(Data(base64Encoded: components.joined()) ?? Data())
                            }))

                            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                                showSheet()
                            }))
                            
                            self.present(alert, animated: true, completion: {
                                textView.becomeFirstResponder()
                            })
                        }
                    }))
                }
                
                valueAlert.addAction(UIAlertAction(title: self.type(of: value), style: .default, handler: { (_) in
                    selectType()
                }))
                
                valueAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                
                valueAlert.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
                valueAlert.popoverPresentationController?.sourceRect = tableView.cellForRow(at: indexPath)?.bounds ?? .zero
                
                self.present(valueAlert, animated: true, completion: nil)
            }
            
            if indexPath.row != 0 {
                alert.addAction(UIAlertAction(title: "Change value", style: .default, handler: { (_) in
                    changeValue()
                }))
            } else {
                alert.addAction(UIAlertAction(title: self.type(of: element), style: .default, handler: { (_) in
                    selectType()
                }))
            }
            
            if let dict = element as? NSDictionary, indexPath.row != 0, let key = key {
                alert.addAction(UIAlertAction(title: "Change key", style: .default, handler: { (_) in
                    let keyAlert = UIAlertController(title: key, message: "Change key", preferredStyle: .alert)
                    
                    var textField: UITextField?
                    
                    keyAlert.addTextField { (_textField) in
                        _textField.text = key
                        textField = _textField
                    }
                    
                    keyAlert.addAction(UIAlertAction(title: "Confirm", style: .default, handler: { (_) in
                        if let textField = textField, let str = textField.text, !str.isEmpty {
                            let mutable = NSMutableDictionary(dictionary: dict)
                            let obj = mutable[key]
                            mutable.removeObject(forKey: key)
                            mutable[str] = obj
                            self.element = mutable
                            
                            tableView.reloadData()
                        } else {
                            showSheet()
                        }
                    }))
                    
                    keyAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                        showSheet()
                    }))
                    
                    self.present(keyAlert, animated: true, completion: nil)
                }))
            }
            
            if !(indexPath.row == 0 && self.key == nil) {
                alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in
                    if indexPath.row == 0 {
                        
                        if let key = self.key, let element = self.parentElement?.element as? [String:Any] {
                            let dict = NSMutableDictionary(dictionary: element)
                            dict[key] = nil
                            self.parentElement?.element = dict
                        } else if let element = self.parentElement?.element as? [Any] {
                            let arr = NSMutableArray(array: element)
                            arr.removeObject(at: indexPath.row)
                            self.parentElement?.element = arr
                        }
                        
                        self.navigationController?.popViewController(animated: true)
                    } else {
                        if let key = key, let element = self.element as? [String:Any] {
                            let dict = NSMutableDictionary(dictionary: element)
                            dict[key] = nil
                            self.element = dict
                        } else if let element = self.element as? [Any] {
                            let arr = NSMutableArray(array: element)
                            arr.removeObject(at: indexPath.row-1)
                            self.element = arr
                        }
                        
                        tableView.reloadData()
                    }
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            alert.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
            alert.popoverPresentationController?.sourceRect = tableView.cellForRow(at: indexPath)?.bounds ?? .zero
        
            if !isPresentedFromContextMenu {
                present(alert, animated: true, completion: nil)
            } else {
                changeValue()
            }
            
            return
        }
        
        if indexPath.row == 0 {
            return showSheet()
        }
                    
        if _value is NSDictionary || _value is NSArray {
            guard let vc = storyboard?.instantiateViewController(withIdentifier: "DocumentViewController") as? DocumentViewController else {
                return
            }
            
            vc.loadViewIfNeeded()
            
            vc.navigationItem.largeTitleDisplayMode = .never
            
            vc.isDocOpen = isDocOpen
            vc.document = document
            vc.key = key ?? "\(indexPath.row-1)"
            vc.element = (element as? NSArray)?[indexPath.row-1] ?? (element as? NSDictionary)?[vc.key ?? ""] ?? [String:Any]()
            vc.parentElement = self
            
            navigationController?.pushViewController(vc, animated: true)
        } else {
            showSheet()
        }
    }
    
    // MARK: - Text view delegate
    
    func textViewDidEndEditing(_ textView: UITextView) {
        let pathExtension = document?.fileURL.pathExtension.lowercased()
        
        let data = textView.text.data(using: .utf8) ?? Data()
        
        do {
            if pathExtension == "json" {
                element = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            } else if pathExtension == "plist" {
                
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tmp.plist")
                try data.write(to: url)
                
                element = (NSDictionary(contentsOfFile: url.path) ?? NSArray(contentsOf: url)) ?? [String:Any]()
            }
        } catch {
            print(error.localizedDescription)
        }
        
        tableView.reloadData()
    }
    
    // MARK: - Context menu interaction delegate
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        
        guard let cell = interaction.view as? UITableViewCell else {
            return nil
        }
        
        guard let indexPath = self.tableView.indexPath(for: cell) else {
            return nil
        }
        
        let key: String?
        
        if indexPath.row != 0 {
            key = (element as? NSDictionary)?.allKeys[indexPath.row-1] as? String
        } else if element is NSArray && indexPath.row != 0 {
            key = nil
        } else {
            key = self.key ?? "Root"
        }
        
        let _value: Any?
        if let key = key, let element = self.element as? [String:Any] {
            _value = element[key]
        } else if let element = self.element as? [Any], indexPath.row != 0 {
            _value = element[indexPath.row-1]
        } else {
            _value = nil
        }
        
        guard let value = _value else {
            return nil
        }
        
        var stringValue: String {
            if value is NSDictionary || value is NSArray {
                let pathExtension = self.document?.fileURL.pathExtension.lowercased()
                if pathExtension == "json" {
                    if let data = try? JSONSerialization.data(withJSONObject: value, options: JSONSerialization.WritingOptions.prettyPrinted), let str = String(data: data, encoding: .utf8) {
                        return str
                    }
                } else if pathExtension == "plist" {
                    
                    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tmp.plist")
                    
                    if let propertyListDict = value as? [String:Any] {
                        let dict = NSDictionary(dictionary: propertyListDict)
                        try? dict.write(to: url)
                    } else if let propertyListArray = value as? [Any] {
                        let arr = NSArray(array: propertyListArray)
                        try? arr.write(to: url)
                    }
                    
                    return (try? String(contentsOf: url)) ?? ""
                }
            } else {
                return "\(value)"
            }
            
            return ""
        }
        
        let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { action in
            self.tableView(self.tableView, didSelectRowAt: indexPath)
        }
        
        let duplicate = UIAction(title: "Duplicate", image: UIImage(systemName: "doc.on.doc.fill")) { action in
            
            guard let key = key else {
                return
            }
            
            if let arr = self.element as? NSArray {
                let mutable = NSMutableArray(array: arr)
                mutable.insert(value, at: indexPath.row+1)
                self.element = mutable
                self.tableView.reloadData()
            } else if let dict = self.element as? NSDictionary {
                let mutable = NSMutableDictionary(dictionary: dict)
                
                var i = 1
                
                var _key = key
                
                while let last = _key.last, Int(String(last)) != nil {
                    _key.removeLast()
                }
                
                var newKey: String {
                    return _key+"\(i)"
                }
                
                while dict[newKey] != nil {
                    i += 1
                }
                
                mutable[newKey] = value
                
                self.element = mutable
                self.tableView.reloadData()
            }
        }
        
        let rename = UIAction(title: "Rename", image: UIImage(systemName: "tag.fill")) { action in
            
            if let dict = self.element as? NSDictionary, indexPath.row != 0, let key = key {
                let keyAlert = UIAlertController(title: key, message: "Change key", preferredStyle: .alert)
                
                var textField: UITextField?
                
                keyAlert.addTextField { (_textField) in
                    _textField.text = key
                    textField = _textField
                }
                
                keyAlert.addAction(UIAlertAction(title: "Confirm", style: .default, handler: { (_) in
                    if let textField = textField, let str = textField.text, !str.isEmpty {
                        let mutable = NSMutableDictionary(dictionary: dict)
                        let obj = mutable[key]
                        mutable.removeObject(forKey: key)
                        mutable[str] = obj
                        self.element = mutable
                        
                        self.tableView.reloadData()
                    }
                }))
                
                keyAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                
                self.present(keyAlert, animated: true, completion: nil)
            }
        }
        
        let copy = UIAction(title: "Copy value", image: UIImage(systemName: "doc.on.clipboard")) { action in
            UIPasteboard.general.string = stringValue
        }
        
        let newWindow = UIAction(title: "Open in new Window", image: UIImage(systemName: "plus.square.fill")) { action in
            
            guard let vc = self.storyboard?.instantiateViewController(withIdentifier: "DocumentViewController") as? DocumentViewController else {
                return
            }
            
            vc.loadViewIfNeeded()
            
            vc.navigationItem.largeTitleDisplayMode = .never
            
            vc.document = self.document
            vc.key = key ?? "\(indexPath.row-1)"
            vc.element = (self.element as? NSArray)?[indexPath.row-1] ?? (self.element as? NSDictionary)?[vc.key ?? ""] ?? [String:Any]()
            vc.parentElement = self
            
            SceneDelegate.customViewController = UINavigationController(rootViewController: vc)
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil, errorHandler: nil)
        }
        
        let inspectWithJS = UIAction(title: "Inspect with JavaScript", image: UIImage(systemName: "chevron.left.slash.chevron.right")) { action in
            guard let context = JSContext() else {
                return
            }
            context.setObject(value, forKeyedSubscript: "value" as NSCopying & NSObjectProtocol)
            
            let console = ConsoleViewController()
            console.context = context
            console.editor = self
            console.key = key ?? "\(indexPath.row-1)"
            let navVC = UINavigationController(rootViewController: console)
            navVC.modalPresentationStyle = .fullScreen
            self.present(navVC, animated: true, completion: nil)
        }
        
        let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash.fill"), attributes: .destructive) { action in
            
            if indexPath.row == 0 {
                if let key = self.key, let element = self.parentElement?.element as? [String:Any] {
                    let dict = NSMutableDictionary(dictionary: element)
                    dict[key] = nil
                    self.parentElement?.element = dict
                } else if let element = self.parentElement?.element as? [Any] {
                    let arr = NSMutableArray(array: element)
                    arr.removeObject(at: indexPath.row)
                    self.parentElement?.element = arr
                }
                
                self.navigationController?.popViewController(animated: true)
            } else {
                if let key = key, let element = self.element as? [String:Any] {
                    let dict = NSMutableDictionary(dictionary: element)
                    dict[key] = nil
                    self.element = dict
                } else if let element = self.element as? [Any] {
                    let arr = NSMutableArray(array: element)
                    arr.removeObject(at: indexPath.row-1)
                    self.element = arr
                }
                
                self.tableView.reloadData()
            }
        }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: { () -> UIViewController? in
            
            let vc = UIViewController()
            
            vc.view = UITextView()
            
            let textView = (vc.view as! UITextView)
            textView.text = stringValue
            textView.backgroundColor = .systemBackground
            textView.textColor = .label
            textView.font = UIFont(name: "Menlo", size: UIFont.systemFontSize)
            
            return vc
        }) { (_) -> UIMenu? in
            
            let children: [UIAction]
            
            if indexPath.row == 0 {
                children = [delete]
            } else if UIDevice.current.userInterfaceIdiom == .pad {
                if self.element is NSDictionary {
                    if value is NSDictionary || value is NSArray {
                        children = [edit, inspectWithJS, rename, duplicate, copy, newWindow, delete]
                    } else {
                        children = [edit, inspectWithJS, rename, duplicate, copy, delete]
                    }
                } else if self.element is NSArray {
                    if value is NSDictionary || value is NSArray {
                        children = [edit, inspectWithJS, duplicate, copy, newWindow, delete]
                    } else {
                        children = [edit, inspectWithJS, duplicate, copy, delete]
                    }
                } else {
                    children = [edit, inspectWithJS, duplicate, copy, delete]
                }
            } else {
                if self.element is NSDictionary {
                    children = [edit, inspectWithJS, rename, duplicate, copy, delete]
                } else {
                    children = [edit, inspectWithJS, duplicate, copy, delete]
                }
            }
            
            return UIMenu(title: cell.textLabel?.text ?? "", children: children)
        }
    }
}
