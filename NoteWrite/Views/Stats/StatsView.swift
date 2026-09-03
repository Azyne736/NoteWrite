import SwiftUI
import SwiftData
import Charts

// MARK: - 统计（连续天数 / 周图表 / 热力图 / 概览）

struct StatsView: View {
    @Query private var todos: [TodoItem]
    @Query private var notes: [Note]

    @State private var appeared = false

    private var calendar: Calendar { Calendar.current }

    private var completionDayKeys: [Int] {
        todos.flatMap(\.historyDayKeys)
    }

    private var dayCountsDict: [Int: Int] {
        var dict: [Int: Int] = [:]
        for key in completionDayKeys {
            dict[key, default: 0] += 1
        }
        return dict
    }

    private var streakStats: (current: Int, best: Int, total: Int) {
        let keys = Set(completionDayKeys)
        let todayKey = calendar.ordinality(of: .day, in: .era, for: Date()) ?? 0

        var current = 0
        var cursor = todayKey
        if !keys.contains(cursor) {
            // 今天还没完成时，允许从昨天继续算
            let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            cursor = calendar.ordinality(of: .day, in: .era, for: yesterday) ?? 0
        }
        while keys.contains(cursor) {
            current += 1
            cursor -= 1
        }

        let sortedKeys = keys.sorted()
        var best = 0
        var run = 0
        var previous: Int? = nil
        for key in sortedKeys {
            if let p = previous, key == p + 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = key
        }
        return (current, max(best, current), sortedKeys.count)
    }

    private struct DayCount: Identifiable {
        let label: String
        let count: Int
        var id: String { label }
    }

    private var weekData: [DayCount] {
        let dict = dayCountsDict
        return (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let key = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
            return DayCount(
                label: date.formatted(.dateTime.weekday(.narrow)),
                count: dict[key] ?? 0
            )
        }
    }

    private var todayRowIndex: Int {
        let weekday = calendar.component(.weekday, from: Date()) // 1=周日 ... 7=周六
        return (weekday + 5) % 7 // 周一=0 ... 周日=6
    }

    private var heatmapStart: Date {
        let firstCell = calendar.date(
            byAdding: .day,
            value: -(17 * 7 + todayRowIndex),
            to: Date()
        ) ?? Date()
        return calendar.startOfDay(for: firstCell)
    }

    private var todayCompletedCount: Int {
        todos.flatMap(\.historyDates)
            .filter { calendar.isDateInToday($0) }
            .count
    }

    private var activeCount: Int {
        todos.filter { !$0.isCompleted }.count
    }

    private var todayActiveCount: Int {
        todos.filter { item in
            guard !item.isCompleted, let due = item.dueDate else { return false }
            return calendar.isDateInToday(due)
        }
        .count
    }

    private var todayPercent: Int {
        let total = todayActiveCount + todayCompletedCount
        guard total > 0 else { return 0 }
        return Int((Double(todayCompletedCount) / Double(total) * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    streakCard
                    weekCard
                    heatmapCard
                    tilesGrid
                }
                .padding(16)
            }
            .navigationTitle("统计")
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    // MARK: 连续完成卡

    private var streakCard: some View {
        let stats = streakStats
        return HStack(spacing: 16) {
            ZStack {
                Circle().fill(
                    LinearGradient(
                        colors: [Color(hex: 0xF97316), Color(hex: 0xEC4899)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                Image(systemName: "flame.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)
            }
            .frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text("连续完成")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(stats.current)")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                    Text("天")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("最长 \(stats.best) 天 · 累计 \(stats.total) 次完成")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: 最近 7 天柱状图

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("最近 7 天", systemImage: "chart.bar.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart(weekData) { item in
                BarMark(
                    x: .value("日期", item.label),
                    y: .value("完成数", appeared ? item.count : 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.5), Color.accentColor],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(5)
                .annotation(position: .top, spacing: 2) {
                    if item.count > 0 {
                        Text("\(item.count)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks {
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 150)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: 18 周热力图（逐列弹入）

    private var heatmapCard: some View {
        let dict = dayCountsDict
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("完成热力图", systemImage: "square.grid.3x3.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 3) {
                    Text("少")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    ForEach(0...3, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatmapColor(level: level))
                            .frame(width: 10, height: 10)
                    }
                    Text("多")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            HStack(alignment: .top, spacing: 4) {
                VStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { row in
                        Text(weekdayRowLabel(row))
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .frame(height: 13, alignment: .center)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(0..<18, id: \.self) { week in
                            VStack(spacing: 4) {
                                ForEach(0..<7, id: \.self) { row in
                                    heatmapCell(week: week, row: row, dict: dict)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func weekdayRowLabel(_ row: Int) -> String {
        ["一", "", "三", "", "五", "", "日"][row]
    }

    @ViewBuilder
    private func heatmapCell(week: Int, row: Int, dict: [Int: Int]) -> some View {
        let date = calendar.date(byAdding: .day, value: week * 7 + row, to: heatmapStart) ?? heatmapStart
        let isFuture = date > Date()
        let key = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let count = dict[key] ?? 0
        RoundedRectangle(cornerRadius: 2.5)
            .fill(
                isFuture
                    ? AnyShapeStyle(Color.clear)
                    : AnyShapeStyle(heatmapColor(level: min(3, count)))
            )
            .frame(width: 13, height: 13)
            .opacity(isFuture ? 0 : (appeared ? 1 : 0))
            .scaleEffect(appeared ? 1 : 0.2)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.7).delay(Double(week) * 0.025),
                value: appeared
            )
    }

    private func heatmapColor(level: Int) -> Color {
        switch level {
        case 0: return Color.primary.opacity(0.06)
        case 1: return Color.accentColor.opacity(0.35)
        case 2: return Color.accentColor.opacity(0.65)
        default: return Color.accentColor
        }
    }

    // MARK: 概览磁贴

    private var tilesGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            statTile(
                icon: "checkmark.circle.fill",
                color: Color(hex: 0x22C55E),
                label: "今日完成",
                value: "\(todayCompletedCount)"
            )
            statTile(
                icon: "checklist",
                color: .accentColor,
                label: "进行中",
                value: "\(activeCount)"
            )
            statTile(
                icon: "note.text",
                color: Color(hex: 0xF59E0B),
                label: "笔记数",
                value: "\(notes.count)"
            )
            statTile(
                icon: "target",
                color: Color(hex: 0xEC4899),
                label: "今日完成率",
                value: "\(todayPercent)%"
            )
        }
    }

    private func statTile(icon: String, color: Color, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .symbolEffect(.bounce, value: value)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
