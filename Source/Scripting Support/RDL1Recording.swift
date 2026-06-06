//
//  RDL1Recording.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/10/08.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
@preconcurrency import DLABridging

/// AppleScript-visible `recording` element (singleton).
///
/// - **Lifecycle policy (app-lifetime singleton):** A single instance is
///   held by `AppDelegate._recordingItem` (a `private lazy var`) and
///   exposed read-only through `AppDelegate.recordingItem`. Constructing
///   additional instances is unsupported: each new instance would
///   register additional observers for `recordingStarted` /
///   `recordingStopped` notification keys, leading to duplicate
///   observer dispatches (and the AppleScript scripting model assumes
///   a single `recording` entity per process). The class is never released
///   during the app's lifetime; therefore the
///   `nonisolated deinit { removeObserver(self) }` below is a
///   **defense-in-depth** safety net, not an expected cleanup path.
@objcMembers
@MainActor
class RDL1Recording: RDL1ScriptableObject {
    /* ============================================================================== */
    
    public var name: String = "current recording"
    public var uniqueID: String = UUID().uuidString
    
    public var fileURL: URL? = nil
    public var startDate: Date? = nil
    public var endDate: Date? = nil
    
    public var running :Bool {
        if let appDelegate = appDelegate {
            return appDelegate.cachedRecordingState
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
    
    /* ============================================================================== */
    
    private lazy var defaults = UserDefaults.standard
    private lazy var notificationCenter = NotificationCenter.default
    private lazy var appDelegate :AppDelegate? = NSApp.delegate as? AppDelegate
    
    /* ============================================================================== */
    
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
    
    private func postNotificationOfChanges() {
        let notification = Notification(name: .recordingStateChangedKey,
                                        object: [Keys.newRecordingData: self])
        notificationCenter.post(notification)
    }
    
    /* ============================================================================== */
    
    override init() {
        // Initialize super class and properties
        super.init()
        self.container = NSApp
        self.containerProperty = Keys.recordingItem
        
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
    
    /// Deregister from `NotificationCenter` on deallocation.
    ///
    /// **Note:** As an app-lifetime singleton (see class doc), this
    /// `deinit` is **defense-in-depth** — it is not reached during normal
    /// app execution. It exists to keep the class safe if the lifecycle
    /// policy is ever changed.
    ///
    /// `addObserver(_:selector:name:object:)` does not return a token;
    /// `removeObserver(self)` removes both observers registered in
    /// `init()` (started / stopped). The `deinit` is `nonisolated`
    /// because `@MainActor` types require that form, and
    /// `removeObserver(_:)` is thread-safe per Foundation's contract.
    nonisolated deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
