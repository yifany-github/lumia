import SwiftUI
import Charts

// MARK: - Dashboard

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingEditor = false
    @State private var editingEntry: JournalEntry? = nil
    @State private var showingProfile = false
    @State private var checkInMood = 5.0
    @State private var checkInStress = 5.0
    @State private var checkInNote = ""

    private var sortedEntries: [JournalEntry] {
        appState.entries.sorted { $0.timestamp > $1.timestamp }
    }

    private var latestEntry: JournalEntry? {
        sortedEntries.first
    }

    private var recentEntries: [JournalEntry] {
        Array(sortedEntries.prefix(1))
    }

    private var latestSession: ChatSession? {
        appState.chatSessions.values
            .filter { !$0.messages.isEmpty && $0.archivedAt == nil }
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .first
    }

    private var latestSessionTherapist: Therapist? {
        guard let latestSession else { return nil }
        return allTherapists.first { $0.id == latestSession.therapistID || $0.id == latestSession.id }
    }

    private var hasReflectionToday: Bool {
        sortedEntries.contains { entry in
            Calendar.current.isDate(Date(timeIntervalSince1970: entry.timestamp), inSameDayAs: Date())
        }
    }

    private var nextHabit: Habit? {
        appState.habits.first(where: { $0.completedAt == nil }) ?? appState.habits.first
    }

    private var chartData: [(day: String, score: Int, energy: Int, anxiety: Int)] {
        Array(appState.entries.sorted { $0.timestamp < $1.timestamp }.suffix(7).map {
            (
                day: $0.date,
                score: $0.sentimentScore ?? 50,
                energy: $0.energyLevel ?? 50,
                anxiety: $0.anxietyLevel ?? 0
            )
        })
    }

    var body: some View {
        ZStack {
            DashboardBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    DashboardHeroView(
                        userName: appState.userName,
                        latestMood: latestEntry?.mood,
                        context: appState.wellbeingContext,
                        onOpenProfile: { showingProfile = true }
                    )

                    HomeMembershipStatusCard(
                        hasPremiumAccess: appState.hasPremiumAccess,
                        onOpenMembership: { showingProfile = true }
                    )

                    HomeRecommendationCard(recommendation: makeRecommendation())

                    HomeStillOpenCard(
                        entries: recentEntries,
                        latestSession: latestSession,
                        therapist: latestSessionTherapist,
                        onOpenJournal: { appState.selectedTab = 1 },
                        onNewReflection: {
                            editingEntry = nil
                            showingEditor = true
                        },
                        onOpenTherapy: {
                            if let therapist = latestSessionTherapist {
                                appState.requestTherapy(with: therapist)
                            } else {
                                appState.selectedTab = 2
                            }
                        }
                    )

                    DailyCheckInCard(
                        existingCheckIn: appState.todayCheckIn,
                        moodScore: $checkInMood,
                        stressScore: $checkInStress,
                        note: $checkInNote,
                        onSave: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                appState.recordDailyCheckIn(
                                    moodScore: Int(checkInMood.rounded()),
                                    stressScore: Int(checkInStress.rounded()),
                                    note: checkInNote
                                )
                            }
                        },
                        onQuickSave: { mood, stress in
                            withAnimation(.easeInOut(duration: 0.18)) {
                                checkInMood = Double(mood)
                                checkInStress = Double(stress)
                                checkInNote = ""
                                appState.recordDailyCheckIn(
                                    moodScore: mood,
                                    stressScore: stress,
                                    note: nil
                                )
                            }
                        }
                    )

                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 44)
            }
        }
        .sheet(isPresented: $showingEditor) {
            JournalEditorView(editingEntry: editingEntry)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        .onAppear {
            syncCheckInState()
            appState.refreshJITAI()
        }
    }

    private func syncCheckInState() {
        guard let checkIn = appState.todayCheckIn else { return }
        checkInMood = Double(checkIn.moodScore)
        checkInStress = Double(checkIn.stressScore)
        checkInNote = checkIn.note ?? ""
    }

    private func makeRecommendation() -> HomeRecommendation {
        if let followUp = appState.activeFollowUp {
            return HomeRecommendation(
                eyebrow: "For now",
                title: "Check in with one tiny plan",
                message: followUp.prompt,
                actionTitle: "Mark done",
                icon: "sparkles",
                tint: Color(hex: 0x7A5C16),
                reasons: [
                    "You already chose this small step.",
                    "A quick check-in keeps the plan light.",
                    "You can snooze it instead of forcing it."
                ],
                action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        _ = appState.recordFollowUp(id: followUp.id, status: .completed)
                    }
                },
                secondaryTitle: "Later",
                secondaryAction: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        _ = appState.snoozeFollowUp(id: followUp.id)
                    }
                },
                quietTitle: "Too hard",
                quietAction: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        _ = appState.recordFollowUp(id: followUp.id, status: .tooHard)
                    }
                }
            )
        }

        if let decision = appState.activeJITAIDecision {
            return HomeRecommendation(
                eyebrow: "A gentle option",
                title: decision.title,
                message: decision.message,
                actionTitle: decision.actionTitle,
                icon: icon(for: decision.kind),
                tint: tint(for: decision.kind),
                reasons: decision.reasonCodes.map(reasonText(for:)),
                action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        appState.acceptJITAIDecision(id: decision.id)
                    }
                },
                secondaryTitle: "Not now",
                secondaryAction: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        appState.dismissJITAIDecision(id: decision.id)
                    }
                },
                quietTitle: "Quiet today",
                quietAction: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        appState.suppressJITAIToday(id: decision.id)
                    }
                }
            )
        }

        if let checkIn = appState.todayCheckIn, checkIn.stressScore >= 7 {
            return HomeRecommendation(
                eyebrow: "Start small",
                title: "Take pressure down first",
                message: "A one-minute reset may fit better than adding another task.",
                actionTitle: "Take a reset",
                icon: "wind",
                tint: Color(hex: 0x8B7A65),
                reasons: [
                    "Your stress check-in is on the heavier side.",
                    "Sanctuary keeps this to a short reset.",
                    "You can leave after one minute."
                ],
                action: { appState.selectedTab = 4 }
            )
        }

        if let checkIn = appState.todayCheckIn, checkIn.moodScore <= 3 {
            return HomeRecommendation(
                eyebrow: "Keep it gentle",
                title: "Choose recovery, not momentum",
                message: "Low mood days usually need less pressure and one softer next step.",
                actionTitle: "Take a reset",
                icon: "moon.zzz.fill",
                tint: Color(hex: 0x4A90E2),
                reasons: [
                    "Your mood check-in is lower today.",
                    "This is only a support suggestion, not a diagnosis.",
                    "A short reset can be enough."
                ],
                action: { appState.selectedTab = 4 }
            )
        }

        if let nextHabit {
            return HomeRecommendation(
                eyebrow: "One small step",
                title: nextHabit.title,
                message: nextHabit.description,
                actionTitle: "Tend this",
                icon: "leaf.fill",
                tint: Color(hex: 0x0F766E),
                reasons: [
                    "This came from a tiny plan you saved.",
                    "Garden turns small care into visible progress.",
                    "There is no streak pressure here."
                ],
                action: { appState.selectedTab = 3 }
            )
        }

        if !hasReflectionToday {
            return HomeRecommendation(
                eyebrow: "A light reflection",
                title: "Write one honest sentence",
                message: "A short note is enough to keep the pattern visible.",
                actionTitle: "Write a little",
                icon: "square.and.pencil",
                tint: .organicSecondary,
                reasons: [
                    "There is no reflection for today yet.",
                    "One sentence is enough.",
                    "It gives the day a place to go."
                ],
                action: {
                    editingEntry = nil
                    showingEditor = true
                }
            )
        }

        return HomeRecommendation(
            eyebrow: "One quiet minute",
            title: "Pick the support that fits",
            message: "You do not need to explain everything before getting a little steadier.",
            actionTitle: "Take one minute",
            icon: "leaf.fill",
            tint: .organicPrimary,
            reasons: [
                "No urgent signal needs attention.",
                "Sanctuary is the lowest-pressure place to start.",
                "You can switch to Journal or Therapy anytime."
            ],
            action: { appState.selectedTab = 4 }
        )
    }

    private func icon(for kind: JITAIPromptKind) -> String {
        switch kind {
        case .recovery:
            return "moon.zzz.fill"
        case .movement:
            return "figure.walk"
        case .reflection:
            return "square.and.pencil"
        case .grounding:
            return "wind"
        case .garden:
            return "leaf.fill"
        }
    }

    private func tint(for kind: JITAIPromptKind) -> Color {
        switch kind {
        case .recovery:
            return Color(hex: 0x4A90E2)
        case .movement, .garden:
            return Color(hex: 0x0F766E)
        case .reflection:
            return Color(hex: 0x7A5C16)
        case .grounding:
            return Color(hex: 0x8B7A65)
        }
    }

    private func reasonText(for code: String) -> String {
        switch code {
        case "checkin.stress.high":
            return "Your check-in suggests today may feel heavier."
        case "checkin.mood.low":
            return "Your mood check-in leaned lower today."
        case "context.self_report":
            return "Your own check-ins matter most here."
        case "journal.anxiety.high":
            return "Your latest reflection sounded more tense."
        case "intervention.grounding":
            return "Grounding keeps the next step small."
        case "health.sleep.below_personal_range":
            return "Rest may be lower than your recent range."
        case "intervention.recovery":
            return "Recovery can be enough for now."
        case "health.steps.below_personal_range":
            return "Movement may have been lighter than usual."
        case "garden.tiny_action":
            return "A tiny Garden action keeps this simple."
        case "journal.no_entry_today":
            return "A short note can be enough today."
        case "intervention.journaling_prompt":
            return "A short prompt keeps this light."
        case "garden.open_habit":
            return "One small Garden step is available."
        case "behavior.small_step":
            return "Small steps are easier to return to."
        default:
            return code.replacingOccurrences(of: ".", with: " ")
        }
    }
}

private struct HomeRecommendation {
    let eyebrow: String
    let title: String
    let message: String
    let actionTitle: String
    let icon: String
    let tint: Color
    let reasons: [String]
    let action: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?
    let quietTitle: String?
    let quietAction: (() -> Void)?

    init(
        eyebrow: String,
        title: String,
        message: String,
        actionTitle: String,
        icon: String,
        tint: Color,
        reasons: [String],
        action: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        quietTitle: String? = nil,
        quietAction: (() -> Void)? = nil
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.icon = icon
        self.tint = tint
        self.reasons = reasons
        self.action = action
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
        self.quietTitle = quietTitle
        self.quietAction = quietAction
    }
}

private struct DashboardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.organicBackground.ignoresSafeArea()
            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(hex: 0x080C07),
                Color.organicBackground,
                Color.organicBackdrop
            ]
        }

        return [
            Color(hex: 0xF8F5EE),
            Color.organicBackground,
            Color(hex: 0xEEF4EA).opacity(0.62)
        ]
    }
}

// MARK: - Hero

private struct DashboardHeroView: View {
    let userName: String
    let latestMood: MoodType?
    let context: WellbeingContextSnapshot
    let onOpenProfile: () -> Void

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private var displayName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "there" : userName
    }

    private var shortName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }

    private var moodLine: String {
        if let latestMood {
            return "\(latestMood.rawValue.capitalized) lately"
        }
        return context.headline
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    LuminaAssetIcon(name: "LuminaMark", size: 19, tint: .organicPrimary)
                        .frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Lumina")
                            .luminaFont(size: 17, weight: .bold, design: .serif)
                            .foregroundColor(.organicForeground)
                        Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .luminaFont(size: 11, weight: .semibold)
                            .foregroundColor(.organicMutedFg)
                    }
                }

                Spacer()

                Button(action: onOpenProfile) {
                    Image(systemName: "person.crop.circle.fill")
                        .luminaFont(size: 25, weight: .regular)
                        .foregroundColor(.organicPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open profile")
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("\(greeting), \(shortName)")
                    .luminaFont(size: 27, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(moodLine)
                    .luminaFont(size: 14, weight: .medium)
                    .foregroundColor(.organicMutedFg)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }
}

// MARK: - Membership

private struct HomeMembershipStatusCard: View {
    let hasPremiumAccess: Bool
    let onOpenMembership: () -> Void

    private var title: String {
        hasPremiumAccess ? "Plus is active" : "Free plan"
    }

    private var message: String {
        hasPremiumAccess
            ? "Live sessions, deeper insights, and guide memory are available."
            : "Today includes 20 AI replies and a 5-minute voice preview."
    }

    private var actionTitle: String {
        hasPremiumAccess ? "Manage" : "See Plus"
    }

    var body: some View {
        Button(action: onOpenMembership) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center, spacing: 12) {
                    Image("LuminaMark")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .padding(9)
                        .background(Color.organicPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .luminaFont(size: 18, weight: .bold, design: .serif)
                            .foregroundColor(.organicForeground)
                        Text(message)
                            .luminaFont(size: 12, weight: .semibold)
                            .foregroundColor(.organicMutedFg)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    Text(actionTitle)
                        .luminaFont(size: 12, weight: .black)
                        .foregroundColor(hasPremiumAccess ? .organicPrimary : Color(hex: 0x7A5C16))
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background((hasPremiumAccess ? Color.organicPrimary : Color(hex: 0xD8B45D)).opacity(0.13))
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    HomeMembershipLimitPill(label: "AI Chat", value: hasPremiumAccess ? "Expanded" : "20/day")
                    HomeMembershipLimitPill(label: "Voice", value: hasPremiumAccess ? "300 min/mo" : "5 min/day")
                    HomeMembershipLimitPill(label: "Memory", value: hasPremiumAccess ? "On" : "Locked")
                }
            }
            .padding(15)
            .background(Color.organicCard.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder((hasPremiumAccess ? Color.organicPrimary : Color(hex: 0xD8B45D)).opacity(0.32), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasPremiumAccess ? "Manage Lumina Plus" : "Compare Free and Lumina Plus")
    }
}

private struct HomeMembershipLimitPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .luminaFont(size: 9, weight: .black)
                .foregroundColor(.organicMutedFg)
                .textCase(.uppercase)
                .kerning(0.7)
            Text(value)
                .luminaFont(size: 11, weight: .bold)
                .foregroundColor(.organicForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .frame(height: 46)
        .background(Color.organicMuted.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Still Open

private struct HomeStillOpenCard: View {
    let entries: [JournalEntry]
    let latestSession: ChatSession?
    let therapist: Therapist?
    let onOpenJournal: () -> Void
    let onNewReflection: () -> Void
    let onOpenTherapy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Still open")
                    .luminaFont(size: 18, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
                Spacer()
                Text("Optional")
                    .luminaFont(size: 10, weight: .black)
                    .foregroundColor(.organicMutedFg)
                    .textCase(.uppercase)
                    .kerning(1.0)
            }

            Text("A couple of threads you can return to when it helps.")
                .luminaFont(size: 12, weight: .medium)
                .foregroundColor(.organicMutedFg)

            VStack(spacing: 9) {
                let clues = activityRows
                if clues.isEmpty {
                    HomeOpenThreadRow(
                        icon: "leaf.fill",
                        tint: .organicPrimary,
                        title: "Nothing needs continuing",
                        subtitle: "You can start anywhere from the tabs below.",
                        actionTitle: "Leave it",
                        action: {}
                    )
                    .disabled(true)
                } else {
                    ForEach(clues) { clue in
                        HomeOpenThreadRow(
                            icon: clue.icon,
                            tint: clue.tint,
                            title: clue.title,
                            subtitle: clue.subtitle,
                            actionTitle: clue.actionTitle,
                            action: clue.action
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.54), lineWidth: 1)
        }
    }

    private var activityRows: [HomeOpenThread] {
        var rows: [HomeOpenThread] = []

        if let latestSession, let therapist {
            rows.append(
                HomeOpenThread(
                    icon: "bubble.left.fill",
                    tint: Color(hex: therapist.accentHex),
                    title: "Continue with \(therapist.name)",
                    subtitle: latestSession.lastMessagePreview.isEmpty ? "A recent therapy conversation is saved." : latestSession.lastMessagePreview,
                    actionTitle: "Continue",
                    action: onOpenTherapy
                )
            )
        }

        if let entry = entries.first {
            rows.append(
                HomeOpenThread(
                    icon: entry.mood.icon,
                    tint: entry.mood.timelineTint,
                    title: "Return to \(entry.title)",
                    subtitle: entry.summary ?? entry.reflection ?? entry.content,
                    actionTitle: "Review",
                    action: onOpenJournal
                )
            )
        } else if rows.isEmpty {
            rows.append(
                HomeOpenThread(
                    icon: "square.and.pencil",
                    tint: .organicPrimary,
                    title: "Leave one sentence",
                    subtitle: "A short reflection is enough if you want to mark today.",
                    actionTitle: "Write",
                    action: onNewReflection
                )
            )
        }

        return Array(rows.prefix(2))
    }
}

private struct HomeOpenThread: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void
}

private struct HomeOpenThreadRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: icon)
                        .luminaFont(size: 13, weight: .bold)
                        .foregroundColor(tint)
                        .frame(width: 34, height: 34)
                        .background(tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .luminaFont(size: 14, weight: .bold)
                            .foregroundColor(.organicForeground)
                            .lineLimit(1)
                        Text(subtitle.isEmpty ? "No summary yet." : subtitle)
                            .luminaFont(size: 12, weight: .medium)
                            .foregroundColor(.organicMutedFg)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 6)
                }

                Text(actionTitle)
                    .luminaFont(size: 12, weight: .medium)
                    .foregroundColor(tint)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(tint.opacity(0.10))
                    .clipShape(Capsule())
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.organicMuted.opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct HomeRecommendationCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let recommendation: HomeRecommendation
    @State private var showWhy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today’s starting point")
                    .luminaFont(size: 18, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
                Text("One suggested next step, not another menu.")
                    .luminaFont(size: 12, weight: .medium)
                    .foregroundColor(.organicMutedFg)
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: recommendation.icon)
                    .luminaFont(size: 16, weight: .semibold)
                    .foregroundColor(recommendation.tint)
                    .frame(width: 38, height: 38)
                    .background(recommendation.tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.eyebrow)
                        .luminaFont(size: 11, weight: .semibold)
                        .foregroundColor(.organicMutedFg)
                    Text(recommendation.title)
                        .luminaFont(size: 23, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                        .lineLimit(2)
                    Text(recommendation.message)
                        .luminaFont(size: 14, weight: .regular)
                        .foregroundColor(.organicMutedFg)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showWhy.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: showWhy ? "chevron.up" : "info.circle.fill")
                        .luminaFont(size: 11, weight: .semibold)
                    Text(showWhy ? "Hide" : "Reason")
                        .luminaFont(size: 12, weight: .semibold)
                }
                .foregroundColor(recommendation.tint)
            }
            .buttonStyle(.plain)

            if showWhy {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recommendation.reasons, id: \.self) { reason in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(recommendation.tint.opacity(0.64))
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            Text(reason)
                                .luminaFont(size: 11, weight: .regular)
                                .foregroundColor(.organicMutedFg)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colorScheme == .dark ? Color.organicMuted.opacity(0.96) : Color.organicMuted.opacity(0.58))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button(action: recommendation.action) {
                HStack(spacing: 8) {
                    Text(recommendation.actionTitle)
                    Image(systemName: "arrow.right")
                }
                    .luminaFont(size: 14, weight: .bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(recommendation.tint)
                    .foregroundColor(colorScheme == .dark ? .organicBackground : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)

            if recommendation.secondaryTitle != nil || recommendation.quietTitle != nil {
                HStack(spacing: 8) {
                    if let title = recommendation.secondaryTitle,
                       let action = recommendation.secondaryAction {
                        HomeRecommendationSecondaryButton(title: title, action: action)
                    }
                    if let title = recommendation.quietTitle,
                       let action = recommendation.quietAction {
                        HomeRecommendationSecondaryButton(title: title, action: action)
                    }
                }
            }
        }
        .padding(18)
        .background(colorScheme == .dark ? Color.organicElevated.opacity(0.98) : Color.organicCard.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(recommendation.tint.opacity(colorScheme == .dark ? 0.34 : 0.20), lineWidth: 1)
        }
    }
}

private struct HomeRecommendationSecondaryButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .luminaFont(size: 12, weight: .bold)
                .foregroundColor(colorScheme == .dark ? .organicForeground.opacity(0.88) : .organicMutedFg)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(colorScheme == .dark ? Color.organicMuted.opacity(0.98) : Color.organicMuted.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Follow-up

struct FollowUpCheckInCard: View {
    let followUp: FollowUp
    let onDone: () -> Void
    let onLater: () -> Void
    let onTooHard: () -> Void

    private var dueText: String {
        let remaining = followUp.dueAt - Date().timeIntervalSince1970
        if remaining <= 0 { return "Ready now" }
        if remaining < 3_600 { return "Later this hour" }
        if remaining < 86_400 { return "Later today" }
        return "Tomorrow"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .luminaFont(size: 16, weight: .semibold)
                    .foregroundColor(Color(hex: 0x7A5C16))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: 0xF7D58A).opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Tiny plan check-in")
                            .luminaFont(size: 17, weight: .bold, design: .serif)
                            .foregroundColor(.organicForeground)
                        Text(dueText)
                            .luminaFont(size: 10, weight: .bold)
                            .foregroundColor(Color(hex: 0x7A5C16))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(hex: 0xF7D58A).opacity(0.58))
                            .clipShape(Capsule())
                    }
                    Text(followUp.prompt)
                        .luminaFont(size: 12, weight: .semibold)
                        .foregroundColor(.organicMutedFg)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("If \(followUp.trigger)")
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(.organicMutedFg)
                    .lineLimit(2)
                Text("Then \(followUp.action)")
                    .luminaFont(size: 15, weight: .bold)
                    .foregroundColor(.organicForeground)
                    .lineLimit(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.organicMuted.opacity(0.64))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 8) {
                FollowUpActionButton(title: "Done", systemName: "checkmark", tint: .organicPrimary, action: onDone)
                FollowUpActionButton(title: "Later", systemName: "clock.fill", tint: Color(hex: 0x8B7A65), action: onLater)
                FollowUpActionButton(title: "Not today", systemName: "xmark", tint: Color(hex: 0x8B7A65), action: onTooHard)
            }
        }
        .padding(18)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color(hex: 0xE3C787).opacity(0.9), lineWidth: 1)
        }
        .shadow(color: Color(hex: 0x7A5C16).opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

private struct FollowUpActionButton: View {
    let title: String
    let systemName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemName)
                    .luminaFont(size: 11, weight: .bold)
                Text(title)
                    .luminaFont(size: 12, weight: .bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(tint.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Daily Check-In

private struct DailyCheckInCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let existingCheckIn: CheckInMetric?
    @Binding var moodScore: Double
    @Binding var stressScore: Double
    @Binding var note: String
    let onSave: () -> Void
    let onQuickSave: (Int, Int) -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 15 : 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: existingCheckIn == nil ? "slider.horizontal.3" : "checkmark")
                    .luminaFont(size: 14, weight: .semibold)
                    .foregroundColor(.organicPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.organicPrimary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(existingCheckIn == nil ? "Check in" : "Check-in saved")
                            .luminaFont(size: 16, weight: .bold, design: .serif)
                            .foregroundColor(.organicForeground)
                        if existingCheckIn != nil {
                            Text("Noted")
                                .luminaFont(size: 9, weight: .bold)
                                .foregroundColor(.organicPrimary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.organicPrimary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(isExpanded ? "Skip anything that does not feel useful." : compactSummary)
                        .luminaFont(size: 12, weight: .regular)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(2)
                }
                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "Close" : (existingCheckIn == nil ? "Open" : "Edit"))
                        .luminaFont(size: 12, weight: .semibold)
                        .foregroundColor(.organicPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.organicPrimary.opacity(0.10))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(spacing: 12) {
                    CheckInSliderRow(
                        title: "Mood",
                        value: $moodScore,
                        icon: "sun.max.fill",
                        tint: .organicSecondary
                    )
                    CheckInSliderRow(
                        title: "Stress",
                        value: $stressScore,
                        icon: "waveform.path.ecg",
                        tint: Color(hex: 0x8B7A65)
                    )
                }

                TextField("Add a note if you want", text: $note, axis: .vertical)
                    .luminaFont(size: 13, weight: .medium)
                    .lineLimit(1...3)
                    .padding(12)
                    .background(colorScheme == .dark ? Color.organicMuted.opacity(0.98) : Color.organicMuted.opacity(0.58))
                    .foregroundColor(.organicForeground)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                Button {
                    onSave()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded = false
                    }
                } label: {
                    Label(existingCheckIn == nil ? "Save check-in" : "Update check-in", systemImage: "checkmark")
                        .luminaFont(size: 13, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.organicPrimary)
                        .foregroundColor(.organicPrimaryFg)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if existingCheckIn == nil {
                HStack(spacing: 8) {
                    QuickCheckInButton(
                        title: "Okay",
                        subtitle: "steady enough",
                        icon: "checkmark",
                        tint: .organicPrimary,
                        action: { onQuickSave(6, 3) }
                    )
                    QuickCheckInButton(
                        title: "Heavy",
                        subtitle: "needs care",
                        icon: "cloud.fill",
                        tint: Color(hex: 0x8B7A65),
                        action: { onQuickSave(3, 7) }
                    )
                }
            } else {
                HStack(spacing: 8) {
                    CheckInStatusPill(title: "Mood", value: moodLabel, icon: "sun.max.fill", tint: .organicSecondary)
                    CheckInStatusPill(title: "Stress", value: stressLabel, icon: "waveform.path.ecg", tint: Color(hex: 0x8B7A65))
                }
            }
        }
        .padding(isExpanded ? 18 : 15)
        .background(colorScheme == .dark ? Color.organicElevated.opacity(0.98) : Color.organicCard.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 26 : 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: isExpanded ? 26 : 22, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(colorScheme == .dark ? 0.62 : 0.46), lineWidth: 1)
        }
    }

    private var compactSummary: String {
        if existingCheckIn != nil {
            return "Mood \(moodLabel) · Stress \(stressLabel)"
        }
        return "Mood and stress, only if useful."
    }

    private var moodLabel: String {
        label(forMoodScore: Int(moodScore.rounded()))
    }

    private var stressLabel: String {
        label(forStressScore: Int(stressScore.rounded()))
    }

    private func label(forMoodScore score: Int) -> String {
        switch score {
        case 0...2:
            return "Low"
        case 3...4:
            return "Tender"
        case 5...6:
            return "Steady"
        case 7...8:
            return "Lifted"
        default:
            return "Bright"
        }
    }

    private func label(forStressScore score: Int) -> String {
        switch score {
        case 0...2:
            return "Quiet"
        case 3...4:
            return "Light"
        case 5...6:
            return "Present"
        case 7...8:
            return "Heavy"
        default:
            return "Needs care"
        }
    }
}

private struct QuickCheckInButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .luminaFont(size: 11, weight: .bold)
                    .foregroundColor(tint)
                    .frame(width: 26, height: 26)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .luminaFont(size: 13, weight: .bold)
                        .foregroundColor(.organicForeground)
                    Text(subtitle)
                        .luminaFont(size: 10, weight: .semibold)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.organicMuted.opacity(0.50))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct CheckInStatusPill: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .luminaFont(size: 10, weight: .bold)
                .foregroundColor(tint)
            Text(title)
                .luminaFont(size: 10, weight: .black)
                .foregroundColor(.organicMutedFg)
                .textCase(.uppercase)
                .kerning(0.8)
            Text(value)
                .luminaFont(size: 12, weight: .bold)
                .foregroundColor(.organicForeground)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(tint.opacity(0.10))
        .clipShape(Capsule())
    }
}

private struct CheckInSliderRow: View {
    let title: String
    @Binding var value: Double
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .luminaFont(size: 11, weight: .semibold)
                    .foregroundColor(tint)
                    .frame(width: 22, height: 22)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())
                Text(title)
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(.organicForeground)
                Spacer()
                Text(valueLabel)
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(tint)
            }
            Slider(value: $value, in: 0...10, step: 1)
                .tint(tint)
        }
    }

    private var valueLabel: String {
        let score = Int(value.rounded())
        if title == "Mood" {
            switch score {
            case 0...2:
                return "Low"
            case 3...4:
                return "Tender"
            case 5...6:
                return "Steady"
            case 7...8:
                return "Lifted"
            default:
                return "Bright"
            }
        }

        switch score {
        case 0...2:
            return "Quiet"
        case 3...4:
            return "Light"
        case 5...6:
            return "Present"
        case 7...8:
            return "Heavy"
        default:
            return "Needs care"
        }
    }
}

// MARK: - Wellbeing Context

private struct WellbeingContextCard: View {
    let context: WellbeingContextSnapshot

    private var tint: Color {
        color(for: context.primarySignal?.tone)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .luminaFont(size: 15, weight: .semibold)
                    .foregroundColor(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Gentle context")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(.organicMutedFg)
                    Text(context.headline)
                        .luminaFont(size: 18, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            Text(context.summary)
                .luminaFont(size: 13, weight: .medium)
                .foregroundColor(.organicMutedFg)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("This stays as context only. You can ignore it anytime.")
                .luminaFont(size: 10, weight: .semibold)
                .foregroundColor(.organicMutedFg.opacity(0.85))
        }
        .padding(18)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: tint.opacity(0.07), radius: 14, x: 0, y: 8)
    }

    private func color(for tone: WellbeingSignalTone?) -> Color {
        switch tone {
        case .attention:
            return Color(hex: 0x8B7A65)
        case .recovery:
            return Color(hex: 0x4A90E2)
        case .progress:
            return Color(hex: 0x0F766E)
        case .steady, .none:
            return .organicPrimary
        }
    }

}

// MARK: - JITAI

private struct JITAIInsightCard: View {
    let decision: JITAIDecision
    let onAccept: () -> Void
    let onDismiss: () -> Void
    let onQuietToday: () -> Void

    @State private var showWhy = false

    private var tint: Color {
        switch decision.kind {
        case .recovery:
            return Color(hex: 0x4A90E2)
        case .movement, .garden:
            return Color(hex: 0x0F766E)
        case .reflection:
            return Color(hex: 0x7A5C16)
        case .grounding:
            return Color(hex: 0x8B7A65)
        }
    }

    private var icon: String {
        switch decision.kind {
        case .recovery:
            return "moon.zzz.fill"
        case .movement:
            return "figure.walk"
        case .reflection:
            return "square.and.pencil"
        case .grounding:
            return "wind"
        case .garden:
            return "leaf.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .luminaFont(size: 16, weight: .semibold)
                    .foregroundColor(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("A gentle option")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(.organicMutedFg)
                    Text(decision.title)
                        .luminaFont(size: 18, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .luminaFont(size: 10, weight: .bold)
                        .foregroundColor(.organicMutedFg)
                        .frame(width: 30, height: 30)
                        .background(Color.organicMuted.opacity(0.72))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss suggestion")
            }

            Text(decision.message)
                .luminaFont(size: 13, weight: .medium)
                .foregroundColor(.organicMutedFg)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showWhy.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showWhy ? "chevron.up" : "chevron.down")
                        .luminaFont(size: 10, weight: .bold)
                    Text("Why this might help")
                        .luminaFont(size: 12, weight: .bold)
                }
                .foregroundColor(tint)
            }
            .buttonStyle(.plain)

            if showWhy {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Based on a few recent signals.")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(.organicForeground)
                    ForEach(decision.reasonCodes, id: \.self) { code in
                        HStack(alignment: .top, spacing: 7) {
                            Circle()
                                .fill(tint.opacity(0.62))
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            Text(reasonText(for: code))
                                .luminaFont(size: 11, weight: .medium)
                                .foregroundColor(.organicMutedFg)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.organicMuted.opacity(0.56))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(spacing: 8) {
                Button(action: onAccept) {
                    Label(decision.actionTitle, systemImage: "arrow.right")
                        .luminaFont(size: 13, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(tint.opacity(0.14))
                        .foregroundColor(tint)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onQuietToday) {
                    Text("Quiet today")
                        .luminaFont(size: 12, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.organicMuted)
                        .foregroundColor(.organicMutedFg)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(tint.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: tint.opacity(0.08), radius: 14, x: 0, y: 8)
    }

    private func reasonText(for code: String) -> String {
        switch code {
        case "checkin.stress.high":
            return "Your check-in suggests today may feel a little heavier."
        case "checkin.mood.low":
            return "Your mood check-in leaned lower today."
        case "context.self_report":
            return "Your own check-ins matter most here."
        case "journal.anxiety.high":
            return "Your latest reflection sounded more tense."
        case "intervention.grounding":
            return "Grounding keeps the next step small."
        case "health.sleep.below_personal_range":
            return "Rest may be lower than usual."
        case "intervention.recovery":
            return "Recovery can be enough for now."
        case "health.steps.below_personal_range":
            return "Movement may have been lighter than usual."
        case "garden.tiny_action":
            return "A tiny Garden action keeps things simple."
        case "journal.no_entry_today":
            return "A short note can be enough today."
        case "intervention.journaling_prompt":
            return "A short prompt keeps this light."
        case "garden.open_habit":
            return "One small Garden step is available."
        case "behavior.small_step":
            return "Small steps are easier to return to."
        default:
            return code.replacingOccurrences(of: ".", with: " ")
        }
    }
}

// MARK: - Focus

private struct TodayFocusPanel: View {
    let latestEntry: JournalEntry?
    let nextHabit: Habit?
    let onNewReflection: () -> Void
    let onOpenGarden: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("For now")
                        .luminaFont(size: 17, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                    Text(latestEntry?.actionItem ?? nextHabit?.description ?? "Write one honest sentence, then let that be enough.")
                        .luminaFont(size: 13, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .lineSpacing(3)
                        .lineLimit(3)
                }
                Spacer(minLength: 14)
                Image(systemName: latestEntry?.mood.icon ?? "sparkles")
                    .luminaFont(size: 18, weight: .bold)
                    .foregroundColor(.organicSecondary)
                    .frame(width: 42, height: 42)
                    .background(Color.organicSecondary.opacity(0.12))
                    .clipShape(Circle())
            }

            if let nextHabit {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Small garden step")
                            .luminaFont(size: 11, weight: .bold)
                            .foregroundColor(.organicMutedFg)
                        Spacer()
                    }
                    Text(nextHabit.title)
                        .luminaFont(size: 14, weight: .bold)
                        .foregroundColor(.organicForeground)
                        .lineLimit(2)
                    Text("One small step is available when you want it.")
                        .luminaFont(size: 12, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 10) {
                Button(action: onNewReflection) {
                    Label("Write a little", systemImage: "plus")
                        .luminaFont(size: 13, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.organicPrimary)
                        .foregroundColor(.organicPrimaryFg)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onOpenGarden) {
                    Label("Open garden", systemImage: "leaf.fill")
                        .luminaFont(size: 13, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.organicMuted)
                        .foregroundColor(.organicForeground)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.6), lineWidth: 1)
        }
    }
}

// MARK: - Wellness

private struct WellnessSummaryPanel: View {
    let chartData: [(day: String, score: Int, energy: Int, anxiety: Int)]
    let averageSentiment: Int

    private var rhythmLabel: String {
        switch averageSentiment {
        case 72...:
            return "Bright"
        case 56..<72:
            return "Steady"
        case 40..<56:
            return "Tender"
        default:
            return "Low"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reflection rhythm")
                        .luminaFont(size: 17, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                    Text(chartData.count > 1 ? "A soft look at recent entries" : "Add reflections when it feels useful")
                        .luminaFont(size: 12, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                }
                Spacer()
                Text(rhythmLabel)
                    .luminaFont(size: 14, weight: .bold)
                    .foregroundColor(.organicPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.organicPrimary.opacity(0.10))
                    .clipShape(Capsule())
            }

            if chartData.count > 1 {
                Chart {
                    ForEach(chartData, id: \.day) { point in
                        AreaMark(
                            x: .value("Day", point.day),
                            y: .value("Wellness", point.score)
                        )
                        .foregroundStyle(Color.organicPrimary.opacity(0.18))

                        LineMark(
                            x: .value("Day", point.day),
                            y: .value("Wellness", point.score)
                        )
                        .foregroundStyle(Color.organicPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                        LineMark(
                            x: .value("Day", point.day),
                            y: .value("Energy", point.energy)
                        )
                        .foregroundStyle(Color.organicSecondary)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }
                }
                .frame(height: 146)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.organicMutedFg)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "chart.xyaxis.line")
                        .luminaFont(size: 22, weight: .bold)
                        .foregroundColor(.organicPrimary)
                    Text("A few reflections can make the pattern easier to see.")
                        .luminaFont(size: 13, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                }
                .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
            }

            HStack(spacing: 12) {
                ChartLegendDot(label: "Wellness", color: .organicPrimary)
                ChartLegendDot(label: "Energy", color: .organicSecondary)
                Spacer()
            }
        }
        .padding(20)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.6), lineWidth: 1)
        }
    }
}

private struct ChartLegendDot: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .luminaFont(size: 11, weight: .bold)
                .foregroundColor(.organicMutedFg)
        }
    }
}

// MARK: - Support

private struct SupportTeamPreview: View {
    let therapists: [Therapist]
    let onOpenTherapist: (Therapist) -> Void
    let onViewAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Support team")
                        .luminaFont(size: 17, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                    Text("Start with the guide that fits this moment.")
                        .luminaFont(size: 12, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                }
                Spacer()
                Button(action: onViewAll) {
                    Text("View all")
                        .luminaFont(size: 12, weight: .black)
                        .foregroundColor(.organicPrimary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                ForEach(therapists) { therapist in
                    SupportTherapistRow(therapist: therapist) {
                        onOpenTherapist(therapist)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.organicMuted.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct SupportTherapistRow: View {
    let therapist: Therapist
    let action: () -> Void
    private var accent: Color { Color(hex: therapist.accentHex) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                TherapistAvatarMark(
                    name: therapist.name,
                    accent: accent,
                    size: 48,
                    radius: 18
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(therapist.name)
                        .luminaFont(size: 15, weight: .bold)
                        .foregroundColor(.organicForeground)
                    Text(therapist.role.uppercased())
                        .luminaFont(size: 9, weight: .black)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(1)
                    Text(therapist.description)
                        .luminaFont(size: 11, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "message.fill")
                    .luminaFont(size: 13, weight: .bold)
                    .foregroundColor(accent)
                    .frame(width: 34, height: 34)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(14)
            .background(Color.organicCard)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.organicBorder.opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Home Journal Preview

private struct RecentReflectionPreview: View {
    let entries: [JournalEntry]
    let onOpenJournal: () -> Void
    let onNewReflection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Recent reflections")
                        .luminaFont(size: 17, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                    Text(entries.isEmpty ? "Start with one honest sentence." : "A quick look at your latest entries.")
                        .luminaFont(size: 12, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                }
                Spacer()
                Button(action: onOpenJournal) {
                    Text("Open")
                        .luminaFont(size: 12, weight: .black)
                        .foregroundColor(.organicPrimary)
                }
                .buttonStyle(.plain)
            }

            if entries.isEmpty {
                Button(action: onNewReflection) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .luminaFont(size: 14, weight: .bold)
                            .foregroundColor(.organicPrimary)
                            .frame(width: 34, height: 34)
                            .background(Color.organicPrimary.opacity(0.12))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Capture a Thought")
                                .luminaFont(size: 15, weight: .bold, design: .serif)
                                .foregroundColor(.organicForeground)
                            Text("Your journal will live in the Journal tab.")
                                .luminaFont(size: 12, weight: .medium)
                                .foregroundColor(.organicMutedFg)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.organicCard)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 10) {
                    ForEach(entries) { entry in
                        HomeReflectionRow(entry: entry)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.6), lineWidth: 1)
        }
    }
}

private struct HomeReflectionRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.mood.icon)
                .luminaFont(size: 14, weight: .bold)
                .foregroundColor(.organicSecondary)
                .frame(width: 34, height: 34)
                .background(Color.organicSecondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.title)
                        .luminaFont(size: 14, weight: .bold)
                        .foregroundColor(.organicForeground)
                        .lineLimit(1)
                    Spacer()
                    Text(entry.date.uppercased())
                        .luminaFont(size: 9, weight: .black)
                        .foregroundColor(.organicMutedFg)
                }
                Text(entry.content)
                    .luminaFont(size: 12, weight: .medium)
                    .foregroundColor(.organicMutedFg)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(Color.organicMuted.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Journal Root

struct JournalRootView: View {
    @State private var selectedSection: JournalSection = .timeline
    @State private var showingEditor = false
    @State private var editingEntry: JournalEntry? = nil

    enum JournalSection: String, CaseIterable {
        case timeline = "Timeline"
        case insights = "Insights"

        var icon: String {
            switch self {
            case .timeline: return "scroll.fill"
            case .insights: return "chart.line.uptrend.xyaxis"
            }
        }
    }

    var body: some View {
        ZStack {
            JournalRootBackdrop().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    JournalHeaderView(
                        onNewReflection: {
                            editingEntry = nil
                            showingEditor = true
                        }
                    )

                    JournalSectionPicker(selectedSection: $selectedSection)

                    switch selectedSection {
                    case .timeline:
                        TimelineTabView(showingEditor: $showingEditor, editingEntry: $editingEntry)
                    case .insights:
                        InsightsTabView()
                    }

                    Spacer(minLength: 118)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 118)
            }
        }
        .sheet(isPresented: $showingEditor) {
            JournalEditorView(editingEntry: editingEntry)
        }
    }
}

private struct JournalHeaderView: View {
    let onNewReflection: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("REFLECTION JOURNAL")
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(.organicMutedFg)
                    .kerning(3.2)
                    .textCase(.uppercase)
                Text("Journal")
                    .luminaFont(size: 31, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
            }

            Spacer(minLength: 12)

            Button(action: onNewReflection) {
                    Image(systemName: "plus")
                        .luminaFont(size: 15, weight: .black)
                    .foregroundColor(.organicPrimaryFg)
                    .frame(width: 44, height: 44)
                    .background(Color.organicPrimary)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.organicBorder.opacity(0.72), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New reflection")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct JournalSectionPicker: View {
    @Binding var selectedSection: JournalRootView.JournalSection

    var body: some View {
        HStack(spacing: 6) {
            ForEach(JournalRootView.JournalSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.icon)
                            .luminaFont(size: 11, weight: .bold)
                        Text(section.rawValue)
                            .luminaFont(size: 12, weight: .bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(selectedSection == section ? .organicPrimaryFg : .organicMutedFg)
                    .background(selectedSection == section ? Color.organicPrimary : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(Color.organicCard)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.organicBorder.opacity(0.72), lineWidth: 1)
        }
    }
}

private struct JournalRootBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.organicBackground

            RadialGradient(
                colors: [
                    Color.organicPrimary.opacity(colorScheme == .dark ? 0.20 : 0.14),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    Color.organicSecondary.opacity(colorScheme == .dark ? 0.12 : 0.14),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 420
            )

            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.organicBackground.opacity(0.40), Color.organicBackdrop]
                    : [Color.organicBackground.opacity(0.20), Color.organicMuted.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
