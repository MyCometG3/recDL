//
//  AppDelegate.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/10/07.
//  Copyright © 2017年 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
import CoreVideo
import DLABridging
import DLABCaptureManager

@NSApplicationMain
@objcMembers
class AppDelegate: NSObject, NSApplicationDelegate {
    
    /* ============================================ */
    // MARK: - Variables
    /* ============================================ */
    
    private lazy var defaults = UserDefaults.standard
    private lazy var notificationCenter = NotificationCenter.default
    
    public private(set) var manager : DLABCaptureManager? = nil
    private var previewLayerReady : Bool = false
    private var updateTimer : Timer? = nil
    private var stopTimer : Timer? = nil
    
    private var evalAutoQuitFlag : Bool = false
    private var targetPath : String? = nil
    
    private var iconActiveState = false
    private let iconIdle = NSImage(named:NSImage.Name(Keys.idle))
    private let iconInactive = NSImage(named:NSImage.Name(Keys.inactive))
    private let iconActive = NSImage(named:NSImage.Name(Keys.active))
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var parentView: CaptureVideoPreview! //NSView!
    @IBOutlet weak var recordForMin: NSTextField!
    
    @IBOutlet weak var recordingButton: NSButton!
    @IBOutlet weak var scalePopup: NSPopUpButton!
    @IBOutlet weak var volumePopup: NSPopUpButton!
    
    @IBOutlet weak var scaleNow: NSMenuItem!
    @IBOutlet weak var volumeNow: NSMenuItem!
    
    @IBOutlet weak var accessoryView: NSView!
    
    /* ============================================ */
    // MARK: - Scripting support
    /* ============================================ */
    
    override func application(_ sender :NSApplication, delegateHandlesKey key :String) -> Bool {
        // print("\(#file) \(#line) \(#function)")
        
        let supportedParameter = [Keys.sessionItem,
                                  Keys.recordingItem,
                                  Keys.folderURL,
                                  Keys.useVideoPreview,
                                  Keys.useAudioPreview]
        if supportedParameter.contains(key) {
            // print("- delegate handles: \(key)")
            return true
        } else {
            // print("- delegate do not handles: \(key)")
            return false
        }
    }
    
    private lazy var _sessionItem :RDL1Session = RDL1Session()
    public var sessionItem :RDL1Session? {
        get { return _sessionItem }
    }
    
    private lazy var _recordingItem :RDL1Recording = RDL1Recording()
    public var recordingItem :RDL1Recording? {
        get { return _recordingItem }
    }
    
    public var folderURL: URL? {
        get { return movieFolder() }
        set { self.defaults.set(newValue, forKey: Keys.movieFolder) }
    }
    
    public var useVideoPreview: Bool {
        get { return !defaults.bool(forKey: Keys.showAlternate) }
        set {
            defaults.set(!newValue, forKey: Keys.showAlternate)
            setScale(-1)                        // Update Popup Menu Selection
        }
    }
    public var useAudioPreview: Bool {
        get { return !defaults.bool(forKey: Keys.forceMute) }
        set {
            defaults.set(!newValue, forKey: Keys.forceMute)
            setVolume(-1)                       // Update Popup Menu Selection
        }
    }
    
    public func registerObserverForScriptingSupport() {
        // print("\(#file) \(#line) \(#function)")
        
        // Register notification observer for Cocoa scripting support
        notificationCenter.addObserver(self,
                                       selector: #selector(handleRestartSession),
                                       name: .handleRestartSessionKey,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(handleStartRecording),
                                       name: .handleStartRecordingKey,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(handleStopRecording),
                                       name: .handleStopRecordingKey,
                                       object: nil)
    }
    
    public func handleRestartSession(_ notification: Notification) {
        // print("\(#file) \(#line) \(#function)")
        
        // Synchronous operation for Script support
        restartSession(notification)
    }
    
    public func handleStartRecording(_ notification: Notification) {
        // print("\(#file) \(#line) \(#function)")
        
        //
        targetPath = nil
        var length : Int = 0
        
        if let userInfo = notification.userInfo {
            if let item = userInfo[Keys.fileURL] as? URL {
                targetPath = item.path
            }
            if let item = userInfo[Keys.maxSeconds] as? Float {
                length = Int(item)
            }
            if let item = userInfo[Keys.autoQuit] as? Bool {
                defaults.set(item, forKey: Keys.autoQuit)
            }
        }
        
        // Synchronous operation for Script support
        startRecording(for:length)
    }
    
    public func handleStopRecording(_ notification: Notification) {
        // print("\(#file) \(#line) \(#function)")
        
        // Synchronous operation for Script support
        stopRecording()
    }
    
    /* ======================================================================================== */
    // MARK: - NSApplicationDelegate protocol
    /* ======================================================================================== */
    
    public func applicationDidFinishLaunching(_ aNotification: Notification) {
        // print("\(#file) \(#line) \(#function)")
        
        // Register notification observer for Cocoa scripting support
        registerObserverForScriptingSupport()
        
        // Register notification observer for Restarting AVCaptureSession
        notificationCenter.addObserver(self,
                                       selector: #selector(restartSession),
                                       name: .restartSessionNotificationKey,
                                       object: nil)
        
        // Register defaults values
        var keyValues:[String:Any] = [:]
        keyValues[Keys.displayMode] = DLABDisplayMode.modeNTSC.rawValue         // DLABDisplayMode
        keyValues[Keys.pixelFormat] = DLABPixelFormat.format8BitYUV.rawValue    // DLABPixelFormat
        keyValues[Keys.aspectRatio] = 40033     // 40:33 for DV-NTSC
        keyValues[Keys.scale] = 100             // Video preview scale 100%
        keyValues[Keys.volume] = 100            // Audio preview volume 100%
        keyValues[Keys.volumeTag] = -1          // -1:Vol: now%
        keyValues[Keys.scaleTag] = -1           // -1:Scale: now%
        
        keyValues[Keys.videoStyle] = VideoStyle.SD_720_480_16_9.rawValue
        keyValues[Keys.clapOffsetH] = 0         // SD:+8..-8, HD:+16..-16
        keyValues[Keys.clapOffsetV] = 0         // SD:+8..-8, HD:+16..-16
        keyValues[Keys.videoTimeScale] = 30000  // Video media track time resolution
        keyValues[Keys.timeCodeFormat] = 0      // 0:None, 32:tmcd, 64:tc64
        
        keyValues[Keys.videoEncode] = true      // false:2vuy, true:encode
        keyValues[Keys.videoEncoder] = 1        // 1:ProRes422,2:ProRes422LT,3:ProRes422Proxy
        // 10:H.264, 11:H265, 0:Uncompressed
        keyValues[Keys.videoBitRate] = 25*1000  // videoBitRate (Kbps)
        keyValues[Keys.videoFieldDetail] = 1    // 0:SingleField, 1:BFF, 2:TFF
        
        keyValues[Keys.audioDepth] = 16         // 16:16bit, 32:32bit
        keyValues[Keys.audioEncode] = true      // false:LPCM, true:AAC
        keyValues[Keys.audioEncoder] = 1        // 1:AACLC, 2:HE-AAC(~80Kbps), 3:HE-AACv2(~40Kbps)
        keyValues[Keys.audioBitRate] = 256      // audioBitRate (Kbps)
        keyValues[Keys.audioChannel] = 2        // 0:off, 2:stereo, 3-16:discrete multi channel
        
        //
        keyValues[Keys.showAlternate] = false   // Disable video preview
        keyValues[Keys.forceMute] = false       // Disable audio preview
        keyValues[Keys.hideInvisible] = false   // Hide video preview when invisible
        
        //
        keyValues[Keys.prefix] = "recdl-"       // movie name prefix
        keyValues[Keys.autoQuit] = false        // Quit after recording stopped
        keyValues[Keys.recordFor] = 30          // recording duration in min. (GUI)
        keyValues[Keys.maxSeconds] = 0          // recording duration in sec. (Scripting)
        keyValues[Keys.maxDuration] = 720       // Maximum recording duration in min.
        
        // Register defaults
        defaults.register(defaults: keyValues)
        
        // Show window now
        window.titleVisibility = .hidden
        _ = window.setFrameAutosaveName(NSWindow.FrameAutosaveName(Keys.previewWindow))
        window.makeKeyAndOrderFront(self)
        
        // Ensure CALayer for the ParentView
        if parentView.wantsLayer == false {
            parentView.wantsLayer = true
        }
        
        if let previewLayer = parentView.layer {
            // Set background color
            let grayColor = CGColor(gray: 0.25, alpha: 1.0)
            previewLayer.backgroundColor = grayColor
        }
        
        // TODO: startSession()
        parentView.verbose = true
        startSession()
        
        // Update Toolbar button title
        setVolume(-1)                       // Update Popup Menu Selection
        setScale(-1)                        // Update Popup Menu Selection
        
        // Start Status Update
        startUpdateStatus()
        
        // Update AppIcon to inactive state
        NSApp.applicationIconImage = iconIdle
        
        //
        notificationCenter.addObserver(forName: NSView.frameDidChangeNotification,
                                       object: parentView,
                                       queue: OperationQueue.main,
                                       using: { (notification) -> Void in self.updateCurrentScale() } )
    }
    
    public func applicationWillTerminate(_ aNotification: Notification) {
        // print("\(#file) \(#line) \(#function)")
        
        // Reset AppIcon badge to inactive state
        NSApp.dockTile.badgeLabel = nil
        
        // Stop Status Update
        stopUpdateStatus()
        
        // Stop Session
        removePreviewLayer()
        stopSession()
        
        // Resign notification observer
        notificationCenter.removeObserver(self)
    }
    
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // print("\(#file) \(#line) \(#function)")
        
        return true
    }
    
    /* ======================================================================================== */
    // MARK: - IBAction
    /* ======================================================================================== */
    
    @IBAction func volumeUp(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        var volTag = defaults.integer(forKey: Keys.volume)
        volTag += 5
        volTag = (volTag > 100 ? 100 : volTag)
        setVolume(volTag)
    }
    
    @IBAction func volumeDown(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        var volTag = defaults.integer(forKey: Keys.volume)
        volTag -= 5
        volTag = (volTag < 0 ? 0 : volTag)
        setVolume(volTag)
    }
    
    @IBAction func updateVolume(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        if sender is NSMenuItem {
            let volTag = (sender as! NSMenuItem).tag
            setVolume(volTag)
        }
        if sender is NSPopUpButton {
            let volTag = (sender as! NSPopUpButton).selectedTag()
            setVolume(volTag)
        }
    }
    
    @IBAction func scaleUp(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        var scaleTag = defaults.integer(forKey: Keys.scale)
        scaleTag += 5
        scaleTag = (scaleTag > 200 ? 200 : scaleTag)
        setScale(scaleTag)
    }
    
    @IBAction func scaleDown(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        var scaleTag = defaults.integer(forKey: Keys.scale)
        scaleTag -= 5
        scaleTag = (scaleTag < 50 ? 50 : scaleTag)
        setScale(scaleTag)
    }
    
    @IBAction func updateScale(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        if sender is NSMenuItem {
            let scaleTag = (sender as! NSMenuItem).tag
            setScale(scaleTag)
        }
        if sender is NSPopUpButton {
            let scaleTag = (sender as! NSPopUpButton).selectedTag()
            setScale(scaleTag)
        }
    }
    
    @IBAction func updateAspectRatio(_ sender: AnyObject) {
        print("\(#file) \(#line) \(#function)")
        
        if sender is NSMenuItem {
            let ratioTag = (sender as! NSMenuItem).tag
            setAspectRatio(ratioTag)
        }
        if sender is NSPopUpButton {
            let ratioTag = (sender as! NSPopUpButton).selectedTag()
            setAspectRatio(ratioTag)
        }
    }
    
    @IBAction func togglePreviewAudio(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        DispatchQueue.main.async(execute: {[unowned self] in
            self.setVolume(-1)                       // Update Popup Menu Selection
        })
    }
    
    @IBAction func togglePreviewVideo(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        DispatchQueue.main.async(execute: {[unowned self] in
            self.setScale(-1)                        // Update Popup Menu Selection
        })
    }
    
    @IBAction func toggleRecording(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        if modifier(.option) {
            if let manager = manager, manager.recording {
                // Reject multiple request
                recordingButton.state = NSControl.StateValue.on   // Reset button state
                NSSound.beep()
            } else {
                // Show a save panel sheet
                recordingButton.state = NSControl.StateValue.off  // Reset button state
                actionRecordingFor(sender)
            }
        } else {
            if recordingButton.state == NSControl.StateValue.on {
                // Start recording
                DispatchQueue.main.async(execute: {[unowned self] in
                    self.targetPath = nil       // Use autogenerated movie path
                    self.startRecording(for: 0)
                })
            } else {
                // Stop recording
                DispatchQueue.main.async(execute: {[unowned self] in
                    self.stopRecording()
                })
            }
        }
    }
    
    @IBAction func actionStartRecording(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        // Reject multiple request
        if let manager = manager, (manager.recording || window.attachedSheet != nil) {
            NSSound.beep()
            return
        }
        
        //
        DispatchQueue.main.async(execute: {[unowned self] in
            self.targetPath = nil           // Use autogenerated movie path
            self.startRecording(for:0)
        })
    }
    
    @IBAction func actionStopRecording(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        //
        DispatchQueue.main.async(execute: {[unowned self] in
            self.stopRecording()
        })
    }
    
    @IBAction func actionRecordingFor(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        // Reject multiple request
        if let manager = manager, (manager.recording || window.attachedSheet != nil) {
            NSSound.beep()
            return
        }
        
        // Setup save panel
        let panel = NSSavePanel()
        panel.prompt = "Start Recording"
        panel.directoryURL = movieFolder()
        panel.nameFieldStringValue = movieName()
        panel.accessoryView = accessoryView
        
        // Update duration textfield (in minutes)
        let min = defaults.integer(forKey: Keys.recordFor)
        self.recordForMin.integerValue = min
        
        // Present as a sheet
        panel.beginSheetModal(for: window, completionHandler: {[unowned self] result in
            // print("\(#file) \(#line) \(#function)")
            
            if result == NSApplication.ModalResponse.OK {
                // Update movie file path
                if let targetURL = panel.url {
                    self.targetPath = targetURL.path    // Use specified file path
                } else {
                    self.targetPath = nil   // Use autogenerated file path
                }
                
                // New value from duration textfield (in minutes)
                let min = self.recordForMin.integerValue
                self.defaults.set(min, forKey: Keys.recordFor)
                
                //
                DispatchQueue.main.async(execute: {[unowned self] in
                    self.startRecording(for: min * 60)
                })
            }
        })
    }
    
    @IBAction func actionSetFolder(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        // Setup open panel
        let panel = NSOpenPanel()
        panel.prompt = "Set as Default"
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = movieFolder()!
        
        // Present as a sheet
        panel.beginSheetModal(for: window, completionHandler: {[unowned self] (result) in
            // print("\(#file) \(#line) \(#function)")
            
            if result == NSApplication.ModalResponse.OK, let url = panel.url {
                self.defaults.set(url, forKey: Keys.movieFolder)
            }
        })
    }
    
    /* ======================================================================================== */
    // MARK: - Capture Session support
    /* ======================================================================================== */
    
    public func startSession() {
        // print("\(#file) \(#line) \(#function)")
        
        if manager == nil {
            manager = DLABCaptureManager()
        }
        if let manager = manager {
            // TODO: add input devide selection
            
            guard let _ = manager.findFirstDevice() else { return }
            
            // TODO: add input port selection (audio/video)
            
            let displayModeRaw : UInt32 = UInt32(defaults.integer(forKey: Keys.displayMode))
            guard let displayMode = DLABDisplayMode(rawValue: displayModeRaw) else { return }
            
            let pixelFormatRaw : UInt32 = UInt32(defaults.integer(forKey: Keys.pixelFormat))
            guard let pixelFormat = DLABPixelFormat(rawValue: pixelFormatRaw) else { return }
            
            guard let videoStyleRaw = defaults.string(forKey: Keys.videoStyle) else { return }
            guard let videoStyle = VideoStyle(rawValue: videoStyleRaw) else { return }
            
            let audioDepthRaw : UInt32 = UInt32(defaults.integer(forKey: Keys.audioDepth))
            guard let audioDepth = DLABAudioSampleType(rawValue: audioDepthRaw) else { return }
            let audioChannel : UInt32  = UInt32(defaults.integer(forKey: Keys.audioChannel))
            
            manager.displayMode = displayMode
            manager.pixelFormat = pixelFormat
            manager.videoStyle = videoStyle
            
            manager.audioDepth = audioDepth
            manager.audioChannels = audioChannel
            
            let showAlternate = defaults.bool(forKey: Keys.showAlternate)
            if !showAlternate {
                manager.videoPreview = parentView // as? CaptureVideoPreview
            }
            
            manager.captureStart()
        }
    }
    
    public func stopSession() {
        // print("\(#file) \(#line) \(#function)")
        
        if let manager = manager {
            manager.captureStop()
            self.manager = nil
        }
    }
    
    public func restartSession(_ notification: Notification) {
        // print("\(#file) \(#line) \(#function)")
        
        // Check user choosen input port (audio/video)
        // modify if required
        
        // Stop Session
        DispatchQueue.main.async(execute: {[unowned self] in
            self.defaults.set(false, forKey: Keys.showAlternate)
            
            self.removePreviewLayer()
            self.manager?.videoPreview = nil
            self.stopSession()
        })
        
        // Start Session
        DispatchQueue.main.async(execute: {[unowned self] in
            // TODO: Start session with proper input port (audio/video)
            self.defaults.set(false, forKey: Keys.showAlternate)
            
            self.startSession()
            self.manager?.videoPreview = self.parentView
            self.addPreviewLayer()
            
            // Update Toolbar button title
            self.setScale(-1)               // Update Popup Menu Selection
            self.setVolume(-1)              // Update Popup Menu Selection
            
            // TODO: Record proper input port to defaults
        })
    }
    
    /* ======================================================================================== */
    // MARK: - Recording support
    /* ======================================================================================== */
    
    public func startRecording(for sec: Int) {
        // print("\(#file) \(#line) \(#function)")
        
        if let manager = manager, manager.recording == false, let movieURL = createMovieURL() {
            // Read parameters for recording
            let clapOffsetH = defaults.integer(forKey: Keys.clapOffsetH)
            let clapOffsetV = defaults.integer(forKey: Keys.clapOffsetV)
            
            let timeScale = defaults.integer(forKey: Keys.videoTimeScale)
            let timeCodeFormat = defaults.integer(forKey: Keys.timeCodeFormat)
            
            let def_videoEncode = defaults.bool(forKey: Keys.videoEncode)
            let def_videoEncoder = defaults.integer(forKey: Keys.videoEncoder)
            let def_videoFieldDetail = defaults.integer(forKey: Keys.videoFieldDetail)
            
            let def_audioEncode = defaults.bool(forKey: Keys.audioEncode)
            let def_audioEncoder = defaults.integer(forKey: Keys.audioEncoder)
            
            let compressVideo = (def_videoEncode)
            let useProRes422 = (def_videoEncoder == 1)
            let useProRes422LT = (def_videoEncoder == 2)
            let useProRes422Proxy = (def_videoEncoder == 3)
            let useH264 = (def_videoEncoder == 10)
            let useH265 = (def_videoEncoder == 11)
            let useVideoBitrate = defaults.integer(forKey: Keys.videoBitRate) * 1024
            
            let compressAudio = (def_audioEncode)
            let useAudioBitrate = defaults.integer(forKey: Keys.audioBitRate) * 1000
            let useAAC = (def_audioEncoder > 0 && useAudioBitrate > 80*1000)
            let useAAC_HE = (def_audioEncoder > 0 && !useAAC && useAudioBitrate > 40*1000)
            let useAAC_HEv2 = (def_audioEncoder > 0 && !useAAC_HE && useAudioBitrate <= 40*1000)
            
            let useInterlacedEncoding = (def_videoFieldDetail > 0)
            let useBFF = (def_videoFieldDetail == 1)
            let useTFF = (def_videoFieldDetail == 2)
            
            // Apply parameters for recording
            manager.offset = NSPoint(x: clapOffsetH, y: clapOffsetV)
            
            manager.sampleTimescale = Int32(timeScale)
            switch timeCodeFormat {
            case 32:
                manager.timecodeFormatType = kCMTimeCodeFormatType_TimeCode32
                manager.supportTimecodeVANC = true
                manager.supportTimecodeCoreAudio = false
            case 64:
                manager.timecodeFormatType = kCMTimeCodeFormatType_TimeCode64
                manager.supportTimecodeVANC = true
                manager.supportTimecodeCoreAudio = false
            default:
                manager.timecodeFormatType = kCMTimeCodeFormatType_TimeCode32
                manager.supportTimecodeVANC = false
                manager.supportTimecodeCoreAudio = false
            }
            
            if compressVideo {
                manager.encodeProRes422 = false
                manager.encodeVideo = true
                if useProRes422 {
                    manager.encodeVideoCodecType = kCMVideoCodecType_AppleProRes422
                    manager.encodeVideoBitrate = 0
                }
                if useProRes422LT {
                    manager.encodeVideoCodecType = kCMVideoCodecType_AppleProRes422LT
                    manager.encodeVideoBitrate = 0
                }
                if useProRes422Proxy {
                    manager.encodeVideoCodecType = kCMVideoCodecType_AppleProRes422Proxy
                    manager.encodeVideoBitrate = 0
                }
                if useH264 {
                    manager.encodeVideoCodecType = kCMVideoCodecType_H264
                    manager.encodeVideoBitrate = UInt(useVideoBitrate)
                }
                if useH265 {
                    manager.encodeVideo = true
                    manager.encodeVideoCodecType = kCMVideoCodecType_HEVC
                    manager.encodeVideoBitrate = UInt(useVideoBitrate)
                }
            } else {
                manager.encodeProRes422 = false
                manager.encodeVideoCodecType = kCMVideoCodecType_422YpCbCr8
                manager.encodeVideoBitrate = 0
            }
            if useInterlacedEncoding {
                if useBFF {
                    manager.fieldDetail = kCMFormatDescriptionFieldDetail_SpatialFirstLineLate
                }
                if useTFF {
                    manager.fieldDetail = kCMFormatDescriptionFieldDetail_SpatialFirstLineEarly
                }
            } else {
                manager.fieldDetail = nil
            }
            
            if compressAudio {
                manager.encodeAudio = true
                if useAAC {
                    manager.encodeAudioFormatID = kAudioFormatMPEG4AAC
                    manager.encodeAudioBitrate = min(UInt(useAudioBitrate), 320*1000) // clipping at 320Kbps
                }
                if useAAC_HE {
                    manager.encodeAudioFormatID = kAudioFormatMPEG4AAC_HE
                    manager.encodeAudioBitrate = min(UInt(useAudioBitrate), 80*1000) // clipping at 80Kbps
                }
                if useAAC_HEv2 {
                    manager.encodeAudioFormatID = kAudioFormatMPEG4AAC_HE_V2
                    manager.encodeAudioBitrate = min(UInt(useAudioBitrate), 40*1000) // clipping at 40Kbps
                }
            } else {
                manager.encodeAudio = false
                manager.encodeAudioBitrate = 0
            }
            
            /* ============================================================================== */
            
            // Start recording to specified URL
            manager.movieURL = movieURL
            manager.recordToggle()
            
            if manager.recording {
                // Schedule StopTimer if required
                scheduleStopTimer(sec)
                
                // Update recording button as pressed state
                recordingButton.state = NSControl.StateValue.on
                
                // Update AppIcon badge to REC state
                NSApp.dockTile.badgeLabel = "REC"
                
                // Post notification with userInfo
                let userInfo : [String:Any] = [Keys.fileURL : movieURL]
                let notification = Notification(name: .recordingStartedNotificationKey,
                                                object: self,
                                                userInfo: userInfo)
                notificationCenter.post(notification)
                
                return
            }
        }
        
        print("ERROR: Failed to start recording.")
    }
    
    public func stopRecording() {
        // print("\(#file) \(#line) \(#function)")
        
        // Stop recording
        if let manager = manager, manager.recording {
            // Stop recording to specified URL
            manager.recordToggle()
            
            if manager.recording == false {
                // Release StopTimer
                invalidateStopTimer()
                
                // Update recording button as released state
                recordingButton.state = NSControl.StateValue.off
                
                // Reset AppIcon badge to inactive state
                NSApp.dockTile.badgeLabel = nil
                
                // Post notification without userInfo
                let notification = Notification(name: .recordingStoppedNotificationKey,
                                                object: self,
                                                userInfo: nil)
                notificationCenter.post(notification)
                
                // Evaluate AutoQuit after finished
                if evalAutoQuitFlag && defaults.bool(forKey: Keys.autoQuit) {
                    //
                    DispatchQueue.main.async(execute: {[unowned self] in
                        NSApp.terminate(self)
                    })
                }
                
                return
            }
        }
        
        print("ERROR: Failed to stop recording.")
    }
    
    private func scheduleStopTimer(_ sec: Int) {
        // print("\(#file) \(#line) \(#function)")
        
        // Release existing StopTimer
        invalidateStopTimer()
        
        if sec > 0 {
            // Setup new StopTimer
            var limit: Double = 0
            let max = defaults.integer(forKey: Keys.maxDuration) * 60 // in seconds
            if max > sec {
                limit = Double(sec)         // hang up on requested minutes
            } else {
                limit = Double(max)         // limit in maxDuration minutes
            }
            
            stopTimer = Timer.scheduledTimer(timeInterval: limit,
                                             target: self,
                                             selector: #selector(stopRecording),
                                             userInfo: nil,
                                             repeats: false)
            
            // Check AutoQuit flag when end of recording
            evalAutoQuitFlag = true
        } else {
            // No StopTimer.
            
            // Don't use AutoQuitFlag value.
            evalAutoQuitFlag = false
        }
    }
    
    private func invalidateStopTimer() {
        // print("\(#file) \(#line) \(#function)")
        
        // Release StopTimer
        if let stopTimer = stopTimer {
            stopTimer.invalidate()
            self.stopTimer = nil
        }
    }
    
    /* ============================================ */
    // MARK: - Misc support
    /* ============================================ */
    
    private func modifier(_ mask: NSEvent.ModifierFlags) -> Bool {
        // print("\(#file) \(#line) \(#function)")
        
        // example : .option, .control, .command, .shift
        
        if let event = NSApp.currentEvent {
            let flag = event.modifierFlags
            return flag.contains(mask)
        }
        return false
    }
    
    private func movieFolder() -> URL? {
        // print("\(#file) \(#line) \(#function)")
        
        if let url = defaults.url(forKey: Keys.movieFolder) {
            var error:NSError?
            if (url as NSURL).checkResourceIsReachableAndReturnError(&error) {
                var flagDirectory = false
                var flagWritable = false
                
                // validate access
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isWritableKey])
                if let resourceValues = resourceValues {
                    flagDirectory = resourceValues.isDirectory!
                    flagWritable = resourceValues.isWritable!
                }
                
                if flagDirectory && flagWritable {
                    return url
                }
            }
        }
        
        // Use Movie folder
        let directory = FileManager.SearchPathDirectory.moviesDirectory
        let domainMask = FileManager.SearchPathDomainMask.userDomainMask
        let movieFolders = NSSearchPathForDirectoriesInDomains(directory, domainMask, true)
        if let folderPath = movieFolders.first {
            let folderURL = URL.init(fileURLWithPath: folderPath)
            return folderURL
        }
        
        // Fallback to user's home directory
        return URL.init(fileURLWithPath: NSHomeDirectory())
    }
    
    private func movieName() -> String {
        // print("\(#file) \(#line) \(#function)")
        
        // Generate Movie file name
        let prefix = defaults.value(forKey: Keys.prefix) as! String
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd-HHmmss"
        let movieName = prefix + formatter.string(from: Date()) + ".mov"
        return movieName
    }
    
    private func createMovieURL() -> URL? {
        // print("\(#file) \(#line) \(#function)")
        
        // Scripting support for target movie path
        if let targetPath = targetPath {
            return URL(fileURLWithPath: targetPath)
        }
        
        //
        if let movieFolder = movieFolder() {
            let targetURL = movieFolder.appendingPathComponent(movieName())
            targetPath = targetURL.path
            return targetURL
        }
        
        return nil
    }
    
    /* ======================================================================================== */
    // MARK: - Status label support
    /* ======================================================================================== */
    
    public func updateStatusDefault() {
        // print("\(#file) \(#line) \(#function)")
        
        // Show default status string
        updateStatus(nil)
        
        // Try update preview connection enabled state as is
        checkOnActiveSpace()
        
        // Update Dock Icon
        updateDockIcon()
    }
    
    private func startUpdateStatus() {
        // print("\(#file) \(#line) \(#function)")
        
        // setup status update timer
        if updateTimer == nil {
            updateTimer = Timer.scheduledTimer(timeInterval: 0.5,
                                               target: self,
                                               selector: #selector(updateStatusDefault),
                                               userInfo: nil,
                                               repeats: true)
        }
    }
    
    private func stopUpdateStatus() {
        // print("\(#file) \(#line) \(#function)")
        
        // discard status update timer
        if let updateTimer = updateTimer {
            updateTimer.invalidate()
            self.updateTimer = nil
        }
        
        // turn off status label
        defaults.set(false, forKey: Keys.statusVisible)
        defaults.setValue("", forKey: Keys.statusString)
    }
    
    private func updateStatus(_ status: String?) {
        // print("\(#file) \(#line) \(#function)")
        
        if let status = status , status.count > 0 {
            // Stop updateStatus Timer
            stopUpdateStatus()
            
            // Show requested status string
            defaults.set(true, forKey: Keys.statusVisible)
            defaults.setValue(status, forKey: Keys.statusString)
        } else {
            // Start updateStatus Timer
            startUpdateStatus()
            
            // Show auto-generated status string
            var visible = false
            var status = ""
            let showAlternate = defaults.bool(forKey: Keys.showAlternate)
            let forceMute = defaults.bool(forKey: Keys.forceMute)
            
            if let manager = manager , manager.recording {
                // Recording now
                visible = true
                status = "Recording..."
                
                if let stopTimer = stopTimer {
                    let interval: TimeInterval = stopTimer.fireDate.timeIntervalSince(Date())
                    if interval > 120 {
                        status = "Recording remains \(Int(interval/60)) minute(s)..."
                    } else {
                        status = "Recording remains \(Int(interval)) second(s)..."
                    }
                    
                    let autoQuit = defaults.bool(forKey: Keys.autoQuit)
                    if autoQuit {
                        status += " (AutoQuit)"
                    }
                }
            } else {
                // Show when preview is disabled
                if showAlternate || forceMute {
                    visible = true
                    status = " preview is disabled."
                    if showAlternate && forceMute {
                        status = "Video/Audio" + status
                    } else if showAlternate {
                        status = "Video" + status
                    } else if forceMute {
                        status = "Audio" + status
                    }
                }
            }
            
            // Update status string
            defaults.set(visible, forKey: Keys.statusVisible)
            defaults.setValue(status, forKey: Keys.statusString)
        }
    }
    
    private func updateDockIcon() {
        // print("\(#file) \(#line) \(#function)")
        
        // Dock Icon Animation
        if let manager = manager , manager.recording {
            // Perform AppIcon Animation
            iconActiveState = !iconActiveState
            NSApp.applicationIconImage = iconActiveState ? iconActive : iconInactive
        } else {
            // Stop AppIcon Animation
            if iconActiveState {
                iconActiveState = false
                NSApp.applicationIconImage = iconIdle
            }
        }
    }
    
    /* ============================================ */
    // MARK: - Volume control support
    /* ============================================ */
    
    private func setVolume(_ volume: Int) {
        // print("\(#file) \(#line) \(#function)")
        
        let forceMute = defaults.bool(forKey: Keys.forceMute)
        if volume >= 0 {
            defaults.set(volume, forKey:Keys.volume)
            
            if let manager = manager {
                manager.volume = (forceMute ? 0.0 : Float(volume) / 100.0)
            }
            
            updateCurrentVolume()
        } else {
            let prevVolume = defaults.integer(forKey: Keys.volume)
            
            if let manager = manager {
                manager.volume = (forceMute ? 0.0 : Float(prevVolume) / 100.0)
            }
        }
        
        volumePopup.selectItem(withTag: -1) // TODO
    }
    
    private func updateCurrentVolume() {
        // print("\(#file) \(#line) \(#function)")
        
        // Update currentVolume title of NSPopupButton
        let volume = defaults.integer(forKey: Keys.volume)
        
        let currentVolume = "Vol: \(volume)%"
        defaults.setValue(currentVolume, forKey: Keys.currentVolume)
    }
    
    /* ============================================ */
    // MARK: - Window resizing support
    /* ============================================ */
    
    private func setAspectRatio(_ ratioTag: Int) {
        // print("\(#file) \(#line) \(#function)")
        
        defaults.set(ratioTag, forKey: Keys.aspectRatio)
        
        resizeAspect()
        
        let notification = Notification(name: .restartSessionNotificationKey,
                                        object: self,
                                        userInfo: nil)
        restartSession(notification)
    }
    
    private func setScale(_ scaleTag: Int) {
        // print("\(#file) \(#line) \(#function)")
        
        if scaleTag > 0 {
            defaults.set(scaleTag, forKey: Keys.scale)
            
            resizeScale()
            
            updateCurrentScale() // Update later in layoutSublayersOfLayer()
        } else {
            // Do nothing
        }
        
        scalePopup.selectItem(withTag: -1) // TODO
    }
    
    private func updateCurrentScale() {
        // print("\(#file) \(#line) \(#function)")
        
        // Update currentScale title of NSPopupButton
        var scaleTag = defaults.integer(forKey: Keys.scale)
        
        if let manager = manager, let videoPreview = manager.videoPreview, let previewLayer = videoPreview.layer {
            let nativeSize = manager.encodedSize
            let scale: CGFloat = 100.0 * previewLayer.bounds.size.height / nativeSize.height
            scaleTag = Int(scale + 0.05)
        }
        
        let currentScale = "Scale: \(scaleTag)%"
        defaults.setValue(currentScale, forKey: Keys.currentScale)
    }
    
    private func resizeAspect() {
        // print("\(#file) \(#line) \(#function)")
        
        // Resize Window Horizontally using pixel aspect ratio
        if let window = parentView.window, let manager = manager {
            let nativeSize = manager.encodedSize
            let contentSize = window.contentView!.bounds.size
            let topOffset: CGFloat = window.frame.size.height - contentSize.height
            
            let targetRatio: CGFloat = apertureRatio() * nativeSize.width / nativeSize.height
            let newContentSize = CGSize(width: contentSize.height * targetRatio, height: contentSize.height)
            
            // Preserve top center
            let newRect = CGRect(x: window.frame.midX - newContentSize.width/2.0,
                                 y: window.frame.maxY - newContentSize.height - topOffset,
                                 width: newContentSize.width,
                                 height: newContentSize.height + topOffset)
            window.setFrame(newRect, display: true, animate: true)
        }
    }
    
    private func resizeScale() {
        // print("\(#file) \(#line) \(#function)")
        
        // Resize Window using specified scale value
        if let window = parentView.window, let manager = manager {
            let nativeSize = manager.encodedSize
            let contentSize = window.contentView!.bounds.size
            let topOffset: CGFloat = window.frame.size.height - contentSize.height
            
            let targetRatio: CGFloat = apertureRatio() * nativeSize.width / nativeSize.height
            let newContentSize = CGSize(width: nativeSize.height * targetRatio * scale(),
                                        height: nativeSize.height * scale())
            
            // Preserve top center
            let newRect = CGRect(x: window.frame.midX - newContentSize.width/2.0,
                                 y: window.frame.maxY - newContentSize.height - topOffset,
                                 width: newContentSize.width,
                                 height: newContentSize.height + topOffset)
            window.setFrame(newRect, display: true, animate: true)
        }
    }
    
    private func apertureRatio() -> CGFloat {
        // print("\(#file) \(#line) \(#function)")
        
        var ratio: CGFloat = 1.0
        let ratioTag = defaults.integer(forKey: Keys.aspectRatio)
        
        if ratioTag > 1001 {
            let numerator: CGFloat = CGFloat(ratioTag / 1000)
            let denominator: CGFloat = CGFloat(ratioTag % 1000)
            ratio = numerator/denominator
        }
        return ratio
    }
    
    private func scale() -> CGFloat {
        // print("\(#file) \(#line) \(#function)")
        
        var scale: CGFloat = 1.0
        let scaleTag = defaults.integer(forKey: Keys.scale)
        
        if scaleTag >= 50 {
            scale = CGFloat(scaleTag)/100.0
        }
        return scale
    }
    
    /* ======================================================================================== */
    // MARK: - Preview Layer support
    /* ======================================================================================== */
    
    /// Show/hide the layer according to current space
    private func checkOnActiveSpace() {
        // print("\(#file) \(#line) \(#function)")
        
        let showAlternate = defaults.bool(forKey: Keys.showAlternate)
        
        let onActive = window.isOnActiveSpace
        let hideInvisible = defaults.bool(forKey: Keys.hideInvisible)
        
        let targetState = !showAlternate && (onActive ? onActive : !hideInvisible)
        let currentState = previewLayerReady
        
        if targetState != currentState {
            if targetState == true {
                addPreviewLayer()
            } else {
                removePreviewLayer()
            }
        }
    }
    
    // Apply video aspect ratio (considering clean aperture)
    private func applyApertureRatio() {
        // print("\(#file) \(#line) \(#function)")
        
        if let manager = manager, let videoPreview = manager.videoPreview {
            var needsLayout = true
            let targetAspectRatio = apertureRatio()
            if let currentAspectRatio = videoPreview.customPixelAspectRatio {
                needsLayout = (currentAspectRatio != targetAspectRatio)
            }
            if needsLayout {
                videoPreview.customPixelAspectRatio = targetAspectRatio
                videoPreview.needsLayout = true
            }
        } else {
            print("!! applyApertureRatio()")
        }
    }
    
    private func addPreviewLayer() {
        // print("\(#file) \(#line) \(#function)")
        
        // Check if already added
        if previewLayerReady == true {
            return
        }
        
        // Check if video preview is disabled
        if defaults.bool(forKey: Keys.showAlternate) {
            return
        }
        
        if let manager = manager {
            // Populate manager.videoPreview if required
            if manager.videoPreview == nil {
                manager.videoPreview = parentView // as? CaptureVideoPreview
            }
            
            if let videoPreview = manager.videoPreview {
                //
                videoPreview.prepare()
                
                // Apply video aspect ratio (considering clean aperture)
                applyApertureRatio()
                
                previewLayerReady = true
            }
        }
        
        //
        if previewLayerReady == false {
            print("ERROR: Failed to addPreviewLayer()")
        }
    }
    
    private func removePreviewLayer() {
        // print("\(#file) \(#line) \(#function)")
        
        // Check if already removed
        if previewLayerReady == false {
            return
        }
        
        if let manager = manager, let videoPreview = manager.videoPreview {
            // Remove preview sublayer
            manager.videoPreview = nil
            
            //
            videoPreview.shutdown()
            
            previewLayerReady = false
        } else {
            print("ERROR: Failed to removePreviewLayer()")
        }
    }
}
