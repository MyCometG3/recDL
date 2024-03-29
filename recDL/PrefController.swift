//
//  PrefController.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/12/09.
//  Copyright © 2017-2024 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa

@objcMembers
class PrefController: NSViewController {
    private lazy var defaults = UserDefaults.standard
    
    /* ============================================================================= */
    //MARK: - IBOutlet
    /* ============================================================================= */
    
    @IBOutlet weak var prefWindow :NSWindow!
    @IBOutlet weak var appDelegate :AppDelegate!
    
    @IBOutlet weak var btnDisplayMode: NSPopUpButton!
    @IBOutlet weak var menuDisplayMode: NSMenu!
    @IBOutlet weak var btnVideoConnection: NSPopUpButton!
    @IBOutlet weak var menuVideoConnection: NSMenu!
    @IBOutlet weak var btnAudioConnection: NSPopUpButton!
    @IBOutlet weak var menuAudioConnection: NSMenu!
    @IBOutlet weak var btnRestartSession: NSButton!
    @IBOutlet weak var menuVideoStyle: NSMenu!
    @IBOutlet weak var menuFieldDominance: NSMenu!
    @IBOutlet weak var segAudioChannelLayout: NSSegmentedControl!
    @IBOutlet weak var btnReverse34: NSButton!
    
    @IBOutlet var descriptionText: NSTextView!
    @IBOutlet weak var vsErrorLabel: NSTextField!
    @IBOutlet weak var clapErrorLabel: NSTextField!
    @IBOutlet weak var fdErrorLabel: NSTextField!

    @IBOutlet weak var buttonAudioEncode: NSButton!
    @IBOutlet weak var textAudioBitRate: NSTextField!
    
    /* ============================================================================= */
    //MARK: - IBAction
    /* ============================================================================= */
    
    @IBAction func showPreferences(_ sender: AnyObject) {
        prefWindow.makeKeyAndOrderFront(self)
        setup()
    }
    
    @IBAction func updateVideoStyle(_ sender: Any) {
        refreshUI()
    }
    
    @IBAction func updateDisplayMode(_ sender: Any) {
        refreshUI()
    }
    
    @IBAction func updateVideoConnection(_ sender: Any) {
        refreshUI()
    }
    
    @IBAction func updateAudioConnection(_ sender: Any) {
        refreshUI()
    }
    
    @IBAction func updateAudioChannel(_ sender: Any) {
        refreshUI()
    }
    
    @IBAction func resetStyle(_ sender: Any) {
        if appDelegate.resetStyleCurrent() {
            refreshUI()
        }
    }

    @IBAction func updateAudioEncoder(_ sender: Any) {
        adjustAudioEncoder()
    }
    
    @IBAction func restartSession(_ sender: Any) {
        //
        let userInfo : [String:Any]? = nil
        let notification = Notification(name: .restartSessionNotificationKey, object: self, userInfo: userInfo)
        NotificationCenter.default.post(notification)
    }
    
    /* ============================================================================= */
    //MARK: - private func
    /* ============================================================================= */
    
    private func setup() {
        // Adjust detail text font size
        let size:CGFloat = 9.8//NSFont.systemFontSize(for: NSControl.ControlSize.mini)
        descriptionText.font = NSFont.userFixedPitchFont(ofSize: size)
        
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
        
        // Fill DisplayMode/VideoConnection/AudioConnection menu
        let dmSelection = appDelegate.updateDisplayModeMenu(menuDisplayMode)
        let vcSelection = appDelegate.updateVideoConnectionMenu(menuVideoConnection)
        let acSelection = appDelegate.updateAudioConnectionMenu(menuAudioConnection)
        
        // Workaround: Value binding may not work as expected
        if dmSelection >= 0 { btnDisplayMode.selectItem(withTag: dmSelection) }
        if vcSelection >= 0 { btnVideoConnection.selectItem(withTag: vcSelection) }
        if acSelection >= 0 { btnAudioConnection.selectItem(withTag: acSelection) }
        
        //
        adjustAudioEncoder()
        
        //
        refreshUI()
    }
    
    private func refreshUI() {
        updateVideoStyle()
        updateFieldDominance()
        updateDescription()
        updateErrorLabel()
        updateAudioLayout()
    }
    
    private func updateVideoStyle() {
        appDelegate.updateVideoStyleMenu(menuVideoStyle)
    }
    
    private func updateFieldDominance() {
        appDelegate.updateFieldDominanceMenu(menuFieldDominance)
    }
    
    private func updateDescription() {
        let desc = "# " + appDelegate.deviceDescription() + "\n# " + appDelegate.displayModeDescription() + "\n# " + appDelegate.videoStyleDescription()
        descriptionText.string = desc
    }
    
    private func updateErrorLabel() {
        let (videoStyleOK, clapOK, fdOK) = appDelegate.verifyCompatibility()
        vsErrorLabel.isHidden = videoStyleOK
        clapErrorLabel.isHidden = clapOK
        fdErrorLabel.isHidden = fdOK
    }
    
    private func updateAudioLayout() {
        let audioChannelLayoutOK = appDelegate.verifyHDMIAudioChannelLayoutReady()
        segAudioChannelLayout.isEnabled = audioChannelLayoutOK
        btnReverse34.isEnabled = audioChannelLayoutOK
    }
    
    private func adjustAudioEncoder() {
        let useAudioBitRate :Int = textAudioBitRate.integerValue
        
        if useAudioBitRate > 80 {
            defaults.set(1, forKey: Keys.audioEncoder)
        } else if useAudioBitRate > 40 {
            defaults.set(2, forKey: Keys.audioEncoder)
        } else {
            defaults.set(3, forKey: Keys.audioEncoder)
        }
    }
}
