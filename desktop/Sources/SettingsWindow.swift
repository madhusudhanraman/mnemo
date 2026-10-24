import Cocoa

final class MnemoSettingsController:NSWindowController,NSWindowDelegate {
    struct Actions {
        let dock:(Bool)->Void
        let login:()->Void
        let size:()->Void
        let colour:(String)->Void
        let loginSettings:()->Void
        let refresh:()->Void
        var spotify:(Bool)->Void = {_ in}
        var location:(String)->Void = {_ in}
        var spotifyConnect:(String)->Void = {_ in}
        var spotifyDisconnect:()->Void = {}
    }
    private let actions:Actions
    let dockToggle=NSButton(checkboxWithTitle:"Show in Dock",target:nil,action:nil)
    let loginToggle=NSButton(checkboxWithTitle:"Launch at Login",target:nil,action:nil)
    let loginStatus=NSTextField(wrappingLabelWithString:"")
    let loginSettingsButton=NSButton(title:"Open Login Settings…",target:nil,action:nil)
    let colourPicker=NSPopUpButton(frame:.zero,pullsDown:false)
    let spotifyToggle=NSButton(checkboxWithTitle:"Spotify on Hover",target:nil,action:nil)
    let spotifyClientID=NSTextField(string:"")
    let spotifyConnect=NSButton(title:"Connect Spotify…",target:nil,action:nil)
    let spotifyDisconnect=NSButton(title:"Disconnect",target:nil,action:nil)
    let spotifyLibraryStatus=NSTextField(wrappingLabelWithString:"")
    let spotifyStatus=NSTextField(wrappingLabelWithString:"")
    let locationPicker=NSPopUpButton(frame:.zero,pullsDown:false)
    let sizeButton=NSButton(title:"Size…",target:nil,action:nil)
    init(actions:Actions) {
        self.actions=actions
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:410,height:570),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.title="Mnemo Settings";window.isReleasedWhenClosed=false
        super.init(window:window)
        window.delegate=self;window.center()
        spotifyToggle.target=self;spotifyToggle.action=#selector(changeSpotify)
        spotifyClientID.placeholderString="Spotify Client ID";spotifyClientID.setAccessibilityLabel("Spotify Client ID")
        spotifyConnect.target=self;spotifyConnect.action=#selector(connectSpotify)
        spotifyDisconnect.target=self;spotifyDisconnect.action=#selector(disconnectSpotify)
        spotifyLibraryStatus.textColor = .secondaryLabelColor;spotifyLibraryStatus.maximumNumberOfLines=4
        spotifyStatus.textColor = .secondaryLabelColor;spotifyStatus.maximumNumberOfLines=3;spotifyStatus.isHidden=true
        dockToggle.target=self;dockToggle.action=#selector(changeDock)
        loginToggle.target=self;loginToggle.action=#selector(changeLogin);loginToggle.allowsMixedState=true
        loginSettingsButton.target=self;loginSettingsButton.action=#selector(openLoginSettings)
        sizeButton.target=self;sizeButton.action=#selector(changeSize)
        colourPicker.target=self;colourPicker.action=#selector(changeColour)
        for (title,value) in [("Auto","auto"),("White","white"),("Lavender","lavender")] {
            colourPicker.addItem(withTitle:title);colourPicker.lastItem?.representedObject=value
        }
        for value in ["Home","Work","Both"] { locationPicker.addItem(withTitle:value);locationPicker.lastItem?.representedObject=value }
        locationPicker.setAccessibilityLabel("Use Mnemo at")
        locationPicker.target=self;locationPicker.action=#selector(changeLocation)
        colourPicker.setAccessibilityLabel("Companion colour")
        loginStatus.textColor = .secondaryLabelColor;loginStatus.maximumNumberOfLines=2
        let appearance=NSStackView(views:[NSTextField(labelWithString:"Colour"),colourPicker,sizeButton])
        appearance.orientation = .horizontal;appearance.spacing=10
        let location=NSStackView(views:[NSTextField(labelWithString:"Use Mnemo at"),locationPicker]);location.orientation = .horizontal;location.spacing=12
        let separator=NSBox();separator.boxType = .separator
        let libraryActions=NSStackView(views:[spotifyConnect,spotifyDisconnect]);libraryActions.orientation = .horizontal;libraryActions.spacing=8
        let stack=NSStackView(views:[location,dockToggle,loginToggle,loginStatus,loginSettingsButton,separator,appearance,spotifyToggle,spotifyStatus,spotifyClientID,libraryActions,spotifyLibraryStatus])
        stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=12;stack.detachesHiddenViews=true
        let content=window.contentView!;content.addSubview(stack);stack.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:24),
            stack.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-24),
            stack.topAnchor.constraint(equalTo:content.topAnchor,constant:22),
            stack.bottomAnchor.constraint(lessThanOrEqualTo:content.bottomAnchor,constant:-22),
            separator.widthAnchor.constraint(equalTo:stack.widthAnchor),
            loginStatus.widthAnchor.constraint(equalTo:stack.widthAnchor),
            spotifyStatus.widthAnchor.constraint(equalTo:stack.widthAnchor),
            spotifyClientID.widthAnchor.constraint(equalTo:stack.widthAnchor),
            spotifyLibraryStatus.widthAnchor.constraint(equalTo:stack.widthAnchor)
        ])
        loginStatus.isHidden=true;loginSettingsButton.isHidden=true
    }
    required init?(coder:NSCoder) { fatalError("Use init(actions:)") }
    func update(showDock:Bool,login:LoginItemState,busy:Bool,message:String?,error:String?,installed:Bool,colour:String) {
        dockToggle.state=showDock ? .on:.off
        loginToggle.state=login == .enabled ? .on:login == .requiresApproval ? .mixed:.off
        loginToggle.title=busy ? "Updating Launch at Login…":"Launch at Login"
        loginToggle.isEnabled=installed && !busy
        let text=message ?? (login == .requiresApproval ? "Approval needed in Login Items":!installed ? "Install Mnemo in Applications to enable login startup.":nil)
        loginStatus.stringValue=text ?? "";loginStatus.toolTip=error;loginStatus.isHidden=text == nil
        loginSettingsButton.isHidden=message == nil && login != .requiresApproval
        if let item=colourPicker.itemArray.first(where:{$0.representedObject as? String == colour}) { colourPicker.select(item) }
    }
    func updateLocation(_ value:String) {
        if let item=locationPicker.itemArray.first(where:{$0.representedObject as? String == value}) { locationPicker.select(item) }
    }
    @objc private func changeLocation() { if let value=locationPicker.selectedItem?.representedObject as? String { actions.location(value) } }
    func updateSpotify(enabled:Bool,status:String?) {
        spotifyToggle.state=enabled ? .on:.off;spotifyStatus.stringValue=status ?? "";spotifyStatus.isHidden=status == nil
    }
    func updateSpotifyLibrary(clientID:String,connected:Bool,connecting:Bool,status:String?) {
        if spotifyClientID.currentEditor()==nil { spotifyClientID.stringValue=clientID }
        spotifyClientID.isEnabled = !connected && !connecting
        spotifyConnect.isHidden=connected;spotifyConnect.isEnabled = !connecting
        spotifyConnect.title=connecting ? "Connecting…":"Connect Spotify…"
        spotifyDisconnect.isHidden = !connected && !connecting
        spotifyLibraryStatus.stringValue=status ?? (connected ? "Connected for saved songs.":"Connect to like songs. Playback controls work without signing in.")
    }
    @objc private func connectSpotify() { actions.spotifyConnect(spotifyClientID.stringValue) }
    @objc private func disconnectSpotify() { actions.spotifyDisconnect() }
    @objc private func changeSpotify() { actions.spotify(spotifyToggle.state == .on) }
    func windowDidBecomeKey(_ notification:Notification) { actions.refresh() }
    @objc private func changeDock() { actions.dock(dockToggle.state == .on) }
    @objc private func changeLogin() { actions.login() }
    @objc private func changeSize() { actions.size() }
    @objc private func changeColour() { if let value=colourPicker.selectedItem?.representedObject as? String { actions.colour(value) } }
    @objc private func openLoginSettings() { actions.loginSettings() }
}
