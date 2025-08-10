//
//  AppDelegate+UI.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2025/06/14.
//  Copyright © 2025 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
import CoreVideo
@preconcurrency import DLABridging
import DLABCaptureManager

extension AppDelegate {
    /* ======================================================================================== */
    // MARK: - Status label support
    /* ======================================================================================== */
    
    public func updateStatusDefault() {
        // print("\(#file) \(#line) \(#function)")
        
        guard checkReadiness() else {
            updateStatus("NOTICE: Please connect device and restart this application.")
            return
        }
        
        // Show default status string
        updateStatus(nil)
        
        // Try update preview connection enabled state as is
        checkOnActiveSpace()
        
        // Update Dock Icon
        updateDockIcon()
    }
    
    internal func startUpdateStatus() {
        // print("\(#file) \(#line) \(#function)")
        
        // setup status update timer
        if updateTimer == nil {
            updateTimer = Timer.scheduledTimer(timeInterval: 0.5,
                                               target: self,
                                               selector: #selector(updateStatusDefault),
                                               userInfo: nil,
                                               repeats: true)
        }
    }
    
    internal func stopUpdateStatus() {
        // print("\(#file) \(#line) \(#function)")
        
        // discard status update timer
        if let updateTimer = updateTimer {
            updateTimer.invalidate()
            self.updateTimer = nil
        }
        
        // turn off status label
        defaults.set(false, forKey: Keys.statusVisible)
        defaults.setValue("", forKey: Keys.statusString)
    }
    
    private func updateStatus(_ status: String?) {
        // print("\(#file) \(#line) \(#function)")
        
        if let status = status , status.count > 0 {
            // Stop updateStatus Timer
            stopUpdateStatus()
            
            // Show requested status string
            defaults.set(true, forKey: Keys.statusVisible)
            defaults.setValue(status, forKey: Keys.statusString)
        } else {
            // Start updateStatus Timer
            startUpdateStatus()
            
            // Show auto-generated status string
            var visible = false
            var status = ""
            let showAlternate = defaults.bool(forKey: Keys.showAlternate)
            let forceMute = defaults.bool(forKey: Keys.forceMute)
            
            if manager != nil && cachedRecordingState {
                // Recording now
                visible = true
                status = "Recording..."
                
                if let stopTimer = stopTimer {
                    let interval: TimeInterval = stopTimer.fireDate.timeIntervalSince(Date())
                    if interval > 120 {
                        status = "Recording remains \(Int(interval/60)) minute(s)..."
                    } else {
                        status = "Recording remains \(Int(interval)) second(s)..."
                    }
                    
                    let autoQuit = defaults.bool(forKey: Keys.autoQuit)
                    if autoQuit {
                        status += " (AutoQuit)"
                    }
                }
            } else {
                // Show when preview is disabled
                if showAlternate || forceMute {
                    visible = true
                    status = " preview is disabled."
                    if showAlternate && forceMute {
                        status = "Video/Audio" + status
                    } else if showAlternate {
                        status = "Video" + status
                    } else if forceMute {
                        status = "Audio" + status
                    }
                }
            }
            
            // Update status string
            defaults.set(visible, forKey: Keys.statusVisible)
            defaults.setValue(status, forKey: Keys.statusString)
        }
    }
    
    private func updateDockIcon() {
        // print("\(#file) \(#line) \(#function)")
        
        // Dock Icon Animation
        if manager != nil && cachedRecordingState {
            if !iconAnimation {
                iconAnimation = true    // Start Icon Animation
            }
            
            Task(priority: .background) {
                // Toggle Animation State
                iconActiveState = !iconActiveState
                
                // Perform AppIcon Badge animation
                NSApp.dockTile.badgeLabel = iconActiveState ? "REC" : "***"
                
                // Perform AppIcon Animation
                if useIconAnimation {
                    let targetIcon = iconActiveState ? iconActive : iconInactive
                    NSApp.applicationIconImage = targetIcon
                }
            }
        } else {
            if !iconAnimation {
                return // No Animation
            }
            iconAnimation = false   // Stop Icon Animation
            
            Task(priority: .background) {
                // Reset AppIcon Badge state
                NSApp.dockTile.badgeLabel = nil
                
                // Reset AppIcon Animation state
                if useIconAnimation {
                    NSApp.applicationIconImage = iconIdle
                }
            }
        }
    }
    
    /* ============================================ */
    // MARK: - Volume control support
    /* ============================================ */
    
    internal func setVolume(_ volume: Int) {
        // print("\(#file) \(#line) \(#function)")
        
        let forceMute = defaults.bool(forKey: Keys.forceMute)
        if volume >= 0 {
            defaults.set(volume, forKey:Keys.volume)
            
            if let manager = manager {
                manager.volume = (forceMute ? 0.0 : Float(volume) / 100.0)
            }
            
            updateCurrentVolume()
        } else {
            let prevVolume = defaults.integer(forKey: Keys.volume)
            
            if let manager = manager {
                manager.volume = (forceMute ? 0.0 : Float(prevVolume) / 100.0)
            }
        }
        
        volumePopup.selectItem(withTag: -1) // TODO
    }
    
    private func updateCurrentVolume() {
        // print("\(#file) \(#line) \(#function)")
        
        // Update currentVolume title of NSPopupButton
        let volume = defaults.integer(forKey: Keys.volume)
        
        let currentVolume = "Vol: \(volume)%"
        defaults.setValue(currentVolume, forKey: Keys.currentVolume)
    }
    
    /* ============================================ */
    // MARK: - Window resizing support
    /* ============================================ */
    
    internal func setAspectRatio(_ ratioTag: Int) {
        // print("\(#file) \(#line) \(#function)")
        
        defaults.set(ratioTag, forKey: Keys.aspectRatio)
        
        resizeAspect()
        
        let notification = Notification(name: .restartSessionNotificationKey,
                                        object: self,
                                        userInfo: nil)
        restartSession(notification)
    }
    
    internal func setScale(_ scaleTag: Int) {
        // print("\(#file) \(#line) \(#function)")
        
        if scaleTag > 0 {
            defaults.set(scaleTag, forKey: Keys.scale)
            
            resizeScale()
            
            updateCurrentScale() // Update later in layoutSublayersOfLayer()
        } else {
            // Do nothing
        }
        
        scalePopup.selectItem(withTag: -1) // TODO
    }
    
    internal func updateCurrentScale() {
        // print("\(#file) \(#line) \(#function)")
        
        // Update currentScale title of NSPopupButton
        var scaleTag = defaults.integer(forKey: Keys.scale)
        
        if let manager = manager, let videoPreview = manager.videoPreview, let previewLayer = videoPreview.layer {
            let nativeSize = manager.encodedSize
            let scale: CGFloat = 100.0 * previewLayer.bounds.size.height / nativeSize.height
            scaleTag = Int(scale + 0.05)
        }
        
        let currentScale = "Scale: \(scaleTag)%"
        defaults.setValue(currentScale, forKey: Keys.currentScale)
    }
    
    private func resizeAspect() {
        // print("\(#file) \(#line) \(#function)")
        
        // Resize Window Horizontally using pixel aspect ratio
        if let window = parentView.window, let manager = manager {
            let nativeSize = manager.encodedSize
            let contentSize = window.contentView!.bounds.size
            let topOffset: CGFloat = window.frame.size.height - contentSize.height
            
            let targetRatio: CGFloat = apertureRatio() * nativeSize.width / nativeSize.height
            let newContentSize = CGSize(width: contentSize.height * targetRatio, height: contentSize.height)
            
            // Preserve top center
            let newRect = CGRect(x: window.frame.midX - newContentSize.width/2.0,
                                 y: window.frame.maxY - newContentSize.height - topOffset,
                                 width: newContentSize.width,
                                 height: newContentSize.height + topOffset)
            window.setFrame(newRect, display: true, animate: true)
        }
    }
    
    private func resizeScale() {
        // print("\(#file) \(#line) \(#function)")
        
        // Resize Window using specified scale value
        if let window = parentView.window, let manager = manager {
            let nativeSize = manager.encodedSize
            let contentSize = window.contentView!.bounds.size
            let topOffset: CGFloat = window.frame.size.height - contentSize.height
            
            let targetRatio: CGFloat = apertureRatio() * nativeSize.width / nativeSize.height
            let newContentSize = CGSize(width: nativeSize.height * targetRatio * scale(),
                                        height: nativeSize.height * scale())
            
            // Preserve top center
            let newRect = CGRect(x: window.frame.midX - newContentSize.width/2.0,
                                 y: window.frame.maxY - newContentSize.height - topOffset,
                                 width: newContentSize.width,
                                 height: newContentSize.height + topOffset)
            window.setFrame(newRect, display: true, animate: true)
        }
    }
    
    private func apertureRatio() -> CGFloat {
        // print("\(#file) \(#line) \(#function)")
        
        var ratio: CGFloat = 1.0
        let ratioTag = defaults.integer(forKey: Keys.aspectRatio)
        
        if ratioTag > 1001 {
            let numerator: CGFloat = CGFloat(ratioTag / 1000)
            let denominator: CGFloat = CGFloat(ratioTag % 1000)
            ratio = numerator/denominator
        }
        return ratio
    }
    
    private func scale() -> CGFloat {
        // print("\(#file) \(#line) \(#function)")
        
        var scale: CGFloat = 1.0
        let scaleTag = defaults.integer(forKey: Keys.scale)
        
        if scaleTag >= 50 {
            scale = CGFloat(scaleTag)/100.0
        }
        return scale
    }
    
    /* ======================================================================================== */
    // MARK: - Preview Layer support
    /* ======================================================================================== */
    
    /// Show/hide the layer according to current space
    private func checkOnActiveSpace() {
        // print("\(#file) \(#line) \(#function)")
        
        let showAlternate = defaults.bool(forKey: Keys.showAlternate)
        
        let onActive = window.isOnActiveSpace
        let hideInvisible = defaults.bool(forKey: Keys.hideInvisible)
        
        let targetState = !showAlternate && (onActive ? onActive : !hideInvisible)
        let currentState = previewLayerReady
        
        if targetState != currentState {
            if targetState == true {
                addPreviewLayer()
            } else {
                removePreviewLayer()
            }
        }
    }
    
    // Apply video aspect ratio (considering clean aperture)
    private func applyApertureRatio() {
        // print("\(#file) \(#line) \(#function)")
        
        if let manager = manager, let videoPreview = manager.videoPreview {
            var needsLayout = true
            let targetAspectRatio = apertureRatio()
            if let currentAspectRatio = videoPreview.customPixelAspectRatio {
                needsLayout = (currentAspectRatio != targetAspectRatio)
            }
            if needsLayout {
                videoPreview.customPixelAspectRatio = targetAspectRatio
                videoPreview.needsLayout = true
            }
        } else {
            printVerbose("ERROR:\(self.className): \(#function) - Failed to applyApertureRatio()")
        }
    }
    
    internal func addPreviewLayer() {
        // print("\(#file) \(#line) \(#function)")
        
        // Check if already added
        if previewLayerReady == true {
            return
        }
        
        // Check if video preview is disabled
        if defaults.bool(forKey: Keys.showAlternate) {
            return
        }
        
        if let manager = manager {
            // Populate manager.videoPreview if required
            if manager.videoPreview == nil {
                manager.videoPreview = parentView // as? CaptureVideoPreview
            }
            
            if let videoPreview = manager.videoPreview {
                //
                videoPreview.prepare()
                
                // Apply video aspect ratio (considering clean aperture)
                applyApertureRatio()
                
                previewLayerReady = true
            }
        }
        
        //
        if previewLayerReady == false {
            printVerbose("ERROR:\(self.className): \(#function) - Failed to addPreviewLayer()")
        }
    }
    
    internal func removePreviewLayer() {
        // print("\(#file) \(#line) \(#function)")
        
        // Check if already removed
        if previewLayerReady == false {
            return
        }
        
        if let manager = manager, let videoPreview = manager.videoPreview {
            //
            videoPreview.shutdown()
            previewLayerReady = false
            
            // Remove preview sublayer
            manager.videoPreview = nil
        } else {
            printVerbose("ERROR:\(self.className): \(#function) - Failed to removePreviewLayer()")
        }
    }
    
    /* ==================================================================================== */
    //MARK: -
    /* ==================================================================================== */
}
