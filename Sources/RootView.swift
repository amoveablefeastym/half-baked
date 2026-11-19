import SwiftUI
import AppKit

let spring = Animation.spring(response: 0.4, dampingFraction: 0.84)

func focus(_ id: String) {
    NotificationCenter.default.post(name: .focusInput, object: id)
}

private struct Ghost: Identifiable { let id = UUID(); let text: String }

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var selection: UUID?
    @State private var ghost: Ghost?
    @State private var ghostFlying = false
    @State private var justAdded: UUID?
    @Namespace private var ns

    var body: some View {
        GeometryReader { g in
            content(zoom: Self.zoom(for: g.size))
                .environment(\.zoom, Self.zoom(for: g.size))
        }
        .ignoresSafeArea()
    }

    /// 960×640 is 1×; bigger windows scale everything up, smaller ones down a little.
    static func zoom(for size: CGSize) -> CGFloat {
        let z = min(size.width / 960, size.height / 640)
        return (min(max(z, 0.8), 2.2) * 20).rounded() / 20
    }

    private func content(zoom: CGFloat) -> some View {
        HStack(spacing: 0) {
            Sidebar(selection: $selection, justAdded: justAdded, ns: ns)
                .frame(width: 264 * zoom)
                .background { ZStack { Theme.shelf; Gingham() }.ignoresSafeArea() }
            Rectangle().fill(Theme.border).frame(width: 2)
            ZStack {
                if let id = selection, store.item(id) != nil {
                    CounterView(id: id, onClose: { selection = nil })
                        .id(id)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                } else {
                    HomeView(ns: ns, onSubmit: launch)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.25), value: selection)
        .background(Theme.flour.ignoresSafeArea())
        .overlay(alignment: .topLeading) { ghostView(zoom) }
        .overlay(alignment: .bottom) { toast }
        .ignoresSafeArea()
        .tint(Theme.accent)
        .foregroundStyle(Theme.ink)
        .onReceive(NotificationCenter.default.publisher(for: .goHome)) { _ in
            selection = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focus("home") }
        }
    }

    // An idea typed on the home screen floats over into the Simmering list.
    private func launch(_ text: String) {
        let g = Ghost(text: text.components(separatedBy: .newlines).first ?? text)
        ghostFlying = false
        ghost = g
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.62)) { ghostFlying = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
            if ghost?.id == g.id { ghost = nil; ghostFlying = false }
            var id: UUID?
            withAnimation(spring) {
                id = store.add(text).id
                justAdded = id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeOut(duration: 1.0)) { if justAdded == id { justAdded = nil } }
            }
        }
    }

    @ViewBuilder
    private func ghostView(_ zoom: CGFloat) -> some View {
        if let ghost {
            Text(ghost.text)
                .pixelFont(30)
                .lineLimit(1)
                .frame(maxWidth: 540 * zoom, alignment: .leading)
                .scaleEffect(ghostFlying ? 0.45 : 1, anchor: .leading)
                .opacity(ghostFlying ? 0.15 : 1)
                .matchedGeometryEffect(id: ghostFlying ? "pot" : "input", in: ns,
                                       properties: .position, anchor: .leading, isSource: false)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let gone = store.recentlyDeleted {
            HStack(spacing: 12) {
                Text("Deleted")
                Button("Undo") { withAnimation(spring) { store.undoDelete() } }
                    .buttonStyle(.plain)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accent)
            }
            .pixelFont(16)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .glass(4, strong: true)
            .frame(maxWidth: 420)
            .padding(.bottom, 18)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: gone.id) {
                try? await Task.sleep(for: .seconds(5))
                withAnimation(spring) {
                    if store.recentlyDeleted?.id == gone.id { store.recentlyDeleted = nil }
                }
            }
        }
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @EnvironmentObject var store: Store
    @Binding var selection: UUID?
    let justAdded: UUID?
    let ns: Namespace.ID
    @State private var showBaked = false
    @State private var dropTarget: String?
    @State private var renaming: UUID?
    @AppStorage("pinned") private var pinned = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
            Button {
                selection = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focus("home") }
            } label: {
                HStack(spacing: 8) {
                    PixelSprite(rows: Sprites.dough, palette: Sprites.doughPalette, px: 1.5)
                    Text("New dough")
                    Spacer()
                }
                .pixelFont(16)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .glass(4, strong: selection == nil)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { pinned.toggle() } label: {
                Image(systemName: pinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(pinned ? Theme.accent : Theme.ink.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .glass(4, strong: pinned)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(pinned ? "Unpin — tuck away when I click elsewhere" : "Pin — stay open when I click elsewhere")
            }
            .padding(.horizontal, 12)
            .padding(.top, 44)

            HStack(spacing: 8) {
                Text("Rising").pixelLabel()
                Spacer()
                Text("\(store.open.count)")
                    .pixelFont(14)
                    .foregroundStyle(Theme.ink.opacity(0.4))
                    .contentTransition(.numericText())
                Button {
                    withAnimation(spring) { renaming = store.addShelf().id }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("New shelf — drag dough onto it to sort your ideas")
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 8)
            .overlay(alignment: .bottomLeading) {
                Color.clear.frame(width: 1, height: 1)
                    .matchedGeometryEffect(id: "pot", in: ns, anchor: .leading)
                    .padding(.leading, 56)
                    .offset(y: 14)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    looseGroup
                    ForEach(store.shelves) { shelf in
                        shelfGroup(shelf)
                            .transition(.opacity)
                    }
                    let baked = store.baked
                    if !baked.isEmpty {
                        Button {
                            withAnimation(spring) { showBaked.toggle() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .rotationEffect(.degrees(showBaked ? 90 : 0))
                                Text("Baked").pixelLabel()
                                Spacer()
                                Text("\(baked.count)")
                                    .pixelFont(14)
                            }
                            .foregroundStyle(Theme.ink.opacity(0.4))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.top, 20)
                        .padding(.bottom, 6)
                        if showBaked {
                            ForEach(baked) { item in card(item).transition(.opacity) }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.never)
        }
    }

    // MARK: Shelves

    private func risingCard(_ item: Item) -> some View {
        card(item)
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity))
    }

    /// Ideas not on any shelf. Also where you drop dough to take it off a shelf.
    private var looseGroup: some View {
        let loose = store.open(on: nil)
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(loose) { risingCard($0) }
            if loose.isEmpty && !store.shelves.isEmpty {
                dropHint("Drop here to take off a shelf", active: dropTarget == "loose")
            }
        }
        .padding(.bottom, 4)
        .modifier(DoughDrop(key: "loose", target: $dropTarget) { id in
            withAnimation(spring) { store.move(id, to: nil) }
        })
    }

    private func shelfGroup(_ shelf: Shelf) -> some View {
        let items = store.open(on: shelf.id)
        let key = shelf.id.uuidString
        return VStack(alignment: .leading, spacing: 3) {
            ShelfHeader(shelf: shelf, count: items.count, renaming: $renaming)
                .contextMenu {
                    Button("Rename Shelf") { renaming = shelf.id }
                    Button("Delete Shelf", role: .destructive) {
                        withAnimation(spring) { store.deleteShelf(shelf.id) }
                    }
                }
            if !shelf.collapsed {
                ForEach(items) { risingCard($0) }
                if items.isEmpty {
                    dropHint("Drag dough here", active: dropTarget == key)
                }
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(dropTarget == key ? Theme.honey.opacity(0.22) : .clear)
                .padding(.horizontal, -4)
        )
        .modifier(DoughDrop(key: key, target: $dropTarget) { id in
            withAnimation(spring) { store.move(id, to: shelf.id) }
        })
    }

    private func dropHint(_ text: String, active: Bool) -> some View {
        Text(text)
            .pixelFont(12)
            .foregroundStyle(Theme.ink.opacity(active ? 0.7 : 0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 4)
                .fill(active ? Theme.honey.opacity(0.3) : .clear))
            .overlay(RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
    }

    private func card(_ item: Item) -> some View {
        IdeaCard(item: item, selected: selection == item.id, highlighted: justAdded == item.id,
                 action: { selection = item.id },
                 onDelete: {
                     if selection == item.id { selection = nil }
                     withAnimation(spring) { store.delete(item.id) }
                 })
        .draggable(item.id.uuidString) {
            HStack(spacing: 8) {
                Loaf(stage: item.stage, px: 2)
                Text(item.title.isEmpty ? "Untitled" : item.title)
                    .pixelFont(13)
                    .lineLimit(1)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .glass(4, strong: true)
        }
        .contextMenu {
            Button(item.done ? "Back in the Oven" : "Mark as Baked") {
                withAnimation(spring) { store.toggleDone(item.id) }
            }
            if !item.done && !store.shelves.isEmpty {
                Menu("Move to Shelf") {
                    Button("No Shelf") { withAnimation(spring) { store.move(item.id, to: nil) } }
                        .disabled(item.shelf == nil)
                    Divider()
                    ForEach(store.shelves) { shelf in
                        Button(shelf.name.isEmpty ? "Untitled shelf" : shelf.name) {
                            withAnimation(spring) { store.move(item.id, to: shelf.id) }
                        }
                        .disabled(item.shelf == shelf.id)
                    }
                }
            }
            Divider()
            Button("Delete", role: .destructive) {
                if selection == item.id { selection = nil }
                withAnimation(spring) { store.delete(item.id) }
            }
        }
    }
}

/// Accepts a dragged idea card (its id as a string) and highlights while hovered.
private struct DoughDrop: ViewModifier {
    let key: String
    @Binding var target: String?
    let onDrop: (UUID) -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { ids, _ in
                let found = ids.compactMap(UUID.init(uuidString:))
                found.forEach(onDrop)
                target = nil
                return !found.isEmpty
            } isTargeted: { over in
                withAnimation(.easeOut(duration: 0.12)) {
                    if over { target = key } else if target == key { target = nil }
                }
            }
    }
}

struct ShelfHeader: View {
    @EnvironmentObject var store: Store
    let shelf: Shelf
    let count: Int
    @Binding var renaming: UUID?
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(spring) { store.updateShelf(shelf.id) { $0.collapsed.toggle() } }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .rotationEffect(.degrees(shelf.collapsed ? 0 : 90))
                    .frame(width: 12, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.ink.opacity(0.45))

            if renaming == shelf.id {
                TextField("Shelf name", text: $name)
                    .textFieldStyle(.plain)
                    .pixelFont(13)
                    .focused($focused)
                    .onSubmit(commit)
                    .onExitCommand { renaming = nil }
                    .onAppear {
                        name = shelf.name
                        DispatchQueue.main.async { focused = true }
                    }
                    .onChange(of: focused) { _, f in if !f { commit() } }
            } else {
                Text(shelf.name.isEmpty ? "Untitled shelf" : shelf.name)
                    .pixelLabel()
                    .lineLimit(1)
                    .onTapGesture(count: 2) { renaming = shelf.id }
                    .help("Double-click to rename")
            }
            Spacer()
            Text("\(count)")
                .pixelFont(14)
                .foregroundStyle(Theme.ink.opacity(0.4))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
    }

    private func commit() {
        guard renaming == shelf.id else { return }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { store.updateShelf(shelf.id) { $0.name = n } }
        renaming = nil
    }
}

struct IdeaCard: View {
    @Environment(\.zoom) private var zoom
    let item: Item
    let selected: Bool
    let highlighted: Bool
    let action: () -> Void
    let onDelete: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 11) {
                Loaf(stage: item.stage, px: 2)
                    .frame(height: 20 * zoom, alignment: .bottom)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title.isEmpty ? "Untitled" : item.title)
                        .bookFont(13.5)
                        .foregroundStyle(Theme.ink.opacity(item.done ? 0.45 : 0.92))
                        .strikethrough(item.done, color: Theme.ink.opacity(0.3))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .padding(.trailing, 28)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.shadow).offset(x: 3, y: 3)
                }
            }
            .background(RoundedRectangle(cornerRadius: 4).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 4)
                .strokeBorder(selected ? Theme.border : .clear, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.45))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Delete idea")
            .padding(.top, 6)
            .padding(.trailing, 6)
            .opacity(hover ? 1 : 0)
        }
        .onHover { hover = $0 }
    }

    private var fill: Color {
        if highlighted { return Theme.honey.opacity(0.45) }
        if selected { return Theme.card }
        if hover { return Theme.cardSoft }
        return .clear
    }
}

// MARK: - Home (the big centered typing spot)

private let prompts = [
    "What's rising?",
    "Got a half-baked idea?",
    "Toss in some dough…",
    "What are you kneading?",
    "Something to bake someday…",
    "What if…",
]

struct HomeView: View {
    @Environment(\.zoom) private var zoom
    @AppStorage("draft") private var draft = ""
    @State private var prompt = prompts.randomElement()!
    let ns: Namespace.ID
    let onSubmit: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Oven(px: 6)
                .padding(.bottom, 36)
            VStack(alignment: .leading, spacing: 14) {
                InkEditor(text: $draft, placeholder: prompt, fontSize: 30, pixel: true, maxHeight: 220,
                          autofocus: true, focusID: "home",
                          onSubmit: submit, onEscape: { NotificationCenter.default.post(name: .hidePanel, object: nil) })
                    .overlay(alignment: .topLeading) {
                        Color.clear.frame(width: 1, height: 38)
                            .matchedGeometryEffect(id: "input", in: ns, anchor: .leading)
                            .padding(.leading, 5)
                    }
                HStack(spacing: 4) {
                    ForEach(0..<70, id: \.self) { _ in
                        Rectangle().fill(Theme.accent.opacity(0.6)).frame(width: 4, height: 3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
            .frame(maxWidth: 560 * zoom)
            .padding(.horizontal, 48 * zoom)
            Spacer()
            Spacer()
        }
    }

    private func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        prompt = prompts.randomElement()!
        onSubmit(text)
    }
}
