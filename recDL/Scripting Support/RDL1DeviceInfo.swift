//
//  RDL1DeviceInfo.swift
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
class RDL1DeviceInfo: RDL1ScriptableObject {
    /* ============================================================================== */
    
    public var name :String // "dev\(nameCounter)"
    public var uniqueID :String = UUID().uuidString
    
    public var modelName :String? = nil
    public var displayName :String? = nil
    public var persistentID :Int = 0
    public var topologicalID :Int = 0
    public var supportFlag :Int = 0
    public var supportCapture :Bool = false
    public var supportPlayback :Bool = false
    public var supportKeying :Bool = false
    public var supportInputFormatDetection :Bool = false
    public var inputVideoSettingArray :[RDL1VideoSetting] = []
    
    public var inputVideoSetting :RDL1VideoSetting? {
        if let device = deviceRaw, let currentRaw = device.inputVideoSetting {
            if let lastRaw = inputVideoSettingRaw, lastRaw == currentRaw {
                return _inputVideoSetting
            }
            
            inputVideoSettingRaw = currentRaw
            _inputVideoSetting = RDL1VideoSetting(from: currentRaw, into: self,
                                                  key: "inputVideoSetting")
        } else {
            inputVideoSettingRaw = nil
            _inputVideoSetting = nil
        }
        return _inputVideoSetting
    }
    
    public var inputAudioSetting : RDL1AudioSetting? {
        if let device = deviceRaw, let currentRaw = device.inputAudioSetting {
            if let lastRaw = inputAudioSettingRaw, lastRaw == currentRaw {
                return _inputAudioSetting
            }
            
            inputAudioSettingRaw = currentRaw
            _inputAudioSetting = RDL1AudioSetting(from: currentRaw, into: self,
                                                  key: "inputAudioSetting")
        } else {
            inputAudioSettingRaw = nil
            _inputAudioSetting = nil
        }
        return _inputAudioSetting
    }
    
    /* ============================================================================== */
    
    private var _outputVideoSetting :RDL1VideoSetting? = nil
    private var _outputAudioSetting :RDL1AudioSetting? = nil
    private var _inputVideoSetting :RDL1VideoSetting? = nil
    private var _inputAudioSetting : RDL1AudioSetting? = nil
    
    private weak var outputVideoSettingRaw :DLABVideoSetting? = nil
    private weak var outputAudioSettingRaw :DLABAudioSetting? = nil
    private weak var inputVideoSettingRaw :DLABVideoSetting? = nil
    private weak var inputAudioSettingRaw :DLABAudioSetting? = nil
    private weak var deviceRaw :DLABDevice? = nil
    
    /* ============================================================================== */
    
    convenience init(from device :DLABDevice, into newContainer :NSObject, property newProperty :String) {
        self.init()
        
        container = newContainer
        containerProperty = String(newProperty)
        
        deviceRaw = device
        
        modelName = String(device.modelName)
        displayName = String(device.displayName)
        persistentID = Int(device.persistentID)
        topologicalID = Int(device.topologicalID)
        supportFlag = Int(device.supportFlag.rawValue)
        supportCapture = Bool(device.supportCapture)
        supportPlayback = Bool(device.supportPlayback)
        supportKeying = Bool(device.supportKeying)
        supportInputFormatDetection = Bool(device.supportInputFormatDetection)
        
        device.inputVideoSettingArray?.forEach { setting in
            let supportedSetting = RDL1VideoSetting(from: setting, into: self,
                                                    key: "inputVideoSettingArray")
            inputVideoSettingArray.append(supportedSetting)
        }
    }
    
    /* ============================================================================== */
    
    override init() {
        self.name = RDL1DeviceInfo.initialName("dev")
        
        // Initialize super class and properties
        super.init()
        self.container = NSApp
        self.containerProperty = Keys.deviceItem
    }
    
    static var nameCounter = 0
    static func initialName(_ prefix: String) -> String {
        self.nameCounter += 1
        return "\(prefix)\(nameCounter)"
    }
}
