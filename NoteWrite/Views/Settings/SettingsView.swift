import SwiftUI
import SwiftData

// MARK: - 设置（外观 / 动效 / 通知 / 数据 / 关于）

struct SettingsView: View {
    @Bindable private var settings = SettingsStore.shared

    @Query private var todos: [TodoItem]
    @Query private var notes: [Note]
    @Environment(\.modelContext) private var context

    @State private var notificationGranted: Bool? = nil
    @State private var showClearConfirm = false
    @State private var showWipeConfirm = false

    private let repoURL = "https://github.com/Azyne736/NoteWrite"

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }

    private var statusText: String {
        switch notificationGranted {
        case .some(true): return "已开启"
        case .some(false): return "未开启"
        case .none: return "未检测"
        }
    }

    private var exportText: String {
        var lines: [String] = [
            "NoteWrite 数据导出",
            "导出时间：\(Date.now.formatted())",
            ""
        ]
        lines.append("—— 待办 (\(todos.count)) ——")
        for todo in todos {
            var line = "• \(todo.title.isEmpty ? "无标题待办" : todo.title)"
            if let due = todo.dueDate {
                line += "（截止 \(due.formatted())）"
            }
            if todo.isCompleted { line += " ✅" }
            if todo.repeatRule != .never { line += " 🔁\(todo.repeatDescription)" }
            lines.append(line)
            for sub in todo.subtasks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                lines.append("   \(sub.isDone ? "☑" : "☐") \(sub.text)")
            }
        }
        lines.append("")
        lines.append("—— 笔记 (\(notes.count)) ——")
        for note in notes {
            lines.append("◆ \(note.title.isEmpty ? "无标题" : note.title)")
            if !note.content.isEmpty {
                lines.append(note.content)
            }
            for item in note.sortedChecklist {
                lines.append("   \(item.isDone ? "☑" : "☐") \(item.text)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("外观", selection: $settings.theme) {
                        Text("跟随系统").tag(0)
                        Text("浅色").tag(1)
                        Text("深色").tag(2)
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 14) {
                        ForEach(AccentChoice.allCases) { choice in
                            accentDot(choice)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                } header: {
                    Text("外观")
                }

                Section {
                    Toggle("触感反馈", isOn: $settings.hapticsOn)
                    Toggle("完成待办的彩带特效", isOn: $settings.confettiOn)
                } header: {
                    Text("动效与反馈")
                } footer: {
                    Text("彩带特效会在完成待办时从勾选框绽放而出")
                }

                Section {
                    Button {
                        Task {
                            notificationGranted = await NotificationManager.shared.requestIfNeeded()
                            if notificationGranted == true {
                                Haptics.success()
                            }
                        }
                    } label: {
                        Label("请求通知权限", systemImage: "bell.badge")
                    }
                    LabeledContent("权限状态", value: statusText)
                    if notificationGranted == false {
                        Label("请前往 系统设置 > 通知 开启", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("提醒通知")
                }

                Section {
                    ShareLink(item: exportText) {
                        Label("导出全部数据（文本）", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("清除已完成的待办", systemImage: "trash")
                    }
                    Button(role: .destructive) {
                        showWipeConfirm = true
                    } label: {
                        Label("删除全部数据", systemImage: "trash.slash")
                    }
                } header: {
                    Text("数据")
                }

                Section {
                    LabeledContent("版本", value: appVersion)
                    LabeledContent("构建", value: "GitHub Actions · iOS 26")
                    Link(destination: URL(string: repoURL)!) {
                        Label("源码仓库", systemImage: "curlybraces.square")
                    }
                } header: {
                    Text("关于")
                } footer: {
                    Text("NoteWrite · SwiftUI + SwiftData 构建，充满动效的笔记与待办应用。")
                }
            }
            .navigationTitle("设置")
            .tint(settings.accentColor)
            .task {
                notificationGranted = await NotificationManager.shared.checkStatus()
            }
            .confirmationDialog(
                "清除所有已完成的待办？",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("清除", role: .destructive) { clearCompleted() }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog(
                "删除全部数据？此操作不可恢复。",
                isPresented: $showWipeConfirm,
                titleVisibility: .visible
            ) {
                Button("全部删除", role: .destructive) { wipeAll() }
                Button("取消", role: .cancel) {}
            }
        }
    }

    // MARK: 主题色选择

    private func accentDot(_ choice: AccentChoice) -> some View {
        let isSelected = settings.accent == choice.rawValue
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                settings.accent = choice.rawValue
            }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(choice.color)
                    .frame(width: 30, height: 30)
                    .overlay {
                        if isSelected {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.8), lineWidth: 2)
                                .padding(-4)
                        }
                    }
                    .scaleEffect(isSelected ? 1.12 : 1)
                Text(choice.name)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.85))
    }

    // MARK: 数据操作

    private func clearCompleted() {
        Haptics.warning()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            for todo in todos where todo.isCompleted {
                TodoActions.delete(todo, context: context)
            }
        }
    }

    private func wipeAll() {
        Haptics.warning()
        withAnimation {
            for todo in todos {
                NotificationManager.shared.cancel(todo)
                context.delete(todo)
            }
            for note in notes {
                context.delete(note)
            }
            try? context.save()
        }
    }
}
