//
//  RDL1Session.swift
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
class RDL1Session: RDL1ScriptableObject {
    /* ============================================================================== */
    
    public var name: String = "current session"
    public var uniqueID: String = UUID().uuidString
    
    public var running :Bool {
        if let appDelegate = appDelegate {
            return appDelegate.cachedRunningState
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
    
    /* ============================================================================== */
    
    private lazy var defaults = UserDefaults.standard
    private lazy var notificationCenter = NotificationCenter.default
    private lazy var appDelegate :AppDelegate? = NSApp.delegate as? AppDelegate
    
    private weak var deviceRaw :DLABDevice? = nil
    private var _device :RDL1DeviceInfo? = nil
    
    /* ============================================================================== */
    
    public func handleRestartSession(_ notification :Notification) {
        // print("\(#file) \(#line) \(#function)")
        
        postNotificationOfChanges()
    }
    
    /* ============================================================================== */
    
    private func postNotificationOfChanges() {
        let notification = Notification(name: .sessionStateChangedKey,
                                        object: [Keys.newSessionData: self])
        notificationCenter.post(notification)
    }
    
    /* ============================================================================== */
    
    override init() {
        // Initialize super class and properties
        super.init()
        self.container = NSApp
        self.containerProperty = Keys.sessionItem
        
        // Register notification observer for Scripting support
        notificationCenter.addObserver(self,
                                       selector: #selector(handleRestartSession(_:)),
                                       name: .restartSessionNotificationKey,
                                       object: nil)
    }
}
