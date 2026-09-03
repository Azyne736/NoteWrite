import SwiftUI
import SwiftData

// MARK: - 笔记列表（文件夹 / 网格与列表切换 / 搜索 / 排序）

struct NotesListView: View {
    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)])
    private var notes: [Note]

    @Environment(\.modelContext) private var context

    @State private var searchText = ""
    @State private var editingNote: Note?
    @State private var editingIsNew = false
    @AppStorage("notes.layout") private var isGrid = true
    @AppStorage("notes.sort") private var sortKey = "updated"
    @State private var selectedFolder: String? = nil
    @State private var showNewFolder = false
    @State private var newFolderName = ""

    @Namespace private var folderNamespace

    private var folders: [String] {
        Array(Set(notes.map(\.folder))).filter { !$0.isEmpty }.sorted()
    }

    private var filtered: [Note] {
        var list = notes
        if let folder = selectedFolder {
            list = list.filter { $0.folder == folder }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.title.localizedStandardContains(searchText) ||
                $0.content.localizedStandardContains(searchText) ||
                $0.tagsRaw.localizedStandardContains(searchText)
            }
        }
        return sortedNotes(list)
    }

    private func sortedNotes(_ list: [Note]) -> [Note] {
        list.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            switch sortKey {
            case "created":
                return a.createdAt > b.createdAt
            case "title":
                return a.title.localizedCompare(b.title) == .orderedAscending
            default:
                return a.updatedAt > b.updatedAt
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !folders.isEmpty {
                        folderChips
                    }
                    if filtered.isEmpty {
                        EmptyStateView(
                            icon: "note.text",
                            title: "这里还没有笔记",
                            caption: searchText.isEmpty
                                ? "点击右上角 + 写下第一条笔记"
                                : "没有匹配「\(searchText)」的笔记"
                        )
                        .frame(minHeight: 320)
                    } else if isGrid {
                        notesGrid
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    } else {
                        notesList
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isGrid)
            }
            .navigationTitle("笔记")
            .searchable(text: $searchText, prompt: "搜索标题、内容、标签")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isGrid.toggle()
                        }
                    } label: {
                        Image(systemName: isGrid ? "rectangle.grid.1x2" : "square.grid.2x2")
                    }
                    .buttonStyle(BouncyButtonStyle(scale: 0.85))

                    Button(action: newNote) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(BouncyButtonStyle(scale: 0.85))

                    Menu {
                        Picker("排序", selection: $sortKey) {
                            Text("按更新时间").tag("updated")
                            Text("按创建时间").tag("created")
                            Text("按标题").tag("title")
                        }
                        Button {
                            newFolderName = ""
                            showNewFolder = true
                        } label: {
                            Label("新建文件夹", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(item: $editingNote) { note in
                NoteEditorView(note: note, isNew: editingIsNew)
                    .presentationDetents([.large])
            }
            .alert("新建文件夹", isPresented: $showNewFolder) {
                TextField("文件夹名称", text: $newFolderName)
                Button("创建并新建笔记") {
                    createNote(inFolder: newFolderName.trimmed)
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    // MARK: 文件夹胶囊（匹配几何滑动选中）

    private var folderChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                folderChip(name: nil, label: "全部", icon: "tray.full")
                ForEach(folders, id: \.self) { folder in
                    folderChip(name: folder, label: folder, icon: "folder")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func folderChip(name: String?, label: String, icon: String) -> some View {
        let isSelected = selectedFolder == name
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedFolder = name
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.footnote.weight(.medium))
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
                        .matchedGeometryEffect(id: "folder.chip", in: folderNamespace)
                } else {
                    Capsule().fill(.quinary)
                }
            }
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.92))
    }

    // MARK: 网格视图

    private var notesGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(filtered) { note in
                NoteGridView(note: note)
                    .onTapGesture { open(note) }
                    .contextMenu {
                        Button { open(note) } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        Button {
                            Haptics.impact(.light)
                            withAnimation { note.pinned.toggle(); try? context.save() }
                        } label: {
                            Label(note.pinned ? "取消置顶" : "置顶", systemImage: "pin")
                        }
                        Button(role: .destructive) { deleteNote(note) } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
            }
        }
    }

    // MARK: 列表视图

    private var notesList: some View {
        VStack(spacing: 8) {
            ForEach(filtered) { note in
                NoteListRow(note: note)
                    .onTapGesture { open(note) }
                    .contextMenu {
                        Button { open(note) } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        Button {
                            Haptics.impact(.light)
                            withAnimation { note.pinned.toggle(); try? context.save() }
                        } label: {
                            Label(note.pinned ? "取消置顶" : "置顶", systemImage: "pin")
                        }
                        Button(role: .destructive) { deleteNote(note) } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
            }
        }
    }

    // MARK: 操作

    private func open(_ note: Note) {
        Haptics.impact(.light)
        editingIsNew = false
        editingNote = note
    }

    private func newNote() {
        createNote(inFolder: selectedFolder ?? "")
    }

    private func createNote(inFolder: String) {
        Haptics.impact(.medium)
        let note = Note(title: "", content: "")
        note.folder = inFolder
        context.insert(note)
        editingIsNew = true
        editingNote = note
    }

    private func deleteNote(_ note: Note) {
        Haptics.warning()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            context.delete(note)
            try? context.save()
        }
    }
}

// MARK: - 笔记网格卡片

struct NoteGridView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: note.pinned ? "pin.fill" : "doc.text")
                    .font(.caption)
                    .foregroundStyle(NotePalette.color(note.colorIndex))
                    .rotationEffect(.degrees(note.pinned ? 0 : -20))
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: note.pinned)
                Spacer()
                if !note.folder.isEmpty {
                    Text(note.folder)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Text(note.title.isEmpty ? "无标题" : note.title)
                .font(.subheadline.weight(.bold))
                .lineLimit(2)
                .foregroundStyle(.primary)
            Text(
                note.content.isEmpty
                    ? "没有正文内容"
                    : note.content.replacingOccurrences(of: "\n", with: " ")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(4)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
            if !note.checklist.isEmpty {
                ChecklistMiniBar(
                    done: note.checklist.filter(\.isDone).count,
                    total: note.checklist.count
                )
            }
            Spacer(minLength: 0)
            HStack {
                Text(note.updatedAt, format: .dateTime.month().day())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                ForEach(Array(note.tags.prefix(1)), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption2)
                        .foregroundStyle(NotePalette.color(note.colorIndex))
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .frame(height: 168, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            NotePalette.color(note.colorIndex).opacity(0.16),
                            NotePalette.color(note.colorIndex).opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(NotePalette.color(note.colorIndex).opacity(0.28))
        )
    }
}

// MARK: - 笔记列表行

struct NoteListRow: View {
    let note: Note

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(NotePalette.color(note.colorIndex))
                .frame(width: 4, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if note.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Text(note.title.isEmpty ? "无标题" : note.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !note.checklist.isEmpty {
                        Text("清单 \(note.checklist.filter(\.isDone).count)/\(note.checklist.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(
                    note.content.isEmpty
                        ? "没有正文内容"
                        : note.content.replacingOccurrences(of: "\n", with: " ")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                HStack(spacing: 8) {
                    if !note.folder.isEmpty {
                        Label(note.folder, systemImage: "folder")
                    }
                    Label(
                        note.updatedAt.formatted(.relative(presentation: .named)),
                        systemImage: "clock"
                    )
                    ForEach(Array(note.tags.prefix(2)), id: \.self) { tag in
                        Text("#\(tag)")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

// MARK: - 清单迷你进度条

struct ChecklistMiniBar: View {
    let done: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("清单 \(done)/\(total)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(
                            width: total == 0
                                ? 0
                                : proxy.size.width * Double(done) / Double(total)
                        )
                }
            }
            .frame(height: 4)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: done)
    }
}
