//
//  RDL1VideoSetting.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/10/08.
//  Copyright © 2017-2024 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
@preconcurrency import DLABridging

@objcMembers
@MainActor
class RDL1VideoSetting: RDL1ScriptableObject {
    /* ============================================================================== */
    
    public var name :String // "vs\(nameCounter)"
    public var uniqueID :String = UUID().uuidString
    
    public var width :Int = 0
    public var height :Int = 0
    public var modeName :String? = nil
    public var duration :Int = 0
    public var timeScale :Int = 0
    public var displayMode :String? = nil
    public var fieldDominance :String? = nil
    public var displayModeFlag :Int = 0
    public var isHD :Bool = false
    public var useSERIAL :Bool = false
    public var useVITC :Bool = false
    public var useRP188 :Bool = false
    public var pixelFormat :String? = nil
    public var inputFlag :Int = 0
    public var outputFlag :Int = 0
    public var rowBytes :Int = 0
    
    //
    
    /* ============================================================================== */
    
    convenience init(from videoSetting :DLABVideoSetting, into newContainer :NSObject, key newProperty :String) {
        self.init()
        
        container = newContainer
        containerProperty = String(newProperty)
        
        width = Int(videoSetting.width)
        height = Int(videoSetting.height)
        modeName = String(videoSetting.name)
        duration = Int(videoSetting.duration)
        timeScale = Int(videoSetting.timeScale)
        displayMode = NSFileTypeForHFSTypeCode(videoSetting.displayMode.rawValue)
        fieldDominance = NSFileTypeForHFSTypeCode(videoSetting.fieldDominance.rawValue)
        displayModeFlag = Int(videoSetting.displayModeFlag.rawValue)
        isHD = Bool(videoSetting.isHD)
        useSERIAL = Bool(videoSetting.useSERIAL)
        useVITC = Bool(videoSetting.useVITC)
        useRP188 = Bool(videoSetting.useRP188)
        
        pixelFormat = NSFileTypeForHFSTypeCode(videoSetting.pixelFormat.rawValue)
        inputFlag = Int(videoSetting.inputFlag.rawValue)
        outputFlag = Int(videoSetting.outputFlag.rawValue)
        rowBytes = Int(videoSetting.rowBytes)
    }
    
    /* ============================================================================== */
    
    override init() {
        self.name = RDL1VideoSetting.initialName("vs")
        
        // Initialize super class and properties
        super.init()
        self.container = NSApp
        self.containerProperty = Keys.videoSetting
    }
    
    static var nameCounter = 0
    static func initialName(_ prefix: String) -> String {
        self.nameCounter += 1
        return "\(prefix)\(nameCounter)"
    }
}
