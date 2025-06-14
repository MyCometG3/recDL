//
//  RDL1ScriptableObject.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2025/06/14.
//  Copyright © 2025 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa
@preconcurrency import DLABridging

@objcMembers
@MainActor
class RDL1ScriptableObject: NSObject {
    /* ============================================================================== */
    
    weak var container :NSObject! = NSApp
    var containerProperty :String = "OverwriteMe"
    
    /* ============================================================================== */
    
    private struct ObjectSpecifierBox: @unchecked Sendable {
        let specifier: NSScriptObjectSpecifier?
    }
    
    override nonisolated var objectSpecifier: NSScriptObjectSpecifier? {
        let block: () -> ObjectSpecifierBox = {
            return MainActor.assumeIsolated {
                return self.objectSpecifierCore()
            }
        }
        if Thread.isMainThread {
            return block().specifier
        } else {
            return DispatchQueue.main.sync {
                return block().specifier
            }
        }
    }
    
    private func objectSpecifierCore() -> ObjectSpecifierBox{
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
        return ObjectSpecifierBox(specifier: specifier)
    }
}
