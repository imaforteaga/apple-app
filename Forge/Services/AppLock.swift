import SwiftUI
import LocalAuthentication

/// Optional Face ID / Touch ID / passcode lock. Everything stays on device.
@MainActor
final class AppLock: ObservableObject {
    static let defaultsKey = "faceIDEnabled"

    @Published var isLocked: Bool
    @Published var errorMessage: String?
    private var isAuthenticating = false

    init() {
        isLocked = UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.defaultsKey) }

    var biometryName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Passcode"
        }
    }

    /// Turn protection on/off. Turning on requires a successful authentication first.
    func setEnabled(_ on: Bool) async -> Bool {
        if on {
            let ok = await evaluate(reason: "Turn on app lock")
            if ok { UserDefaults.standard.set(true, forKey: Self.defaultsKey) }
            return ok
        } else {
            let ok = await evaluate(reason: "Turn off app lock")
            if ok {
                UserDefaults.standard.set(false, forKey: Self.defaultsKey)
                isLocked = false
            }
            return ok
        }
    }

    func lockIfNeeded() {
        if isEnabled { isLocked = true }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        if await evaluate(reason: "Unlock your private data") { isLocked = false }
    }

    private func evaluate(reason: String) async -> Bool {
        isAuthenticating = true
        defer { isAuthenticating = false }
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            errorMessage = error?.localizedDescription ?? "Set a device passcode in Settings to use app lock."
            return false
        }
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            errorMessage = nil
            return ok
        } catch {
            errorMessage = (error as? LAError)?.code == .userCancel ? nil : error.localizedDescription
            return false
        }
    }
}

struct LockView: View {
    @EnvironmentObject private var lock: AppLock

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Circle()
                .fill(Theme.brandGradient)
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .opacity(0.25)
                .offset(y: -200)
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(Theme.brandGradient))
                    .shadow(color: Theme.orange.opacity(0.4), radius: 20, y: 8)
                Text("Forge is locked")
                    .font(Theme.display(28))
                    .foregroundStyle(Theme.text)
                Text("Your photos, measurements and journal are private.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                if let msg = lock.errorMessage {
                    Text(msg).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Spacer()
                Button("Unlock with \(lock.biometryName)") {
                    Task { await lock.unlock() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .task { await lock.unlock() }
    }
}
