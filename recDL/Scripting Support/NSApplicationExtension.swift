//
//  NSApplicationExtension.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/10/28.
//  Copyright © 2017-2023 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa

@objc
extension NSApplication {
    public func handleRestartSession(_ command: NSScriptCommand) {
        // print("\(#file) \(#line) \(#function)")
        
        // Post notification without userInfo
        let notification = Notification(name: .handleRestartSessionKey,
                                        object: self,
                                        userInfo: nil)
        NotificationCenter.default.post(notification)
    }
    
    public func handleStopRecord(_ command: NSScriptCommand) {
        // print("\(#file) \(#line) \(#function)")
        
        // Post notification without userInfo
        let notification = Notification(name: .handleStopRecordingKey,
                                        object: self,
                                        userInfo: nil)
        NotificationCenter.default.post(notification)
    }
    
    public func handleStartRecord(_ command: NSScriptCommand) {
        // print("\(#file) \(#line) \(#function)")
        
        let fileURL: URL? = command.evaluatedArguments?[Keys.fileURL] as? URL
        let maxSeconds: Float? = command.evaluatedArguments?[Keys.maxSeconds] as? Float
        let autoQuit: Bool? = command.evaluatedArguments?[Keys.autoQuit] as? Bool
        
        // Post notification with userInfo
        let userInfo : [String:Any] = [
            Keys.fileURL : fileURL as Any,
            Keys.maxSeconds : maxSeconds as Any,
            Keys.autoQuit : autoQuit as Any
        ]
        let notification = Notification(name: .handleStartRecordingKey,
                                        object: self,
                                        userInfo: userInfo)
        NotificationCenter.default.post(notification)
    }
}
