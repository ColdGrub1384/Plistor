//
//  UITextView.swift
//  Plistor
//
//  Created by Adrian Labbé on 19-12-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit

extension UITextView {
    
    /// Scrolls to bottom.
    func scrollToBottom() {
        
        let text_ = text
        
        let range = NSMakeRange(((text_ ?? "") as NSString).length - 1, 1)
        scrollRangeToVisible(range)
    }
}
