import Foundation

struct Reminder: Codable {
    var id: String
    var text: String
    var dueAt: Double
    var status: String
    var createdAt: Double
}

enum ReminderError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
}

final class ReminderStore {
    let url: URL
    private(set) var reminders: [Reminder]
    init(url: URL) throws {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            do { reminders = try JSONDecoder().decode([Reminder].self, from: Data(contentsOf: url)) }
            catch { throw ReminderError.invalid("Saved reminders could not be read. The original file has not been changed: \(url.path)") }
        } else { reminders = [] }
    }
    private func commit(_ rows: [Reminder]) throws {
        let data = try JSONEncoder().encode(rows)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        reminders = rows
    }
    func save(id: String?, text: String, dueAt: Double, now: Double = Date().timeIntervalSince1970 * 1000) throws {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 280 else { throw ReminderError.invalid("Use between 1 and 280 characters for a reminder.") }
        guard dueAt.isFinite, dueAt > now else { throw ReminderError.invalid("Choose a reminder time in the future.") }
        var rows = reminders
        if let id = id {
            guard let index = rows.firstIndex(where: { $0.id == id }) else { throw ReminderError.invalid("That reminder no longer exists.") }
            rows[index].text = value; rows[index].dueAt = dueAt; rows[index].status = "pending"
        } else {
            rows.append(Reminder(id: UUID().uuidString, text: value, dueAt: dueAt, status: "pending", createdAt: now))
        }
        try commit(rows)
    }
    func action(id: String, action: String, now: Double = Date().timeIntervalSince1970 * 1000) throws {
        var rows = reminders
        guard let index = rows.firstIndex(where: { $0.id == id }) else { throw ReminderError.invalid("That reminder no longer exists.") }
        switch action {
        case "done": rows[index].status = "done"
        case "snooze": rows[index].status = "pending"; rows[index].dueAt = now + 3 * 60 * 60 * 1000
        case "delete": rows.remove(at: index)
        default: throw ReminderError.invalid("Unknown reminder action.")
        }
        try commit(rows)
    }
    @discardableResult func checkDue(now: Double = Date().timeIntervalSince1970 * 1000) throws -> [Reminder] {
        var rows = reminders; var due: [Reminder] = []
        for index in rows.indices where rows[index].status == "pending" && rows[index].dueAt <= now {
            rows[index].status = "due"; due.append(rows[index])
        }
        if !due.isEmpty { try commit(rows) }
        return due
    }
    func json() throws -> String { String(decoding: try JSONEncoder().encode(reminders), as: UTF8.self) }
}
