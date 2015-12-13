//
//  AppDelegate.swift
//  Spreadsheet
//
//  Created by Chris Eidhof on 01.07.14.
//  Copyright (c) 2014 Unsigned Integer. All rights reserved.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    var controller : SheetWindowController?


    func applicationDidFinishLaunching(aNotification: NSNotification) {
        controller = SheetWindowController(windowNibName: "Sheet")
        controller?.showWindow(self)
    }
    
}




