import SwiftUI

// MARK: - Card

struct CardStyle: ViewModifier {
    var padding: CGFloat = 18
    var fill: Color = Theme.card
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .stroke(Theme.hairline.opacity(0.55), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.035), radius: 18, x: 0, y: 6)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .onAppear {
                guard !appeared else { return }
                withAnimation(Motion.gentle) { appeared = true }
            }
    }
}

/// Soft fade-and-rise entrance, optionally staggered with `delay`.
struct RiseModifier: ViewModifier {
    var delay: Double = 0
    @State private var appeared = false
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .onAppear {
                guard !appeared else { return }
                withAnimation(Motion.gentle.delay(delay)) { appeared = true }
            }
    }
}

/// Gentle press feedback for tappable rows and cards.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

extension View {
    func card(padding: CGFloat = 18, fill: Color = Theme.card) -> some View {
        modifier(CardStyle(padding: padding, fill: fill))
    }

    func rise(delay: Double = 0) -> some View { modifier(RiseModifier(delay: delay)) }

    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }

    /// Styles a `Form` / `List` to match the warm design system.
    func warmForm() -> some View {
        self.scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }

    func keyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(compact ? .subheadline : .body, design: .default, weight: .medium))
            .foregroundStyle(Theme.background)
            .padding(.vertical, compact ? 10 : 15)
            .padding(.horizontal, compact ? 18 : 22)
            .frame(maxWidth: compact ? nil : .infinity)
            .background(Capsule(style: .continuous).fill(Theme.text))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(compact ? .subheadline : .body, design: .default, weight: .medium))
            .foregroundStyle(Theme.accentText)
            .padding(.vertical, compact ? 10 : 14)
            .padding(.horizontal, compact ? 16 : 20)
            .frame(maxWidth: compact ? nil : .infinity)
            .background(Capsule(style: .continuous).fill(Theme.softAccent))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

// MARK: - Progress ring

struct ProgressRing<Center: View>: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var colors: [Color] = [Theme.yellow, Theme.orange]
    @ViewBuilder var center: () -> Center

    @State private var shown: Double = 0

    var body: some View {
        let p = min(max(shown, 0), 1)
        ZStack {
            Circle().stroke(Theme.cardAlt, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: p)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: colors),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(max(1, 360 * p))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center()
        }
        .onAppear { withAnimation(Motion.ring) { shown = progress } }
        .onChange(of: progress) { _, new in
            withAnimation(Motion.ring) { shown = new }
        }
    }
}

extension ProgressRing where Center == EmptyView {
    init(progress: Double, lineWidth: CGFloat = 12, colors: [Color] = [Theme.yellow, Theme.orange]) {
        self.init(progress: progress, lineWidth: lineWidth, colors: colors) { EmptyView() }
    }
}

/// Small labelled ring used on the dashboard.
struct RingStat: View {
    let title: String
    let value: String
    let detail: String
    let progress: Double
    var icon: String? = nil
    var size: CGFloat = 92

    var body: some View {
        VStack(spacing: 10) {
            ProgressRing(progress: progress, lineWidth: 9) {
                VStack(spacing: 0) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.orange)
                    }
                    Text(value)
                        .font(Theme.number(18))
                        .foregroundStyle(Theme.text)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .animation(Motion.soft, value: value)
                }
                .padding(.horizontal, 6)
            }
            .frame(width: size, height: size)
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(.footnote, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Headers, chips, rows

struct SectionTitle<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.display(22))
                    .foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            trailing()
        }
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct Chip: View {
    let title: String
    var icon: String? = nil
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .semibold)) }
                Text(title).font(.system(.subheadline, design: .default, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(selected ? Color.white : Theme.text)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? AnyShapeStyle(Theme.orange) : AnyShapeStyle(Theme.cardAlt))
            )
            .scaleEffect(selected ? 1.0 : 0.98)
        }
        .buttonStyle(PressableStyle())
        .animation(Motion.quick, value: selected)
    }
}

struct ChipPicker<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String
    var icon: ((T) -> String?)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { opt in
                    Chip(title: label(opt), icon: icon?(opt), selected: opt == selection) {
                        selection = opt
                    }
                }
            }
            .padding(.horizontal, Theme.pad)
        }
    }
}

struct IconBadge: View {
    let systemName: String
    var size: CGFloat = 38
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Theme.accentText)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.softAccent))
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var icon: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let icon { IconBadge(systemName: icon, size: 30) }
            Text(value)
                .font(Theme.number(24))
                .foregroundStyle(Theme.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(Motion.soft, value: value)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .card(padding: 14)
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            IconBadge(systemName: icon, size: 54)
            Text(title)
                .font(Theme.display(19))
                .foregroundStyle(Theme.text)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
}

struct LinearProgressBar: View {
    var progress: Double
    var height: CGFloat = 8
    @State private var shown: Double = 0
    var body: some View {
        let progress = shown
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.cardAlt)
                Capsule()
                    .fill(Theme.brandGradient)
                    .frame(width: max(height, geo.size.width * CGFloat(min(max(progress, 0), 1))))
                    .opacity(progress > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .onAppear { withAnimation(Motion.ring) { shown = self.progress } }
        .onChange(of: self.progress) { _, new in withAnimation(Motion.soft) { shown = new } }
    }
}

struct MacroBar: View {
    let label: String
    let value: Double
    let goal: Double
    var unit: String = "g"
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(.footnote.weight(.semibold)).foregroundStyle(Theme.text)
                Spacer()
                Text("\(value.whole) / \(goal.whole) \(unit)")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            LinearProgressBar(progress: goal > 0 ? value / goal : 0, height: 7)
        }
    }
}

// MARK: - Number input

/// Decimal text field bound to an optional Double – empty text means `nil`.
struct NumberField: View {
    let title: String
    @Binding var value: Double?
    var unit: String = ""
    var placeholder: String = "–"
    @State private var text = ""

    init(_ title: String, value: Binding<Double?>, unit: String = "", placeholder: String = "–") {
        self.title = title
        self._value = value
        self.unit = unit
        self.placeholder = placeholder
    }

    /// Non-optional convenience.
    init(_ title: String, required: Binding<Double>, unit: String = "") {
        self.title = title
        self._value = Binding<Double?>(
            get: { required.wrappedValue },
            set: { if let v = $0 { required.wrappedValue = v } })
        self.unit = unit
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
                .onChange(of: text) { _, new in
                    let parsed = parseDouble(new)
                    if parsed != value { value = parsed }
                }
            if !unit.isEmpty {
                Text(unit).foregroundStyle(Theme.textSecondary)
            }
        }
        .onAppear { if let v = value { text = v.clean } }
        .onChange(of: value) { _, new in
            // Reflect programmatic changes (e.g. scaling a portion) without fighting the user's typing.
            if parseDouble(text) != new { text = new.map { $0.clean } ?? "" }
        }
    }
}

struct IntStepperRow: View {
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...1000
    var step: Int = 1
    var unit: String = ""

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)\(unit.isEmpty ? "" : " " + unit)")
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Achievement overlay (restrained, not childish)

struct AchievementOverlay: View {
    let title: String
    let subtitle: String
    var onDismiss: () -> Void
    @State private var go = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            VStack(spacing: 18) {
                ZStack {
                    ForEach(0..<14, id: \.self) { i in
                        Capsule()
                            .fill(Theme.brandGradient)
                            .frame(width: 4, height: 16)
                            .offset(y: go ? -78 : -44)
                            .rotationEffect(.degrees(Double(i) * (360.0 / 14.0)))
                            .opacity(go ? 0 : 1)
                    }
                    Circle()
                        .fill(Theme.brandGradient)
                        .frame(width: 84, height: 84)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white))
                        .scaleEffect(go ? 1 : 0.3)
                        .shadow(color: Theme.orange.opacity(0.25), radius: 16, y: 8)
                }
                .frame(height: 170)
                VStack(spacing: 6) {
                    Text("Milestone reached")
                        .font(.system(.caption, design: .default, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.accentText)
                        .textCase(.uppercase)
                    Text(title)
                        .font(Theme.display(24))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.textSecondary)
                }
                Button("Continue", action: onDismiss)
                    .buttonStyle(PrimaryButtonStyle(compact: true))
            }
            .padding(28)
            .frame(maxWidth: 330)
            .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Theme.card))
            .shadow(color: .black.opacity(0.14), radius: 30, y: 12)
            .scaleEffect(go ? 1 : 0.92)
            .opacity(go ? 1 : 0)
        }
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) { go = true }
        }
        .transition(.opacity)
    }
}
