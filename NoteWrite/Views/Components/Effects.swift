import SwiftUI

// MARK: - 颜色 / 字符串工具

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Date {
    static func todayAt(hour: Int, minute: Int, calendar: Calendar = .current) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps) ?? Date()
    }
}

// MARK: - 弹性按压按钮

struct BouncyButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

// MARK: - 抖动效果

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    var travel: CGFloat = 7
    var shakesPerUnit: CGFloat = 3

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: travel * sin(animatableData * .pi * shakesPerUnit * 2),
                y: 0
            )
        )
    }
}

// MARK: - 动画进度环

struct ProgressRing: View {
    var progress: Double
    var size: CGFloat = 32
    var lineWidth: CGFloat = 4
    var tint: Color = .accentColor

    @State private var intro = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: intro ? progress : 0)
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.6), tint],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.15)) {
                intro = true
            }
        }
        .onChange(of: progress) { _, _ in
            intro = true
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: progress)
    }
}

// MARK: - 彩带粒子（Canvas 物理模拟）

struct ConfettiBurst: View {
    var trigger: Int

    static let defaultPalette: [Color] = [
        Color(hex: 0xF43F5E), Color(hex: 0xF97316), Color(hex: 0xFACC15),
        Color(hex: 0x22C55E), Color(hex: 0x06B6D4), Color(hex: 0x6366F1),
        Color(hex: 0xEC4899)
    ]

    struct Particle {
        let angle: Double
        let speed: Double
        let spin: Double
        let width: Double
        let height: Double
        let color: Color
        let isCircle: Bool
    }

    static func makeParticles() -> [Particle] {
        (0..<42).map { index in
            Particle(
                angle: Double(index) / 42.0 * 2 * .pi + Double.random(in: -0.08...0.08),
                speed: Double.random(in: 0.45...1.35),
                spin: Double.random(in: -8...8),
                width: Double.random(in: 4...8),
                height: Double.random(in: 3...6),
                color: defaultPalette.randomElement() ?? .pink,
                isCircle: Bool.random()
            )
        }
    }

    @State private var startDate: Date? = nil
    @State private var particles: [Particle] = ConfettiBurst.makeParticles()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                guard let start = startDate else { return }
                let t = timeline.date.timeIntervalSince(start)
                guard t > 0, t < 1.15 else { return }

                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let fade = max(0, 1 - min(1, t / 1.1))

                for particle in particles {
                    let distance = 26 + particle.speed * 130 * t
                    let gravity = 190 * t * t
                    let x = center.x + cos(particle.angle) * distance
                    let y = center.y + sin(particle.angle) * distance * 0.85 + gravity

                    var ctx = context
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(particle.spin * t))

                    let rect = CGRect(
                        x: -particle.width / 2,
                        y: -particle.height / 2,
                        width: particle.width,
                        height: particle.height
                    )
                    if particle.isCircle {
                        ctx.fill(Path(ellipseIn: rect), with: .color(particle.color.opacity(fade)))
                    } else {
                        ctx.fill(
                            Path(roundedRect: rect, cornerRadius: 1.5),
                            with: .color(particle.color.opacity(fade))
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            startDate = Date()
        }
    }
}

// MARK: - 流动网格渐变背景（MeshGradient）

struct AnimatedMeshBackground: View {
    var colors: [Color]
    var active: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(width: 3, height: 3, points: points(at: t), colors: colors)
        }
    }

    private func osc(_ t: TimeInterval, _ frequency: Double, _ phase: Double, _ amplitude: Double = 0.15) -> Float {
        Float(0.5 + sin(t * frequency + phase) * amplitude)
    }

    private func points(at t: TimeInterval) -> [SIMD2<Float>] {
        [
            [0, 0],
            [osc(t, 0.9, 0.0), osc(t, 1.3, 1.7, 0.12)],
            [1, 0],
            [osc(t, 1.1, 2.4, 0.12), osc(t, 0.8, 0.9)],
            [osc(t, 0.7, 3.8), osc(t, 1.0, 5.1)],
            [1 - osc(t, 1.2, 4.4, 0.12), osc(t, 0.9, 2.2)],
            [0, 1],
            [osc(t, 1.4, 6.0), 1 - osc(t, 1.1, 1.2, 0.12)],
            [1, 1]
        ]
    }
}

// MARK: - 空状态

struct EmptyStateView: View {
    let icon: String
    let title: String
    let caption: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor.opacity(0.8))
                .symbolEffect(.pulse)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - 毛玻璃卡片容器

struct CardContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }
}

// MARK: - 区块标题

struct SectionHeader: View {
    let title: String
    let icon: String
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(color)
        .textCase(nil)
    }
}

// MARK: - 标签胶囊

struct ChipView: View {
    var icon: String? = nil
    let text: String
    var color: Color = .secondary
    var pulse: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                iconView
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.13)))
    }

    @ViewBuilder
    private var iconView: some View {
        if pulse {
            Image(systemName: icon ?? "").symbolEffect(.pulse)
        } else {
            Image(systemName: icon ?? "")
        }
    }
}

// MARK: - 编辑器卡片

struct EditorCard<Content: View>: View {
    let title: String
    let icon: String
    private let content: Content

    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
    }
}
