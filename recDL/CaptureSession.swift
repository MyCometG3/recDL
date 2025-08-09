//
//  CaptureSession.swift
//  recDL
//
//  Created by AI Assistant on 2025/01/09.
//  Copyright © 2025 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Foundation

/// Protocol for capture manager to avoid direct dependency
protocol CaptureManagerProtocol {
    func captureStartAsync() async -> Bool
    func captureStopAsync() async -> Bool  
    func recordToggleAsync() async
    var recording: Bool { get }
}

/// Actor that centralizes capture session state management and enforces sequential operations
@globalActor
actor CaptureSession {
    static let shared = CaptureSession()
    
    private var manager: CaptureManagerProtocol?
    private var isConfigured = false
    private var isStarted = false
    private var isRecording = false
    
    // MARK: - Lifecycle Methods
    
    /// Configure the capture session with the provided manager
    func configure<T: CaptureManagerProtocol>(manager: T) async -> Bool {
        guard !isConfigured else { return true }
        
        self.manager = manager
        isConfigured = true
        return true
    }
    
    /// Start the capture session
    func start() async -> Bool {
        guard let manager = manager, isConfigured, !isStarted else { return false }
        
        let result = await manager.captureStartAsync()
        if result {
            isStarted = true
        }
        return result
    }
    
    /// Stop the capture session
    func stop() async -> Bool {
        guard let manager = manager, isStarted else { return false }
        
        let result = await manager.captureStopAsync()
        if result {
            isStarted = false
            isRecording = false
        }
        return result
    }
    
    /// Toggle recording state
    func toggleRecording() async -> Bool {
        guard let manager = manager, isStarted else { return false }
        
        await manager.recordToggleAsync()
        isRecording = manager.recording
        return true
    }
    
    /// Reset the session (stop and clear manager)
    func reset() async {
        if isStarted {
            _ = await stop()
        }
        
        manager = nil
        isConfigured = false
        isStarted = false
        isRecording = false
    }
    
    // MARK: - State Queries
    
    var currentManager: CaptureManagerProtocol? {
        return manager
    }
    
    var sessionIsConfigured: Bool {
        return isConfigured
    }
    
    var sessionIsStarted: Bool {
        return isStarted
    }
    
    var sessionIsRecording: Bool {
        return isRecording
    }
}