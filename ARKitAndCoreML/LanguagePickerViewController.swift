//
//  LanguagePickerViewController.swift
//  ARKitAndCoreML
//
//  Created by HDO on 1/26/19.
//  Copyright © 2019 Henry Do. All rights reserved.
//

import Foundation
import UIKit

class LanguagePickerViewController : UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    
    @IBOutlet weak var languagePickerView: UIPickerView!
    
    let languages = [
    ["Arabic", "af"],
    ["Chinese (Simplified)", "zh-CN"],
    ["Chinese (Traditional)", "zh-TW"],
    ["Danish", "da"],
    ["Dutch", "nl"],
    ["English", "en"],
    ["Finnish", "fi"],
    ["French", "fr"],
    ["German", "de"],
    ["Greek", "el"],
    ["Hebrew", "he"],
    ["Hindi", "hi"],
    ["Hungarian", "hu"],
    ["Icelandic", "is"],
    ["Indonesian", "id"],
    ["Irish", "ga"],
    ["Italian", "it"],
    ["Japanese", "ja"],
    ["Korean", "ko"],
    ["Latin", "la"],
    ["Romanian", "ro"],
    ["Russian", "ru"],
    ["Spanish", "es"],
    ["Thai", "th"],
    ["Vietnamese", "vi"]
    ]
    
    var selectedLanguage : Array<String> = ["English", "en"]
    
    // Picker Actions
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return languages.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return languages[row][0]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedLanguage = languages[row]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.languagePickerView.delegate = self
        self.languagePickerView.dataSource = self
        
        var index : Int = 0
        
        for (i, e) in languages.enumerated() {
            if (e[0] == selectedLanguage[0]) {
                index = i
            }
        }

        self.languagePickerView.selectRow(index, inComponent: 0, animated: false)
    }
}
