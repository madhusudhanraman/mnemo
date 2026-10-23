import Foundation

struct Reminder: Codable {
    var id: String
    var text: String
    var dueAt: Double?
    var status: String
    var createdAt: Double
    var projectID: String? = nil
    var notes: String? = nil
}
struct MnemoProject: Codable {
    var id: String
    var name: String
    var space: String
    var createdAt: Double
}
private struct ReminderDocument: Codable {
    var version: Int
    var reminders: [Reminder]
    var projects: [MnemoProject]
}
enum ReminderError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
}
final class ReminderStore {
    let url: URL
    private(set) var reminders: [Reminder]
    private(set) var projects: [MnemoProject] = []
    private var legacyFormat=false
    init(url: URL) throws {
        self.url=url
        if FileManager.default.fileExists(atPath:url.path) {
            do {
                let data=try Data(contentsOf:url)
                if let legacy=try? JSONDecoder().decode([Reminder].self,from:data) {
                    reminders=legacy;legacyFormat=true
                } else {
                    let document=try JSONDecoder().decode(ReminderDocument.self,from:data)
                    guard document.version==2 else { throw ReminderError.invalid("Unsupported saved data version.") }
                    reminders=document.reminders;projects=document.projects
                }
            } catch { throw ReminderError.invalid("Saved reminders could not be read. The original file has not been changed: \(url.path)") }
        } else { reminders=[] }
    }
    private func commit(_ rows:[Reminder],projects updated:[MnemoProject]?=nil) throws {
        let nextProjects=updated ?? projects
        let data=try JSONEncoder().encode(ReminderDocument(version:2,reminders:rows,projects:nextProjects))
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        // Preserve the original array before the first write in the project-aware format.
        if legacyFormat {
            let backup=url.deletingPathExtension().appendingPathExtension("before-projects.json")
            if !FileManager.default.fileExists(atPath:backup.path) { try FileManager.default.copyItem(at:url,to:backup) }
        }
        try data.write(to:url,options:.atomic)
        reminders=rows;projects=nextProjects;legacyFormat=false
    }
    func saveProject(id:String?=nil,name:String,space:String,now:Double=Date().timeIntervalSince1970*1000) throws {
        let value=name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !value.isEmpty,value.count<=80,["Work","Home"].contains(space) else { throw ReminderError.invalid("Choose Work or Home and a project name of 1–80 characters.") }
        guard !projects.contains(where:{$0.id != id && $0.space==space && $0.name.caseInsensitiveCompare(value) == .orderedSame}) else { throw ReminderError.invalid("A project with that name already exists here.") }
        var rows=projects
        if let id=id {
            guard let index=rows.firstIndex(where:{$0.id==id}) else { throw ReminderError.invalid("That project no longer exists.") }
            rows[index].name=value;rows[index].space=space
        } else { rows.append(MnemoProject(id:UUID().uuidString,name:value,space:space,createdAt:now)) }
        try commit(reminders,projects:rows)
    }
    func save(id:String?,text:String,dueAt:Double?,projectID:String?=nil,notes:String?=nil,now:Double=Date().timeIntervalSince1970*1000) throws {
        let value=text.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !value.isEmpty,value.count<=280 else { throw ReminderError.invalid("Use between 1 and 280 characters for a reminder.") }
        if let projectID=projectID { guard projects.contains(where:{$0.id==projectID}) else { throw ReminderError.invalid("That project no longer exists.") } }
        if let dueAt=dueAt { guard dueAt.isFinite,dueAt>now else { throw ReminderError.invalid("Choose a reminder time in the future.") } }
        else if projectID == nil { throw ReminderError.invalid("Choose a reminder time, or add this task to a project.") }
        let note=notes?.trimmingCharacters(in:.whitespacesAndNewlines)
        guard (note?.count ?? 0)<=10000 else { throw ReminderError.invalid("Keep notes within 10,000 characters.") }
        let savedNote=note?.isEmpty == false ? note:nil
        let status=dueAt == nil ? "task":"pending"
        var rows=reminders
        if let id=id {
            guard let index=rows.firstIndex(where:{$0.id==id}) else { throw ReminderError.invalid("That reminder no longer exists.") }
            rows[index].text=value;rows[index].dueAt=dueAt;rows[index].status=status;rows[index].projectID=projectID;rows[index].notes=savedNote
        } else { rows.append(Reminder(id:UUID().uuidString,text:value,dueAt:dueAt,status:status,createdAt:now,projectID:projectID,notes:savedNote)) }
        try commit(rows)
    }
    func action(id:String,action:String,now:Double=Date().timeIntervalSince1970*1000) throws {
        var rows=reminders
        guard let index=rows.firstIndex(where:{$0.id==id}) else { throw ReminderError.invalid("That reminder no longer exists.") }
        switch action {
        case "done": rows[index].status="done"
        case "reopen": rows[index].status=rows[index].dueAt.map({$0<=now ? "due":"pending"}) ?? "task"
        case "snooze":
            guard rows[index].dueAt != nil else { throw ReminderError.invalid("This task has no reminder to postpone.") }
            rows[index].status="pending";rows[index].dueAt=now+3*60*60*1000
        case "delete": rows.remove(at:index)
        default: throw ReminderError.invalid("Unknown reminder action.")
        }
        try commit(rows)
    }
    @discardableResult func checkDue(now:Double=Date().timeIntervalSince1970*1000) throws -> [Reminder] {
        var rows=reminders;var due:[Reminder]=[]
        for index in rows.indices where rows[index].status=="pending" && (rows[index].dueAt.map({$0<=now}) ?? false) {
            rows[index].status="due";due.append(rows[index])
        }
        if !due.isEmpty { try commit(rows) };return due
    }
    func projectsJSON() throws -> String { String(decoding:try JSONEncoder().encode(projects),as:UTF8.self) }
    func json() throws -> String {
        let data=try JSONEncoder().encode(reminders)
        var rows=try JSONSerialization.jsonObject(with:data) as! [[String:Any]]
        for index in rows.indices {
            if let id=reminders[index].projectID,let project=projects.first(where:{$0.id==id}) {
                rows[index]["projectName"]=project.name;rows[index]["projectSpace"]=project.space
            }
        }
        return String(decoding:try JSONSerialization.data(withJSONObject:rows),as:UTF8.self)
    }
}
