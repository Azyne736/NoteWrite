import SwiftUI
import SwiftData
import UIKit

// MARK: - 待办编辑器

struct TodoEditorView: View {
    @Bindable var todo: TodoItem
    let isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Namespace private var namespace
    @State private var showReminder: Bool
    @State private var showDeleteConfirm = false
    @State private var newSubtaskText = ""
    @FocusState private var titleFocused: Bool

    private let calendar = Calendar.current
    private let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]

    init(todo: TodoItem, isNew: Bool) {
        self.todo = todo
        self.isNew = isNew
        _showReminder = State(initialValue: todo.reminderDate != nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerRow
                titleSection
                noteSection
                priorityCard
                dueCard
                reminderCard
                repeatCard
                longTermCard
                tagsCard
                pinRow
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
        .onChange(of: todo.hasSpecificTime) { _, hasTime in
            // 打开具体时间且当前为午夜 0 点时，默认设为上午 9 点
            if hasTime, let due = todo.dueDate, due == calendar.startOfDay(for: due) {
                var comps = calendar.dateComponents([.year, .month, .day], from: due)
                comps.hour = 9
                comps.minute = 0
                todo.dueDate = calendar.date(from: comps) ?? due
            }
        }
        .onDisappear {
            if isNew &&
                todo.title.trimmed.isEmpty &&
                todo.noteText.trimmed.isEmpty &&
                todo.subtasks.isEmpty {
                TodoActions.delete(todo, context: context)
            }
        }
    }

    // MARK: 头部

    private var headerRow: some View {
        HStack {
            Text(isNew ? "新待办" : "编辑待办")
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

    // MARK: 标题 / 备注

    private var titleSection: some View {
        TextField("待办标题", text: $todo.title, axis: .vertical)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .lineLimit(1...3)
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

    private var noteSection: some View {
        TextField("备注（可选）", text: $todo.noteText, axis: .vertical)
            .font(.subheadline)
            .lineLimit(1...4)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
    }

    // MARK: 优先级

    private var priorityCard: some View {
        EditorCard(title: "优先级", icon: "flag.fill") {
            HStack(spacing: 8) {
                ForEach(Priority.allCases) { priority in
                    priorityPill(priority)
                }
            }
        }
    }

    private func priorityPill(_ priority: Priority) -> some View {
        let isSelected = todo.priority == priority
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                todo.priority = priority
                try? context.save()
            }
        } label: {
            Text(priority.label)
                .font(.footnote.weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? Color.white : priority.color)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(priority.color.gradient)
                            .matchedGeometryEffect(id: "priority.pill", in: namespace)
                    } else {
                        Capsule()
                            .strokeBorder(priority.color.opacity(0.45), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.9))
    }

    // MARK: 截止日期

    private var dueCard: some View {
        EditorCard(title: "截止日期", icon: "calendar") {
            Toggle("设定截止日期", isOn: dueEnabled)
                .font(.subheadline)
            if todo.dueDate != nil {
                quickDateChips
                Toggle("包含具体时间", isOn: $todo.hasSpecificTime)
                    .font(.subheadline)
                DatePicker(
                    "截止",
                    selection: dueBinding,
                    displayedComponents: todo.hasSpecificTime ? [.date, .hourAndMinute] : [.date]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: todo.dueDate)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: todo.hasSpecificTime)
    }

    private var dueEnabled: Binding<Bool> {
        Binding(
            get: { todo.dueDate != nil },
            set: { on in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if on {
                        todo.dueDate = Date.todayAt(hour: 18, minute: 0, calendar: calendar)
                        todo.hasSpecificTime = false
                    } else {
                        todo.dueDate = nil
                        todo.hasSpecificTime = false
                    }
                }
            }
        )
    }

    private var dueBinding: Binding<Date> {
        Binding(
            get: { todo.dueDate ?? Date() },
            set: { todo.dueDate = $0 }
        )
    }

    private var quickDateChips: some View {
        HStack(spacing: 8) {
            quickDateChip("今天") {
                todo.dueDate = dateAfterDays(0, hour: 18, minute: 0)
            }
            quickDateChip("明天") {
                todo.dueDate = dateAfterDays(1, hour: 9, minute: 0)
            }
            quickDateChip("下周") {
                todo.dueDate = dateAfterDays(7, hour: 9, minute: 0)
            }
        }
    }

    private func quickDateChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                action()
                todo.hasSpecificTime = true
            }
        } label: {
            Text(label)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.9))
    }

    private func dateAfterDays(_ days: Int, hour: Int, minute: Int) -> Date {
        let base = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
        var comps = calendar.dateComponents([.year, .month, .day], from: base)
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps) ?? base
    }

    // MARK: 提醒

    private var reminderCard: some View {
        EditorCard(title: "提醒", icon: "alarm") {
            Toggle("开启提醒", isOn: reminderEnabled)
                .font(.subheadline)
            if showReminder {
                DatePicker(
                    "",
                    selection: reminderBinding,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color(hex: 0xEC4899))
                .frame(maxWidth: .infinity, alignment: .leading)

                if todo.dueDate != nil {
                    HStack(spacing: 8) {
                        quickReminderChip("截止时") {
                            todo.reminderDate = todo.dueDate
                        }
                        quickReminderChip("提前 1 小时") {
                            todo.reminderDate = todo.dueDate?.addingTimeInterval(-3600)
                        }
                    }
                }
                Text("到点后会发送本地通知提醒你")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showReminder)
    }

    private var reminderEnabled: Binding<Bool> {
        Binding(
            get: { showReminder },
            set: { on in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showReminder = on
                }
                if on {
                    if todo.reminderDate == nil {
                        todo.reminderDate = defaultReminder()
                    }
                    Task { _ = await NotificationManager.shared.requestIfNeeded() }
                } else {
                    todo.reminderDate = nil
                    NotificationManager.shared.cancel(todo)
                }
            }
        )
    }

    private var reminderBinding: Binding<Date> {
        Binding(
            get: { todo.reminderDate ?? Date() },
            set: { todo.reminderDate = $0 }
        )
    }

    private func quickReminderChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { action() }
        } label: {
            Text(label)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: 0xEC4899).opacity(0.12)))
                .foregroundStyle(Color(hex: 0xEC4899))
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.9))
    }

    private func defaultReminder() -> Date {
        if let due = todo.dueDate, due > Date() {
            if todo.hasSpecificTime { return due }
            var comps = calendar.dateComponents([.year, .month, .day], from: due)
            comps.hour = 20
            comps.minute = 0
            if let result = calendar.date(from: comps), result > Date() {
                return result
            }
        }
        let evening = Date.todayAt(hour: 20, minute: 0, calendar: calendar)
        if evening > Date() { return evening }
        return dateAfterDays(1, hour: 9, minute: 0)
    }

    // MARK: 重复

    private var repeatCard: some View {
        EditorCard(title: "重复", icon: "arrow.triangle.2.circlepath") {
            Picker("重复", selection: repeatBinding) {
                ForEach(RepeatRule.allCases) { rule in
                    Text(rule.label).tag(rule)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            if todo.repeatRule == .everyNDays {
                Stepper(value: $todo.repeatIntervalDays, in: 1...365) {
                    Text("每 \(todo.repeatIntervalDays) 天重复一次")
                        .font(.subheadline)
                }
                .tint(Color.accentColor)
            }
            if todo.repeatRule == .weeklyOnDays {
                weekdaySelector
            }
            if todo.repeatRule != .never {
                Text("完成一次后自动滚动到下一次")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: todo.repeatRule)
    }

    private var repeatBinding: Binding<RepeatRule> {
        Binding(
            get: { todo.repeatRule },
            set: { rule in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    todo.repeatRule = rule
                    if rule == .weeklyOnDays && todo.repeatWeekdays.isEmpty {
                        todo.repeatWeekdays = [2, 3, 4, 5, 6] // 周一至周五
                    }
                }
            }
        )
    }

    private var weekdaySelector: some View {
        HStack(spacing: 6) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                weekdayDot(symbol: symbol, weekday: weekdayNumber(for: index))
            }
        }
    }

    private func weekdayNumber(for index: Int) -> Int {
        index == 6 ? 1 : index + 2
    }

    private func weekdayDot(symbol: String, weekday: Int) -> some View {
        let isSelected = todo.repeatWeekdays.contains(weekday)
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                var set = todo.repeatWeekdays
                if isSelected {
                    set.remove(weekday)
                } else {
                    set.insert(weekday)
                }
                todo.repeatWeekdays = set
            }
        } label: {
            Text(symbol)
                .font(.footnote.weight(.semibold))
                .frame(width: 34, height: 34)
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .background {
                    if isSelected {
                        Circle().fill(Color.accentColor)
                    } else {
                        Circle().strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.82))
    }

    // MARK: 长期任务（子任务 + 进度）

    private var longTermCard: some View {
        EditorCard(title: "长期任务", icon: "chart.line.uptrend.xyaxis") {
            Toggle("作为长期任务", isOn: $todo.isLongTerm)
                .font(.subheadline)
            if todo.isLongTerm {
                if !todo.subtasks.isEmpty {
                    progressBar
                    ForEach(todo.subtasks.sorted { $0.orderIndex < $1.orderIndex }) { sub in
                        SubtaskRow(subtask: sub) {
                            deleteSubtask(sub)
                        }
                    }
                }
                newSubtaskRow
                Text("拆解成小步骤，进度会自动计算")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: todo.isLongTerm)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.accentColor.opacity(0.12))
                Capsule()
                    .fill(Color.accentColor.gradient)
                    .frame(width: proxy.size.width * todo.subtaskProgress)
            }
        }
        .frame(height: 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: todo.subtaskProgress)
    }

    private var newSubtaskRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.accentColor)
            TextField("添加子任务", text: $newSubtaskText)
                .font(.subheadline)
                .onSubmit(addSubtask)
            Button(action: addSubtask) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        newSubtaskText.trimmed.isEmpty
                            ? Color.secondary.opacity(0.4)
                            : Color.accentColor
                    )
            }
            .buttonStyle(BouncyButtonStyle(scale: 0.85))
            .disabled(newSubtaskText.trimmed.isEmpty)
        }
        .padding(.vertical, 4)
    }

    private func addSubtask() {
        let text = newSubtaskText.trimmed
        guard !text.isEmpty else { return }
        Haptics.impact(.light)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            let sub = SubTask(text: text, orderIndex: todo.subtasks.count)
            context.insert(sub)
            todo.subtasks.append(sub)
            try? context.save()
        }
        newSubtaskText = ""
    }

    private func deleteSubtask(_ sub: SubTask) {
        Haptics.impact(.light)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            context.delete(sub)
            todo.subtasks.removeAll { $0.id == sub.id }
            try? context.save()
        }
    }

    // MARK: 标签 / 置顶

    private var tagsCard: some View {
        EditorCard(title: "标签", icon: "tag") {
            TextField("用逗号分隔，如：工作,重要", text: tagsBinding)
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
            get: { todo.tags.joined(separator: ", ") },
            set: { newValue in
                todo.tags = newValue
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private var pinRow: some View {
        HStack {
            Label("置顶显示", systemImage: todo.pinned ? "pin.fill" : "pin")
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: $todo.pinned)
                .labelsHidden()
                .tint(.orange)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: 底部操作

    private var bottomBar: some View {
        HStack(spacing: 12) {
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
            "删除这个待办？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                Haptics.warning()
                TodoActions.delete(todo, context: context)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func finish() {
        Haptics.success()
        todo.updatedAt = Date()
        try? context.save()
        Task { await NotificationManager.shared.syncReminder(for: todo) }
        dismiss()
    }

    private func cancelAndDismiss() {
        Haptics.impact(.light)
        if isNew {
            TodoActions.delete(todo, context: context)
        }
        dismiss()
    }
}

// MARK: - 子任务行

struct SubtaskRow: View {
    @Bindable var subtask: SubTask
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    subtask.isDone.toggle()
                }
            } label: {
                Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(subtask.isDone ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(BouncyButtonStyle(scale: 0.82))

            TextField("子任务", text: $subtask.text, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...2)
                .strikethrough(subtask.isDone, color: .secondary)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
    }
}
