//
//  RDL1AudioSetting.swift
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
class RDL1AudioSetting: NSObject {
    public var name :String = "as\(nameCounter)"
    public var uniqueID :String = UUID().uuidString
    
    public var sampleSize :Int = 0
    public var channelCount :Int = 0
    public var sampleType :Int = 0
    public var sampleRate :Int = 0
    
    //
    
    private weak var container :NSObject! = NSApp
    private var containerProperty :String = Keys.audioSetting
    
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
