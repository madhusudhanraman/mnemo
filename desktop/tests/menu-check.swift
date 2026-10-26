// AppKit checks run against the production delegate, without launching its reminder UI.
let app=NSApplication.shared
let delegate=AppDelegate()
let defaults=UserDefaults.standard
let previous=defaults.volatileDomain(forName:UserDefaults.argumentDomain)
defer { defaults.setVolatileDomain(previous,forName:UserDefaults.argumentDomain) }
defaults.setVolatileDomain(["ghostColour":"white"],forName:UserDefaults.argumentDomain)
delegate.createMenu()
let originalStatus=delegate.statusItem!,originalMenu=delegate.statusItem.menu!
let originalMain=app.mainMenu!
assert(originalMenu.delegate === delegate)
assert(originalMenu.items.filter({!$0.isSeparatorItem}).map(\.title) == ["Open Mnemo…","Settings…","Show / hide ghost","Pause / resume motion","Quit Mnemo"])
assert(originalMain.items.first!.submenu!.items.filter({!$0.isSeparatorItem}).map(\.title) == ["Settings…","Quit Mnemo"])
let editMenu=originalMain.items.first(where:{$0.title=="Edit"})!.submenu!
let editActions=editMenu.items.filter{!$0.isSeparatorItem}
assert(editActions.map(\.keyEquivalent)==["z","z","x","c","v","a"])
assert(editActions.map{NSStringFromSelector($0.action!)}==["undo:","redo:","cut:","copy:","paste:","selectAll:"])
assert(editActions.allSatisfy{$0.target==nil},"Edit actions use the focused responder")
assert(editActions[1].keyEquivalentModifierMask == [.command,.shift])
delegate.createMenu()
assert(delegate.statusItem === originalStatus && delegate.statusItem.menu === originalMenu)
assert(app.mainMenu === originalMain)
let nested=NSMenu();delegate.observeMenu(nested)
delegate.startMouseTracking()
assert(delegate.mouseMonitors.count==2)
delegate.menuWillOpen(originalMenu);delegate.menuWillOpen(nested)
assert(delegate.mouseMonitors.isEmpty,"AppKit menu tracking has no companion event monitors")
assert(delegate.trackingMenus.count==2)
defaults.setVolatileDomain(["ghostColour":"white"],forName:UserDefaults.argumentDomain)
delegate.menuNeedsUpdate(nested)
delegate.menuDidClose(nested);assert(delegate.trackingMenus.count==1)
delegate.menuDidClose(originalMenu);assert(delegate.trackingMenus.isEmpty)
for item in originalMenu.items where item.action != nil { assert(item.target === delegate) }
RunLoop.main.run(until:Date().addingTimeInterval(0.1))
assert(delegate.mouseMonitors.count==2,"Mouse tracking resumes after dismissal")
delegate.stopMouseTracking()

assert(originalMenu.items.contains(where:{$0.action == #selector(AppDelegate.showSettings)}))
let dock=delegate.applicationDockMenu(app)!
assert(dock.delegate === delegate && dock.items.count==2)
var dockChange:Bool?,loginClicks=0,sizeClicks=0,chosenColour="",chosenLocation=""
let settings=MnemoSettingsController(actions:.init(dock:{dockChange=$0},login:{loginClicks+=1},size:{sizeClicks+=1},colour:{chosenColour=$0},loginSettings:{},refresh:{},location:{chosenLocation=$0}))
settings.update(showDock:true,login:.requiresApproval,busy:false,message:nil,error:nil,installed:true,colour:"white")
assert(settings.dockToggle.state == .on && settings.loginToggle.state == .mixed)
assert(!settings.loginSettingsButton.isHidden && !settings.loginStatus.isHidden)
settings.dockToggle.performClick(nil);assert(dockChange == false)
settings.loginToggle.performClick(nil);assert(loginClicks==1)
settings.sizeButton.performClick(nil);assert(sizeClicks==1)
settings.colourPicker.selectItem(at:2)
app.sendAction(settings.colourPicker.action!,to:settings.colourPicker.target,from:settings.colourPicker)
assert(chosenColour=="lavender")
settings.update(showDock:false,login:.enabled,busy:true,message:nil,error:nil,installed:true,colour:"auto")
assert(settings.dockToggle.state == .off && !settings.loginToggle.isEnabled)
settings.update(showDock:true,login:.enabled,busy:false,message:nil,error:nil,installed:true,colour:"white")
assert(settings.loginToggle.isEnabled && settings.loginStatus.isHidden && settings.loginSettingsButton.isHidden)
settings.updateLocation("Work");assert(settings.locationPicker.selectedItem?.representedObject as? String == "Work")
settings.locationPicker.selectItem(at:0);app.sendAction(settings.locationPicker.action!,to:settings.locationPicker.target,from:settings.locationPicker)
assert(chosenLocation=="Home")
settings.close()
NSStatusBar.system.removeStatusItem(originalStatus)
print("PASS: compact menus contain quick actions only; menu identity is stable; nested tracking remains active until all menus close; action targets are intact.")

print("PASS: native Settings actions, Dock preference display, login approval/busy states, appearance bindings and Dock-menu entry points.")

let displays=[CGRect(x:0,y:0,width:1440,height:900),CGRect(x:-1920,y:120,width:1920,height:1080)]
assert(AppDelegate.nearestArea(to:NSPoint(x:-500,y:500),areas:displays)==displays[1])
assert(AppDelegate.nearestArea(to:NSPoint(x:1700,y:500),areas:displays)==displays[0])
assert(AppDelegate.nearestArea(to:.zero,areas:[])==nil)
assert(AppDelegate.nearestArea(to:NSPoint(x:0,y:1600),areas:[CGRect(x:0,y:900,width:1440,height:900)])?.minY==900)
print("Display selection checks passed")

let canvas=NSSize(width:840,height:760)
let edgeBody=CGRect(x:1400,y:-100,width:128,height:150)
assert(AppDelegate.safeCompanionOrigin(NSPoint(x:1044,y:-350),size:canvas,area:displays[0],body:edgeBody) == NSPoint(x:936,y:-230))
let insideBody=CGRect(x:400,y:200,width:128,height:150)
assert(AppDelegate.safeCompanionOrigin(NSPoint(x:44,y:-50),size:canvas,area:displays[0],body:insideBody) == NSPoint(x:44,y:-50))
print("PASS: movement bounds constrain the body rather than transparent tile space")

let companionBehavior=CompanionPanel.companionBehavior
assert(companionBehavior.contains(.stationary),"Companion remains visible in Mission Control")
assert(companionBehavior.contains(.canJoinAllSpaces) && companionBehavior.contains(.fullScreenAuxiliary))
assert(companionBehavior.contains(.ignoresCycle) && !companionBehavior.contains(.transient) && !companionBehavior.contains(.managed))
print("PASS: companion Mission Control and Spaces policy")

let grabStart=NSPoint(x:500,y:400),windowStart=NSPoint(x:100,y:200)
assert(AppDelegate.dragOrigin(start:windowStart,pointerStart:grabStart,pointer:NSPoint(x:850,y:700)) == NSPoint(x:450,y:500))
assert(AppDelegate.dragOrigin(start:windowStart,pointerStart:grabStart,pointer:grabStart) == windowStart)
print("PASS: native drag retains original grab offset without accumulating event deltas")

let highBody=CGRect(x:400,y:850,width:128,height:150)
let highOrigin=AppDelegate.safeCompanionOrigin(NSPoint(x:44,y:600),size:canvas,area:displays[0],body:highBody)
assert(highBody.maxY+highOrigin.y-600 == displays[0].maxY,"Crown can reach the menu bar boundary")

assert(SpotifyPlayback.Command.previous.eventID == "Prev")
assert(SpotifyPlayback.Command.next.eventID == "Next")
assert(SpotifyPlayback.Command.toggle.eventID == "PlPs")
assert(SpotifyPlayback.Command(rawValue:"unexpected") == nil)

// A pause acknowledgement can precede Spotify's playing -> paused transition.
// Both observations must retain metadata so the Play control stays visible.
assert(SpotifyPlayback.hasCurrentTrack(SpotifyPlayback.code("kPSP")))
assert(SpotifyPlayback.hasCurrentTrack(SpotifyPlayback.code("kPSp")))
assert(!SpotifyPlayback.hasCurrentTrack(SpotifyPlayback.code("kPSS")))
print("PASS: track remains available throughout a delayed pause transition")
