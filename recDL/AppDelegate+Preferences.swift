//
//  AppDelegate+Preferences.swift
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
    // MARK: - Preferences window support
    /* ======================================================================================== */
    
    public func deviceDescription() -> String {
        var desc:String = "ERROR: DeviceInfo is not available."
        if let deviceInfo = deviceInfo {
            let modelName = deviceInfo["modelName"] as! String
            let displayName = deviceInfo["displayName"] as! String
            let persistentID = deviceInfo["persistentID"] as! Int64
            let deviceGroupID = deviceInfo["deviceGroupID"] as! Int64
            let topologicalID = deviceInfo["topologicalID"] as! Int64
            let numberOfSubDevices = deviceInfo["numberOfSubDevices"] as! Int64
            let subDeviceIndex = deviceInfo["subDeviceIndex"] as! Int64
            let profileID = deviceInfo["profileID"] as! Int64
            let duplex = deviceInfo["duplex"] as! Int64
            let duplexStr:String = NSFileTypeForHFSTypeCode(UInt32(duplex))
            
            desc = "DeviceInfo = \(persistentID):\(topologicalID):\(profileID)"
            desc += " \(deviceGroupID):\(numberOfSubDevices):\(subDeviceIndex)"
            desc += " \(duplexStr)"
            
            desc += "\n \(displayName)"
            if modelName != displayName {
                desc += ",\n \(modelName)"
            }
        }
        return desc
    }
    
    public func displayModeDescription() -> String {
        var desc:String = "ERROR: displayMode is not available."
        if let selectedDisplayMode = displayModeCurrent(), let settingInfo = settingInfoCurrent() {
            if let displayMode = displayModeFrom(settingInfo), selectedDisplayMode == displayMode {
                // create description from settingInfo
                let name = settingInfo["name"] as! String
                let typeString = settingInfo["displayMode"] as! String
                let width = settingInfo["width"] as! Int
                let height = settingInfo["height"] as! Int
                let duration = settingInfo["duration"] as! Int64
                let timeScale = settingInfo["timeScale"] as! Int64
                let fieldDominance = settingInfo["fieldDominance"] as! String
                var fdString:String = "Unknown"
                switch fieldDominance {
                case NSFileTypeForHFSTypeCode(DLABFieldDominance.lowerFieldFirst.rawValue):
                    fdString = "lowerFieldFirst"
                case NSFileTypeForHFSTypeCode(DLABFieldDominance.upperFieldFirst.rawValue):
                    fdString = "upperFieldFirst"
                case NSFileTypeForHFSTypeCode(DLABFieldDominance.progressiveFrame.rawValue):
                    fdString = "progressiveFrame"
                case NSFileTypeForHFSTypeCode(DLABFieldDominance.progressiveSegmentedFrame.rawValue):
                    fdString = "progressiveSegmentedFrame"
                default:
                    fdString = "Unknown";
                }
                desc = "DisplayMode = \"\(name)\",\n \(typeString), \(width)x\(height), \(duration)/\(timeScale),\n \(fdString)"
            }
        }
        return desc
    }
    
    public func videoStyleDescription() -> String {
        var desc:String = "ERROR: unknown videoStyle is specified."
        let vsString:String? = defaults.string(forKey: Keys.videoStyle)
        if let vsString = vsString {
            let videoStyle = VideoStyle.init(rawValue: vsString)
            if let videoStyle = videoStyle {
                let name = videoStyle.rawValue
                let encodedSize = videoStyle.encodedSize()
                let encodedDesc = String(format: "encoded: %.1fx%.1f", encodedSize.width, encodedSize.height)
                let visibleSize = videoStyle.visibleSize()
                let visibleDesc = String(format: "visible: %.1fx%.1f", visibleSize.width, visibleSize.height)
                let clapRangeH = Int((encodedSize.width - visibleSize.width) / 2)
                let clapRangeV = Int((encodedSize.height - visibleSize.height) / 2)
                let clapRangeDesc = String(format:"clapRange: +-%d/+-%d", clapRangeH, clapRangeV)
                
                desc = "VideoStyle = \"\(name)\",\n \(encodedDesc) \(visibleDesc) \(clapRangeDesc)"
            }
        }
        return desc
    }
    
    public func updateDisplayModeMenu(_ menu:NSMenu) -> Int {
        // Show only supported displayMode menu depends on Device
        var selectedTag = -1
        guard checkReadiness() else { return selectedTag }
        
        if let list:[String:Any] = availableSettingInfo, list.count > 0 {
            // previous selectedTag
            selectedTag = defaults.integer(forKey: Keys.displayMode)
            
            let sortedKeys = list.keys.sorted()
            menu.removeAllItems()
            for key:String in sortedKeys {
                let settingInfo:[String:Any] = list[key] as! [String:Any]
                if let displayMode:DLABDisplayMode = displayModeFrom(settingInfo) {
                    let menuTitle = NSFileTypeForHFSTypeCode(displayMode.rawValue) + ": " + key
                    let menuItem = NSMenuItem(title: menuTitle, action: nil, keyEquivalent: "")
                    menuItem.tag = Int(displayMode.rawValue)
                    
                    menu.addItem(menuItem)
                }
            }
            
            if menu.item(withTag: selectedTag) == nil {
                let menuItem = menu.item(at: 0)!
                selectedTag = menuItem.tag
            }
            
            defaults.setValue(true, forKey: Keys.enableDisplayMode)
        } else {
            defaults.setValue(false, forKey: Keys.enableDisplayMode)
        }
        if selectedTag >= 0 {
            defaults.setValue(selectedTag, forKey: Keys.displayMode)
        }
        return selectedTag
    }
    
    public func updateVideoConnectionMenu(_ menu:NSMenu) -> Int {
        // Show unsupported connection menutitle in red color
        let size = NSFont.smallSystemFontSize
        let font = NSFont.menuFont(ofSize: size)
        let attrYes:[NSAttributedString.Key : Any] = [ .font: font ]
        let attrNo:[NSAttributedString.Key : Any] = [ .font: font, .foregroundColor: NSColor.red ]
        
        var selectedTag = -1
        guard checkReadiness() else { return selectedTag }
        
        if let manager = manager, let device = manager.currentDevice {
            if let numberValue = try? device.intValue(for: .configurationVideoInputConnection) {
                selectedTag = numberValue.intValue
                
                defaults.setValue(selectedTag, forKey: Keys.videoConnection)
            }
            if let numberValue = try? device.intValue(for: DLABAttribute.videoInputConnections) {
                let availableConnection:Int = numberValue.intValue
                for menuItem in menu.items {
                    let ready = (availableConnection & menuItem.tag) > 0
                    let fontAttr = (ready ? attrYes : attrNo)
                    menuItem.attributedTitle = NSAttributedString(string: menuItem.title,
                                                                  attributes: fontAttr)
                    menuItem.state = (menuItem.tag == selectedTag) ? .on : .off
                }
            }
            
            defaults.setValue(true, forKey: Keys.enableVideoConnection)
        } else {
            defaults.setValue(false, forKey: Keys.enableVideoConnection)
        }
        return selectedTag
    }
    
    public func updateAudioConnectionMenu(_ menu:NSMenu) -> Int {
        // Show unsupported connection menutitle in red color
        let size = NSFont.smallSystemFontSize
        let font = NSFont.menuFont(ofSize: size)
        let attrYes:[NSAttributedString.Key : Any] = [ .font: font ]
        let attrNo:[NSAttributedString.Key : Any] = [ .font: font, .foregroundColor: NSColor.red ]
        
        var selectedTag = -1
        guard checkReadiness() else { return selectedTag }
        
        if let manager = manager, let device = manager.currentDevice {
            if let numberValue = try? device.intValue(for: .configurationAudioInputConnection) {
                selectedTag = numberValue.intValue
                
                defaults.setValue(selectedTag, forKey: Keys.audioConnection)
            }
            if let numberValue = try? device.intValue(for: DLABAttribute.audioInputConnections) {
                let availableConnection:UInt32 = numberValue.uint32Value
                for menuItem in menu.items {
                    let ready = (availableConnection & UInt32(menuItem.tag)) > 0
                    let fontAttr = (ready ? attrYes : attrNo)
                    menuItem.attributedTitle = NSAttributedString(string: menuItem.title,
                                                                  attributes: fontAttr)
                    menuItem.state = (menuItem.tag == selectedTag) ? .on : .off
                }
            }
            
            defaults.setValue(true, forKey: Keys.enableAudioConnection)
        } else {
            defaults.setValue(false, forKey: Keys.enableAudioConnection)
        }
        return selectedTag
    }
    
    public func updateVideoStyleMenu(_ menu:NSMenu) {
        // Show unsupported videoStyle menutitle in red color
        let size = NSFont.smallSystemFontSize
        let font = NSFont.menuFont(ofSize: size)
        let attrYes:[NSAttributedString.Key : Any] = [ .font: font ]
        let attrNo:[NSAttributedString.Key : Any] = [ .font: font, .foregroundColor: NSColor.red ]
        
        guard checkReadiness() else { return }
        
        let uint32Value = UInt32(defaults.integer(forKey: Keys.displayMode))
        let displayMode = DLABDisplayMode(rawValue: uint32Value)!
        
        if let settingInfo:[String:Any] = settingInfoFor(displayMode),
           let nativeSize = pixelSizeFrom(settingInfo)
        {
            let width = Int(nativeSize.width)
            let height = Int(nativeSize.height)
            let searchStr = String("\(width):\(height)")
            
            var optionStr:String? = nil
            if nativeSize.equalTo(NSSize(width: 720, height: 486)) {
                optionStr = "525 13.5"
            } else if nativeSize.equalTo(NSSize(width: 720, height: 576)) {
                optionStr = "625 13.5"
            } else if nativeSize.equalTo(NSSize(width: 1440, height: 1080)) {
                optionStr = "HDCAM"
            }
            
            for menuItem in menu.items {
                let title = menuItem.title
                var sameSize = title.contains(searchStr)
                if let optionStr = optionStr {
                    sameSize = sameSize || title.contains(optionStr)
                }
                let fontAttr = (sameSize ? attrYes : attrNo)
                menuItem.attributedTitle = NSAttributedString(string: title,
                                                              attributes: fontAttr)
            }
        }
    }
    
    public func updateFieldDominanceMenu(_ menu:NSMenu) {
        // Show inconsistent fieldMode menutitle in red color
        let size = NSFont.smallSystemFontSize
        let font = NSFont.menuFont(ofSize: size)
        let attrYes:[NSAttributedString.Key : Any] = [ .font: font ]
        let attrNo:[NSAttributedString.Key : Any] = [ .font: font, .foregroundColor: NSColor.red ]
        
        guard checkReadiness() else { return }
        
        let uint32Value = UInt32(defaults.integer(forKey: Keys.displayMode))
        let displayMode = DLABDisplayMode(rawValue: uint32Value)!
        
        if let settingInfo:[String:Any] = settingInfoFor(displayMode),
           let nativeFD = fieldDominanceFrom(settingInfo)
        {
            for menuItem in menu.items {
                // 0:SingleField, 1:BFF, 2:TFF
                let fd = fieldDominanceForTag(menuItem.tag)
                let sameFD = (fd == nativeFD)
                let fontAttr = (sameFD ? attrYes : attrNo)
                menuItem.attributedTitle = NSAttributedString(string: menuItem.title,
                                                              attributes: fontAttr)
            }
        }
    }
    
    public func verifyCompatibility() -> (Bool, Bool, Bool) {
        let displayMode = DLABDisplayMode.init(rawValue: UInt32(defaults.integer(forKey: Keys.displayMode)))
        let vsString:String? = defaults.string(forKey: Keys.videoStyle)
        let clap = NSPoint(x: defaults.integer(forKey: Keys.clapOffsetH),
                           y: defaults.integer(forKey: Keys.clapOffsetV))
        let fd = fieldDominanceForTag(defaults.integer(forKey: Keys.videoFieldDetail))
        if let vsString = vsString {
            let videoStyle = VideoStyle.init(rawValue: vsString)
            if let displayMode = displayMode, let videoStyle = videoStyle {
                let okStyle:Bool = verifyVideoStyleOf(videoStyle, for: displayMode)
                let okClap:Bool = verifyClapOf(clap, for: videoStyle)
                let okFD:Bool = verifyFieldDominanceOf(fd, for: displayMode)
                
                return (okStyle, okClap, okFD)
            }
        }
        return (false, false, false)
    }
    
    public func verifyHDMIAudioChannelLayoutReady() -> Bool {
        let videoConnectionRaw : UInt32 = UInt32(defaults.integer(forKey: Keys.videoConnection))
        let videoConnection = DLABVideoConnection(rawValue: videoConnectionRaw)
        
        let audioConnectionRaw : UInt32 = UInt32(defaults.integer(forKey: Keys.audioConnection))
        let audioConnection = DLABAudioConnection(rawValue: audioConnectionRaw)
        
        let audioChannel : UInt32  = UInt32(defaults.integer(forKey: Keys.audioChannel))
        
        if videoConnection == .HDMI && audioConnection == .embedded {
            if audioChannel == 8 {
                return true
            }
        }
        return false
    }
    
    public func resetStyleCurrent() -> Bool {
        if let settingInfo = settingInfoCurrent() {
            return applyFrom(settingInfo)
        }
        return false
    }
    
    public func checkReadiness() -> Bool {
        let required = (deviceInfo == nil) || (availableSettingInfo == nil)
        if required {
            return queryDevice()
        } else {
            return true
        }
    }
    
    /* ==================================================================================== */
    //MARK: - Private functions
    /* ==================================================================================== */
    
    private func queryDevice() -> Bool {
        // initialize properties
        deviceInfo = nil
        availableSettingInfo = nil
        
        if let manager = manager, let device = manager.currentDevice {
            // deviceInfo
            deviceInfo = manager.deviceInfo(device: device)
            
            // availableModes
            var settingInfoList:[String:Any] = [:]
            if let inputList = manager.inputVideoSettingList(device: device) {
                let expectedDisplayModes = manager.displayModeList()
                for setting in inputList {
                    // Filter out unsupported displayModes
                    if expectedDisplayModes.contains(setting.displayMode) {
                        // Register settingInfo list
                        let name:String = setting.name
                        let settingInfo:[String:Any] = manager.videoSettingInfo(setting: setting)
                        settingInfoList.updateValue(settingInfo, forKey: name)
                    } else {
                        let osTypeValue:UInt32 = setting.displayMode.rawValue
                        let strValue:String = NSFileTypeForHFSTypeCode(osTypeValue)!
                        printVerbose("NOTICE:\(self.className): \(#function) - Skipped DLABDisplayMode: \(setting.name)/\(strValue)")
                    }
                }
            }
            if settingInfoList.count > 0 {
                availableSettingInfo = settingInfoList
            }
        }
        
        if deviceInfo != nil && availableSettingInfo != nil {
            return true
        } else {
            return false
        }
    }
    
    private func displayModeCurrent() -> DLABDisplayMode? {
        let dmValue:UInt32 = UInt32(defaults.integer(forKey: Keys.displayMode))
        if let currentDisplayMode = DLABDisplayMode(rawValue:dmValue) {
            return currentDisplayMode
        } else {
            return nil
        }
    }
    
    private func settingInfoCurrent() -> [String:Any]? {
        if let currentDisplayMode = displayModeCurrent() {
            return settingInfoFor(currentDisplayMode)
        }
        return nil
    }
    
    private func settingInfoFor(_ targetDisplayMode:DLABDisplayMode) -> [String:Any]? {
        if let list:[String:Any] = availableSettingInfo, list.count > 0 {
            for item in list.values {
                let settingInfo = item as! [String:Any]
                let displayMode = displayModeFrom(settingInfo)
                if let displayMode = displayMode, displayMode == targetDisplayMode {
                    return settingInfo
                }
            }
        }
        return nil
    }
    
    private func displayModeFrom(_ settingInfo:[String:Any]) -> DLABDisplayMode? {
        if let strValue = settingInfo["displayMode"] as? String {
            let uint32Value:OSType = NSHFSTypeCodeFromFileType(strValue)
            let displayMode = DLABDisplayMode.init(rawValue: uint32Value)
            return displayMode
        } else {
            return nil
        }
    }
    
    private func fieldDominanceFrom(_ settingInfo:[String:Any]) -> DLABFieldDominance? {
        if let strValue = settingInfo["fieldDominance"] as? String {
            let uint32Value:OSType = NSHFSTypeCodeFromFileType(strValue)
            let fieldDominance = DLABFieldDominance.init(rawValue: uint32Value)
            return fieldDominance
        } else {
            return nil
        }
    }
    
    private func fieldDominanceForTag(_ tag:Int) -> DLABFieldDominance {
        let fdList:[DLABFieldDominance] =
        [.progressiveFrame, .lowerFieldFirst, .upperFieldFirst]
        let fd = fdList[tag]
        return fd
    }
    
    private func pixelSizeFrom(_ settingInfo:[String:Any]) -> NSSize? {
        if let numWidth = settingInfo["width"] as? NSNumber,
           let numHeight = settingInfo["height"] as? NSNumber
        {
            return NSSize(width: numWidth.intValue, height: numHeight.intValue)
        } else {
            return nil
        }
    }
    
    private func videoStyleListFor(_ settingInfo:[String:Any]) -> [VideoStyle]? {
        if let manager = manager, let size = pixelSizeFrom(settingInfo) {
            return manager.videoStyleListOf(size)
        } else {
            return nil
        }
    }
    
    private func verifyVideoStyleOf(_ videoStyle:VideoStyle, for targetDisplayMode:DLABDisplayMode) -> Bool {
        // Size value of videoStyle
        let videoStyleSize:NSSize = videoStyle.encodedSize()
        var displayModeSize:NSSize = NSZeroSize
        
        // Size value of displayMode
        if let settingInfo = settingInfoFor(targetDisplayMode),
           let pixelSize = pixelSizeFrom(settingInfo){
            displayModeSize = pixelSize
        }
        let result:Bool = videoStyleSize.equalTo(displayModeSize)
        return result
    }
    
    private func defaultVideoStyleFrom(_ settingInfo:[String:Any]) -> VideoStyle? {
        if let list = videoStyleListFor(settingInfo), list.count > 0 {
            let defaultStyle = list.first!
            return defaultStyle
        }
        return nil
    }
    
    private func verifyFieldDominanceOf(_ fd:DLABFieldDominance, for targetDisplayMode:DLABDisplayMode) -> Bool {
        if let settingInfo = settingInfoFor(targetDisplayMode) {
            let nativeFD = fieldDominanceFrom(settingInfo)
            return (fd == nativeFD)
        }
        return false
    }
    
    private func verifyClapOf(_ offset:NSPoint, for videoStyle: VideoStyle) -> Bool {
        let encoded = videoStyle.encodedSize()
        let visible = videoStyle.visibleSize()
        let wRange = Int(encoded.width - visible.width) / 2
        let hRange = Int(encoded.height - visible.height) / 2
        
        let offsetHOK = abs(Int(offset.x)) <= wRange
        let offsetVOK = abs(Int(offset.y)) <= hRange
        return (offsetHOK && offsetVOK)
    }
    
    private func defaultClapFor(_ videoStyle:VideoStyle) -> NSPoint {
        let encoded = videoStyle.encodedSize()
        let visible = videoStyle.visibleSize()
        let wRange = Int(encoded.width - visible.width) / 2
        let hRange = Int(encoded.height - visible.height) / 2
        
        // clamp offsetH, offsetV to maximum clap rect
        var offsetH:Int = defaults.integer(forKey: Keys.clapOffsetH)
        var offsetV:Int = defaults.integer(forKey: Keys.clapOffsetV)
        offsetH = min(max(-wRange, offsetH), wRange)
        offsetV = min(max(-hRange, offsetV), hRange)
        let newClap = NSPoint(x: offsetH, y: offsetV)
        return newClap
    }
    
    private func applyFrom(_ settingInfo:[String:Any]) -> Bool {
        var success:Bool = true
        
        var newDisplayMode:DLABDisplayMode = .modeNTSC
        if success, let valueFromSettingInfo = displayModeFrom(settingInfo) {
            newDisplayMode = valueFromSettingInfo
        } else {
            success = false
        }
        
        var newFieldDetail:Int = 0 // 0:SingleField, 1:BFF, 2:TFF
        if success, let valueFromSettingInfo = fieldDominanceFrom(settingInfo) {
            switch valueFromSettingInfo {
            case DLABFieldDominance.progressiveFrame:
                newFieldDetail = 0
            case DLABFieldDominance.lowerFieldFirst:
                newFieldDetail = 1
            case DLABFieldDominance.upperFieldFirst:
                newFieldDetail = 2
            default:
                success = false
            }
        }
        
        var newVideoStyle:VideoStyle? = nil
        if success, let defaultVideoStyle = defaultVideoStyleFrom(settingInfo) {
            newVideoStyle = defaultVideoStyle
        } else {
            success = false
        }
        
        var newOffset:NSPoint = NSZeroPoint
        if success, let newVideoStyle = newVideoStyle {
            // Clamp into supported clap offset rect
            newOffset = defaultClapFor(newVideoStyle)
            
            // update userDefaults
            defaults.set(newDisplayMode.rawValue, forKey: Keys.displayMode)
            defaults.set(newFieldDetail, forKey: Keys.videoFieldDetail)
            defaults.set(newVideoStyle.rawValue, forKey: Keys.videoStyle)
            defaults.set(newOffset.x, forKey: Keys.clapOffsetH)
            defaults.set(newOffset.y, forKey: Keys.clapOffsetV)
        } else {
            success = false
        }
        
        return success
    }
    
    /* ==================================================================================== */
    //MARK: -
    /* ==================================================================================== */
}
