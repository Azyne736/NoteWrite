import Foundation
import SwiftData
import SwiftUI

// MARK: - 优先级

enum Priority: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "无"
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .urgent: return "紧急"
        }
    }

    var color: Color {
        switch self {
        case .none: return Color(hex: 0x94A3B8)
        case .low: return Color(hex: 0x38BDF8)
        case .medium: return Color(hex: 0xFBBF24)
        case .high: return Color(hex: 0xFB7185)
        case .urgent: return Color(hex: 0xE11D48)
        }
    }

    var sortIndex: Int {
        Priority.allCases.firstIndex(of: self) ?? 0
    }
}

// MARK: - 重复规则

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case never
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly
    case everyNDays
    case weeklyOnDays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .never: return "不重复"
        case .daily: return "每天"
        case .weekly: return "每周"
        case .biweekly: return "每两周"
        case .monthly: return "每月"
        case .yearly: return "每年"
        case .everyNDays: return "自定义间隔"
        case .weeklyOnDays: return "每周指定日"
        }
    }
}

// MARK: - 重复规则引擎

enum RecurrenceEngine {
    static func nextOccurrence(
        after date: Date,
        rule: RepeatRule,
        intervalDays: Int = 1,
        weekdays: Set<Int> = [],
        calendar: Calendar = .current
    ) -> Date? {
        switch rule {
        case .never:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        case .everyNDays:
            return calendar.date(byAdding: .day, value: max(1, intervalDays), to: date)
        case .weeklyOnDays:
            guard !weekdays.isEmpty else { return nil }
            for offset in 1...14 {
                if let candidate = calendar.date(byAdding: .day, value: offset, to: date),
                   weekdays.contains(calendar.component(.weekday, from: candidate)) {
                    return candidate
                }
            }
            return nil
        }
    }

    static func describe(rule: RepeatRule, intervalDays: Int, weekdays: Set<Int>) -> String {
        switch rule {
        case .never:
            return ""
        case .everyNDays:
            return "每 \(max(1, intervalDays)) 天"
        case .weeklyOnDays:
            let names = [1: "日", 2: "一", 3: "二", 4: "三", 5: "四", 6: "五", 7: "六"]
            let days = [2, 3, 4, 5, 6, 7, 1]
                .filter { weekdays.contains($0) }
                .compactMap { names[$0] }
                .joined(separator: "·")
            return days.isEmpty ? "每周指定日" : "周\(days)"
        default:
            return rule.label
        }
    }
}

// MARK: - 待办模型

@Model
final class TodoItem {
    var id: UUID = UUID()
    var title: String = ""
    var noteText: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var dueDate: Date? = nil
    var hasSpecificTime: Bool = false
    var reminderDate: Date? = nil
    var priorityRaw: String = Priority.none.rawValue
    var repeatRuleRaw: String = RepeatRule.never.rawValue
    var repeatIntervalDays: Int = 2
    var repeatWeekdaysRaw: String = ""
    var pinned: Bool = false
    var isLongTerm: Bool = false
    var completedAt: Date? = nil
    var completionHistoryData: Data = Data()
    var tagsRaw: String = ""

    @Relationship(deleteRule: .cascade, inverse: \SubTask.todo)
    var subtasks: [SubTask] = []

    init(title: String = "", noteText: String = "") {
        self.title = title
        self.noteText = noteText
    }

    var isCompleted: Bool { completedAt != nil }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRuleRaw) ?? .never }
        set { repeatRuleRaw = newValue.rawValue }
    }

    var repeatWeekdays: Set<Int> {
        get { Set(repeatWeekdaysRaw.split(separator: ",").compactMap { Int($0) }) }
        set { repeatWeekdaysRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    var repeatDescription: String {
        RecurrenceEngine.describe(rule: repeatRule, intervalDays: repeatIntervalDays, weekdays: repeatWeekdays)
    }

    var tags: [String] {
        get {
            tagsRaw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set { tagsRaw = newValue.joined(separator: ",") }
    }

    var historyDates: [Date] {
        get { (try? JSONDecoder().decode([Date].self, from: completionHistoryData)) ?? [] }
        set { completionHistoryData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var historyDayKeys: [Int] {
        historyDates.map { Calendar.current.ordinality(of: .day, in: .era, for: $0) ?? 0 }
    }

    func addCompletion(_ date: Date) {
        var dates = historyDates
        dates.append(date)
        historyDates = dates
    }

    func removeLastCompletion() {
        var dates = historyDates
        if !dates.isEmpty { dates.removeLast() }
        historyDates = dates
    }

    var subtaskProgress: Double {
        guard !subtasks.isEmpty else { return 0 }
        let done = subtasks.filter(\.isDone).count
        return Double(done) / Double(subtasks.count)
    }

    /// 从当前截止日期（或缺省当前时间）开始，找到下一个晚于现在的重复时点
    func nextOccurrenceAfterNow() -> Date? {
        let now = Date()
        var cursor = dueDate ?? now
        for _ in 0..<600 {
            guard let next = RecurrenceEngine.nextOccurrence(
                after: cursor,
                rule: repeatRule,
                intervalDays: repeatIntervalDays,
                weekdays: repeatWeekdays
            ) else { return nil }
            if next > now { return next }
            cursor = next
        }
        return nil
    }
}

// MARK: - 子任务

@Model
final class SubTask {
    var id: UUID = UUID()
    var text: String = ""
    var isDone: Bool = false
    var orderIndex: Int = 0
    var createdAt: Date = Date()
    var todo: TodoItem? = nil

    init(text: String = "", orderIndex: Int = 0) {
        self.text = text
        self.orderIndex = orderIndex
    }
}

// MARK: - 排序

enum TodoSort {
    static func sort(_ items: [TodoItem], by key: String) -> [TodoItem] {
        switch key {
        case "created":
            return items.sorted { $0.createdAt > $1.createdAt }
        case "priority":
            return items.sorted {
                if $0.priority.sortIndex != $1.priority.sortIndex {
                    return $0.priority.sortIndex > $1.priority.sortIndex
                }
                return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
        case "title":
            return items.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        default:
            return items.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        }
    }

    static func defaultSort(_ items: [TodoItem]) -> [TodoItem] {
        items.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            let ad = a.dueDate ?? .distantFuture
            let bd = b.dueDate ?? .distantFuture
            if ad != bd { return ad < bd }
            return a.priority.sortIndex > b.priority.sortIndex
        }
    }
}

// MARK: - 待办操作

@MainActor
enum TodoActions {
    static func toggleComplete(_ todo: TodoItem, context: ModelContext) {
        if todo.isCompleted {
            todo.completedAt = nil
            todo.removeLastCompletion()
        } else {
            todo.addCompletion(Date())
            if todo.repeatRule != .never, let next = todo.nextOccurrenceAfterNow() {
                let base = todo.dueDate ?? Date()
                let delta = next.timeIntervalSince(base)
                todo.dueDate = next
                if let reminder = todo.reminderDate {
                    todo.reminderDate = reminder.addingTimeInterval(delta)
                }
                // 重复任务：滚动到下一次出现，保持未完成状态
            } else {
                todo.completedAt = Date()
            }
        }
        todo.updatedAt = Date()
        try? context.save()
        Task { await NotificationManager.shared.syncReminder(for: todo) }
    }

    static func delete(_ todo: TodoItem, context: ModelContext) {
        NotificationManager.shared.cancel(todo)
        context.delete(todo)
        try? context.save()
    }
}
