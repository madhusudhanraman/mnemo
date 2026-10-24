import Cocoa
import WebKit
import UserNotifications
import ServiceManagement

// The transparent canvas may extend offscreen while the companion remains visible.
final class CompanionWebView: WKWebView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class CompanionPanel: NSPanel {
    static let companionBehavior:NSWindow.CollectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
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

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, NSMenuDelegate, NSMenuItemValidation {
    let spotify=SpotifyPlayback()
    let spotifyLibrary=SpotifyLibrary()
    var spotifyState:[String:Any] = ["playing":false]
    var spotifyStatus:String?
    let backgroundColour = BackgroundColour()
    let loginItem=LoginItemController()
    var loginState=LoginItemState.disabled
    var loginChangePending=false
    var loginMessage:String?
    var loginError:String?
    var instanceLock:InstanceLock?
    var startupReady=false
    var colourTicks = 0
    var nextColourSample=Date.distantPast
    var colourInterval=5.0
    var priorLuminance: Double?
    var sampledOrigin: NSPoint?
    var displayObserver: NSObjectProtocol?
    var screenAsleep=false, sessionInactive=false
    var lastSentColour: Bool?
    var store: ReminderStore!
    var ghost: NSPanel!
    var ghostWeb: WKWebView!
    var manager: NSWindow?
    var managerWeb: WKWebView?
    var settingsController:MnemoSettingsController?
    var sizesWindow: NSWindow?
    var sizesWeb: WKWebView?
    var statusItem: NSStatusItem!
    var timer: Timer?
    var observers: [Any] = []
    var mouseMonitors:[Any]=[]
    var hitRegions: [CGRect] = []
    var lastUsableBounds = ""
    var dragPointerStart:NSPoint?
    var dragWindowStart:NSPoint?
    var nativeDragMoved=false
    var pointerIsOverCompanion: Bool?
    var lastSentSystemActive: Bool?
    var trackingMenus=Set<ObjectIdentifier>()
    let testMode = CommandLine.arguments.contains("--test")
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            if !testMode {
                if !CommandLine.arguments.contains("--development"),!AppInstallation.isInstalled,
                   let installed=Bundle(url:AppInstallation.installedURL),installed.bundleIdentifier == AppInstallation.bundleID {
                    let configuration=NSWorkspace.OpenConfiguration();configuration.activates=false
                    NSWorkspace.shared.openApplication(at:AppInstallation.installedURL,configuration:configuration) { _,error in
                        if let error=error { self.showError(error.localizedDescription) }
                        NSApp.terminate(nil)
                    }
                    return
                }
                let lockURL=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Mnemo/instance.lock")
                guard let lock=try InstanceLock(url:lockURL) else { AppInstallation.revealRunningCopy();NSApp.terminate(nil);return }
                instanceLock=lock
            }
            let root = testMode ? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Mnemo-test-\(ProcessInfo.processInfo.processIdentifier)") : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Mnemo")
            store = try ReminderStore(url: root.appendingPathComponent("reminders.json"))
            // Cancel alerts scheduled by older builds; reminders now use thought bubbles only.
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            loginState=loginItem.state
            createMenu(); createGhost();startupReady=true;checkDue()
            spotify.onChange={ [weak self] state in
                guard let self=self else { return };self.spotifyState=state;self.sendSpotify()
                if self.pointerIsOverCompanion == true { self.spotifyLibrary.inspect(self.currentSpotifyURI) }
            }
            spotifyLibrary.onChange={ [weak self] in self?.sendSpotify();self?.refreshSpotifySettings() }
            spotify.onStatus={ [weak self] status in self?.spotifyStatus=status;self?.refreshSpotifySettings() }
            spotify.setEnabled(UserDefaults.standard.bool(forKey:"spotifyOnHover"))
            DistributedNotificationCenter.default().addObserver(self,selector:#selector(revealCompanion),name:AppInstallation.revealNotification,object:nil)
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.checkDue(); self?.updateColour(); self?.updateSystemActivity(); if self?.pointerIsOverCompanion == true && self?.screenAsleep == false && self?.sessionInactive == false { self?.spotify.refresh() } }
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
            displayObserver=NotificationCenter.default.addObserver(forName:NSApplication.didChangeScreenParametersNotification,object:nil,queue:.main) { [weak self] _ in self?.recoverDisplayPosition() }
            observers.append(workspace.addObserver(forName:NSWorkspace.activeSpaceDidChangeNotification,object:nil,queue:.main) { [weak self] _ in
                guard let self=self else { return };self.nextColourSample = .distantPast
                self.sendVisibility()
            })
            startMouseTracking()
        } catch { showError(error.localizedDescription); NSApp.terminate(nil) }
    }
    func startMouseTracking() {
        guard mouseMonitors.isEmpty,trackingMenus.isEmpty else { return }
        if let monitor=NSEvent.addLocalMonitorForEvents(matching:[.mouseMoved,.leftMouseDown,.leftMouseDragged,.leftMouseUp],handler:{ [weak self] event in self?.trackCompanionDrag(event);self?.updateClickThrough();return event }) { mouseMonitors.append(monitor) }
        if let monitor=NSEvent.addGlobalMonitorForEvents(matching:[.mouseMoved,.leftMouseDragged],handler:{ [weak self] _ in self?.updateClickThrough() }) { mouseMonitors.append(monitor) }
    }
    func stopMouseTracking() {
        for monitor in mouseMonitors { NSEvent.removeMonitor(monitor) }
        mouseMonitors.removeAll()
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
        if webView === ghostWeb { lastSentSystemActive=nil;updateSystemActivity();sendVisibility();sendSpotify();lastUsableBounds="";sendUsableBounds() }
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
        window.mnemoDesktop={nativeDrag:true,mode:'\(mode)',systemActive:\(systemIsActive() ? "true" : "false"),usageLocation:'\(usageLocation)',preferredHeight:\(UserDefaults.standard.integer(forKey:"ghostVisibleHeight")),debug:\(debugRendering()),setSize:height=>send('setSize',{height}),list:()=>call('list'),listProjects:()=>call('listProjects'),saveProject:project=>call('saveProject',project),save:item=>call('save',item),action:item=>call('action',item),manage:()=>send('manage'),closeManager:()=>send('closeManager'),moveBy:delta=>send('moveBy',delta),hitRegions:regions=>send('hitRegions',{regions}),spotifyControl:command=>call('spotifyControl',{command}),spotifyLike:uri=>call('spotifyLike',{uri})};
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
            let candidate=NSRect(x:x,y:y,width:840,height:760)
            if NSScreen.screens.contains(where:{$0.visibleFrame.intersects(candidate)}) { origin=NSPoint(x:x,y:y); if !UserDefaults.standard.bool(forKey:"wideCompanionCanvas") { origin.x-=260;origin.y-=180 } }
        }
        origin=boundedOrigin(origin,size:NSSize(width:840,height:760))
        ghost = CompanionPanel(contentRect: NSRect(origin:origin,size:NSSize(width:840,height:760)), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        ghost.title = "Mnemo companion"; ghost.isOpaque = false; ghost.backgroundColor = .clear; ghost.hasShadow = false
        ghost.level = .floating; ghost.hidesOnDeactivate = false; ghost.collectionBehavior = CompanionPanel.companionBehavior
        // Floating windows otherwise default to transient (hidden in Mission Control).
        // Keep the companion stationary and out of normal window cycling.
        ghost.isReleasedWhenClosed = false; ghost.acceptsMouseMovedEvents = true
        ghostWeb = makeWeb(mode: "companion"); ghost.contentView = ghostWeb
        recoverDisplayPosition()
        ghost.orderFrontRegardless()
    }
    @objc func showManager() {
        if manager == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 720), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Mnemo"; window.minSize = NSSize(width: 400, height: 550); window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(red: 0.14, green: 0.13, blue: 0.19, alpha: 1)
            managerWeb = makeWeb(mode: "manager",resource:"editor"); window.contentView = managerWeb; window.center(); manager = window
        }
        managerWeb?.evaluateJavaScript("window.dispatchEvent(new Event('mnemo-new-reminder'))",completionHandler:nil)
        NSApp.activate(ignoringOtherApps: true); manager?.makeKeyAndOrderFront(nil)
    }
    var usageLocation:String {
        let value=UserDefaults.standard.string(forKey:"usageLocation") ?? "Both"
        return ["Home","Work","Both"].contains(value) ? value:"Both"
    }
    func setUsageLocation(_ value:String) {
        guard ["Home","Work","Both"].contains(value) else { return }
        UserDefaults.standard.set(value,forKey:"usageLocation")
        for web in [ghostWeb,managerWeb].compactMap({$0}) {
            web.evaluateJavaScript("window.dispatchEvent(new CustomEvent('mnemo-location',{detail:'\(value)'}))",completionHandler:nil)
        }
        refreshSettings()
    }
    var showInDock:Bool { UserDefaults.standard.object(forKey:"showInDock") as? Bool ?? true }
    @objc func showSettings() {
        if settingsController == nil {
            settingsController=MnemoSettingsController(actions:.init(
                dock:{ [weak self] value in self?.setShowInDock(value) },
                login:{ [weak self] in self?.toggleLaunchAtLogin() },
                size:{ [weak self] in self?.showSizes() },
                colour:{ [weak self] value in
                    let item=NSMenuItem();item.representedObject=value;self?.chooseColour(item)
                },
                loginSettings:{ [weak self] in self?.openLoginSettings() },
                refresh:{ [weak self] in self?.refreshLoginItemState() },
                spotify:{ [weak self] value in
                    UserDefaults.standard.set(value,forKey:"spotifyOnHover");self?.spotify.setEnabled(value);self?.refreshSpotifySettings()
                },
                location:{ [weak self] value in self?.setUsageLocation(value) },
                spotifyConnect:{ [weak self] id in
                    if SpotifyLibrary.validClientID(id.trimmingCharacters(in:.whitespacesAndNewlines)) { UserDefaults.standard.set(id.trimmingCharacters(in:.whitespacesAndNewlines),forKey:"spotifyClientID") }
                    self?.spotifyLibrary.connect(clientID:id)
                },
                spotifyDisconnect:{ [weak self] in self?.spotifyLibrary.disconnect() }
            ))
        }
        refreshLoginItemState();refreshSettings()
        NSApp.activate(ignoringOtherApps:true);settingsController?.showWindow(nil);settingsController?.window?.makeKeyAndOrderFront(nil)
    }
    var currentSpotifyURI:String { spotifyState["uri"] as? String ?? "" }
    func sendSpotify() {
        var state=spotifyState;state["libraryConnected"]=spotifyLibrary.connected
        state["canLike"]=SpotifyLibrary.trackURI(currentSpotifyURI)
        if let saved=spotifyLibrary.saved(currentSpotifyURI) { state["liked"]=saved }
        guard let data=try? JSONSerialization.data(withJSONObject:state),let json=String(data:data,encoding:.utf8) else { return }
        ghostWeb?.evaluateJavaScript("window.dispatchEvent(new CustomEvent('mnemo-spotify',{detail:\(json)}))",completionHandler:nil)
    }
    func refreshSpotifySettings() {
        settingsController?.updateSpotify(enabled:UserDefaults.standard.bool(forKey:"spotifyOnHover"),status:spotifyStatus)
        settingsController?.updateSpotifyLibrary(clientID:spotifyLibrary.connected ? spotifyLibrary.clientID:UserDefaults.standard.string(forKey:"spotifyClientID") ?? "",connected:spotifyLibrary.connected,connecting:spotifyLibrary.connecting,status:spotifyLibrary.status)
    }
    func refreshSettings() {
        refreshSpotifySettings()
        settingsController?.updateLocation(usageLocation)
        settingsController?.update(showDock:showInDock,login:loginState,busy:loginChangePending,message:loginMessage,error:loginError,installed:AppInstallation.isInstalled,colour:UserDefaults.standard.string(forKey:"ghostColour") ?? "white")
    }
    func setShowInDock(_ visible:Bool) {
        let activeWindow=[settingsController?.window,manager,sizesWindow].compactMap({$0}).first(where:{$0.isKeyWindow})
        let ghostWasVisible=ghost?.isVisible == true
        guard NSApp.setActivationPolicy(visible ? .regular:.accessory) else { refreshSettings();return }
        UserDefaults.standard.set(visible,forKey:"showInDock");refreshSettings()
        DispatchQueue.main.async { [weak self,weak activeWindow] in
            if ghostWasVisible { self?.ghost?.orderFrontRegardless() }
            if let window=activeWindow { NSApp.activate(ignoringOtherApps:true);window.makeKeyAndOrderFront(nil) }
        }
    }
    func applicationDockMenu(_ sender:NSApplication) -> NSMenu? {
        let menu=NSMenu()
        for (title,action) in [("Open Mnemo…",#selector(showManager)),("Settings…",#selector(showSettings))] {
            let item=NSMenuItem(title:title,action:action,keyEquivalent:"");item.target=self;menu.addItem(item)
        }
        observeMenu(menu)
        return menu
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
        // Keep the status item and menu objects stable for AppKit's tracking loop.
        guard statusItem == nil else { refreshMenuState(); return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image=mnemoMenuIcon();statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.setAccessibilityLabel("Mnemo reminders");statusItem.button?.toolTip = "Mnemo · your reminder companion"
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Mnemo…", action: #selector(showManager), keyEquivalent: "r")
        menu.addItem(withTitle:"Settings…",action:#selector(showSettings),keyEquivalent:",")
        menu.addItem(withTitle: "Show / hide ghost", action: #selector(toggleGhost), keyEquivalent: "")
        menu.addItem(withTitle: "Pause / resume motion", action: #selector(toggleMotion), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Mnemo", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }; statusItem.menu = menu
        let mainMenu=NSMenu(),applicationMenu=NSMenu(),applicationItem=NSMenuItem()
        let settingsItem=NSMenuItem(title:"Settings…",action:#selector(showSettings),keyEquivalent:",");settingsItem.target=self;applicationMenu.addItem(settingsItem);applicationMenu.addItem(.separator())
        let quitItem=NSMenuItem(title:"Quit Mnemo",action:#selector(quit),keyEquivalent:"q");quitItem.target=self
        applicationMenu.addItem(quitItem);applicationItem.submenu=applicationMenu;mainMenu.addItem(applicationItem);NSApp.mainMenu=mainMenu
        observeMenu(menu);observeMenu(applicationMenu);refreshLoginItemState()
    }
    func observeMenu(_ menu:NSMenu) {
        menu.delegate=self
        for item in menu.items { if let submenu=item.submenu { observeMenu(submenu) } }
    }
    func menuNeedsUpdate(_ menu:NSMenu) { if trackingMenus.isEmpty { refreshMenuState();refreshLoginItemState() } }
    func menuWillOpen(_ menu:NSMenu) {
        let wasTracking = !trackingMenus.isEmpty
        trackingMenus.insert(ObjectIdentifier(menu))
        if !wasTracking { stopMouseTracking();sendVisibility() }
    }
    func menuDidClose(_ menu:NSMenu) {
        trackingMenus.remove(ObjectIdentifier(menu))
        if trackingMenus.isEmpty {
            refreshMenuState();updateLoginItemMenus();sendVisibility()
            // Reinstall only after AppKit finishes dismissing the menu.
            DispatchQueue.main.async { [weak self] in
                guard let self=self,self.trackingMenus.isEmpty else { return }
                self.startMouseTracking();self.updateClickThrough()
            }
        }
    }
    func refreshMenuState() {
        let mode=UserDefaults.standard.string(forKey:"ghostColour") ?? "white"
        for parent in (statusItem?.menu?.items ?? []) + (NSApp.mainMenu?.items.first?.submenu?.items ?? []) {
            guard let submenu=parent.submenu else { continue }
            for item in submenu.items {
                if let value=item.representedObject as? String {
                    let state:NSControl.StateValue=value == mode ? .on : .off
                    if item.state != state { item.state=state }
                }
            }
            if let status=submenu.item(withTag:917),status.title != backgroundColour.status { status.title=backgroundColour.status }
        }
    }
    func addLaunchAtLoginItems(to menu:NSMenu) {
        let item=NSMenuItem(title:"Launch at Login",action:#selector(toggleLaunchAtLogin),keyEquivalent:"")
        item.tag=918;item.target=self;menu.addItem(item)
        let message=NSMenuItem(title:"",action:nil,keyEquivalent:"");message.tag=919;message.isHidden=true;menu.addItem(message)
        let settings=NSMenuItem(title:"Open Login Settings…",action:#selector(openLoginSettings),keyEquivalent:"")
        settings.tag=920;settings.target=self;settings.isHidden=true;menu.addItem(settings)
    }
    func refreshLoginItemState() {
        if !loginChangePending { loginState=loginItem.state }
        updateLoginItemMenus()
    }
    func updateLoginItemMenus() {
        refreshSettings()
        guard trackingMenus.isEmpty else { return }
        for menu in [statusItem?.menu,NSApp.mainMenu?.items.first?.submenu].compactMap({$0}) {
            guard let item=menu.item(withTag:918) else { continue }
            let title=loginChangePending ? "Updating Launch at Login…":"Launch at Login"
            if item.title != title { item.title=title }
            let state:NSControl.StateValue=loginState == .enabled ? .on:loginState == .requiresApproval ? .mixed:.off
            if item.state != state { item.state=state }
            item.toolTip=AppInstallation.isInstalled ? nil:"Install Mnemo in Applications to enable launch at login."
            item.isEnabled=AppInstallation.isInstalled && !loginChangePending
            let message=loginMessage ?? (loginState == .requiresApproval ? "Approval needed in Login Items":nil)
            if let row=menu.item(withTag:919) { row.title=message ?? "";row.toolTip=loginError;row.isHidden=message == nil }
            menu.item(withTag:920)?.isHidden=message == nil
        }
    }
    func validateMenuItem(_ item:NSMenuItem) -> Bool {
        if item.tag == 918 { return AppInstallation.isInstalled && !loginChangePending }
        return true
    }
    @objc func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
    @objc func toggleLaunchAtLogin() {
        guard AppInstallation.isInstalled,!loginChangePending else { return }
        loginChangePending=true;loginMessage=nil;loginError=nil;updateLoginItemMenus()
        // The action may still be inside AppKit's post-tracking dismissal stack.
        // Neither registration nor a modal dialog may hold that stack open.
        loginItem.toggleAsync { [weak self] state,error in
            guard let self=self else { return }
            self.loginChangePending=false;self.loginState=state
            NSLog("Mnemo Launch at Login: %@",error?.localizedDescription ?? String(describing:state))
            if let error=error { self.loginMessage="Couldn’t change Launch at Login";self.loginError=error.localizedDescription }
            else if state == .notFound || state == .unavailable { self.loginMessage="macOS hasn’t confirmed login startup" }
            self.updateLoginItemMenus()
        }
    }
    @objc func revealCompanion() { guard startupReady else { return };ghost.orderFrontRegardless();sendVisibility() }
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
        refreshMenuState();refreshSettings();colourTicks=0;nextColourSample = .distantPast;colourInterval=5;updateColour()
    }
    func sendColour(_ dark:Bool) {
        guard lastSentColour != dark else { return };lastSentColour=dark
        ghostWeb?.evaluateJavaScript("window.dispatchEvent(new CustomEvent('mnemo-colour',{detail:\(dark ? "true" : "false")}))",completionHandler:nil)
    }
    func updateColour() {
        if trackingMenus.isEmpty { refreshMenuState() }
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
    func sendVisibility() { guard ghost != nil else { return };let visible=ghost.isVisible && !screenAsleep && !sessionInactive && trackingMenus.isEmpty;ghostWeb.evaluateJavaScript("window.dispatchEvent(new CustomEvent('mnemo-visible',{detail:\(visible ? "true" : "false")}))",completionHandler:nil) }
    @objc func toggleGhost() { if ghost.isVisible { ghost.orderOut(nil) } else { ghost.orderFrontRegardless() };sendVisibility() }
    @objc func toggleMotion() { ghostWeb.evaluateJavaScript("window.dispatchEvent(new Event('mnemo-pause'))", completionHandler: nil) }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func woke() { checkDue() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { if startupReady { showManager() };return true }
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
            case "spotifyLike":
                guard mode=="companion",spotify.enabled,let uri=payload["uri"] as? String,uri==currentSpotifyURI,SpotifyLibrary.trackURI(uri) else { throw ReminderError.invalid("The track changed or cannot be saved. Try again.") }
                guard spotifyLibrary.connected else { showSettings();reply(web:web,id:id,result:["needsConnection":true]);return }
                spotifyLibrary.toggle(uri) { [weak self,weak web] error in self?.reply(web:web,id:id,result:error==nil ? true:nil,error:error) }
            case "spotifyControl":
                guard mode == "companion",spotify.enabled else { throw ReminderError.invalid("Enable Spotify on Hover in Settings.") }
                guard let value=payload["command"] as? String,let command=SpotifyPlayback.Command(rawValue:value) else { throw ReminderError.invalid("Unknown Spotify control.") }
                spotify.control(command) { [weak self,weak web] error in self?.reply(web:web,id:id,result:error == nil ? true:nil,error:error) }
            case "list": reply(web: web, id: id, result: try JSONSerialization.jsonObject(with: Data(store.json().utf8)))
            case "listProjects": reply(web:web,id:id,result:try JSONSerialization.jsonObject(with:Data(store.projectsJSON().utf8)))
            case "saveProject":
                guard let name=payload["name"] as? String,let space=payload["space"] as? String else { throw ReminderError.invalid("A project needs a name and space.") }
                try store.saveProject(id:payload["id"] as? String,name:name,space:space);changed()
                reply(web:web,id:id,result:try JSONSerialization.jsonObject(with:Data(store.projectsJSON().utf8)))
            case "save":
                guard let text = payload["text"] as? String else { throw ReminderError.invalid("A reminder needs text and a valid time.") }
                try store.save(id: payload["id"] as? String, text: text, dueAt: payload["dueAt"] as? Double,projectID:payload["projectID"] as? String,notes:payload["notes"] as? String); changed()
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
                ghost.setFrameOrigin(boundedOrigin(NSPoint(x:origin.x+dx,y:origin.y-dy),size:ghost.frame.size,dragging:true))
                sendUsableBounds()
                if payload["remember"] as? Bool == true {
                    rememberDisplayPosition()
                }
            case "hitRegions":
                guard mode == "companion", let regions = payload["regions"] as? [[String: Double]] else { return }
                hitRegions = regions.compactMap { region in guard let x=region["x"],let y=region["y"],let w=region["width"],let h=region["height"],x.isFinite,y.isFinite,w>0,h>0 else{return nil};return CGRect(x:x,y:y,width:w,height:h) }; updateClickThrough()
            case "scriptError": print("Renderer error: \(payload["message"] ?? "unknown")")
            default: throw ReminderError.invalid("Unknown app request.")
            }
        } catch { reply(web: web, id: id, error: error.localizedDescription) }
    }
    func displayID(_ screen:NSScreen) -> String {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "unknown"
    }
    func bodyRect(origin:NSPoint,size:NSSize) -> CGRect {
        let body=hitRegions.first ?? CGRect(x:356,y:360,width:128,height:150)
        return CGRect(x:origin.x+body.minX,y:origin.y+size.height-body.maxY,width:body.width,height:body.height)
    }
    static func nearestArea(to point:NSPoint,areas:[CGRect]) -> CGRect? {
        areas.min { a,b in
            func distance(_ r:CGRect) -> Double {
                let dx=max(r.minX-point.x,0,point.x-r.maxX),dy=max(r.minY-point.y,0,point.y-r.maxY)
                return dx*dx+dy*dy
            }
            return distance(a)<distance(b)
        }
    }
    func boundedOrigin(_ origin:NSPoint,size:NSSize,dragging:Bool=false) -> NSPoint {
        let body=bodyRect(origin:origin,size:size)
        let pointerArea=dragging ? NSScreen.screens.first(where:{$0.frame.contains(NSEvent.mouseLocation)})?.visibleFrame : nil
        guard let area=pointerArea ?? Self.nearestArea(to:NSPoint(x:body.midX,y:body.midY),areas:NSScreen.screens.map(\.visibleFrame)) else { return origin }
        return Self.safeCompanionOrigin(origin,size:size,area:area,body:body)
    }
    static func safeCompanionOrigin(_ origin:NSPoint,size:NSSize,area:CGRect,body:CGRect) -> NSPoint {
        let safe=area.insetBy(dx:20,dy:20)
        return NSPoint(x:origin.x+min(max(body.minX,safe.minX),max(safe.minX,safe.maxX-body.width))-body.minX,
                       y:origin.y+min(max(body.minY,safe.minY),max(safe.minY,area.maxY-body.height))-body.minY)
    }
    func sendUsableBounds() {
        guard ghost != nil,ghostWeb != nil else { return }
        let body=bodyRect(origin:ghost.frame.origin,size:ghost.frame.size)
        guard let area=Self.nearestArea(to:NSPoint(x:body.midX,y:body.midY),areas:NSScreen.screens.map(\.visibleFrame)) else { return }
        let frame=ghost.frame
        let json="{left:\(max(0,area.minX-frame.minX)),top:\(max(0,frame.maxY-area.maxY)),right:\(min(frame.width,area.maxX-frame.minX)),bottom:\(min(frame.height,frame.maxY-area.minY))}"
        guard json != lastUsableBounds else { return };lastUsableBounds=json
        ghostWeb.evaluateJavaScript("window.mnemoUsableBounds=\(json);window.dispatchEvent(new Event('mnemo-bounds'))",completionHandler:nil)
    }
    func rememberDisplayPosition() {
        UserDefaults.standard.set(true,forKey:"wideCompanionCanvas")
        let body=bodyRect(origin:ghost.frame.origin,size:ghost.frame.size)
        guard let screen=NSScreen.screens.first(where:{$0.frame.contains(NSPoint(x:body.midX,y:body.midY))}) else { return }
        let area=screen.visibleFrame,id=displayID(screen)
        var positions=UserDefaults.standard.dictionary(forKey:"ghostDisplayPositions") ?? [:]
        positions[id]=["x":(body.minX-area.minX)/max(1,area.width-body.width),"y":(body.minY-area.minY)/max(1,area.height-body.height)]
        UserDefaults.standard.set(positions,forKey:"ghostDisplayPositions")
        UserDefaults.standard.set(id,forKey:"ghostPreferredDisplay")
        UserDefaults.standard.set(["x":ghost.frame.minX,"y":ghost.frame.minY],forKey:"ghostRestingPosition")
    }
    func recoverDisplayPosition() {
        guard ghost != nil else { return }
        let defaults=UserDefaults.standard
        var origin=ghost.frame.origin
        // Dock, menu bar and full-screen changes resize the visible area of the current display; only keep him on screen then.
        let body=bodyRect(origin:origin,size:ghost.frame.size)
        let current=NSScreen.screens.first(where:{$0.frame.contains(NSPoint(x:body.midX,y:body.midY))})
        if let current=current,displayID(current)==defaults.string(forKey:"ghostPreferredDisplay") {
            let bounded=boundedOrigin(origin,size:ghost.frame.size)
            if bounded != origin { ghost.setFrameOrigin(bounded) }
            nextColourSample = .distantPast;updateClickThrough();return
        }
        if let preferred=defaults.string(forKey:"ghostPreferredDisplay"),
           let screen=NSScreen.screens.first(where:{displayID($0)==preferred}),
           let positions=defaults.dictionary(forKey:"ghostDisplayPositions"),let saved=positions[preferred] as? [String:Double],
           let x=saved["x"],let y=saved["y"],x.isFinite,y.isFinite {
            let body=bodyRect(origin:.zero,size:ghost.frame.size),area=screen.visibleFrame
            origin=NSPoint(x:area.minX+min(1,max(0,x))*max(0,area.width-body.width)-body.minX,
                           y:area.minY+min(1,max(0,y))*max(0,area.height-body.height)-body.minY)
        }
        ghost.setFrameOrigin(boundedOrigin(origin,size:ghost.frame.size))
        nextColourSample = .distantPast;updateClickThrough()
    }

    static func dragOrigin(start:NSPoint,pointerStart:NSPoint,pointer:NSPoint) -> NSPoint {
        NSPoint(x:start.x+pointer.x-pointerStart.x,y:start.y+pointer.y-pointerStart.y)
    }
    func trackCompanionDrag(_ event:NSEvent) {
        switch event.type {
        case .leftMouseDown:
            guard event.window === ghost,!event.modifierFlags.contains(.shift) else { return }
            let mouse=NSEvent.mouseLocation
            let point=CGPoint(x:mouse.x-ghost.frame.minX,y:ghost.frame.maxY-mouse.y)
            guard hitRegions.first?.contains(point) == true else { return }
            dragPointerStart=mouse;dragWindowStart=ghost.frame.origin;nativeDragMoved=false
            ghost.ignoresMouseEvents=false
        case .leftMouseDragged:
            guard let pointerStart=dragPointerStart,let start=dragWindowStart else { return }
            let pointer=NSEvent.mouseLocation
            if hypot(pointer.x-pointerStart.x,pointer.y-pointerStart.y)>5 { nativeDragMoved=true }
            guard nativeDragMoved else { return }
            ghost.setFrameOrigin(boundedOrigin(Self.dragOrigin(start:start,pointerStart:pointerStart,pointer:pointer),size:ghost.frame.size,dragging:true))
            sendUsableBounds()
        case .leftMouseUp:
            // Deliver release to WebKit before restoring click-through.
            DispatchQueue.main.async { [weak self] in
                self?.dragPointerStart=nil;self?.dragWindowStart=nil;self?.nativeDragMoved=false;self?.updateClickThrough()
            }
        default: break
        }
    }
    func updateClickThrough() {
        sendUsableBounds()
        guard ghost != nil, !hitRegions.isEmpty, trackingMenus.isEmpty else { return }
        let mouse = NSEvent.mouseLocation, point = CGPoint(x: mouse.x-ghost.frame.minX, y: ghost.frame.maxY-mouse.y)
        let interactive=dragPointerStart != nil || hitRegions.contains(where: { $0.contains(point) })
        if ghost.ignoresMouseEvents == interactive { ghost.ignoresMouseEvents = !interactive }
        if pointerIsOverCompanion != interactive {
            pointerIsOverCompanion=interactive
            if interactive { spotify.refresh(force:true);spotifyLibrary.inspect(currentSpotifyURI) }
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
        do { if !(try store.checkDue()).isEmpty { ghost.orderFrontRegardless();sendVisibility(); broadcast() } }
        catch { print("Reminder scheduler: \(error.localizedDescription)") }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url=navigationAction.request.url, url.isFileURL, url.path.hasPrefix(Bundle.main.resourceURL?.path ?? "UNAVAILABLE") else { decisionHandler(.cancel); return }; decisionHandler(.allow)
    }
    func showError(_ text:String) { let alert=NSAlert();alert.messageText="Mnemo couldn’t start";alert.informativeText=text;alert.runModal() }
}

let app=NSApplication.shared
let delegate=AppDelegate()
app.setActivationPolicy(delegate.showInDock ? .regular:.accessory)
app.delegate=delegate
app.run()
