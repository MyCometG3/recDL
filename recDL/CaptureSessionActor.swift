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

/// Actor that encapsulates CaptureManager functionality and provides async interface
actor CaptureSession {
    
    // MARK: - Properties
    
    private var manager: CaptureManager?
    private var verbose: Bool = true
    
    // MARK: - Initialization
    
    init() {
        self.manager = nil
        self.verbose = true
    }
    
    // MARK: - Configuration
    
    func setVerbose(_ verbose: Bool) {
        self.verbose = verbose
    }
    
    // MARK: - Session Management
    
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
        manager.videoConnection = videoConnection
        manager.audioConnection = audioConnection
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
    
    func startCaptureSession() async -> Bool {
        guard let manager = manager else { return false }
        
        return await manager.captureStartAsync()
    }
    
    func stopCaptureSession() async -> Bool {
        guard let manager = manager else { return false }
        
        return await manager.captureStopAsync()
    }
    
    // MARK: - Recording Management
    
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
    
    func startRecording(to movieURL: URL) async -> Bool {
        guard let manager = manager, !manager.recording else { return false }
        
        manager.movieURL = movieURL
        let toggleResult = await manager.recordToggleAsync()
        
        // Return true if recording actually started
        return toggleResult && manager.recording
    }
    
    func stopRecording() async -> Bool {
        guard let manager = manager, manager.recording else { return false }
        
        let toggleResult = await manager.recordToggleAsync()
        
        // Return true if recording actually stopped
        return toggleResult && !manager.recording
    }
    
    // MARK: - State Access
    
    func isRecording() -> Bool {
        return manager?.recording ?? false
    }
    
    func getManager() -> CaptureManager? {
        return manager
    }
    
    func destroyManager() {
        manager = nil
    }
    
    // MARK: - Manager Property Access
    
    func getManagerRecordingState() -> Bool {
        return manager?.recording ?? false
    }
}