import Cocoa
import ServiceManagement
import Darwin

enum LoginItemState { case disabled, enabled, requiresApproval, notFound, unavailable }
protocol LoginItemService {
    var state:LoginItemState { get }
    func register() throws
    func unregister() throws
}
struct SystemLoginItemService:LoginItemService {
    var state:LoginItemState {
        switch SMAppService.mainApp.status {
        case .notRegistered:return .disabled
        case .enabled:return .enabled
        case .requiresApproval:return .requiresApproval
        case .notFound:return .notFound
        @unknown default:return .unavailable
        }
    }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}
final class LoginItemController {
    let service:LoginItemService
    private let queue=DispatchQueue(label:"local.mnemo.login-registration",qos:.utility)
    init(service:LoginItemService=SystemLoginItemService()) { self.service=service }
    var state:LoginItemState { service.state }
    func toggleAsync(completion:@escaping (LoginItemState,Error?) -> Void) {
        queue.async {
            var failure:Error?
            do { try self.toggle() } catch { failure=error }
            let state=self.state
            DispatchQueue.main.async { completion(state,failure) }
        }
    }
    func toggle() throws {
        switch state {
        case .enabled,.requiresApproval:try service.unregister()
        case .disabled,.notFound:try service.register()
        case .unavailable:throw NSError(domain:"Mnemo",code:1,userInfo:[NSLocalizedDescriptionKey:"Mnemo could not be found for login registration. Reinstall the app and try again."])
        }
    }
}

// The kernel releases the lock on exit, including crashes. Never unlink the lock file.
final class InstanceLock {
    private let descriptor:Int32
    init?(url:URL) throws {
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        let fd=Darwin.open(url.path,O_CREAT|O_RDWR|O_CLOEXEC,mode_t(0o600))
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue:errno) ?? .EIO) }
        if flock(fd,LOCK_EX|LOCK_NB) != 0 {
            let error=errno;Darwin.close(fd)
            if error == EWOULDBLOCK { return nil }
            throw POSIXError(POSIXErrorCode(rawValue:error) ?? .EIO)
        }
        descriptor=fd
    }
    deinit { Darwin.close(descriptor) }
}

enum AppInstallation {
    static let bundleID="local.mnemo.companion"
    static let revealNotification=Notification.Name("local.mnemo.companion.reveal")
    static var userURL:URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Mnemo.app") }
    static var installedURL:URL {
        if FileManager.default.fileExists(atPath:userURL.path) { return userURL }
        let system=URL(fileURLWithPath:"/Applications/Mnemo.app")
        return FileManager.default.fileExists(atPath:system.path) ? system:userURL
    }
    static func sameLocation(_ a:URL,_ b:URL) -> Bool { a.resolvingSymlinksInPath().standardizedFileURL == b.resolvingSymlinksInPath().standardizedFileURL }
    static var isInstalled:Bool { sameLocation(Bundle.main.bundleURL,installedURL) }
    static func revealRunningCopy() {
        let others=NSRunningApplication.runningApplications(withBundleIdentifier:bundleID).filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }
        if let running=others.first { running.activate(options:[]) }
        DistributedNotificationCenter.default().postNotificationName(revealNotification,object:nil,userInfo:nil,deliverImmediately:true)
    }
}
