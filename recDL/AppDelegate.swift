//
//  AppDelegate.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/10/07.
//  Copyright © 2017-2024 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
import CoreVideo
@preconcurrency import DLABridging
import DLABCaptureManager

@main
@objcMembers
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    /* ============================================ */
    // MARK: - Variables
    /* ============================================ */
    
    internal var prepared: Bool = false
    internal var verbose: Bool = true
    
    internal lazy var defaults = UserDefaults.standard
    internal lazy var notificationCenter = NotificationCenter.default
    
    public internal(set) var manager : CaptureManager? = nil
    internal let captureSession = CaptureSession()
    internal var cachedRecordingState = false
    internal var cachedRunningState = false
    internal var previewLayerReady : Bool = false
    internal var updateTimer : Timer? = nil
    internal var stopTimer : Timer? = nil
    
    internal var evalAutoQuitFlag : Bool = false
    internal var targetPath : String? = nil
    
    internal var iconActiveState = false
    internal var iconAnimation = false
    internal let iconIdle = NSImage(named:Keys.idle)
    internal let iconInactive = NSImage(named:Keys.inactive)
    internal let iconActive = NSImage(named:Keys.active)
    
    // Note - DockIcon animation is heavy operation
    internal var useIconAnimation = true
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var parentView: CaptureVideoPreview! //NSView!
    @IBOutlet weak var recordForMin: NSTextField!
    
    @IBOutlet weak var recordingButton: NSButton!
    @IBOutlet weak var scalePopup: NSPopUpButton!
    @IBOutlet weak var volumePopup: NSPopUpButton!
    
    @IBOutlet weak var scaleNow: NSMenuItem!
    @IBOutlet weak var volumeNow: NSMenuItem!
    
    @IBOutlet weak var accessoryView: NSView!
    
    internal var deviceInfo : [String:Any]? = nil
    internal var availableSettingInfo : [String:Any]? = nil
    
    /* ============================================ */
    // MARK: - Cached State Management
    /* ============================================ */
    
    internal func updateCachedState() {
        cachedRecordingState = performAsync {
            await self.captureSession.isRecording()
        }
        cachedRunningState = performAsync {
            await self.captureSession.isRunning()
        }
    }
    
    /* ============================================ */
    // MARK: - Scripting support
    /* ============================================ */
    
    func application(_ sender :NSApplication, delegateHandlesKey key :String) -> Bool {
        // print("\(#file) \(#line) \(#function)")
        
        let supportedParameter = [Keys.sessionItem,
                                  Keys.recordingItem,
                                  Keys.folderURL,
                                  Keys.useVideoPreview,
                                  Keys.useAudioPreview]
        if supportedParameter.contains(key) {
            printVerbose("NOTICE:\(self.className): \(#function) - delegate handles: \(key)")
            return true
        } else {
            printVerbose("NOTICE:\(self.className): \(#function) - delegate does not handle: \(key)")
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
        keyValues[Keys.timeCodeSource] = 0      // 0:None, 1:SERIAL, 2:VITC, 4:RP188, 8:CoreAudio
        keyValues[Keys.timeCodeFormat] = 0      // 0:None, 32:tmcd, 64:tc64
        
        keyValues[Keys.videoConnection] = DLABVideoConnection.sVideo.rawValue
        keyValues[Keys.audioConnection] = DLABAudioConnection.analogRCA.rawValue
        
        keyValues[Keys.videoEncode] = true      // false:2vuy, true:encode
        keyValues[Keys.videoEncoder] = 1
        // 0:ProRes422HQ 1:ProRes422,2:ProRes422LT,3:ProRes422Proxy
        // 10:H.264, 11:H265, 0:Uncompressed
        keyValues[Keys.videoBitRate] = 25*1000  // videoBitRate (Kbps)
        keyValues[Keys.videoFieldDetail] = 1    // 0:SingleField, 1:BFF, 2:TFF
        
        keyValues[Keys.audioDepth] = 16         // 16:16bit, 32:32bit
        keyValues[Keys.audioEncode] = true      // false:LPCM, true:AAC
        keyValues[Keys.audioEncoder] = 1        // 1:AACLC, 2:HE-AAC(~80Kbps), 3:HE-AACv2(~40Kbps)
        keyValues[Keys.audioBitRate] = 256      // audioBitRate (Kbps)
        keyValues[Keys.audioChannel] = 2        // 0:off, 2:stereo, 3-16:discrete multi channel
        keyValues[Keys.audioLayout] = 6         // 0:discrete, 2:LR, 3:LRC, 6:5.1ch, 8:7.1ch
        keyValues[Keys.audioReverse34] = false  // false:(3,4)=(C,LFE), true:(3,4)=(LFE,C)
        
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
        
        Task { setup() }
    }
    
    private func setup() {
        // print("\(#file) \(#line) \(#function)")
        
        // Register notification observer for Cocoa scripting support
        registerObserverForScriptingSupport()
        
        // Register notification observer for Restarting AVCaptureSession
        notificationCenter.addObserver(self,
                                       selector: #selector(restartSession),
                                       name: .restartSessionNotificationKey,
                                       object: nil)
        
        // Show window now
        window.titleVisibility = .hidden
        _ = window.setFrameAutosaveName(Keys.previewWindow)
        window.makeKeyAndOrderFront(self)
        window.isMovableByWindowBackground = true
        
        // Ensure CALayer for the ParentView
        if parentView.wantsLayer == false {
            parentView.wantsLayer = true
        }
        
        if let previewLayer = parentView.layer {
            // Set background color
            let grayColor = CGColor(gray: 0.25, alpha: 1.0)
            previewLayer.backgroundColor = grayColor
        }
        
        //
        parentView.verbose = false
        startSession()
        
        // Update Toolbar button title
        setVolume(-1)                       // Update Popup Menu Selection
        setScale(-1)                        // Update Popup Menu Selection
        
        // Start Status Update
        startUpdateStatus()
        
        // Prepare AppIcon animation
        Task(priority: .background) {
            // Resize AppIcon for animation (to avoid performance impact)
            let iconSize = NSSize(width: 64, height: 64)
            iconInactive?.size = iconSize
            iconActive?.size = iconSize
            iconIdle?.size = iconSize
            
            // PreCache icon images
            if let iconActive = iconActive {
                NSApp.applicationIconImage = iconActive
            }
            if let iconInactive = iconInactive {
                NSApp.applicationIconImage = iconInactive
            }
            if let iconIdle = iconIdle {
                NSApp.applicationIconImage = iconIdle
            }
        }
        
        //
        let handler: @Sendable (Notification) -> Void = { [weak self] notification in
            guard let self = self else { preconditionFailure("Self is nil") }
            
            Task(priority: .background) {
                await updateCurrentScale()
            }
        }
        notificationCenter.addObserver(forName: NSView.frameDidChangeNotification,
                                       object: parentView,
                                       queue: nil,
                                       using: handler)
        
        // Initialize cached recording state
        updateCachedState()
        
        prepared = true
    }
    
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // print("\(#file) \(#line) \(#function)")
        
        // Graceful close handler (NSApplicationDelegate method)
        if prepared {
            Task { @MainActor [weak self] in
                guard let self = self else { preconditionFailure("self is nil") }
                
                printVerbose("NOTICE:\(self.className): \(#function) - cleanup started")
                cleanup()
                printVerbose("NOTICE:\(self.className): \(#function) - cleanup done")
            
                NSApp.reply(toApplicationShouldTerminate: true)
            }
            printVerbose("NOTICE:\(self.className): \(#function) - later")
            return .terminateLater
        } else {
            printVerbose("NOTICE:\(self.className): \(#function) - ready")
            return .terminateNow
        }
    }
    
    public func applicationWillTerminate(_ aNotification: Notification) {
        // print("\(#file) \(#line) \(#function)")
        
        // Force termination handler (NSApplicationDelegate method)
        if prepared {
            printVerbose("NOTICE:\(self.className): \(#function) - cleanup started")
            cleanup()
            printVerbose("NOTICE:\(self.className): \(#function) - cleanup done")
        }
    }
    
    private func cleanup() {
        // print("\(#file) \(#line) \(#function)")
        
        // Ensure that we are prepared
        if prepared == false { return }
        
        // Reset AppIcon
        NSApp.applicationIconImage = nil
        
        // Reset AppIcon badge to inactive state
        NSApp.dockTile.badgeLabel = nil
        
        // Stop Status Update
        stopUpdateStatus()
        
        // Stop Session
        removePreviewLayer()
        stopSession()
        
        // Resign notification observer
        notificationCenter.removeObserver(self)
        
        //
        prepared = false
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
        
        if let menuItem = sender as? NSMenuItem {
            let volTag = menuItem.tag
            setVolume(volTag)
        } else if let popUpButton = sender as? NSPopUpButton {
            let volTag = popUpButton.selectedTag()
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
        
        if let menuItem = sender as? NSMenuItem {
            let scaleTag = menuItem.tag
            setScale(scaleTag)
        } else if let popUpButton = sender as? NSPopUpButton {
            let scaleTag = popUpButton.selectedTag()
            setScale(scaleTag)
        }
    }
    
    @IBAction func updateAspectRatio(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        if let menuItem = sender as? NSMenuItem {
            let ratioTag = menuItem.tag
            setAspectRatio(ratioTag)
        } else if let popUpButton = sender as? NSPopUpButton {
            let ratioTag = popUpButton.selectedTag()
            setAspectRatio(ratioTag)
        }
    }
    
    @IBAction func togglePreviewAudio(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        Task { @MainActor [weak self] in
            guard let self = self else { preconditionFailure("self is nil") }
            self.setVolume(-1)                       // Update Popup Menu Selection
        }
    }
    
    @IBAction func togglePreviewVideo(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        Task { @MainActor [weak self] in
            guard let self = self else { preconditionFailure("self is nil") }
            self.setScale(-1)                        // Update Popup Menu Selection
        }
    }
    
    @IBAction func toggleRecording(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        if modifier(.option) {
            if manager != nil && cachedRecordingState {
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
                Task { @MainActor [weak self] in
                    guard let self = self else { preconditionFailure("self is nil") }
                    self.targetPath = nil       // Use autogenerated movie path
                    self.startRecording(for: 0)
                }
            } else {
                // Stop recording
                Task { @MainActor [weak self] in
                    guard let self = self else { preconditionFailure("self is nil") }
                    self.stopRecording()
                }
            }
        }
    }
    
    @IBAction func actionStartRecording(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        // Reject multiple request
        if manager != nil && (cachedRecordingState || window.attachedSheet != nil) {
            NSSound.beep()
            return
        }
        
        //
        Task { @MainActor [weak self] in
            guard let self = self else { preconditionFailure("self is nil") }
            self.targetPath = nil           // Use autogenerated movie path
            self.startRecording(for:0)
        }
    }
    
    @IBAction func actionStopRecording(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        //
        Task { @MainActor [weak self] in
            guard let self = self else { preconditionFailure("self is nil") }
            self.stopRecording()
        }
    }
    
    @IBAction func actionRecordingFor(_ sender: AnyObject) {
        // print("\(#file) \(#line) \(#function)")
        
        // Reject multiple request
        if manager != nil && (cachedRecordingState || window.attachedSheet != nil) {
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
                Task { @MainActor [weak self] in
                    guard let self = self else { preconditionFailure("self is nil") }
                    self.startRecording(for: min * 60)
                }
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
    
    internal func movieFolder() -> URL? {
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
    
    internal func movieName() -> String {
        // print("\(#file) \(#line) \(#function)")
        
        // Generate Movie file name
        let prefix = defaults.string(forKey: Keys.prefix) ?? "recdl-"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd-HHmmss"
        let movieName = prefix + formatter.string(from: Date()) + ".mov"
        return movieName
    }
    
    internal func printVerbose(_ message: String...) {
        // print("\(#file) \(#line) \(#function)")
        
        if self.verbose {
            let output = message.joined(separator: "\n")
            print(output)
        }
    }
    
    /* ==================================================================================== */
    //MARK: -
    /* ==================================================================================== */
}
