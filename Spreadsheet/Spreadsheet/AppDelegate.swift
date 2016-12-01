import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var controller : SheetWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        controller = SheetWindowController(windowNibName: "Sheet")
        controller?.showWindow(self)
    }
}
