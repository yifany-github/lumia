import SwiftUI
import LocalAuthentication
import AuthenticationServices
import CryptoKit
import Security

private enum ProfileAuthMode: String, CaseIterable, Identifiable {
    case signIn
    case register

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signIn: return "Sign In"
        case .register: return "Register"
        }
    }
}

private enum ProfileCredentialMethod: String, CaseIterable, Identifiable {
    case email
    case phone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .email: return "Email"
        case .phone: return "Phone"
        }
    }
}

private enum AppleSignInNonce {
    private static let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    static func random(length: Int = 32) throws -> String {
        precondition(length > 0)
        var result = ""
        result.reserveCapacity(length)

        while result.count < length {
            var randomByte: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &randomByte)
            guard status == errSecSuccess else {
                throw NSError(
                    domain: "LuminaAppleSignIn",
                    code: Int(status),
                    userInfo: [NSLocalizedDescriptionKey: "Apple sign-in could not start securely. Try again."]
                )
            }
            if randomByte < charset.count {
                result.append(charset[Int(randomByte)])
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Activity Share Sheet (UIKit bridge)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

struct ProfileAvatarImage: View {
    let avatarID: ProfileAvatarID
    let fallbackText: String
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.organicCard, Color.organicPrimary.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(avatarID.assetName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .padding(size * 0.12)

            if fallbackText.isEmpty == false && avatarID.assetName.isEmpty {
                Text(fallbackText)
                    .luminaFont(size: size * 0.34, weight: .bold, design: .rounded)
                    .foregroundColor(.organicPrimary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.72), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismissProfile
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(LuminaAppearanceMode.storageKey) private var appearanceModeRawValue = LuminaAppearanceMode.system.rawValue
    @AppStorage(WelcomeGuideStorage.completionKey) private var hasCompletedWelcomeGuide = false

    @State private var showNameEdit     = false
    @State private var showBioEdit      = false
    @State private var showIdentityEdit = false
    @State private var showAIConnection = false
    @State private var showGoalSheet    = false
    @State private var showShareSheet   = false
    @State private var showClearConfirm = false
    @State private var showClearChatConfirm = false
    @State private var showClearJournalConfirm = false
    @State private var showBiometricUnavailable = false
    @State private var showAccountSheet = false
    @State private var showSignOutConfirm = false
    @State private var showMembershipSheet = false
    @State private var biometricUnavailableMessage = "Device authentication is not available."
    @State private var editedName  = ""
    @State private var editedBio   = ""
    @State private var editedAvatarID: ProfileAvatarID = .cat
    @State private var editedGender: ProfileGender = .notSpecified
    @State private var aiConnectionErrorMessage: String?
    @State private var aiConnectionStatusMessage: String?
    @State private var isTestingAIConnection = false
    @State private var authMode: ProfileAuthMode = .signIn
    @State private var authMethod: ProfileCredentialMethod = .email
    @State private var authName = ""
    @State private var authEmail = ""
    @State private var authPhone = ""
    @State private var authPassword = ""
    @State private var authConfirmPassword = ""
    @State private var authErrorMessage: String?
    @State private var isAuthSubmitting = false
    @State private var currentAppleNonce: String?
    @State private var selectedMembershipPlan = "yearly"
    @State private var membershipActionError: String?
    @State private var appeared    = false

    var totalSessions: Int   { appState.chatSessions.count }
    var totalMessages: Int   { appState.chatSessions.values.reduce(0) { $0 + $1.messageCount } }
    var completedHabits: Int { appState.habits.filter { $0.completedAt != nil }.count }

    var journalStreak: Int {
        let sorted = appState.entries.sorted { $0.timestamp > $1.timestamp }
        var streak = 0; var prev = Date().timeIntervalSince1970
        for e in sorted {
            if prev - e.timestamp < 86400 * 2 { streak += 1; prev = e.timestamp } else { break }
        }
        return min(streak, 99)
    }

    var initials: String {
        appState.userName.split(separator: " ").compactMap { $0.first }
            .map { String($0) }.prefix(2).joined().uppercased()
    }

    var joinedString: String {
        let stored = UserDefaults.standard.double(forKey: "lumina_join_date")
        let date   = stored > 0 ? Date(timeIntervalSince1970: stored) : appState.joinDate
        let f = DateFormatter(); f.dateStyle = .long; return f.string(from: date)
    }

    var latestMetrics: EmotionalMetrics? {
        appState.chatSessions.values.sorted { $0.lastUpdated > $1.lastUpdated }.first?.metrics
    }

    var biometricLockDetail: String {
        appState.requireBiometrics ? "On - unlock with Face ID, Touch ID, or passcode" : "Off - protect private reflections"
    }

    var biometricLockBinding: Binding<Bool> {
        Binding(
            get: { appState.requireBiometrics },
            set: { enabled in
                if enabled {
                    enableBiometricLockIfAvailable()
                } else {
                    appState.requireBiometrics = false
                }
            }
        )
    }

    var exportText: String {
        let formatter = ISO8601DateFormatter()
        let exportedAt = formatter.string(from: Date())
        let entries = appState.entries.sorted { $0.timestamp > $1.timestamp }.map { entry in
            """
            [Journal] \(entry.date) · \(entry.title)
            Mood: \(entry.mood.label)
            Tags: \(entry.tags.joined(separator: ", "))
            \(entry.content)
            Reflection: \(entry.reflection ?? "None")
            Action: \(entry.actionItem ?? "None")
            """
        }.joined(separator: "\n\n---\n\n")

        let sessions = appState.chatSessions.values.sorted { $0.lastUpdated > $1.lastUpdated }.map { session in
            let therapistName = allTherapists.first { $0.id == session.therapistID || $0.id == session.id }?.name ?? session.therapistID
            return """
            [Therapy] \(therapistName)
            Messages: \(session.messageCount)
            Last updated: \(formatter.string(from: Date(timeIntervalSince1970: session.lastUpdated)))
            Last message: \(session.lastMessagePreview.isEmpty ? "None" : session.lastMessagePreview)
            """
        }.joined(separator: "\n\n---\n\n")

        let habits = appState.habits.map { habit in
            "[Garden] \(habit.title) · growth \(habit.growth)% · \(habit.completedAt == nil ? "open" : "completed")"
        }.joined(separator: "\n")

        return """
        Lumia Export
        Exported: \(exportedAt)
        User: \(appState.userName)
        Bio: \(appState.userBio.isEmpty ? "None" : appState.userBio)
        Avatar: \(appState.profileAvatarID.rawValue)
        Gender: \(appState.profileGender.rawValue)

        Counts
        Journals: \(appState.entries.count)
        Therapy sessions: \(totalSessions)
        Therapy messages: \(totalMessages)
        Habits: \(appState.habits.count)
        Check-ins: \(appState.checkIns.count)
        Journals
        \(entries.isEmpty ? "No journal entries." : entries)

        Therapy Sessions
        \(sessions.isEmpty ? "No therapy sessions." : sessions)

        Garden
        \(habits.isEmpty ? "No garden habits." : habits)
        """
    }

    // ── Body ─────────────────────────────────────────────────────────
    var body: some View {
        ZStack(alignment: .top) {
            Color.organicBackground.ignoresSafeArea()

            // Gradient cap pinned to top (fixes status bar color)
            LinearGradient(
                colors: [Color.organicPrimary.opacity(0.28), Color.organicPrimary.opacity(0.10), Color.organicBackground],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
            .frame(height: 320)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    quietOverview
                    settingsSection
                    dangerZone
                    appFooter
                    Spacer(minLength: 80)
                }
            }
        }
        .onAppear {
            LuminaAppearanceMode.applyInterfaceStyleOverride(appearanceModeRawValue)
            if UserDefaults.standard.double(forKey: "lumina_join_date") == 0 {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lumina_join_date")
            }
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            Task { await appState.refreshNotificationPermissionState() }
        }
        .onChange(of: appearanceModeRawValue) { rawValue in
            withAnimation(.easeInOut(duration: 0.18)) {
                LuminaAppearanceMode.applyInterfaceStyleOverride(rawValue)
            }
        }
        .preferredColorScheme(LuminaAppearanceMode.normalized(appearanceModeRawValue).colorScheme)
        .sheet(isPresented: $showNameEdit)  { nameSheet }
        .sheet(isPresented: $showBioEdit)   { bioSheet }
        .sheet(isPresented: $showIdentityEdit) { identitySheet }
        .sheet(isPresented: $showAIConnection) { aiConnectionSheet }
        .sheet(isPresented: $showGoalSheet) { goalsSheet }
        .sheet(isPresented: $showAccountSheet) { accountSheet }
        .sheet(isPresented: $showMembershipSheet) { membershipSheet }
        .sheet(isPresented: $showShareSheet) { ShareSheet(items: [exportText]) }
        .alert("Reset All Data?", isPresented: $showClearConfirm) {
            Button("Delete Everything", role: .destructive) {
                appState.clearAllChatSessions()
                appState.entries.removeAll()
                appState.deleteLocalHealthData()
                hasCompletedWelcomeGuide = false
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This permanently removes journal entries, chat history, local preferences, and shows the guide again next launch.") }
        .alert("Clear Chat History?", isPresented: $showClearChatConfirm) {
            Button("Clear Chats", role: .destructive) {
                appState.clearAllChatSessions()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes all saved therapy conversations. Journal entries and garden progress stay untouched.") }
        .alert("Clear Journal Entries?", isPresented: $showClearJournalConfirm) {
            Button("Clear Journal", role: .destructive) {
                appState.entries.removeAll()
                appState.refreshJITAI()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes all saved reflections. Therapy sessions and garden progress stay untouched.") }
        .alert("Face ID / Touch ID Unavailable", isPresented: $showBiometricUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(biometricUnavailableMessage)
        }
        .alert("Sign Out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                appState.signOutAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Lumia will keep local journals, chats, and garden progress on this device.")
        }
    }

    // ── Hero ─────────────────────────────────────────────────────────
    var heroSection: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Color.clear.frame(height: 120)
                Button { editedName = appState.userName; showNameEdit = true } label: {
                    Label("Edit", systemImage: "pencil")
                        .luminaFont(size: 12, weight: .semibold)
                        .foregroundColor(.organicPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.trailing, 20).padding(.bottom, 10)
            }

            Button {
                prepareIdentitySheet()
                showIdentityEdit = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatarImage(avatarID: appState.profileAvatarID, fallbackText: initials, size: 96)
                        .shadow(color: Color.organicPrimary.opacity(colorScheme == .dark ? 0.16 : 0.22), radius: 18, x: 0, y: 9)

                    Image(systemName: "pencil")
                        .luminaFont(size: 11, weight: .black)
                        .foregroundColor(.organicPrimary)
                        .frame(width: 28, height: 28)
                        .background(Color.organicCard, in: Circle())
                        .overlay(Circle().strokeBorder(Color.organicBorder.opacity(0.72), lineWidth: 1))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change profile avatar")
            .offset(y: -12).padding(.bottom, -12)

            VStack(spacing: 6) {
                Text(appState.userName)
                    .luminaFont(size: 26, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)

                if !appState.userBio.isEmpty {
                    Text(appState.userBio)
                        .luminaFont(size: 13).foregroundColor(.organicMutedFg)
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                } else {
                    Button { editedBio = appState.userBio; showBioEdit = true } label: {
                        Text("+ Add a bio").luminaFont(size: 12, weight: .medium)
                            .foregroundColor(.organicPrimary.opacity(0.7))
                    }
                }

                Label(joinedString, systemImage: "calendar")
                    .luminaFont(size: 11).foregroundColor(.organicMutedFg).padding(.top, 2)

                if appState.profileGender != .notSpecified {
                    Text(appState.profileGender.profileDetail)
                        .luminaFont(size: 10, weight: .bold)
                        .foregroundColor(.organicMutedFg)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Color.organicMuted.opacity(0.62), in: Capsule())
                }

                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Circle().fill(.green).frame(width: 7, height: 7)
                        Text("Active").luminaFont(size: 11, weight: .bold).foregroundColor(.green)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.green.opacity(0.09)).clipShape(Capsule())

                    if journalStreak > 0 {
                        HStack(spacing: 5) {
                            Text("🔥").luminaFont(size: 11)
                            Text("\(journalStreak)d streak")
                                .luminaFont(size: 11, weight: .bold)
                                .foregroundColor(Color(hex: 0xD97706))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color(hex: 0xD97706).opacity(0.09)).clipShape(Capsule())
                    }
                }.padding(.top, 4)
            }
            .padding(.bottom, 28)
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: appeared)
    }

    // ── Stats Grid ────────────────────────────────────────────────────
    var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ProfileStat(value: "\(appState.entries.count)",      label: "Entries",  icon: "scroll.fill",             color: .organicPrimary)
            ProfileStat(value: "\(totalSessions)",              label: "Sessions", icon: "bubble.left.fill",        color: Color(hex: 0xC18C5D))
            ProfileStat(value: "\(appState.averageSentiment)%", label: "Mood",     icon: "heart.fill",              color: Color(hex: 0xBE185D))
            ProfileStat(value: "\(totalMessages)",              label: "Messages", icon: "text.bubble",             color: Color(hex: 0x4A90E2))
            ProfileStat(value: "\(completedHabits)",            label: "Habits",   icon: "leaf.fill",               color: Color(hex: 0x4E9C5C))
            ProfileStat(value: "\(appState.waterDrops)💧",     label: "Garden",   icon: "drop.fill",               color: Color(hex: 0x5AC8FA))
        }
        .padding(.horizontal, 16).padding(.bottom, 20)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)
    }

    var quietOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Overview", icon: "leaf.fill")
            HStack(spacing: 10) {
                ProfileStat(value: "\(appState.entries.count)", label: "Entries", icon: "scroll.fill", color: .organicPrimary)
                ProfileStat(value: "\(totalSessions)", label: "Chats", icon: "bubble.left.fill", color: Color(hex: 0xC18C5D))
                ProfileStat(value: "\(completedHabits)", label: "Garden", icon: "leaf.fill", color: Color(hex: 0x4E9C5C))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)
    }

    // ── Recent Sessions ───────────────────────────────────────────────
    var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Recent Sessions", icon: "bubble.left.and.bubble.right.fill")
            VStack(spacing: 10) {
                ForEach(
                    allTherapists.compactMap { appState.session(for: $0) }
                        .sorted { $0.lastUpdated > $1.lastUpdated }
                ) { session in
                    if let therapist = allTherapists.first(where: { $0.id == session.therapistID || $0.id == session.id }) {
                        SessionHistoryRow(session: session, therapist: therapist) {
                            withAnimation { appState.requestTherapy(with: therapist) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 20)
    }

    // ── Achievements ──────────────────────────────────────────────────
    var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Achievements", icon: "star.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    AchievementBadge(emoji: "📖", title: "First Entry",  unlocked: appState.entries.count >= 1)
                    AchievementBadge(emoji: "💬", title: "First Chat",   unlocked: totalSessions >= 1)
                    AchievementBadge(emoji: "🌱", title: "Green Thumb",  unlocked: completedHabits >= 1)
                    AchievementBadge(emoji: "📚", title: "Journaler",    unlocked: appState.entries.count >= 5)
                    AchievementBadge(emoji: "🔥", title: "Week Streak",  unlocked: journalStreak >= 7)
                    AchievementBadge(emoji: "🌳", title: "Full Garden",  unlocked: appState.habits.allSatisfy { $0.plantType == .tree })
                    AchievementBadge(emoji: "💡", title: "Deep Thinker", unlocked: totalMessages >= 50)
                    AchievementBadge(emoji: "🏆", title: "Master",       unlocked: totalSessions >= 8)
                }
                .padding(.horizontal, 16).padding(.vertical, 4)
            }.padding(.horizontal, -16)
        }
        .padding(.horizontal, 16).padding(.bottom, 20)
    }

    // ── Wellness Pulse ────────────────────────────────────────────────
    func wellnessPulse(_ m: EmotionalMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Mental Health Pulse", icon: "waveform.path.ecg")
            WellnessSnapshot(metrics: m)
        }
        .padding(.horizontal, 16).padding(.bottom, 20)
    }

    // ── Goals ─────────────────────────────────────────────────────────
    var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Wellness Goals", icon: "target")
                Spacer()
                Button("Edit") { showGoalSheet = true }
                    .luminaFont(size: 12, weight: .bold).foregroundColor(.organicPrimary).padding(.bottom, 8)
            }
            VStack(spacing: 10) {
                GoalProgressRow(
                    icon: "scroll.fill", iconColor: .organicPrimary,
                    title: "Weekly Journaling",
                    subtitle: "\(min(appState.entries.count, appState.journalGoalPerWeek)) / \(appState.journalGoalPerWeek) entries",
                    progress: min(1, Double(appState.entries.count) / Double(max(1, appState.journalGoalPerWeek))),
                    color: .organicPrimary)
                GoalProgressRow(
                    icon: "wind", iconColor: Color(hex: 0x4A90E2),
                    title: "Daily Meditation", subtitle: "\(appState.meditationGoalMinutes) min goal",
                    progress: 0.4, color: Color(hex: 0x4A90E2))
                GoalProgressRow(
                    icon: "leaf.fill", iconColor: Color(hex: 0x4E9C5C),
                    title: "Habit Completion",
                    subtitle: "\(completedHabits) / \(appState.habits.count) today",
                    progress: appState.habits.isEmpty ? 0 : Double(completedHabits) / Double(appState.habits.count),
                    color: Color(hex: 0x4E9C5C))
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 20)
    }

    // ── Evaluation ───────────────────────────────────────────────────
    var evaluationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Evaluation", icon: "checklist.checked")
            EvaluationPanel(
                promptPolicy: appState.activePromptPolicyLabel,
                interventionCount: appState.interventionLogs.count,
                checkInCount: appState.checkIns.count,
                crisisRouteCount: appState.crisisRouteCount,
                userControlCount: appState.userControlActionCount,
                falsePositiveCount: appState.falsePositiveSafetyCount,
                canFlagSafety: appState.canFlagLatestSafetyRoute,
                onFlagFalsePositive: appState.flagLatestSafetyRouteFalsePositive
            )
        }
        .padding(.horizontal, 16).padding(.bottom, 20)
    }

    // ── Settings ──────────────────────────────────────────────────────
    var settingsSection: some View {
        ProfileSettingsSectionView(
            appState: appState,
            appearanceModeRawValue: $appearanceModeRawValue,
            totalSessions: totalSessions,
            onAccount: {
                prepareAccountSheet()
                showAccountSheet = true
            },
            onSignOut: { showSignOutConfirm = true },
            onEditName: {
                editedName = appState.userName
                showNameEdit = true
            },
            onEditBio: {
                editedBio = appState.userBio
                showBioEdit = true
            },
            onEditIdentity: {
                prepareIdentitySheet()
                showIdentityEdit = true
            },
            onAIConnection: {
                aiConnectionErrorMessage = nil
                aiConnectionStatusMessage = nil
                showAIConnection = true
            },
            onQuickGuide: {
                dismissProfile()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                    NotificationCenter.default.post(name: .luminaShowWelcomeGuide, object: nil)
                }
            },
            onRefreshNotifications: {
                Task { await appState.refreshNotificationPermissionState() }
            },
            onOpenSystemSettings: openSystemSettings,
            onEnableBiometricLock: enableBiometricLockIfAvailable,
            onMembership: { showMembershipSheet = true },
            onExport: { showShareSheet = true }
        )
    }

    var accountStatusRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accountProviderTint(appState.currentAccount?.provider ?? .email).opacity(0.16))
                        .frame(width: 42, height: 42)
                    if let account = appState.currentAccount {
                        Text(account.initials)
                            .luminaFont(size: 15, weight: .black, design: .rounded)
                            .foregroundColor(accountProviderTint(account.provider))
                    } else {
                        Image(systemName: "person.badge.key.fill")
                            .luminaFont(size: 17, weight: .bold)
                            .foregroundColor(.organicPrimary)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.currentAccount?.displayName ?? "Sign in to Lumia")
                        .luminaFont(size: 15, weight: .bold)
                        .foregroundColor(.organicForeground)
                    Text(accountStatusDetail)
                        .luminaFont(size: 11, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 0)

                Button(appState.isSignedIn ? "Manage" : "Sign In") {
                    prepareAccountSheet()
                    showAccountSheet = true
                }
                .luminaFont(size: 12, weight: .bold)
                .foregroundColor(.organicPrimary)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Color.organicPrimary.opacity(0.10))
                .clipShape(Capsule())
            }

            if appState.isSignedIn {
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundColor(Color(hex: 0xBE185D))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.organicCard)
    }

    var accountStatusDetail: String {
        guard let account = appState.currentAccount else {
            return "Use Email, phone, Apple ID, or Google."
        }
        return "\(account.provider.title) · \(account.primaryContact)"
    }

    var notificationStatusRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Status")
                    .luminaFont(size: 13, weight: .semibold)
                    .foregroundColor(.organicForeground)
                Spacer()
                Text(appState.notificationPermissionLabel)
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(appState.notificationPermissionState == .denied ? Color(hex: 0xBE185D) : .organicPrimary)
            }
            if let error = appState.notificationError {
                Text(error)
                    .luminaFont(size: 11, weight: .medium)
                    .foregroundColor(Color(hex: 0xBE185D))
            } else if appState.notificationPermissionState == .denied {
                Text("Enable notifications in iOS Settings > Notifications > Lumia.")
                    .luminaFont(size: 11, weight: .medium)
                    .foregroundColor(.organicMutedFg)
            } else if appState.dailyReminderEnabled && appState.jitaiNotificationsEnabled {
                Text("Reminders stay local and respect quiet hours.")
                    .luminaFont(size: 11, weight: .medium)
                    .foregroundColor(.organicMutedFg)
            } else if appState.jitaiNotificationsEnabled {
                Text("Gentle suggestions stay within quiet hours and daily limits.")
                    .luminaFont(size: 11, weight: .medium)
                    .foregroundColor(.organicMutedFg)
            } else if appState.dailyReminderEnabled {
                Text("One local reminder each day. Gentle suggestions are off.")
                    .luminaFont(size: 11, weight: .medium)
                    .foregroundColor(.organicMutedFg)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.organicCard)
    }

    // ── Danger Zone ───────────────────────────────────────────────────
    var dangerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Data Management", icon: "exclamationmark.triangle.fill")
            VStack(spacing: 10) {
                dangerButton(icon: "bubble.left.and.bubble.right", color: .orange,
                             title: "Clear Chat History", subtitle: "Removes all saved conversations")
                { showClearChatConfirm = true }
                dangerButton(icon: "doc.text.fill", color: Color(hex: 0xBE185D),
                             title: "Clear Journal Entries", subtitle: "Removes reflections only")
                { showClearJournalConfirm = true }
                dangerButton(icon: "trash.fill", color: .red,
                             title: "Reset All Data", subtitle: "Deletes entries, chats, and local health context")
                { showClearConfirm = true }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 20)
    }

    // ── Footer ────────────────────────────────────────────────────────
    var appFooter: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg").luminaFont(size: 26).foregroundColor(.organicPrimary.opacity(0.35))
            Text("Lumia · v1.0.0").luminaFont(size: 12, weight: .semibold, design: .serif).foregroundColor(.organicMutedFg)
        }.padding(.vertical, 24)
    }

    // ── Helpers ───────────────────────────────────────────────────────
    func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).luminaFont(size: 12, weight: .semibold).foregroundColor(.organicPrimary)
            Text(title.uppercased()).luminaFont(size: 11, weight: .black).foregroundColor(.organicMutedFg).kerning(1.5)
        }.padding(.bottom, 6)
    }

    func groupLabel(_ title: String) -> some View {
        Text(title).luminaFont(size: 10, weight: .black).foregroundColor(.organicMutedFg).kerning(2)
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func divider() -> some View { Divider().padding(.horizontal, 16).padding(.vertical, 2) }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    func accountProviderTint(_ provider: LuminaAccountProvider) -> Color {
        switch provider {
        case .email: return .organicPrimary
        case .phone: return Color(hex: 0x0F766E)
        case .apple: return .organicForeground
        case .google: return Color(hex: 0x4A6FA5)
        }
    }

    func accountProviderIcon(_ provider: LuminaAccountProvider) -> String {
        switch provider {
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .apple: return "apple.logo"
        case .google: return "globe"
        }
    }

    func prepareAccountSheet() {
        authMode = .signIn
        authMethod = .email
        authName = appState.userName == "User" ? "" : appState.userName
        authEmail = appState.currentAccount?.email ?? ""
        authPhone = appState.currentAccount?.phone ?? ""
        authPassword = ""
        authConfirmPassword = ""
        authErrorMessage = nil
    }

    func prepareIdentitySheet() {
        editedAvatarID = appState.profileAvatarID
        editedGender = appState.profileGender
    }

    func enableBiometricLockIfAvailable() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            biometricUnavailableMessage = error?.localizedDescription ?? "Set a device passcode or enroll Face ID / Touch ID before enabling Privacy Lock."
            showBiometricUnavailable = true
            appState.requireBiometrics = false
            return
        }

        appState.requireBiometrics = true
    }

    func settingsRow(icon: String, bg: Color, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(bg).frame(width: 30, height: 30)
                    Image(systemName: icon).luminaFont(size: 13).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).luminaFont(size: 15).foregroundColor(.organicForeground)
                    Text(detail).luminaFont(size: 12).foregroundColor(.organicMutedFg).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").luminaFont(size: 12).foregroundColor(Color.organicBorder)
            }
            .padding(.horizontal, 16).padding(.vertical, 11).background(Color.organicCard).contentShape(Rectangle())
        }
    }

    func toggleRow(icon: String, bg: Color, title: String, detail: String? = nil, value: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(bg).frame(width: 30, height: 30)
                Image(systemName: icon).luminaFont(size: 13).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).luminaFont(size: 15).foregroundColor(.organicForeground)
                if let detail {
                    Text(detail)
                        .luminaFont(size: 11, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
            }
            Spacer()
            Toggle("", isOn: value).tint(.organicPrimary).labelsHidden()
        }.padding(.horizontal, 16).padding(.vertical, 10).background(Color.organicCard)
    }

    func preferencePickerRow(
        icon: String,
        bg: Color,
        title: String,
        detail: String,
        selection: Binding<Int>,
        values: [Int],
        valueLabel: @escaping (Int) -> String
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(bg).frame(width: 30, height: 30)
                Image(systemName: icon).luminaFont(size: 13).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).luminaFont(size: 15).foregroundColor(.organicForeground)
                Text(detail).luminaFont(size: 11, weight: .medium).foregroundColor(.organicMutedFg)
            }
            Spacer()
            Picker("", selection: selection) {
                ForEach(values, id: \.self) { value in
                    Text(valueLabel(value)).tag(value)
                }
            }
            .pickerStyle(.menu)
            .tint(.organicPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.organicCard)
    }

    func dangerButton(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.1)).frame(width: 36, height: 36)
                    Image(systemName: icon).luminaFont(size: 14).foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).luminaFont(size: 14, weight: .semibold).foregroundColor(color)
                    Text(subtitle).luminaFont(size: 11).foregroundColor(.organicMutedFg)
                }
                Spacer()
                Image(systemName: "chevron.right").luminaFont(size: 12).foregroundColor(.organicBorder)
            }
            .padding(14).background(Color.organicCard).cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
        }
    }

    struct ProfileSettingsSectionView: View {
        @ObservedObject var appState: AppState
        @Binding var appearanceModeRawValue: String

        let totalSessions: Int
        let onAccount: () -> Void
        let onSignOut: () -> Void
        let onEditName: () -> Void
        let onEditBio: () -> Void
        let onEditIdentity: () -> Void
        let onAIConnection: () -> Void
        let onQuickGuide: () -> Void
        let onRefreshNotifications: () -> Void
        let onOpenSystemSettings: () -> Void
        let onEnableBiometricLock: () -> Void
        let onMembership: () -> Void
        let onExport: () -> Void

        private var biometricLockBinding: Binding<Bool> {
            Binding(
                get: { appState.requireBiometrics },
                set: { enabled in
                    if enabled {
                        onEnableBiometricLock()
                    } else {
                        appState.requireBiometrics = false
                    }
                }
            )
        }

        private var accountStatusDetail: String {
            guard let account = appState.currentAccount else {
                return "Use email, phone, or Google."
            }
            return "\(account.provider.title) - \(account.primaryContact)"
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Settings", icon: "gearshape.fill")

                SettingsOverviewCard(
                    appearance: LuminaAppearanceMode.normalized(appearanceModeRawValue).title,
                    notifications: appState.notificationPermissionLabel,
                    privacyLockEnabled: appState.requireBiometrics
                )

                VStack(spacing: 1) {
                    groupLabel("ACCOUNT")
                    accountStatusRow
                    membershipStatusRow

                    divider
                    groupLabel("PROFILE")
                    settingsRow(icon: "person.crop.square.fill", bg: Color(hex: 0x5D7052), title: "Avatar", detail: appState.profileAvatarID.title, action: onEditIdentity)
                    settingsRow(icon: "person.text.rectangle.fill", bg: Color(hex: 0x0F766E), title: "Gender", detail: appState.profileGender.profileDetail, action: onEditIdentity)
                    settingsRow(icon: "person.fill", bg: .organicPrimary, title: "Display Name", detail: appState.userName, action: onEditName)
                    settingsRow(icon: "text.alignleft", bg: Color(hex: 0x6D28D9), title: "Bio", detail: appState.userBio.isEmpty ? "Not set" : appState.userBio, action: onEditBio)
                    settingsRow(icon: "sparkles", bg: Color(hex: 0x9A6A22), title: "AI Connection", detail: "Service status", action: onAIConnection)

                    divider
                    groupLabel("HELP")
                    settingsRow(icon: "questionmark.circle.fill", bg: Color(hex: 0x0F766E), title: "Guide", detail: "Replay the short start screen", action: onQuickGuide)
                }
                .background(Color.organicCard)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.organicBorder.opacity(0.4), lineWidth: 1))

                settingsDisclosure(
                    title: "Reminders",
                    subtitle: appState.notificationPermissionLabel,
                    icon: "bell.fill",
                    tint: Color(hex: 0x8F3A4A)
                ) {
                    toggleRow(
                        icon: "bell.fill",
                        bg: Color(hex: 0x8F3A4A),
                        title: "Daily Reminder",
                        detail: appState.dailyReminderEnabled ? String(format: "%02d:00", appState.dailyReminderHour) : "Off",
                        value: $appState.dailyReminderEnabled
                    )
                    toggleRow(
                        icon: "sparkles",
                        bg: Color(hex: 0x0F766E),
                        title: "Gentle Suggestions",
                        detail: appState.jitaiNotificationsEnabled ? "On - respects quiet hours" : "Off",
                        value: $appState.jitaiNotificationsEnabled
                    )
                    notificationStatusRow
                    settingsRow(icon: "arrow.clockwise", bg: Color(hex: 0x5D7052), title: "Refresh Status", detail: appState.notificationPermissionLabel, action: onRefreshNotifications)
                    settingsRow(icon: "gearshape.2.fill", bg: Color(hex: 0x6D28D9), title: "Open iOS Settings", detail: "Notifications, Face ID, app access", action: onOpenSystemSettings)

                    if appState.dailyReminderEnabled {
                        timePickerRow
                    }
                    if appState.jitaiNotificationsEnabled {
                        preferencePickerRow(
                            icon: "number",
                            bg: Color(hex: 0x7A5C16),
                            title: "Daily Cap",
                            detail: "\(appState.jitaiMaxDailyPrompts) per day",
                            selection: $appState.jitaiMaxDailyPrompts,
                            values: Array(1...5),
                            valueLabel: { "\($0)" }
                        )
                        preferencePickerRow(
                            icon: "moon.fill",
                            bg: Color(hex: 0x4A90E2),
                            title: "Quiet Starts",
                            detail: appState.jitaiQuietHoursLabel,
                            selection: $appState.jitaiQuietHoursStart,
                            values: Array(0..<24),
                            valueLabel: { String(format: "%02d:00", $0) }
                        )
                        preferencePickerRow(
                            icon: "sun.max.fill",
                            bg: Color(hex: 0xD97706),
                            title: "Quiet Ends",
                            detail: appState.jitaiQuietHoursLabel,
                            selection: $appState.jitaiQuietHoursEnd,
                            values: Array(0..<24),
                            valueLabel: { String(format: "%02d:00", $0) }
                        )
                    }
                }

                settingsDisclosure(
                    title: "Appearance",
                    subtitle: LuminaAppearanceMode.normalized(appearanceModeRawValue).detail,
                    icon: "paintpalette.fill",
                    tint: .organicPrimary
                ) {
                    LuminaAppearancePickerRow(selectionRawValue: $appearanceModeRawValue)
                    toggleRow(icon: "hand.tap.fill", bg: Color(hex: 0x4A6FA5), title: "Haptic Feedback", detail: "Subtle feedback on tab changes", value: $appState.hapticFeedbackEnabled)
                    toggleRow(
                        icon: "textformat.size",
                        bg: Color(hex: 0x0F766E),
                        title: "Larger Text",
                        detail: appState.useLargeText ? "On - larger app text" : "Off - standard app text",
                        value: $appState.useLargeText
                    )
                }

                settingsDisclosure(
                    title: "Privacy & Data",
                    subtitle: appState.requireBiometrics ? "Lock is on" : "Lock is off",
                    icon: "lock.fill",
                    tint: Color(hex: 0x5D7052)
                ) {
                    toggleRow(
                        icon: "faceid",
                        bg: Color(hex: 0x5D7052),
                        title: "Face ID / Touch ID",
                        detail: appState.requireBiometrics ? "On - unlock with Face ID, Touch ID, or passcode" : "Off - protect private reflections",
                        value: biometricLockBinding
                    )
                    toggleRow(
                        icon: "text.bubble.fill",
                        bg: Color(hex: 0x0F766E),
                        title: "Let Therapy Remember Journal Themes",
                        detail: appState.useJournalContextInTherapy ? "On - recent themes may help" : "Off - chats stay separate",
                        value: $appState.useJournalContextInTherapy
                    )
                    infoRow(
                        icon: "heart.text.square.fill",
                        bg: Color(hex: 0xBE185D),
                        title: "Health Context",
                        detail: "Coming soon - not enabled in v1.",
                        badge: "SOON"
                    )
                    settingsRow(
                        icon: "square.and.arrow.up.fill",
                        bg: Color(hex: 0x6D28D9),
                        title: "Export Data",
                        detail: "\(appState.entries.count) entries, \(totalSessions) sessions",
                        action: onExport
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }

        private var accountStatusRow: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(accountProviderTint(appState.currentAccount?.provider ?? .email).opacity(0.16))
                            .frame(width: 42, height: 42)
                        if let account = appState.currentAccount {
                            Text(account.initials)
                                .luminaFont(size: 15, weight: .black, design: .rounded)
                                .foregroundColor(accountProviderTint(account.provider))
                        } else {
                            Image(systemName: "person.badge.key.fill")
                                .luminaFont(size: 17, weight: .bold)
                                .foregroundColor(.organicPrimary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(appState.currentAccount?.displayName ?? "Sign in to Lumia")
                            .luminaFont(size: 15, weight: .bold)
                            .foregroundColor(.organicForeground)
                        Text(accountStatusDetail)
                            .luminaFont(size: 11, weight: .medium)
                            .foregroundColor(.organicMutedFg)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer(minLength: 0)

                    Button(appState.isSignedIn ? "Manage" : "Sign In", action: onAccount)
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundColor(.organicPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Color.organicPrimary.opacity(0.10))
                        .clipShape(Capsule())
                }

                if appState.isSignedIn {
                    Button(role: .destructive, action: onSignOut) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .luminaFont(size: 12, weight: .bold)
                            .foregroundColor(Color(hex: 0xBE185D))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.organicCard)
        }

        private var membershipStatusRow: some View {
            Button(action: onMembership) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: appState.hasPremiumAccess
                                            ? [Color(hex: 0x9A6A22).opacity(0.24), Color.organicPrimary.opacity(0.14)]
                                            : [Color.organicPrimary.opacity(0.16), Color(hex: 0xD8B45D).opacity(0.13)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                            Image("LuminaMark")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .accessibilityHidden(true)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text(appState.subscriptionState.displayTitle)
                                    .luminaFont(size: 17, weight: .bold, design: .serif)
                                    .foregroundColor(.organicForeground)
                                Text(appState.hasPremiumAccess ? "ACTIVE" : "PLUS")
                                    .luminaFont(size: 8, weight: .black)
                                    .foregroundColor(appState.hasPremiumAccess ? Color(hex: 0x5D7052) : Color(hex: 0x7A5C16))
                                    .kerning(1)
                                    .padding(.horizontal, 7)
                                    .frame(height: 20)
                                    .background((appState.hasPremiumAccess ? Color(hex: 0x5D7052) : Color(hex: 0xD8B45D)).opacity(0.14))
                                    .clipShape(Capsule())
                            }
                            Text(appState.subscriptionState.displayDetail)
                                .luminaFont(size: 12, weight: .semibold)
                                .foregroundColor(.organicMutedFg)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .luminaFont(size: 12, weight: .bold)
                            .foregroundColor(.organicMutedFg)
                            .frame(width: 34, height: 34)
                            .background(Color.organicMuted.opacity(0.64))
                            .clipShape(Circle())
                    }

                    HStack(spacing: 8) {
                        MembershipMiniPill(icon: "phone.fill", title: "Live")
                        MembershipMiniPill(icon: "chart.line.uptrend.xyaxis", title: "Patterns")
                        MembershipMiniPill(icon: "brain.head.profile", title: "Memory")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(Color.organicCard)
            }
            .buttonStyle(.plain)
        }

        struct MembershipMiniPill: View {
            let icon: String
            let title: String

            var body: some View {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .luminaFont(size: 9, weight: .black)
                    Text(title)
                        .luminaFont(size: 10, weight: .black)
                }
                .foregroundColor(.organicPrimary)
                .padding(.horizontal, 9)
                .frame(height: 26)
                .background(Color.organicPrimary.opacity(0.09))
                .clipShape(Capsule())
            }
        }

        private var notificationStatusRow: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Status")
                        .luminaFont(size: 13, weight: .semibold)
                        .foregroundColor(.organicForeground)
                    Spacer()
                    Text(appState.notificationPermissionLabel)
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundColor(appState.notificationPermissionState == .denied ? Color(hex: 0xBE185D) : .organicPrimary)
                }
                if let error = appState.notificationError {
                    Text(error)
                        .luminaFont(size: 11, weight: .medium)
                        .foregroundColor(Color(hex: 0xBE185D))
                } else if appState.notificationPermissionState == .denied {
                    Text("Enable notifications in iOS Settings > Notifications > Lumia.")
                        .luminaFont(size: 11, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                } else if appState.dailyReminderEnabled && appState.jitaiNotificationsEnabled {
                    Text("Daily reminders and smart suggestions are local notifications.")
                        .luminaFont(size: 11, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                } else if appState.jitaiNotificationsEnabled {
                    Text("Smart suggestions keep quiet hours, daily caps, and fatigue limits.")
                        .luminaFont(size: 11, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                } else if appState.dailyReminderEnabled {
                    Text("Lumia schedules one local reminder each day.")
                        .luminaFont(size: 11, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.organicCard)
        }

        private var timePickerRow: some View {
            HStack {
                Text("Time")
                    .luminaFont(size: 15)
                    .foregroundColor(.organicForeground)
                Spacer()
                Picker("", selection: $appState.dailyReminderHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .tint(.organicPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.organicCard)
        }

        private func sectionHeader(_ title: String, icon: String) -> some View {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .luminaFont(size: 12, weight: .semibold)
                    .foregroundColor(.organicPrimary)
                Text(title.uppercased())
                    .luminaFont(size: 11, weight: .black)
                    .foregroundColor(.organicMutedFg)
                    .kerning(1.5)
            }
            .padding(.bottom, 6)
        }

        private func groupLabel(_ title: String) -> some View {
            Text(title)
                .luminaFont(size: 10, weight: .black)
                .foregroundColor(.organicMutedFg)
                .kerning(2)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var divider: some View {
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
        }

        private func settingsRow(icon: String, bg: Color, title: String, detail: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(bg)
                            .frame(width: 30, height: 30)
                        Image(systemName: icon)
                            .luminaFont(size: 13)
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .luminaFont(size: 15)
                            .foregroundColor(.organicForeground)
                        Text(detail)
                            .luminaFont(size: 12)
                            .foregroundColor(.organicMutedFg)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .luminaFont(size: 12)
                        .foregroundColor(Color.organicBorder)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Color.organicCard)
                .contentShape(Rectangle())
            }
        }

        private func infoRow(icon: String, bg: Color, title: String, detail: String, badge: String? = nil) -> some View {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(bg)
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .luminaFont(size: 13)
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .luminaFont(size: 15)
                        .foregroundColor(.organicForeground)
                    Text(detail)
                        .luminaFont(size: 12)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(2)
                }
                Spacer()
                if let badge {
                    Text(badge)
                        .luminaFont(size: 9, weight: .black)
                        .foregroundColor(bg)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(bg.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.organicCard)
        }

        private func toggleRow(icon: String, bg: Color, title: String, detail: String? = nil, value: Binding<Bool>) -> some View {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(bg)
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .luminaFont(size: 13)
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .luminaFont(size: 15)
                        .foregroundColor(.organicForeground)
                    if let detail {
                        Text(detail)
                            .luminaFont(size: 11, weight: .medium)
                            .foregroundColor(.organicMutedFg)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                    }
                }
                Spacer()
                Toggle("", isOn: value)
                    .tint(.organicPrimary)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.organicCard)
        }

        private func preferencePickerRow(
            icon: String,
            bg: Color,
            title: String,
            detail: String,
            selection: Binding<Int>,
            values: [Int],
            valueLabel: @escaping (Int) -> String
        ) -> some View {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(bg)
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .luminaFont(size: 13)
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .luminaFont(size: 15)
                        .foregroundColor(.organicForeground)
                    Text(detail)
                        .luminaFont(size: 11, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                }
                Spacer()
                Picker("", selection: selection) {
                    ForEach(values, id: \.self) { value in
                        Text(valueLabel(value)).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .tint(.organicPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.organicCard)
        }

        private func accountProviderTint(_ provider: LuminaAccountProvider) -> Color {
            switch provider {
            case .email: return .organicPrimary
            case .phone: return Color(hex: 0x0F766E)
            case .apple: return .organicForeground
            case .google: return Color(hex: 0x4A6FA5)
            }
        }

        private func settingsDisclosure<Content: View>(
            title: String,
            subtitle: String,
            icon: String,
            tint: Color,
            @ViewBuilder content: @escaping () -> Content
        ) -> some View {
            DisclosureGroup {
                VStack(spacing: 1) {
                    content()
                }
                .padding(.top, 10)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .luminaFont(size: 14, weight: .bold)
                        .foregroundColor(tint)
                        .frame(width: 36, height: 36)
                        .background(tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .luminaFont(size: 15, weight: .bold)
                            .foregroundColor(.organicForeground)
                        Text(subtitle)
                            .luminaFont(size: 11, weight: .medium)
                            .foregroundColor(.organicMutedFg)
                            .lineLimit(1)
                    }
                }
            }
            .tint(.organicPrimary)
            .padding(14)
            .background(Color.organicCard)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.organicBorder.opacity(0.44), lineWidth: 1)
            }
        }
    }

    struct SettingsOverviewCard: View {
        let appearance: String
        let notifications: String
        let privacyLockEnabled: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Image("LuminaMark")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Settings")
                            .luminaFont(size: 17, weight: .bold, design: .serif)
                            .foregroundColor(.organicForeground)
                        Text("Only the things you may need to change.")
                            .luminaFont(size: 12, weight: .medium)
                            .foregroundColor(.organicMutedFg)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    SettingsStatusPill(title: "Theme", value: appearance, icon: "paintpalette.fill", tint: .organicPrimary)
                    SettingsStatusPill(title: "Reminders", value: notifications, icon: "bell.fill", tint: Color(hex: 0xBE185D))
                    SettingsStatusPill(title: "Lock", value: privacyLockEnabled ? "On" : "Off", icon: "lock.fill", tint: Color(hex: 0x7A5C16))
                }
            }
            .padding(14)
            .background(Color.organicCard.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.organicBorder.opacity(0.34), lineWidth: 1)
            }
        }
    }

    struct SettingsStatusPill: View {
        let title: String
        let value: String
        let icon: String
        let tint: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: icon)
                    .luminaFont(size: 11, weight: .bold)
                    .foregroundColor(tint)
                Text(value)
                    .luminaFont(size: 12, weight: .black)
                    .foregroundColor(.organicForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(title.uppercased())
                    .luminaFont(size: 8, weight: .black)
                    .foregroundColor(.organicMutedFg)
                    .kerning(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(tint.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
    }

    struct EvaluationPanel: View {
        let promptPolicy: String
        let interventionCount: Int
        let checkInCount: Int
        let crisisRouteCount: Int
        let userControlCount: Int
        let falsePositiveCount: Int
        let canFlagSafety: Bool
        let onFlagFalsePositive: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .luminaFont(size: 17, weight: .bold)
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.organicPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Governance is on")
                            .luminaFont(size: 17, weight: .bold, design: .serif)
                            .foregroundColor(.organicForeground)
                        Text("Policy \(promptPolicy)")
                            .luminaFont(size: 12, weight: .medium)
                            .foregroundColor(.organicMutedFg)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    EvaluationMetricChip(title: "Interventions", value: "\(interventionCount)", color: .organicPrimary)
                    EvaluationMetricChip(title: "Check-ins", value: "\(checkInCount)", color: Color(hex: 0x4A90E2))
                    EvaluationMetricChip(title: "Safety routes", value: "\(crisisRouteCount)", color: Color(hex: 0xBE185D))
                    EvaluationMetricChip(title: "Controls", value: "\(userControlCount)", color: Color(hex: 0x7A5C16))
                }

                HStack(spacing: 8) {
                    Text("False positive feedback: \(falsePositiveCount)")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(.organicMutedFg)
                    Spacer()
                    Button(action: onFlagFalsePositive) {
                        Text("Too sensitive")
                            .luminaFont(size: 11, weight: .black)
                            .foregroundColor(canFlagSafety ? Color(hex: 0xBE185D) : .organicMutedFg.opacity(0.55))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.organicMuted)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canFlagSafety)
                }
            }
            .padding(18)
            .background(Color.organicCard)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.organicBorder.opacity(0.48), lineWidth: 1)
            }
        }
    }

    struct EvaluationMetricChip: View {
        let title: String
        let value: String
        let color: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .luminaFont(size: 16, weight: .black)
                    .foregroundColor(color)
                Text(title)
                    .luminaFont(size: 10, weight: .black)
                    .foregroundColor(.organicMutedFg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.organicMuted.opacity(0.56))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
    }

    // ── Account ───────────────────────────────────────────────────────
    var accountSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.organicBorder.opacity(0.72))
                .frame(width: 42, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 18)

            HStack(alignment: .top, spacing: 12) {
                Image("LuminaMark")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(accountSheetTitle)
                        .luminaFont(size: 24, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                    Text(accountSheetSubtitle)
                        .luminaFont(size: 12, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button {
                    showAccountSheet = false
                } label: {
                    Image(systemName: "xmark")
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundColor(.organicMutedFg)
                        .frame(width: 38, height: 38)
                        .background(Color.organicMuted.opacity(0.82))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 18)

            ScrollView(showsIndicators: false) {
                if let account = appState.currentAccount {
                    signedInAccountPanel(account)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 24)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        accountModeControl
                        accountMethodControl

                        VStack(spacing: 12) {
                            if authMode == .register {
                                accountTextInput(
                                    label: "Name",
                                    icon: "person.fill",
                                    placeholder: "Your name",
                                    text: $authName,
                                    contentType: .name
                                )
                            }

                            if authMethod == .email {
                                accountTextInput(
                                    label: "Email",
                                    icon: "envelope.fill",
                                    placeholder: "you@example.com",
                                    text: $authEmail,
                                    keyboard: .emailAddress,
                                    contentType: .emailAddress,
                                    autocapitalization: .never,
                                    disablesAutocorrection: true
                                )
                            } else {
                                accountTextInput(
                                    label: "Phone",
                                    icon: "phone.fill",
                                    placeholder: "+1 555 123 4567",
                                    text: $authPhone,
                                    keyboard: .phonePad,
                                    contentType: .telephoneNumber
                                )
                            }

                            accountTextInput(
                                label: "Password",
                                icon: "lock.fill",
                                placeholder: authMode == .register ? "At least 8 characters" : "Password",
                                text: $authPassword,
                                contentType: authMode == .register ? .newPassword : .password,
                                isSecure: true
                            )

                            if authMode == .register {
                                accountTextInput(
                                    label: "Confirm",
                                    icon: "checkmark.shield.fill",
                                    placeholder: "Repeat password",
                                    text: $authConfirmPassword,
                                    contentType: .newPassword,
                                    isSecure: true
                                )
                            }
                        }

                        if let authErrorMessage {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .luminaFont(size: 13, weight: .bold)
                                    .foregroundColor(Color(hex: 0xBE185D))
                                Text(authErrorMessage)
                                    .luminaFont(size: 12, weight: .semibold)
                                    .foregroundColor(Color(hex: 0xBE185D))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .background(Color(hex: 0xBE185D).opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Button(action: submitCredentialAuth) {
                            HStack(spacing: 9) {
                                if isAuthSubmitting {
                                    ProgressView()
                                        .tint(.organicPrimaryFg)
                                } else {
                                    Text(authMode == .register ? "Create account" : "Sign in")
                                    Image(systemName: "arrow.right")
                                        .luminaFont(size: 14, weight: .bold)
                                }
                            }
                            .luminaFont(size: 15, weight: .bold)
                            .foregroundColor(.organicPrimaryFg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.organicPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isAuthSubmitting)
                        .opacity(isAuthSubmitting ? 0.72 : 1)

                        accountDivider
                        federatedAuthButtons
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color.organicBackground.ignoresSafeArea())
        .presentationDetents([.height(accountSheetHeight), .large])
        .presentationDragIndicator(.hidden)
    }

    var membershipSheet: some View {
        let plans = appState.revenueCatPlans
        let selectedPlan = plans.first(where: { $0.id == selectedMembershipPlan })
            ?? plans.first(where: { $0.isRecommended })
            ?? plans.first
        let currentProductID = appState.subscriptionState.productID
        let selectedPlanIsCurrent = selectedPlan.map { isCurrentMembershipPlan($0, currentProductID: currentProductID) } ?? false

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Capsule()
                        .fill(Color.organicBorder.opacity(0.72))
                        .frame(width: 42, height: 5)
                    Spacer()
                    Button {
                        showMembershipSheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .luminaFont(size: 12, weight: .bold)
                            .foregroundColor(.organicMutedFg)
                            .frame(width: 38, height: 38)
                            .background(Color.organicMuted.opacity(0.82))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close membership")
                }
                .padding(.top, 10)

                MembershipHeroCard(
                    isPremium: appState.hasPremiumAccess,
                    statusTitle: appState.subscriptionState.displayTitle,
                    statusDetail: appState.subscriptionState.displayDetail
                )

                MembershipUsageCard(
                    isPremium: appState.hasPremiumAccess,
                    allowance: appState.subscriptionAllowance
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Included with Plus")
                        .luminaFont(size: 18, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                    MembershipFeatureRow(icon: "phone.fill", title: "Live therapy sessions", detail: "Voice sessions with transcript saved back to Therapy when available.")
                    MembershipFeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Daily patterns", detail: "Short summaries across entries without extra setup.")
                    MembershipFeatureRow(icon: "brain.head.profile", title: "Doctor memory", detail: "Each guide can keep useful context with clear privacy boundaries.")
                    MembershipFeatureRow(icon: "leaf.fill", title: "Premium Garden loops", detail: "Extra routines, quests, and restorative progress markers.")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Plans")
                        .luminaFont(size: 18, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)

                    if appState.isMembershipLoading && plans.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading App Store plans...")
                                .luminaFont(size: 13, weight: .semibold)
                                .foregroundColor(.organicMutedFg)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.organicCard)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else if plans.isEmpty {
                        Text(appState.membershipErrorMessage ?? "Plans are not available yet. Check RevenueCat offerings and App Store products, then try again.")
                            .luminaFont(size: 13, weight: .semibold)
                            .foregroundColor(.organicMutedFg)
                            .lineSpacing(3)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.organicCard)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        ForEach(plans) { plan in
                            let isCurrentPlan = isCurrentMembershipPlan(plan, currentProductID: currentProductID)
                            MembershipPlanOption(
                                title: plan.title,
                                price: plan.price,
                                detail: membershipPlanDetail(for: plan, isCurrentPlan: isCurrentPlan),
                                isSelected: selectedPlan?.id == plan.id,
                                badge: isCurrentPlan ? "Current" : (plan.isRecommended ? "Recommended" : nil)
                            ) {
                                selectedMembershipPlan = plan.id
                            }
                        }
                    }
                }

                VStack(spacing: 10) {
                    Button {
                        guard let selectedPlan else { return }
                        membershipActionError = nil
                        Task { @MainActor in
                            do {
                                try await appState.purchaseSubscriptionPlan(selectedPlan.id)
                            } catch {
                                membershipActionError = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: selectedPlanIsCurrent ? "checkmark.seal.fill" : "sparkles")
                                .luminaFont(size: 14, weight: .bold)
                            Text(purchaseButtonTitle(for: selectedPlan, isCurrentPlan: selectedPlanIsCurrent))
                        }
                        .luminaFont(size: 15, weight: .bold)
                        .foregroundColor(.organicPrimaryFg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(selectedPlanIsCurrent ? Color(hex: 0x5D7052) : Color.organicPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedPlanIsCurrent || appState.isMembershipLoading || selectedPlan == nil)

                    Button {
                        membershipActionError = nil
                        Task { @MainActor in
                            do {
                                try await appState.restoreRevenueCatPurchases()
                            } catch {
                                membershipActionError = error.localizedDescription
                            }
                        }
                    } label: {
                        Text("Restore purchases")
                            .luminaFont(size: 13, weight: .bold)
                            .foregroundColor(.organicPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.isMembershipLoading)

                    if let message = membershipActionError ?? appState.membershipErrorMessage {
                        Text(message)
                            .luminaFont(size: 11, weight: .semibold)
                            .foregroundColor(Color(hex: 0xB94A5C))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Your plan is synced to your Lumia account. Restore if you changed devices or reinstalled the app.")
                        .luminaFont(size: 11, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Monthly users can choose Yearly here. Apple handles the upgrade inside the same subscription group and applies the remaining value automatically when eligible.")
                        .luminaFont(size: 11, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
        .background(Color.organicBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .task {
            await appState.refreshRevenueCatSubscription()
            if selectedMembershipPlan == "yearly",
               let recommended = appState.revenueCatPlans.first(where: { $0.isRecommended }) {
                selectedMembershipPlan = recommended.id
            }
        }
    }

    private func isCurrentMembershipPlan(_ plan: RevenueCatPlan, currentProductID: String?) -> Bool {
        guard let currentProductID else { return false }
        return plan.productIdentifier == currentProductID
    }

    private func membershipPlanDetail(for plan: RevenueCatPlan, isCurrentPlan: Bool) -> String {
        if isCurrentPlan {
            return "Your current Lumia Plus plan"
        }
        if appState.hasPremiumAccess && plan.isRecommended {
            return "Upgrade from Monthly to Yearly through Apple"
        }
        return plan.detail
    }

    private func purchaseButtonTitle(for plan: RevenueCatPlan?, isCurrentPlan: Bool) -> String {
        guard let plan else { return "Plans unavailable" }
        if isCurrentPlan {
            return "Current plan"
        }
        if appState.hasPremiumAccess {
            return plan.isRecommended ? "Upgrade to \(plan.title)" : "Switch to \(plan.title)"
        }
        return "Continue with \(plan.title)"
    }

    struct MembershipHeroCard: View {
        @Environment(\.colorScheme) private var colorScheme
        let isPremium: Bool
        let statusTitle: String
        let statusDetail: String

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    Image("LuminaMark")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                    Spacer()
                    Text(isPremium ? "ACTIVE" : "PLUS")
                        .luminaFont(size: 9, weight: .black)
                        .foregroundColor(isDark ? Color(hex: 0xD8E8C7) : Color(hex: 0x5D7052))
                        .kerning(1.4)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background((isDark ? Color.white.opacity(0.10) : Color.white.opacity(0.58)))
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Lumia Plus")
                        .luminaFont(size: 32, weight: .bold, design: .serif)
                        .foregroundColor(isDark ? Color(hex: 0xF7F2E8) : .organicForeground)
                    Text("More presence when you need it: live sessions, deeper reflections, and memory that stays under your control.")
                        .luminaFont(size: 14, weight: .semibold)
                        .foregroundColor(isDark ? Color(hex: 0xD7D1C4) : .organicMutedFg)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Image(systemName: isPremium ? "checkmark.seal.fill" : "sparkles")
                        .luminaFont(size: 13, weight: .bold)
                        .foregroundColor(isDark ? Color(hex: 0xCDE0B4) : .organicPrimary)
                        .frame(width: 30, height: 30)
                        .background((isDark ? Color.white.opacity(0.10) : Color.white.opacity(0.46)))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusTitle)
                            .luminaFont(size: 13, weight: .bold)
                            .foregroundColor(isDark ? Color(hex: 0xF7F2E8) : .organicForeground)
                        Text(statusDetail)
                            .luminaFont(size: 11, weight: .semibold)
                            .foregroundColor(isDark ? Color(hex: 0xD7D1C4) : .organicMutedFg)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.38))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: heroColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.organicBorder.opacity(0.36), lineWidth: 1)
            }
        }

        private var isDark: Bool { colorScheme == .dark }

        private var heroColors: [Color] {
            if isDark {
                return [Color(hex: 0x1A2118), Color(hex: 0x2F3A2A), Color(hex: 0x3A301F)]
            }
            return [Color(hex: 0xF5E8C7), Color(hex: 0xDDE8CF), Color.organicCard]
        }
    }

    struct MembershipUsageCard: View {
        let isPremium: Bool
        let allowance: SubscriptionAllowance

        private var aiProgress: Double {
            guard let limit = allowance.aiChatDailyLimit, limit > 0 else { return 1 }
            return min(1, Double(allowance.aiChatRepliesToday) / Double(limit))
        }

        private var voiceProgress: Double {
            guard allowance.voiceLimitSeconds > 0 else { return 0 }
            return min(1, Double(allowance.voiceUsedSeconds) / Double(allowance.voiceLimitSeconds))
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text(isPremium ? "Plus usage" : "Free usage today")
                        .luminaFont(size: 18, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                    Spacer()
                    Text(isPremium ? "MONTHLY" : "DAILY")
                        .luminaFont(size: 9, weight: .black)
                        .foregroundColor(.organicMutedFg)
                        .kerning(1.2)
                }

                if isPremium {
                    MembershipMeterRow(
                        icon: "message.fill",
                        title: "AI chat",
                        detail: "Expanded fair use",
                        progress: 1,
                        tint: .organicPrimary
                    )
                } else {
                    MembershipMeterRow(
                        icon: "message.fill",
                        title: "AI chat",
                        detail: allowance.aiUsageText,
                        progress: aiProgress,
                        tint: .organicPrimary
                    )
                }

                MembershipMeterRow(
                    icon: "phone.fill",
                    title: "Voice",
                    detail: "\(allowance.voiceUsageText) of \(allowance.voiceLimitText)",
                    progress: voiceProgress,
                    tint: Color(hex: 0xD8B45D)
                )
            }
            .padding(16)
            .background(Color.organicCard)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.organicBorder.opacity(0.30), lineWidth: 1)
            }
        }
    }

    struct MembershipMeterRow: View {
        let icon: String
        let title: String
        let detail: String
        let progress: Double
        let tint: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .luminaFont(size: 12, weight: .black)
                        .foregroundColor(tint)
                        .frame(width: 28, height: 28)
                        .background(tint.opacity(0.11))
                        .clipShape(Circle())

                    Text(title)
                        .luminaFont(size: 13, weight: .black)
                        .foregroundColor(.organicForeground)

                    Spacer()

                    Text(detail)
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.organicMuted.opacity(0.65))
                        Capsule()
                            .fill(tint)
                            .frame(width: max(10, proxy.size.width * progress))
                    }
                }
                .frame(height: 7)
            }
        }
    }

    struct MembershipFeatureRow: View {
        let icon: String
        let title: String
        let detail: String

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .luminaFont(size: 13, weight: .bold)
                    .foregroundColor(.organicPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.organicPrimary.opacity(0.10))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .luminaFont(size: 14, weight: .bold)
                        .foregroundColor(.organicForeground)
                    Text(detail)
                        .luminaFont(size: 12, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(Color.organicCard)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.organicBorder.opacity(0.30), lineWidth: 1)
            }
        }
    }

    struct MembershipPlanOption: View {
        let title: String
        let price: String
        let detail: String
        let isSelected: Bool
        let badge: String?
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .luminaFont(size: 18, weight: .bold)
                        .foregroundColor(isSelected ? .organicPrimary : .organicMutedFg)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 7) {
                            Text(title)
                                .luminaFont(size: 15, weight: .bold)
                                .foregroundColor(.organicForeground)
                            if let badge {
                                Text(badge)
                                    .luminaFont(size: 8, weight: .black)
                                    .foregroundColor(Color(hex: 0x7A5C16))
                                    .kerning(0.7)
                                    .padding(.horizontal, 7)
                                    .frame(height: 19)
                                    .background(Color(hex: 0xD8B45D).opacity(0.16))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(detail)
                            .luminaFont(size: 11, weight: .semibold)
                            .foregroundColor(.organicMutedFg)
                            .lineLimit(2)
                    }
                    Spacer()
                    Text(price)
                        .luminaFont(size: 13, weight: .black, design: .rounded)
                        .foregroundColor(.organicForeground)
                        .multilineTextAlignment(.trailing)
                }
                .padding(15)
                .background(isSelected ? Color.organicPrimary.opacity(0.10) : Color.organicCard)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isSelected ? Color.organicPrimary.opacity(0.42) : Color.organicBorder.opacity(0.30), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    var accountSheetTitle: String {
        if appState.isSignedIn { return "Your account" }
        return authMode == .register ? "Create account" : "Welcome back"
    }

    var accountSheetSubtitle: String {
        if let account = appState.currentAccount {
            return "\(account.provider.title) · \(account.primaryContact)"
        }
        return authMode == .register ? "Save a private Lumia profile on this device." : "Continue with a saved profile or use Apple."
    }

    var accountSheetHeight: CGFloat {
        if appState.isSignedIn { return 390 }
        return authMode == .register ? 760 : 640
    }

    var accountModeControl: some View {
        HStack(spacing: 6) {
            ForEach(ProfileAuthMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        authMode = mode
                        authErrorMessage = nil
                    }
                } label: {
                    Text(mode.title)
                        .luminaFont(size: 13, weight: .bold)
                        .foregroundColor(authMode == mode ? .organicPrimaryFg : .organicMutedFg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(authMode == mode ? Color.organicPrimary : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.organicMuted.opacity(0.72), in: Capsule())
    }

    var accountMethodControl: some View {
        HStack(spacing: 8) {
            ForEach(ProfileCredentialMethod.allCases) { method in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        authMethod = method
                        authErrorMessage = nil
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: method == .email ? "envelope.fill" : "phone.fill")
                            .luminaFont(size: 12, weight: .bold)
                        Text(method.title)
                            .luminaFont(size: 13, weight: .bold)
                    }
                    .foregroundColor(authMethod == method ? .organicPrimary : .organicMutedFg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(authMethod == method ? Color.organicPrimary.opacity(0.12) : Color.organicMuted.opacity(0.54))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(authMethod == method ? Color.organicPrimary.opacity(0.34) : Color.clear, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    var accountDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.organicBorder.opacity(0.5))
                .frame(height: 1)
            Text("or")
                .luminaFont(size: 11, weight: .black)
                .foregroundColor(.organicMutedFg)
            Rectangle()
                .fill(Color.organicBorder.opacity(0.5))
                .frame(height: 1)
        }
    }

    func accountTextInput(
        label: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        isSecure: Bool = false,
        autocapitalization: TextInputAutocapitalization = .sentences,
        disablesAutocorrection: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased())
                .luminaFont(size: 10, weight: .black)
                .foregroundColor(.organicMutedFg)
                .kerning(1.4)

            HStack(spacing: 11) {
                Image(systemName: icon)
                    .luminaFont(size: 13, weight: .bold)
                    .foregroundColor(.organicPrimary)
                    .frame(width: 22)

                if isSecure {
                    SecureField(placeholder, text: text)
                        .textContentType(contentType)
                        .luminaFont(size: 15, weight: .semibold)
                        .foregroundColor(.organicForeground)
                        .tint(.organicPrimary)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboard)
                        .textContentType(contentType)
                        .textInputAutocapitalization(autocapitalization)
                        .disableAutocorrection(disablesAutocorrection)
                        .luminaFont(size: 15, weight: .semibold)
                        .foregroundColor(.organicForeground)
                        .tint(.organicPrimary)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color.organicMuted.opacity(0.70))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(Color.organicBorder.opacity(0.32), lineWidth: 1)
            }
        }
    }

    func signedInAccountPanel(_ account: LuminaAccount) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accountProviderTint(account.provider).opacity(0.16))
                        .frame(width: 64, height: 64)
                    Text(account.initials)
                        .luminaFont(size: 22, weight: .black, design: .rounded)
                        .foregroundColor(accountProviderTint(account.provider))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.displayName)
                        .luminaFont(size: 18, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                    Label(account.provider.title, systemImage: accountProviderIcon(account.provider))
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundColor(accountProviderTint(account.provider))
                    Text(account.primaryContact)
                        .luminaFont(size: 12, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                }
                Spacer(minLength: 0)
            }

            Text("Account sign-in is now separated from local privacy lock. Signing out keeps local data on this device until you choose to delete it.")
                .luminaFont(size: 12, weight: .medium)
                .foregroundColor(.organicMutedFg)
                .lineSpacing(3)

            Button(role: .destructive) {
                showAccountSheet = false
                showSignOutConfirm = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .luminaFont(size: 15, weight: .bold)
                    .foregroundColor(Color(hex: 0xBE185D))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: 0xBE185D).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    var federatedAuthButtons: some View {
        VStack(spacing: 10) {
            SignInWithAppleButton(
                authMode == .register ? .signUp : .signIn,
                onRequest: prepareAppleAuthorizationRequest,
                onCompletion: handleAppleAuthorization
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(isAuthSubmitting)
            .opacity(isAuthSubmitting ? 0.72 : 1)

            Button(action: handleGoogleSignIn) {
                HStack(spacing: 10) {
                    Image(systemName: accountProviderIcon(.google))
                        .luminaFont(size: 15, weight: .bold)
                    Text("Continue with Google")
                        .luminaFont(size: 15, weight: .bold)
                }
                .foregroundColor(.organicForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.organicMuted.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    func submitCredentialAuth() {
        authErrorMessage = nil
        guard !isAuthSubmitting else { return }
        isAuthSubmitting = true
        Task {
            do {
                switch (authMode, authMethod) {
                case (.signIn, .email):
                    try await appState.signInWithEmail(email: authEmail, password: authPassword)
                case (.register, .email):
                    try await appState.registerAccountWithEmail(
                        displayName: authName,
                        email: authEmail,
                        password: authPassword,
                        confirmPassword: authConfirmPassword
                    )
                case (.signIn, .phone):
                    throw LuminaAuthError.providerUnavailable("Phone sign-in is not available yet. Use email, Apple, or Google for now.")
                case (.register, .phone):
                    throw LuminaAuthError.providerUnavailable("Phone registration is not available yet. Use email, Apple, or Google for now.")
                }
                resetAuthFormAfterSuccess()
            } catch {
                authErrorMessage = userFacingAuthError(error)
            }
            isAuthSubmitting = false
        }
    }

    func prepareAppleAuthorizationRequest(_ request: ASAuthorizationAppleIDRequest) {
        authErrorMessage = nil
        do {
            let nonce = try AppleSignInNonce.random()
            currentAppleNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)
        } catch {
            currentAppleNonce = nil
            authErrorMessage = userFacingAuthError(error)
        }
    }

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard !isAuthSubmitting else { return }
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authErrorMessage = "Apple authorization did not return a usable credential."
                return
            }
            guard let rawNonce = currentAppleNonce else {
                authErrorMessage = "Apple sign-in could not complete securely. Please try again."
                return
            }
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                authErrorMessage = "Apple sign-in did not return an identity token."
                currentAppleNonce = nil
                return
            }

            authErrorMessage = nil
            isAuthSubmitting = true
            Task {
                do {
                    try await appState.signInWithApple(
                        idToken: idToken,
                        rawNonce: rawNonce,
                        fullName: credential.fullName,
                        email: credential.email
                    )
                    resetAuthFormAfterSuccess()
                } catch {
                    authErrorMessage = userFacingAuthError(error)
                }
                currentAppleNonce = nil
                isAuthSubmitting = false
            }
        case .failure(let error):
            currentAppleNonce = nil
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                authErrorMessage = nil
                return
            }
            authErrorMessage = userFacingAuthError(error)
        }
    }

    func handleGoogleSignIn() {
        authErrorMessage = nil
        guard !isAuthSubmitting else { return }
        isAuthSubmitting = true
        Task {
            do {
                try await appState.signInWithGoogle()
                resetAuthFormAfterSuccess()
            } catch {
                authErrorMessage = userFacingAuthError(error)
            }
            isAuthSubmitting = false
        }
    }

    func resetAuthFormAfterSuccess() {
        authPassword = ""
        authConfirmPassword = ""
        authErrorMessage = nil
        showAccountSheet = false
    }

    // ── Edit Sheets ───────────────────────────────────────────────────
    var identitySheet: some View {
        ProfileSheetChrome(
            title: "Profile",
            saveTitle: "Save",
            canSave: true,
            onCancel: { showIdentityEdit = false },
            onSave: {
                appState.profileAvatarID = editedAvatarID
                appState.profileGender = editedGender
                showIdentityEdit = false
            }
        ) {
            VStack(spacing: 18) {
                ProfileAvatarImage(avatarID: editedAvatarID, fallbackText: initials, size: 104)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 12) {
                    ProfileFieldLabel("Avatar")

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(ProfileAvatarID.allCases) { avatar in
                            Button {
                                editedAvatarID = avatar
                            } label: {
                                VStack(spacing: 7) {
                                    ProfileAvatarImage(avatarID: avatar, fallbackText: "", size: 64)
                                        .overlay {
                                            if editedAvatarID == avatar {
                                                RoundedRectangle(cornerRadius: 21, style: .continuous)
                                                    .strokeBorder(Color.organicPrimary, lineWidth: 3)
                                            }
                                        }
                                    Text(avatar.title)
                                        .luminaFont(size: 11, weight: .black)
                                        .foregroundColor(editedAvatarID == avatar ? .organicPrimary : .organicMutedFg)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    (editedAvatarID == avatar ? Color.organicPrimary.opacity(0.12) : Color.organicMuted.opacity(0.56)),
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    ProfileFieldLabel("Gender")

                    VStack(spacing: 8) {
                        ForEach(ProfileGender.allCases) { gender in
                            Button {
                                editedGender = gender
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: editedGender == gender ? "checkmark.circle.fill" : "circle")
                                        .luminaFont(size: 15, weight: .bold)
                                        .foregroundColor(editedGender == gender ? .organicPrimary : .organicMutedFg.opacity(0.72))

                                    Text(gender.title)
                                        .luminaFont(size: 14, weight: .bold)
                                        .foregroundColor(.organicForeground)

                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .background(
                                    editedGender == gender ? Color.organicPrimary.opacity(0.10) : Color.organicMuted.opacity(0.48),
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .presentationDetents([.height(appState.useLargeText ? 690 : 620), .large])
    }

    var nameSheet: some View {
        ProfileSheetChrome(
            title: "Display Name",
            saveTitle: "Save",
            canSave: !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onCancel: { showNameEdit = false },
            onSave: {
                let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { appState.userName = trimmed }
                showNameEdit = false
            }
        ) {
            ProfileFieldLabel("Your Name")
            TextField("Name", text: $editedName)
                .luminaFont(size: 18, weight: .medium)
                .foregroundColor(.organicForeground)
                .tint(.organicPrimary)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color.organicMuted.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .presentationDetents([.height(appState.useLargeText ? 320 : 270)])
    }

    var bioSheet: some View {
        ProfileSheetChrome(
            title: "Bio",
            saveTitle: "Save",
            canSave: true,
            onCancel: { showBioEdit = false },
            onSave: {
                appState.userBio = editedBio.trimmingCharacters(in: .whitespacesAndNewlines)
                showBioEdit = false
            }
        ) {
            ProfileFieldLabel("About You")
            ZStack(alignment: .topLeading) {
                if editedBio.isEmpty {
                    Text("A short description about yourself.")
                        .luminaFont(size: 15, weight: .medium)
                        .foregroundColor(.organicMutedFg.opacity(0.76))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                }

                TextEditor(text: $editedBio)
                    .luminaFont(size: 16, weight: .medium)
                    .foregroundColor(.organicForeground)
                    .tint(.organicPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 150)
            }
            .background(Color.organicMuted.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .presentationDetents([.height(appState.useLargeText ? 430 : 370)])
    }

    var aiConnectionSheet: some View {
        ProfileSheetChrome(
            title: "AI Connection",
            saveTitle: isTestingAIConnection ? "Checking..." : (aiConnectionStatusMessage == nil ? "Check Status" : "Check Again"),
            canSave: !isTestingAIConnection,
            onCancel: { showAIConnection = false },
            onSave: {
                testAIConnection()
            }
        ) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: 0x9A6A22).opacity(0.16))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .luminaFont(size: 18, weight: .black)
                        .foregroundStyle(Color(hex: 0x9A6A22))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Service Status")
                        .luminaFont(size: 15, weight: .bold)
                        .foregroundColor(.organicForeground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("AI support is managed securely by Lumia. No setup is needed on this device.")
                        .luminaFont(size: 12, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.organicMuted.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            if let aiConnectionStatusMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .luminaFont(size: 12, weight: .black)
                        .foregroundStyle(Color.organicPrimary)
                    Text(aiConnectionStatusMessage)
                        .luminaFont(size: 12, weight: .semibold)
                        .foregroundStyle(Color.organicPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.organicPrimary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if let aiConnectionErrorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .luminaFont(size: 12, weight: .black)
                        .foregroundStyle(Color(hex: 0xBE185D))
                    Text(aiConnectionErrorMessage)
                        .luminaFont(size: 12, weight: .semibold)
                        .foregroundStyle(Color(hex: 0xBE185D))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0xBE185D).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if isTestingAIConnection {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Color.organicPrimary)
                    Text("Checking AI service status...")
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundStyle(Color.organicMutedFg)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .presentationDetents([.height(appState.useLargeText ? 430 : 360)])
    }

    private func testAIConnection() {
        aiConnectionErrorMessage = nil
        aiConnectionStatusMessage = nil
        isTestingAIConnection = true

        Task {
            do {
                let config = try await withAIConnectionTimeout(seconds: 12) {
                    try await GeminiService.shared.runtimeConfig()
                }
                await MainActor.run {
                    isTestingAIConnection = false
                    aiConnectionStatusMessage = config.promptVersion.isEmpty
                        ? "AI service is connected."
                        : "AI service is connected. Prompt \(config.promptVersion)."
                }
            } catch is CancellationError {
                await MainActor.run {
                    isTestingAIConnection = false
                    aiConnectionErrorMessage = "AI service check was cancelled."
                }
            } catch {
                await MainActor.run {
                    isTestingAIConnection = false
                    aiConnectionErrorMessage = GeminiService.userFacingMessage(
                        for: error,
                        fallback: "AI service is unavailable right now. Try again in a moment."
                    )
                }
            }
        }
    }

    private func withAIConnectionTimeout<T>(
        seconds: UInt64,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw URLError(.timedOut)
            }

            guard let result = try await group.next() else {
                throw URLError(.timedOut)
            }
            group.cancelAll()
            return result
        }
    }

    private func userFacingAuthError(_ error: Error) -> String {
        if let authError = error as? LuminaAuthError {
            return authError.localizedDescription
        }

        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("network") ||
            message.localizedCaseInsensitiveContains("timed out") ||
            message.localizedCaseInsensitiveContains("offline") {
            return "The connection was interrupted. Check your network and try again."
        }
        if message.localizedCaseInsensitiveContains("password") {
            return "The email or password does not look right."
        }
        if message.localizedCaseInsensitiveContains("email") {
            return "Check the email address and try again."
        }
        if message.localizedCaseInsensitiveContains("cancel") {
            return "Sign in was cancelled."
        }
        return "Sign in could not be completed. Please try again."
    }

    var goalsSheet: some View {
        ProfileSheetChrome(
            title: "Wellness Goals",
            saveTitle: "Done",
            canSave: true,
            onCancel: { showGoalSheet = false },
            onSave: { showGoalSheet = false }
        ) {
            GoalSettingStepper(
                icon: "scroll.fill",
                title: "Weekly Journaling",
                detail: "\(appState.journalGoalPerWeek)x per week",
                tint: .organicPrimary,
                value: $appState.journalGoalPerWeek,
                range: 1...7,
                step: 1
            )

            GoalSettingStepper(
                icon: "wind",
                title: "Meditation",
                detail: "\(appState.meditationGoalMinutes) min per day",
                tint: Color(hex: 0x4A6FA5),
                value: $appState.meditationGoalMinutes,
                range: 5...60,
                step: 5
            )
        }
        .presentationDetents([.height(appState.useLargeText ? 430 : 370)])
    }

    struct ProfileSheetChrome<Content: View>: View {
        let title: String
        let saveTitle: String
        let canSave: Bool
        let onCancel: () -> Void
        let onSave: () -> Void
        let content: Content

        init(
            title: String,
            saveTitle: String,
            canSave: Bool,
            onCancel: @escaping () -> Void,
            onSave: @escaping () -> Void,
            @ViewBuilder content: () -> Content
        ) {
            self.title = title
            self.saveTitle = saveTitle
            self.canSave = canSave
            self.onCancel = onCancel
            self.onSave = onSave
            self.content = content()
        }

        var body: some View {
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel", action: onCancel)
                        .luminaFont(size: 15, weight: .semibold)
                        .foregroundColor(.organicPrimary)
                        .frame(width: 82, height: 40)
                        .background(Color.organicMuted.opacity(0.72))
                        .clipShape(Capsule())

                    Spacer()

                    Text(title)
                        .luminaFont(size: 17, weight: .bold)
                        .foregroundColor(.organicForeground)

                    Spacer()

                    Button(saveTitle, action: onSave)
                        .luminaFont(size: 15, weight: .bold)
                        .foregroundColor(canSave ? .organicPrimary : .organicMutedFg)
                        .frame(width: 82, height: 40)
                        .background(Color.organicMuted.opacity(0.72))
                        .clipShape(Capsule())
                        .disabled(!canSave)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)

                Spacer(minLength: 0)
            }
            .background(Color.organicBackground.ignoresSafeArea())
        }
    }

    struct ProfileFieldLabel: View {
        let text: String

        init(_ text: String) {
            self.text = text
        }

        var body: some View {
            Text(text)
                .luminaFont(size: 12, weight: .black)
                .foregroundColor(.organicMutedFg)
                .textCase(.uppercase)
                .kerning(1.2)
        }
    }

    struct GoalSettingStepper: View {
        let icon: String
        let title: String
        let detail: String
        let tint: Color
        @Binding var value: Int
        let range: ClosedRange<Int>
        let step: Int

        var body: some View {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .luminaFont(size: 15, weight: .bold)
                    .foregroundColor(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .luminaFont(size: 15, weight: .bold)
                        .foregroundColor(.organicForeground)
                    Text(detail)
                        .luminaFont(size: 12, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                }

                Spacer()

                Stepper("", value: $value, in: range, step: step)
                    .labelsHidden()
                    .tint(tint)
            }
            .padding(14)
            .background(Color.organicCard)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.organicBorder.opacity(0.42), lineWidth: 1)
            }
        }
    }
}
