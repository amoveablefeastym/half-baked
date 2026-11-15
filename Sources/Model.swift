import SwiftUI

enum EntryKind: String, Codable {
    case thought, step
    var label: String { self == .thought ? "Note" : "Step" }
    var symbol: String { self == .thought ? "pencil" : "list.number" }
}

/// A finding, answer or follow-up attached to a step or thought.
struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var created = Date()
}

struct Entry: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var kind: EntryKind
    var done = false
    var created = Date()
    var notes: [Note] = []

    init(text: String, kind: EntryKind, created: Date = Date()) {
        self.text = text
        self.kind = kind
        self.created = created
    }

    private enum CodingKeys: String, CodingKey { case id, text, kind, done, created, notes }

    // Tolerant decoding so entries saved before notes existed still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        kind = try c.decodeIfPresent(EntryKind.self, forKey: .kind) ?? .thought
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        notes = try c.decodeIfPresent([Note].self, forKey: .notes) ?? []
    }
}

struct Item: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var entries: [Entry] = []
    var done = false
    var created = Date()
    var doneAt: Date? = nil

    init(title: String) { self.title = title }

    var steps: [Entry] { entries.filter { $0.kind == .step } }
    var thoughts: [Entry] { entries.filter { $0.kind == .thought } }

    var meta: String {
        var parts: [String] = []
        let s = steps
        if !s.isEmpty { parts.append("\(s.filter(\.done).count)/\(s.count) steps") }
        let t = thoughts.count
        if t > 0 { parts.append("\(t) thought\(t == 1 ? "" : "s")") }
        return parts.isEmpty ? created.formatted(.relative(presentation: .named)) : parts.joined(separator: " · ")
    }

    // Tolerant decoding so older saves (which had a `notes` string) still load.
    private enum CodingKeys: String, CodingKey { case id, title, entries, done, created, doneAt, notes }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        entries = try c.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        doneAt = try c.decodeIfPresent(Date.self, forKey: .doneAt)
        if entries.isEmpty, let notes = try c.decodeIfPresent(String.self, forKey: .notes),
           !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entries = [Entry(text: notes, kind: .thought, created: created)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(entries, forKey: .entries)
        try c.encode(done, forKey: .done)
        try c.encode(created, forKey: .created)
        try c.encodeIfPresent(doneAt, forKey: .doneAt)
    }
}

@MainActor
final class Store: ObservableObject {
    @Published var items: [Item] = [] {
        didSet { if loaded { save() } }
    }
    @Published var recentlyDeleted: Item?
    private var loaded = false

    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Half-Baked", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("items.json")
    }()

    init() {
        if let data = try? Data(contentsOf: url) {
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            items = (try? dec.decode([Item].self, from: data)) ?? []
        }
        loaded = true
    }

    private func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(items) { try? data.write(to: url, options: .atomic) }
    }

    var open: [Item] { items.filter { !$0.done }.sorted { $0.created > $1.created } }
    var baked: [Item] {
        items.filter(\.done).sorted { ($0.doneAt ?? $0.created) > ($1.doneAt ?? $1.created) }
    }

    func item(_ id: UUID) -> Item? { items.first { $0.id == id } }

    @discardableResult
    func add(_ title: String) -> Item {
        let item = Item(title: title)
        items.append(item)
        return item
    }

    func update(_ id: UUID, _ change: (inout Item) -> Void) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
    }

    func toggleDone(_ id: UUID) {
        update(id) { $0.done.toggle(); $0.doneAt = $0.done ? Date() : nil }
    }

    func delete(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        recentlyDeleted = items.remove(at: i)
    }

    func undoDelete() {
        guard let item = recentlyDeleted else { return }
        items.append(item)
        recentlyDeleted = nil
    }

    func title(_ id: UUID) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.item(id)?.title ?? "" },
            set: { [weak self] v in self?.update(id) { $0.title = v } }
        )
    }

    // MARK: Entries (the stuff on an idea's counter)

    @discardableResult
    func addEntry(to id: UUID, text: String, kind: EntryKind) -> UUID {
        let e = Entry(text: text, kind: kind)
        update(id) { $0.entries.append(e) }
        return e.id
    }

    func updateEntry(_ id: UUID, _ eid: UUID, _ change: (inout Entry) -> Void) {
        update(id) { item in
            guard let j = item.entries.firstIndex(where: { $0.id == eid }) else { return }
            change(&item.entries[j])
        }
    }

    func deleteEntry(_ id: UUID, _ eid: UUID) {
        update(id) { $0.entries.removeAll { $0.id == eid } }
    }

    // MARK: Notes (findings inside a step or thought)

    @discardableResult
    func addNote(_ id: UUID, _ eid: UUID, text: String) -> UUID {
        let n = Note(text: text)
        updateEntry(id, eid) { $0.notes.append(n) }
        return n.id
    }

    func deleteNote(_ id: UUID, _ eid: UUID, _ nid: UUID) {
        updateEntry(id, eid) { $0.notes.removeAll { $0.id == nid } }
    }

    func noteText(_ id: UUID, _ eid: UUID, _ nid: UUID) -> Binding<String> {
        Binding(
            get: { [weak self] in
                self?.item(id)?.entries.first { $0.id == eid }?.notes.first { $0.id == nid }?.text ?? ""
            },
            set: { [weak self] v in
                self?.updateEntry(id, eid) { e in
                    if let k = e.notes.firstIndex(where: { $0.id == nid }) { e.notes[k].text = v }
                }
            }
        )
    }

    func entryText(_ id: UUID, _ eid: UUID) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.item(id)?.entries.first { $0.id == eid }?.text ?? "" },
            set: { [weak self] v in self?.updateEntry(id, eid) { $0.text = v } }
        )
    }
}
