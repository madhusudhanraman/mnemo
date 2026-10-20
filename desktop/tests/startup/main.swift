import Foundation

// A child process proves exclusivity across processes, not just within one test.
if CommandLine.arguments.count>2,CommandLine.arguments[1]=="--probe" {
    let lock=try InstanceLock(url:URL(fileURLWithPath:CommandLine.arguments[2]))
    print(lock == nil ? "busy":"acquired")
    exit(0)
}
final class FakeLoginService:LoginItemService {
    var state=LoginItemState.disabled
    var registrationCount=0,unregistrationCount=0
    var error:Error?
    func register() throws { if let error=error { throw error };registrationCount+=1;state = .enabled }
    func unregister() throws { if let error=error { throw error };unregistrationCount+=1;state = .disabled }
}
let service=FakeLoginService(),controller=LoginItemController(service:FakeLoginService())
assert(controller.state == .disabled,"Constructing the controller must not register login startup")
let login=LoginItemController(service:service)
try login.toggle();assert(service.registrationCount==1 && login.state == .enabled)
try login.toggle();assert(service.unregistrationCount==1 && login.state == .disabled)
service.state = .requiresApproval
assert(login.state == .requiresApproval,"Approval pending must not be reported as enabled")
try login.toggle();assert(service.unregistrationCount==2,"Pending registration can be disabled")
service.error=NSError(domain:"test",code:42)
do { try login.toggle();assertionFailure("Registration errors must propagate") } catch { assert(login.state == .disabled) }
service.error=nil;service.state = .unavailable
do { try login.toggle();assertionFailure("Unavailable services must not register") } catch { assert(service.registrationCount==1) }
service.state = .notFound
try login.toggle();assert(service.registrationCount==2 && login.state == .enabled,"Not-found status must allow a real registration attempt")
final class SlowLoginService:LoginItemService {
    var state=LoginItemState.disabled
    let entered=DispatchSemaphore(value:0),release=DispatchSemaphore(value:0)
    func register() throws { entered.signal();release.wait();state = .enabled }
    func unregister() throws { state = .disabled }
}
let slow=SlowLoginService()
let slowController=LoginItemController(service:slow)
var completionRan=false,mainWorkRan=false
slowController.toggleAsync { state,error in
    assert(Thread.isMainThread && error == nil && state == .enabled)
    completionRan=true
}
assert(slow.entered.wait(timeout:.now()+2) == .success)
DispatchQueue.main.async { mainWorkRan=true }
RunLoop.main.run(until:Date().addingTimeInterval(0.05))
assert(mainWorkRan && !completionRan,"A blocked registration must not block the main UI queue")
slow.release.signal()
let deadline=Date().addingTimeInterval(2)
while !completionRan && Date()<deadline { RunLoop.main.run(until:Date().addingTimeInterval(0.01)) }
assert(completionRan)
let root=FileManager.default.temporaryDirectory.appendingPathComponent("mnemo-startup-tests-"+UUID().uuidString)
defer { try? FileManager.default.removeItem(at:root) }
let url=root.appendingPathComponent("instance.lock")
var held:InstanceLock?=try InstanceLock(url:url)
assert(held != nil)
func probe() throws -> String {
    let child=Process(),pipe=Pipe();child.executableURL=URL(fileURLWithPath:CommandLine.arguments[0]);child.arguments=["--probe",url.path];child.standardOutput=pipe
    try child.run();child.waitUntilExit();assert(child.terminationStatus==0)
    return String(data:pipe.fileHandleForReading.readDataToEndOfFile(),encoding:.utf8)!.trimmingCharacters(in:.whitespacesAndNewlines)
}
let blocked=try probe();assert(blocked=="busy","Second process must not obtain a live instance lock")
held=nil
let released=try probe();assert(released=="acquired","Lock must be released when its owner exits or closes it")
let again=try probe();assert(again=="acquired","Child exit releases its lock without deleting the lock file")
assert(AppInstallation.sameLocation(root.appendingPathComponent("Mnemo.app"),root.appendingPathComponent("./Mnemo.app")))
print("PASS: login opt-in, on/off, approval, failures, unavailable service, not-found recovery, nonblocking registration, cross-process instance exclusion and release.")
