import SwiftUI
import SwiftData
import UIKit

// MARK: - 笔记编辑器（标题 / 正文 / 清单 / 颜色 / 文件夹 / 标签）

struct NoteEditorView: View {
    @Bindable var note: Note
    let isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)])
    private var allNotes: [Note]

    @State private var newChecklistText = ""
    @State private var showChecklist: Bool
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var showDeleteConfirm = false
    @FocusState private var titleFocused: Bool

    init(note: Note, isNew: Bool) {
        self.note = note
        self.isNew = isNew
        _showChecklist = State(initialValue: !note.checklist.isEmpty)
    }

    private var folders: [String] {
        var set = Set(allNotes.map(\.folder).filter { !$0.isEmpty })
        if !note.folder.isEmpty { set.insert(note.folder) }
        return set.sorted()
    }

    private var shareText: String {
        var lines: [String] = [note.title.isEmpty ? "无标题笔记" : note.title, ""]
        if !note.content.isEmpty {
            lines.append(note.content)
        }
        for item in note.sortedChecklist {
            lines.append("\(item.isDone ? "☑" : "☐") \(item.text)")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerRow
                titleField
                contentEditor
                statsRow
                checklistCard
                styleCard
                tagsCard
                bottomBar
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
        )
        .onAppear {
            if isNew { titleFocused = true }
        }
        .onChange(of: note.title) { _, _ in note.updatedAt = Date() }
        .onChange(of: note.content) { _, _ in note.updatedAt = Date() }
        .onDisappear {
            if isNew && note.isBlank {
                context.delete(note)
                try? context.save()
            }
        }
    }

    // MARK: 头部

    private var headerRow: some View {
        HStack {
            Text(isNew ? "新笔记" : "编辑笔记")
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(BouncyButtonStyle(scale: 0.85))
        }
    }

    // MARK: 标题 / 正文

    private var titleField: some View {
        TextField("给笔记起个标题", text: $note.title, axis: .vertical)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .lineLimit(1...2)
            .focused($titleFocused)
            .submitLabel(.done)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.25))
            )
    }

    private var contentEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $note.content)
                .font(.body)
                .frame(minHeight: 200, alignment: .topLeading)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            if note.content.isEmpty {
                Text("写点什么吧…")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            Label("\(note.content.count) 字", systemImage: "text.word.spacing")
            Spacer()
            Label(
                note.updatedAt.formatted(.relative(presentation: .named)),
                systemImage: "clock.arrow.circlepath"
            )
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }

    // MARK: 清单

    private var checklistCard: some View {
        EditorCard(title: "清单", icon: "list.bullet.rectangle") {
            Toggle("在笔记中使用清单", isOn: $showChecklist)
                .font(.subheadline)
            if showChecklist {
                if !note.checklist.isEmpty {
                    ChecklistMiniBar(
                        done: note.checklist.filter(\.isDone).count,
                        total: note.checklist.count
                    )
                    ForEach(note.sortedChecklist) { item in
                        ChecklistRowView(item: item) {
                            deleteChecklistItem(item)
                        }
                    }
                }
                newChecklistRow
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showChecklist)
    }

    private var newChecklistRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.accentColor)
            TextField("添加清单项", text: $newChecklistText)
                .font(.subheadline)
                .onSubmit(addChecklistItem)
            Button(action: addChecklistItem) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        newChecklistText.trimmed.isEmpty
                            ? Color.secondary.opacity(0.4)
                            : Color.accentColor
                    )
            }
            .buttonStyle(BouncyButtonStyle(scale: 0.85))
            .disabled(newChecklistText.trimmed.isEmpty)
        }
        .padding(.vertical, 4)
    }

    private func addChecklistItem() {
        let text = newChecklistText.trimmed
        guard !text.isEmpty else { return }
        Haptics.impact(.light)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            let item = NoteChecklistItem(text: text, orderIndex: note.checklist.count)
            context.insert(item)
            note.checklist.append(item)
            try? context.save()
        }
        newChecklistText = ""
    }

    private func deleteChecklistItem(_ item: NoteChecklistItem) {
        Haptics.impact(.light)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            context.delete(item)
            note.checklist.removeAll { $0.id == item.id }
            try? context.save()
        }
    }

    // MARK: 外观与整理

    private var styleCard: some View {
        EditorCard(title: "外观与整理", icon: "paintpalette") {
            HStack(spacing: 10) {
                ForEach(NotePalette.colors.indices, id: \.self) { index in
                    colorDot(index)
                }
            }
            Divider()
            HStack {
                Label("文件夹", systemImage: "folder")
                    .font(.subheadline)
                Spacer()
                folderMenu
            }
        }
    }

    private func colorDot(_ index: Int) -> some View {
        let isSelected = note.colorIndex == index
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) {
                note.colorIndex = index
            }
        } label: {
            Circle()
                .fill(NotePalette.color(index))
                .frame(width: 26, height: 26)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: 2)
                            .padding(-4)
                    }
                }
                .scaleEffect(isSelected ? 1.15 : 1)
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.85))
    }

    private var folderMenu: some View {
        Menu {
            Picker("文件夹", selection: folderBinding) {
                Text("未分组").tag("")
                ForEach(folders, id: \.self) { folder in
                    Text(folder).tag(folder)
                }
            }
            Divider()
            Button {
                newFolderName = ""
                showNewFolder = true
            } label: {
                Label("新建文件夹", systemImage: "folder.badge.plus")
            }
        } label: {
            HStack(spacing: 4) {
                Text(note.folder.isEmpty ? "未分组" : note.folder)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline)
            .foregroundStyle(Color.accentColor)
        }
    }

    private var folderBinding: Binding<String> {
        Binding(
            get: { note.folder },
            set: { note.folder = $0.trimmed }
        )
    }

    // MARK: 标签

    private var tagsCard: some View {
        EditorCard(title: "标签", icon: "tag") {
            TextField("用逗号分隔，如：灵感,工作", text: tagsBinding)
                .font(.subheadline)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
        }
    }

    private var tagsBinding: Binding<String> {
        Binding(
            get: { note.tags.joined(separator: ", ") },
            set: { newValue in
                note.tags = newValue
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    // MARK: 底部操作

    private var bottomBar: some View {
        HStack(spacing: 12) {
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.body.weight(.semibold))
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.accentColor.opacity(0.12)))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(BouncyButtonStyle(scale: 0.85))

            if !isNew {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Color.red.opacity(0.12)))
                        .foregroundStyle(.red)
                }
                .buttonStyle(BouncyButtonStyle(scale: 0.85))
            }
            Spacer()
            if isNew {
                Button("取消") { cancelAndDismiss() }
                    .foregroundStyle(.secondary)
            }
            Button(action: finish) {
                Label("完成", systemImage: "checkmark")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.accentColor.gradient))
                    .foregroundStyle(.white)
            }
            .buttonStyle(BouncyButtonStyle(scale: 0.93))
        }
        .confirmationDialog(
            "删除这篇笔记？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                Haptics.warning()
                withAnimation {
                    context.delete(note)
                    try? context.save()
                }
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
        .alert("新建文件夹", isPresented: $showNewFolder) {
            TextField("文件夹名称", text: $newFolderName)
            Button("创建") {
                let name = newFolderName.trimmed
                if !name.isEmpty {
                    withAnimation { note.folder = name }
                }
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func finish() {
        Haptics.success()
        note.updatedAt = Date()
        try? context.save()
        dismiss()
    }

    private func cancelAndDismiss() {
        Haptics.impact(.light)
        if isNew {
            context.delete(note)
            try? context.save()
        }
        dismiss()
    }
}

// MARK: - 清单行

struct ChecklistRowView: View {
    @Bindable var item: NoteChecklistItem
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    item.isDone.toggle()
                }
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(item.isDone ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(BouncyButtonStyle(scale: 0.82))

            TextField("清单项", text: $item.text, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...2)
                .strikethrough(item.isDone, color: .secondary)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
    }
}
