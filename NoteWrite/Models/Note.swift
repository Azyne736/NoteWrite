import Foundation
import SwiftData
import SwiftUI

// MARK: - 笔记模型

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var pinned: Bool = false
    var colorIndex: Int = 0
    var folder: String = ""
    var tagsRaw: String = ""

    @Relationship(deleteRule: .cascade, inverse: \NoteChecklistItem.note)
    var checklist: [NoteChecklistItem] = []

    init(title: String = "", content: String = "") {
        self.title = title
        self.content = content
    }

    var tags: [String] {
        get {
            tagsRaw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set { tagsRaw = newValue.joined(separator: ",") }
    }

    var isBlank: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        checklist.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.isEmpty
    }

    var sortedChecklist: [NoteChecklistItem] {
        checklist.sorted { $0.orderIndex < $1.orderIndex }
    }

    var checklistProgress: Double {
        guard !checklist.isEmpty else { return 0 }
        let done = checklist.filter(\.isDone).count
        return Double(done) / Double(checklist.count)
    }
}

// MARK: - 笔记清单项

@Model
final class NoteChecklistItem {
    var id: UUID = UUID()
    var text: String = ""
    var isDone: Bool = false
    var orderIndex: Int = 0
    var note: Note? = nil

    init(text: String = "", orderIndex: Int = 0) {
        self.text = text
        self.orderIndex = orderIndex
    }
}

// MARK: - 笔记配色

enum NotePalette {
    static let colors: [Color] = [
        Color(hex: 0xF59E0B), // 琥珀
        Color(hex: 0xF97316), // 橙
        Color(hex: 0xEC4899), // 粉
        Color(hex: 0x8B5CF6), // 紫
        Color(hex: 0x14B8A6), // 青
        Color(hex: 0x3B82F6), // 蓝
        Color(hex: 0x22C55E), // 绿
        Color(hex: 0x64748B)  // 石板灰
    ]

    static func color(_ index: Int) -> Color {
        colors.indices.contains(index) ? colors[index] : colors[0]
    }
}
