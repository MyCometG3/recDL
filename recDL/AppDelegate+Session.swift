//
//  AppDelegate+Session.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2025/06/14.
//  Copyright © 2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
import CoreVideo
import os.lock
@preconcurrency import DLABridging
import DLABCaptureManager

extension Comparable {
    internal func clipped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private final class UnfairLockBox: @unchecked Sendable {
    private var rawLock = os_unfair_lock_s()
    
    @inline(__always)
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(&rawLock)
        defer { os_unfair_lock_unlock(&rawLock) }
        return try body()
    }
}

extension AppDelegate {
    private final class ThrowingAsyncResultBox<T>: @unchecked Sendable {
        private let lock = UnfairLockBox()
        private let semaphore = DispatchSemaphore(value: 0)
        private var result: Result<T, Error>?
        
        func store(_ result: Result<T, Error>) {
            lock.withLock { self.result = result }
            semaphore.signal()
        }
        
        func waitAndGet() throws -> T {
            semaphore.wait()
            return try lock.withLock {
                guard let result = result else {
                    fatalError("Async operation failed to complete - this should never happen")
                }
                return try result.get()
            }
        }
    }
    
    private final class AsyncResultBox<T>: @unchecked Sendable {
        private let lock = UnfairLockBox()
        private let semaphore = DispatchSemaphore(value: 0)
        private var value: T?
        
        func store(_ value: T) {
            lock.withLock { self.value = value }
            semaphore.signal()
        }
        
        func waitAndGet() -> T {
            semaphore.wait()
            return lock.withLock {
                guard let value = value else {
                    fatalError("Async operation failed to complete - this should never happen for non-throwing operations")
                }
                return value
            }
        }
    }
    
    /// Executes an asynchronous, throwing operation synchronously.
    /// - Note: Uses an attached task to avoid detached-task sendability diagnostics.
    nonisolated func performAsync<T: Sendable>(_ block: @Sendable @escaping () async throws -> T) throws -> T {
        let box = ThrowingAsyncResultBox<T>()
        
        Task(priority: .high) { [box, block] in
            do {
                box.store(.success(try await block()))
            } catch {
                box.store(.failure(error))
            }
        }
        
        return try box.waitAndGet()
    }
    
    /// Executes an asynchronous, non-throwing operation synchronously.
    /// - Note: Uses an attached task to avoid detached-task sendability diagnostics.
    nonisolated func performAsync<T: Sendable>(_ block: @Sendable @escaping () async -> T) -> T {
        let box = AsyncResultBox<T>()
        
        Task(priority: .high) { [box, block] in
            box.store(await block())
        }
        
        return box.waitAndGet()
    }
}

extension AppDelegate {
    /* ======================================================================================== */
    // MARK: - Capture Session support
    /* ======================================================================================== */
    
    private func applySessionParametersAsync() async {
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
        
        // Prepare parameters for actor (accessing main actor context)
        let hdmiAudioChannels = self.verifyHDMIAudioChannelLayoutReady() ? audioLayout : nil
        let reverseCh3Ch4 = self.verifyHDMIAudioChannelLayoutReady() ? audioReverse34 : nil
        
        let timecodeSource: TimecodeType?
        let timeCodeSourceRaw = self.defaults.integer(forKey: Keys.timeCodeSource)
        switch timeCodeSourceRaw {
        case 1, 2, 4, 8:
            timecodeSource = TimecodeType(rawValue: timeCodeSourceRaw)
        default:
            timecodeSource = nil
        }
        
        // Apply parameters through actor
        await self.captureSession.applySessionParameters(
            displayMode: displayMode,
            videoConnection: videoConnection,
            audioConnection: audioConnection,
            pixelFormat: pixelFormat,
            videoStyle: videoStyle,
            audioDepth: audioDepth,
            audioChannels: audioChannel,
            hdmiAudioChannels: hdmiAudioChannels,
            reverseCh3Ch4: reverseCh3Ch4,
            timecodeSource: timecodeSource
        )
    }
    
    public func startSession() async {
        // print("\(#file) \(#line) \(#function)")
        
        // Create manager through actor and set as local reference
        let verbose = self.verbose
        await self.captureSession.setVerbose(verbose)
        manager = await self.captureSession.createManager()
        
        guard manager != nil else {
            printVerbose("ERROR:\(self.className): \(#function) - Failed to create CaptureManager.")
            return
        }
        
        await applySessionParametersAsync()
        
        addPreviewLayer()
        
        printVerbose("NOTICE:\(self.className): \(#function) - Starting capture session...")
        let result = await self.captureSession.startCaptureSession()
        if result {
            printVerbose("NOTICE:\(self.className): \(#function) - Starting capture session completed.")
            await refreshCachedState()
            
            Task(priority: .utility) { [captureSession] in
                _ = await captureSession.prewarmRecordingPath()
            }
        } else {
            printVerbose("ERROR:\(self.className): \(#function) - Starting capture session failed.")
        }
    }
    
    public func stopSession() async {
        // print("\(#file) \(#line) \(#function)")
        
        if manager != nil {
            printVerbose("NOTICE:\(self.className): \(#function) - Stopping capture session...")
            let result = await self.captureSession.stopCaptureSession()
            if result {
                printVerbose("NOTICE:\(self.className): \(#function) - Stopping capture session completed.")
            } else {
                printVerbose("ERROR:\(self.className): \(#function) - Stopping capture session failed.")
            }
            
            await self.captureSession.destroyManager()
            self.manager = nil
            await refreshCachedState()
        } else {
            printVerbose("ERROR:\(self.className): \(#function) - CaptureManager is nil.")
        }
    }
    
    public func restartSession(_ notification: Notification) {
        // print("\(#file) \(#line) \(#function)")
        
        guard restartSessionTask == nil else {
            printVerbose("NOTICE:\(self.className): \(#function) - Restart already in progress")
            return
        }
        
        // Check user choosen input port (audio/video)
        // modify if required
        if manager == nil {
            printVerbose("ERROR:\(self.className): \(#function) - CaptureManager is nil.")
            return
        }
        
        restartSessionTask = Task { @MainActor [weak self] in
            guard let self = self else {
                AppDelegate.printNilSelfWarning(#function)
                return
            }
            defer {
                self.restartSessionTask = nil
            }
            
            // Stop Session
            self.stopUpdateStatus()
            self.defaults.set(false, forKey: Keys.showAlternate)
            
            self.removePreviewLayer()
            self.manager?.videoPreview = nil
            await self.stopSession()
            
            //
            try? await Task.sleep(nanoseconds: 100_000_000) // sleep for 0.1 seconds
            
            // Start Session
            await self.startSession()
            self.manager?.videoPreview = self.parentView
            self.addPreviewLayer()
            
            self.defaults.set(false, forKey: Keys.showAlternate)
            self.startUpdateStatus()
            
            // Update Toolbar button title
            self.setScale(-1)               // Update Popup Menu Selection
            self.setVolume(-1)              // Update Popup Menu Selection
            
            // Update cached recording state after restart
            await self.refreshCachedState()
        }
    }
    
    /* ======================================================================================== */
    // MARK: - Recording support
    /* ======================================================================================== */
    
    private func applyRecordingParameters() {
        guard let manager = self.manager else { return }
        
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
        let useAAC = (def_audioEncoder > 0 && useAudioBitrate > 80_000)
        let useAAC_HE = (def_audioEncoder > 0 && !useAAC && useAudioBitrate > 40_000)
        let useAAC_HEv2 = (def_audioEncoder > 0 && !useAAC_HE && useAudioBitrate <= 40_000)
        
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
                manager.encodeAudioBitrate = min(UInt(useAudioBitrate), 80_000) // clipping at 80Kbps
            }
            if useAAC_HEv2 {
                manager.encodeAudioFormatID = kAudioFormatMPEG4AAC_HE_V2
                manager.encodeAudioBitrate = min(UInt(useAudioBitrate), 40_000) // clipping at 40Kbps
            }
        } else {
            manager.encodeAudio = false
            manager.encodeAudioBitrate = 0
        }
        
        performAsync {
            await self.captureSession.invalidateRecordingPreparation()
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
        
        let isRecording = performAsync {
            await self.captureSession.isRecording()
        }
        
        if manager != nil && !isRecording, let movieURL = createMovieURL() {
            // Configure recording parameters
            applyRecordingParameters()
            
            // Start recording to specified URL
            let recordingStarted = performAsync {
                await self.captureSession.startRecording(to: movieURL)
            }
            
            // Update cached state after operation
            updateCachedState()
            
            if recordingStarted {
                
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
    
    /// Non-blocking start flow for UI-triggered recording.
    /// This avoids synchronous semaphore waits on the main thread while the writer initializes.
    public func startRecordingNonBlocking(for sec: Int) async {
        // print("\(#file) \(#line) \(#function)")
        
        guard !recordingStartInProgress else {
            printVerbose("ERROR:\(self.className): \(#function) - Recording start already in progress")
            return
        }
        
        let isRecording = await self.captureSession.isRecording()
        
        guard manager != nil, !isRecording, let movieURL = createMovieURL() else {
            printVerbose("ERROR:\(self.className): \(#function) - Failed to start recording")
            return
        }
        recordingStartInProgress = true
        defer {
            recordingStartInProgress = false
        }
        
        let startedAt = CFAbsoluteTimeGetCurrent()
        printVerbose("TRACE:\(self.className): \(#function) - begin ")
        
        applyRecordingParameters()
        
        let recordingStarted = await self.captureSession.startRecording(to: movieURL)
        
        // Refresh cache asynchronously to keep the hot path non-blocking.
        updateCachedStateAsync()
        
        if recordingStarted {
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
            
            let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startedAt) * 1000.0)
            printVerbose("TRACE:\(self.className): \(#function) - success \(elapsedMs)ms ")
            return
        }
        
        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startedAt) * 1000.0)
        printVerbose("TRACE:\(self.className): \(#function) - failed \(elapsedMs)ms ")
        printVerbose("ERROR:\(self.className): \(#function) - Failed to start recording")
    }
    
    /// Synchronous stop path for AppleScript/script callers.
    /// Timer-driven stops use `stopRecordingFromTimer()` so the main thread does not wait on
    /// `performAsync { semaphore.wait() }`.
    public func stopRecording() {
        // print("\(#file) \(#line) \(#function)")
        
        let isRecording = performAsync {
            await self.captureSession.isRecording()
        }
        
        // Stop recording
        if manager != nil && isRecording {
            // Stop recording to specified URL
            let recordingStopped = performAsync {
                await self.captureSession.stopRecording()
            }
            
            // Update cached state after operation
            updateCachedState()
            
            if recordingStopped {
                finishRecordingStop()
                return
            }
        }
        
        printVerbose("ERROR:\(self.className): \(#function) - Failed to stop recording")
    }
    
    @objc
    private func stopRecordingFromTimer() {
        Task { @MainActor [weak self] in
            guard let self = self else {
                AppDelegate.printNilSelfWarning(#function)
                return
            }
            
            let recordingStopped = await self.captureSession.stopRecording()
            await self.refreshCachedState()
            
            if recordingStopped {
                self.finishRecordingStop()
                return
            }
            
            self.printVerbose("ERROR:\(self.className): \(#function) - Failed to stop recording")
        }
    }
    
    private func finishRecordingStop() {
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
            printVerbose("NOTICE:\(self.className): \(#function) - AutoQuit triggered")
            
            let selector = #selector(NSApplication.terminate(_:))
            NSApp.perform(selector,
                          with: nil,
                          afterDelay: 0.1,
                          inModes: [.common])
            /*
             * Calling NSApp.terminate() directly causes a deadlock with
             * NSApplication.TerminateReply.terminateLater.
             * Instead, trigger termination using performSelector method.
             * NSApp.terminate(self)
             */
        }
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
                                             selector: #selector(stopRecordingFromTimer),
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
