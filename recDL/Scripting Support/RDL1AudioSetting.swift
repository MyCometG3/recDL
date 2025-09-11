//
//  RDL1AudioSetting.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/10/08.
//  Copyright © 2017-2025 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
@preconcurrency import DLABridging

@objcMembers
@MainActor
class RDL1AudioSetting: RDL1ScriptableObject {
    /* ============================================================================== */
    
    public var name :String // "as\(nameCounter)"
    public var uniqueID :String = UUID().uuidString
    
    public var sampleSize :Int = 0
    public var channelCount :Int = 0
    public var sampleType :Int = 0
    public var sampleRate :Int = 0
    
    /* ============================================================================== */
    
    convenience init?(from audioSetting :DLABAudioSetting, into newContainer :NSObject, key newProperty :String) {
        self.init()
        
        container = newContainer
        containerProperty = String(newProperty)
        
        sampleSize = Int(audioSetting.sampleSize)
        channelCount = Int(audioSetting.channelCount)
        sampleType = Int(audioSetting.sampleType.rawValue)
        sampleRate = Int(audioSetting.sampleRate.rawValue)
    }
    
    /* ============================================================================== */
    
    override init() {
        self.name = RDL1AudioSetting.initialName("as")
        
        // Initialize super class and properties
        super.init()
        self.container = NSApp
        self.containerProperty = Keys.audioSetting
    }
    
    static var nameCounter = 0
    static func initialName(_ prefix: String) -> String {
        self.nameCounter += 1
        return "\(prefix)\(nameCounter)"
    }
}
