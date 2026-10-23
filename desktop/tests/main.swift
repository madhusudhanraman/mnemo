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

try store.saveProject(name:"  Website  ",space:"Work",now:1000)
let work=store.projects[0].id
try store.saveProject(name:"Website",space:"Home",now:1000)
check(store.projects.count==2 && store.projects[0].name=="Website","Work and Home have independent project names")
do { try store.saveProject(name:"website",space:"Work");fatalError("Duplicate project must reject") } catch {}
do { try store.saveProject(name:"",space:"Home");fatalError("Blank project must reject") } catch {}
do { try store.saveProject(name:"Test",space:"Other");fatalError("Invalid space must reject") } catch {}
try store.save(id:nil,text:"Plan the layout",dueAt:nil,projectID:work,now:1000)
let task=store.reminders[0].id
check(store.reminders[0].status=="task" && store.reminders[0].dueAt==nil,"Tasks do not need reminder dates")
check(try store.checkDue(now:999999999).isEmpty,"Unscheduled tasks never announce")
try store.action(id:task,action:"done",now:3000)
try store.action(id:task,action:"reopen",now:3000)
check(store.reminders[0].status=="task","Reopen unscheduled task without inventing a deadline")
try store.save(id:nil,text:"Review",dueAt:2000,projectID:work,now:1000)
check(try store.checkDue(now:2000).count==1,"Project reminder fires at deadline")
let projectReminder=store.reminders[1].id
try store.saveProject(id:work,name:"New website",space:"Work",now:3000)
check(try store.json().contains("New website"),"Reminder label follows project renaming")
try store.action(id:projectReminder,action:"snooze",now:3000)
check(store.reminders[1].dueAt==10803000,"Project reminders postpone by three hours")
let reloaded=try ReminderStore(url:file)
check(reloaded.projects.count==2 && reloaded.reminders[0].projectID==work,"Projects and tasks persist together")
do { try store.save(id:nil,text:"Orphan",dueAt:nil,projectID:"missing");fatalError("Orphan task must reject") } catch {}
do { try store.save(id:nil,text:"No deadline",dueAt:nil);fatalError("Standalone reminder still needs a date") } catch {}
let legacyFile=directory.appendingPathComponent("legacy.json")
let legacy="[{\"id\":\"old\",\"text\":\"Existing reminder\",\"dueAt\":2000,\"status\":\"pending\",\"createdAt\":1000}]"
try Data(legacy.utf8).write(to:legacyFile)
let migrated=try ReminderStore(url:legacyFile)
check(try String(contentsOf:legacyFile,encoding:.utf8)==legacy,"Opening legacy data does not rewrite it")
try migrated.saveProject(name:"First project",space:"Home")
check(try String(contentsOf:directory.appendingPathComponent("legacy.before-projects.json"),encoding:.utf8)==legacy,"Original reminders are backed up before migration")
check(try ReminderStore(url:legacyFile).reminders[0].id=="old","Migration keeps existing reminder identity and deadline")
check(try migrated.checkDue(now:2000).count==1,"Migrated reminders still fire")
print("PASS: Work/Home projects, atomic task persistence, scheduling, completion/reopen, project labels, validation and legacy backup/migration.")
try Data("invalid-json".utf8).write(to:file)
do { _=try ReminderStore(url:file);fatalError("Corruption must not silently reset") } catch {}
check(try String(contentsOf:file,encoding:.utf8)=="invalid-json","Preserve corrupt original")
print("PASS: persistence, validation, exact deadline, no duplicate firing, snooze, wake catch-up, edit, completion, delete and corruption preservation.")
