import SwiftUI
import UIKit
import UserNotifications
import LocalAuthentication
import FirebaseCore
import GoogleSignIn

@main
struct LuminaApp: App {
    @UIApplicationDelegateAdaptor(LuminaAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()
    @StateObject private var notificationRouter = NotificationNavigationRouter.shared
    @AppStorage(WelcomeGuideStorage.completionKey) private var hasCompletedWelcomeGuide = false
    @AppStorage(LuminaAppearanceMode.storageKey) private var appearanceModeRawValue = LuminaAppearanceMode.system.rawValue
    @State private var isReplayingWelcomeGuide = false
    @State private var isShowingStartup = true
    @State private var isPrivacyUnlocked = false
    @State private var isAuthenticatingPrivacyLock = false
    @State private var privacyLockError: String? = nil

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()

                if isShowingStartup {
                    LuminaStartupView()
                        .transition(.opacity)
                        .zIndex(10)
                }

                if appState.requireBiometrics && !isPrivacyUnlocked && !isShowingStartup {
                    LuminaPrivacyLockView(
                        errorMessage: privacyLockError,
                        onUnlock: authenticatePrivacyLock
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .environmentObject(appState)
            .preferredColorScheme(LuminaAppearanceMode.normalized(appearanceModeRawValue).colorScheme)
            .luminaLargeText(appState.useLargeText)
                .fullScreenCover(
                    isPresented: Binding(
                        get: { !hasCompletedWelcomeGuide || isReplayingWelcomeGuide },
                        set: { isPresented in
                            if !isPresented {
                                hasCompletedWelcomeGuide = true
                                isReplayingWelcomeGuide = false
                            }
                        }
                    )
                ) {
                    WelcomeGuideView(
                        isReplay: hasCompletedWelcomeGuide,
                        onFinish: completeWelcomeGuide,
                        onSkip: completeWelcomeGuide
                    )
                    .environmentObject(appState)
                    .interactiveDismissDisabled()
                }
                .onAppear {
                    LuminaAppearanceMode.applyInterfaceStyleOverride(appearanceModeRawValue)
                    handleNotificationRequest(notificationRouter.pendingRequest)
                    dismissStartupAfterDelay()
                }
                .onChange(of: appearanceModeRawValue) { rawValue in
                    LuminaAppearanceMode.applyInterfaceStyleOverride(rawValue)
                }
                .onChange(of: notificationRouter.pendingRequest) { request in
                    handleNotificationRequest(request)
                }
                .onChange(of: appState.requireBiometrics) { enabled in
                    if enabled {
                        isPrivacyUnlocked = false
                        authenticatePrivacyLock()
                    } else {
                        isPrivacyUnlocked = true
                        isAuthenticatingPrivacyLock = false
                        privacyLockError = nil
                    }
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        dismissStartupAfterDelay()
                    }
                    guard appState.requireBiometrics else { return }
                    switch phase {
                    case .active:
                        if !isShowingStartup && !isPrivacyUnlocked && !isAuthenticatingPrivacyLock {
                            authenticatePrivacyLock()
                        }
                    case .background:
                        isPrivacyUnlocked = false
                        isAuthenticatingPrivacyLock = false
                    default:
                        break
                    }
                }
            .onReceive(NotificationCenter.default.publisher(for: .luminaShowWelcomeGuide)) { _ in
                isReplayingWelcomeGuide = true
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }

    private func completeWelcomeGuide() {
        hasCompletedWelcomeGuide = true
        isReplayingWelcomeGuide = false
    }

    private func handleNotificationRequest(_ request: NotificationNavigationRequest?) {
        guard let request else { return }
        appState.handleNotificationNavigation(request)
        notificationRouter.clearPendingRequest(id: request.id)
    }

    private func dismissStartupAfterDelay() {
        guard isShowingStartup else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard isShowingStartup else { return }
            withAnimation(.easeOut(duration: 0.24)) {
                isShowingStartup = false
            }
            appState.startPostLaunchServices()
        }
    }

    private func authenticatePrivacyLock() {
        guard appState.requireBiometrics else {
            isPrivacyUnlocked = true
            isAuthenticatingPrivacyLock = false
            privacyLockError = nil
            return
        }
        guard !isPrivacyUnlocked, !isAuthenticatingPrivacyLock else { return }

        let context = LAContext()
        var authError: NSError?
        let reason = "Unlock Lumina to view your private reflections and conversations."

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            privacyLockError = authError?.localizedDescription ?? "Device authentication is not available."
            appState.requireBiometrics = false
            isPrivacyUnlocked = true
            isAuthenticatingPrivacyLock = false
            return
        }

        isAuthenticatingPrivacyLock = true
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            Task { @MainActor in
                isAuthenticatingPrivacyLock = false
                isPrivacyUnlocked = success
                privacyLockError = success ? nil : (error?.localizedDescription ?? "Authentication was not completed.")
            }
        }
    }
}

private struct LuminaStartupView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: 0x070B06), Color.organicBackground, Color.organicBackdrop]
                    : [Color(hex: 0xFFFCF4), Color.organicBackground, Color(hex: 0xEEF4EA)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Image("LuminaLaunchMark")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 168, height: 168)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.10), radius: 20, x: 0, y: 14)
                .shadow(color: Color.organicPrimary.opacity(colorScheme == .dark ? 0.18 : 0.10), radius: 28, x: 0, y: 0)
                .accessibilityHidden(true)
        }
    }
}

private struct LuminaPrivacyLockView: View {
    @Environment(\.colorScheme) private var colorScheme
    let errorMessage: String?
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: 0x050805), Color(hex: 0x0B1209), Color(hex: 0x11180F)]
                    : [Color(hex: 0xFFFDF6), Color(hex: 0xF6F1E7), Color(hex: 0xEEF5EA)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            PrivacyLockAmbientArt(colorScheme: colorScheme)

            VStack(spacing: 28) {
                Spacer(minLength: 40)

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Color.organicPrimary.opacity(colorScheme == .dark ? 0.13 : 0.10))
                            .frame(width: 150, height: 150)
                            .blur(radius: 18)
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .fill(Color.organicElevated.opacity(colorScheme == .dark ? 0.82 : 0.92))
                            .frame(width: 118, height: 118)
                            .overlay {
                                RoundedRectangle(cornerRadius: 34, style: .continuous)
                                    .strokeBorder(Color.organicPrimary.opacity(0.26), lineWidth: 1)
                            }
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 22, x: 0, y: 14)
                        Image("LuminaMark")
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .accessibilityHidden(true)
                    }

                    VStack(spacing: 7) {
                        Text("A quiet pause")
                            .luminaFont(size: 12, weight: .black)
                            .kerning(2.4)
                            .foregroundColor(.organicMutedFg)
                        Text("Your space is protected")
                            .luminaFont(size: 32, weight: .bold, design: .serif)
                            .foregroundColor(.organicForeground)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.82)
                        Text("Take one easy breath. Lumina will open when you are ready.")
                            .luminaFont(size: 15, weight: .medium)
                            .foregroundColor(.organicMutedFg)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                    }
                }

                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .luminaFont(size: 15, weight: .bold)
                            .foregroundColor(.organicPrimary)
                        Text("Private reflections stay on the other side of this lock.")
                            .luminaFont(size: 12, weight: .semibold)
                            .foregroundColor(.organicMutedFg)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.organicElevated.opacity(colorScheme == .dark ? 0.74 : 0.86))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.organicBorder.opacity(0.55), lineWidth: 1)
                    }

                    Button(action: onUnlock) {
                        HStack(spacing: 10) {
                            Image(systemName: "faceid")
                                .luminaFont(size: 18, weight: .bold)
                            Text("Unlock Lumina")
                                .luminaFont(size: 16, weight: .black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.organicPrimary)
                        .foregroundColor(.organicPrimaryFg)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.organicPrimary.opacity(colorScheme == .dark ? 0.18 : 0.24), radius: 18, x: 0, y: 10)
                    }
                    .buttonStyle(.plain)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .luminaFont(size: 12, weight: .semibold)
                        .foregroundColor(Color(hex: 0xBE185D))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                Spacer()

                Text("Face ID, Touch ID, or passcode")
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(.organicMutedFg.opacity(0.82))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 34)
            .frame(maxWidth: 420)
        }
    }
}

private struct PrivacyLockAmbientArt: View {
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Circle()
                        .fill(Color.organicPrimary.opacity(colorScheme == .dark ? 0.14 : 0.12))
                        .frame(width: 220, height: 220)
                        .blur(radius: 46)
                        .offset(x: -82, y: -44)
                    Spacer()
                }
                Spacer()
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.organicSecondary.opacity(colorScheme == .dark ? 0.12 : 0.15))
                        .frame(width: 260, height: 260)
                        .blur(radius: 58)
                        .offset(x: 88, y: 80)
                }
            }

            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 120, style: .continuous)
                    .stroke(Color.organicPrimary.opacity(Double(3 - index) * 0.035), lineWidth: 1)
                    .frame(width: CGFloat(250 + index * 62), height: CGFloat(250 + index * 62))
                    .rotationEffect(.degrees(Double(index) * 10))
                    .offset(y: -170)
                    .accessibilityHidden(true)
            }
        }
        .allowsHitTesting(false)
    }
}

enum WelcomeGuideStorage {
    static let completionKey = "lumina.hasCompletedWelcomeGuide"
}

extension Notification.Name {
    static let luminaShowWelcomeGuide = Notification.Name("lumina.showWelcomeGuide")
}

// MARK: - Welcome Guide
struct WelcomeGuideView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedStart: WelcomeStartOption = .reflect

    let isReplay: Bool
    let onFinish: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            WelcomeGuideBackground()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        welcomeHeader
                        WelcomeGuideEssentialsCard()
                        WelcomeGuidePlanCard(hasPremiumAccess: appState.hasPremiumAccess)
                        WelcomeGuideStartPicker(selectedStart: $selectedStart)
                        welcomeBoundaryNote
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 18)
                }

                footer
            }
        }
    }

    private var topBar: some View {
        HStack {
            Image("LuminaMark")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            Text("Lumina")
                .luminaFont(size: 18, weight: .bold, design: .serif)
                .foregroundColor(.organicForeground)

            Spacer()

            Button(isReplay ? "Close" : "Skip") {
                onSkip()
            }
            .luminaFont(size: 13, weight: .semibold)
            .foregroundColor(.organicMutedFg)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick guide")
                .luminaFont(size: 13, weight: .semibold)
                .foregroundColor(.organicPrimary)

            Text("Use Lumina in one small step.")
                .luminaFont(size: 38, weight: .bold, design: .serif)
                .foregroundColor(.organicForeground)
                .lineLimit(3)
                .minimumScaleFactor(0.78)

            Text("Write, talk, or reset. Pick what helps now; ignore the rest.")
                .luminaFont(size: 17, weight: .regular)
                .lineSpacing(5)
                .foregroundColor(.organicMutedFg)
        }
        .padding(.top, 10)
    }

    private var welcomeBoundaryNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock")
                .luminaFont(size: 13, weight: .semibold)
                .foregroundColor(.organicPrimary)
                .frame(width: 24, height: 24)

            Text("Reminders and health context are optional. You can review them later in Profile.")
                .luminaFont(size: 13, weight: .medium)
                .foregroundColor(.organicMutedFg)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.organicCard.opacity(0.68), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.36), lineWidth: 1)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                startSelectedPath()
            } label: {
                HStack(spacing: 10) {
                    Text(selectedStart.buttonTitle)
                    Image(systemName: selectedStart.buttonIcon)
                        .luminaFont(size: 14, weight: .bold)
                }
                .luminaFont(size: 16, weight: .bold)
                .foregroundColor(.organicPrimaryFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.organicPrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button("Start at Home") {
                appState.selectedTab = LuminaRootTab.home.rawValue
                onFinish()
            }
            .luminaFont(size: 13, weight: .semibold)
            .foregroundColor(.organicMutedFg)
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 24)
    }

    private func startSelectedPath() {
        switch selectedStart {
        case .reflect:
            appState.selectedTab = LuminaRootTab.journal.rawValue
        case .talk:
            let therapist = allTherapists.first(where: { $0.id == "serena" }) ?? allTherapists[0]
            appState.requestTherapy(with: therapist)
        case .reset:
            appState.selectedTab = LuminaRootTab.sanctuary.rawValue
        case .grow:
            appState.selectedTab = LuminaRootTab.garden.rawValue
        }
        onFinish()
    }
}

private struct WelcomeGuideEssentialsCard: View {
    private let items = [
        WelcomeGuideEssential(icon: "scroll", title: "Journal", detail: "Put the day into words."),
        WelcomeGuideEssential(icon: "bubble.left.and.bubble.right", title: "Therapy", detail: "Talk through what feels heavy."),
        WelcomeGuideEssential(icon: "heart", title: "Sanctuary", detail: "Use a short reset first.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .luminaFont(size: 15, weight: .semibold)
                        .foregroundColor(.organicPrimary)
                        .frame(width: 34, height: 34)
                        .background(Color.organicPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .luminaFont(size: 16, weight: .semibold)
                            .foregroundColor(.organicForeground)
                        Text(item.detail)
                            .luminaFont(size: 13, weight: .regular)
                            .foregroundColor(.organicMutedFg)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .overlay(alignment: .bottom) {
                    if index < items.count - 1 {
                        Rectangle()
                            .fill(Color.organicBorder.opacity(0.48))
                            .frame(height: 1)
                            .padding(.leading, 60)
                    }
                }
            }
        }
        .background(Color.organicCard.opacity(0.58), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct WelcomeGuideEssential: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

private struct WelcomeGuidePlanCard: View {
    let hasPremiumAccess: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Free and Plus")
                    .luminaFont(size: 18, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
                Spacer(minLength: 8)
                Text(hasPremiumAccess ? "PLUS ACTIVE" : "FREE TODAY")
                    .luminaFont(size: 9, weight: .black)
                    .foregroundColor(hasPremiumAccess ? .organicPrimary : Color(hex: 0x7A5C16))
                    .kerning(1.0)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background((hasPremiumAccess ? Color.organicPrimary : Color(hex: 0xD8B45D)).opacity(0.12))
                    .clipShape(Capsule())
            }

            Text("Start free. Upgrade only when you want more continuity, voice time, and memory.")
                .luminaFont(size: 13, weight: .medium)
                .foregroundColor(.organicMutedFg)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                WelcomePlanCompareRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "AI Chat",
                    freeValue: "20 replies / day",
                    plusValue: "Expanded fair use"
                )
                WelcomePlanCompareRow(
                    icon: "mic.fill",
                    title: "Voice",
                    freeValue: "5 min / day preview",
                    plusValue: "300 min / month"
                )
                WelcomePlanCompareRow(
                    icon: "brain.head.profile",
                    title: "Guide memory",
                    freeValue: "Off",
                    plusValue: "Doctor memory + journal context"
                )
                WelcomePlanCompareRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Deep insights",
                    freeValue: "Basic reflection",
                    plusValue: "Daily patterns and summaries"
                )
            }
        }
        .padding(16)
        .background(Color.organicCard.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct WelcomePlanCompareRow: View {
    let icon: String
    let title: String
    let freeValue: String
    let plusValue: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .luminaFont(size: 12, weight: .bold)
                .foregroundColor(.organicPrimary)
                .frame(width: 28, height: 28)
                .background(Color.organicPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .luminaFont(size: 13, weight: .bold)
                    .foregroundColor(.organicForeground)

                HStack(spacing: 8) {
                    WelcomePlanValue(label: "Free", value: freeValue, isPremium: false)
                    WelcomePlanValue(label: "Plus", value: plusValue, isPremium: true)
                }
            }
        }
        .padding(11)
        .background(Color.organicMuted.opacity(0.38), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct WelcomePlanValue: View {
    let label: String
    let value: String
    let isPremium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .luminaFont(size: 8, weight: .black)
                .foregroundColor(isPremium ? .organicPrimary : .organicMutedFg)
                .textCase(.uppercase)
                .kerning(0.7)
            Text(value)
                .luminaFont(size: 10, weight: .bold)
                .foregroundColor(.organicForeground)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .frame(minHeight: 42)
        .background((isPremium ? Color.organicPrimary : Color.organicCard).opacity(isPremium ? 0.10 : 0.78), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct WelcomeGuideBackground: View {
    var body: some View {
        ZStack {
            Color.organicBackground.ignoresSafeArea()

            LinearGradient(
                colors: [Color.organicBackground, Color.organicBackdrop],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                ForEach(0..<7, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.organicBorder.opacity(0.16))
                        .frame(height: 1)
                }
            }
            .padding(.horizontal, 22)
            .offset(y: -34)
            .ignoresSafeArea()
        }
    }
}

private struct WelcomeGuidePageView: View {
    let page: WelcomeGuidePage

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 12) {
                Text(page.eyebrow)
                    .luminaFont(size: 13, weight: .semibold)
                    .foregroundColor(page.tint)

                Text(page.title)
                    .luminaFont(size: 38, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)

                Text(page.message)
                    .luminaFont(size: 17, weight: .regular)
                    .lineSpacing(5)
                    .foregroundColor(.organicMutedFg)
                    .multilineTextAlignment(.leading)
            }

            WelcomeGuideSceneView(page: page)

            VStack(spacing: 10) {
                ForEach(page.points) { point in
                    WelcomeGuidePointRow(point: point, tint: page.tint)
                }
            }

            Spacer(minLength: 6)
        }
    }
}

private struct WelcomeGuideSceneView: View {
    let page: WelcomeGuidePage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(page.sceneRows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 12) {
                    Text(row.time)
                        .luminaFont(size: 12, weight: .semibold)
                        .foregroundColor(page.tint)
                        .frame(width: 48, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .luminaFont(size: 15, weight: .semibold)
                            .foregroundColor(.organicForeground)
                        Text(row.detail)
                            .luminaFont(size: 12, weight: .regular)
                            .foregroundColor(.organicMutedFg)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(index == 0 ? Color.organicCard.opacity(0.76) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .bottom) {
                    if index < page.sceneRows.count - 1 {
                        Rectangle()
                            .fill(Color.organicBorder.opacity(0.55))
                            .frame(height: 1)
                            .padding(.leading, 74)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.organicCard.opacity(0.58), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct WelcomeGuidePointRow: View {
    let point: WelcomeGuidePoint
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: point.icon)
                .luminaFont(size: 12, weight: .semibold)
                .foregroundColor(tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(point.title)
                    .luminaFont(size: 14, weight: .semibold)
                    .foregroundColor(.organicForeground)
                Text(point.detail)
                    .luminaFont(size: 12, weight: .regular)
                    .foregroundColor(.organicMutedFg)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct WelcomeGuideStartPicker: View {
    @Binding var selectedStart: WelcomeStartOption

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Start with")
                    .luminaFont(size: 18, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
                Text("Choose one. You can switch tabs anytime.")
                    .luminaFont(size: 13, weight: .regular)
                    .foregroundColor(.organicMutedFg)
            }

            VStack(spacing: 10) {
                ForEach(WelcomeStartOption.allCases) { option in
                    WelcomeStartOptionRow(
                        option: option,
                        isSelected: selectedStart == option
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedStart = option
                        }
                    }
                }
            }
        }
    }
}

private struct WelcomeStartOptionRow: View {
    let option: WelcomeStartOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: option.icon)
                    .luminaFont(size: 18, weight: .semibold)
                    .foregroundColor(isSelected ? .white : option.tint)
                    .frame(width: 42, height: 42)
                    .background(isSelected ? option.tint : option.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .luminaFont(size: 16, weight: .semibold)
                        .foregroundColor(.organicForeground)
                    Text(option.detail)
                        .luminaFont(size: 12, weight: .regular)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .luminaFont(size: 18, weight: .semibold)
                    .foregroundColor(isSelected ? option.tint : Color.organicBorder)
            }
            .padding(12)
            .background(Color.organicCard.opacity(isSelected ? 0.95 : 0.64), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? option.tint.opacity(0.42) : Color.organicBorder.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct WelcomeGuidePage: Identifiable {
    let id: String
    let eyebrow: String
    let title: String
    let message: String
    let tint: Color
    let sceneRows: [WelcomeGuideSceneRow]
    let points: [WelcomeGuidePoint]

    static let defaultPages: [WelcomeGuidePage] = [
        WelcomeGuidePage(
            id: "welcome",
            eyebrow: "Welcome",
            title: "A quiet place to land",
            message: "Write a line, talk something through, or take one minute to settle. Nothing here has to become a streak.",
            tint: .organicPrimary,
            sceneRows: [
                WelcomeGuideSceneRow(time: "Now", title: "One sentence is enough", detail: "Capture the part you do not want to lose."),
                WelcomeGuideSceneRow(time: "Then", title: "Choose company or quiet", detail: "Talk with a guide, or open a short reset."),
                WelcomeGuideSceneRow(time: "Later", title: "Keep the small plan", detail: "Garden holds tiny actions without pressure.")
            ],
            points: [
                WelcomeGuidePoint(icon: "minus.circle", title: "Less to manage", detail: "No daily score is waiting for you."),
                WelcomeGuidePoint(icon: "mic", title: "Typing is optional", detail: "Use voice when writing feels like too much."),
                WelcomeGuidePoint(icon: "hand.raised", title: "You decide", detail: "Suggestions can be ignored or changed.")
            ]
        ),
        WelcomeGuidePage(
            id: "paths",
            eyebrow: "Guide",
            title: "Know where to go",
            message: "The tabs are deliberately simple. Each one has a job, so you do not have to search while you are already tired.",
            tint: Color(hex: 0xC18C5D),
            sceneRows: [
                WelcomeGuideSceneRow(time: "Journal", title: "Name the day", detail: "A place for rough notes and reflections."),
                WelcomeGuideSceneRow(time: "Therapy", title: "Talk with a guide", detail: "Pick a tone: warm, structured, mindful, or direct."),
                WelcomeGuideSceneRow(time: "Sanctuary", title: "Get steady first", detail: "Short resets when the next step is too big.")
            ],
            points: [
                WelcomeGuidePoint(icon: "house", title: "Home", detail: "Shows only the most useful next step."),
                WelcomeGuidePoint(icon: "leaf", title: "Garden", detail: "Turns tiny plans into something visible."),
                WelcomeGuidePoint(icon: "person", title: "Profile", detail: "Permissions and data stay easy to review.")
            ]
        ),
        WelcomeGuidePage(
            id: "safety",
            eyebrow: "Boundaries",
            title: "Keep it on your terms",
            message: "Reminders, health context, and suggestions are optional. Lumina should feel like support, not another thing to keep up with.",
            tint: Color(hex: 0x0F766E),
            sceneRows: [
                WelcomeGuideSceneRow(time: "Quiet", title: "Reminders can wait", detail: "Daily caps and quiet hours keep nudges limited."),
                WelcomeGuideSceneRow(time: "Private", title: "Permissions are separate", detail: "Health context is explained before you connect it."),
                WelcomeGuideSceneRow(time: "Safety", title: "Know when to leave the app", detail: "Sanctuary keeps crisis resources close.")
            ],
            points: [
                WelcomeGuidePoint(icon: "bell.slash", title: "Quiet hours", detail: "You can keep the app silent."),
                WelcomeGuidePoint(icon: "lock", title: "Local control", detail: "Review data settings from Profile."),
                WelcomeGuidePoint(icon: "cross.case", title: "Outside help", detail: "Use emergency resources when risk is immediate.")
            ]
        )
    ]
}

private struct WelcomeGuideSceneRow: Identifiable {
    let id = UUID()
    let time: String
    let title: String
    let detail: String
}

private struct WelcomeGuidePoint: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

private enum WelcomeStartOption: String, CaseIterable, Identifiable {
    case reflect
    case talk
    case reset
    case grow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reflect: return "Write a line"
        case .talk: return "Talk it through"
        case .reset: return "Settle first"
        case .grow: return "Keep a small plan"
        }
    }

    var detail: String {
        switch self {
        case .reflect: return "Open Journal and put the day somewhere."
        case .talk: return "Start with Serena when you want warmth."
        case .reset: return "Open Sanctuary for a short reset."
        case .grow: return "Open Garden and save one tiny action."
        }
    }

    var icon: String {
        switch self {
        case .reflect: return "scroll"
        case .talk: return "bubble.left.and.bubble.right"
        case .reset: return "wind"
        case .grow: return "leaf"
        }
    }

    var buttonTitle: String {
        switch self {
        case .reflect: return "Open Journal"
        case .talk: return "Start Therapy"
        case .reset: return "Open Sanctuary"
        case .grow: return "Open Garden"
        }
    }

    var buttonIcon: String {
        switch self {
        case .reflect: return "square.and.pencil"
        case .talk: return "bubble.left"
        case .reset: return "heart"
        case .grow: return "leaf"
        }
    }

    var tint: Color {
        switch self {
        case .reflect: return .organicPrimary
        case .talk: return Color(hex: 0xC18C5D)
        case .reset: return Color(hex: 0x4A90E2)
        case .grow: return Color(hex: 0x0F766E)
        }
    }
}

// MARK: - Root Tab View (native TabView)
enum LuminaRootTab: Int, CaseIterable, Identifiable {
    case home = 0
    case journal = 1
    case therapy = 2
    case garden = 3
    case sanctuary = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .journal: return "Journal"
        case .therapy: return "Therapy"
        case .garden: return "Garden"
        case .sanctuary: return "Sanctuary"
        }
    }

    var iconAsset: String {
        switch self {
        case .home: return "LuminaTabHome"
        case .journal: return "LuminaTabJournal"
        case .therapy: return "LuminaTabTherapy"
        case .garden: return "LuminaTabGarden"
        case .sanctuary: return "LuminaTabSanctuary"
        }
    }
}

struct RootTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var loadedTabs: Set<Int> = [LuminaRootTab.home.rawValue]
    @State private var hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    init() {
        Self.configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            tabContent(.home) {
                DashboardView()
            }
                .tabItem { Label(LuminaRootTab.home.title, image: LuminaRootTab.home.iconAsset) }
                .tag(LuminaRootTab.home.rawValue)
                .badge(appState.activeFollowUp == nil ? 0 : 1)

            tabContent(.journal) {
                JournalRootView()
            }
                .tabItem { Label(LuminaRootTab.journal.title, image: LuminaRootTab.journal.iconAsset) }
                .tag(LuminaRootTab.journal.rawValue)

            tabContent(.therapy) {
                FullChatView()
            }
                .tabItem { Label(LuminaRootTab.therapy.title, image: LuminaRootTab.therapy.iconAsset) }
                .tag(LuminaRootTab.therapy.rawValue)

            tabContent(.garden) {
                GardenStandaloneView()
            }
                .tabItem { Label(LuminaRootTab.garden.title, image: LuminaRootTab.garden.iconAsset) }
                .tag(LuminaRootTab.garden.rawValue)

            tabContent(.sanctuary) {
                SanctuaryView()
            }
                .tabItem { Label(LuminaRootTab.sanctuary.title, image: LuminaRootTab.sanctuary.iconAsset) }
                .tag(LuminaRootTab.sanctuary.rawValue)
        }
        .tint(Color.organicPrimary)
        .onAppear {
            loadedTabs.insert(appState.selectedTab)
            hapticGenerator.prepare()
        }
        .onChange(of: appState.selectedTab) { selectedTab in
            loadTabAfterNavigationSettles(selectedTab)
            guard appState.hapticFeedbackEnabled else { return }
            hapticGenerator.impactOccurred()
            hapticGenerator.prepare()
        }
    }

    @ViewBuilder
    private func tabContent<Content: View>(_ tab: LuminaRootTab, @ViewBuilder content: () -> Content) -> some View {
        if loadedTabs.contains(tab.rawValue) {
            content()
        } else {
            LuminaDeferredTabView(tab: tab)
        }
    }

    private func loadTabAfterNavigationSettles(_ tab: Int) {
        guard !loadedTabs.contains(tab) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            loadedTabs.insert(tab)
        }
    }

    private static func configureTabBarAppearance() {
        let selected = UIColor.luminaPrimary
        let normal = UIColor.luminaMutedForeground
        let background = UIColor.luminaTabBackground
        let hairline = UIColor.luminaBorder.withAlphaComponent(0.72)

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.shadowColor = hairline

        let itemAppearances = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ]

        itemAppearances.forEach { item in
            item.normal.iconColor = normal
            item.normal.titleTextAttributes = [
                .foregroundColor: normal,
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
            ]
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [
                .foregroundColor: selected,
                .font: UIFont.systemFont(ofSize: 10, weight: .bold)
            ]
            item.normal.badgeBackgroundColor = selected.withAlphaComponent(0.9)
            item.selected.badgeBackgroundColor = selected
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

private struct LuminaDeferredTabView: View {
    let tab: LuminaRootTab

    var body: some View {
        ZStack {
            Color.organicBackground.ignoresSafeArea()
            VStack(spacing: 10) {
                Image(tab.iconAsset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .foregroundColor(.organicPrimary.opacity(0.78))
                Text(tab.title)
                    .luminaFont(size: 13, weight: .bold)
                    .foregroundColor(.organicMutedFg)
            }
            .opacity(0.72)
        }
    }
}

final class LuminaAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        UNUserNotificationCenter.current().delegate = NotificationNavigationRouter.shared
        return true
    }
}

final class NotificationNavigationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationNavigationRouter()

    @Published private(set) var pendingRequest: NotificationNavigationRequest?

    private override init() {
        super.init()
    }

    func clearPendingRequest(id: String) {
        guard pendingRequest?.id == id else { return }
        pendingRequest = nil
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = Self.navigationRequest(from: response.notification.request.content.userInfo)
        DispatchQueue.main.async {
            self.pendingRequest = request
            completionHandler()
        }
    }

    private static func navigationRequest(from userInfo: [AnyHashable: Any]) -> NotificationNavigationRequest {
        let notificationType = userInfo["notificationType"] as? String ?? "unknown"
        let decisionID = userInfo["decisionID"] as? String
        let destinationTab = intValue(userInfo["destinationTab"])

        return NotificationNavigationRequest(
            notificationType: notificationType,
            decisionID: decisionID,
            destinationTab: destinationTab
        )
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }
}
