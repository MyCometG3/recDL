//
//  RDL1Recording.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/10/08.
//  Copyright © 2017-2024 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
import DLABridging

@objcMembers
class RDL1Recording: NSObject {
    public var name: String = "current recording"
    public var uniqueID: String = UUID().uuidString
    
    public var fileURL: URL? = nil
    public var startDate: Date? = nil
    public var endDate: Date? = nil
    
    public var running :Bool {
        if let appDelegate = appDelegate, let manager = appDelegate.manager {
            return manager.recording
        }
        return false
    }
    
    public var durationInSec: NSNumber? {
        if let dateFrom = startDate {
            let dateTo = endDate ?? Date()
            let elapsed = dateTo.timeIntervalSince(dateFrom)
            return NSNumber(value: elapsed as Double)
        }
        return nil
    }
    
    //
    
    private weak var container :NSObject! = NSApp
    private var containerProperty :String = Keys.recordingItem
    
    private lazy var defaults = UserDefaults.standard
    private lazy var notificationCenter = NotificationCenter.default
    private lazy var appDelegate :AppDelegate? = NSApp.delegate as? AppDelegate
    
    /* ============================================================================== */
    
    private func postNotificationOfChanges() {
        let notification = Notification(name: .recordingStateChangedKey,
                                        object: [Keys.newRecordingData: self])
        notificationCenter.post(notification)
    }
    
    public func handleStartRecording(_ notification :Notification) {
        // print("\(#file) \(#line) \(#function)")
        
        // called after recording is started
        startDate = Date()
        endDate = nil
        
        fileURL = nil
        if let userInfo = notification.userInfo {
            if let item = userInfo[Keys.fileURL] as? URL {
                fileURL = item
            }
        }
        
        postNotificationOfChanges()
    }
    
    public func handleStopRecording(_ notification: Notification) {
        // print("\(#file) \(#line) \(#function)")
        
        // called after recording is stopped
        endDate = Date()
        
        postNotificationOfChanges()
    }
    
    /* ============================================================================== */
    
    override init() {
        super.init()
        
        // Register notification observer for Scripting support
        notificationCenter.addObserver(self,
                                       selector: #selector(handleStartRecording(_:)),
                                       name: .recordingStartedNotificationKey,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(handleStopRecording(_:)),
                                       name: .recordingStoppedNotificationKey,
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
