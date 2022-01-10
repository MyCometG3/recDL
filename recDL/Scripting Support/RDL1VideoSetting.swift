//
//  RDL1VideoSetting.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/10/08.
//  Copyright © 2017-2022 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
import DLABridging

private var nameCounter = 1

@objcMembers
class RDL1VideoSetting: NSObject {
    public var name :String = "vs\(nameCounter)"
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
    public var useVITC :Bool = false
    public var useRP188 :Bool = false
    public var pixelFormat :String? = nil
    public var inputFlag :Int = 0
    public var outputFlag :Int = 0
    public var rowBytes :Int = 0
    
    //
    
    private weak var container :NSObject! = NSApp
    private var containerProperty :String = Keys.videoSetting
    
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
        useVITC = Bool(videoSetting.useVITC)
        useRP188 = Bool(videoSetting.useRP188)
        
        pixelFormat = NSFileTypeForHFSTypeCode(videoSetting.pixelFormat.rawValue)
        inputFlag = Int(videoSetting.inputFlag.rawValue)
        outputFlag = Int(videoSetting.outputFlag.rawValue)
        rowBytes = Int(videoSetting.rowBytes)
    }
    
    /* ============================================================================== */
    
    override init() {
        super.init()
        nameCounter += 1
    }
    
    override var objectSpecifier: NSScriptObjectSpecifier? {
        let desc = container.classDescription as! NSScriptClassDescription
        let spec = (container == NSApp) ? nil : container.objectSpecifier
        let prop = containerProperty
        let specifier = NSPropertySpecifier(containerClassDescription: desc,
                                            containerSpecifier: spec,
                                            key: prop)
        //let specifier = NSNameSpecifier(containerClassDescription: desc,
        //                                containerSpecifier: spec,
        //                                key: prop,
        //                                name: name)
        return specifier
    }
}
