//
//  CustomCommand.swift
//  recDL
//
//  Created by Takashi Mochizuki on 2017/10/28.
//  Copyright © 2017-2024 MyCometG3. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

import Cocoa

@objcMembers
class CustomCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        // print("\(#file) \(#line) \(#function)")
        
        // Unhandled command detected
        let errorMsg = "ERROR: CustomCommand: Internal error is detected."
        
        print(errorMsg)
        print("- Command description: \(self.commandDescription)")
        if let directParameter = self.directParameter {
            print("- Direct parameter: \(directParameter)")
        }
        if let arguments = self.evaluatedArguments {
            print("- Evaluated arguments: \(arguments)")
        }
        
        return errorMsg
    }
}
