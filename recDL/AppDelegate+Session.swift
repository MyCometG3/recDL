//
//  AppDelegate+Session.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2025/06/14.
//  Copyright © 2025 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
import CoreVideo
@preconcurrency import DLABridging
import DLABCaptureManager

extension Comparable {
    internal func clipped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension AppDelegate {
    /* ======================================================================================== */
    // MARK: - Capture Session support
    /* ======================================================================================== */
    
    private func applySessionParameters(_ manager: CaptureManager) {
        // Read parameters for session
        let displayModeRaw : UInt32 = UInt32(defaults.integer(forKey: Keys.displayMode))
        guard let displayMode = DLABDisplayMode(rawValue: displayModeRaw) else { return }
        
        let videoConnectionRaw : UInt32 = UInt32(defaults.integer(forKey: Keys.videoConnection))
        let videoConnection = DLABVideoConnection(rawValue: videoConnectionRaw)
        
        let audioConnectionRaw : UInt32 = UInt32(defaults.integer(forKey: Keys.audioConnection))
        let audioConnection = DLABAudioConnection(rawValue: audioConnectionRaw)
        
        let pixelFormatRaw : UInt32 = UInt32(defaults.integer(forKey: Keys.pixelFormat))
        guard let pixelFormat = DLABPixelFormat(rawValue: pixelFormatRaw) else { return }
        
        guard let videoStyleRaw = defaults.string(forKey: Keys.videoStyle) else { return }
        guard let videoStyle = VideoStyle(rawValue: videoStyleRaw) else { return }
        
        let audioDepthRaw : UInt32 = UInt32(defaults.integer(forKey: Keys.audioDepth))
        guard let audioDepth = DLABAudioSampleType(rawValue: audioDepthRaw) else { return }
        let audioChannel : UInt32  = UInt32(defaults.integer(forKey: Keys.audioChannel))
        let audioLayout : UInt32 = UInt32(defaults.integer(forKey: Keys.audioLayout))
        let audioReverse34 : Bool = defaults.bool(forKey: Keys.audioReverse34)
        
        manager.displayMode = displayMode
        manager.videoConnection = videoConnection
        manager.audioConnection = audioConnection
        manager.pixelFormat = pixelFormat
        manager.videoStyle = videoStyle
        
        manager.audioDepth = audioDepth
        manager.audioChannels = audioChannel
        if verifyHDMIAudioChannelLayoutReady() {
            manager.hdmiAudioChannels = audioLayout
            manager.reverseCh3Ch4 = audioReverse34
        }
        
        let timeCodeSource : Int = defaults.integer(forKey: Keys.timeCodeSource)
        switch timeCodeSource {
        case 1, 2, 4, 8:
            manager.timecodeSource = TimecodeType(rawValue: timeCodeSource)
        default:
            manager.timecodeSource = nil
        }
    }
    
    public func startSession() {
        // print("\(#file) \(#line) \(#function)")
        
        if manager == nil {
            manager = CaptureManager()
        }
        if let manager = manager {
            manager.verbose = self.verbose
            
            // TODO: add input devide selection
            
            guard let _ = manager.findFirstDevice() else { return }
            
            applySessionParameters(manager)
            
            addPreviewLayer()
            
            printVerbose("NOTICE:\(self.className): \(#function) - Starting capture session...")
            let result = performAsync {
                await manager.captureStartAsync()
            }
            if result {
                printVerbose("NOTICE:\(self.className): \(#function) - Starting capture session completed.")
            } else {
                printVerbose("ERROR:\(self.className): \(#function) - Starting capture session failed.")
            }
        } else {
            printVerbose("ERROR:\(self.className): \(#function) - CaptureManager is nil.")
        }
    }
    
    public func stopSession() {
        // print("\(#file) \(#line) \(#function)")
        
        if let manager = manager {
            printVerbose("NOTICE:\(self.className): \(#function) - Stopping capture session...")
            let result = performAsync {
                await manager.captureStopAsync()
            }
            if result {
                printVerbose("NOTICE:\(self.className): \(#function) - Stopping capture session completed.")
            } else {
                printVerbose("ERROR:\(self.className): \(#function) - Stopping capture session failed.")
            }
            self.manager = nil
        } else {
            printVerbose("ERROR:\(self.className): \(#function) - CaptureManager is nil.")
        }
    }
    
    public func restartSession(_ notification: Notification) {
        // print("\(#file) \(#line) \(#function)")
        
        // Check user choosen input port (audio/video)
        // modify if required
        if manager == nil {
            printVerbose("ERROR:\(self.className): \(#function) - CaptureManager is nil.")
            return
        }
        
        Task { @MainActor [weak self] in
            guard let self = self else { preconditionFailure("self is nil") }
            
            // Stop Session
            self.stopUpdateStatus()
            self.defaults.set(false, forKey: Keys.showAlternate)
            
            self.removePreviewLayer()
            self.manager?.videoPreview = nil
            self.stopSession()
            
            //
            try? await Task.sleep(nanoseconds: 100_000_000) // sleep for 0.1 seconds
            
            // Start Session
            self.startSession()
            self.manager?.videoPreview = self.parentView
            self.addPreviewLayer()
            
            self.defaults.set(false, forKey: Keys.showAlternate)
            self.startUpdateStatus()
            
            // Update Toolbar button title
            self.setScale(-1)               // Update Popup Menu Selection
            self.setVolume(-1)              // Update Popup Menu Selection
        }
    }
    
    /* ======================================================================================== */
    // MARK: - Recording support
    /* ======================================================================================== */
    
    private func applyRecordingParameters(_ manager: CaptureManager) {
        // Read parameters for recording
        let clapOffsetH = defaults.integer(forKey: Keys.clapOffsetH)
        let clapOffsetV = defaults.integer(forKey: Keys.clapOffsetV)
        
        let timeScale = defaults.integer(forKey: Keys.videoTimeScale)
        let timeCodeFormat = defaults.integer(forKey: Keys.timeCodeFormat)
        let timeCodeSource = defaults.integer(forKey: Keys.timeCodeSource)
        
        let def_videoEncode = defaults.bool(forKey: Keys.videoEncode)
        let def_videoEncoder = defaults.integer(forKey: Keys.videoEncoder)
        let def_videoFieldDetail = defaults.integer(forKey: Keys.videoFieldDetail)
        
        let def_audioEncode = defaults.bool(forKey: Keys.audioEncode)
        let def_audioEncoder = defaults.integer(forKey: Keys.audioEncoder)
        
        let compressVideo = (def_videoEncode)
        let useProRes422HQ = (def_videoEncoder == 0)
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
        case 64:
            manager.timecodeFormatType = kCMTimeCodeFormatType_TimeCode64
        default:
            manager.timecodeFormatType = kCMTimeCodeFormatType_TimeCode32
            manager.timecodeSource = nil
        }
        switch timeCodeSource {
        case 1, 2, 4, 8:
            manager.timecodeSource = TimecodeType(rawValue: timeCodeSource)
        default:
            manager.timecodeSource = nil
        }
        
        if compressVideo {
            manager.encodeProRes422 = false
            manager.encodeVideo = true
            if useProRes422HQ {
                manager.encodeVideoCodecType = kCMVideoCodecType_AppleProRes422HQ
                manager.encodeVideoBitrate = 0
            }
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
                let channelCount = max(2, UInt(manager.hdmiAudioChannels))
                let range = queryBitrateRange(channelCount: channelCount)
                manager.encodeAudioBitrate = UInt(useAudioBitrate).clipped(to: range.min...range.max)
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
    }
    
    /// AAC encoder bitrate range
    private func queryBitrateRange<T: BinaryInteger>(channelCount: T) -> (min: T, max: T) {
        precondition(channelCount > 0, "Channel count must be positive")
        let channelCountWithoutLFE: T = (channelCount > 5) ? (channelCount - 1) : channelCount
        let minRate = 40_000 * channelCountWithoutLFE
        let maxRate = 160_000 * channelCountWithoutLFE
        return (min: minRate, max: maxRate)
    }
    
    public func startRecording(for sec: Int) {
        // print("\(#file) \(#line) \(#function)")
        
        if let manager = manager, manager.recording == false, let movieURL = createMovieURL() {
            // Configure recording parameters
            applyRecordingParameters(manager)
            
            // Start recording to specified URL
            manager.movieURL = movieURL
            performAsync {
                await manager.recordToggleAsync()
            }
            
            if manager.recording {
                // Schedule StopTimer if required
                scheduleStopTimer(sec)
                
                // Update recording button as pressed state
                recordingButton.state = NSControl.StateValue.on
                
                // Update dock icon and badge
                Task(priority: .background) {
                    // Update AppIcon badge to active state
                    NSApp.dockTile.badgeLabel = "REC"
                    
                    // Update AppIcon animation to active state
                    NSApp.applicationIconImage = iconActive
                }
                
                // Post notification with userInfo
                let userInfo : [String:Any] = [Keys.fileURL : movieURL]
                let notification = Notification(name: .recordingStartedNotificationKey,
                                                object: self,
                                                userInfo: userInfo)
                notificationCenter.post(notification)
                
                return
            }
        }
        
        printVerbose("ERROR:\(self.className): \(#function) - Failed to start recording")
    }
    
    public func stopRecording() {
        // print("\(#file) \(#line) \(#function)")
        
        // Stop recording
        if let manager = manager, manager.recording {
            // Stop recording to specified URL
            performAsync {
                await manager.recordToggleAsync()
            }
            
            if manager.recording == false {
                // Release StopTimer
                invalidateStopTimer()
                
                // Update recording button as released state
                recordingButton.state = NSControl.StateValue.off
                
                // Reset dock icon and badge
                Task(priority: .background) {
                    // Reset AppIcon badge to inactive state
                    NSApp.dockTile.badgeLabel = nil
                    
                    // Reset AppIcon animation to inactive state
                    NSApp.applicationIconImage = iconIdle
                }
                
                // Post notification without userInfo
                let notification = Notification(name: .recordingStoppedNotificationKey,
                                                object: self,
                                                userInfo: nil)
                notificationCenter.post(notification)
                
                // Evaluate AutoQuit after finished
                if evalAutoQuitFlag && defaults.bool(forKey: Keys.autoQuit) {
                    printVerbose("NOTICE:\(self.className): \(#function) - AutoQuite triggered")
                    
                    /*
                     * Calling NSApp.terminate() asynchronously could cause a deadlock with
                     * NSApplication.TerminateReply.terminateLater.
                     *
                     * Task { @MainActor [weak self] in
                     *     guard let self = self else { preconditionFailure("self is nil") }
                     *     NSApp.terminate(self)
                     * }
                     *
                     * To avoid potential deadlocks, terminate the application synchronously.
                     */
                    
                    NSApp.terminate(self)
                }
                
                return
            }
        }
        
        printVerbose("ERROR:\(self.className): \(#function) - Failed to stop recording")
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
    
    /* ==================================================================================== */
    //MARK: -
    /* ==================================================================================== */
}

extension AppDelegate {
    /// Executes an asynchronous, throwing operation synchronously using a detached task.
    /// - Parameter block: A closure that performs asynchronous work and may throw.
    /// - Returns: The result produced by the closure.
    /// - Note: This method blocks the calling thread until the asynchronous work completes.
    ///         It can be used from the main thread only if the operation does not rely on main-thread execution.
    nonisolated func performAsync<T: Sendable>(_ block: @Sendable @escaping () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = DispatchQueue(label: "ResultLock")
        var result: Result<T, Error>?
        Task.detached(priority: .high) {
            let taskResult: Result<T, Error>
            do {
                taskResult = .success(try await block())
            } catch {
                taskResult = .failure(error)
            }
            lock.sync {
                result = taskResult
            }
            semaphore.signal()
        }
        semaphore.wait()
        return try lock.sync { try result!.get() }
    }
    
    /// Executes an asynchronous, non-throwing operation synchronously using a detached task.
    /// - Parameter block: A closure that performs asynchronous work.
    /// - Returns: The result produced by the closure.
    /// - Note: This method blocks the calling thread until the asynchronous work completes.
    ///         It can be used from the main thread only if the operation does not rely on main-thread execution.
    nonisolated func performAsync<T: Sendable>(_ block: @Sendable @escaping () async -> T) -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = DispatchQueue(label: "ResultLock")
        var result: T?
        Task.detached(priority: .high) {
            let taskResult = await block()
            lock.sync {
                result = taskResult
            }
            semaphore.signal()
        }
        semaphore.wait()
        return lock.sync { result! }
    }
}
