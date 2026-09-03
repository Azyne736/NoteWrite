import SwiftUI

// MARK: - 主题色选项

enum AccentChoice: Int, CaseIterable, Identifiable {
    case indigo = 0
    case blue
    case teal
    case green
    case orange
    case pink
    case purple

    var id: Int { rawValue }

    var color: Color {
        switch self {
        case .indigo: return Color(hex: 0x6366F1)
        case .blue: return Color(hex: 0x3B82F6)
        case .teal: return Color(hex: 0x14B8A6)
        case .green: return Color(hex: 0x22C55E)
        case .orange: return Color(hex: 0xF97316)
        case .pink: return Color(hex: 0xEC4899)
        case .purple: return Color(hex: 0x8B5CF6)
        }
    }

    var name: String {
        ["靛蓝", "蓝色", "青色", "绿色", "橙色", "粉色", "紫色"][rawValue]
    }
}

// MARK: - 全局设置（UserDefaults 持久化）

@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    var theme: Int {
        didSet { defaults.set(theme, forKey: "settings.theme") }
    }

    var accent: Int {
        didSet { defaults.set(accent, forKey: "settings.accent") }
    }

    var hapticsOn: Bool {
        didSet { defaults.set(hapticsOn, forKey: "settings.haptics") }
    }

    var confettiOn: Bool {
        didSet { defaults.set(confettiOn, forKey: "settings.confetti") }
    }

    private init() {
        theme = defaults.integer(forKey: "settings.theme")
        if defaults.object(forKey: "settings.accent") != nil {
            accent = defaults.integer(forKey: "settings.accent")
        } else {
            accent = AccentChoice.indigo.rawValue
        }
        hapticsOn = defaults.object(forKey: "settings.haptics") == nil
            ? true
            : defaults.bool(forKey: "settings.haptics")
        confettiOn = defaults.object(forKey: "settings.confetti") == nil
            ? true
            : defaults.bool(forKey: "settings.confetti")
    }

    var scheme: ColorScheme? {
        switch theme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var accentColor: Color {
        AccentChoice(rawValue: accent)?.color ?? AccentChoice.indigo.color
    }
}
