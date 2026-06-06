//
//  RDL1Session.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/10/08.
//  Copyright © 2017-2026 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
@preconcurrency import DLABridging

/// AppleScript-visible `session` element (singleton).
///
/// - **Lifecycle policy (app-lifetime singleton):** A single instance is
///   held by `AppDelegate._sessionItem` (a `private lazy var`) and exposed
///   read-only through `AppDelegate.sessionItem`. Constructing additional
///   instances is unsupported: each new instance would register an
///   additional observer for `restartSessionNotificationKey`, leading
///   to duplicate observer dispatches (and the AppleScript scripting
///   model assumes a single `session` entity per process). The class is
///   never released during the app's lifetime; therefore the
///   `nonisolated deinit { removeObserver(self) }` below is a
///   **defense-in-depth** safety net, not an expected cleanup path.
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
    
    /// Deregister from `NotificationCenter` on deallocation.
    ///
    /// **Note:** As an app-lifetime singleton (see class doc), this
    /// `deinit` is **defense-in-depth** — it is not reached during normal
    /// app execution. It exists to keep the class safe if the lifecycle
    /// policy is ever changed.
    ///
    /// `addObserver(_:selector:name:object:)` does not return a token;
    /// the standard cleanup for the selector-based API is
    /// `removeObserver(_:)` (which removes every entry registered
    /// against `self`). This class only registers its own observer in
    /// `init()`, so `removeObserver(self)` is exactly equivalent to
    /// per-token removal. The `deinit` is `nonisolated` because
    /// `@MainActor` types require that form, and `removeObserver(_:)`
    /// is thread-safe per Foundation's contract.
    nonisolated deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
