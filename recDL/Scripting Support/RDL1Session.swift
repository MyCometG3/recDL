//
//  RDL1Session.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/10/08.
//  Copyright © 2017年 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
import DLABridging

@objcMembers
class RDL1Session: NSObject {
    public var name: String = "current session"
    public var uniqueID: String = UUID().uuidString
    
    public var running :Bool {
        if let appDelegate = appDelegate, let manager = appDelegate.manager {
            return manager.running
        }
        return false
    }
    
    public var currentDevice :RDL1DeviceInfo? {
        if let appDelegate = appDelegate, let manager = appDelegate.manager, let currentRaw = manager.currentDevice {
            if let lastRaw = deviceRaw, lastRaw == currentRaw {
                return _device
            }
            
            deviceRaw = currentRaw
            _device = RDL1DeviceInfo(from: currentRaw, into: self, property: "currentDevice")
        } else {
            deviceRaw = nil
            _device = nil
        }
        return _device
    }
    
    //
    
    private weak var container :NSObject! = NSApp
    private var containerProperty :String = Keys.sessionItem
    
    private lazy var defaults = UserDefaults.standard
    private lazy var notificationCenter = NotificationCenter.default
    private lazy var appDelegate :AppDelegate? = NSApp.delegate as? AppDelegate
    
    private weak var deviceRaw :DLABDevice? = nil
    private var _device :RDL1DeviceInfo? = nil
    
    /* ============================================================================== */
    
    private func postNotificationOfChanges() {
        let notification = Notification(name: .sessionStateChangedKey,
                                        object: [Keys.newSessionData: self])
        notificationCenter.post(notification)
    }
    
    public func handleRestartSession(_ notification :Notification) {
        // print("\(#file) \(#line) \(#function)")
        
        postNotificationOfChanges()
    }
    
    /* ============================================================================== */
    
    override init() {
        super.init()
        
        // Register notification observer for Scripting support
        notificationCenter.addObserver(self,
                                       selector: #selector(handleRestartSession(_:)),
                                       name: .restartSessionNotificationKey,
                                       object: nil)
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
