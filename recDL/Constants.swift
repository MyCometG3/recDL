//
//  Constants.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/10/07.
//  Copyright © 2017-2024 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Foundation

/* ======================================================================================== */
// MARK: - Cocoa scripting support; for Notification.Name extension
/* ======================================================================================== */

extension Notification.Name {
    static let recordingStateChangedKey = Notification.Name("recordingStateChangedKey")
    static let sessionStateChangedKey = Notification.Name("sessionStateChangedKey")
    
    static let handleRestartSessionKey = Notification.Name("handleRestartSession")
    static let handleStopRecordingKey = Notification.Name("handleStopRecording")
    static let handleStartRecordingKey = Notification.Name("handleStartRecording")
}

/* ======================================================================================== */
// MARK: - Application support; for Notification.Name extension
/* ======================================================================================== */

extension Notification.Name {
    static let recordingStartedNotificationKey = NSNotification.Name("RecordingStartedNotification")
    static let recordingStoppedNotificationKey = NSNotification.Name("RecordingStoppedNotification")
    
    static let restartSessionNotificationKey = Notification.Name("restartSessionNotification")
}

/* ======================================================================================== */
// MARK: - Shared Keys enumeration for Cocoa bindings, Dictionary Keys, UserDefaults, etc.
/* ======================================================================================== */

enum Keys {
    // Scripting support
    static let deviceItem = "deviceItem"
    static let sessionItem = "sessionItem"
    static let recordingItem = "recordingItem"
    static let folderURL = "folderURL"
    static let useVideoPreview = "useVideoPreview"
    static let useAudioPreview = "useAudioPreview"
    static let videoSetting = "videoSetting"
    static let audioSetting = "audioSetting"
    static let fileURL = "fileURL"
    
    static let newSessionData = "newSessionData"
    static let newRecordingData = "newRecordingData"

    /* ==================================================== */
    
    // Extra control
    static let showAlternate = "showAlternate"
    static let forceMute = "forceMute"
    static let hideInvisible = "hideInvisible"

    // Control Recordings
    static let prefix = "prefix"
    static let autoQuit = "autoQuit"
    static let recordFor = "recordFor"
    static let maxSeconds = "maxSeconds"
    static let maxDuration = "maxDuration"
    
    static let movieFolder = "movieFolder"

    /* ==================================================== */
    
    // Control Menus
    static let aspectRatio = "aspectRatio"
    static let scale = "scale"
    static let volume = "volume"
    static let volumeTag = "volumeTag"
    static let scaleTag = "scaleTag"
    
    // Configure Recording
    static let displayMode = "displayMode"
    static let pixelFormat = "pixelFormat"
    static let videoStyle = "videoStyle"
    static let clapOffsetH = "clapOffsetH"
    static let clapOffsetV = "clapOffsetV"
    static let videoTimeScale = "videoTimeScale"
    static let timeCodeFormat = "timeCodeFormat"
    static let timeCodeSource = "timeCodeSource"
    static let videoConnection = "videoConnection"
    static let audioConnection = "audioConnection"

    static let videoEncode = "videoEncode"
    static let videoEncoder = "videoEncoder"
    static let videoBitRate = "videoBitRate"
    static let videoFieldDetail = "videoFieldDetail"

    static let audioDepth = "audioDepth"
    static let audioEncode = "audioEncode"
    static let audioEncoder = "audioEncoder"
    static let audioBitRate = "audioBitRate"
    static let audioChannel = "audioChannel"
    static let audioLayout = "audioLayout"
    static let audioReverse34 = "audioReverse34"
    
    /* ==================================================== */
    
    // Status String (Binding)
    static let statusVisible = "statusVisible"
    static let statusString = "statusString"
    
    // Menu String (Binding)
    static let currentVolume = "currentVolume"
    static let currentScale = "currentScale"
    
    // Window AutoSaveName
    static let previewWindow = "previewWindow"
    
    // Icons
    static let idle = "idle"
    static let inactive = "inactive"
    static let active = "active"

    // Pref popup buttons
    static let enableDisplayMode = "enableDisplayMode"
    static let enableVideoConnection = "enableVideoConnection"
    static let enableAudioConnection = "enableAudioConnection"
}

/* ======================================================================================== */
// MARK: - Audio Encoding Constants
/* ======================================================================================== */

enum AudioConstants {
    static let aacBitrateThreshold: UInt = 80_000      // Threshold for AAC LC vs HE-AAC
    static let aacHEBitrateThreshold: UInt = 40_000    // Threshold for HE-AAC vs HE-AACv2
    static let sessionRestartDelay: UInt64 = 100_000_000  // 0.1 seconds in nanoseconds
    static let minAACBitratePerChannel: UInt = 40_000  // Minimum bitrate per channel for AAC
    static let maxAACBitratePerChannel: UInt = 160_000 // Maximum bitrate per channel for AAC
}
