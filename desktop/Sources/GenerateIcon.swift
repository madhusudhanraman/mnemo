import Cocoa
let output=CommandLine.arguments[1]
let image=NSImage(size:NSSize(width:1024,height:1024))
image.lockFocus()
let tile=NSBezierPath(roundedRect:NSRect(x:86,y:86,width:852,height:852),xRadius:192,yRadius:192)
NSGradient(starting:NSColor(calibratedRed:0.32,green:0.25,blue:0.45,alpha:1),ending:NSColor(calibratedRed:0.13,green:0.11,blue:0.20,alpha:1))!.draw(in:tile,angle:-90)
let ghost=NSBezierPath()
ghost.move(to:NSPoint(x:286,y:300))
ghost.curve(to:NSPoint(x:300,y:575),controlPoint1:NSPoint(x:307,y:415),controlPoint2:NSPoint(x:290,y:490))
ghost.curve(to:NSPoint(x:512,y:790),controlPoint1:NSPoint(x:300,y:710),controlPoint2:NSPoint(x:390,y:790))
ghost.curve(to:NSPoint(x:724,y:575),controlPoint1:NSPoint(x:634,y:790),controlPoint2:NSPoint(x:724,y:710))
ghost.curve(to:NSPoint(x:754,y:292),controlPoint1:NSPoint(x:720,y:465),controlPoint2:NSPoint(x:738,y:360))
ghost.curve(to:NSPoint(x:630,y:300),controlPoint1:NSPoint(x:708,y:324),controlPoint2:NSPoint(x:690,y:324))
ghost.curve(to:NSPoint(x:504,y:270),controlPoint1:NSPoint(x:576,y:276),controlPoint2:NSPoint(x:568,y:250))
ghost.curve(to:NSPoint(x:380,y:293),controlPoint1:NSPoint(x:444,y:294),controlPoint2:NSPoint(x:440,y:313))
ghost.curve(to:NSPoint(x:286,y:300),controlPoint1:NSPoint(x:322,y:274),controlPoint2:NSPoint(x:312,y:268));ghost.close()
NSGraphicsContext.saveGraphicsState()
let shadow=NSShadow();shadow.shadowOffset=NSSize(width:0,height:-14);shadow.shadowBlurRadius=28;shadow.shadowColor=NSColor.black.withAlphaComponent(0.3);shadow.set()
NSColor.white.setFill();ghost.fill();NSGraphicsContext.restoreGraphicsState()
NSGradient(starting:NSColor(calibratedRed:0.99,green:0.97,blue:1,alpha:1),ending:NSColor(calibratedRed:0.75,green:0.70,blue:0.84,alpha:1))!.draw(in:ghost,angle:-65)
for x in [425.0,565.0] {
 NSColor(calibratedRed:0.12,green:0.09,blue:0.19,alpha:1).setFill();NSBezierPath(ovalIn:NSRect(x:x,y:548,width:55,height:89)).fill()
 NSColor.white.withAlphaComponent(0.95).setFill();NSBezierPath(ovalIn:NSRect(x:x+12,y:600,width:12,height:20)).fill()
}
image.unlockFocus()
let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output))
