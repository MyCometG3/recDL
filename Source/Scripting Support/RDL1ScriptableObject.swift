//
//  RDL1ScriptableObject.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2025/06/14.
//  Copyright © 2026 MyCometG3. All rights reserved.
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
        if Thread.isMainThread {
            MainActor.preconditionIsolated()
            return MainActor.assumeIsolated {
                return self.objectSpecifierCore()
            }.specifier
        } else {
            return DispatchQueue.main.sync {
                return MainActor.assumeIsolated {
                    return self.objectSpecifierCore()
                }.specifier
            }
        }
    }
    
    private func objectSpecifierCore() -> ObjectSpecifierBox {
        // `classDescription` is declared non-optional in the AppKit
        // bridge but the actual returned object must be an
        // NSScriptClassDescription to build a property specifier.
        // Force-casting (`as!`) would crash if the container's class
        // description were ever something else (e.g. an sdef mismatch
        // during scripting reload). Fall back to a nil specifier in
        // that defensive path so the failure surfaces as a "no
        // object specifier" to the scripting runtime rather than a
        // hard crash.
        guard let desc = container.classDescription as? NSScriptClassDescription else {
            return ObjectSpecifierBox(specifier: nil)
        }
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
