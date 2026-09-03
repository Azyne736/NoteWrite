import SwiftUI
import SwiftData

// MARK: - 待办行卡片

struct TodoRowView: View {
    @Bindable var todo: TodoItem
    @Environment(\.modelContext) private var context

    @State private var confettiTrigger = 0
    @State private var appeared = false
    @State private var confettiEnabled = UserDefaults.standard.object(forKey: "settings.confetti") == nil
        ? true
        : UserDefaults.standard.bool(forKey: "settings.confetti")

    private var isDone: Bool { todo.isCompleted }
    private var priorityColor: Color { todo.priority.color }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            checkBox
            VStack(alignment: .leading, spacing: 6) {
                Text(todo.title.trimmed.isEmpty ? "新待办" : todo.title)
                    .font(.body.weight(.medium))
                    .strikethrough(isDone, color: .secondary)
                    .foregroundStyle(isDone ? Color.secondary : Color.primary)
                    .lineLimit(2)
                chipRow
            }
            Spacer(minLength: 6)
            if todo.isLongTerm && !todo.subtasks.isEmpty {
                ProgressRing(progress: todo.subtaskProgress, size: 30, lineWidth: 4)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -20)
        .overlay(alignment: .leading) {
            if confettiEnabled {
                ConfettiBurst(trigger: confettiTrigger)
                    .frame(width: 340, height: 340)
                    .offset(x: -146, y: 4)
            }
        }
        .onAppear {
            guard !appeared else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: 勾选框（弹性 + 缩放转换 + 彩带）

    private var checkBox: some View {
        Button(action: toggleDone) {
            ZStack {
                Circle()
                    .strokeBorder(
                        isDone ? priorityColor : priorityColor.opacity(0.65),
                        lineWidth: 1.8
                    )
                if isDone {
                    Circle()
                        .fill(priorityColor)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(.white)
                        )
                        .transition(.scale(scale: 0.25).combined(with: .opacity))
                }
            }
            .frame(width: 25, height: 25)
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.8))
        .padding(.top, 2)
    }

    private func toggleDone() {
        let completing = !todo.isCompleted
        if completing {
            Haptics.success()
            if confettiEnabled {
                confettiTrigger += 1
            }
        } else {
            Haptics.impact(.light)
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.62)) {
            TodoActions.toggleComplete(todo, context: context)
        }
    }

    // MARK: 信息胶囊

    private var chipRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { allChips }
            HStack(spacing: 6) { coreChips }
        }
    }

    @ViewBuilder
    private var allChips: some View {
        dueChip
        if todo.repeatRule != .never {
            ChipView(icon: "arrow.triangle.2.circlepath", text: todo.repeatDescription, color: Color(hex: 0x14B8A6))
        }
        if todo.reminderDate != nil {
            reminderChip
        }
        if !todo.subtasks.isEmpty {
            ChipView(
                icon: "list.bullet",
                text: "\(todo.subtasks.filter(\.isDone).count)/\(todo.subtasks.count)",
                color: Color(hex: 0x3B82F6)
            )
        }
        if todo.priority != Priority.none {
            ChipView(icon: "flag.fill", text: todo.priority.label, color: todo.priority.color)
        }
        ForEach(Array(todo.tags.prefix(2)), id: \.self) { tag in
            ChipView(icon: "tag", text: tag, color: .secondary)
        }
    }

    @ViewBuilder
    private var coreChips: some View {
        dueChip
        if todo.reminderDate != nil {
            reminderChip
        }
        if !todo.subtasks.isEmpty {
            ChipView(
                icon: "list.bullet",
                text: "\(todo.subtasks.filter(\.isDone).count)/\(todo.subtasks.count)",
                color: Color(hex: 0x3B82F6)
            )
        }
    }

    @ViewBuilder
    private var dueChip: some View {
        if let due = todo.dueDate {
            let calendar = Calendar.current
            let text = todo.hasSpecificTime
                ? due.formatted(.dateTime.month().day().hour().minute())
                : due.formatted(.dateTime.month().day())
            let color: Color = {
                if due < calendar.startOfDay(for: Date()) { return .red }
                if calendar.isDateInToday(due) { return .accentColor }
                if calendar.isDateInTomorrow(due) { return .orange }
                return .secondary
            }()
            let isPastToday = calendar.isDateInToday(due) && due < Date()
            ChipView(
                icon: isPastToday ? "clock.badge.exclamationmark" : "calendar",
                text: text,
                color: color
            )
        }
    }

    @ViewBuilder
    private var reminderChip: some View {
        if let reminder = todo.reminderDate {
            let upcomingSoon = reminder > Date() && reminder < Date().addingTimeInterval(3600)
            ChipView(
                icon: "alarm",
                text: reminder.formatted(.dateTime.month().day().hour().minute()),
                color: Color(hex: 0xEC4899),
                pulse: upcomingSoon
            )
        }
    }
}
