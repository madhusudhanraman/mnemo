import Foundation

func check(_ condition: @autoclosure () throws -> Bool, _ message: String) { do { if try condition() == false { fatalError(message) } } catch { fatalError("\(message): \(error)") } }
let directory=URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("mnemo-store-tests-\(UUID().uuidString)")
let file=directory.appendingPathComponent("reminders.json")
defer { try? FileManager.default.removeItem(at:directory) }
let store=try ReminderStore(url:file)
try store.save(id:nil,text:"  Water the plants  ",dueAt:2000,now:1000)
let id=store.reminders[0].id
check(store.reminders[0].text=="Water the plants","Trim text")
check(try ReminderStore(url:file).reminders.count==1,"Save persists")
check(try store.checkDue(now:1999).isEmpty,"Must not fire early")
check(try store.checkDue(now:2000).count==1,"Fire at deadline")
check(try store.checkDue(now:3000).isEmpty,"Do not re-fire a due reminder")
try store.action(id:id,action:"snooze",now:3000)
check(store.reminders[0].dueAt==10803000,"Remind Me Later postpones three hours")
check(store.reminders[0].status=="pending","Later rearms")
check(try ReminderStore(url:file).reminders[0].dueAt==10803000,"Postponement survives restart")
check(try store.checkDue(now:10802999).isEmpty,"Postponement must not fire early")
check(try store.checkDue(now:10804000).count==1,"Catch up after sleep")
try store.action(id:id,action:"done")
check(try store.checkDue(now:999999999).isEmpty,"Completed does not re-fire")
try store.save(id:id,text:"Edited",dueAt:2000000,now:1000)
check(store.reminders.count==1 && store.reminders[0].text=="Edited","Edit in place")
do { try store.save(id:nil,text:" ",dueAt:3000,now:1000);fatalError("Blank must reject") } catch {}
do { try store.save(id:nil,text:"Past",dueAt:500,now:1000);fatalError("Past must reject") } catch {}
try store.action(id:id,action:"delete")
check(try ReminderStore(url:file).reminders.isEmpty,"Delete persists")
try Data("invalid-json".utf8).write(to:file)
do { _=try ReminderStore(url:file);fatalError("Corruption must not silently reset") } catch {}
check(try String(contentsOf:file,encoding:.utf8)=="invalid-json","Preserve corrupt original")
print("PASS: persistence, validation, exact deadline, no duplicate firing, snooze, wake catch-up, edit, completion, delete and corruption preservation.")
