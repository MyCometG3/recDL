//
//  Constants.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/10/07.
//  Copyright © 2017年 MyCometG3. All rights reserved.
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

    static let videoEncode = "videoEncode"
    static let videoEncoder = "videoEncoder"
    static let videoBitRate = "videoBitRate"
    static let videoFieldDetail = "videoFieldDetail"

    static let audioDepth = "audioDepth"
    static let audioEncode = "audioEncode"
    static let audioEncoder = "audioEncoder"
    static let audioBitRate = "audioBitRate"
    static let audioChannel = "audioChannel"
    
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

}
