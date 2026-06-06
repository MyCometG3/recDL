//
//  PrefController.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/12/09.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa

@objcMembers
@MainActor
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
    @IBOutlet weak var audioBitRateErrorLabel: NSTextField!

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
        // The XIB binds `textAudioBitRate.value` to
        // `values.audioBitRate`, so by the time this IBAction fires the
        // (possibly invalid) value has already been written to
        // `Keys.audioBitRate` via `NSUserDefaultsController`. If we let
        // an out-of-range value reach `applyRecordingParameters()` (in
        // `AppDelegate+Session.swift`), the recording pipeline will
        // happily produce a movie with an invalid AAC bitrate.
        //
        // Clamp the value here — both the text field and the defaults
        // — so the recording pipeline never sees an out-of-range
        // bitrate. The `adjustAudioEncoder()` call below then maps the
        // (now in-range) value to the right AAC variant.
        let kbps = textAudioBitRate.integerValue
        if kbps < Self.audioBitRateMinKbps || kbps > Self.audioBitRateMaxKbps {
            let clamped = min(max(kbps, Self.audioBitRateMinKbps), Self.audioBitRateMaxKbps)
            textAudioBitRate.integerValue = clamped
            defaults.set(clamped, forKey: Keys.audioBitRate)
            appDelegate.printVerbose("ERROR:\(self.className): \(#function) - Audio bit rate out of range: \(kbps) kbps, clamped to \(clamped) kbps (valid: \(Self.audioBitRateMinKbps)–\(Self.audioBitRateMaxKbps))")
        }
        
        adjustAudioEncoder()
        
        // Refresh the UI so the error label state reflects the new
        // value immediately (without this, the user would have to
        // toggle another control to see the error / non-error state).
        refreshUI()
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
        
        // Validate the audio bit rate text field. Mirrors the range
        // check in `adjustAudioEncoder()` but is decoupled so the
        // label reflects the current field state even when the user
        // is mid-edit and the IBAction has not yet fired.
        let kbps = textAudioBitRate.integerValue
        let audioBitRateOK = kbps >= Self.audioBitRateMinKbps
            && kbps <= Self.audioBitRateMaxKbps
        audioBitRateErrorLabel.isHidden = audioBitRateOK
    }
    
    private func updateAudioLayout() {
        let audioChannelLayoutOK = appDelegate.verifyHDMIAudioChannelLayoutReady()
        segAudioChannelLayout.isEnabled = audioChannelLayoutOK
        btnReverse34.isEnabled = audioChannelLayoutOK
    }
    
    /// Inclusive broad valid range for the audio bit rate text field, in kbps.
    /// This keeps the UI wide enough for the highest AAC LC bitrate accepted
    /// by the current recording pipeline (7.1 without LFE = 1120 kbps).
    /// Lower per-layout ceilings are still enforced later by
    /// `applyRecordingParameters()` via `queryBitrateRange(channelCount:)`.
    private static let audioBitRateMinKbps: Int = 16
    private static let audioBitRateMaxKbps: Int = 1120
    
    private func adjustAudioEncoder() {
        let useAudioBitRateKbps: Int = textAudioBitRate.integerValue
        let useAudioBitRate = useAudioBitRateKbps * 1000
        
        // Reject out-of-range input (empty, non-numeric → 0, negative,
        // or absurdly large). The previous implementation silently fell
        // through to HE-AACv2 in the `else` branch, which would record
        // near-silent audio with no feedback to the user.
        if useAudioBitRateKbps < Self.audioBitRateMinKbps
            || useAudioBitRateKbps > Self.audioBitRateMaxKbps {
            // Leave the previous valid `audioEncoder` defaults value
            // untouched and surface the error via the existing label
            // infrastructure. `refreshUI()` → `updateErrorLabel()`
            // (see below) takes care of show/hide.
            //
            appDelegate.printVerbose("ERROR:\(self.className): \(#function) - Audio bit rate out of range: \(useAudioBitRateKbps) kbps (valid: \(Self.audioBitRateMinKbps)–\(Self.audioBitRateMaxKbps))")
            return
        }
        
        if useAudioBitRate > AudioConstants.aacBitrateThreshold {
            defaults.set(1, forKey: Keys.audioEncoder)
        } else if useAudioBitRate > AudioConstants.aacHEBitrateThreshold {
            defaults.set(2, forKey: Keys.audioEncoder)
        } else {
            defaults.set(3, forKey: Keys.audioEncoder)
        }
    }
}
