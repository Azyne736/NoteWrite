import SwiftUI
import SwiftData

// MARK: - 今天 · 仪表盘

struct DashboardView: View {
    let isActive: Bool
    var goTo: (RootView.Tab) -> Void

    @Query(sort: [SortDescriptor(\TodoItem.createdAt, order: .reverse)])
    private var todos: [TodoItem]

    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)])
    private var notes: [Note]

    @Environment(\.modelContext) private var context

    @State private var editingTodo: TodoItem?
    @State private var editingTodoIsNew = false
    @State private var editingNote: Note?
    @State private var editingNoteIsNew = false
    @State private var shakeTrigger: CGFloat = 0

    private static let heroColors: [Color] = [
        Color(hex: 0x6366F1), Color(hex: 0x8B5CF6), Color(hex: 0xEC4899),
        Color(hex: 0x818CF8), Color(hex: 0xA855F7), Color(hex: 0xF472B6),
        Color(hex: 0xA78BFA), Color(hex: 0xC084FC), Color(hex: 0xFB7185)
    ]

    private var activeTodos: [TodoItem] {
        todos.filter { !$0.isCompleted }
    }

    private var todayItems: [TodoItem] {
        activeTodos.filter {
            guard let due = $0.dueDate else { return false }
            return Calendar.current.isDateInToday(due)
        }
    }

    private var todayListItems: [TodoItem] {
        TodoSort.defaultSort(todayItems)
    }

    private var overdueItems: [TodoItem] {
        activeTodos.filter {
            guard let due = $0.dueDate else { return false }
            return due < Calendar.current.startOfDay(for: Date())
        }
    }

    private var todayDoneCount: Int {
        todos.flatMap(\.historyDates)
            .filter { Calendar.current.isDateInToday($0) }
            .count
    }

    private var todayTotalCount: Int {
        todayItems.count + todayDoneCount
    }

    private var todayProgress: Double {
        guard todayTotalCount > 0 else { return 0 }
        return Double(todayDoneCount) / Double(todayTotalCount)
    }

    private var recentNotes: [Note] {
        Array(notes.prefix(6))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<5: return "夜深了 🌙"
        case 5..<11: return "早上好 ☀️"
        case 11..<13: return "中午好 🍱"
        case 13..<18: return "下午好 ☕️"
        default: return "晚上好 🌆"
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                header
                heroCard
                if !overdueItems.isEmpty {
                    overdueCard
                }
                quickActions
                if !todayListItems.isEmpty {
                    todaySection
                }
                if !recentNotes.isEmpty {
                    recentNotesSection
                }
                Text("NoteWrite · 记录想法，完成待办")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .sheet(item: $editingTodo) { todo in
            TodoEditorView(todo: todo, isNew: editingTodoIsNew)
                .presentationDetents([.large])
        }
        .sheet(item: $editingNote) { note in
            NoteEditorView(note: note, isNew: editingNoteIsNew)
                .presentationDetents([.large])
        }
        .onAppear {
            if !overdueItems.isEmpty {
                withAnimation(.easeInOut(duration: 0.6).delay(0.5)) {
                    shakeTrigger = 1
                }
            }
        }
    }

    // MARK: 顶部

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(Date.now, format: .dateTime.year().month().day().weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: newTodo) {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.accentColor.gradient))
            }
            .buttonStyle(BouncyButtonStyle(scale: 0.85))
        }
    }

    // MARK: 英雄卡（流动网格渐变 + 进度环）

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日进度")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                    Text("\(todayDoneCount) / \(todayTotalCount)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: todayDoneCount)
                    Text(todayProgress >= 1 ? "全部完成，太棒了！🎉" : "继续保持 💪")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                Spacer()
                ProgressRing(progress: todayProgress, size: 74, lineWidth: 8, tint: .white)
                    .overlay(
                        Text("\(Int((todayProgress * 100).rounded()))%")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    )
            }
            HStack(spacing: 8) {
                heroChip(icon: "checklist", label: "待办 \(todayItems.count)")
                heroChip(icon: "checkmark.circle.fill", label: "完成 \(todayDoneCount)")
                if !overdueItems.isEmpty {
                    heroChip(icon: "exclamationmark.triangle.fill", label: "逾期 \(overdueItems.count)")
                }
            }
        }
        .padding(18)
        .background {
            ZStack {
                AnimatedMeshBackground(colors: Self.heroColors, active: isActive)
                LinearGradient(
                    colors: [.black.opacity(0.18), .black.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22))
        )
    }

    private func heroChip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.18)))
    }

    // MARK: 逾期提醒卡（抖动）

    private var overdueCard: some View {
        Button {
            Haptics.impact(.medium)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                goTo(.todos)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(overdueItems.count) 项待办已逾期")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("点按查看并处理")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.8))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xEF4444), Color(hex: 0xF97316)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .modifier(ShakeEffect(animatableData: shakeTrigger))
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.97))
    }

    // MARK: 快捷操作

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickActionButton(
                title: "新建待办",
                subtitle: "提醒 · 重复 · 长期",
                icon: "plus.circle.fill",
                colors: [Color(hex: 0x6366F1), Color(hex: 0x8B5CF6)],
                action: newTodo
            )
            quickActionButton(
                title: "新建笔记",
                subtitle: "清单 · 标签 · 文件夹",
                icon: "square.and.pencil.fill",
                colors: [Color(hex: 0xEC4899), Color(hex: 0xF97316)],
                action: newNote
            )
        }
    }

    private func quickActionButton(
        title: String,
        subtitle: String,
        icon: String,
        colors: [Color],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.95))
    }

    // MARK: 今日待办

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("今日待办", "checklist") {
                Button {
                    Haptics.impact(.light)
                    goTo(.todos)
                } label: {
                    HStack(spacing: 2) {
                        Text("全部")
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(BouncyButtonStyle())
            }
            CardContainer {
                VStack(spacing: 2) {
                    ForEach(Array(todayListItems.prefix(5))) { todo in
                        TodoRowView(todo: todo)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.impact(.light)
                                editingTodoIsNew = false
                                editingTodo = todo
                            }
                    }
                }
            }
        }
    }

    // MARK: 最近笔记

    private var recentNotesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("最近笔记", "note.text") {
                EmptyView()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentNotes) { note in
                        Button {
                            Haptics.impact(.light)
                            editingNoteIsNew = false
                            editingNote = note
                        } label: {
                            NoteMiniCard(note: note)
                        }
                        .buttonStyle(BouncyButtonStyle(scale: 0.96))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func sectionHeader<Trailing: View>(
        _ title: String,
        _ icon: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            trailing()
        }
    }

    // MARK: 建新

    private func newTodo() {
        Haptics.impact(.medium)
        let todo = TodoItem(title: "")
        todo.dueDate = Date.todayAt(hour: 18, minute: 0)
        todo.hasSpecificTime = false
        context.insert(todo)
        editingTodoIsNew = true
        editingTodo = todo
    }

    private func newNote() {
        Haptics.impact(.medium)
        let note = Note(title: "", content: "")
        context.insert(note)
        editingNoteIsNew = true
        editingNote = note
    }
}

// MARK: - 笔记迷你卡（横滑）

struct NoteMiniCard: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: note.pinned ? "pin.fill" : "note.text")
                    .font(.footnote)
                    .foregroundStyle(NotePalette.color(note.colorIndex))
                Spacer()
            }
            Text(note.title.isEmpty ? "无标题笔记" : note.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(.primary)
            Text(note.content.isEmpty ? "空笔记" : note.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Text(note.updatedAt, format: .dateTime.month().day())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 150, height: 110, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(NotePalette.color(note.colorIndex).opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(NotePalette.color(note.colorIndex).opacity(0.3))
        )
    }
}
