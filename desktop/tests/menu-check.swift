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
let colour=originalMenu.items.first(where:{$0.title=="Colour"})!.submenu!
assert(originalMenu.delegate === delegate && colour.delegate === delegate)
assert(colour.items.first(where:{$0.representedObject as? String == "white"})!.state == .on)
defaults.setVolatileDomain(["ghostColour":"lavender"],forName:UserDefaults.argumentDomain)
delegate.createMenu()
assert(delegate.statusItem === originalStatus && delegate.statusItem.menu === originalMenu)
assert(app.mainMenu === originalMain)
for menu in [colour,originalMain.items.first!.submenu!.items.first(where:{$0.title=="Colour"})!.submenu!] {
 assert(menu.items.first(where:{$0.representedObject as? String == "lavender"})!.state == .on)
 assert(menu.items.first(where:{$0.representedObject as? String == "white"})!.state == .off)
 assert(menu.item(withTag:917)!.action == nil)
}
delegate.startMouseTracking()
assert(delegate.mouseMonitors.count==2)
delegate.menuWillOpen(originalMenu);delegate.menuWillOpen(colour)
assert(delegate.mouseMonitors.isEmpty,"AppKit menu tracking has no companion event monitors")
assert(delegate.trackingMenus.count==2)
defaults.setVolatileDomain(["ghostColour":"white"],forName:UserDefaults.argumentDomain)
delegate.menuNeedsUpdate(colour)
assert(colour.items.first(where:{$0.representedObject as? String == "lavender"})!.state == .on,"Tracking must not rewrite the open menu")
delegate.menuDidClose(colour);assert(delegate.trackingMenus.count==1)
delegate.menuDidClose(originalMenu);assert(delegate.trackingMenus.isEmpty)
assert(colour.items.first(where:{$0.representedObject as? String == "white"})!.state == .on,"Deferred updates apply after tracking ends")
for item in originalMenu.items where item.action != nil { assert(item.target === delegate) }
RunLoop.main.run(until:Date().addingTimeInterval(0.1))
assert(delegate.mouseMonitors.count==2,"Mouse tracking resumes after dismissal")
delegate.stopMouseTracking()

assert(originalMenu.items.contains(where:{$0.action == #selector(AppDelegate.showSettings)}))
let dock=delegate.applicationDockMenu(app)!
assert(dock.delegate === delegate && dock.items.count==2)
var dockChange:Bool?,loginClicks=0,sizeClicks=0,chosenColour=""
let settings=MnemoSettingsController(actions:.init(dock:{dockChange=$0},login:{loginClicks+=1},size:{sizeClicks+=1},colour:{chosenColour=$0},loginSettings:{},refresh:{}))
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
settings.close()
NSStatusBar.system.removeStatusItem(originalStatus)
print("PASS: native menu identity survives colour changes; both menus update checkmarks; nested tracking remains active until all menus close; action targets are intact.")

print("PASS: native Settings actions, Dock preference display, login approval/busy states, appearance bindings and Dock-menu entry points.")

let displays=[CGRect(x:0,y:0,width:1440,height:900),CGRect(x:-1920,y:120,width:1920,height:1080)]
assert(AppDelegate.nearestArea(to:NSPoint(x:-500,y:500),areas:displays)==displays[1])
assert(AppDelegate.nearestArea(to:NSPoint(x:1700,y:500),areas:displays)==displays[0])
assert(AppDelegate.nearestArea(to:.zero,areas:[])==nil)
assert(AppDelegate.nearestArea(to:NSPoint(x:0,y:1600),areas:[CGRect(x:0,y:900,width:1440,height:900)])?.minY==900)
print("Display selection checks passed")

let companionBehavior=CompanionPanel.companionBehavior
assert(companionBehavior.contains(.stationary),"Companion remains visible in Mission Control")
assert(companionBehavior.contains(.canJoinAllSpaces) && companionBehavior.contains(.fullScreenAuxiliary))
assert(companionBehavior.contains(.ignoresCycle) && !companionBehavior.contains(.transient) && !companionBehavior.contains(.managed))
print("PASS: companion Mission Control and Spaces policy")
