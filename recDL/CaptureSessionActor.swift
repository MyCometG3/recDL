//
//  CaptureSessionActor.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2025/01/10.
//  Copyright © 2025 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
import CoreVideo
@preconcurrency import DLABridging
import DLABCaptureManager

/// Actor that encapsulates CaptureManager functionality and provides async interface for video capture operations.
///
/// `CaptureSession` provides thread-safe access to video capture functionality through Swift's actor system.
/// It manages the lifecycle of capture sessions and recording operations while maintaining compatibility
/// with existing synchronous APIs through bridging functions.
///
/// ## Usage
/// ```swift
/// let captureSession = CaptureSession()
/// 
/// // Initialize and configure
/// let created = await captureSession.createManager()
/// await captureSession.applySessionParameters(...)
/// 
/// // Start capture session
/// let started = await captureSession.startCaptureSession()
/// 
/// // Begin recording
/// let recording = await captureSession.startRecording(to: movieURL)
/// ```
///
/// - Note: This actor maintains sequential processing behavior for compatibility with existing code.
/// - Important: All capture and recording operations are asynchronous and must be called with `await`.
actor CaptureSession {
    
    // MARK: - Properties
    
    /// The underlying CaptureManager instance that handles the actual capture operations.
    private var manager: CaptureManager?
    
    /// Controls whether verbose logging is enabled for capture operations.
    private var verbose: Bool = true
    
    // MARK: - Initialization
    
    /// Creates a new CaptureSession instance.
    ///
    /// The session is initialized without an active CaptureManager. Call `createManager()`
    /// to initialize the underlying capture system.
    init() {
        self.manager = nil
        self.verbose = true
    }
    
    // MARK: - Configuration
    
    /// Sets the verbose logging mode for capture operations.
    ///
    /// - Parameter verbose: `true` to enable verbose logging, `false` to disable.
    func setVerbose(_ verbose: Bool) {
        self.verbose = verbose
    }
    
    // MARK: - Session Management
    
    /// Creates and initializes the underlying CaptureManager instance.
    ///
    /// This method creates a new CaptureManager if one doesn't exist, configures it with
    /// the current verbose setting, and attempts to find the first available capture device.
    ///
    /// - Returns: `true` if the manager was successfully created and a device was found, `false` otherwise.
    /// - Note: This method must be called before any capture operations can be performed.
    func createManager() -> Bool {
        if manager == nil {
            manager = CaptureManager()
        }
        
        guard let manager = manager else { return false }
        
        manager.verbose = self.verbose
        
        // TODO: add input device selection
        guard let _ = manager.findFirstDevice() else { return false }
        
        return true
    }
    
    /// Applies session-level configuration parameters to the capture manager.
    ///
    /// This method configures various aspects of the capture session including display mode,
    /// connection types, pixel format, and audio settings.
    ///
    /// - Parameters:
    ///   - displayMode: The display mode for video capture (resolution and frame rate).
    ///   - videoConnection: Optional video connection type (HDMI, SDI, etc.).
    ///   - audioConnection: Optional audio connection type.
    ///   - pixelFormat: The pixel format for captured video frames.
    ///   - videoStyle: The video processing style.
    ///   - audioDepth: The audio sample bit depth.
    ///   - audioChannels: The number of audio channels to capture.
    ///   - hdmiAudioChannels: Optional HDMI-specific audio channel count.
    ///   - reverseCh3Ch4: Optional flag to reverse audio channels 3 and 4.
    ///   - timecodeSource: Optional timecode source configuration.
    ///
    /// - Note: This method has no effect if the manager has not been created yet.
    func applySessionParameters(
        displayMode: DLABDisplayMode,
        videoConnection: DLABVideoConnection?,
        audioConnection: DLABAudioConnection?,
        pixelFormat: DLABPixelFormat,
        videoStyle: VideoStyle,
        audioDepth: DLABAudioSampleType,
        audioChannels: UInt32,
        hdmiAudioChannels: UInt32?,
        reverseCh3Ch4: Bool?,
        timecodeSource: TimecodeType?
    ) {
        guard let manager = manager else { return }
        
        manager.displayMode = displayMode
        if let videoConnection = videoConnection {
            manager.videoConnection = videoConnection
        }
        if let audioConnection = audioConnection {
            manager.audioConnection = audioConnection
        }
        manager.pixelFormat = pixelFormat
        manager.videoStyle = videoStyle
        
        manager.audioDepth = audioDepth
        manager.audioChannels = audioChannels
        if let hdmiAudioChannels = hdmiAudioChannels {
            manager.hdmiAudioChannels = hdmiAudioChannels
        }
        if let reverseCh3Ch4 = reverseCh3Ch4 {
            manager.reverseCh3Ch4 = reverseCh3Ch4
        }
        
        manager.timecodeSource = timecodeSource
    }
    
    /// Starts the capture session asynchronously.
    ///
    /// This method begins the video capture process. The capture session must be properly
    /// configured before calling this method.
    ///
    /// - Returns: `true` if the capture session started successfully, `false` otherwise.
    /// - Note: Requires a valid manager instance created with `createManager()`.
    func startCaptureSession() async -> Bool {
        guard let manager = manager else { return false }
        
        return await manager.captureStartAsync()
    }
    
    /// Stops the capture session asynchronously.
    ///
    /// This method stops the video capture process. Any active recording will also be stopped.
    ///
    /// - Returns: `true` if the capture session stopped successfully, `false` otherwise.
    /// - Note: Requires a valid manager instance.
    func stopCaptureSession() async -> Bool {
        guard let manager = manager else { return false }
        
        return await manager.captureStopAsync()
    }
    
    // MARK: - Recording Management
    
    /// Applies recording-specific configuration parameters to the capture manager.
    ///
    /// This method configures encoding settings for both video and audio recording,
    /// including codecs, bitrates, and format specifications.
    ///
    /// - Parameters:
    ///   - offset: The offset point for video capture positioning.
    ///   - sampleTimescale: The timescale for media samples.
    ///   - timecodeFormatType: The format type for timecode data.
    ///   - timecodeSource: Optional timecode source for synchronization.
    ///   - encodeVideo: Whether to encode video during recording.
    ///   - encodeVideoCodecType: The video codec type for encoding.
    ///   - encodeVideoBitrate: The target bitrate for video encoding.
    ///   - encodeProRes422: Whether to use ProRes 422 encoding.
    ///   - fieldDetail: Optional field detail configuration.
    ///   - encodeAudio: Whether to encode audio during recording.
    ///   - encodeAudioFormatID: The audio format identifier for encoding.
    ///   - encodeAudioBitrate: The target bitrate for audio encoding.
    ///
    /// - Note: This method has no effect if the manager has not been created yet.
    func applyRecordingParameters(
        offset: NSPoint,
        sampleTimescale: Int32,
        timecodeFormatType: CMTimeCodeFormatType,
        timecodeSource: TimecodeType?,
        encodeVideo: Bool,
        encodeVideoCodecType: CMVideoCodecType,
        encodeVideoBitrate: UInt,
        encodeProRes422: Bool,
        fieldDetail: CFString?,
        encodeAudio: Bool,
        encodeAudioFormatID: AudioFormatID,
        encodeAudioBitrate: UInt
    ) {
        guard let manager = manager else { return }
        
        manager.offset = offset
        manager.sampleTimescale = sampleTimescale
        manager.timecodeFormatType = timecodeFormatType
        manager.timecodeSource = timecodeSource
        
        manager.encodeProRes422 = encodeProRes422
        manager.encodeVideo = encodeVideo
        manager.encodeVideoCodecType = encodeVideoCodecType
        manager.encodeVideoBitrate = encodeVideoBitrate
        manager.fieldDetail = fieldDetail
        
        manager.encodeAudio = encodeAudio
        manager.encodeAudioFormatID = encodeAudioFormatID
        manager.encodeAudioBitrate = encodeAudioBitrate
    }
    
    /// Starts recording to the specified movie file URL asynchronously.
    ///
    /// This method begins recording captured video and audio to a file. The capture session
    /// must already be active before recording can start.
    ///
    /// - Parameter movieURL: The file URL where the recorded movie should be saved.
    /// - Returns: `true` if recording started successfully, `false` if recording was already active or failed to start.
    ///
    /// - Note: Recording will fail if the capture session is not active or if a recording is already in progress.
    /// - Important: Ensure the destination directory exists and is writable before calling this method.
    func startRecording(to movieURL: URL) async -> Bool {
        guard let manager = manager, !manager.recording else { return false }
        
        manager.movieURL = movieURL
        await manager.recordToggleAsync()
        
        // Return true if recording actually started
        return manager.recording
    }
    
    /// Stops the current recording session asynchronously.
    ///
    /// This method stops the active recording and finalizes the movie file.
    ///
    /// - Returns: `true` if recording stopped successfully, `false` if no recording was active or stopping failed.
    ///
    /// - Note: This method has no effect if no recording is currently active.
    /// - Important: The movie file may not be immediately available after this call returns due to finalization processes.
    func stopRecording() async -> Bool {
        guard let manager = manager, manager.recording else { return false }
        
        await manager.recordToggleAsync()
        
        // Return true if recording actually stopped
        return !manager.recording
    }
    
    // MARK: - State Access
    
    /// Returns the current capture session running state.
    ///
    /// - Returns: `true` if the capture session is currently running, `false` otherwise.
    /// - Note: Returns `false` if no manager instance exists.
    func isRunning() -> Bool {
        return manager?.running ?? false
    }
    
    /// Returns the current recording state.
    ///
    /// - Returns: `true` if recording is currently active, `false` otherwise.
    /// - Note: Returns `false` if no manager instance exists.
    func isRecording() -> Bool {
        return manager?.recording ?? false
    }
    
    /// Provides access to the underlying CaptureManager instance.
    ///
    /// - Returns: The current CaptureManager instance, or `nil` if not created.
    /// - Warning: Direct access to the manager should be used sparingly as it bypasses actor isolation.
    /// - Note: This method is provided for compatibility with existing code that requires direct manager access.
    func getManager() -> CaptureManager? {
        return manager
    }
    
    /// Destroys the current CaptureManager instance.
    ///
    /// This method releases the underlying capture manager, effectively terminating all
    /// capture and recording operations. The manager can be recreated later with `createManager()`.
    ///
    /// - Note: Any active capture session or recording will be stopped before destruction.
    func destroyManager() {
        manager = nil
    }
    
    // MARK: - Manager Property Access
}