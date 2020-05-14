//
//  PrefController.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/12/09.
//  Copyright © 2017-2020年 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa

@objcMembers
class PrefController: NSViewController {
    private lazy var defaults = UserDefaults.standard
    
    @IBOutlet weak var prefWindow :NSWindow!
    @IBOutlet weak var appDelegate :AppDelegate!
    
    @IBAction func showPreferences(_ sender: AnyObject) {
        prefWindow.makeKeyAndOrderFront(self)
        setup()
    }
    
    @IBAction func checkParameterError(_ sender: Any) {
        updateErrorLabel()
    }
    
    @IBAction func updateDisplayMode(_ sender: Any) {
        updateDescription()
        updateErrorLabel()
    }
    
    @IBAction func resetStyle(_ sender: Any) {
        if appDelegate.resetStyleCurrent() {
            updateDescription()
            updateErrorLabel()
        }
    }
    
    @IBOutlet weak var btnDisplayMode: NSPopUpButton!
    @IBOutlet weak var menuDisplayMode: NSMenu!
    @IBOutlet weak var btnVideoConnection: NSPopUpButton!
    @IBOutlet weak var menuVideoConnection: NSMenu!
    @IBOutlet weak var btnAudioConnection: NSPopUpButton!
    @IBOutlet weak var menuAudioConnection: NSMenu!
    @IBOutlet weak var btnRestartSession: NSButton!
    
    @IBOutlet var descriptionText: NSTextView!
    @IBOutlet weak var vsErrorLabel: NSTextField!
    @IBOutlet weak var clapErrorLabel: NSTextField!
    
    private func setup() {
        // Check device readiness
        let ready = appDelegate.checkReadiness()
        btnDisplayMode.isEnabled = ready
        btnVideoConnection.isEnabled = ready
        btnAudioConnection.isEnabled = ready
        btnRestartSession.isEnabled = ready
        guard ready else {
            descriptionText.string = "ERROR: No DeckLink device is detected."
            return
        }
        
        //
        updateAudioEncoder(self)
        
        // Fill DisplayMode/VideoConnection/AudioConnection menu
        let dmSelection = appDelegate.updateDisplayModeMenu(menuDisplayMode)
        let vcSelection = appDelegate.updateVideoConnectionMenu(menuVideoConnection)
        let acSelection = appDelegate.updateAudioConnectionMenu(menuAudioConnection)
        
        // Workaround: Value binding may not work as expected
        if dmSelection >= 0 { btnDisplayMode.selectItem(withTag: dmSelection) }
        if vcSelection >= 0 { btnVideoConnection.selectItem(withTag: vcSelection) }
        if acSelection >= 0 { btnAudioConnection.selectItem(withTag: acSelection) }
        
        //
        updateDescription()
        updateErrorLabel()
    }
    
    private func updateDescription() {
        let size = NSFont.systemFontSize(for: NSControl.ControlSize.mini)
        descriptionText.font = NSFont.userFixedPitchFont(ofSize: size)
        
        let desc = "# " + appDelegate.deviceDescription() + "\n# " + appDelegate.displayModeDescription()
        descriptionText.string = desc
    }
    
    private func updateErrorLabel() {
        let (videoStyleOK, clapOK) = appDelegate.verifyCompatibility()
        vsErrorLabel.isHidden = videoStyleOK
        clapErrorLabel.isHidden = clapOK
    }
    
    /* ============================================================================= */
    
    @IBOutlet weak var buttonAudioEncode: NSButton!
    @IBOutlet weak var textAudioBitRate: NSTextField!
    
    @IBAction func updateAudioEncoder(_ sender: Any) {
        //let useAudioEncode :Bool = buttonAudioEncode.state == .on
        let useAudioBitRate :Int = textAudioBitRate.integerValue
        
        if useAudioBitRate > 80 {
            defaults.set(1, forKey: Keys.audioEncoder)
        } else if useAudioBitRate > 40 {
            defaults.set(2, forKey: Keys.audioEncoder)
        } else {
            defaults.set(3, forKey: Keys.audioEncoder)
        }
    }
    
    @IBAction func restartSession(_ sender: Any) {
        //
        let userInfo : [String:Any]? = nil
        let notification = Notification(name: .restartSessionNotificationKey, object: self, userInfo: userInfo)
        NotificationCenter.default.post(notification)
    }
}
