import SwiftUI
import AppKit

/// The workspace for one idea: its plan (steps) and thoughts.
struct CounterView: View {
    @EnvironmentObject var store: Store
    let id: UUID
    let onClose: () -> Void

    @Environment(\.zoom) private var zoom
    @State private var compose = ""
    @State private var kind: EntryKind = .thought
    @State private var lastAdded: UUID?
    /// The step/note whose thread is open (only one at a time).
    @State private var openEntry: UUID?
    @State private var focusThread = false

    var body: some View {
        if let item = store.item(id) {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 30) {
                            header(item)
                            if !item.steps.isEmpty { plan(item) }
                            if !item.thoughts.isEmpty { thoughts(item) }
                        }
                        .padding(.horizontal, 48 * zoom)
                        .padding(.top, 56)
                        .padding(.bottom, 28)
                        .frame(maxWidth: 760 * zoom, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.never)
                    .onChange(of: lastAdded) { _, new in
                        guard let new else { return }
                        withAnimation(spring) { proxy.scrollTo(new, anchor: .center) }
                    }
                }
                composer
            }
        }
    }

    // MARK: Header

    private func header(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                Loaf(stage: item.stage, px: 4, steam: true)
                Spacer()
                Button {
                    withAnimation(spring) { store.toggleDone(id) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.done ? "arrow.uturn.backward" : "flame.fill")
                        Text(item.done ? "Back in the oven" : "Mark as baked")
                    }
                    .pixelFont(15)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .glass(99)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                Button {
                    onClose()
                    withAnimation(spring) { store.delete(id) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                        .frame(width: 28, height: 26)
                        .glass(99)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Delete idea")
            }
            InkEditor(text: store.title(id), placeholder: "Untitled", fontSize: 32, pixel: true,
                      onSubmit: { focus("counter") }, onEscape: { focus("counter") })
        }
    }

    // MARK: Plan

    private func plan(_ item: Item) -> some View {
        let steps = item.steps
        let doneCount = steps.filter(\.done).count
        let progress = steps.isEmpty ? 0 : Double(doneCount) / Double(steps.count)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recipe").pixelLabel()
                Spacer()
            }
            PixelProgress(value: progress)
                .animation(spring, value: progress)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(steps) { step in
                    StepRow(itemID: id, step: step, tint: item.color,
                            openEntry: $openEntry, focusThread: $focusThread).id(step.id)
                }
            }
            .padding(.vertical, 6)
            .glass(18)
        }
    }

    // MARK: Thoughts

    private func thoughts(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes").pixelLabel()
            ForEach(item.thoughts) { t in
                ThoughtCard(itemID: id, entry: t, tint: item.color,
                            openEntry: $openEntry, focusThread: $focusThread).id(t.id)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    // MARK: Composer

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    toggleKind()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: kind.symbol)
                        Text(kind.label)
                    }
                    .pixelFont(15)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.honey.opacity(0.3), in: RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.border, lineWidth: 1.5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Switch between a thought and a plan step (tab)")
                .padding(.top, 1)

                InkEditor(text: $compose,
                          placeholder: kind == .thought ? "Add a thought, a detail, a question…" : "Add a step to the plan…",
                          fontSize: 16, maxHeight: 140, autofocus: true, focusID: "counter",
                          onSubmit: add, onEscape: onClose,
                          onTab: { toggleKind(); return true })
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glass(4, strong: true)

        }
        .frame(maxWidth: 680 * zoom)
        .padding(.horizontal, 40)
        .padding(.bottom, 18)
        .padding(.top, 6)
    }

    private func toggleKind() {
        withAnimation(.easeOut(duration: 0.15)) { kind = kind == .thought ? .step : .thought }
    }

    private func add() {
        let text = compose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        compose = ""
        withAnimation(spring) { lastAdded = store.addEntry(to: id, text: text, kind: kind) }
    }
}

struct StepRow: View {
    @EnvironmentObject var store: Store
    @Environment(\.zoom) private var zoom
    let itemID: UUID
    let step: Entry
    let tint: Color
    @Binding var openEntry: UUID?
    @Binding var focusThread: Bool
    @State private var hover = false

    private var expanded: Bool { openEntry == step.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            row
            if expanded {
                EntryThread(itemID: itemID, entry: step, tint: tint, autofocus: focusThread, onClose: collapse)
                    .padding(.leading, 28 * zoom)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 3)
            .fill(expanded ? Theme.honey.opacity(0.14) : (hover ? Theme.honey.opacity(0.08) : .clear))
            .padding(.horizontal, 6))
        .background(Color.clear.contentShape(Rectangle())
            .onTapGesture { if !expanded { open(focusComposer: true) } })
        .onHover { hover = $0 }
    }

    private func open(focusComposer: Bool) {
        focusThread = focusComposer
        withAnimation(spring) { openEntry = step.id }
    }

    private func collapse() {
        withAnimation(spring) { openEntry = nil }
        focus("counter")
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(spring) { store.updateEntry(itemID, step.id) { $0.done.toggle() } }
            } label: {
                ZStack {
                    Rectangle().fill(step.done ? Theme.honey : Theme.card)
                    Rectangle().strokeBorder(Theme.border, lineWidth: 2)
                    if step.done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Sprites.outline)
                    }
                }
                .frame(width: 16 * zoom, height: 16 * zoom)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(step.done ? "Undo step: \(step.text)" : "Complete step: \(step.text)")
            .padding(.top, 3)

            if step.done {
                Text(step.text)
                    .bookFont(15)
                    .strikethrough(color: Theme.ink.opacity(0.3))
                    .foregroundStyle(Theme.ink.opacity(0.42))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                    .contentShape(Rectangle())
                    .onTapGesture { if !expanded { open(focusComposer: true) } }
            } else {
                InkEditor(text: store.entryText(itemID, step.id), fontSize: 15,
                          onSubmit: { focus("counter") }, onEscape: collapse,
                          onBlur: removeIfEmpty,
                          onFocus: { if !expanded { open(focusComposer: false) } })
            }

            ThreadToggle(count: step.notes.count, expanded: Binding(
                get: { expanded },
                set: { v in focusThread = true; openEntry = v ? step.id : nil }), visible: hover)
                .padding(.top, 2)
            trash
        }
    }

    private var trash: some View {
        Button {
            withAnimation(spring) { store.deleteEntry(itemID, step.id) }
        } label: {
            Image(systemName: "xmark").font(.system(size: 9.5, weight: .semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink.opacity(0.4))
        .padding(.top, 5)
        .opacity(hover ? 1 : 0)
        .help("Remove step")
    }

    private func removeIfEmpty() {
        let t = store.item(itemID)?.entries.first { $0.id == step.id }?.text ?? ""
        if t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            withAnimation(spring) { store.deleteEntry(itemID, step.id) }
        }
    }
}

struct ThoughtCard: View {
    @EnvironmentObject var store: Store
    let itemID: UUID
    let entry: Entry
    let tint: Color
    @Binding var openEntry: UUID?
    @Binding var focusThread: Bool
    @State private var hover = false

    private var expanded: Bool { openEntry == entry.id }

    private func open(focusComposer: Bool) {
        focusThread = focusComposer
        withAnimation(spring) { openEntry = entry.id }
    }

    private func collapse() {
        withAnimation(spring) { openEntry = nil }
        focus("counter")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [tint, tint.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                .frame(width: 2.5)
                .shadow(color: tint.opacity(0.7), radius: 4)
                .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 8) {
                InkEditor(text: store.entryText(itemID, entry.id), fontSize: 15,
                          onSubmit: { focus("counter") }, onEscape: collapse,
                          onBlur: {
                              let t = store.item(itemID)?.entries.first { $0.id == entry.id }?.text ?? ""
                              if t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                  withAnimation(spring) { store.deleteEntry(itemID, entry.id) }
                              }
                          },
                          onFocus: { if !expanded { open(focusComposer: false) } })
                if expanded {
                    EntryThread(itemID: itemID, entry: entry, tint: tint, autofocus: focusThread, onClose: collapse)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.leading, 14)
        }
        .padding(.leading, 16)
        .padding(.trailing, 64)
        .padding(.vertical, 14)
        .background(Color.clear.contentShape(Rectangle())
            .onTapGesture { if !expanded { open(focusComposer: true) } })
        .glass(16, strong: expanded)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 2) {
            ThreadToggle(count: entry.notes.count, expanded: Binding(
                get: { expanded },
                set: { v in focusThread = true; openEntry = v ? entry.id : nil }), visible: hover)
            Button {
                withAnimation(spring) { store.deleteEntry(itemID, entry.id) }
            } label: {
                Image(systemName: "xmark").font(.system(size: 9.5, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.ink.opacity(0.4))
            .padding(6)
            .opacity(hover ? 1 : 0)
            }
            .padding(6)
        }
        .onHover { hover = $0 }
    }
}

/// The ↳ button that opens an entry's thread. Always visible once it has notes.
struct ThreadToggle: View {
    let count: Int
    @Binding var expanded: Bool
    let visible: Bool

    var body: some View {
        Button {
            withAnimation(spring) { expanded.toggle() }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: expanded ? "chevron.up" : "arrow.turn.down.right")
                    .font(.system(size: 9.5, weight: .semibold))
                if count > 0 && !expanded {
                    Text("\(count)").pixelFont(14)
                }
            }
            .foregroundStyle(count > 0 || expanded ? Theme.accent : Theme.ink.opacity(0.45))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(count > 0 || expanded ? Theme.honey.opacity(0.28) : .clear, in: RoundedRectangle(cornerRadius: 3))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(expanded ? "Close" : "Open — add findings, answers, notes")
        .opacity(visible || count > 0 || expanded ? 1 : 0)
    }
}

/// Findings / answers / follow-ups nested under a step or thought.
struct EntryThread: View {
    @EnvironmentObject var store: Store
    let itemID: UUID
    let entry: Entry
    let tint: Color
    var autofocus = true
    let onClose: () -> Void
    @State private var compose = ""

    private var composerID: String { "note-\(entry.id)" }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 1)
                .fill(LinearGradient(colors: [tint.opacity(0.9), tint.opacity(0.1)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 1.5)
                .shadow(color: tint.opacity(0.6), radius: 3)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(entry.notes) { note in
                    NoteRow(itemID: itemID, entryID: entry.id, note: note, composerID: composerID)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                InkEditor(text: $compose,
                          placeholder: entry.kind == .step ? "Add a finding…" : "Add to this…",
                          fontSize: 14, maxHeight: 120, autofocus: autofocus, focusID: composerID,
                          onSubmit: add, onEscape: onClose)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .glass(10)
            }
        }
    }

    private func add() {
        let text = compose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        compose = ""
        withAnimation(spring) { _ = store.addNote(itemID, entry.id, text: text) }
    }
}

struct NoteRow: View {
    @EnvironmentObject var store: Store
    let itemID: UUID
    let entryID: UUID
    let note: Note
    let composerID: String
    @State private var hover = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Theme.ink.opacity(0.25)).frame(width: 4, height: 4).padding(.top, 9)
            InkEditor(text: store.noteText(itemID, entryID, note.id), fontSize: 14,
                      onSubmit: { focus(composerID) }, onEscape: { focus(composerID) },
                      onBlur: {
                          let t = store.item(itemID)?.entries.first { $0.id == entryID }?
                              .notes.first { $0.id == note.id }?.text ?? ""
                          if t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                              withAnimation(spring) { store.deleteNote(itemID, entryID, note.id) }
                          }
                      })
            Button {
                withAnimation(spring) { store.deleteNote(itemID, entryID, note.id) }
            } label: {
                Image(systemName: "xmark").font(.system(size: 8.5, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.ink.opacity(0.4))
            .padding(.top, 5)
            .opacity(hover ? 1 : 0)
        }
        .onHover { hover = $0 }
    }
}
