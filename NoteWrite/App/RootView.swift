import SwiftUI

struct RootView: View {
    @State private var selection: Tab = .today
    @State private var showSplash = true

    enum Tab: Int, CaseIterable, Identifiable {
        case today, todos, notes, stats, settings

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .today: return "今天"
            case .todos: return "待办"
            case .notes: return "笔记"
            case .stats: return "统计"
            case .settings: return "设置"
            }
        }

        var symbol: String {
            switch self {
            case .today: return "sun.max.fill"
            case .todos: return "checklist"
            case .notes: return "note.text"
            case .stats: return "chart.bar.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            pages
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 84)
                }

            VStack(spacing: 0) {
                Spacer()
                CustomTabBar(selection: $selection)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 6)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)

            if showSplash {
                SplashView()
                    .zIndex(2)
                    .transition(.opacity.combined(with: .scale(scale: 1.12)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: showSplash)
        .task {
            try? await Task.sleep(for: .seconds(1.15))
            withAnimation(.easeOut(duration: 0.55)) {
                showSplash = false
            }
        }
    }

    /// 页面交叉淡入淡出 + 轻微缩放，保留各页状态
    private var pages: some View {
        ZStack {
            ForEach(Tab.allCases) { tab in
                page(tab)
                    .opacity(selection == tab ? 1 : 0)
                    .scaleEffect(selection == tab ? 1 : 0.96)
                    .animation(.easeInOut(duration: 0.26), value: selection)
                    .allowsHitTesting(selection == tab)
            }
        }
    }

    @ViewBuilder
    private func page(_ tab: Tab) -> some View {
        switch tab {
        case .today:
            DashboardView(isActive: selection == .today) { selection = $0 }
        case .todos:
            TodoListView()
        case .notes:
            NotesListView()
        case .stats:
            StatsView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - 自定义底部标签栏（毛玻璃 + 匹配几何指示器）

struct CustomTabBar: View {
    @Binding var selection: RootView.Tab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(RootView.Tab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
        }
    }

    private func tabButton(_ tab: RootView.Tab) -> some View {
        let isSelected = selection == tab
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .symbolEffect(.bounce, value: isSelected)
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.16))
                        .matchedGeometryEffect(id: "tab.indicator", in: namespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.9))
    }
}

// MARK: - 启动动画

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x6366F1), Color(hex: 0x8B5CF6), Color(hex: 0xEC4899)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 108, height: 108)
                    Image(systemName: "square.and.pencil.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse)
                }
                Text("NoteWrite")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("记录想法 · 完成待办")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.85))
                ProgressView()
                    .tint(.white)
                    .padding(.top, 8)
            }
        }
    }
}
