import Foundation
import UserNotifications

// MARK: - 本地提醒通知

final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    static func identifier(for todo: TodoItem) -> String {
        "todo-\(todo.id.uuidString)"
    }

    /// 已授权（含临时授权）则返回 true，不弹窗
    func checkStatus() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// 必要时请求授权（仅在未决定状态弹窗）
    @discardableResult
    func requestIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return await checkStatus()
        }
    }

    /// 取消旧提醒并按待办的 reminderDate 重新安排
    func syncReminder(for todo: TodoItem) async {
        let id = Self.identifier(for: todo)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard !todo.isCompleted, let reminder = todo.reminderDate, reminder > Date() else { return }
        guard await requestIfNeeded() else { return }

        let content = UNMutableNotificationContent()
        content.title = "待办提醒"
        content.body = todo.title.trimmed.isEmpty ? "该完成任务啦" : todo.title
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: reminder
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancel(_ todo: TodoItem) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier(for: todo)])
    }
}
