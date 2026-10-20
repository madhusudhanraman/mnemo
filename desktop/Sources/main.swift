import Cocoa
import WebKit
import UserNotifications

// The transparent canvas may extend offscreen while the companion remains visible.
final class CompanionWebView: WKWebView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class CompanionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

final class Bridge: NSObject, WKScriptMessageHandler {
    weak var owner: AppDelegate?
    let mode: String
    init(owner: AppDelegate, mode: String) { self.owner = owner; self.mode = mode }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let method = body["method"] as? String else { return }
        owner?.handle(method: method, body: body, web: message.webView, mode: mode)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    let backgroundColour = BackgroundColour()
    var colourTicks = 0
    var nextColourSample=Date.distantPast
    var colourInterval=5.0
    var priorLuminance: Double?
    var sampledOrigin: NSPoint?
    var screenAsleep=false, sessionInactive=false
    var lastSentColour: Bool?
    var store: ReminderStore!
    var ghost: NSPanel!
    var ghostWeb: WKWebView!
    var manager: NSWindow?
    var managerWeb: WKWebView?
    var sizesWindow: NSWindow?
    var sizesWeb: WKWebView?
    var statusItem: NSStatusItem!
    var timer: Timer?
    var observers: [Any] = []
    var hitRegions: [CGRect] = []
    var pointerIsOverCompanion: Bool?
    var lastSentSystemActive: Bool?
    let testMode = CommandLine.arguments.contains("--test")
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let root = testMode ? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Mnemo-test-\(ProcessInfo.processInfo.processIdentifier)") : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Mnemo")
            store = try ReminderStore(url: root.appendingPathComponent("reminders.json"))
            // Cancel alerts scheduled by older builds; reminders now use thought bubbles only.
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            createMenu(); createGhost(); checkDue()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.checkDue(); self?.updateColour(); self?.updateSystemActivity() }
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
            let workspace=NSWorkspace.shared.notificationCenter
            for name in [NSWorkspace.screensDidSleepNotification,NSWorkspace.screensDidWakeNotification,NSWorkspace.sessionDidResignActiveNotification,NSWorkspace.sessionDidBecomeActiveNotification] {
                observers.append(workspace.addObserver(forName:name,object:nil,queue:.main) { [weak self] event in
                    guard let self=self else { return }
                    if event.name == NSWorkspace.screensDidSleepNotification { self.screenAsleep=true }
                    if event.name == NSWorkspace.screensDidWakeNotification { self.screenAsleep=false }
                    if event.name == NSWorkspace.sessionDidResignActiveNotification { self.sessionInactive=true }
                    if event.name == NSWorkspace.sessionDidBecomeActiveNotification { self.sessionInactive=false }
                    self.sendVisibility();if !self.screenAsleep && !self.sessionInactive { self.nextColourSample = .distantPast;self.checkDue() }
                })
            }
            observers.append(workspace.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main) { [weak self] _ in self?.nextColourSample = .distantPast;self?.colourInterval=5 })
            for local in [true, false] {
                if local {
                    let token = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in self?.updateClickThrough(); return event }
                    if let token = token { observers.append(token) }
                } else if let token = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { [weak self] _ in self?.updateClickThrough() }) { observers.append(token) }
            }
        } catch { showError(error.localizedDescription); NSApp.terminate(nil) }
    }
    // Aggregate idle time only: no event tap, key contents or input permission.
    func systemIsActive() -> Bool {
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
        return idle.isFinite && idle >= 0 && idle < 60
    }
    func updateSystemActivity() {
        guard ghost.isVisible && !screenAsleep && !sessionInactive else { lastSentSystemActive=nil; return }
        let active=systemIsActive()
        guard lastSentSystemActive != active else { return }
        lastSentSystemActive=active
        ghostWeb.evaluateJavaScript("window.dispatchEvent(new CustomEvent('mnemo-system-activity',{detail:\(active ? "true" : "false")}))",completionHandler:nil)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView === ghostWeb { lastSentSystemActive=nil;updateSystemActivity();sendVisibility() }
    }
    // Optional rendering overrides for performance experiments, e.g. `defaults write local.mnemo.companion debugIdleFPS -float 12`.
    func debugRendering() -> String {
        var values: [String: Double] = [:]
        for (key, name, range) in [("debugIdleFPS", "idleFPS", 1.0...60), ("debugSleepyFPS", "sleepyFPS", 1.0...60), ("debugPixelRatio", "pixelRatio", 0.5...2)] {
            if let value = UserDefaults.standard.object(forKey: key) as? Double, range.contains(value) { values[name] = value }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: values), let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }
    func makeWeb(mode: String, resource: String = "ghost") -> WKWebView {
        let controller = WKUserContentController(); controller.add(Bridge(owner: self, mode: mode), name: "mnemo")
        let script = """
        (()=>{let next=0;const pending=new Map();window.mnemoNativeReply=reply=>{const p=pending.get(reply.id);if(!p)return;pending.delete(reply.id);reply.error?p.reject(new Error(reply.error)):p.resolve(reply.result)};
        const call=(method,payload={})=>new Promise((resolve,reject)=>{const id=++next;pending.set(id,{resolve,reject});window.webkit.messageHandlers.mnemo.postMessage({id,method,payload})});
        const send=(method,payload={})=>window.webkit.messageHandlers.mnemo.postMessage({method,payload});
        window.mnemoDesktop={mode:'\(mode)',systemActive:\(systemIsActive() ? "true" : "false"),preferredHeight:\(UserDefaults.standard.integer(forKey:"ghostVisibleHeight")),debug:\(debugRendering()),setSize:height=>send('setSize',{height}),list:()=>call('list'),save:item=>call('save',item),action:item=>call('action',item),manage:()=>send('manage'),closeManager:()=>send('closeManager'),moveBy:delta=>send('moveBy',delta),hitRegions:regions=>send('hitRegions',{regions})};
        window.addEventListener('error',e=>send('scriptError',{message:e.message}));
        })();
        """
        controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let config = WKWebViewConfiguration(); config.userContentController = controller
        let web = CompanionWebView(frame: .zero, configuration: config)
        web.focusRingType = .none
        web.setValue(false, forKey: "drawsBackground"); web.underPageBackgroundColor = .clear; web.navigationDelegate = self
        web.autoresizingMask = [.width, .height]
        if let url = Bundle.main.url(forResource: resource, withExtension: "html") { web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent()) }
        return web
    }
    func createGhost() {
        let area = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var origin=NSPoint(x:area.maxX-360,y:area.minY+30)
        if let saved=UserDefaults.standard.dictionary(forKey:"ghostRestingPosition"),let x=saved["x"] as? Double,let y=saved["y"] as? Double,x.isFinite,y.isFinite {
            let candidate=NSRect(x:x,y:y,width:320,height:440)
            if NSScreen.screens.contains(where:{$0.visibleFrame.intersects(candidate)}) { origin=NSPoint(x:x,y:y) }
        }
        origin=boundedOrigin(origin,size:NSSize(width:320,height:440))
        ghost = CompanionPanel(contentRect: NSRect(origin:origin,size:NSSize(width:320,height:440)), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        ghost.title = "Mnemo companion"; ghost.isOpaque = false; ghost.backgroundColor = .clear; ghost.hasShadow = false
        ghost.level = .floating; ghost.hidesOnDeactivate = false; ghost.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ghost.isReleasedWhenClosed = false; ghost.acceptsMouseMovedEvents = true
        ghostWeb = makeWeb(mode: "companion"); ghost.contentView = ghostWeb
        ghost.orderFrontRegardless()
    }
    @objc func showManager() {
        if manager == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 720), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Mnemo · Reminders"; window.minSize = NSSize(width: 400, height: 550); window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(red: 0.14, green: 0.13, blue: 0.19, alpha: 1)
            managerWeb = makeWeb(mode: "manager",resource:"editor"); window.contentView = managerWeb; window.center(); manager = window
        }
        NSApp.activate(ignoringOtherApps: true); manager?.makeKeyAndOrderFront(nil)
    }
    @objc func showSizes() {
        if sizesWindow == nil {
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:720,height:440),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
            window.title="Mnemo · Size";window.isReleasedWhenClosed=false
            window.backgroundColor=NSColor(red:0.14,green:0.13,blue:0.19,alpha:1)
            sizesWeb=makeWeb(mode:"sizes",resource:"sizes");window.contentView=sizesWeb;window.center();sizesWindow=window
        }
        NSApp.activate(ignoringOtherApps:true);sizesWindow?.makeKeyAndOrderFront(nil)
    }
    func createMenu() {
        if let previous=statusItem { NSStatusBar.system.removeStatusItem(previous) }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image=mnemoMenuIcon();statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.setAccessibilityLabel("Mnemo reminders");statusItem.button?.toolTip = "Mnemo · your reminder companion"
        let menu = NSMenu()
        menu.addItem(withTitle: "My reminders…", action: #selector(showManager), keyEquivalent: "r")
        menu.addItem(withTitle:"Size…",action:#selector(showSizes),keyEquivalent:"")
        let colourItem=NSMenuItem(title:"Colour",action:nil,keyEquivalent:"");colourItem.submenu=colourMenu();menu.addItem(colourItem)
        menu.addItem(withTitle: "Show / hide ghost", action: #selector(toggleGhost), keyEquivalent: "")
        menu.addItem(withTitle: "Pause / resume motion", action: #selector(toggleMotion), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Mnemo", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }; statusItem.menu = menu
        let mainMenu=NSMenu(),applicationMenu=NSMenu(),applicationItem=NSMenuItem()
        let quitItem=NSMenuItem(title:"Quit Mnemo",action:#selector(quit),keyEquivalent:"q");quitItem.target=self
        let sizeItem=NSMenuItem(title:"Size…",action:#selector(showSizes),keyEquivalent:"");sizeItem.target=self;applicationMenu.addItem(sizeItem);let colourMain=NSMenuItem(title:"Colour",action:nil,keyEquivalent:"");colourMain.submenu=colourMenu();applicationMenu.addItem(colourMain);applicationMenu.addItem(.separator());applicationMenu.addItem(quitItem);applicationItem.submenu=applicationMenu;mainMenu.addItem(applicationItem);NSApp.mainMenu=mainMenu
    }
    func colourMenu() -> NSMenu {
        let menu=NSMenu()
        for (title,mode) in [("Auto","auto"),("White","white"),("Lavender","lavender")] {
            let item=NSMenuItem(title:title,action:#selector(chooseColour(_:)),keyEquivalent:"")
            item.target=self;item.representedObject=mode
            item.state=(UserDefaults.standard.string(forKey:"ghostColour") ?? "white")==mode ? .on : .off
            menu.addItem(item)
        }
        let status=NSMenuItem(title:backgroundColour.status,action:nil,keyEquivalent:"");status.tag=917;menu.addItem(.separator());menu.addItem(status)
        return menu
    }
    @objc func chooseColour(_ sender:NSMenuItem) {
        guard let mode=sender.representedObject as? String else { return }
        if mode == "auto" {
            guard #available(macOS 14.0, *) else {
                let alert=NSAlert();alert.messageText="Auto colour needs macOS 14 or later.";alert.runModal();return
            }
            if !CGPreflightScreenCaptureAccess() { _ = CGRequestScreenCaptureAccess() }
            if !CGPreflightScreenCaptureAccess() {
                let alert=NSAlert();alert.messageText="Allow Screen Recording for Mnemo";alert.informativeText="Enable Mnemo in System Settings → Privacy & Security → Screen Recording, then restart Mnemo. Background samples are never saved or sent.";alert.runModal()
            }
        }
        UserDefaults.standard.set(mode,forKey:"ghostColour")
        createMenu();colourTicks=0;nextColourSample = .distantPast;colourInterval=5;updateColour()
    }
    func sendColour(_ dark:Bool) {
        guard lastSentColour != dark else { return };lastSentColour=dark
        ghostWeb?.evaluateJavaScript("window.dispatchEvent(new CustomEvent('mnemo-colour',{detail:\(dark ? "true" : "false")}))",completionHandler:nil)
    }
    func updateColour() {
        for parent in (statusItem?.menu?.items ?? []) + (NSApp.mainMenu?.items.first?.submenu?.items ?? []) {
            parent.submenu?.item(withTag:917)?.title=backgroundColour.status
        }
        let mode=UserDefaults.standard.string(forKey:"ghostColour") ?? "white"
        if mode != "auto" { sendColour(mode == "lavender");return }
        guard !screenAsleep,!sessionInactive,ghost.isVisible,let body=hitRegions.first else { return }
        let origin=ghost.frame.origin
        if let previous=sampledOrigin,hypot(origin.x-previous.x,origin.y-previous.y)>3 { nextColourSample = .distantPast;colourInterval=5 }
        guard Date()>=nextColourSample,!backgroundColour.busy else { return }
        sampledOrigin=origin;nextColourSample=Date().addingTimeInterval(colourInterval)
        backgroundColour.sample(window:ghost,body:body) { [weak self] dark in
            guard UserDefaults.standard.string(forKey:"ghostColour") == "auto" else { return }
            guard let self=self else { return }
            if let value=self.backgroundColour.luminance,let prior=self.priorLuminance,abs(value-prior)<0.04 { self.colourInterval=min(20,self.colourInterval*1.6) } else { self.colourInterval=5 }
            self.priorLuminance=self.backgroundColour.luminance;self.nextColourSample=Date().addingTimeInterval(self.colourInterval)
            self.sendColour(dark)
        }
    }
    func sendVisibility() { let visible=ghost.isVisible && !screenAsleep && !sessionInactive;ghostWeb.evaluateJavaScript("window.dispatchEvent(new CustomEvent('mnemo-visible',{detail:\(visible ? "true" : "false")}))",completionHandler:nil) }
    @objc func toggleGhost() { if ghost.isVisible { ghost.orderOut(nil) } else { ghost.orderFrontRegardless() };sendVisibility() }
    @objc func toggleMotion() { ghostWeb.evaluateJavaScript("window.dispatchEvent(new Event('mnemo-pause'))", completionHandler: nil) }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func woke() { checkDue() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showManager();return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func reply(web: WKWebView?, id: Any?, result: Any? = nil, error: String? = nil) {
        guard let web = web, let id = id else { return }
        var value: [String: Any] = ["id": id]; if let error = error { value["error"] = error } else { value["result"] = result ?? NSNull() }
        guard let data = try? JSONSerialization.data(withJSONObject: value), let json = String(data: data, encoding: .utf8) else { return }
        web.evaluateJavaScript("window.mnemoNativeReply(\(json))", completionHandler: nil)
    }
    func handle(method: String, body: [String: Any], web: WKWebView?, mode: String) {
        let id = body["id"], payload = body["payload"] as? [String: Any] ?? [:]
        do {
            switch method {
            case "list": reply(web: web, id: id, result: try JSONSerialization.jsonObject(with: Data(store.json().utf8)))
            case "save":
                guard let text = payload["text"] as? String, let dueAt = payload["dueAt"] as? Double else { throw ReminderError.invalid("A reminder needs text and a valid time.") }
                try store.save(id: payload["id"] as? String, text: text, dueAt: dueAt); changed()
                reply(web: web, id: id, result: try JSONSerialization.jsonObject(with: Data(store.json().utf8)))
            case "action":
                guard let item = payload["id"] as? String, let action = payload["action"] as? String else { throw ReminderError.invalid("Invalid reminder action.") }
                try store.action(id: item, action: action)
                if let data=try? JSONSerialization.data(withJSONObject:["id":item,"action":action]),let json=String(data:data,encoding:.utf8) { ghostWeb.evaluateJavaScript("window.dispatchEvent(new CustomEvent('mnemo-reminder-action',{detail:\(json)}))",completionHandler:nil) }
                changed()
                reply(web: web, id: id, result: try JSONSerialization.jsonObject(with: Data(store.json().utf8)))
            case "setSize":
                guard let height=payload["height"] as? Int,(60...180).contains(height) else { return }
                UserDefaults.standard.set(height,forKey:"ghostVisibleHeight")
                ghostWeb.evaluateJavaScript("window.dispatchEvent(new CustomEvent('mnemo-size',{detail:\(height)}))",completionHandler:nil)
            case "manage": showManager()
            case "closeManager": manager?.close()
            case "moveBy":
                guard mode == "companion", let dx = payload["dx"] as? Double, let dy = payload["dy"] as? Double, dx.isFinite, dy.isFinite, abs(dx) < 500, abs(dy) < 500 else { return }
                let origin=ghost.frame.origin
                ghost.setFrameOrigin(boundedOrigin(NSPoint(x:origin.x+dx,y:origin.y-dy),size:ghost.frame.size))
                if payload["remember"] as? Bool == true {
                    UserDefaults.standard.set(["x":ghost.frame.origin.x,"y":ghost.frame.origin.y],forKey:"ghostRestingPosition")
                }
            case "hitRegions":
                guard mode == "companion", let regions = payload["regions"] as? [[String: Double]] else { return }
                hitRegions = regions.compactMap { region in guard let x=region["x"],let y=region["y"],let w=region["width"],let h=region["height"],x.isFinite,y.isFinite,w>0,h>0 else{return nil};return CGRect(x:x,y:y,width:w,height:h) }; updateClickThrough()
            case "scriptError": print("Renderer error: \(payload["message"] ?? "unknown")")
            default: throw ReminderError.invalid("Unknown app request.")
            }
        } catch { reply(web: web, id: id, error: error.localizedDescription) }
    }
    func boundedOrigin(_ origin:NSPoint,size:NSSize) -> NSPoint {
        // Hit regions use top-left web coordinates; AppKit uses bottom-left coordinates.
        // Only the ghost determines movement limits, never its transparent canvas or bubble.
        let body=hitRegions.first ?? CGRect(x:96,y:220,width:128,height:150)
        let left=body.minX, right=body.maxX
        let bottom=size.height-body.maxY, top=size.height-body.minY
        let center=NSPoint(x:origin.x+body.midX,y:origin.y+size.height-body.midY)
        let screen=NSScreen.screens.first(where:{$0.frame.contains(center)}) ?? ghost?.screen ?? NSScreen.main
        guard let area=screen?.visibleFrame else { return origin }
        return NSPoint(x:min(max(origin.x,area.minX-left),area.maxX-right),
                       y:min(max(origin.y,area.minY-bottom),area.maxY-top))
    }

    func updateClickThrough() {
        guard ghost != nil, !hitRegions.isEmpty else { return }
        let mouse = NSEvent.mouseLocation, point = CGPoint(x: mouse.x-ghost.frame.minX, y: ghost.frame.maxY-mouse.y)
        let interactive=hitRegions.contains(where: { $0.contains(point) })
        ghost.ignoresMouseEvents = !interactive
        if pointerIsOverCompanion != interactive {
            pointerIsOverCompanion=interactive
            ghostWeb.evaluateJavaScript("window.dispatchEvent(new CustomEvent('mnemo-hover',{detail:\(interactive ? "true" : "false")}))",completionHandler:nil)
        }
    }
    func changed() {
        broadcast()
    }
    func broadcast() {
        for web in [ghostWeb, managerWeb] { web?.evaluateJavaScript("window.dispatchEvent(new Event('mnemo-reminders-changed'))", completionHandler: nil) }
    }
    func checkDue() {
        guard !screenAsleep,!sessionInactive else { return }
        do { if !(try store.checkDue()).isEmpty { ghost.orderFrontRegardless();ghostWeb.evaluateJavaScript("window.dispatchEvent(new CustomEvent('mnemo-visible',{detail:true}))",completionHandler:nil); broadcast() } }
        catch { print("Reminder scheduler: \(error.localizedDescription)") }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url=navigationAction.request.url, url.isFileURL, url.path.hasPrefix(Bundle.main.resourceURL?.path ?? "UNAVAILABLE") else { decisionHandler(.cancel); return }; decisionHandler(.allow)
    }
    func showError(_ text:String) { let alert=NSAlert();alert.messageText="Mnemo couldn’t start";alert.informativeText=text;alert.runModal() }
}

let app=NSApplication.shared
let delegate=AppDelegate()
app.setActivationPolicy(.regular)
app.delegate=delegate
app.run()
