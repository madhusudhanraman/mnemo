import Cocoa

func mnemoMenuIcon() -> NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 20), flipped: false) { _ in
        let sheet = NSBezierPath()
        sheet.move(to: NSPoint(x: 3, y: 3))
        sheet.line(to: NSPoint(x: 3, y: 11))
        sheet.curve(to: NSPoint(x: 9, y: 18), controlPoint1: NSPoint(x: 3, y: 15.6), controlPoint2: NSPoint(x: 5.4, y: 18))
        sheet.curve(to: NSPoint(x: 15, y: 11), controlPoint1: NSPoint(x: 12.6, y: 18), controlPoint2: NSPoint(x: 15, y: 15.6))
        sheet.line(to: NSPoint(x: 15, y: 3))
        sheet.curve(to: NSPoint(x: 11, y: 3.4), controlPoint1: NSPoint(x: 13.7, y: 1.1), controlPoint2: NSPoint(x: 12.7, y: 5.2))
        sheet.curve(to: NSPoint(x: 7, y: 3.2), controlPoint1: NSPoint(x: 9.8, y: 1.7), controlPoint2: NSPoint(x: 8.6, y: 1.7))
        sheet.curve(to: NSPoint(x: 3, y: 3), controlPoint1: NSPoint(x: 5.4, y: 5), controlPoint2: NSPoint(x: 4.2, y: 1.2))
        sheet.close()
        sheet.windingRule = .evenOdd
        sheet.appendOval(in: NSRect(x: 5.7, y: 9.3, width: 2.3, height: 3.6))
        sheet.appendOval(in: NSRect(x: 10, y: 9.3, width: 2.3, height: 3.6))
        NSColor.black.setFill(); sheet.fill()
        return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Mnemo"
    return image
}
