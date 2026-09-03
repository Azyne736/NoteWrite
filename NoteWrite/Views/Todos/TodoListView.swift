import SwiftUI
import SwiftData

// MARK: - 待办列表（置顶/逾期/今天/即将/随时/已完成）

struct TodoListView: View {
    @Query(sort: [SortDescriptor(\TodoItem.createdAt, order: .reverse)])
    private var todos: [TodoItem]

    @Environment(\.modelContext) private var context

    @State private var searchText = ""
    @State private var editingTodo: TodoItem?
    @State private var editingIsNew = false
    @State private var showCompleted = true
    @AppStorage("todos.sort") private var sortKey = "due"

    private var calendar: Calendar { Calendar.current }

    private var searchResults: [TodoItem]? {
        guard !searchText.isEmpty else { return nil }
        return todos.filter {
            $0.title.localizedStandardContains(searchText) ||
            $0.noteText.localizedStandardContains(searchText) ||
            $0.tagsRaw.localizedStandardContains(searchText)
        }
    }

    private var visibleActive: [TodoItem] {
        let base = searchResults ?? todos.filter { !$0.isCompleted }
        return TodoSort.sort(base, by: sortKey)
    }

    private var pinnedItems: [TodoItem] {
        visibleActive.filter(\.pinned)
    }

    private var overdueItems: [TodoItem] {
        visibleActive.filter { item in
            guard !item.pinned, let due = item.dueDate else { return false }
            return due < calendar.startOfDay(for: Date())
        }
    }

    private var todayItems: [TodoItem] {
        visibleActive.filter { item in
            guard !item.pinned, let due = item.dueDate else { return false }
            return calendar.isDateInToday(due)
        }
    }

    private var upcomingItems: [TodoItem] {
        visibleActive.filter { item in
            guard !item.pinned, let due = item.dueDate else { return false }
            let endOfToday = calendar.dateInterval(of: .day, for: Date())?.end ?? Date()
            return due > endOfToday
        }
    }

    private var anytimeItems: [TodoItem] {
        visibleActive.filter { !$0.pinned && $0.dueDate == nil }
    }

    private var completedItems: [TodoItem] {
        let base = searchResults ?? todos
        return base
            .filter(\.isCompleted)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if todos.isEmpty {
                    EmptyStateView(
                        icon: "checklist",
                        title: "还没有待办",
                        caption: "点击右上角 + 创建第一个待办\n支持提醒、重复、子任务与优先级"
                    )
                } else {
                    todoList
                }
            }
            .navigationTitle("待办")
            .searchable(text: $searchText, prompt: "搜索待办、备注、标签")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: newTodo) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(BouncyButtonStyle(scale: 0.85))

                    Menu {
                        Picker("排序方式", selection: $sortKey) {
                            Text("按截止日期").tag("due")
                            Text("按创建时间").tag("created")
                            Text("按优先级").tag("priority")
                            Text("按标题").tag("title")
                        }
                        Toggle("显示已完成", isOn: $showCompleted)
                        Divider()
                        Button(role: .destructive, action: clearCompleted) {
                            Label("清除已完成", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(item: $editingTodo) { todo in
                TodoEditorView(todo: todo, isNew: editingIsNew)
                    .presentationDetents([.large])
            }
        }
    }

    private var todoList: some View {
        List {
            if let results = searchResults {
                Section {
                    ForEach(results) { todo in
                        row(todo)
                    }
                } header: {
                    SectionHeader(title: "搜索结果 · \(results.count)", icon: "magnifyingglass")
                }
            } else {
                if !pinnedItems.isEmpty {
                    Section {
                        ForEach(pinnedItems) { row($0) }
                    } header: {
                        SectionHeader(title: "置顶", icon: "pin.fill", color: .orange)
                    }
                }
                if !overdueItems.isEmpty {
                    Section {
                        ForEach(overdueItems) { row($0) }
                    } header: {
                        SectionHeader(title: "已逾期", icon: "exclamationmark.circle.fill", color: .red)
                    }
                }
                if !todayItems.isEmpty {
                    Section {
                        ForEach(todayItems) { row($0) }
                    } header: {
                        SectionHeader(title: "今天", icon: "sun.max.fill", color: .accentColor)
                    }
                }
                if !upcomingItems.isEmpty {
                    Section {
                        ForEach(upcomingItems) { row($0) }
                    } header: {
                        SectionHeader(title: "即将到来", icon: "calendar", color: .secondary)
                    }
                }
                if !anytimeItems.isEmpty {
                    Section {
                        ForEach(anytimeItems) { row($0) }
                    } header: {
                        SectionHeader(title: "随时", icon: "tray", color: .secondary)
                    }
                }
                if showCompleted && !completedItems.isEmpty {
                    Section {
                        ForEach(completedItems) { row($0) }
                    } header: {
                        SectionHeader(title: "已完成 · \(completedItems.count)", icon: "checkmark.circle.fill", color: .green)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: todos.count)
    }

    private func row(_ todo: TodoItem) -> some View {
        TodoRowView(todo: todo)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.impact(.light)
                editingIsNew = false
                editingTodo = todo
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    toggle(todo)
                } label: {
                    Label(todo.isCompleted ? "撤销完成" : "完成", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        TodoActions.delete(todo, context: context)
                    }
                } label: {
                    Label("删除", systemImage: "trash.fill")
                }
                Button {
                    Haptics.impact(.light)
                    editingIsNew = false
                    editingTodo = todo
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                .tint(.blue)
                Button {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        todo.pinned.toggle()
                        try? context.save()
                    }
                } label: {
                    Label(todo.pinned ? "取消置顶" : "置顶", systemImage: todo.pinned ? "pin.slash" : "pin")
                }
                .tint(.orange)
            }
    }

    private func toggle(_ todo: TodoItem) {
        let completing = !todo.isCompleted
        if completing {
            Haptics.success()
        } else {
            Haptics.impact(.light)
        }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) {
            TodoActions.toggleComplete(todo, context: context)
        }
    }

    private func newTodo() {
        Haptics.impact(.medium)
        let todo = TodoItem(title: "")
        context.insert(todo)
        editingIsNew = true
        editingTodo = todo
    }

    private func clearCompleted() {
        Haptics.warning()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            for todo in todos where todo.isCompleted {
                TodoActions.delete(todo, context: context)
            }
        }
    }
}
