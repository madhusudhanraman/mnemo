import Cocoa
import ApplicationServices

// Use Spotify’s published scripting codes directly, without compiling or running scripts.
final class SpotifyPlayback {
    private let queue=DispatchQueue(label:"local.mnemo.spotify",qos:.utility)
    private var busy=false
    private var nextRead=Date.distantPast
    private var generation=0
    var enabled=false
    var onChange:(([String:Any])->Void)?
    var onStatus:((String?)->Void)?
    func setEnabled(_ value:Bool) {
        enabled=value;generation+=1;nextRead = .distantPast
        onChange?(["playing":false]);onStatus?(nil)
        if value { refresh(force:true) }
    }
    func refresh(force:Bool=false) {
        run(command:nil,force:force)
    }
    enum Command:String {
        case previous,next,toggle
        var eventID:String { switch self { case .previous:return "Prev";case .next:return "Next";case .toggle:return "PlPs" } }
    }
    func control(_ command:Command,completion:@escaping (String?)->Void) { run(command:command,force:true,completion:completion) }
    private func run(command:Command?,force:Bool,completion:((String?)->Void)?=nil) {
        guard enabled else { completion?("Enable Spotify on Hover in Settings.");return }
        guard !busy else { completion?("Spotify is updating. Try again.");return }
        guard force || Date()>=nextRead else { return }
        nextRead=Date().addingTimeInterval(5)
        guard NSRunningApplication.runningApplications(withBundleIdentifier:"com.spotify.client").contains(where:{!$0.isTerminated}) else {
            onChange?(["playing":false]);onStatus?("Open Spotify to show music on hover.");completion?("Spotify is not running.");return
        }
        busy=true
        let token=generation
        // Address the existing process so a read can never launch Spotify.
        guard let pid=NSRunningApplication.runningApplications(withBundleIdentifier:"com.spotify.client").first?.processIdentifier else { busy=false;completion?("Spotify is not running.");return }
        queue.async { [weak self] in
            var error:NSError?
            var title="",artist="",uri="",playing=false,available=false
            do {
                let target=NSAppleEventDescriptor(processIdentifier:pid)
                if let descriptor=target.aeDesc {
                    let permission=AEDeterminePermissionToAutomateTarget(descriptor,Self.code("****"),Self.code("****"),true)
                    if permission != noErr { throw NSError(domain:NSOSStatusErrorDomain,code:Int(permission)) }
                }
                var requestedPlaying:Bool?
                if command == .toggle {
                    let before=try Self.send(target:target,property:Self.property("pPlS"))
                    requestedPlaying=before.enumCodeValue != Self.code("kPSP")
                }
                if let command=command { _ = try Self.send(target:target,eventClass:"spfy",eventID:command.eventID) }
                let state=try Self.send(target:target,property:Self.property("pPlS"))
                // Spotify can acknowledge a command before its state property catches up.
                playing=requestedPlaying ?? (state.enumCodeValue == Self.code("kPSP"))
                // Read metadata using Spotify's observed state, not the requested
                // button state: a just-paused track may still report playing.
                if Self.hasCurrentTrack(state.enumCodeValue) {
                    let track=Self.property("pTrk")
                    title=try Self.send(target:target,property:Self.property("pnam",container:track)).stringValue ?? ""
                    artist=try Self.send(target:target,property:Self.property("pArt",container:track)).stringValue ?? ""
                    available = !title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
                    uri=(try? Self.send(target:target,property:Self.property("ID  ",container:track)))?.stringValue ?? ""
                }
            } catch let failure as NSError { error=failure }
            let denied=error?.code == -1743
            let failed=error != nil
            let errorCode=error?.code ?? 0
            DispatchQueue.main.async {
                guard let self=self else { return };self.busy=false
                guard token==self.generation,self.enabled else { completion?("Spotify integration was disabled.");return }
                if failed {
                    self.onChange?(["playing":false])
                    self.onStatus?(denied ? "Allow Mnemo → Spotify in System Settings → Privacy & Security → Automation.":"Spotify is unavailable (\(errorCode)). Try hovering again.")
                    // A denied permission should not repeatedly trigger requests on hover.
                    if denied { self.enabled=false }
                    completion?(denied ? "Allow Mnemo to control Spotify in Automation settings.":"Spotify could not complete the request.")
                } else {
                    self.onStatus?(nil)
                    self.onChange?(["playing":playing,"available":available,"title":title,"artist":artist,"uri":uri]);completion?(nil)
                    if command != nil {
                        DispatchQueue.main.asyncAfter(deadline:.now()+0.4) { [weak self] in
                            guard let self=self,self.enabled,self.generation==token else { return }
                            self.refresh(force:true)
                        }
                    }
                }
            }
        }
    }
    static func hasCurrentTrack(_ state:UInt32) -> Bool {
        state == code("kPSP") || state == code("kPSp")
    }
    static func code(_ text:String) -> UInt32 { text.utf8.reduce(0){($0<<8)|UInt32($1)} }
    static func property(_ name:String,container:NSAppleEventDescriptor = .null()) -> NSAppleEventDescriptor {
        let record=NSAppleEventDescriptor.record()
        record.setDescriptor(NSAppleEventDescriptor(typeCode:code("prop")),forKeyword:code("want"))
        record.setDescriptor(NSAppleEventDescriptor(enumCode:code("prop")),forKeyword:code("form"))
        record.setDescriptor(NSAppleEventDescriptor(typeCode:code(name)),forKeyword:code("seld"))
        record.setDescriptor(container,forKeyword:code("from"))
        return record.coerce(toDescriptorType:code("obj "))!
    }
    static func send(target:NSAppleEventDescriptor,property:NSAppleEventDescriptor?=nil,eventClass:String="core",eventID:String="getd") throws -> NSAppleEventDescriptor {
        let event=NSAppleEventDescriptor(eventClass:code(eventClass),eventID:code(eventID),targetDescriptor:target,returnID:-1,transactionID:0)
        if let property=property { event.setParam(property,forKeyword:code("----")) }
        let response=try event.sendEvent(options:[.waitForReply,.canInteract],timeout:5)
        if let error=response.paramDescriptor(forKeyword:code("errn")),error.int32Value != 0 { throw NSError(domain:NSOSStatusErrorDomain,code:Int(error.int32Value)) }
        return response.paramDescriptor(forKeyword:code("----")) ?? .null()
    }

}
