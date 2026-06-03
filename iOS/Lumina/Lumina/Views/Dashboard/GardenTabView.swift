import SwiftUI
import UIKit

// MARK: - Garden Tab

private enum GardenFirstVisitGuideStorage {
    static let completionKey = "lumina.garden.hasCompletedFirstVisitGuide.v1"
}

private enum GardenFirstVisitGuideStep: Int, CaseIterable, Identifiable {
    case world
    case traces
    case shelf

    var id: Int { rawValue }

    var stepText: String {
        "\(rawValue + 1)/\(Self.allCases.count)"
    }

    var title: String {
        switch self {
        case .world:
            return "Garden is a memory scene"
        case .traces:
            return "Tap visible traces"
        case .shelf:
            return "Use the shelf for details"
        }
    }

    var detail: String {
        switch self {
        case .world:
            return "This is not a task board. Journal, Therapy, Sanctuary, and check-ins can leave visible traces here over time."
        case .traces:
            return "Dew, stones, visitors, and the keeper can be opened. Tap one to look closer, or leave it alone."
        case .shelf:
            return "The bottom shelf keeps recent traces and optional returns in one place. Open it only when you want context."
        }
    }

    var focusLabel: String {
        switch self {
        case .world:
            return "Look around the grove"
        case .traces:
            return "Tap glowing or placed objects"
        case .shelf:
            return "Open the bottom shelf"
        }
    }

    var systemImage: String {
        switch self {
        case .world: return "leaf.fill"
        case .traces: return "hand.tap.fill"
        case .shelf: return "tray.full.fill"
        }
    }

    var tint: Color {
        switch self {
        case .world: return Color(hex: 0x6D8B5F)
        case .traces: return Color(hex: 0xD99A32)
        case .shelf: return Color(hex: 0x7893C4)
        }
    }

    var focusAnchor: CGPoint {
        switch self {
        case .world: return CGPoint(x: 0.50, y: 0.27)
        case .traces: return CGPoint(x: 0.50, y: 0.34)
        case .shelf: return CGPoint(x: 0.50, y: 0.70)
        }
    }

    var focusSize: CGSize {
        switch self {
        case .world: return CGSize(width: 270, height: 118)
        case .traces: return CGSize(width: 292, height: 132)
        case .shelf: return CGSize(width: 226, height: 64)
        }
    }

    var focusCornerRadius: CGFloat {
        switch self {
        case .world: return 48
        case .traces: return 56
        case .shelf: return 34
        }
    }

    var primaryActionTitle: String {
        next == nil ? "Enter Garden" : "Next"
    }

    var placesCardAtTop: Bool {
        self == .shelf
    }

    var next: GardenFirstVisitGuideStep? {
        Self(rawValue: rawValue + 1)
    }

    var previous: GardenFirstVisitGuideStep? {
        Self(rawValue: rawValue - 1)
    }
}

struct GardenTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WelcomeGuideStorage.completionKey) private var hasCompletedWelcomeGuide = false
    @AppStorage(GardenFirstVisitGuideStorage.completionKey) private var hasCompletedGardenFirstVisitGuide = false
    @State private var selectedTool: GardenTool = .explore
    @State private var selectedArrangementType: GardenDecorationType = .lamp
    @State private var selectedHabitID: String?
    @State private var showingMemoryShelf = false
    @State private var hasScheduledGardenFirstVisitGuide = false
    @State private var showingGardenFirstVisitGuide = false
    @State private var gardenFirstVisitGuideStep: GardenFirstVisitGuideStep = .world
    @State private var gardenToast: GardenToast?
    @State private var recentlyWateredHabitID: String?
    @State private var avatarPosition = CGPoint(x: 0.50, y: 0.62)
    @State private var keeperIsWalking = false
    @State private var keeperFacesLeft = false
    @State private var keeperMoveToken = UUID()
    @State private var keeperRoamIndex = 0
    @State private var keeperAmbientMood: GardenKeeperMood = .idle
    @State private var focusedHabitID: String?
    @State private var selectedVisitorInvitationID: String?
    @State private var selectedAreaUnlockID: String?
    @State private var areaDewBurst: GardenAreaDewBurst?

    private var completedHabitIDsToday: Set<String> {
        Set(appState.habits.filter { appState.isGardenHabitCompletedToday($0) }.map(\.id))
    }

    private var completedCount: Int {
        completedHabitIDsToday.count
    }

    private var averageGrowth: Int {
        guard !appState.habits.isEmpty else { return 0 }
        return appState.habits.reduce(0) { $0 + $1.growth } / appState.habits.count
    }

    private var completedTherapyPlanCount: Int {
        appState.habits.filter { $0.sourceMicroPlanID != nil && appState.isGardenHabitCompletedToday($0) }.count
    }

    private var gatheredForageToday: Int {
        let dayKey = GardenForageItem.dayKey(for: Date())
        return appState.gardenForageItems.filter { $0.dayKey == dayKey && $0.isGathered }.count
    }

    private var completedAreaKindsToday: Set<GardenMapAreaKind> {
        let dayKey = GardenForageItem.dayKey(for: Date())
        return Set(appState.gardenAreaVisits.filter { $0.dayKey == dayKey }.map(\.area))
    }

    private var areaVisitCounts: [GardenMapAreaKind: Int] {
        Dictionary(grouping: appState.gardenAreaVisits, by: \.area)
            .mapValues(\.count)
    }

    private var areaMilestoneStages: [GardenMapAreaKind: Set<Int>] {
        Dictionary(grouping: appState.gardenAreaMilestones, by: \.area)
            .mapValues { Set($0.map(\.stage)) }
    }

    private var gardenMemoryDepth: Int {
        let areaStageCount = areaMilestoneStages.values.reduce(0) { $0 + $1.count }
        let areaReturnCount = areaVisitCounts.values.reduce(0, +) / 3
        return appState.habits.count + appState.gardenKeepsakes.count + areaStageCount + areaReturnCount
    }

    private var gardenAtmosphere: GardenAtmosphereKind {
        GardenAtmosphereKind.resolve(
            checkIn: appState.todayCheckIn,
            memoryDepth: gardenMemoryDepth,
            readyTraceCount: readyTracePromptCount,
            hour: Calendar.current.component(.hour, from: Date())
        )
    }

    private var areaLogEntries: [GardenAreaLogEntry] {
        GardenAreaLogEntry.entries(
            unlockedAreas: appState.gardenUnlockedAreas,
            visits: appState.gardenAreaVisits,
            milestones: appState.gardenAreaMilestones
        )
    }

    private var starterSeeds: [GardenStarterSeed] {
        GardenStarterSeed.defaults.filter { seed in
            !appState.habits.contains { $0.title.caseInsensitiveCompare(seed.title) == .orderedSame }
        }
    }

    private var gardenTracePrompts: [GardenTracePrompt] {
        let forageDayKey = GardenForageItem.dayKey(for: Date())
        var prompts = [
            GardenTracePrompt(
                id: "gather-dew-\(forageDayKey)",
                title: "Morning dew",
                detail: "Notice a few soft dew drops already resting around the grove.",
                progress: min(gatheredForageToday, 3),
                goal: 3,
                dewAmount: 2,
                systemImage: "sparkles"
            ),
            GardenTracePrompt(
                id: "tend-two",
                title: "Two traces noticed",
                detail: "If two small returns already happened, the shelf can remember them.",
                progress: min(completedCount, 2),
                goal: 2,
                dewAmount: 2,
                systemImage: "checkmark.seal.fill"
            ),
            GardenTracePrompt(
                id: "grow-grove",
                title: "A rooted patch",
                detail: "When the grove feels more settled, a small marker can stay.",
                progress: min(averageGrowth, 60),
                goal: 60,
                dewAmount: 2,
                systemImage: "leaf.fill"
            ),
        ]
        if !appState.therapyMicroPlans.isEmpty {
            prompts.insert(
                GardenTracePrompt(
                    id: "try-therapy-plan",
                    title: "Therapy trace noticed",
                    detail: "A tiny plan from Therapy has had room to be tried.",
                    progress: min(completedTherapyPlanCount, 1),
                    goal: 1,
                    dewAmount: 3,
                    systemImage: "sparkles"
                ),
                at: 0
            )
        }
        if appState.habits.isEmpty || !appState.keptGardenPromptIDs.contains("plant-first-seed") {
            prompts.insert(
                GardenTracePrompt(
                    id: "plant-first-seed",
                    title: "First trace",
                    detail: "Choose or save one small practice only if it helps.",
                    progress: appState.habits.isEmpty ? 0 : 1,
                    goal: 1,
                    dewAmount: 1,
                    systemImage: "leaf.fill"
                ),
                at: 0
            )
        }
        return prompts
    }

    private var readyTracePromptCount: Int {
        gardenTracePrompts.filter { prompt in
            prompt.isComplete && !appState.keptGardenPromptIDs.contains(prompt.id)
        }.count
    }

    private var todaysVisitorInvitation: GardenVisitorInvitation? {
        let dayKey = GardenForageItem.dayKey(for: Date())
        return appState.gardenVisitorInvitations.first { $0.dayKey == dayKey }
    }

    private var gardenRhythmStages: [GardenRhythmStage] {
        let hasRoutine = !appState.habits.isEmpty
        let routineProgress = hasRoutine ? min(completedCount, 1) : 0
        let invitation = todaysVisitorInvitation
        let visitorGoal = max(invitation?.targetCount ?? 1, 1)
        let visitorProgress = invitation?.isCompleted == true
            ? visitorGoal
            : min(invitation.map { visitorInvitationProgress(for: $0) } ?? 0, visitorGoal)

        return [
            GardenRhythmStage(
                id: "routine",
                title: hasRoutine ? "Touch" : "Begin",
                detail: hasRoutine ? "One trace" : "First trace",
                progress: routineProgress,
                goal: 1,
                systemImage: hasRoutine ? "checkmark.seal.fill" : "leaf.fill",
                tint: Color(hex: 0x5FA461)
            ),
            GardenRhythmStage(
                id: "dew",
                title: "Dew",
                detail: "Hidden dew",
                progress: min(gatheredForageToday, 3),
                goal: 3,
                systemImage: "drop.fill",
                tint: Color(hex: 0x309FD2)
            ),
            GardenRhythmStage(
                id: "visitor",
                title: invitation?.visitor.displayName ?? "Visitor",
                detail: invitation?.isCompleted == true ? "A change is ready" : "Visitor note",
                progress: visitorProgress,
                goal: visitorGoal,
                systemImage: invitation?.isCompleted == true ? "sparkles" : "person.crop.circle.badge.questionmark",
                tint: invitation?.visitor.accent ?? Color(hex: 0xD99A32)
            )
        ]
    }

    private var gardenNextMove: GardenNextMove {
        if appState.habits.isEmpty {
            return GardenNextMove(
                title: "Save one small trace",
                detail: "Write, talk, or choose a tiny practice to begin the grove.",
                systemImage: "leaf.fill",
                tint: Color(hex: 0x6D8B5F)
            )
        }

        if readyTracePromptCount > 0 {
            return GardenNextMove(
                title: "See what changed",
                detail: "The grove kept a small visible change.",
                systemImage: "sparkles",
                tint: Color(hex: 0x6D8B5F)
            )
        }

        if let invitation = appState.activeGardenVisitorInvitation {
            if !invitation.isAccepted {
                return GardenNextMove(
                    title: "Meet \(invitation.visitor.displayName)",
                    detail: "A visitor is carrying a small invitation.",
                    systemImage: "person.crop.circle.badge.questionmark",
                    tint: invitation.visitor.accent
                )
            }

            let progress = visitorInvitationProgress(for: invitation)
            if progress >= invitation.targetCount {
                return GardenNextMove(
                    title: "Notice \(invitation.visitor.displayName)'s change",
                    detail: "A small marker is ready to be placed.",
                    systemImage: "sparkles",
                    tint: invitation.visitor.accent
                )
            }

            return GardenNextMove(
                title: invitation.invitationKind.title,
                detail: "\(min(progress, invitation.targetCount))/\(invitation.targetCount) with \(invitation.visitor.displayName).",
                systemImage: invitation.invitationKind.systemImage,
                tint: invitation.visitor.accent
            )
        }

        if completedCount == 0, let nextHabit = appState.habits.first(where: { !completedHabitIDsToday.contains($0.id) }) {
            return GardenNextMove(
                title: "Touch one visible trace",
                detail: nextHabit.title,
                systemImage: "checkmark.seal.fill",
                tint: Color(hex: 0x5FA461)
            )
        }

        if gatheredForageToday < 3 {
            return GardenNextMove(
                title: "Find a little dew",
                detail: "\(gatheredForageToday)/3 found. Optional, only if it feels easy.",
                systemImage: "drop.fill",
                tint: Color(hex: 0x309FD2)
            )
        }

        if let area = appState.gardenUnlockedAreas.first(where: { !completedAreaKindsToday.contains($0.area) })?.area {
            return GardenNextMove(
                title: area.actionTitle,
                detail: "Open \(area.title) for a small visible change.",
                systemImage: area.icon,
                tint: area.tint
            )
        }

        return GardenNextMove(
            title: "Grove is steady",
            detail: "You can open a corner, gather dew, or leave the rest for later.",
            systemImage: "leaf.fill",
            tint: Color(hex: 0x6D8B5F)
        )
    }

    private var selectedHabit: Habit? {
        guard let selectedHabitID else { return nil }
        return appState.habits.first { $0.id == selectedHabitID }
    }

    private var selectedHabitDisplayIndex: Int {
        guard let selectedHabitID else { return 0 }
        return appState.habits.firstIndex { $0.id == selectedHabitID } ?? 0
    }

    private var selectedHabitJournalEntry: JournalEntry? {
        guard let journalID = selectedHabit?.sourceJournalEntryID else { return nil }
        return appState.entries.first { $0.id == journalID }
    }

    private var selectedHabitMicroPlan: MicroPlan? {
        guard let microPlanID = selectedHabit?.sourceMicroPlanID else { return nil }
        return appState.therapyMicroPlans.first { $0.id == microPlanID }
    }

    private var selectedVisitorInvitation: GardenVisitorInvitation? {
        guard let selectedVisitorInvitationID else { return nil }
        return appState.gardenVisitorInvitations.first { $0.id == selectedVisitorInvitationID }
    }

    private var selectedAreaUnlock: GardenMapAreaUnlock? {
        guard let selectedAreaUnlockID else { return nil }
        return appState.gardenUnlockedAreas.first { $0.id == selectedAreaUnlockID }
    }

    private var showingHabitDetail: Binding<Bool> {
        Binding(
            get: { selectedHabitID != nil },
            set: { if !$0 { selectedHabitID = nil } }
        )
    }

    private var showingVisitorInvitationDetail: Binding<Bool> {
        Binding(
            get: { selectedVisitorInvitationID != nil },
            set: { if !$0 { selectedVisitorInvitationID = nil } }
        )
    }

    private var showingAreaDetail: Binding<Bool> {
        Binding(
            get: { selectedAreaUnlockID != nil },
            set: { if !$0 { selectedAreaUnlockID = nil } }
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let atmosphere = gardenAtmosphere
            ZStack {
                GardenGameBackdrop(atmosphere: atmosphere)

                    GardenWorldScene(
                        habits: appState.habits,
                        waterDrops: appState.waterDrops,
                        selectedTool: selectedTool,
                        readyTracePromptCount: readyTracePromptCount,
                        completedHabitIDsToday: completedHabitIDsToday,
                        isSceneActive: appState.selectedTab == LuminaRootTab.garden.rawValue,
                        avatarPosition: avatarPosition,
                        keeperIsWalking: keeperIsWalking,
                        keeperFacesLeft: keeperFacesLeft,
                        keeperAmbientMood: keeperAmbientMood,
                        focusedHabitID: focusedHabitID,
                        decorations: appState.gardenDecorations,
                        forageItems: appState.gardenForageItems.filter { !$0.isGathered },
                        keepsakes: appState.gardenKeepsakes,
                        unlockedAreas: appState.gardenUnlockedAreas,
                        completedAreaKindsToday: completedAreaKindsToday,
                        areaVisitCounts: areaVisitCounts,
                        areaMilestoneStages: areaMilestoneStages,
                        visitorInvitation: appState.activeGardenVisitorInvitation,
                        visitorInvitationProgress: appState.activeGardenVisitorInvitation.map(visitorInvitationProgress(for:)) ?? 0,
                        recentlyWateredHabitID: recentlyWateredHabitID,
                        onBoardTap: { showingMemoryShelf = true },
                        onWateringCanTap: activateWateringCan,
                        onForageTap: handleForageTap,
                        onAreaTap: handleAreaTap,
                        onVisitorTap: handleVisitorTap,
                        onPlotTap: handlePlotTap
                    )

                    GardenSceneAtmosphereLayer(
                        traceCount: appState.habits.count,
                        memoryDepth: gardenMemoryDepth,
                        atmosphere: atmosphere
                    )
                        .allowsHitTesting(false)

                VStack(spacing: 0) {
                    GardenMemoryHeader(
                        traceCount: appState.habits.count,
                        quietCount: appState.gardenKeepsakes.count,
                        atmosphere: atmosphere,
                        onOpenBoard: { showingMemoryShelf = true }
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                    Spacer(minLength: 0)

                    if let gardenToast {
                        GardenToastView(toast: gardenToast)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 10)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if !showingGardenFirstVisitGuide || gardenFirstVisitGuideStep == .shelf {
                        GardenMemoryWhisperBar(
                            totalCount: appState.habits.count,
                            onOpenBoard: { showingMemoryShelf = true }
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(86, proxy.safeAreaInsets.bottom + 68))
                        .opacity(showingGardenFirstVisitGuide ? 0.82 : 1)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                if let areaDewBurst {
                    GardenAreaDewBurstView(burst: areaDewBurst)
                        .frame(width: 150, height: 96)
                        .position(
                            x: proxy.size.width * CGFloat(areaDewBurst.area.mapPosition.x),
                            y: proxy.size.height * CGFloat(areaDewBurst.area.mapPosition.y)
                        )
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }

                if showingGardenFirstVisitGuide {
                    GardenFirstVisitGuideOverlay(
                        step: gardenFirstVisitGuideStep,
                        onBack: goBackGardenFirstVisitGuide,
                        onNext: advanceGardenFirstVisitGuide,
                        onSkip: finishGardenFirstVisitGuide
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
        }
        .onAppear {
            appState.refreshGardenForage()
            appState.refreshGardenVisitorInvitation()
            scheduleGardenFirstVisitGuideIfNeeded()
        }
        .task {
            scheduleGardenFirstVisitGuideIfNeeded()
        }
        .onReceive(Timer.publish(every: gardenKeeperRoamInterval, on: .main, in: .common).autoconnect()) { _ in
            roamKeeperIfIdle()
        }
        .onReceive(Timer.publish(every: gardenKeeperAmbientMoodInterval, on: .main, in: .common).autoconnect()) { _ in
            advanceKeeperAmbientMood()
        }
        .onChange(of: appState.selectedTab) { selectedTab in
            if selectedTab == LuminaRootTab.garden.rawValue {
                scheduleGardenFirstVisitGuideIfNeeded()
            }
        }
        .onChange(of: hasCompletedWelcomeGuide) { didComplete in
            guard didComplete else { return }
            scheduleGardenFirstVisitGuideIfNeeded()
        }
        .onChange(of: hasCompletedGardenFirstVisitGuide) { didComplete in
            guard !didComplete else { return }
            hasScheduledGardenFirstVisitGuide = false
            scheduleGardenFirstVisitGuideIfNeeded()
        }
        .sheet(isPresented: showingHabitDetail) {
            if let habit = selectedHabit {
                GardenHabitDetailSheet(
                    habit: habit,
                    displayIndex: selectedHabitDisplayIndex,
                    sourceEntry: selectedHabitJournalEntry,
                    sourceMicroPlan: selectedHabitMicroPlan,
                    isCompletedToday: appState.isGardenHabitCompletedToday(habit),
                    waterDrops: appState.waterDrops,
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            appState.completeHabit(id: habit.id)
                        }
                    },
                    onWater: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            appState.waterPlant(id: habit.id)
                        }
                    }
                )
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingMemoryShelf) {
            GardenMemoryShelfSheet(
                habits: appState.habits,
                waterDrops: appState.waterDrops,
                completedHabitIDsToday: completedHabitIDsToday,
                prompts: gardenTracePrompts,
                keptPromptIDs: appState.keptGardenPromptIDs,
                gardenRhythmStages: gardenRhythmStages,
                nextMove: gardenNextMove,
                readyTracePromptCount: readyTracePromptCount,
                areaLogs: areaLogEntries,
                starterSeeds: starterSeeds,
                followUp: appState.activeFollowUp,
                onSelect: { habit in
                    showingMemoryShelf = false
                    selectedHabitID = habit.id
                },
                onSelectArea: { area in
                    if let unlock = appState.gardenUnlockedAreas.first(where: { $0.area == area }) {
                        showingMemoryShelf = false
                        selectedAreaUnlockID = unlock.id
                    }
                },
                onComplete: { habit in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        appState.completeHabit(id: habit.id)
                    }
                },
                onPlantStarter: plantStarterSeed,
                onTouchPrompt: touchGardenTracePrompt,
                onCompleteFollowUp: { followUp in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        _ = appState.recordFollowUp(id: followUp.id, status: .completed)
                    }
                },
                onSnoozeFollowUp: { followUp in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        _ = appState.snoozeFollowUp(id: followUp.id)
                    }
                },
                onMarkFollowUpTooHard: { followUp in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        _ = appState.recordFollowUp(id: followUp.id, status: .tooHard)
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: showingVisitorInvitationDetail) {
            if let invitation = selectedVisitorInvitation {
                GardenVisitorInvitationSheet(
                    invitation: invitation,
                    progress: visitorInvitationProgress(for: invitation),
                    onAccept: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            _ = appState.acceptGardenVisitorInvitation(id: invitation.id)
                        }
                    },
                    onSettleGift: {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            if let completedInvitation = appState.settleGardenVisitorInvitation(
                                id: invitation.id,
                                progress: visitorInvitationProgress(for: invitation)
                            ) {
                                selectedVisitorInvitationID = nil
                                showToast(
                                    title: "Visitor gift placed",
                                    detail: "\(GardenMapAreaKind.area(for: GardenKeepsakeKind.keepsake(for: completedInvitation.visitor)).title) opened softly.",
                                    icon: "gift.fill",
                                    tint: Color(hex: 0xD99A32)
                                )
                            }
                        }
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            _ = appState.dismissGardenVisitorInvitation(id: invitation.id)
                            selectedVisitorInvitationID = nil
                        }
                    }
                )
                .presentationDetents([.height(560), .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: showingAreaDetail) {
            if let unlock = selectedAreaUnlock {
                GardenAreaSheet(
                    unlock: unlock,
                    visit: areaVisitToday(for: unlock.area),
                    visitCount: areaVisitCount(for: unlock.area),
                    unlockedMilestones: areaMilestones(for: unlock.area),
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            if let result = appState.completeGardenMapAreaVisit(area: unlock.area) {
                                selectedAreaUnlockID = nil
                                showAreaDewBurst(area: unlock.area, amount: result.totalDewAmount)
                                let milestoneText = result.unlockedMilestones.first.map {
                                    " \(unlock.area.milestoneTitle(stage: $0.stage)) changed."
                                } ?? ""
                                showToast(
                                    title: result.unlockedMilestones.isEmpty ? "\(unlock.area.title) visited" : "Grove corner changed",
                                    detail: milestoneText.isEmpty ? "This corner has been noticed." : milestoneText.trimmingCharacters(in: .whitespaces),
                                    icon: unlock.area.icon,
                                    tint: unlock.area.tint
                                )
                            }
                        }
                    }
                )
                .presentationDetents([.height(650), .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func touchGardenTracePrompt(_ prompt: GardenTracePrompt) {
        guard prompt.isComplete else { return }
        withAnimation(.easeInOut(duration: 0.20)) {
            if appState.touchGardenPrompt(id: prompt.id, dewAmount: prompt.dewAmount) {
                showToast(
                    title: "Small change noticed",
                    detail: "\(prompt.title) is now part of the shelf.",
                    icon: "sparkles",
                    tint: Color(hex: 0xD99A32)
                )
            }
        }
    }

    private func plantStarterSeed(_ seed: GardenStarterSeed) {
        withAnimation(.easeInOut(duration: 0.20)) {
            if let habit = appState.plantStarterGardenRoutine(title: seed.title, description: seed.detail) {
                focusedHabitID = habit.id
                showToast(
                    title: "Trace placed",
                    detail: "\(habit.title) is now part of the grove.",
                    icon: seed.systemImage,
                    tint: seed.tint
                )
            }
        }
    }

    private func activateWateringCan() {
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedTool = .tend
        }
        showToast(
            title: "Touch mode",
            detail: "Tap a trace to gently notice it.",
            icon: "sparkles",
            tint: Color(hex: 0x309FD2)
        )
    }

    private func handleForageTap(_ item: GardenForageItem) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            if appState.gatherGardenForageItem(id: item.id) != nil {
                showToast(
                    title: "Dew gathered",
                    detail: "Small discoveries now feed the grove.",
                    icon: "sparkles",
                    tint: Color(hex: 0xD99A32)
                )
            }
        }
    }

    private func handleVisitorTap(_ invitation: GardenVisitorInvitation) {
        moveKeeper(
            to: keeperApproachPosition(for: invitation),
            duration: 0.58
        )
        selectedVisitorInvitationID = invitation.id
    }

    private func keeperApproachPosition(for invitation: GardenVisitorInvitation) -> CGPoint {
        let sideOffset = invitation.x < 0.5 ? 0.20 : -0.20
        return CGPoint(
            x: min(max(invitation.x + sideOffset, 0.18), 0.82),
            y: min(max(invitation.y + 0.07, 0.48), 0.68)
        )
    }

    private func handleAreaTap(_ unlock: GardenMapAreaUnlock) {
        moveKeeper(
            to: CGPoint(
                x: unlock.area.mapPosition.x,
                y: min(unlock.area.mapPosition.y + 0.08, 0.72)
            ),
            duration: 0.58
        )
        selectedAreaUnlockID = unlock.id
    }

    private func areaVisitToday(for area: GardenMapAreaKind) -> GardenMapAreaVisit? {
        let dayKey = GardenForageItem.dayKey(for: Date())
        return appState.gardenAreaVisits.first { $0.area == area && $0.dayKey == dayKey }
    }

    private func areaVisitCount(for area: GardenMapAreaKind) -> Int {
        areaVisitCounts[area] ?? 0
    }

    private func areaMilestones(for area: GardenMapAreaKind) -> [GardenAreaMilestoneUnlock] {
        appState.gardenAreaMilestones
            .filter { $0.area == area }
            .sorted { $0.stage < $1.stage }
    }

    private func visitorInvitationProgress(for invitation: GardenVisitorInvitation) -> Int {
        switch invitation.invitationKind {
        case .gatherDew:
            return gatheredForageToday
        case .touchTrace:
            return completedCount
        }
    }

    private func handlePlotTap(_ habit: Habit) {
        guard let plotPosition = plotPosition(for: habit) else {
            selectedHabitID = habit.id
            return
        }

        moveKeeper(
            to: CGPoint(
                x: plotPosition.x,
                y: min(plotPosition.y + 0.075, 0.72)
            ),
            duration: 0.56
        )
        withAnimation(.easeInOut(duration: 0.18)) {
            focusedHabitID = habit.id
        }

        switch selectedTool {
        case .explore:
            selectedHabitID = habit.id
            clearFocus(after: 0.4)
        case .tend:
            if !appState.isGardenHabitCompletedToday(habit) {
                withAnimation(.easeInOut(duration: 0.22)) {
                    appState.completeHabit(id: habit.id)
                }
                showToast(
                    title: "Trace touched",
                    detail: "The grove remembers the return.",
                    icon: "sparkles",
                    tint: Color(hex: 0x5FA461)
                )
                clearFocus(after: 1.4)
                return
            }

            guard appState.waterDrops > 0, habit.plantType != .tree else {
                selectedHabitID = habit.id
                return
            }
            withAnimation(.easeInOut(duration: 0.22)) {
                appState.waterPlant(id: habit.id)
                recentlyWateredHabitID = habit.id
            }
            showToast(
                title: "Dew added",
                detail: "\(habit.title) feels a little more visible.",
                icon: "drop.fill",
                tint: Color(hex: 0x309FD2)
            )
            clearWaterBurst(after: 1.2)
            clearFocus(after: 1.4)
        case .arrange:
            let decorationType = selectedArrangementType
            if arrangeDecoration(near: habit, at: plotPosition, type: decorationType) {
                showToast(
                    title: "\(decorationType.title) arranged",
                    detail: "-\(decorationType.dewCost) dew. The grove keeps this small object.",
                    icon: decorationType.systemImage,
                    tint: decorationType.tint
                )
            } else {
                showToast(
                    title: "Need more dew",
                    detail: "\(decorationType.title) costs \(decorationType.dewCost) dew.",
                    icon: "drop.fill",
                    tint: Color(hex: 0x309FD2)
                )
            }
            clearFocus(after: 1.4)
        }
    }

    private func plotPosition(for habit: Habit) -> CGPoint? {
        guard let index = appState.habits.firstIndex(where: { $0.id == habit.id }),
              index < gardenPlotPositions.count else { return nil }
        return gardenPlotPositions[index]
    }

    private var canRoamKeeper: Bool {
        appState.selectedTab == LuminaRootTab.garden.rawValue &&
        !reduceMotion &&
        !ProcessInfo.processInfo.isLowPowerModeEnabled &&
        focusedHabitID == nil &&
        selectedHabitID == nil &&
        selectedVisitorInvitationID == nil &&
        selectedAreaUnlockID == nil &&
        !showingMemoryShelf &&
        !showingGardenFirstVisitGuide &&
        recentlyWateredHabitID == nil
    }

    private var canShowGardenFirstVisitGuide: Bool {
        hasCompletedWelcomeGuide &&
        !hasCompletedGardenFirstVisitGuide &&
        !showingGardenFirstVisitGuide &&
        !showingMemoryShelf &&
        selectedHabitID == nil &&
        selectedVisitorInvitationID == nil &&
        selectedAreaUnlockID == nil
    }

    private func scheduleGardenFirstVisitGuideIfNeeded() {
        guard canShowGardenFirstVisitGuide, !hasScheduledGardenFirstVisitGuide else { return }
        hasScheduledGardenFirstVisitGuide = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
            guard canShowGardenFirstVisitGuide else {
                hasScheduledGardenFirstVisitGuide = false
                return
            }
            gardenFirstVisitGuideStep = .world
            keeperAmbientMood = .waiting
            withAnimation(.easeOut(duration: 0.28)) {
                showingGardenFirstVisitGuide = true
            }
        }
    }

    private func advanceGardenFirstVisitGuide() {
        guard let nextStep = gardenFirstVisitGuideStep.next else {
            finishGardenFirstVisitGuide()
            return
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            gardenFirstVisitGuideStep = nextStep
            keeperAmbientMood = nextStep == .traces ? .inspecting : .idle
        }
    }

    private func goBackGardenFirstVisitGuide() {
        guard let previousStep = gardenFirstVisitGuideStep.previous else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            gardenFirstVisitGuideStep = previousStep
        }
    }

    private func finishGardenFirstVisitGuide() {
        hasCompletedGardenFirstVisitGuide = true
        hasScheduledGardenFirstVisitGuide = false
        withAnimation(.easeOut(duration: 0.20)) {
            showingGardenFirstVisitGuide = false
        }
        gardenFirstVisitGuideStep = .world
    }

    private func roamKeeperIfIdle() {
        guard canRoamKeeper, !gardenKeeperRoamingStops.isEmpty else { return }

        let nextIndex = (keeperRoamIndex + 1) % gardenKeeperRoamingStops.count
        keeperRoamIndex = nextIndex
        let destination = gardenKeeperRoamingStops[nextIndex]
        let settleMood = gardenKeeperRoamingSettleMoods[nextIndex % gardenKeeperRoamingSettleMoods.count]
        moveKeeper(
            to: destination,
            duration: keeperMoveDuration(from: avatarPosition, to: destination),
            settleMood: settleMood
        )
    }

    private func advanceKeeperAmbientMood() {
        guard canRoamKeeper, !keeperIsWalking, !gardenKeeperAmbientMoodCycle.isEmpty else { return }
        guard let currentIndex = gardenKeeperAmbientMoodCycle.firstIndex(of: keeperAmbientMood) else {
            keeperAmbientMood = gardenKeeperAmbientMoodCycle[0]
            return
        }
        let nextIndex = (currentIndex + 1) % gardenKeeperAmbientMoodCycle.count
        withAnimation(.easeInOut(duration: 0.24)) {
            keeperAmbientMood = gardenKeeperAmbientMoodCycle[nextIndex]
        }
    }

    private func moveKeeper(to destination: CGPoint, duration: Double, settleMood: GardenKeeperMood? = nil) {
        let clampedDestination = CGPoint(
            x: min(max(destination.x, 0.12), 0.88),
            y: min(max(destination.y, 0.34), 0.65)
        )
        if abs(clampedDestination.x - avatarPosition.x) > 0.012 {
            keeperFacesLeft = clampedDestination.x < avatarPosition.x
        }

        let allowsMotion = !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
        let token = UUID()
        keeperMoveToken = token
        keeperIsWalking = allowsMotion

        let movementAnimation: Animation? = allowsMotion ? .linear(duration: duration) : nil
        withAnimation(movementAnimation) {
            avatarPosition = clampedDestination
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64((duration + 0.10) * 1_000_000_000))
            guard keeperMoveToken == token else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                keeperIsWalking = false
                if let settleMood {
                    keeperAmbientMood = settleMood
                }
            }
        }
    }

    private func keeperMoveDuration(from origin: CGPoint, to destination: CGPoint) -> Double {
        let deltaX = Double(destination.x - origin.x)
        let deltaY = Double(destination.y - origin.y)
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        return min(max(distance * 3.0, 0.72), 1.65)
    }

    private func openJournal(for habitID: String, after seconds: Double) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            selectedHabitID = habitID
            clearFocus(after: 0.4)
        }
    }

    private func arrangeDecoration(near habit: Habit, at plotPosition: CGPoint, type: GardenDecorationType) -> Bool {
        let offsets = type.offsets
        let usedCount = appState.gardenDecorations.filter { $0.anchorHabitID == habit.id }.count
        let offset = offsets[usedCount % offsets.count]
        let position = CGPoint(
            x: min(max(plotPosition.x + offset.width, 0.10), 0.90),
            y: min(max(plotPosition.y + offset.height, 0.28), 0.73)
        )

        var didArrange = false
        withAnimation(.easeInOut(duration: 0.24)) {
            didArrange = appState.arrangeGardenDecoration(
                type: type,
                anchorHabitID: habit.id,
                x: Double(position.x),
                y: Double(position.y)
            )
            if didArrange {
                selectedArrangementType = type.next
            }
        }
        return didArrange
    }

    private func showToast(title: String, detail: String, icon: String, tint: Color) {
        let toast = GardenToast(title: title, detail: detail, icon: icon, tint: tint)
        withAnimation(.easeOut(duration: 0.18)) {
            gardenToast = toast
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard gardenToast?.id == toast.id else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                gardenToast = nil
            }
        }
    }

    private func showAreaDewBurst(area: GardenMapAreaKind, amount: Int) {
        let burst = GardenAreaDewBurst(area: area, amount: amount)
        withAnimation(.easeOut(duration: 0.18)) {
            areaDewBurst = burst
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard areaDewBurst?.id == burst.id else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                areaDewBurst = nil
            }
        }
    }

    private func clearWaterBurst(after seconds: Double) {
        let id = recentlyWateredHabitID
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard recentlyWateredHabitID == id else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                recentlyWateredHabitID = nil
            }
        }
    }

    private func clearFocus(after seconds: Double) {
        let id = focusedHabitID
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard focusedHabitID == id else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                focusedHabitID = nil
            }
        }
    }
}

private struct GardenToast: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let tint: Color
}

private struct GardenAreaDewBurst: Identifiable {
    let id = UUID()
    let area: GardenMapAreaKind
    let amount: Int
}

private struct GardenTracePrompt: Identifiable {
    let id: String
    let title: String
    let detail: String
    let progress: Int
    let goal: Int
    let dewAmount: Int
    let systemImage: String

    var isComplete: Bool { progress >= goal }

    var progressFraction: CGFloat {
        guard goal > 0 else { return 0 }
        return min(1, CGFloat(progress) / CGFloat(goal))
    }
}

private struct GardenRhythmStage: Identifiable {
    let id: String
    let title: String
    let detail: String
    let progress: Int
    let goal: Int
    let systemImage: String
    let tint: Color

    var isComplete: Bool {
        progress >= goal
    }

    var progressText: String {
        "\(min(progress, goal))/\(max(goal, 1))"
    }
}

private struct GardenNextMove {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
}

private struct GardenStarterSeed: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    static let defaults: [GardenStarterSeed] = [
        GardenStarterSeed(
            id: "one-sentence",
            title: "One honest sentence",
            detail: "Write one line you can leave as it is.",
            systemImage: "text.append",
            tint: Color(hex: 0x6D8B5F)
        ),
        GardenStarterSeed(
            id: "three-breaths",
            title: "Three slow breaths",
            detail: "Pause once and let the body soften.",
            systemImage: "wind",
            tint: Color(hex: 0x4C8F8B)
        ),
        GardenStarterSeed(
            id: "small-reset",
            title: "Clear one small surface",
            detail: "Make one visible corner a little easier.",
            systemImage: "sparkles",
            tint: Color(hex: 0xB8862D)
        )
    ]
}

private let gardenPlotPositions: [CGPoint] = [
    CGPoint(x: 0.28, y: 0.43),
    CGPoint(x: 0.72, y: 0.43),
    CGPoint(x: 0.30, y: 0.58),
    CGPoint(x: 0.70, y: 0.58),
    CGPoint(x: 0.50, y: 0.66),
    CGPoint(x: 0.49, y: 0.33),
    CGPoint(x: 0.39, y: 0.51),
    CGPoint(x: 0.61, y: 0.51)
]

private let gardenKeepsakePositions: [CGPoint] = [
    CGPoint(x: 0.70, y: 0.59),
    CGPoint(x: 0.50, y: 0.66),
    CGPoint(x: 0.28, y: 0.60)
]

private func gardenFrameAssetNames(_ prefix: String, count: Int) -> [String] {
    guard count > 0 else { return [] }
    return (1...count).map { gardenFrameAssetName(prefix, index: $0) }
}

private func gardenFrameAssetName(_ prefix: String, index: Int) -> String {
    "\(prefix)\(index < 10 ? "0\(index)" : "\(index)")"
}

private func gardenPingPongFrameAssetNames(_ prefix: String, indices: [Int]) -> [String] {
    guard !indices.isEmpty else { return [] }
    let returnLeg = indices.dropLast().dropFirst().reversed()
    return (indices + returnLeg).map { gardenFrameAssetName(prefix, index: $0) }
}

private func gardenAmbientPingPongFrameAssetNames(_ prefix: String, indices: [Int], holdCount: Int) -> [String] {
    guard let firstIndex = indices.first else { return [] }
    let stillness = Array(repeating: firstIndex, count: holdCount)
    let returnLeg = indices.dropLast().dropFirst().reversed()
    return (stillness + indices + returnLeg + stillness).map { gardenFrameAssetName(prefix, index: $0) }
}

private func gardenAmbientFrameAssetNames(_ prefix: String, indices: [Int], holdCount: Int) -> [String] {
    guard let firstIndex = indices.first else { return [] }
    let stillness = Array(repeating: firstIndex, count: holdCount)
    return (stillness + indices + stillness).map { gardenFrameAssetName(prefix, index: $0) }
}

private enum GardenCharacterMotionTiming {
    static let visitorIdle: TimeInterval = 0.20
    static let visitorWalk: TimeInterval = 0.14
    static let visitorOffer: TimeInterval = 0.14
    static let solIdle: TimeInterval = 0.24
    static let keeperWalk: TimeInterval = 0.10
    static let keeperAction: TimeInterval = 0.12
}

private let gardenCharacterPlaybackScale: TimeInterval = 2.4
private let gardenMinimumSpriteFrameDuration: TimeInterval = 0.28

private func gardenEffectiveSpriteFrameDuration(_ frameDuration: TimeInterval) -> TimeInterval {
    max(frameDuration * gardenCharacterPlaybackScale, gardenMinimumSpriteFrameDuration)
}

private let gardenKeeperWalkFrames = gardenFrameAssetNames("GardenKeeperWalkFull", count: 16)

private let gardenKeeperIdleFrames = [
    "GardenKeeperInspectFull01"
]

private let gardenKeeperWaitingFrames = [
    "GardenKeeperInspectFull01"
]

private let gardenKeeperInspectFrames = gardenFrameAssetNames("GardenKeeperInspectFull", count: 16)

private let gardenKeeperTendFrames = gardenFrameAssetNames("GardenKeeperInspectFull", count: 16)

private let gardenKeeperPlaceFrames = gardenFrameAssetNames("GardenKeeperPlaceFull", count: 16)

private let gardenVisitorMiraIdleFrames = gardenAmbientPingPongFrameAssetNames(
    "GardenVisitorMiraIdleFull",
    indices: Array(1...8),
    holdCount: 10
)

private let gardenVisitorMiraWalkFrames = gardenPingPongFrameAssetNames(
    "GardenVisitorMiraWalkFull",
    indices: Array(1...8)
)

private let gardenVisitorMiraOfferFrames = gardenFrameAssetNames("GardenVisitorMiraOfferFull", count: 16)

private let gardenVisitorSolIdleFrames = gardenAmbientPingPongFrameAssetNames(
    "GardenVisitorSolIdleFull",
    indices: [5, 6, 7, 8, 9],
    holdCount: 8
)

private let gardenVisitorSolWalkFrames = gardenPingPongFrameAssetNames(
    "GardenVisitorSolWalkFull",
    indices: [1, 2, 3, 4, 5, 6, 7, 8]
)

private let gardenVisitorSolOfferFrames = gardenFrameAssetNames("GardenVisitorSolOfferFull", count: 16)

private let gardenVisitorNoriIdleFrames = gardenAmbientFrameAssetNames(
    "GardenVisitorNoriIdleFull",
    indices: Array(1...16),
    holdCount: 12
)

private let gardenVisitorNoriWalkFrames = gardenPingPongFrameAssetNames(
    "GardenVisitorNoriWalkFull",
    indices: Array(1...12)
)

private let gardenVisitorNoriOfferFrames = gardenFrameAssetNames("GardenVisitorNoriOfferFull", count: 16)

private enum GardenKeeperMood: Equatable {
    case waiting
    case idle
    case walking
    case inspecting
    case tending
    case placing

    var frames: [String] {
        switch self {
        case .waiting:
            return gardenKeeperWaitingFrames
        case .idle:
            return gardenKeeperIdleFrames
        case .walking:
            return gardenKeeperWalkFrames
        case .inspecting:
            return gardenKeeperInspectFrames
        case .tending:
            return gardenKeeperTendFrames
        case .placing:
            return gardenKeeperPlaceFrames
        }
    }

    var frameDuration: TimeInterval {
        switch self {
        case .walking:
            return GardenCharacterMotionTiming.keeperWalk
        case .tending:
            return GardenCharacterMotionTiming.keeperAction
        case .inspecting:
            return GardenCharacterMotionTiming.keeperAction
        case .placing:
            return GardenCharacterMotionTiming.keeperAction
        case .idle:
            return 1.18
        case .waiting:
            return 1.28
        }
    }

    var repeatsFrames: Bool {
        switch self {
        case .waiting, .idle, .walking:
            return true
        case .inspecting, .tending, .placing:
            return false
        }
    }

    var usesOneShotAction: Bool {
        !repeatsFrames
    }

    var shadowWidth: CGFloat {
        switch self {
        case .walking: return 78
        case .inspecting, .tending, .placing: return 76
        case .waiting, .idle: return 72
        }
    }

    var spriteScale: CGFloat {
        1.0
    }

    var spriteYOffset: CGFloat {
        0
    }
}

private let gardenKeeperRoamInterval: TimeInterval = 11.5
private let gardenKeeperAmbientMoodInterval: TimeInterval = 8.0
private let gardenKeeperAmbientMoodCycle: [GardenKeeperMood] = [
    .idle,
    .waiting,
    .idle
]

private let gardenKeeperRoamingStops: [CGPoint] = [
    CGPoint(x: 0.50, y: 0.62),
    CGPoint(x: 0.43, y: 0.62),
    CGPoint(x: 0.56, y: 0.59),
    CGPoint(x: 0.66, y: 0.57),
    CGPoint(x: 0.48, y: 0.55),
    CGPoint(x: 0.50, y: 0.62)
]

private let gardenKeeperRoamingSettleMoods: [GardenKeeperMood] = [
    .waiting,
    .idle,
    .idle,
    .waiting,
    .idle,
    .waiting
]

private extension GardenDecorationType {
    var title: String {
        switch self {
        case .lamp: return "Lantern"
        case .stones: return "Stepping stones"
        case .flowers: return "Wildflowers"
        }
    }

    var systemImage: String {
        switch self {
        case .lamp: return "lamp.floor.fill"
        case .stones: return "circle.grid.2x2.fill"
        case .flowers: return "camera.macro"
        }
    }

    var tint: Color {
        switch self {
        case .lamp: return Color(hex: 0xD99A32)
        case .stones: return Color(hex: 0x8B7A65)
        case .flowers: return Color(hex: 0xD66D90)
        }
    }

    var next: GardenDecorationType {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return .lamp }
        return all[(index + 1) % all.count]
    }

    var offsets: [CGSize] {
        switch self {
        case .lamp:
            return [
                CGSize(width: -0.10, height: -0.05),
                CGSize(width: 0.10, height: -0.05),
                CGSize(width: -0.09, height: 0.06)
            ]
        case .stones:
            return [
                CGSize(width: -0.02, height: 0.10),
                CGSize(width: 0.08, height: 0.08),
                CGSize(width: -0.10, height: 0.08)
            ]
        case .flowers:
            return [
                CGSize(width: 0.11, height: -0.01),
                CGSize(width: -0.11, height: 0.00),
                CGSize(width: 0.02, height: -0.10)
            ]
        }
    }
}

private extension GardenVisitorKind {
    var displayName: String {
        switch self {
        case .mira: return "Mira"
        case .sol: return "Sol"
        case .nori: return "Nori"
        }
    }

    var roleTitle: String {
        switch self {
        case .mira: return "Path guide"
        case .sol: return "Lantern maker"
        case .nori: return "Seed archivist"
        }
    }

    var accent: Color {
        switch self {
        case .mira: return Color(hex: 0xD99A32)
        case .sol: return Color(hex: 0x5FA461)
        case .nori: return Color(hex: 0x6E8BC8)
        }
    }

    var portraitAssetName: String {
        switch self {
        case .mira: return "GardenVisitorMiraPortrait"
        case .sol: return "GardenVisitorSolPortrait"
        case .nori: return "GardenVisitorNoriPortrait"
        }
    }

    var idleSpriteAssetNames: [String] {
        switch self {
        case .mira:
            return gardenVisitorMiraIdleFrames
        case .sol:
            return gardenVisitorSolIdleFrames
        case .nori:
            return gardenVisitorNoriIdleFrames
        }
    }

    var walkSpriteAssetNames: [String] {
        switch self {
        case .mira:
            return gardenVisitorMiraWalkFrames
        case .sol:
            return gardenVisitorSolWalkFrames
        case .nori:
            return gardenVisitorNoriWalkFrames
        }
    }

    var offerSpriteAssetNames: [String] {
        switch self {
        case .mira:
            return gardenVisitorMiraOfferFrames
        case .sol:
            return gardenVisitorSolOfferFrames
        case .nori:
            return gardenVisitorNoriOfferFrames
        }
    }

    var allSpriteAssetNames: [String] {
        switch self {
        case .mira:
            return gardenVisitorMiraIdleFrames + gardenVisitorMiraWalkFrames + gardenVisitorMiraOfferFrames
        case .sol:
            return gardenVisitorSolIdleFrames + gardenVisitorSolWalkFrames + gardenVisitorSolOfferFrames
        case .nori:
            return gardenVisitorNoriIdleFrames + gardenVisitorNoriWalkFrames + gardenVisitorNoriOfferFrames
        }
    }

    var idleFrameDuration: TimeInterval {
        switch self {
        case .mira:
            return GardenCharacterMotionTiming.visitorIdle
        case .sol:
            return GardenCharacterMotionTiming.solIdle
        case .nori:
            return GardenCharacterMotionTiming.visitorIdle
        }
    }

    var walkFrameDuration: TimeInterval {
        switch self {
        case .mira:
            return GardenCharacterMotionTiming.visitorWalk
        case .sol:
            return GardenCharacterMotionTiming.visitorWalk
        case .nori:
            return GardenCharacterMotionTiming.visitorWalk
        }
    }

    var offerFrameDuration: TimeInterval {
        switch self {
        case .mira:
            return GardenCharacterMotionTiming.visitorOffer
        case .sol:
            return GardenCharacterMotionTiming.visitorOffer
        case .nori:
            return GardenCharacterMotionTiming.visitorOffer
        }
    }

    var roamingOffsets: [CGSize] {
        switch self {
        case .mira:
            return [
                CGSize(width: 0, height: 0),
                CGSize(width: -14, height: 5),
                CGSize(width: 8, height: -6),
                CGSize(width: 18, height: 3)
            ]
        case .sol:
            return [
                CGSize(width: 0, height: 0),
                CGSize(width: 12, height: -5),
                CGSize(width: -10, height: -2),
                CGSize(width: -18, height: 6)
            ]
        case .nori:
            return [
                CGSize(width: 0, height: 0),
                CGSize(width: 10, height: 4),
                CGSize(width: -12, height: -5),
                CGSize(width: 16, height: -2)
            ]
        }
    }

    var message: String {
        switch self {
        case .mira:
            return "I found a small path through the grove. Help me steady it before sunset?"
        case .sol:
            return "The lanterns are low. A little care can bring the warm light back."
        case .nori:
            return "I am cataloging tiny wins. Show me one small sign that the grove is awake."
        }
    }
}

private extension GardenVisitorInvitationKind {
    var title: String {
        switch self {
        case .gatherDew: return "Notice dew"
        case .touchTrace: return "Touch a trace"
        }
    }

    var detail: String {
        switch self {
        case .gatherDew:
            return "Find a few soft dew motes resting around the grove."
        case .touchTrace:
            return "Touch one trace if it already happened."
        }
    }

    var systemImage: String {
        switch self {
        case .gatherDew: return "drop.fill"
        case .touchTrace: return "checkmark.seal.fill"
        }
    }
}

private extension GardenKeepsakeKind {
    var title: String {
        switch self {
        case .pathCharm: return "Path Charm"
        case .sunLantern: return "Sun Lantern"
        case .seedArchive: return "Seed Archive"
        }
    }

    var detail: String {
        switch self {
        case .pathCharm: return "A marker from Mira for days when one step is enough."
        case .sunLantern: return "A warm lamp from Sol that makes evening visits softer."
        case .seedArchive: return "Nori's tiny record of small wins that took root."
        }
    }

    var icon: String {
        switch self {
        case .pathCharm: return "signpost.right.fill"
        case .sunLantern: return "lamp.floor.fill"
        case .seedArchive: return "archivebox.fill"
        }
    }

    var assetName: String {
        switch self {
        case .pathCharm: return "GardenTraceWindCharmV2"
        case .sunLantern: return "GardenTraceLanternV2"
        case .seedArchive: return "GardenTraceMemoryStoneV2"
        }
    }

    var tint: Color {
        switch self {
        case .pathCharm: return Color(hex: 0xC98E45)
        case .sunLantern: return Color(hex: 0xE4AD3D)
        case .seedArchive: return Color(hex: 0x6E8BC8)
        }
    }

    var mapPosition: (x: Double, y: Double) {
        switch self {
        case .pathCharm: return (0.22, 0.58)
        case .sunLantern: return (0.77, 0.39)
        case .seedArchive: return (0.84, 0.50)
        }
    }
}

private extension GardenMapAreaKind {
    var title: String {
        switch self {
        case .pathNook: return "Path Nook"
        case .lanternGlade: return "Lantern Glade"
        case .archiveCorner: return "Archive Corner"
        }
    }

    var detail: String {
        switch self {
        case .pathNook:
            return "A small walking loop for days when one step is enough."
        case .lanternGlade:
            return "A warm clearing for evening care and softer returns."
        case .archiveCorner:
            return "A quiet shelf for saved routines and plant memories."
        }
    }

    var actionTitle: String {
        switch self {
        case .pathNook: return "Take the short loop"
        case .lanternGlade: return "Light the lanterns"
        case .archiveCorner: return "Sort one memory"
        }
    }

    var actionDetail: String {
        switch self {
        case .pathNook:
            return "Walk the tiny route and leave one steady mark behind."
        case .lanternGlade:
            return "Refresh the clearing light so evening visits feel warmer."
        case .archiveCorner:
            return "Place one small win where it can be found again."
        }
    }

    var miniGameTitle: String {
        switch miniGameKind {
        case .route: return "Trace the route"
        case .lanterns: return "Warm the clearing"
        case .archive: return "File the seeds"
        }
    }

    var miniGameReadyTitle: String {
        switch miniGameKind {
        case .route: return "Route traced"
        case .lanterns: return "Lanterns lit"
        case .archive: return "Seeds filed"
        }
    }

    func milestoneTitle(stage: Int) -> String {
        switch (self, stage) {
        case (.pathNook, 1): return "Trail marker"
        case (.pathNook, 2): return "Stone loop"
        case (.pathNook, 3): return "Quiet route"
        case (.lanternGlade, 1): return "First lantern"
        case (.lanternGlade, 2): return "Evening glow"
        case (.lanternGlade, 3): return "Gathering light"
        case (.archiveCorner, 1): return "Seed label"
        case (.archiveCorner, 2): return "Routine shelf"
        case (.archiveCorner, 3): return "Memory catalog"
        default: return "Area milestone"
        }
    }

    func milestoneDetail(stage: Int) -> String {
        switch (self, stage) {
        case (.pathNook, 1):
            return "The first signpost makes this walk feel intentional."
        case (.pathNook, 2):
            return "The loop is easier to follow when the path is tended."
        case (.pathNook, 3):
            return "A full quiet route is open for short reset walks."
        case (.lanternGlade, 1):
            return "A small warm light now marks the clearing."
        case (.lanternGlade, 2):
            return "The glade holds its glow for longer evening visits."
        case (.lanternGlade, 3):
            return "The lanterns are bright enough to welcome company."
        case (.archiveCorner, 1):
            return "One saved seed turns effort into something findable."
        case (.archiveCorner, 2):
            return "The shelf starts organizing routines into a memory."
        case (.archiveCorner, 3):
            return "The archive can now hold a fuller record of growth."
        default:
            return "This area has grown from repeated care."
        }
    }

    var icon: String {
        switch self {
        case .pathNook: return "figure.walk"
        case .lanternGlade: return "sparkles"
        case .archiveCorner: return "books.vertical.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pathNook: return Color(hex: 0x8EAD69)
        case .lanternGlade: return Color(hex: 0xE2A747)
        case .archiveCorner: return Color(hex: 0x7893C4)
        }
    }

    var mapPosition: (x: Double, y: Double) {
        switch self {
        case .pathNook: return (0.22, 0.58)
        case .lanternGlade: return (0.77, 0.39)
        case .archiveCorner: return (0.84, 0.50)
        }
    }
}

private struct GardenToastView: View {
    let toast: GardenToast

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: toast.icon)
                .luminaFont(size: 16, weight: .black)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(toast.tint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .luminaFont(size: 14, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0x3F3428))
                    .lineLimit(1)
                Text(toast.detail)
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(Color(hex: 0x756750))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(hex: 0xFFF8E8).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x1B3C22).opacity(0.20), radius: 18, x: 0, y: 8)
    }
}

private struct GardenAreaDewBurstView: View {
    let burst: GardenAreaDewBurst
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false

    var body: some View {
        ZStack {
            if !reduceMotion {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: "drop.fill")
                        .luminaFont(size: CGFloat(10 + index % 3), weight: .black)
                        .foregroundColor(Color(hex: 0x55BDE6))
                        .opacity(appear ? 0 : 0.95)
                        .scaleEffect(appear ? 0.64 : 1)
                        .offset(
                            x: CGFloat([-46, -24, 0, 26, 44][index]),
                            y: appear ? CGFloat([-50, -68, -58, -74, -52][index]) : 10
                        )
                        .animation(.easeOut(duration: 0.70).delay(Double(index) * 0.04), value: appear)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .luminaFont(size: 15, weight: .black)
                    .foregroundColor(Color(hex: 0x309FD2))
                Text("soft dew")
                    .luminaFont(size: 20, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0x3F3428))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(hex: 0xFFF8E8).opacity(0.95))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(burst.area.tint.opacity(0.36), lineWidth: 1.2))
            .shadow(color: Color(hex: 0x17381F).opacity(0.20), radius: 12, x: 0, y: 7)
            .scaleEffect(appear && !reduceMotion ? 1.05 : 0.92)
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.22), value: appear)
        }
        .onAppear {
            appear = true
        }
    }
}

private struct GardenSoftDewBadge: View {
    var label = "dew"
    var fontSize: CGFloat = 12
    var iconSize: CGFloat = 10
    var horizontalPadding: CGFloat = 9
    var verticalPadding: CGFloat = 6
    var background: Color = Color(hex: 0xFFF8E8)

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "drop.fill")
                .luminaFont(size: iconSize, weight: .black)
                .foregroundColor(Color(hex: 0x309FD2))

            Text(label)
                .luminaFont(size: fontSize, weight: .black, design: .rounded)
                .foregroundColor(Color(hex: 0x4D4032))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(background)
        .clipShape(Capsule())
        .accessibilityLabel("soft dew")
    }
}

// MARK: - Game UI

private enum GardenTool: String, CaseIterable, Identifiable {
    case explore
    case tend
    case arrange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explore: return "Explore"
        case .tend: return "Touch"
        case .arrange: return "Arrange"
        }
    }

    var systemImage: String {
        switch self {
        case .explore: return "figure.walk"
        case .tend: return "sparkles"
        case .arrange: return "plus"
        }
    }

    var tint: Color {
        switch self {
        case .explore: return Color(hex: 0x7D6A54)
        case .tend: return Color(hex: 0x5FA461)
        case .arrange: return Color(hex: 0xD99A32)
        }
    }
}

private enum GardenAtmosphereKind: Equatable {
    case clear
    case morningDew
    case softRain
    case quietMist
    case lanternHour

    static func resolve(checkIn: CheckInMetric?, memoryDepth: Int, readyTraceCount: Int, hour: Int) -> GardenAtmosphereKind {
        if let checkIn {
            if checkIn.stressScore >= 7 {
                return .softRain
            }
            if checkIn.moodScore <= 3 {
                return .quietMist
            }
        }

        if hour >= 19 || hour < 5 {
            return .lanternHour
        }

        if readyTraceCount > 0 || memoryDepth >= 5 {
            return .morningDew
        }

        return .clear
    }

    var title: String {
        switch self {
        case .clear: return "Clear grove"
        case .morningDew: return "Dew light"
        case .softRain: return "Soft rain"
        case .quietMist: return "Quiet mist"
        case .lanternHour: return "Lantern hour"
        }
    }

    var systemImage: String {
        switch self {
        case .clear: return "leaf.fill"
        case .morningDew: return "sparkles"
        case .softRain: return "cloud.rain.fill"
        case .quietMist: return "cloud.fog.fill"
        case .lanternHour: return "flame.fill"
        }
    }

    var tint: Color {
        switch self {
        case .clear: return Color(hex: 0x5FA461)
        case .morningDew: return Color(hex: 0xD99A32)
        case .softRain: return Color(hex: 0x5B8FB5)
        case .quietMist: return Color(hex: 0x8CA594)
        case .lanternHour: return Color(hex: 0xE2A64E)
        }
    }
}

private struct GardenGameBackdrop: View {
    let atmosphere: GardenAtmosphereKind

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("GardenWorldSpringQuietV2")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [
                        Color(hex: 0xFFF6D8).opacity(0.10),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                GardenBackdropAtmosphereWash(atmosphere: atmosphere)

                if atmosphere == .lanternHour {
                    GardenFireflies()
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct GardenBackdropAtmosphereWash: View {
    let atmosphere: GardenAtmosphereKind

    var body: some View {
        switch atmosphere {
        case .clear:
            Color.clear
        case .morningDew:
            LinearGradient(
                colors: [
                    Color(hex: 0xFFF2B8).opacity(0.13),
                    Color.clear,
                    Color(hex: 0xDCE9A5).opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .softRain:
            Color(hex: 0x5E7F82)
                .opacity(0.16)
        case .quietMist:
            LinearGradient(
                colors: [
                    Color(hex: 0xF3F0D8).opacity(0.18),
                    Color(hex: 0xDDE5D1).opacity(0.12),
                    Color(hex: 0x233C30).opacity(0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .lanternHour:
            Color(hex: 0x273454)
                .opacity(0.16)
        }
    }
}

private func gardenMotionSeed(from value: String) -> Double {
    var accumulator = 0
    for scalar in value.unicodeScalars {
        accumulator = (accumulator * 31 + Int(scalar.value)) % 997
    }
    return Double(abs(accumulator))
}

private func gardenUnitClamp(_ value: Double) -> Double {
    min(max(value, 0.03), 0.97)
}

private struct GardenPressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96
    var pressedOpacity: Double = 0.88

    func makeBody(configuration: Configuration) -> some View {
        GardenPressableButtonBody(
            configuration: configuration,
            pressedScale: pressedScale,
            pressedOpacity: pressedOpacity
        )
    }
}

private struct GardenPressableButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let pressedScale: CGFloat
    let pressedOpacity: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allowsMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && allowsMotion ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(allowsMotion ? .easeOut(duration: 0.12) : nil, value: configuration.isPressed)
    }
}

private struct GardenSceneAtmosphereLayer: View {
    let traceCount: Int
    let memoryDepth: Int
    let atmosphere: GardenAtmosphereKind

    private var settledDepth: Int {
        min(max(memoryDepth, 0), 14)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(hex: 0xFFF2C0).opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        Color(hex: 0xFFF0B8).opacity(traceCount == 0 ? 0.16 : 0.10),
                        Color.clear
                    ],
                    center: .init(x: 0.50, y: 0.72),
                    startRadius: 12,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.38
                )

                GardenAmbientPollen()
                    .opacity(traceCount == 0 ? 0.08 : 0.06 + Double(settledDepth) * 0.004)

                GardenWeatherOverlay(atmosphere: atmosphere)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct GardenWorldMemoryBloomLayer: View {
    let depth: Int

    private var bloomCount: Int {
        min(max(depth, 0), 12)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<bloomCount, id: \.self) { index in
                    GardenMemoryBloomMark(
                        tint: Color(hex: [0xE7D678, 0xF0B4A0, 0xD7E8A8, 0xBFDFA9][index % 4]),
                        seed: index
                    )
                    .frame(width: CGFloat(20 + (index % 3) * 4), height: CGFloat(18 + (index % 2) * 4))
                    .position(
                        x: proxy.size.width * CGFloat([0.20, 0.34, 0.47, 0.62, 0.76, 0.86][index % 6]),
                        y: proxy.size.height * CGFloat(0.48 + Double((index * 17) % 34) / 100)
                    )
                    .blendMode(.screen)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GardenMemoryBloomMark: View {
    let tint: Color
    let seed: Int

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(tint.opacity(0.58))
                    .frame(width: 4, height: 10)
                    .offset(y: -4)
                    .rotationEffect(.degrees(Double(index) * 72 + Double(seed % 3) * 8))
            }

            Circle()
                .fill(Color(hex: 0xFFF4C2).opacity(0.70))
                .frame(width: 4, height: 4)
        }
        .rotationEffect(.degrees(Double((seed * 23) % 40) - 20))
        .shadow(color: tint.opacity(0.28), radius: 4, x: 0, y: 1)
    }
}

private struct GardenAmbientPollen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allowsMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        if allowsMotion {
            TimelineView(.periodic(from: .now, by: 1.0 / 18.0)) { context in
                pollenContent(phase: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            pollenContent(phase: 0)
        }
    }

    private func pollenContent(phase: TimeInterval) -> some View {
        GeometryReader { proxy in
            ForEach(0..<16, id: \.self) { index in
                let baseX = Double((index * 31 + 13) % 100) / 100
                let baseY = Double((index * 47 + 28) % 100) / 100
                let driftX = allowsMotion ? sin(phase * 0.10 + Double(index) * 1.7) * 0.018 : 0
                let driftY = allowsMotion ? cos(phase * 0.08 + Double(index) * 1.1) * 0.010 : 0
                let pulse = allowsMotion ? 0.78 + 0.22 * sin(phase * 0.42 + Double(index)) : 1
                Circle()
                    .fill(Color(hex: index.isMultiple(of: 3) ? 0xF4DFA0 : 0xD7E4B8).opacity(0.45 * pulse))
                    .frame(width: CGFloat(index.isMultiple(of: 4) ? 4 : 2), height: CGFloat(index.isMultiple(of: 4) ? 4 : 2))
                    .position(
                        x: proxy.size.width * CGFloat(gardenUnitClamp(baseX + driftX)),
                        y: proxy.size.height * CGFloat(gardenUnitClamp(baseY + driftY))
                    )
                    .blur(radius: index.isMultiple(of: 5) ? 0.8 : 0)
            }
        }
    }
}

private struct GardenWeatherOverlay: View {
    let atmosphere: GardenAtmosphereKind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allowsMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        if allowsMotion {
            TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { context in
                weatherContent(phase: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            weatherContent(phase: 0)
        }
    }

    @ViewBuilder
    private func weatherContent(phase: TimeInterval) -> some View {
        switch atmosphere {
        case .clear:
            EmptyView()
        case .morningDew:
            GardenDewLightLayer(phase: phase)
                .opacity(0.82)
        case .softRain:
            GardenSoftRainLayer(phase: phase)
                .opacity(0.74)
        case .quietMist:
            GardenQuietMistLayer(phase: phase)
                .opacity(0.72)
        case .lanternHour:
            GardenLanternAtmosphereLayer(phase: phase)
                .opacity(0.72)
        }
    }
}

private struct GardenSoftRainLayer: View {
    let phase: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<32, id: \.self) { index in
                    let xUnit = (Double((index * 37 + 11) % 100) / 100 + phase * 0.020)
                        .truncatingRemainder(dividingBy: 1)
                    let yUnit = (Double((index * 29 + 7) % 100) / 100 + phase * 0.090)
                        .truncatingRemainder(dividingBy: 1)

                    Capsule()
                        .fill(Color(hex: 0xDDF1F4).opacity(index.isMultiple(of: 4) ? 0.34 : 0.22))
                        .frame(width: 1.2, height: CGFloat(18 + (index % 3) * 5))
                        .rotationEffect(.degrees(13))
                        .position(
                            x: proxy.size.width * CGFloat(xUnit),
                            y: proxy.size.height * CGFloat(yUnit)
                        )
                }

                LinearGradient(
                    colors: [
                        Color(hex: 0xEAF7EF).opacity(0.06),
                        Color.clear,
                        Color(hex: 0x1A332A).opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

private struct GardenQuietMistLayer: View {
    let phase: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    let drift = sin(phase * 0.22 + Double(index)) * 0.035
                    Capsule()
                        .fill(Color(hex: 0xF3F2DD).opacity(0.10 + Double(index % 2) * 0.025))
                        .frame(width: proxy.size.width * CGFloat(0.58 + Double(index) * 0.10), height: CGFloat(44 + index * 10))
                        .blur(radius: CGFloat(16 + index * 3))
                        .position(
                            x: proxy.size.width * CGFloat(0.18 + Double(index) * 0.18 + drift),
                            y: proxy.size.height * CGFloat(0.30 + Double(index) * 0.10)
                        )
                }
            }
        }
    }
}

private struct GardenDewLightLayer: View {
    let phase: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<11, id: \.self) { index in
                    let pulse = 0.45 + 0.35 * sin(phase * 1.1 + Double(index) * 0.74)
                    let driftX = sin(phase * 0.16 + Double(index) * 1.3) * 0.014
                    let driftY = cos(phase * 0.12 + Double(index) * 1.1) * 0.008
                    let baseX = Double((index * 23 + 16) % 100) / 100
                    let baseY = Double((index * 41 + 30) % 100) / 100
                    Circle()
                        .fill(Color(hex: 0xFFF2A8).opacity(0.18 + pulse * 0.22))
                        .frame(width: CGFloat(4 + index % 3) + CGFloat(pulse) * 1.5, height: CGFloat(4 + index % 3) + CGFloat(pulse) * 1.5)
                        .shadow(color: Color(hex: 0xFFF2A8).opacity(0.45), radius: 7)
                        .position(
                            x: proxy.size.width * CGFloat(gardenUnitClamp(baseX + driftX)),
                            y: proxy.size.height * CGFloat(gardenUnitClamp(baseY + driftY))
                        )
                }
            }
        }
    }
}

private struct GardenLanternAtmosphereLayer: View {
    let phase: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<9, id: \.self) { index in
                    let rise = (Double((index * 19 + 31) % 100) / 100 - phase * 0.018)
                        .truncatingRemainder(dividingBy: 1)
                    let sway = sin(phase * 0.5 + Double(index)) * 0.015
                    Circle()
                        .fill(Color(hex: 0xFFE891).opacity(index.isMultiple(of: 3) ? 0.50 : 0.32))
                        .frame(width: CGFloat(3 + index % 2), height: CGFloat(3 + index % 2))
                        .shadow(color: Color(hex: 0xFFE891).opacity(0.58), radius: 6)
                        .position(
                            x: proxy.size.width * CGFloat(Double((index * 33 + 18) % 100) / 100 + sway),
                            y: proxy.size.height * CGFloat(rise < 0 ? rise + 1 : rise)
                        )
                }
            }
        }
    }
}

private struct GardenMemoryGroveCanvas: View {
    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(
                Path(bounds),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(hex: 0x7FA976),
                        Color(hex: 0xD3D995),
                        Color(hex: 0x92B86C),
                        Color(hex: 0x406C51)
                    ]),
                    startPoint: CGPoint(x: size.width * 0.50, y: 0),
                    endPoint: CGPoint(x: size.width * 0.50, y: size.height)
                )
            )

            drawSoftCanopy(in: &context, size: size)
            drawWater(in: &context, size: size)
            drawMemoryTrail(in: &context, size: size)
            drawMemoryClearings(in: &context, size: size)
            drawMeadowTexture(in: &context, size: size)
            drawVignette(in: &context, size: size)
        }
        .overlay(
            LinearGradient(
                colors: [
                    Color(hex: 0xFFF0BE).opacity(0.20),
                    Color.clear,
                    Color(hex: 0x1D4030).opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(Color(hex: 0x6F9B67))
        .accessibilityHidden(true)
    }

    private func drawSoftCanopy(in context: inout GraphicsContext, size: CGSize) {
        let clusters: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
            (-0.03, 0.07, 0.31, 0.14, Color(hex: 0x315D48)),
            (0.23, 0.02, 0.35, 0.13, Color(hex: 0x477746)),
            (0.78, 0.04, 0.34, 0.15, Color(hex: 0x5D893F)),
            (1.03, 0.22, 0.24, 0.23, Color(hex: 0x315D48)),
            (-0.08, 0.88, 0.38, 0.20, Color(hex: 0x244D3F)),
            (1.06, 0.84, 0.34, 0.23, Color(hex: 0x2D5B45)),
            (0.50, 1.02, 0.38, 0.12, Color(hex: 0x3E6D4C))
        ]

        for (index, cluster) in clusters.enumerated() {
            for leaf in 0..<34 {
                let angle = CGFloat((leaf * 47 + index * 19) % 360) * .pi / 180
                let radius = sqrt(CGFloat((leaf * 29 + 17) % 100) / 100)
                let x = size.width * (cluster.0 + cos(angle) * cluster.2 * radius)
                let y = size.height * (cluster.1 + sin(angle) * cluster.3 * radius)
                let width = size.width * CGFloat(0.045 + Double((leaf + index) % 4) * 0.009)
                let height = width * CGFloat(0.58 + Double(leaf % 3) * 0.08)
                let opacity = 0.18 + Double((leaf + index) % 5) * 0.025
                let path = Path(ellipseIn: CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height))
                context.translateBy(x: x, y: y)
                context.rotate(by: .degrees(Double((leaf * 31 + index * 9) % 76) - 38))
                context.translateBy(x: -x, y: -y)
                context.fill(path, with: .color(cluster.4.opacity(opacity)))
                context.transform = .identity
            }
        }
    }

    private func drawWater(in context: inout GraphicsContext, size: CGSize) {
        var stream = Path()
        stream.move(to: CGPoint(x: size.width * 0.82, y: size.height * 0.00))
        stream.addCurve(
            to: CGPoint(x: size.width * 0.72, y: size.height * 0.34),
            control1: CGPoint(x: size.width * 0.96, y: size.height * 0.13),
            control2: CGPoint(x: size.width * 0.62, y: size.height * 0.20)
        )
        stream.addCurve(
            to: CGPoint(x: size.width * 0.84, y: size.height * 0.72),
            control1: CGPoint(x: size.width * 0.82, y: size.height * 0.47),
            control2: CGPoint(x: size.width * 0.67, y: size.height * 0.60)
        )
        stream.addCurve(
            to: CGPoint(x: size.width * 0.71, y: size.height * 1.02),
            control1: CGPoint(x: size.width * 1.00, y: size.height * 0.84),
            control2: CGPoint(x: size.width * 0.60, y: size.height * 0.89)
        )

        context.stroke(
            stream,
            with: .color(Color(hex: 0x3D9FB0).opacity(0.44)),
            style: StrokeStyle(lineWidth: size.width * 0.23, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            stream,
            with: .color(Color(hex: 0xC8ECE1).opacity(0.30)),
            style: StrokeStyle(lineWidth: size.width * 0.10, lineCap: .round, lineJoin: .round)
        )

        for index in 0..<12 {
            let x = size.width * CGFloat(0.69 + Double((index * 17) % 22) / 100)
            let y = size.height * CGFloat(0.09 + Double(index) * 0.066)
            let rect = CGRect(x: x, y: y, width: size.width * 0.08, height: size.height * 0.010)
            context.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0xE8FFF5).opacity(0.17)))
        }
    }

    private func drawMemoryTrail(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: CGPoint(x: size.width * 0.24, y: size.height * 0.10))
        path.addCurve(
            to: CGPoint(x: size.width * 0.48, y: size.height * 0.34),
            control1: CGPoint(x: size.width * 0.18, y: size.height * 0.22),
            control2: CGPoint(x: size.width * 0.55, y: size.height * 0.22)
        )
        path.addCurve(
            to: CGPoint(x: size.width * 0.32, y: size.height * 0.58),
            control1: CGPoint(x: size.width * 0.40, y: size.height * 0.45),
            control2: CGPoint(x: size.width * 0.22, y: size.height * 0.46)
        )
        path.addCurve(
            to: CGPoint(x: size.width * 0.55, y: size.height * 0.82),
            control1: CGPoint(x: size.width * 0.46, y: size.height * 0.67),
            control2: CGPoint(x: size.width * 0.44, y: size.height * 0.74)
        )
        path.addCurve(
            to: CGPoint(x: size.width * 0.46, y: size.height * 0.98),
            control1: CGPoint(x: size.width * 0.66, y: size.height * 0.90),
            control2: CGPoint(x: size.width * 0.35, y: size.height * 0.91)
        )

        context.stroke(
            path,
            with: .color(Color(hex: 0xEAD79A).opacity(0.28)),
            style: StrokeStyle(lineWidth: size.width * 0.095, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(Color(hex: 0xFFF1BC).opacity(0.20)),
            style: StrokeStyle(lineWidth: size.width * 0.044, lineCap: .round, lineJoin: .round)
        )

        for index in 0..<15 {
            let t = CGFloat(index) / 14
            let x = size.width * (0.23 + 0.30 * sin(t * .pi * 1.4) + 0.22 * t)
            let y = size.height * (0.12 + 0.82 * t)
            let rect = CGRect(x: x - 9, y: y - 4, width: 18, height: 8)
            context.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0xF3DCA2).opacity(0.20)))
        }
    }

    private func drawMemoryClearings(in context: inout GraphicsContext, size: CGSize) {
        let clearings: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
            (0.34, 0.43, 0.18, 0.065, Color(hex: 0xDDE8AB)),
            (0.66, 0.49, 0.17, 0.060, Color(hex: 0xD9E4A3)),
            (0.43, 0.59, 0.15, 0.056, Color(hex: 0xE7DC9C)),
            (0.72, 0.68, 0.18, 0.064, Color(hex: 0xCEDF9C)),
            (0.29, 0.72, 0.17, 0.060, Color(hex: 0xDBE6A7)),
            (0.56, 0.36, 0.13, 0.046, Color(hex: 0xE4D99B))
        ]

        for (index, clearing) in clearings.enumerated() {
            let center = CGPoint(x: size.width * clearing.0, y: size.height * clearing.1)
            let rect = CGRect(
                x: center.x - size.width * clearing.2 / 2,
                y: center.y - size.height * clearing.3 / 2,
                width: size.width * clearing.2,
                height: size.height * clearing.3
            )
            context.fill(Path(ellipseIn: rect), with: .color(clearing.4.opacity(0.24)))
            context.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -1)), with: .color(Color(hex: 0xFFF2C2).opacity(0.14)), lineWidth: 1)

            for mark in 0..<5 {
                let x = center.x + CGFloat(mark - 2) * size.width * 0.018
                let y = center.y + CGFloat((mark + index) % 3 - 1) * size.height * 0.008
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 2, y: y - 1, width: 4, height: 2)),
                    with: .color(Color(hex: 0x577B43).opacity(0.22))
                )
            }
        }
    }

    private func drawMeadowTexture(in context: inout GraphicsContext, size: CGSize) {
        for index in 0..<180 {
            let x = size.width * CGFloat((index * 37 + 11) % 100) / 100
            let y = size.height * CGFloat((index * 53 + 19) % 100) / 100
            guard y > size.height * 0.10, y < size.height * 0.91 else { continue }
            let flower = index.isMultiple(of: 9)
            let width = flower ? CGFloat(4) : CGFloat(8 + (index % 4) * 3)
            let height = flower ? CGFloat(4) : CGFloat(2)
            let color = flower
                ? Color(hex: [0xF3E5A3, 0xE9B7A0, 0xEAF1D7][index % 3]).opacity(0.52)
                : Color(hex: [0x4F7C42, 0x6D9652, 0xD6CE86][index % 3]).opacity(0.20)
            let mark = Path(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: height / 2)
            context.translateBy(x: x, y: y)
            context.rotate(by: .degrees(Double((index * 29) % 70) - 35))
            context.translateBy(x: -x, y: -y)
            context.fill(mark, with: .color(color))
            context.transform = .identity
        }
    }

    private func drawVignette(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.clear,
                    Color(hex: 0x143526).opacity(0.22)
                ]),
                center: CGPoint(x: size.width * 0.50, y: size.height * 0.48),
                startRadius: size.width * 0.24,
                endRadius: size.height * 0.72
            )
        )
    }
}

private struct GardenFireflies: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allowsMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        if allowsMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 18.0)) { context in
                content(phase: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            content(phase: 0)
        }
    }

    private func content(phase: TimeInterval) -> some View {
        GeometryReader { proxy in
            ForEach(0..<12, id: \.self) { index in
                let baseX = Double((index * 37 + 18) % 100) / 100
                let baseY = Double((index * 23 + 34) % 100) / 100
                let seed = Double(index) * 0.73
                let driftX = allowsMotion ? sin(phase * 0.16 + seed) * 0.030 : 0
                let driftY = allowsMotion ? cos(phase * 0.12 + seed * 1.4) * 0.018 : 0
                let glow = allowsMotion ? 0.62 + 0.38 * sin(phase * 0.92 + seed * 2.1) : 0.85
                Circle()
                    .fill(Color(hex: 0xFFE891).opacity((index.isMultiple(of: 3) ? 0.70 : 0.42) * glow))
                    .frame(
                        width: CGFloat(3 + index % 3) + CGFloat(glow) * 1.2,
                        height: CGFloat(3 + index % 3) + CGFloat(glow) * 1.2
                    )
                    .shadow(color: Color(hex: 0xFFE891).opacity(0.54 * glow), radius: 5 + CGFloat(glow) * 3)
                    .position(
                        x: CGFloat(gardenUnitClamp(baseX + driftX)) * proxy.size.width,
                        y: CGFloat(gardenUnitClamp(baseY + driftY)) * proxy.size.height
                    )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GardenMemoryHeader: View {
    let traceCount: Int
    let quietCount: Int
    let atmosphere: GardenAtmosphereKind
    let onOpenBoard: () -> Void

    private var subtitle: String {
        traceCount == 0 ? "Quiet world" : "\(traceCount) visible trace\(traceCount == 1 ? "" : "s")"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onOpenBoard) {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .luminaFont(size: 12, weight: .black)
                        .foregroundColor(Color(hex: 0xF7F0D3))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: 0x3F633B).opacity(0.78))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Lumia Garden")
                            .luminaFont(size: 14, weight: .black, design: .rounded)
                            .foregroundColor(Color(hex: 0x24472A))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(subtitle)
                            .luminaFont(size: 9, weight: .bold)
                            .foregroundColor(Color(hex: 0x5E6A4F))
                            .lineLimit(1)
                    }

                    if quietCount > 0 {
                        Text("\(quietCount)")
                            .luminaFont(size: 10, weight: .black, design: .rounded)
                            .foregroundColor(Color(hex: 0xF8F0D2))
                            .frame(width: 24, height: 24)
                            .background(Color(hex: 0x55724A).opacity(0.90))
                            .clipShape(Circle())
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, quietCount > 0 ? 8 : 12)
                .padding(.vertical, 6)
                .background(Color(hex: 0xF9F0D8).opacity(0.34))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.26), lineWidth: 1))
            }
            .buttonStyle(GardenPressableButtonStyle(pressedScale: 0.97, pressedOpacity: 0.90))
            .accessibilityLabel("Open Garden memory shelf")

            Spacer(minLength: 0)

            GardenAtmosphereChip(atmosphere: atmosphere)
        }
    }
}

private struct GardenAtmosphereChip: View {
    let atmosphere: GardenAtmosphereKind

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: atmosphere.systemImage)
                .luminaFont(size: 10, weight: .black)
            Text(atmosphere.title)
                .luminaFont(size: 10, weight: .black, design: .rounded)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .foregroundColor(Color(hex: 0xFFF8DC))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(atmosphere.tint.opacity(0.58))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
        .shadow(color: Color(hex: 0x17381F).opacity(0.10), radius: 8, x: 0, y: 4)
        .accessibilityLabel("Garden atmosphere, \(atmosphere.title)")
    }
}

private struct GardenMemoryWhisperBar: View {
    let totalCount: Int
    let onOpenBoard: () -> Void

    private var title: String {
        totalCount == 0 ? "Leave a trace" : "Memory shelf"
    }

    var body: some View {
        Button(action: onOpenBoard) {
            HStack(spacing: 8) {
                Image(systemName: totalCount == 0 ? "leaf.fill" : "tray.full.fill")
                    .luminaFont(size: 11, weight: .black)
                    .foregroundColor(Color(hex: 0x48613A))
                    .frame(width: 24, height: 24)
                    .background(Color(hex: 0xF5EAC6).opacity(0.86))
                    .clipShape(Circle())

                Text(title)
                    .luminaFont(size: 10, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0xF8F0D2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if totalCount > 0 {
                    Text("\(totalCount)")
                        .luminaFont(size: 10, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x2D3C24))
                        .frame(width: 22, height: 22)
                        .background(Color(hex: 0xF5EAC6).opacity(0.82))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color(hex: 0x3D4A32).opacity(0.24))
                    .overlay(Capsule().stroke(Color(hex: 0xF1E4BC).opacity(0.24), lineWidth: 1))
            )
        }
        .buttonStyle(GardenPressableButtonStyle(pressedScale: 0.97, pressedOpacity: 0.88))
        .accessibilityLabel(totalCount == 0 ? "Begin Garden memory" : "Open Garden memory shelf")
    }
}

private struct GardenFirstVisitGuideOverlay: View {
    let step: GardenFirstVisitGuideStep
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: 0x0C1B12).opacity(0.18),
                        Color(hex: 0x0C1B12).opacity(0.08),
                        Color(hex: 0x0C1B12).opacity(0.24)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                GardenFirstVisitFocusHalo(step: step)
                    .position(
                        x: proxy.size.width * step.focusAnchor.x,
                        y: proxy.size.height * step.focusAnchor.y
                    )
                    .allowsHitTesting(false)

                if step.placesCardAtTop {
                    VStack(spacing: 0) {
                        GardenFirstVisitGuideCard(
                            step: step,
                            onBack: onBack,
                            onNext: onNext,
                            onSkip: onSkip
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, max(proxy.safeAreaInsets.top + 72, 96))

                        Spacer(minLength: 0)
                    }
                    .zIndex(2)
                } else {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        GardenFirstVisitGuideCard(
                            step: step,
                            onBack: onBack,
                            onNext: onNext,
                            onSkip: onSkip
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom + 104, 118))
                    }
                    .zIndex(2)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct GardenFirstVisitFocusHalo: View {
    let step: GardenFirstVisitGuideStep
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    private var allowsMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: step.focusCornerRadius, style: .continuous)
                .fill(Color(hex: 0xFFF7D6).opacity(0.08))
                .frame(width: step.focusSize.width, height: step.focusSize.height)
                .blur(radius: 2)

            RoundedRectangle(cornerRadius: step.focusCornerRadius, style: .continuous)
                .stroke(Color(hex: 0xFFF8E8).opacity(0.78), lineWidth: 1.4)
                .frame(width: step.focusSize.width, height: step.focusSize.height)
                .shadow(color: step.tint.opacity(0.36), radius: 18, x: 0, y: 0)
                .scaleEffect(isBreathing && allowsMotion ? 1.025 : 1.0)

            Image(systemName: step.systemImage)
                .luminaFont(size: 15, weight: .black)
                .foregroundColor(Color(hex: 0xFFF8E8))
                .frame(width: 36, height: 36)
                .background(step.tint.opacity(0.96))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(hex: 0xFFF8E8).opacity(0.70), lineWidth: 1))
                .offset(x: step.focusSize.width * 0.42, y: -step.focusSize.height * 0.42)

            HStack(spacing: 6) {
                Image(systemName: step.systemImage)
                    .luminaFont(size: 10, weight: .black)
                Text(step.focusLabel)
                    .luminaFont(size: 11, weight: .black, design: .rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundColor(Color(hex: 0xFFF8E8))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(step.tint.opacity(0.92))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hex: 0xFFF8E8).opacity(0.58), lineWidth: 1))
            .shadow(color: Color(hex: 0x17381F).opacity(0.18), radius: 10, x: 0, y: 5)
            .offset(y: step.focusSize.height * 0.50 + 18)
        }
        .frame(width: step.focusSize.width + 84, height: step.focusSize.height + 104)
        .animation(allowsMotion ? .easeInOut(duration: 1.9).repeatForever(autoreverses: true) : nil, value: isBreathing)
        .onAppear {
            guard allowsMotion else { return }
            isBreathing = true
        }
    }
}

private struct GardenFirstVisitGuideCard: View {
    let step: GardenFirstVisitGuideStep
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: step.systemImage)
                    .luminaFont(size: 16, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 38, height: 38)
                    .background(step.tint)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Garden")
                            .luminaFont(size: 11, weight: .black)
                            .foregroundColor(Color(hex: 0x82725B))
                            .textCase(.uppercase)
                        Text(step.stepText)
                            .luminaFont(size: 10, weight: .black, design: .rounded)
                            .foregroundColor(step.tint)
                    }

                    Text(step.title)
                        .luminaFont(size: 20, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x3F3428))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(step.detail)
                        .luminaFont(size: 13, weight: .semibold)
                        .foregroundColor(Color(hex: 0x6F604B))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
            }

            HStack(spacing: 6) {
                ForEach(GardenFirstVisitGuideStep.allCases) { guideStep in
                    Capsule()
                        .fill(guideStep == step ? step.tint : Color(hex: 0xD8C7A2))
                        .frame(width: guideStep == step ? 24 : 7, height: 7)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button(action: onSkip) {
                    Text("Skip")
                        .luminaFont(size: 13, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x6F604B))
                        .frame(width: 72, height: 44)
                        .background(Color(hex: 0xF3E7CB).opacity(0.86))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if step.previous != nil {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .luminaFont(size: 13, weight: .black)
                            .foregroundColor(Color(hex: 0x6F604B))
                            .frame(width: 44, height: 44)
                            .background(Color(hex: 0xF3E7CB).opacity(0.86))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }

                Spacer(minLength: 0)

                Button(action: onNext) {
                    HStack(spacing: 8) {
                        Text(step.primaryActionTitle)
                            .lineLimit(1)
                        Image(systemName: step.next == nil ? "checkmark" : "arrow.right")
                    }
                    .luminaFont(size: 14, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(step.tint)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(hex: 0xFFF8E8).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(hex: 0xE0C68E).opacity(0.74), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x17381F).opacity(0.18), radius: 22, x: 0, y: 12)
    }
}

private struct GardenGameHUD: View {
    let waterDrops: Int
    let completedCount: Int
    let totalCount: Int
    let averageGrowth: Int
    let nextMove: GardenNextMove
    let readyTracePromptCount: Int
    let onOpenBoard: () -> Void

    private var progress: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(completedCount) / CGFloat(totalCount)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpenBoard) {
                HStack(spacing: 9) {
                    Image(systemName: "leaf.fill")
                        .luminaFont(size: 14, weight: .black)
                        .foregroundColor(Color(hex: 0xF4F0D9))
                        .frame(width: 30, height: 30)
                        .background(Color(hex: 0x42683D).opacity(0.92))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Lumia Grove")
                            .luminaFont(size: 15, weight: .black, design: .rounded)
                            .foregroundColor(Color(hex: 0x24472A))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(totalCount == 0 ? "Quiet world" : "\(totalCount) visible trace\(totalCount == 1 ? "" : "s")")
                            .luminaFont(size: 9, weight: .bold)
                            .foregroundColor(Color(hex: 0x63714D))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 11)
                .padding(.vertical, 6)
                .background(Color(hex: 0xFFF7DE).opacity(0.58))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.44), lineWidth: 1))
                .shadow(color: Color(hex: 0x18371E).opacity(0.08), radius: 7, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Garden memory")

            Spacer(minLength: 6)

            GardenHUDChip(value: "\(waterDrops)", icon: "drop.fill", tint: Color(hex: 0x309FD2), label: "Dew")
        }
    }
}

private struct GardenGroveCue: View {
    let totalCount: Int
    let nextMove: GardenNextMove
    let onOpenBoard: () -> Void

    private var title: String {
        totalCount == 0 ? "Begin with one trace" : "\(totalCount) quiet trace\(totalCount == 1 ? "" : "s")"
    }

    private var detail: String {
        totalCount == 0 ? "Let the grove keep one small action." : "Tap a keepsake to open what it remembers."
    }

    var body: some View {
        Button(action: onOpenBoard) {
            HStack(spacing: 10) {
                Image(systemName: totalCount == 0 ? "leaf.fill" : "sparkles")
                    .luminaFont(size: 13, weight: .black)
                    .foregroundColor(Color(hex: 0xEAF0D2))
                    .frame(width: 30, height: 30)
                    .background(Color(hex: 0x516D43).opacity(0.88))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .luminaFont(size: 13, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0xFFF7DE))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(detail)
                        .luminaFont(size: 10, weight: .bold)
                        .foregroundColor(Color(hex: 0xF3E6C3).opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 6)

                Text(totalCount == 0 ? "Start" : "Open")
                    .luminaFont(size: 11, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0x34432C))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color(hex: 0xF6E8BD).opacity(0.94))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color(hex: 0x29361F).opacity(0.72))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hex: 0xF4E8C4).opacity(0.22), lineWidth: 1))
            .shadow(color: Color(hex: 0x102115).opacity(0.20), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(totalCount == 0 ? "Begin Garden" : "Open Garden memory")
    }
}

private struct GardenHUDChip: View {
    let value: String
    let icon: String
    let tint: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .luminaFont(size: 12, weight: .black)
                .foregroundColor(tint)
            Text(value)
                .luminaFont(size: 14, weight: .black, design: .rounded)
                .foregroundColor(Color(hex: 0x4D4032))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .accessibilityLabel("\(label) \(value)")
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color(hex: 0xFFF8E8).opacity(0.76))
        .clipShape(Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct GardenArrangeHint: View {
    let selectedArrangementType: GardenDecorationType
    let canAfford: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: selectedArrangementType.systemImage)
                .luminaFont(size: 13, weight: .black)
                .foregroundColor(Color(hex: 0xFFFDF4))
                .frame(width: 28, height: 28)
                .background(selectedArrangementType.tint)
                .clipShape(Circle())

            Text(selectedArrangementType.title)
                .luminaFont(size: 12, weight: .black, design: .rounded)
                .foregroundColor(Color(hex: 0x3F3428))
                .lineLimit(1)

            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .luminaFont(size: 10, weight: .black)
                    .foregroundColor(Color(hex: 0x309FD2))
                Text("\(selectedArrangementType.dewCost)")
                    .luminaFont(size: 12, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0x4D4032))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(hex: 0xFFF8E8).opacity(0.90))
            .clipShape(Capsule())

            Text(canAfford ? "Tap a trace" : "Gather dew first")
                .luminaFont(size: 11, weight: .heavy)
                .foregroundColor(canAfford ? Color(hex: 0x5FA461) : Color(hex: 0xA06B3B))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(hex: 0xFFF7DE).opacity(0.72))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.56), lineWidth: 1))
        .shadow(color: Color(hex: 0x18371E).opacity(0.12), radius: 9, x: 0, y: 5)
        .padding(.horizontal, 22)
    }
}

private struct GardenToolbelt: View {
    @Binding var selectedTool: GardenTool
    @Binding var selectedArrangementType: GardenDecorationType

    var body: some View {
        HStack(spacing: 10) {
            ForEach(GardenTool.allCases) { tool in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if tool == .arrange && selectedTool == .arrange {
                            selectedArrangementType = selectedArrangementType.next
                        } else {
                            selectedTool = tool
                        }
                    }
                } label: {
                    HStack(spacing: selectedTool == tool ? 6 : 0) {
                        Image(systemName: tool == .arrange && selectedTool == .arrange ? selectedArrangementType.systemImage : tool.systemImage)
                            .luminaFont(size: 16, weight: .black)
                        if selectedTool == tool {
                            Text(tool == .arrange ? selectedArrangementType.title : tool.title)
                                .luminaFont(size: 12, weight: .black, design: .rounded)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                    .foregroundColor(selectedTool == tool ? Color(hex: 0xFFFDF4) : tool.tint)
                    .frame(width: selectedTool == tool ? (tool == .arrange ? 118 : 88) : 40, height: 40)
                    .background(selectedTool == tool ? (tool == .arrange ? selectedArrangementType.tint : tool.tint) : Color(hex: 0xFFF8E8).opacity(0.92))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedTool == tool ? Color.white.opacity(0.48) : Color.white.opacity(0.62), lineWidth: 1)
                    )
                }
                .buttonStyle(GardenPressableButtonStyle(pressedScale: 0.94, pressedOpacity: 0.90))
                .accessibilityLabel(tool == .arrange ? "Arrange \(selectedArrangementType.title)" : tool.title)
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Color(hex: 0x5A442D).opacity(0.82))
                .overlay(Capsule().stroke(Color.white.opacity(0.26), lineWidth: 1))
        )
        .shadow(color: Color(hex: 0x1C3D24).opacity(0.24), radius: 14, x: 0, y: 8)
    }
}

// MARK: - World Scene

private struct GardenWorldScene: View {
    let habits: [Habit]
    let waterDrops: Int
    let selectedTool: GardenTool
    let readyTracePromptCount: Int
    let completedHabitIDsToday: Set<String>
    let isSceneActive: Bool
    let avatarPosition: CGPoint
    let keeperIsWalking: Bool
    let keeperFacesLeft: Bool
    let keeperAmbientMood: GardenKeeperMood
    let focusedHabitID: String?
    let decorations: [GardenDecoration]
    let forageItems: [GardenForageItem]
    let keepsakes: [GardenKeepsake]
    let unlockedAreas: [GardenMapAreaUnlock]
    let completedAreaKindsToday: Set<GardenMapAreaKind>
    let areaVisitCounts: [GardenMapAreaKind: Int]
    let areaMilestoneStages: [GardenMapAreaKind: Set<Int>]
    let visitorInvitation: GardenVisitorInvitation?
    let visitorInvitationProgress: Int
    let recentlyWateredHabitID: String?
    let onBoardTap: () -> Void
    let onWateringCanTap: () -> Void
    let onForageTap: (GardenForageItem) -> Void
    let onAreaTap: (GardenMapAreaUnlock) -> Void
    let onVisitorTap: (GardenVisitorInvitation) -> Void
    let onPlotTap: (Habit) -> Void

    var body: some View {
        GeometryReader { proxy in
            let visibleHabits = Array(habits.prefix(3))
            let visibleKeepsakes = Array(keepsakes.prefix(max(0, 3 - visibleHabits.count)))
            let areaStageCount = areaMilestoneStages.values.reduce(0) { $0 + $1.count }
            let memoryDepth = habits.count + keepsakes.count + areaStageCount
            let pathTraceCount = max(visibleHabits.count + visibleKeepsakes.count, min(memoryDepth, gardenPlotPositions.count))
            let resolvedAvatarPosition = resolvedKeeperPosition(avatarPosition, avoiding: visitorInvitation)

            ZStack {
                GardenMemoryPathLayer(traceCount: pathTraceCount)
                    .opacity(memoryDepth > 3 ? min(0.10 + Double(memoryDepth) * 0.012, 0.22) : 0)
                    .blendMode(.softLight)
                    .zIndex(0.05)

                ForEach(unlockedAreas) { unlock in
                    GardenAreaVisualUnlockCluster(
                        area: unlock.area,
                        unlockedStages: areaMilestoneStages[unlock.area] ?? []
                    )
                    .scaleEffect(sceneDepthScale(for: CGFloat(unlock.area.mapPosition.y)) * 0.94, anchor: .bottom)
                    .position(
                        x: proxy.size.width * unlock.area.mapPosition.x,
                        y: proxy.size.height * unlock.area.mapPosition.y
                    )
                    .zIndex(Double(unlock.area.mapPosition.y) - 0.08)
                }

                ForEach(decorations) { decoration in
                    let size = decorationSize(for: decoration.type)
                    GardenDecorationNode(type: decoration.type)
                        .frame(width: size.width, height: size.height)
                        .scaleEffect(sceneDepthScale(for: CGFloat(decoration.y)), anchor: .bottom)
                        .position(
                            x: proxy.size.width * decoration.x,
                            y: proxy.size.height * decoration.y
                        )
                        .zIndex(decoration.y + 0.02)
                }

                ForEach(Array(visibleKeepsakes.enumerated()), id: \.element.id) { index, keepsake in
                    let keepsakePosition = keepsakePosition(for: index)
                    let keepsakeScale = sceneDepthScale(for: keepsakePosition.y) * 0.96
                    GardenKeepsakeNode(keepsake: keepsake)
                        .scaleEffect(keepsakeScale, anchor: .bottom)
                        .position(
                            x: proxy.size.width * keepsakePosition.x,
                            y: proxy.size.height * keepsakePosition.y
                        )
                        .zIndex(Double(keepsakePosition.y))
                        .accessibilityLabel(keepsake.kind.title)
                }

                ForEach(Array(visibleHabits.enumerated()), id: \.element.id) { index, habit in
                    let isCompletedToday = completedHabitIDsToday.contains(habit.id)
                    Button {
                        onPlotTap(habit)
                    } label: {
                        GardenTraceNode(
                            habit: habit,
                            displayIndex: index,
                            mapY: gardenPlotPositions[index].y,
                            tool: selectedTool,
                            canWater: waterDrops > 0 && habit.plantType != .tree,
                            isCompletedToday: isCompletedToday,
                            isWatering: recentlyWateredHabitID == habit.id,
                            isFocused: focusedHabitID == habit.id
                        )
                    }
                    .buttonStyle(GardenPressableButtonStyle(pressedScale: 0.95, pressedOpacity: 0.90))
                    .accessibilityLabel(habit.title)
                    .accessibilityHint(selectedTool == .explore ? "Open this garden trace" : "Use selected garden tool")
                    .position(
                        x: proxy.size.width * gardenPlotPositions[index].x,
                        y: proxy.size.height * gardenPlotPositions[index].y
                    )
                    .zIndex(Double(gardenPlotPositions[index].y) + 0.06)
                }

                ForEach(unlockedAreas) { unlock in
                    Button {
                        onAreaTap(unlock)
                    } label: {
                        GardenAreaWhisperNode(
                            unlock: unlock,
                            isCompletedToday: completedAreaKindsToday.contains(unlock.area),
                            completedStageCount: areaMilestoneStages[unlock.area]?.count ?? 0
                        )
                    }
                    .buttonStyle(GardenPressableButtonStyle(pressedScale: 0.94, pressedOpacity: 0.88))
                    .accessibilityLabel("\(unlock.area.title), \(completedAreaKindsToday.contains(unlock.area) ? "already settled" : "open grove corner")")
                    .scaleEffect(sceneDepthScale(for: CGFloat(unlock.area.mapPosition.y)) * 0.92, anchor: .bottom)
                    .position(
                        x: proxy.size.width * unlock.area.mapPosition.x,
                        y: proxy.size.height * unlock.area.mapPosition.y
                    )
                    .zIndex(Double(unlock.area.mapPosition.y) + 0.08)
                }

                ForEach(Array(forageItems.prefix(3))) { item in
                    Button {
                        onForageTap(item)
                    } label: {
                        GardenForageNode(item: item)
                    }
                    .buttonStyle(GardenPressableButtonStyle(pressedScale: 0.88, pressedOpacity: 0.86))
                    .accessibilityLabel("Gather soft dew")
                    .scaleEffect(sceneDepthScale(for: CGFloat(item.y)) * 0.84, anchor: .bottom)
                    .position(
                        x: proxy.size.width * item.x,
                        y: proxy.size.height * item.y
                    )
                    .zIndex(item.y + 0.12)
                }

                if let visitorInvitation {
                    Button {
                        onVisitorTap(visitorInvitation)
                    } label: {
                        GardenVisitorNode(
                            invitation: visitorInvitation,
                            progress: visitorInvitationProgress,
                            isSceneActive: isSceneActive
                        )
                    }
                    .buttonStyle(GardenPressableButtonStyle(pressedScale: 0.96, pressedOpacity: 0.90))
                    .accessibilityLabel("Meet \(visitorInvitation.visitor.displayName)")
                    .scaleEffect(sceneDepthScale(for: CGFloat(visitorInvitation.y)) * 1.02, anchor: .bottom)
                    .position(
                        x: proxy.size.width * visitorInvitation.x,
                        y: proxy.size.height * visitorInvitation.y
                    )
                    .zIndex(visitorInvitation.y + 0.16)
                }

                GardenKeeperAvatar(
                    mood: keeperMood(
                        hasTraces: !habits.isEmpty,
                        isWalking: keeperIsWalking,
                        selectedTool: selectedTool,
                        focusedHabitID: focusedHabitID,
                        isWatering: recentlyWateredHabitID != nil,
                        hasReadyChange: readyTracePromptCount > 0,
                        ambientMood: keeperAmbientMood
                    ),
                    facesLeft: keeperFacesLeft,
                    isSceneActive: isSceneActive,
                    showsWaterBurst: recentlyWateredHabitID != nil
                )
                    .frame(width: 172, height: 188)
                    .scaleEffect(sceneDepthScale(for: resolvedAvatarPosition.y) * 0.94, anchor: .bottom)
                    .position(
                        x: proxy.size.width * resolvedAvatarPosition.x,
                        y: proxy.size.height * resolvedAvatarPosition.y
                    )
                    .zIndex(Double(resolvedAvatarPosition.y) + 0.10)

            }
        }
    }

    private func nextMilestone(for area: GardenMapAreaKind) -> GardenAreaMilestoneDefinition? {
        let unlockedStages = areaMilestoneStages[area] ?? []
        return area.milestoneDefinitions.first { !unlockedStages.contains($0.stage) }
    }

    private func decorationSize(for type: GardenDecorationType) -> CGSize {
        switch type {
        case .lamp:
            return CGSize(width: 42, height: 56)
        case .stones:
            return CGSize(width: 54, height: 36)
        case .flowers:
            return CGSize(width: 58, height: 48)
        }
    }

    private func keepsakePosition(for index: Int) -> CGPoint {
        return gardenKeepsakePositions[index % gardenKeepsakePositions.count]
    }

    private func sceneDepthScale(for y: CGFloat) -> CGFloat {
        min(max(0.72 + y * 0.54, 0.82), 1.10)
    }

    private func resolvedKeeperPosition(_ position: CGPoint, avoiding invitation: GardenVisitorInvitation?) -> CGPoint {
        guard let invitation else { return position }
        let visitorPosition = CGPoint(x: invitation.x, y: invitation.y)
        let overlapsVisitor = abs(position.x - visitorPosition.x) < 0.18 && abs(position.y - visitorPosition.y) < 0.14
        guard overlapsVisitor else { return position }

        let horizontalOffset = position.x <= visitorPosition.x ? -0.20 : 0.20
        return CGPoint(
            x: min(max(position.x + horizontalOffset, 0.18), 0.82),
            y: min(max(position.y + 0.08, 0.48), 0.68)
        )
    }

    private func keeperMood(
        hasTraces: Bool,
        isWalking: Bool,
        selectedTool: GardenTool,
        focusedHabitID: String?,
        isWatering: Bool,
        hasReadyChange: Bool,
        ambientMood: GardenKeeperMood
    ) -> GardenKeeperMood {
        if isWalking { return .walking }
        if isWatering { return .tending }
        if focusedHabitID != nil { return selectedTool == .tend ? .tending : .inspecting }
        if hasReadyChange || selectedTool == .arrange { return .placing }
        return hasTraces ? ambientMood : .waiting
    }
}

private struct GardenSceneObjectButton: View {
    let assetName: String
    let title: String
    let badgeSystemImage: String?
    var badgeText: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .shadow(color: Color(hex: 0x17381F).opacity(0.26), radius: 8, x: 0, y: 6)

                if let badgeSystemImage {
                    HStack(spacing: 3) {
                        Image(systemName: badgeSystemImage)
                            .luminaFont(size: 8, weight: .black)
                        if let badgeText {
                            Text(badgeText)
                                .luminaFont(size: 9, weight: .black, design: .rounded)
                        }
                    }
                    .foregroundColor(Color(hex: 0xFFFBEA))
                    .frame(minWidth: badgeText == nil ? 19 : 31, minHeight: 19)
                    .padding(.horizontal, badgeText == nil ? 0 : 4)
                    .background(Color(hex: 0x4E7B49).opacity(0.96))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.58), lineWidth: 1))
                    .shadow(color: Color(hex: 0x17381F).opacity(0.16), radius: 4, x: 0, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct GardenForageNode: View {
    let item: GardenForageItem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allowsIdleMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var seed: Double {
        gardenMotionSeed(from: item.id)
    }

    var body: some View {
        if allowsIdleMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                content(phase: context.date.timeIntervalSinceReferenceDate + seed * 0.013)
            }
        } else {
            content(phase: seed * 0.013)
        }
    }

    @ViewBuilder
    private func content(phase: TimeInterval) -> some View {
        let pulse = 0.5 + 0.5 * sin(phase * 1.45)
        let glint = 0.5 + 0.5 * sin(phase * 2.2 + 0.6)

        ZStack {
            Circle()
                .fill(Color(hex: 0xFFF4A8).opacity(0.16 + pulse * 0.11))
                .frame(width: 30 + CGFloat(pulse) * 5, height: 30 + CGFloat(pulse) * 5)
                .blur(radius: 8)

            Circle()
                .stroke(Color(hex: 0xFFFBEA).opacity(0.18 + (1 - pulse) * 0.50), lineWidth: 1.3)
                .frame(width: 19 + CGFloat(pulse) * 10, height: 19 + CGFloat(pulse) * 10)

            ForEach(0..<3, id: \.self) { index in
                let angle = phase * (0.36 + Double(index) * 0.04) + Double(index) * 2.15
                Circle()
                    .fill(Color(hex: 0xFFF8D6).opacity(0.30 + glint * 0.28))
                    .frame(width: CGFloat(index == 0 ? 3 : 2), height: CGFloat(index == 0 ? 3 : 2))
                    .offset(
                        x: CGFloat(cos(angle) * Double(9 + index * 2)),
                        y: CGFloat(sin(angle) * Double(5 + index))
                    )
            }

            Image(systemName: "drop.fill")
                .luminaFont(size: 11, weight: .black)
                .foregroundColor(Color(hex: 0x54BFE8))
                .shadow(color: Color(hex: 0xFFF4A8).opacity(0.82), radius: 5, x: 0, y: 0)
                .scaleEffect(0.98 + CGFloat(glint) * 0.06)
                .offset(y: CGFloat(-1.4 * pulse))
        }
        .frame(width: 44, height: 44)
    }
}

private struct GardenGroundShadow: View {
    let width: CGFloat
    let height: CGFloat
    var opacity: Double = 0.16
    var blurRadius: CGFloat = 0.5

    private var assetName: String {
        if width <= 44 {
            return "GardenGroundShadowSoft05"
        }
        if width >= 72 {
            return "GardenGroundShadowSoft03"
        }
        return "GardenGroundShadowSoft02"
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: width, height: max(height * 2.6, height + 8))
            .opacity(min(max(opacity / 0.16, 0.35), 1.10))
            .blur(radius: blurRadius * 0.35)
            .blendMode(.multiply)
            .accessibilityHidden(true)
    }
}

@MainActor
private enum GardenSpriteImageCache {
    private static var images: [String: UIImage] = [:]

    static func image(named name: String) -> UIImage? {
        if let image = images[name] {
            return image
        }

        guard let image = UIImage(named: name) else {
            return nil
        }

        images[name] = image
        return image
    }

    static func preload(_ names: [String]) {
        for name in Set(names) {
            _ = image(named: name)
        }
    }
}

private struct GardenAnimatedSprite: View {
    private struct FrameState {
        let currentIndex: Int
    }

    let assetNames: [String]
    var frameDuration: TimeInterval = 0.56
    var repeats: Bool = true
    var isActive: Bool = true
    var sequenceStartDate: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentFrameIndex = 0

    private var allowsFrameAnimation: Bool {
        assetNames.count > 1 && isActive && !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var effectiveFrameDuration: TimeInterval {
        gardenEffectiveSpriteFrameDuration(frameDuration)
    }

    private var playbackIdentity: String {
        [
            assetNames.joined(separator: "|"),
            String(format: "%.3f", frameDuration),
            repeats ? "repeat" : "once",
            isActive ? "active" : "paused",
            reduceMotion ? "reduced" : "motion",
            sequenceStartDate.map { String(format: "%.3f", $0.timeIntervalSinceReferenceDate) } ?? "local"
        ].joined(separator: "#")
    }

    var body: some View {
        spriteStack(frameState: FrameState(currentIndex: allowsFrameAnimation ? currentFrameIndex : 0))
        .transaction { transaction in
            transaction.animation = nil
        }
        .onChange(of: assetNames) { _ in
            currentFrameIndex = 0
        }
        .task(id: playbackIdentity) {
            await runPlaybackLoop()
        }
    }

    @MainActor
    private func setFrameIndex(_ index: Int) {
        currentFrameIndex = index
    }

    private func runPlaybackLoop() async {
        setFrameIndex(0)
        guard allowsFrameAnimation, !assetNames.isEmpty, effectiveFrameDuration > 0 else {
            return
        }

        let frameCount = assetNames.count
        var index = 0

        while !Task.isCancelled {
            let nanoseconds = UInt64(effectiveFrameDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }

            if repeats {
                index = (index + 1) % frameCount
            } else {
                index = min(index + 1, frameCount - 1)
            }

            setFrameIndex(index)

            if !repeats && index == frameCount - 1 {
                return
            }
        }
    }

    @ViewBuilder
    private func spriteStack(frameState: FrameState) -> some View {
        if assetNames.isEmpty {
            EmptyView()
        } else {
            let currentIndex = min(max(frameState.currentIndex, 0), assetNames.count - 1)
            if let image = GardenSpriteImageCache.image(named: assetNames[currentIndex]) {
                Image(uiImage: image)
                    .interpolation(.high)
                    .resizable()
                    .scaledToFit()
                    .accessibilityHidden(true)
            } else {
                Color.clear
            }
        }
    }
}

private struct GardenSpritePreloader: View {
    let assetNames: [String]

    var body: some View {
        Color.clear
        .frame(width: 1, height: 1)
        .onAppear {
            GardenSpriteImageCache.preload(assetNames)
        }
        .onChange(of: assetNames) { newAssetNames in
            GardenSpriteImageCache.preload(newAssetNames)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct GardenVisitorNode: View {
    let invitation: GardenVisitorInvitation
    let progress: Int
    let isSceneActive: Bool

    private var isReady: Bool {
        invitation.isAccepted && progress >= invitation.targetCount
    }

    private var badgeText: String {
        if isReady {
            return "!"
        }
        if invitation.isAccepted {
            return "\(min(progress, invitation.targetCount))/\(invitation.targetCount)"
        }
        return "?"
    }

    private var visitorFrames: [String] {
        if isReady {
            return invitation.visitor.offerSpriteAssetNames
        }
        if invitation.isAccepted {
            return invitation.visitor.idleSpriteAssetNames
        }
        return invitation.visitor.idleSpriteAssetNames
    }

    private var visitorFrameDuration: TimeInterval {
        if isReady { return invitation.visitor.offerFrameDuration }
        return invitation.visitor.idleFrameDuration
    }

    private var visitorRepeatsFrames: Bool {
        !isReady
    }

    var body: some View {
        ZStack {
            GardenGroundShadow(width: 68, height: 12, opacity: 0.15, blurRadius: 0.7)
                .offset(y: 52)

            if isReady {
                Circle()
                    .fill(Color(hex: 0xFFE891).opacity(0.18))
                    .frame(width: 86, height: 86)
                    .blur(radius: 12)
                    .offset(y: 2)
            }

            GardenAnimatedSprite(
                assetNames: visitorFrames,
                frameDuration: visitorFrameDuration,
                repeats: visitorRepeatsFrames,
                isActive: isSceneActive
            )
                .id(visitorFrames.joined(separator: "|"))
                .frame(width: 148, height: 164)
                .shadow(color: Color(hex: 0x17381F).opacity(0.18), radius: 4, x: 0, y: 3)
                .offset(y: -12)

            GardenSpritePreloader(assetNames: visitorFrames)

            if invitation.isAccepted || isReady {
                GardenVisitorStatusBadge(
                    text: badgeText,
                    systemImage: isReady ? "gift.fill" : nil,
                    tint: invitation.visitor.accent
                )
                .offset(x: 38, y: -42)
            }
        }
        .frame(width: 154, height: 172)
    }
}

private struct GardenVisitorStatusBadge: View {
    let text: String
    let systemImage: String?
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .luminaFont(size: 9, weight: .black)
            } else {
                Text(text)
                    .luminaFont(size: text.count > 1 ? 9 : 12, weight: .black, design: .rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .foregroundColor(systemImage == nil ? Color(hex: 0x5B4630) : Color(hex: 0xFFF8E8))
        .frame(minWidth: 24, minHeight: 22)
        .padding(.horizontal, text.count > 1 ? 5 : 0)
        .background(systemImage == nil ? Color(hex: 0xFFF8E8).opacity(0.96) : tint)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.66), lineWidth: 1))
        .shadow(color: Color(hex: 0x17381F).opacity(0.12), radius: 5, x: 0, y: 3)
    }
}

private struct GardenKeepsakeNode: View {
    let keepsake: GardenKeepsake
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allowsIdleMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var seed: Double {
        gardenMotionSeed(from: keepsake.id)
    }

    var body: some View {
        if allowsIdleMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                content(phase: context.date.timeIntervalSinceReferenceDate + seed * 0.017)
            }
        } else {
            content(phase: seed * 0.017)
        }
    }

    @ViewBuilder
    private func content(phase: TimeInterval) -> some View {
        let breath = 0.5 + 0.5 * sin(phase * 0.82)
        let tinySway = sin(phase * 0.54 + 0.4)
        let lanternPulse = keepsake.kind == .sunLantern ? breath : 0
        let charmSway = keepsake.kind == .pathCharm ? tinySway * 1.8 : 0
        let archiveLift = keepsake.kind == .seedArchive ? sin(phase * 0.44) * 0.8 : 0

        ZStack {
            GardenGroundShadow(width: 48, height: 10, opacity: 0.13, blurRadius: 1.2)
                .offset(y: 25)

            GardenTraceNest(
                tint: keepsake.kind.tint,
                variant: keepsake.kind.rawValue.unicodeScalars.reduce(0) { $0 + Int($1.value) },
                intensity: 0.50
            )
            .offset(y: 15)
            .scaleEffect(0.58)
            .blendMode(.multiply)

            Circle()
                .fill(keepsake.kind.tint.opacity(0.08 + breath * 0.09 + lanternPulse * 0.05))
                .frame(width: 56 + CGFloat(breath) * 8, height: 56 + CGFloat(breath) * 8)
                .blur(radius: 10)
                .offset(y: 2)

            if keepsake.kind == .sunLantern {
                Circle()
                    .fill(Color(hex: 0xFFE891).opacity(0.12 + breath * 0.16))
                    .frame(width: 42 + CGFloat(breath) * 10, height: 42 + CGFloat(breath) * 10)
                    .blur(radius: 8)
                    .offset(y: 0)
            }

            Image(keepsake.kind.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: keepsake.kind == .sunLantern ? 52 : 58, height: keepsake.kind == .pathCharm ? 72 : 60)
                .opacity(0.98)
                .shadow(color: Color(hex: 0x17381F).opacity(0.16), radius: 1.2, x: 0, y: 1)
                .shadow(color: Color(hex: 0x17381F).opacity(0.10), radius: 7, x: 0, y: 5)
                .rotationEffect(.degrees(charmSway), anchor: .top)
                .scaleEffect(1.0 + CGFloat(breath) * (keepsake.kind == .sunLantern ? 0.018 : 0.010), anchor: .bottom)
                .offset(y: CGFloat(-archiveLift))

            if keepsake.kind == .seedArchive {
                Capsule()
                    .fill(Color(hex: 0xFFF8D6).opacity(0.28 + breath * 0.22))
                    .frame(width: 30, height: 3)
                    .blur(radius: 2)
                    .rotationEffect(.degrees(-12))
                    .offset(x: 1, y: -16 + CGFloat(archiveLift))
            }
        }
        .frame(width: 84, height: 88)
    }
}

private struct GardenAreaWhisperNode: View {
    let unlock: GardenMapAreaUnlock
    let isCompletedToday: Bool
    let completedStageCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allowsMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var seed: Double {
        gardenMotionSeed(from: unlock.id)
    }

    var body: some View {
        if allowsMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                content(phase: context.date.timeIntervalSinceReferenceDate + seed * 0.011)
            }
        } else {
            content(phase: seed * 0.011)
        }
    }

    @ViewBuilder
    private func content(phase: TimeInterval) -> some View {
        let pulse = 0.5 + 0.5 * sin(phase * 0.72)
        let completedPulse = isCompletedToday ? pulse : 0

        ZStack {
            Circle()
                .fill(Color(hex: 0xFFF8E8).opacity(0.26 + pulse * 0.11))
                .frame(width: 32 + CGFloat(pulse) * 5, height: 32 + CGFloat(pulse) * 5)
                .blur(radius: 6)

            Circle()
                .stroke(unlock.area.tint.opacity(0.18 + completedPulse * 0.20), lineWidth: 1.2)
                .frame(width: 31 + CGFloat(pulse) * 8, height: 31 + CGFloat(pulse) * 8)
                .opacity(0.55 - pulse * 0.24)

            Image(systemName: unlock.area.icon)
                .luminaFont(size: 12, weight: .black)
                .foregroundColor(isCompletedToday ? Color(hex: 0xFFF8E8) : unlock.area.tint)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isCompletedToday ? Color(hex: 0x5FA461).opacity(0.96) : Color(hex: 0xFFFDF4).opacity(0.82))
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: 0xFFF8E8).opacity(0.64), lineWidth: 1)
                )
                .shadow(color: Color(hex: 0x17381F).opacity(0.13), radius: 4, x: 0, y: 3)
                .scaleEffect(1.0 + CGFloat(completedPulse) * 0.05)

            if completedStageCount > 0 {
                Text("\(completedStageCount)")
                    .luminaFont(size: 8, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 16, height: 16)
                    .background(unlock.area.tint)
                    .clipShape(Circle())
                    .offset(x: 14, y: -14)
            }
        }
        .frame(width: 42, height: 42)
    }
}

private struct GardenMapAreaNode: View {
    let unlock: GardenMapAreaUnlock
    let isCompletedToday: Bool
    let visitCount: Int
    let nextMilestone: GardenAreaMilestoneDefinition?
    let completedStageCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progressLabel: String {
        if isCompletedToday {
            return "Seen"
        }
        guard let nextMilestone else {
            return "Settled"
        }
        return "\(min(visitCount, nextMilestone.requiredVisits))/\(nextMilestone.requiredVisits)"
    }

    private var allowsMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var seed: Double {
        gardenMotionSeed(from: unlock.id)
    }

    var body: some View {
        if allowsMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 18.0)) { context in
                content(phase: context.date.timeIntervalSinceReferenceDate + seed * 0.019)
            }
        } else {
            content(phase: seed * 0.019)
        }
    }

    @ViewBuilder
    private func content(phase: TimeInterval) -> some View {
        let pulse = 0.5 + 0.5 * sin(phase * 0.60)

        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(unlock.area.tint.opacity(isCompletedToday ? 0.12 : 0.20))
                .frame(width: 108, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color(hex: 0xFFF8E8).opacity(0.56), lineWidth: 1.2)
                )
                .shadow(color: Color(hex: 0x17381F).opacity(0.14), radius: 10, x: 0, y: 6)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(unlock.area.tint.opacity(0.10 + pulse * 0.12), lineWidth: 1)
                .frame(width: 111 + CGFloat(pulse) * 4, height: 73 + CGFloat(pulse) * 3)
                .blur(radius: 0.4)

            VStack(spacing: 4) {
                Image(systemName: unlock.area.icon)
                    .luminaFont(size: 15, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 28, height: 28)
                    .background(isCompletedToday ? Color(hex: 0x5FA461) : unlock.area.tint.opacity(0.95))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.50), lineWidth: 1))
                    .scaleEffect(1 + CGFloat(isCompletedToday ? pulse * 0.04 : 0))

                VStack(spacing: 1) {
                    Text(unlock.area.title)
                        .luminaFont(size: 10, weight: .black, design: .rounded)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(progressLabel)
                        .luminaFont(size: 8, weight: .black, design: .rounded)
                        .lineLimit(1)
                }
                .foregroundColor(Color(hex: 0xFFF8E8))
                .shadow(color: Color(hex: 0x1F3523).opacity(0.30), radius: 2, x: 0, y: 1)

                HStack(spacing: 3) {
                    ForEach(1...3, id: \.self) { stage in
                        Circle()
                            .fill(stage <= completedStageCount ? Color(hex: 0xFFF8E8) : Color(hex: 0xFFF8E8).opacity(0.28))
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .frame(width: 116, height: 78)
    }
}

private struct GardenAreaVisualUnlockCluster: View {
    let area: GardenMapAreaKind
    let unlockedStages: Set<Int>

    private var visibleMarks: [GardenAreaMapEvolutionDefinition] {
        area.mapEvolutionDefinitions.filter { unlockedStages.contains($0.stage) }
    }

    var body: some View {
        ZStack {
            if !unlockedStages.isEmpty {
                GardenAreaEvolvedGroundPatch(
                    area: area,
                    completedStageCount: unlockedStages.count
                )
            }

            ForEach(visibleMarks) { mark in
                GardenAreaStageMark(area: area, stage: mark.stage)
                    .scaleEffect(mark.scale)
                    .offset(
                        x: CGFloat(mark.localXOffset),
                        y: CGFloat(mark.localYOffset)
                    )
            }
        }
        .frame(width: 184, height: 146)
        .accessibilityHidden(true)
    }
}

private struct GardenAreaEvolvedGroundPatch: View {
    let area: GardenMapAreaKind
    let completedStageCount: Int

    var body: some View {
        ZStack {
            switch area {
            case .pathNook:
                PathNookGroundPatch(completedStageCount: completedStageCount)
            case .lanternGlade:
                LanternGladeGroundPatch(completedStageCount: completedStageCount)
            case .archiveCorner:
                ArchiveCornerGroundPatch(completedStageCount: completedStageCount)
            }
        }
        .frame(width: 176, height: 132)
    }
}

private struct PathNookGroundPatch: View {
    let completedStageCount: Int

    private let stoneOffsets: [(x: CGFloat, y: CGFloat, rotation: Double)] = [
        (-58, 28, -20), (-40, 20, -12), (-24, 14, 8), (-8, 7, -6),
        (10, 3, 11), (28, 0, -10), (45, -8, 7), (58, -20, -14),
        (39, -35, 17), (17, -44, -9), (-7, -42, 6), (-28, -34, -15)
    ]

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color(hex: 0xD8C99E).opacity(0.22))
                .frame(width: 142, height: 44)
                .rotationEffect(.degrees(-22))
                .offset(x: 1, y: -4)

            ForEach(0..<min(stoneOffsets.count, max(1, completedStageCount) * 4), id: \.self) { index in
                let stone = stoneOffsets[index]
                Ellipse()
                    .fill(Color(hex: index.isMultiple(of: 2) ? 0xE6D6B9 : 0xC9B38E))
                    .frame(width: 18, height: 11)
                    .overlay(Ellipse().stroke(Color(hex: 0xA28A68).opacity(0.78), lineWidth: 0.8))
                    .rotationEffect(.degrees(stone.rotation))
                    .offset(x: stone.x, y: stone.y)
            }

            if completedStageCount >= 3 {
                Capsule()
                    .fill(Color(hex: 0x8EAD69).opacity(0.24))
                    .frame(width: 130, height: 18)
                    .rotationEffect(.degrees(18))
                    .offset(y: -34)
            }
        }
    }
}

private struct LanternGladeGroundPatch: View {
    let completedStageCount: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xFFD66B).opacity(0.10 + Double(completedStageCount) * 0.04))
                .frame(width: CGFloat(82 + completedStageCount * 24), height: CGFloat(82 + completedStageCount * 24))
                .blur(radius: 12)

            if completedStageCount >= 2 {
                Capsule()
                    .fill(Color(hex: 0xE3B550).opacity(0.38))
                    .frame(width: 118, height: 8)
                    .rotationEffect(.degrees(-6))
                    .offset(y: 18)
                Capsule()
                    .fill(Color(hex: 0xE3B550).opacity(0.30))
                    .frame(width: 104, height: 6)
                    .rotationEffect(.degrees(18))
                    .offset(y: -26)
            }

            ForEach(0..<completedStageCount, id: \.self) { index in
                Circle()
                    .fill(Color(hex: 0xFFF3A8).opacity(0.46))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color(hex: 0xE2A747), lineWidth: 1))
                    .offset(
                        x: CGFloat([-42, 42, 0][index]),
                        y: CGFloat([22, 18, -34][index])
                    )
            }
        }
    }
}

private struct ArchiveCornerGroundPatch: View {
    let completedStageCount: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0xD8C39F).opacity(0.32))
                .frame(width: 130, height: 82)
                .rotationEffect(.degrees(-3))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(hex: 0x8A6A47).opacity(0.26), lineWidth: 1)
                )

            if completedStageCount >= 2 {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill([Color(hex: 0x7893C4), Color(hex: 0x8EAD69), Color(hex: 0xD4A654)][index])
                            .frame(width: 12, height: CGFloat(26 + index * 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color(hex: 0x5B5245).opacity(0.55), lineWidth: 0.7)
                            )
                    }
                }
                .offset(x: 33, y: -4)
            }

            if completedStageCount >= 3 {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(hex: 0x8A6A47).opacity(0.84))
                    .frame(width: 74, height: 18)
                    .overlay(
                        HStack(spacing: 5) {
                            Image(systemName: "leaf.fill")
                                .luminaFont(size: 8, weight: .black)
                            Text("CATALOG")
                                .luminaFont(size: 7, weight: .black, design: .rounded)
                        }
                        .foregroundColor(Color(hex: 0xF2E8BC))
                    )
                    .offset(y: 33)
            }
        }
    }
}

private struct GardenAreaStageMark: View {
    let area: GardenMapAreaKind
    let stage: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allowsMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        if allowsMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 18.0)) { context in
                content(phase: context.date.timeIntervalSinceReferenceDate + gardenMotionSeed(from: "\(area.rawValue)-\(stage)") * 0.017)
            }
        } else {
            content(phase: 0)
        }
    }

    @ViewBuilder
    private func content(phase: TimeInterval) -> some View {
        let pulse = 0.5 + 0.5 * sin(phase * 0.68)
        let stageSway = area == .pathNook ? sin(phase * 0.42) * 0.7 : 0
        let stageLift = area == .archiveCorner ? sin(phase * 0.46) * 0.6 : 0

        ZStack {
            switch area {
            case .pathNook:
                PathNookStageMark(stage: stage)
            case .lanternGlade:
                LanternGladeStageMark(stage: stage)
            case .archiveCorner:
                ArchiveCornerStageMark(stage: stage)
            }
        }
        .rotationEffect(.degrees(stageSway), anchor: .bottom)
        .scaleEffect(1 + CGFloat(area == .lanternGlade ? pulse * 0.018 : 0), anchor: .bottom)
        .offset(y: CGFloat(-stageLift))
    }
}

private struct PathNookStageMark: View {
    let stage: Int

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.13))
                .frame(width: 36, height: 9)
                .offset(y: 14)

            switch stage {
            case 1:
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: 0xB77A3A))
                        .frame(width: 30, height: 17)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(hex: 0x6E4B2A), lineWidth: 1.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: 0x6E4B2A))
                        .frame(width: 6, height: 22)
                }
            case 2:
                HStack(spacing: -3) {
                    ForEach(0..<4, id: \.self) { index in
                        Ellipse()
                            .fill(Color(hex: index.isMultiple(of: 2) ? 0xE6D6B9 : 0xCDBA98))
                            .frame(width: 18, height: 11)
                            .overlay(Ellipse().stroke(Color(hex: 0x9B876C), lineWidth: 0.8))
                            .rotationEffect(.degrees(Double(index * 8 - 12)))
                    }
                }
            default:
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: 0xB77A3A))
                        .frame(width: 8, height: 36)
                        .offset(x: -15, y: 3)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: 0xB77A3A))
                        .frame(width: 8, height: 36)
                        .offset(x: 15, y: 3)
                    Capsule()
                        .fill(Color(hex: 0xE4C16D))
                        .frame(width: 42, height: 11)
                        .offset(y: -15)
                }
            }
        }
        .frame(width: 52, height: 50)
    }
}

private struct LanternGladeStageMark: View {
    let stage: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowing = false

    private var allowsIdleMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xFFD66B).opacity(glowing && allowsIdleMotion ? 0.28 : 0.18))
                .frame(width: CGFloat(42 + stage * 6), height: CGFloat(42 + stage * 6))
                .blur(radius: 7)
                .animation(allowsIdleMotion ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : nil, value: glowing)

            VStack(spacing: -1) {
                Capsule()
                    .fill(Color(hex: 0x5F4A31))
                    .frame(width: 5, height: 19)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(hex: 0xF5BD4B))
                    .frame(width: CGFloat(22 + stage * 2), height: CGFloat(25 + stage * 2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(hex: 0x734E2B), lineWidth: 1.2)
                    )
                    .overlay(
                        Image(systemName: stage == 3 ? "sparkles" : "flame.fill")
                            .luminaFont(size: 9 + CGFloat(stage), weight: .black)
                            .foregroundColor(Color(hex: 0xFFF8E8))
                    )
            }
        }
        .frame(width: 58, height: 58)
        .onAppear {
            guard allowsIdleMotion else { return }
            glowing = true
        }
    }
}

private struct ArchiveCornerStageMark: View {
    let stage: Int

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.12))
                .frame(width: 40, height: 9)
                .offset(y: 18)

            switch stage {
            case 1:
                VStack(spacing: -2) {
                    Capsule()
                        .fill(Color(hex: 0x6E8BC8))
                        .frame(width: 21, height: 9)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: 0xF0DDAE))
                        .frame(width: 30, height: 22)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: 0x8B7659), lineWidth: 1))
                }
            case 2:
                HStack(spacing: -2) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill([Color(hex: 0x6E8BC8), Color(hex: 0x8EAD69), Color(hex: 0xD4A654)][index])
                            .frame(width: 12, height: CGFloat(29 + index * 4))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(hex: 0x5B5245), lineWidth: 0.8))
                    }
                }
            default:
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: 0x8A6A47))
                        .frame(width: 42, height: 30)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: 0x5B3F29), lineWidth: 1.2))
                    Image(systemName: "leaf.fill")
                        .luminaFont(size: 13, weight: .black)
                        .foregroundColor(Color(hex: 0xF2E8BC))
                }
            }
        }
        .frame(width: 54, height: 54)
    }
}

private struct GardenLampMarker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allowsMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        if allowsMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                content(phase: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            content(phase: 0)
        }
    }

    @ViewBuilder
    private func content(phase: TimeInterval) -> some View {
        let glow = 0.5 + 0.5 * sin(phase * 0.86)

        ZStack {
            Circle()
                .fill(Color(hex: 0xFFD66B).opacity(0.18 + glow * 0.11))
                .blur(radius: 12 + CGFloat(glow) * 2)
                .frame(width: 68 + CGFloat(glow) * 8, height: 68 + CGFloat(glow) * 8)
            Image("GardenPropLamp")
                .resizable()
                .scaledToFit()
                .shadow(color: Color(hex: 0x2F2B1A).opacity(0.24), radius: 7, x: 0, y: 5)
        }
        .accessibilityHidden(true)
    }
}

private struct GardenDecorationNode: View {
    let type: GardenDecorationType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allowsMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var seed: Double {
        gardenMotionSeed(from: type.rawValue)
    }

    var body: some View {
        if allowsMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                content(phase: context.date.timeIntervalSinceReferenceDate + seed * 0.05)
            }
        } else {
            content(phase: seed * 0.05)
        }
    }

    @ViewBuilder
    private func content(phase: TimeInterval) -> some View {
        let breath = 0.5 + 0.5 * sin(phase * 0.76)
        let sway = sin(phase * 0.55)

        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.13))
                .frame(width: 34 + CGFloat(breath) * 2, height: 10)
                .offset(y: 16)

            switch type {
            case .lamp:
                Circle()
                    .fill(Color(hex: 0xFFD66B).opacity(0.12 + breath * 0.10))
                    .frame(width: 54 + CGFloat(breath) * 8, height: 54 + CGFloat(breath) * 8)
                    .blur(radius: 10)
                    .offset(y: -4)
                Image("GardenPropLamp")
                    .resizable()
                    .scaledToFit()
                    .shadow(color: Color(hex: 0x2F2B1A).opacity(0.22), radius: 6, x: 0, y: 4)
                    .scaleEffect(1 + CGFloat(breath) * 0.012, anchor: .bottom)
            case .stones:
                GardenStoneCluster(phase: phase, allowsMotion: allowsMotion)
            case .flowers:
                GardenFlowerCluster(phase: phase, allowsMotion: allowsMotion)
                    .rotationEffect(.degrees(sway * 1.2), anchor: .bottom)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GardenStoneCluster: View {
    var phase: TimeInterval = 0
    var allowsMotion = false

    var body: some View {
        let gleam = allowsMotion ? 0.5 + 0.5 * sin(phase * 0.72 + 0.8) : 0.35

        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Ellipse()
                    .fill(Color(hex: index.isMultiple(of: 2) ? 0xD9C7A8 : 0xBCA78B))
                    .frame(width: CGFloat(13 + index % 3 * 3), height: CGFloat(9 + index % 2 * 2))
                    .overlay(Ellipse().stroke(Color(hex: 0x8B7A65), lineWidth: 0.8))
                    .offset(
                        x: CGFloat([-13, -4, 8, 16, 0][index]),
                        y: CGFloat([4, -2, 2, -4, 8][index])
                    )
            }

            Capsule()
                .fill(Color(hex: 0xFFF8D6).opacity(0.16 + gleam * 0.20))
                .frame(width: 18, height: 2)
                .blur(radius: 1)
                .rotationEffect(.degrees(-16))
                .offset(x: CGFloat(-10 + gleam * 18), y: -6)
        }
    }
}

private struct GardenFlowerCluster: View {
    var phase: TimeInterval = 0
    var allowsMotion = false

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                let stemSway = allowsMotion ? sin(phase * (0.64 + Double(index) * 0.03) + Double(index) * 0.8) * 2.4 : 0
                VStack(spacing: 0) {
                    Circle()
                        .fill(index.isMultiple(of: 2) ? Color(hex: 0xF8E9A6) : Color(hex: 0xF2A4BD))
                        .frame(width: 9, height: 9)
                        .overlay(Circle().fill(Color(hex: 0xE6A53A)).frame(width: 3, height: 3))
                    Capsule()
                        .fill(Color(hex: 0x4E7B49))
                        .frame(width: 2, height: 12)
                }
                .rotationEffect(.degrees(Double(index * 11 - 18) + stemSway), anchor: .bottom)
                .offset(
                    x: CGFloat([-15, -7, 4, 13, 0][index]),
                    y: CGFloat([3, -5, -2, 2, 7][index])
                )
            }
        }
    }
}

private struct GardenKeeperAvatar: View {
    let mood: GardenKeeperMood
    let facesLeft: Bool
    let isSceneActive: Bool
    let showsWaterBurst: Bool
    @State private var displayedMood: GardenKeeperMood?
    @State private var displayedFrames: [String] = []
    @State private var displayedFrameDuration: TimeInterval = 0.56
    @State private var displayedRepeats = true
    @State private var displayedSequenceStartDate = Date()
    @State private var transitionToken = UUID()

    private var activeFrames: [String] {
        displayedFrames.isEmpty ? mood.frames : displayedFrames
    }

    private var activeFrameDuration: TimeInterval {
        displayedFrames.isEmpty ? mood.frameDuration : displayedFrameDuration
    }

    private var activeRepeats: Bool {
        displayedFrames.isEmpty ? mood.repeatsFrames : displayedRepeats
    }

    var body: some View {
        ZStack {
            GardenGroundShadow(
                width: (displayedMood ?? mood).shadowWidth,
                height: (displayedMood ?? mood) == .walking ? 14 : 13,
                opacity: (displayedMood ?? mood) == .walking ? 0.16 : 0.14,
                blurRadius: 0.7
            )
            .offset(y: 48)

            GardenAnimatedSprite(
                assetNames: activeFrames,
                frameDuration: activeFrameDuration,
                repeats: activeRepeats,
                isActive: isSceneActive,
                sequenceStartDate: displayedSequenceStartDate
            )
                .frame(width: 168, height: 180)
                .scaleEffect((displayedMood ?? mood).spriteScale, anchor: .bottom)
                .scaleEffect(x: facesLeft ? -1 : 1, y: 1)
                .shadow(color: Color(hex: 0x17381F).opacity(0.18), radius: 4, x: 0, y: 3)
                .offset(y: -17 + (displayedMood ?? mood).spriteYOffset)

            GardenSpritePreloader(assetNames: activeFrames)

            if showsWaterBurst {
                GardenWaterBurst()
                    .scaleEffect(0.62)
                    .offset(x: facesLeft ? -24 : 24, y: -22)
                }
        }
        .onAppear {
            show(mood, replacingCurrent: true)
        }
        .onChange(of: mood) { newMood in
            transition(to: newMood)
        }
        .accessibilityLabel("Garden keeper")
    }

    private func show(_ nextMood: GardenKeeperMood, replacingCurrent: Bool = false) {
        if replacingCurrent {
            transitionToken = UUID()
        }
        displayedMood = nextMood
        displayedFrames = nextMood.frames
        displayedFrameDuration = nextMood.frameDuration
        displayedRepeats = nextMood.repeatsFrames
        displayedSequenceStartDate = Date()
    }

    private func transition(to nextMood: GardenKeeperMood) {
        let previousMood = displayedMood ?? mood
        guard previousMood != nextMood else {
            show(nextMood)
            return
        }

        let token = UUID()
        transitionToken = token

        let currentFrameIndex = currentDisplayedFrameIndex()
        let bridgeFrames = transitionFrames(
            from: previousMood,
            currentFrames: activeFrames,
            currentIndex: currentFrameIndex,
            to: nextMood
        )

        guard !bridgeFrames.isEmpty else {
            show(nextMood)
            return
        }

        let bridgeFrameDuration = transitionFrameDuration(from: previousMood, to: nextMood)
        displayedMood = nextMood
        displayedFrames = bridgeFrames
        displayedFrameDuration = bridgeFrameDuration
        displayedRepeats = false
        displayedSequenceStartDate = Date()

        Task { @MainActor in
            let duration = gardenEffectiveSpriteFrameDuration(bridgeFrameDuration) * Double(bridgeFrames.count)
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard transitionToken == token else { return }
            show(nextMood)
        }
    }

    private func currentDisplayedFrameIndex() -> Int {
        guard !activeFrames.isEmpty, activeFrameDuration > 0 else { return 0 }
        let effectiveFrameDuration = gardenEffectiveSpriteFrameDuration(activeFrameDuration)
        let framePosition = max(0, Date().timeIntervalSince(displayedSequenceStartDate)) / effectiveFrameDuration
        if activeRepeats {
            return Int(framePosition) % activeFrames.count
        }

        return min(max(0, Int(framePosition)), activeFrames.count - 1)
    }

    private func transitionFrames(
        from previousMood: GardenKeeperMood,
        currentFrames: [String],
        currentIndex: Int,
        to nextMood: GardenKeeperMood
    ) -> [String] {
        guard !currentFrames.isEmpty else { return [] }

        if previousMood == .walking, nextMood != .walking {
            return deduplicatedAdjacent(
                remainingCycleFrames(after: currentIndex, in: currentFrames)
                    + Array(nextMood.frames.prefix(1))
            )
        }

        if previousMood.usesOneShotAction {
            let clampedIndex = min(max(0, currentIndex), currentFrames.count - 1)
            let unwindFrames = Array(currentFrames[0...clampedIndex].reversed())
            return deduplicatedAdjacent(unwindFrames + Array(nextMood.frames.prefix(1)))
        }

        return []
    }

    private func remainingCycleFrames(after index: Int, in frames: [String]) -> [String] {
        guard frames.count > 1 else { return frames }
        let clampedIndex = min(max(0, index), frames.count - 1)
        let nextIndex = (clampedIndex + 1) % frames.count
        if nextIndex == 0 {
            return [frames[0]]
        }

        return Array(frames[nextIndex..<frames.count]) + [frames[0]]
    }

    private func transitionFrameDuration(from previousMood: GardenKeeperMood, to nextMood: GardenKeeperMood) -> TimeInterval {
        if previousMood == .walking || nextMood == .walking {
            return GardenCharacterMotionTiming.keeperWalk
        }
        if previousMood.usesOneShotAction || nextMood.usesOneShotAction {
            return GardenCharacterMotionTiming.keeperAction
        }

        return min(previousMood.frameDuration, nextMood.frameDuration, 0.16)
    }

    private func deduplicatedAdjacent(_ frames: [String]) -> [String] {
        frames.reduce(into: [String]()) { result, frame in
            if result.last != frame {
                result.append(frame)
            }
        }
    }
}

private struct GardenGrassTexture: View {
    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<54, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Color(hex: 0x5EA954).opacity(0.22) : Color(hex: 0xD8F39B).opacity(0.28))
                    .frame(width: CGFloat(9 + (index % 4) * 4), height: CGFloat(3 + (index % 3)))
                    .rotationEffect(.degrees(Double((index * 37) % 46) - 23))
                    .position(
                        x: CGFloat((index * 53 + 11) % 100) / 100 * proxy.size.width,
                        y: CGFloat((index * 29 + 17) % 100) / 100 * proxy.size.height
                    )
            }
        }
    }
}

private struct GardenQuietGroveOverlay: View {
    let traceCount: Int

    var body: some View {
        GeometryReader { _ in
            ZStack {
                GardenSoftTrailRibbon(traceCount: traceCount)
                    .stroke(
                        Color(hex: 0xFFF0C9).opacity(0.10),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 8)

                GardenSoftTrailRibbon(traceCount: traceCount)
                    .stroke(
                        Color(hex: 0xF8E9B7).opacity(0.16),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [2, 18])
                    )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GardenSoftTrailRibbon: Shape {
    let traceCount: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.40))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.55),
            control1: CGPoint(x: rect.width * 0.25, y: rect.height * 0.47),
            control2: CGPoint(x: rect.width * 0.35, y: rect.height * 0.45)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.69, y: rect.height * 0.48),
            control1: CGPoint(x: rect.width * 0.50, y: rect.height * 0.66),
            control2: CGPoint(x: rect.width * 0.60, y: rect.height * 0.38)
        )

        if traceCount > 3 {
            path.addCurve(
                to: CGPoint(x: rect.width * 0.73, y: rect.height * 0.70),
                control1: CGPoint(x: rect.width * 0.82, y: rect.height * 0.57),
                control2: CGPoint(x: rect.width * 0.68, y: rect.height * 0.61)
            )
        }

        return path
    }
}

private struct GardenGroveMossPatch: View {
    let tint: Color
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Ellipse()
                    .fill(tint.opacity(0.58))
                    .overlay(Ellipse().stroke(accent.opacity(0.28), lineWidth: 1.2))
                    .shadow(color: Color(hex: 0x253E22).opacity(0.10), radius: 10, x: 0, y: 5)

                Ellipse()
                    .fill(Color(hex: 0xF8EEC9).opacity(0.16))
                    .frame(width: proxy.size.width * 0.72, height: proxy.size.height * 0.54)
                    .offset(x: -proxy.size.width * 0.05, y: -proxy.size.height * 0.10)

                ForEach(0..<12, id: \.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 2) ? Color(hex: 0x668D49).opacity(0.26) : Color(hex: 0xF7EABF).opacity(0.24))
                        .frame(width: CGFloat(12 + (index % 4) * 6), height: CGFloat(3 + index % 3))
                        .rotationEffect(.degrees(Double((index * 31) % 54) - 27))
                        .position(
                            x: CGFloat((index * 37 + 19) % 100) / 100 * proxy.size.width,
                            y: CGFloat((index * 23 + 31) % 100) / 100 * proxy.size.height
                        )
                }
            }
        }
    }
}

private struct GardenGroveLanternMemory: View {
    var body: some View {
        ZStack {
            GardenGroundShadow(width: 42, height: 9, opacity: 0.13, blurRadius: 0.6)
                .offset(y: 31)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hex: 0x7C5A36))
                .frame(width: 6, height: 44)
                .offset(y: 8)

            Circle()
                .fill(Color(hex: 0xFFE8A5).opacity(0.24))
                .frame(width: 58, height: 58)
                .blur(radius: 8)
                .offset(x: 10, y: -10)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: 0xF3D58E))
                .frame(width: 24, height: 26)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(hex: 0x8C6339).opacity(0.44), lineWidth: 1)
                )
                .offset(x: 10, y: -11)

            Image(systemName: "sparkles")
                .luminaFont(size: 10, weight: .black)
                .foregroundColor(Color(hex: 0x8A6A35))
                .offset(x: 10, y: -11)
        }
    }
}

private struct GardenGroveRippleMemory: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Ellipse()
                    .stroke(Color(hex: 0xD9F2F0).opacity(0.36 - Double(index) * 0.07), lineWidth: 1.3)
                    .frame(width: CGFloat(48 + index * 18), height: CGFloat(19 + index * 8))
            }

            Image(systemName: "drop.fill")
                .luminaFont(size: 13, weight: .black)
                .foregroundColor(Color(hex: 0x54BFE8).opacity(0.82))
        }
    }
}

private struct GardenGroveRestingStoneCluster: View {
    var body: some View {
        ZStack {
            GardenGroundShadow(width: 78, height: 11, opacity: 0.13, blurRadius: 0.8)
                .offset(y: 13)

            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(index.isMultiple(of: 2) ? Color(hex: 0xD8CBAE) : Color(hex: 0xBFC8A0))
                    .frame(width: CGFloat(24 + (index % 2) * 8), height: CGFloat(15 + (index % 3) * 3))
                    .rotationEffect(.degrees(Double(index * 13) - 18))
                    .offset(
                        x: CGFloat(index * 14 - 28),
                        y: CGFloat((index % 2) * -7)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color(hex: 0x7F775F).opacity(0.22), lineWidth: 1)
                            .rotationEffect(.degrees(Double(index * 13) - 18))
                            .offset(
                                x: CGFloat(index * 14 - 28),
                                y: CGFloat((index % 2) * -7)
                            )
                    )
            }
        }
    }
}

private struct GardenMemoryPathLayer: View {
    let traceCount: Int

    private var activeCount: Int {
        min(traceCount, 5, gardenPlotPositions.count)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if activeCount > 1 {
                    tracePath(in: proxy.size, through: Array(gardenPlotPositions.prefix(activeCount)))
                        .stroke(
                            Color(hex: 0xFFF3C8).opacity(0.10),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 6)

                    tracePath(in: proxy.size, through: Array(gardenPlotPositions.prefix(activeCount)))
                        .stroke(
                            Color(hex: 0xD7C287).opacity(0.16),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [2, 18])
                        )
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func tracePath(in size: CGSize, through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: size.width * first.x, y: size.height * first.y))

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let previousPoint = CGPoint(x: size.width * previous.x, y: size.height * previous.y)
            let currentPoint = CGPoint(x: size.width * current.x, y: size.height * current.y)
            let controlOffset = CGFloat(index.isMultiple(of: 2) ? -38 : 38)
            let control1 = CGPoint(x: previousPoint.x + (currentPoint.x - previousPoint.x) * 0.42, y: previousPoint.y + controlOffset)
            let control2 = CGPoint(x: previousPoint.x + (currentPoint.x - previousPoint.x) * 0.66, y: currentPoint.y - controlOffset)
            path.addCurve(to: currentPoint, control1: control1, control2: control2)
        }
        return path
    }
}

private struct GardenTraceGlow: View {
    let index: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: index.isMultiple(of: 2) ? 0xFFF4BE : 0xDCE8B8).opacity(0.18))
                .frame(width: CGFloat(104 + (index % 3) * 10), height: CGFloat(58 + (index % 2) * 12))
                .blur(radius: 12)
                .rotationEffect(.degrees(Double((index * 19) % 34) - 17))

            ForEach(0..<3, id: \.self) { mote in
                Circle()
                    .fill(Color(hex: 0xFFF8D6).opacity(0.40))
                    .frame(width: CGFloat(3 + mote), height: CGFloat(3 + mote))
                    .offset(
                        x: CGFloat((mote * 17 + index * 7) % 36) - 18,
                        y: CGFloat((mote * 11 + index * 5) % 24) - 12
                    )
            }
        }
        .frame(width: 128, height: 92)
    }
}

private struct GardenTraceNest: View {
    let tint: Color
    let variant: Int
    var intensity: Double = 0.70

    private var seed: Int {
        abs(variant % 997)
    }

    private var safeIntensity: Double {
        min(max(intensity, 0.0), 1.0)
    }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: 0x162713).opacity(0.16 * safeIntensity))
                .frame(width: 104, height: 28)
                .blur(radius: 6)
                .offset(y: 12)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0xD7D09A).opacity(0.18 * safeIntensity),
                            tint.opacity(0.10 * safeIntensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 48
                    )
                )
                .frame(width: 96, height: 44)
                .rotationEffect(.degrees(Double((seed * 17) % 22) - 11))

            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .fill((index.isMultiple(of: 2) ? tint : Color(hex: 0xD8C990)).opacity(0.13 * safeIntensity))
                    .frame(width: CGFloat(10 + (index % 3) * 5), height: 2)
                    .rotationEffect(.degrees(Double((index * 29 + seed * 11) % 74) - 37))
                    .offset(
                        x: CGFloat((index * 15 + seed * 7) % 70) - 35,
                        y: CGFloat((index * 11 + seed * 5) % 26) - 13
                    )
            }
        }
        .frame(width: 112, height: 58)
        .accessibilityHidden(true)
    }
}

private enum GardenTraceSourceKind {
    case journal
    case therapy
    case practice

    static func resolve(for habit: Habit) -> GardenTraceSourceKind {
        if habit.sourceJournalEntryID != nil { return .journal }
        if habit.sourceMicroPlanID != nil { return .therapy }
        return .practice
    }

    var title: String {
        switch self {
        case .journal: return "Journal trace"
        case .therapy: return "Therapy trace"
        case .practice: return "Quiet practice"
        }
    }

    var originTitle: String {
        switch self {
        case .journal: return "Kept from Journal"
        case .therapy: return "Kept from Therapy"
        case .practice: return "Kept in Garden"
        }
    }

    var sourceCardTitle: String {
        switch self {
        case .journal: return "Original reflection"
        case .therapy: return "Therapy note"
        case .practice: return "Garden note"
        }
    }

    var detail: String {
        switch self {
        case .journal: return "Something written down became visible here."
        case .therapy: return "A small understanding or plan found a marker."
        case .practice: return "A quiet practice left a gentle trace."
        }
    }

    var icon: String {
        switch self {
        case .journal: return "book.pages.fill"
        case .therapy: return "bubble.left.and.text.bubble.right.fill"
        case .practice: return "leaf.fill"
        }
    }

    var tint: Color {
        switch self {
        case .journal: return Color(hex: 0x6D8B5F)
        case .therapy: return Color(hex: 0xB9822C)
        case .practice: return Color(hex: 0x4A9F94)
        }
    }
}

private enum GardenTraceObjectKind {
    case paperPage
    case letter
    case carvedStone
    case quietBowl
    case windChime
    case lantern
    case rootCharm

    static func resolve(for habit: Habit, displayIndex: Int) -> GardenTraceObjectKind {
        let source = GardenTraceSourceKind.resolve(for: habit)
        let seed = habit.id.unicodeScalars.reduce(0) { $0 + Int($1.value) } + displayIndex * 17

        switch source {
        case .journal:
            if habit.plantType == .tree || displayIndex.isMultiple(of: 3) {
                return .carvedStone
            }
            return seed.isMultiple(of: 2) ? .paperPage : .letter
        case .therapy:
            if habit.plantType == .tree || displayIndex.isMultiple(of: 4) {
                return .lantern
            }
            return seed.isMultiple(of: 2) ? .rootCharm : .windChime
        case .practice:
            switch habit.plantType {
            case .seed, .sprout: return .quietBowl
            case .flower: return .windChime
            case .tree: return .lantern
            }
        }
    }

    var title: String {
        switch self {
        case .paperPage: return "Paper page"
        case .letter: return "Letter"
        case .carvedStone: return "Carved stone"
        case .quietBowl: return "Quiet bowl"
        case .windChime: return "Wind chime"
        case .lantern: return "Lantern"
        case .rootCharm: return "Root charm"
        }
    }

    var assetName: String {
        switch self {
        case .paperPage: return "GardenTracePaperPageV2"
        case .letter: return "GardenTracePaperPageV2"
        case .carvedStone: return "GardenTraceMemoryStoneV2"
        case .quietBowl: return "GardenTraceLeafBowlV2"
        case .windChime: return "GardenTraceWindCharmV2"
        case .lantern: return "GardenTraceLanternV2"
        case .rootCharm: return "GardenTraceWindCharmV2"
        }
    }

    var assetSize: CGSize {
        switch self {
        case .paperPage, .letter: return CGSize(width: 64, height: 66)
        case .carvedStone: return CGSize(width: 70, height: 66)
        case .quietBowl: return CGSize(width: 72, height: 54)
        case .windChime, .rootCharm: return CGSize(width: 58, height: 78)
        case .lantern: return CGSize(width: 62, height: 76)
        }
    }

    var icon: String {
        switch self {
        case .paperPage: return "doc.text.fill"
        case .letter: return "envelope.open.fill"
        case .carvedStone: return "seal.fill"
        case .quietBowl: return "drop.fill"
        case .windChime: return "bell.fill"
        case .lantern: return "lightbulb.fill"
        case .rootCharm: return "sparkles"
        }
    }

    var meaning: String {
        switch self {
        case .paperPage: return "A written reflection that wanted a visible place."
        case .letter: return "A thought that may be worth returning to later."
        case .carvedStone: return "A moment that felt understood enough to leave a mark."
        case .quietBowl: return "A return to the body, held without pressure."
        case .windChime: return "A soft signal that continuity is present."
        case .lantern: return "A steady marker for a path that has become easier to find."
        case .rootCharm: return "A small plan or insight tied back to daily life."
        }
    }
}

private struct GardenTraceObjectDescriptor {
    let source: GardenTraceSourceKind
    let object: GardenTraceObjectKind

    static func resolve(for habit: Habit, displayIndex: Int) -> GardenTraceObjectDescriptor {
        GardenTraceObjectDescriptor(
            source: GardenTraceSourceKind.resolve(for: habit),
            object: GardenTraceObjectKind.resolve(for: habit, displayIndex: displayIndex)
        )
    }

    var tint: Color {
        source.tint
    }

    func stageTitle(for plantType: PlantType) -> String {
        switch plantType {
        case .seed: return "\(object.title) just arrived"
        case .sprout: return "\(object.title) is settling"
        case .flower: return "\(object.title) is easy to notice"
        case .tree: return "\(object.title) is rooted"
        }
    }

    func ageText(createdAt: TimeInterval) -> String {
        let diff = max(0, Date().timeIntervalSince1970 - createdAt)
        if diff < 3600 { return "Kept just now" }
        if diff < 86400 { return "Kept today" }

        let days = Int(diff / 86400)
        if days == 1 { return "Kept yesterday" }
        if days < 30 { return "Kept \(days)d ago" }

        let months = max(1, days / 30)
        return months == 1 ? "Kept 1mo ago" : "Kept \(months)mo ago"
    }
}

private struct GardenTraceNode: View {
    let habit: Habit
    let displayIndex: Int
    let mapY: CGFloat
    let tool: GardenTool
    let canWater: Bool
    let isCompletedToday: Bool
    let isWatering: Bool
    let isFocused: Bool

    private var descriptor: GardenTraceObjectDescriptor {
        GardenTraceObjectDescriptor.resolve(for: habit, displayIndex: displayIndex)
    }

    private var traceTint: Color {
        descriptor.tint
    }

    private var depthScale: CGFloat {
        min(max(0.70 + mapY * 0.48, 0.84), 1.04)
    }

    private var traceIcon: String {
        descriptor.object.icon
    }

    private var nestIntensity: Double {
        descriptor.source == .therapy ? 0.58 : 0.52
    }

    private var groundShadowWidth: CGFloat {
        switch descriptor.object {
        case .quietBowl:
            return 64
        case .windChime, .rootCharm, .lantern:
            return 50
        default:
            return 58
        }
    }

    var body: some View {
        ZStack {
            GardenTraceNest(
                tint: traceTint,
                variant: displayIndex,
                intensity: nestIntensity
            )
            .offset(y: 18)
            .scaleEffect(0.64)
            .blendMode(.multiply)

            GardenGroundShadow(
                width: groundShadowWidth,
                height: 12,
                opacity: 0.14,
                blurRadius: 1.4
            )
            .offset(y: descriptor.source == .therapy ? 25 : 27)

            traceBase

            traceObject

            statusBadge
                .offset(x: 33, y: -32)
                .shadow(color: Color(hex: 0x17381F).opacity(0.14), radius: 4, x: 0, y: 2)
                .scaleEffect(isFocused ? 1.06 : 1)
                .animation(.easeInOut(duration: 0.16), value: isFocused)
                .animation(.easeInOut(duration: 0.16), value: isCompletedToday)
                .animation(.easeInOut(duration: 0.16), value: tool)

            if isWatering {
                GardenWaterBurst()
                    .scaleEffect(0.78)
                    .offset(y: -30)
            }
        }
        .frame(width: 100, height: 98)
        .contentShape(Circle())
        .scaleEffect(depthScale * (isFocused ? 1.06 : 1.0))
        .animation(.easeInOut(duration: 0.18), value: isFocused)
    }

    @ViewBuilder
    private var traceObject: some View {
        GardenTraceAssetNode(
            assetName: descriptor.object.assetName,
            size: descriptor.object.assetSize,
            tint: traceTint,
            isRooted: habit.growth >= 72,
            motionSeed: gardenMotionSeed(from: "\(habit.id)-\(displayIndex)-\(descriptor.object.assetName)")
        )
    }

    @ViewBuilder
    private var traceBase: some View {
        if isFocused {
            Circle()
                .stroke(Color(hex: 0xFFF1A8).opacity(0.82), lineWidth: 1.8)
                .frame(width: 68, height: 68)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isCompletedToday {
            Image(systemName: "checkmark.seal.fill")
                .luminaFont(size: 17, weight: .black)
                .foregroundColor(Color(hex: 0xFFFDF4))
                .frame(width: 22, height: 22)
                .background(Color(hex: 0x5FA461))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(hex: 0xFFF8E8), lineWidth: 1.4))
        } else if tool == .explore {
            Image(systemName: traceIcon)
                .luminaFont(size: 10, weight: .black)
                .foregroundColor(traceTint)
                .frame(width: 21, height: 21)
                .background(Color(hex: 0xFFFDF4).opacity(0.92))
                .clipShape(Circle())
                .overlay(Circle().stroke(traceTint.opacity(0.24), lineWidth: 1))
        } else if tool == .tend {
            Image(systemName: canWater ? "drop.fill" : "hand.draw.fill")
                .luminaFont(size: 10, weight: .black)
                .foregroundColor(canWater ? Color(hex: 0x309FD2) : Color(hex: 0x5FA461))
                .frame(width: 22, height: 22)
                .background(Color(hex: 0xFFF8E8).opacity(0.94))
                .clipShape(Circle())
        } else if tool == .arrange {
            Image(systemName: "plus")
                .luminaFont(size: 10, weight: .black)
                .foregroundColor(Color(hex: 0x9D642A))
                .frame(width: 22, height: 22)
                .background(Color(hex: 0xFFF0C7))
                .clipShape(Circle())
        }
    }
}

private struct GardenTraceAssetNode: View {
    let assetName: String
    let size: CGSize
    let tint: Color
    let isRooted: Bool
    var motionSeed: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allowsMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var hasWarmGlow: Bool {
        assetName.contains("Lantern") || assetName.contains("WindCharm")
    }

    private var shouldSway: Bool {
        assetName.contains("WindCharm")
    }

    var body: some View {
        if allowsMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                content(phase: context.date.timeIntervalSinceReferenceDate + motionSeed * 0.021)
            }
        } else {
            content(phase: motionSeed * 0.021)
        }
    }

    @ViewBuilder
    private func content(phase: TimeInterval) -> some View {
        let slow = 0.5 + 0.5 * sin(phase * 0.74)
        let medium = 0.5 + 0.5 * sin(phase * 1.08 + 0.7)
        let paperLift = assetName.contains("Paper") ? sin(phase * 0.52) * 0.7 : 0
        let stoneGlow = assetName.contains("Stone") ? slow : 0
        let bowlRipple = assetName.contains("Bowl") ? medium : 0
        let swayDegrees = shouldSway ? sin(phase * 0.86) * 2.0 : 0
        let lanternLift = assetName.contains("Lantern") ? sin(phase * 0.62 + 0.4) * 0.8 : 0

        ZStack {
            Ellipse()
                .fill(tint.opacity(0.10 + slow * 0.08))
                .frame(width: size.width * 1.05, height: max(10, size.height * 0.20))
                .blur(radius: 5)
                .offset(y: size.height * 0.39)

            if hasWarmGlow {
                Circle()
                    .fill(Color(hex: 0xFFE19A).opacity(0.09 + slow * 0.12))
                    .frame(width: size.width * (1.02 + CGFloat(slow) * 0.10), height: size.width * (1.02 + CGFloat(slow) * 0.10))
                    .blur(radius: 12)
                    .offset(y: size.height * 0.02)
            }

            if assetName.contains("Bowl") {
                ForEach(0..<2, id: \.self) { index in
                    Ellipse()
                        .stroke(Color(hex: 0xCDEFD7).opacity(0.18 + bowlRipple * 0.20), lineWidth: 1)
                        .frame(
                            width: size.width * CGFloat(0.44 + Double(index) * 0.18 + bowlRipple * 0.08),
                            height: size.height * CGFloat(0.16 + Double(index) * 0.05 + bowlRipple * 0.04)
                        )
                        .offset(y: size.height * -0.04)
                }
            }

            if assetName.contains("Stone"), isRooted {
                Capsule()
                    .fill(Color(hex: 0xFFF4B8).opacity(0.13 + stoneGlow * 0.18))
                    .frame(width: size.width * 0.42, height: 3)
                    .blur(radius: 1.5)
                    .rotationEffect(.degrees(-14))
                    .offset(x: 2, y: -6)
            }

            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .opacity(0.98)
                .shadow(color: Color(hex: 0x17381F).opacity(0.12), radius: 1.2, x: 0, y: 1)
                .shadow(color: Color(hex: 0x17381F).opacity(0.12), radius: 7, x: 0, y: 5)
                .rotationEffect(.degrees(swayDegrees + (assetName.contains("Paper") ? sin(phase * 0.38) * 0.65 : 0)), anchor: shouldSway ? .top : .center)
                .scaleEffect(1 + CGFloat(slow) * (isRooted ? 0.018 : 0.010), anchor: .bottom)
                .offset(
                    x: shouldSway ? CGFloat(cos(phase * 0.68) * 0.7) : 0,
                    y: CGFloat(-paperLift - lanternLift)
                )

            if assetName.contains("Lantern") {
                Circle()
                    .fill(Color(hex: 0xFFF8D6).opacity(0.18 + medium * 0.18))
                    .frame(width: 7, height: 7)
                    .blur(radius: 1.5)
                    .offset(y: -size.height * 0.10 + CGFloat(lanternLift))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GardenJournalMemoryTrace: View {
    let tint: Color
    let isRooted: Bool

    var body: some View {
        ZStack {
            GardenMemoryStone(tint: tint)
                .scaleEffect(1.08)
                .offset(x: -24, y: 19)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: 0xFFF3D1))
                .frame(width: 44, height: 54)
                .rotationEffect(.degrees(6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: 0xA98C5D).opacity(0.34), lineWidth: 1)
                )
                .shadow(color: Color(hex: 0x2B281F).opacity(0.13), radius: 5, x: 0, y: 3)

            Capsule()
                .fill(tint.opacity(0.72))
                .frame(width: 8, height: 39)
                .rotationEffect(.degrees(6))
                .offset(x: -13, y: 0)

            VStack(alignment: .leading, spacing: 4) {
                Capsule().fill(Color(hex: 0x9F8D72).opacity(0.46)).frame(width: 18, height: 2)
                Capsule().fill(Color(hex: 0x9F8D72).opacity(0.34)).frame(width: 23, height: 2)
                Capsule().fill(Color(hex: 0x9F8D72).opacity(0.26)).frame(width: 14, height: 2)
            }
            .rotationEffect(.degrees(6))
            .offset(x: 9, y: 2)

            GardenSmallLeafAccent(tint: tint)
                .opacity(isRooted ? 1 : 0.58)
                .offset(x: 23, y: -24)
        }
        .frame(width: 96, height: 96)
        .accessibilityHidden(true)
    }
}

private struct GardenTherapyPathTrace: View {
    let tint: Color
    let isRooted: Bool

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(hex: 0xD6C59F))
                    .frame(width: CGFloat(22 + index % 2 * 5), height: CGFloat(13 + index % 2 * 3))
                    .rotationEffect(.degrees(Double(index * 15) - 22))
                    .offset(x: CGFloat(index * 22 - 34), y: CGFloat(index.isMultiple(of: 2) ? 23 : 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color(hex: 0x8F7A55).opacity(0.20), lineWidth: 1)
                            .rotationEffect(.degrees(Double(index * 15) - 22))
                            .offset(x: CGFloat(index * 22 - 34), y: CGFloat(index.isMultiple(of: 2) ? 23 : 14))
                    )
            }

            GardenPathMarker(tint: tint)
                .scaleEffect(1.25)
                .offset(x: -8, y: -1)

            Circle()
                .fill(Color(hex: 0xFFE9A7).opacity(isRooted ? 0.38 : 0.22))
                .frame(width: 46, height: 46)
                .blur(radius: 8)
                .offset(x: 25, y: -16)

            Image(systemName: "sparkles")
                .luminaFont(size: 15, weight: .black)
                .foregroundColor(tint)
                .offset(x: 25, y: -16)
        }
        .frame(width: 112, height: 100)
        .accessibilityHidden(true)
    }
}

private struct GardenPracticeTrace: View {
    let plantType: PlantType
    let scale: CGFloat

    var body: some View {
        ZStack {
            GardenPlantIllustration(type: plantType)
                .frame(width: 70, height: 86)
                .scaleEffect(scale)
                .shadow(color: Color(hex: 0x1B3C22).opacity(0.15), radius: 4, x: 0, y: 3)

            GardenSmallLeafAccent(tint: Color(hex: 0x4A9F94))
                .scaleEffect(0.82)
                .offset(x: -28, y: 19)
        }
        .frame(width: 100, height: 100)
        .accessibilityHidden(true)
    }
}

private struct GardenSmallLeafAccent: View {
    let tint: Color

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color(hex: 0x8B6B42).opacity(0.80))
                .frame(width: 5, height: 22)
                .rotationEffect(.degrees(30))
                .offset(y: 8)

            Ellipse()
                .fill(tint.opacity(0.82))
                .frame(width: 18, height: 10)
                .rotationEffect(.degrees(-32))
                .offset(x: -7, y: -2)

            Ellipse()
                .fill(Color(hex: 0xBDD392).opacity(0.88))
                .frame(width: 16, height: 9)
                .rotationEffect(.degrees(36))
                .offset(x: 7, y: 1)
        }
    }
}

private struct GardenMemoryStone: View {
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: 0xD2C4A6))
                .frame(width: 32, height: 26)
                .rotationEffect(.degrees(-8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: 0x9C8B72).opacity(0.42), lineWidth: 1)
                )

            Image(systemName: "quote.opening")
                .luminaFont(size: 10, weight: .black)
                .foregroundColor(tint)
                .offset(y: -1)
        }
        .accessibilityHidden(true)
    }
}

private struct GardenPathMarker: View {
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(hex: 0x8B6339))
                .frame(width: 7, height: 31)
                .offset(y: 11)

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(hex: 0xF3D999))
                .frame(width: 34, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color(hex: 0x9D7548).opacity(0.56), lineWidth: 1)
                )

            Image(systemName: "arrow.turn.up.right")
                .luminaFont(size: 9, weight: .black)
                .foregroundColor(tint)
        }
        .accessibilityHidden(true)
    }
}

private struct GardenFirstTraceInvitation: View {
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0xFFF8E8).opacity(0.26))
                    .frame(width: 88, height: 88)
                    .blur(radius: 8)

                Image(systemName: "leaf.fill")
                    .luminaFont(size: 18, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 46, height: 46)
                    .background(Color(hex: 0x6D8B5F).opacity(0.88))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
            }

            Text("The grove is waiting")
                .luminaFont(size: 12, weight: .black, design: .rounded)
                .foregroundColor(Color(hex: 0xFFF8E8))
                .shadow(color: Color(hex: 0x1B3C22).opacity(0.34), radius: 3, x: 0, y: 1)
        }
        .accessibilityLabel("The grove is waiting for its first trace")
    }
}

private struct GardenOpenTraceAnchor: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: 0xFFF8E8).opacity(0.13))
                .frame(width: 100, height: 58)
                .overlay(
                    Ellipse()
                        .stroke(Color(hex: 0xFFF8E8).opacity(0.44), style: StrokeStyle(lineWidth: 1.5, dash: [5, 7]))
                )

            Image(systemName: "plus")
                .luminaFont(size: 15, weight: .black)
                .foregroundColor(Color(hex: 0xFFF8E8).opacity(0.88))
        }
        .frame(width: 112, height: 76)
        .accessibilityHidden(true)
    }
}

private struct GardenPlotNode: View {
    let habit: Habit
    let tool: GardenTool
    let canWater: Bool
    let isCompletedToday: Bool
    let isWatering: Bool
    let isFocused: Bool

    private var plantShadow: (width: CGFloat, height: CGFloat, y: CGFloat, opacity: Double) {
        switch habit.plantType {
        case .seed:
            return (52, 10, 20, 0.12)
        case .sprout:
            return (56, 11, 25, 0.13)
        case .flower:
            return (66, 13, 34, 0.14)
        case .tree:
            return (74, 15, 42, 0.15)
        }
    }

    private var sourceBadgeIcon: String? {
        if habit.sourceJournalEntryID != nil { return "book.pages.fill" }
        if habit.sourceMicroPlanID != nil { return "sparkles" }
        return nil
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tool == .explore ? Color.clear : tool.tint.opacity(0.14))
                .frame(width: isFocused ? 96 : 88, height: isFocused ? 96 : 88)
                .overlay(
                    Circle()
                        .stroke(isFocused ? Color(hex: 0xFFF1A8).opacity(0.86) : (tool == .explore ? Color.clear : Color(hex: 0xFFF8E8).opacity(0.68)), lineWidth: isFocused ? 2.2 : 1.4)
                )

            GardenGroundShadow(
                width: plantShadow.width,
                height: plantShadow.height,
                opacity: plantShadow.opacity,
                blurRadius: 0.8
            )
            .offset(y: plantShadow.y)

            GardenPlantIllustration(type: habit.plantType)
                .frame(width: 82, height: 98)
                .shadow(color: Color(hex: 0x1B3C22).opacity(0.14), radius: 4, x: 0, y: 3)

            if isWatering {
                GardenWaterBurst()
                    .offset(y: -36)
            }

            if isCompletedToday {
                Image(systemName: "checkmark.seal.fill")
                    .luminaFont(size: 18, weight: .black)
                    .foregroundColor(Color(hex: 0xFFFDF4))
                    .background(Circle().fill(Color(hex: 0x5FA461)).frame(width: 24, height: 24))
                    .offset(x: 37, y: -34)
            }

            if let sourceBadgeIcon, tool == .explore {
                Image(systemName: sourceBadgeIcon)
                    .luminaFont(size: 12, weight: .black)
                    .foregroundColor(Color(hex: 0x5D7052))
                    .frame(width: 24, height: 24)
                    .background(Color(hex: 0xFFFDF4).opacity(0.92))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(hex: 0xCBD8B8), lineWidth: 1))
                    .offset(x: -36, y: -34)
            }

            if tool == .tend {
                Image(systemName: canWater || !isCompletedToday ? "sparkles" : "book.pages.fill")
                    .luminaFont(size: 15, weight: .black)
                    .foregroundColor(canWater || !isCompletedToday ? Color(hex: 0x5FA461) : Color(hex: 0x8B7A65))
                    .padding(6)
                    .background(Color(hex: 0xF2F6D9))
                    .clipShape(Circle())
                    .offset(x: -38, y: -34)
            }

            if tool == .arrange {
                Image(systemName: "plus")
                    .luminaFont(size: 15, weight: .black)
                    .foregroundColor(Color(hex: 0x9D642A))
                    .padding(6)
                    .background(Color(hex: 0xFFF0C7))
                    .clipShape(Circle())
                    .offset(x: -38, y: -34)
            }
        }
        .frame(width: 126, height: 126)
        .contentShape(Circle())
        .scaleEffect(isFocused ? 1.05 : (tool == .explore ? 1.0 : 1.02))
    }
}

private struct GardenWaterBurst: View {
    @State private var rising = false
    @State private var rippling = false

    private let offsets: [CGSize] = [
        CGSize(width: -24, height: -8),
        CGSize(width: -10, height: -20),
        CGSize(width: 6, height: -12),
        CGSize(width: 20, height: -24),
        CGSize(width: 30, height: -4)
    ]

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(Color(hex: 0xBFE9D2).opacity(rippling ? 0 : 0.48), lineWidth: 1.4)
                .frame(width: rippling ? 64 : 22, height: rippling ? 20 : 7)
                .offset(y: 9)
                .animation(.easeOut(duration: 0.58), value: rippling)

            ForEach(offsets.indices, id: \.self) { index in
                Image(systemName: "drop.fill")
                    .luminaFont(size: CGFloat(9 + index % 3), weight: .black)
                    .foregroundColor(Color(hex: 0x55BDE6))
                    .opacity(rising ? 0 : 0.95)
                    .scaleEffect(rising ? 0.55 : 1)
                    .offset(
                        x: offsets[index].width,
                        y: rising ? offsets[index].height - 26 : offsets[index].height
                    )
                    .animation(.easeOut(duration: 0.85).delay(Double(index) * 0.04), value: rising)
            }
        }
        .onAppear {
            rippling = false
            rising = false
            DispatchQueue.main.async {
                rippling = true
                rising = true
            }
        }
    }
}

private struct GardenPlantIllustration: View {
    let type: PlantType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var assetName: String {
        switch type {
        case .seed: return "GardenPlantSeed"
        case .sprout: return "GardenPlantSprout"
        case .flower: return "GardenPlantFlower"
        case .tree: return "GardenPlantTree"
        }
    }

    private var imageSize: CGSize {
        switch type {
        case .seed: return CGSize(width: 68, height: 42)
        case .sprout: return CGSize(width: 70, height: 54)
        case .flower: return CGSize(width: 82, height: 90)
        case .tree: return CGSize(width: 88, height: 108)
        }
    }

    private var allowsMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        if allowsMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 18.0)) { context in
                content(phase: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            content(phase: 0)
        }
    }

    @ViewBuilder
    private func content(phase: TimeInterval) -> some View {
        let seed = gardenMotionSeed(from: type.rawValue)
        let sway = type == .seed ? 0 : sin(phase * 0.48 + seed * 0.11) * Double(type == .tree ? 0.8 : 1.4)
        let breath = type == .seed ? 0 : 0.5 + 0.5 * sin(phase * 0.55 + seed * 0.07)

        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: imageSize.width, height: imageSize.height)
            .rotationEffect(.degrees(sway), anchor: .bottom)
            .scaleEffect(1 + CGFloat(breath) * 0.006, anchor: .bottom)
            .accessibilityHidden(true)
    }
}

private struct EmptyGardenPlot: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xFFF8E8).opacity(0.18))
                .frame(width: 96, height: 96)
                .overlay(
                    Circle()
                        .stroke(Color(hex: 0xFFF8E8).opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [6]))
                )
            Image(systemName: "plus")
                .luminaFont(size: 16, weight: .black)
                .foregroundColor(Color(hex: 0xF7F0CD))
        }
        .frame(width: 110, height: 100)
    }
}

private struct GardenCabin: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: 0xC9874D))
                .frame(width: 86, height: 58)
                .offset(y: 18)
                .overlay(
                    HStack(spacing: 18) {
                        RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x6E492A)).frame(width: 16, height: 28)
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0xF4D595)).frame(width: 18, height: 18)
                    }
                    .offset(y: 22)
                )

            TriangleShape()
                .fill(Color(hex: 0x8F4A35))
                .frame(width: 106, height: 58)
                .offset(y: -15)
                .overlay(
                    TriangleShape()
                        .stroke(Color(hex: 0x6C3525), lineWidth: 2)
                        .frame(width: 106, height: 58)
                        .offset(y: -15)
                )

            Capsule()
                .fill(Color(hex: 0xE2B36C))
                .frame(width: 76, height: 9)
                .offset(y: 3)
        }
    }
}

private struct GardenPond: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: 0x497F6A).opacity(0.20))
                .frame(width: 112, height: 74)
                .offset(y: 7)
            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: 0x7DD7F0), Color(hex: 0x3BA5D0)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 104, height: 68)
            Capsule()
                .fill(Color.white.opacity(0.45))
                .frame(width: 34, height: 7)
                .rotationEffect(.degrees(-12))
                .offset(x: -18, y: -8)
            Circle()
                .fill(Color(hex: 0xD7F5B0))
                .frame(width: 18, height: 18)
                .offset(x: 34, y: 12)
        }
    }
}

private struct GardenFenceLine: View {
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<7, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: 0xE1B273))
                    .frame(width: 8, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color(hex: 0x9B6738), lineWidth: 1))
            }
        }
        .overlay(
            Capsule().fill(Color(hex: 0xC68B4F)).frame(width: 112, height: 8).offset(y: -6)
        )
        .rotationEffect(.degrees(-4))
    }
}

private struct GardenStonePath: View {
    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                Ellipse()
                    .fill(Color(hex: 0xEFE4CB).opacity(0.92))
                    .frame(width: CGFloat(32 + (index % 3) * 7), height: CGFloat(19 + (index % 2) * 5))
                    .overlay(Ellipse().stroke(Color(hex: 0xC7B493), lineWidth: 1))
                    .position(x: CGFloat(index) * 28, y: CGFloat(index % 2) * 18)
            }
        }
        .frame(width: 190, height: 62)
        .rotationEffect(.degrees(-17))
    }
}

private struct GardenSignBoard: View {
    let completedCount: Int
    let totalCount: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: 0xC48245))
                .frame(width: 88, height: 50)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x7C4D2B), lineWidth: 2))
            VStack(spacing: 2) {
                Text("TODAY")
                    .luminaFont(size: 9, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF2C7))
                Text("\(completedCount)/\(max(totalCount, 1))")
                    .luminaFont(size: 18, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0xFFFDF4))
            }
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: 0x7C4D2B))
                .frame(width: 9, height: 34)
                .offset(y: 42)
        }
    }
}

// MARK: - Sheets

private struct GardenAreaSheet: View {
    let unlock: GardenMapAreaUnlock
    let visit: GardenMapAreaVisit?
    let visitCount: Int
    let unlockedMilestones: [GardenAreaMilestoneUnlock]
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var miniGameSteps: Set<Int> = []

    private var isCompletedToday: Bool {
        visit != nil
    }

    private var unlockedStages: Set<Int> {
        Set(unlockedMilestones.map(\.stage))
    }

    private var nextMilestone: GardenAreaMilestoneDefinition? {
        unlock.area.milestoneDefinitions.first { !unlockedStages.contains($0.stage) }
    }

    private var nextChapter: GardenAreaChapterDefinition? {
        unlock.area.chapterDefinitions.first { !unlockedStages.contains($0.stage) }
    }

    private var progressFraction: CGFloat {
        guard let nextChapter else { return 1 }
        return min(1, CGFloat(visitCount) / CGFloat(nextChapter.requiredVisits))
    }

    private var progressText: String {
        guard let nextChapter else { return "All chapters settled" }
        return "\(min(visitCount, nextChapter.requiredVisits))/\(nextChapter.requiredVisits) quiet visits"
    }

    private var canPlaceAreaChange: Bool {
        isCompletedToday || miniGameSteps.count >= unlock.area.miniGameKind.requiredSteps
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(unlock.area.tint.opacity(0.14))
                        .frame(width: 68, height: 78)

                    GardenMapAreaNode(
                        unlock: unlock,
                        isCompletedToday: isCompletedToday,
                        visitCount: visitCount,
                        nextMilestone: nextMilestone,
                        completedStageCount: unlockedMilestones.count
                    )
                    .scaleEffect(0.66)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Grove corner")
                        .luminaFont(size: 12, weight: .black)
                        .foregroundColor(Color(hex: 0x82725B))
                        .textCase(.uppercase)
                    Text(unlock.area.title)
                        .luminaFont(size: 25, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x3F3428))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(unlock.area.detail)
                        .luminaFont(size: 14, weight: .semibold)
                        .foregroundColor(Color(hex: 0x6F604B))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(2)

                Spacer(minLength: 4)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .luminaFont(size: 13, weight: .black)
                        .foregroundColor(Color(hex: 0x78664E))
                        .frame(width: 34, height: 34)
                        .background(Color(hex: 0xF2E5CE))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 11) {
                Image(systemName: isCompletedToday ? "checkmark.seal.fill" : unlock.area.icon)
                    .luminaFont(size: 16, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 38, height: 38)
                    .background(isCompletedToday ? Color(hex: 0x5FA461) : unlock.area.tint)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(isCompletedToday ? "Already settled" : unlock.area.actionTitle)
                        .luminaFont(size: 15, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                    Text(isCompletedToday ? "Return later if this corner feels useful." : unlock.area.actionDetail)
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundColor(Color(hex: 0x82725B))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(2)

                Spacer(minLength: 8)

                GardenSoftDewBadge(label: "dew")
            }
            .padding(14)
            .background(Color(hex: 0xF2F6D9))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(unlock.area.tint.opacity(0.24), lineWidth: 1)
            )

            GardenAreaMiniGamePanel(
                area: unlock.area,
                isCompletedToday: isCompletedToday,
                completedSteps: $miniGameSteps
            )

            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("Visible change")
                        .luminaFont(size: 12, weight: .black)
                        .foregroundColor(Color(hex: 0x82725B))
                        .textCase(.uppercase)
                    Spacer(minLength: 0)
                    Text("Chapter \(unlockedMilestones.count)/\(unlock.area.chapterDefinitions.count)")
                        .luminaFont(size: 11, weight: .black, design: .rounded)
                        .foregroundColor(unlock.area.tint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(unlock.area.tint.opacity(0.12))
                        .clipShape(Capsule())
                }

                if let nextChapter {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(nextChapter.title)
                                .luminaFont(size: 18, weight: .black, design: .rounded)
                                .foregroundColor(Color(hex: 0x3F3428))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(2)
                            Spacer(minLength: 0)
                            GardenSoftDewBadge(label: "dew", fontSize: 11, iconSize: 10, horizontalPadding: 8, verticalPadding: 5)
                        }

                        Text(nextChapter.story)
                            .luminaFont(size: 12, weight: .bold)
                            .foregroundColor(Color(hex: 0x82725B))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Image(systemName: unlock.area.icon)
                                .luminaFont(size: 11, weight: .black)
                                .foregroundColor(Color(hex: 0xFFF8E8))
                                .frame(width: 24, height: 24)
                                .background(unlock.area.tint)
                                .clipShape(Circle())

                            Text(nextChapter.objective)
                                .luminaFont(size: 12, weight: .black, design: .rounded)
                                .foregroundColor(Color(hex: 0x4E4034))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(Color(hex: 0xFFF8E8).opacity(0.70))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(hex: 0xE1D5BC))
                                Capsule()
                                    .fill(unlock.area.tint)
                                    .frame(width: proxy.size.width * progressFraction)
                            }
                        }
                        .frame(height: 8)

                        Text(progressText)
                            .luminaFont(size: 11, weight: .black, design: .rounded)
                            .foregroundColor(Color(hex: 0x6F604B))
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .luminaFont(size: 16, weight: .black)
                            .foregroundColor(Color(hex: 0x5FA461))
                        Text("All current area chapters are settled.")
                            .luminaFont(size: 13, weight: .black, design: .rounded)
                            .foregroundColor(Color(hex: 0x4E4034))
                    }
                }

                if !unlockedMilestones.isEmpty {
                    HStack(spacing: 7) {
                        ForEach(unlockedMilestones.suffix(3)) { milestone in
                            GardenAreaMilestonePill(
                                area: unlock.area,
                                milestone: milestone
                            )
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(hex: 0xFFF3D8))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(unlock.area.tint.opacity(0.20), lineWidth: 1)
            )

            Button {
                if isCompletedToday {
                    dismiss()
                } else if canPlaceAreaChange {
                    onComplete()
                }
            } label: {
                Label(
                    isCompletedToday ? "Settled" : (canPlaceAreaChange ? "Place this change" : unlock.area.miniGameTitle),
                    systemImage: isCompletedToday ? "checkmark.circle.fill" : (canPlaceAreaChange ? "sparkles" : unlock.area.icon)
                )
                    .luminaFont(size: 15, weight: .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundColor(.white)
                    .background(canPlaceAreaChange ? (isCompletedToday ? Color(hex: 0x5FA461) : unlock.area.tint) : Color(hex: 0xB6AA96))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canPlaceAreaChange)
        }
        .padding(.horizontal, 22)
        .padding(.top, 36)
        .padding(.bottom, 22)
        }
        .background(Color(hex: 0xFFF8E8).ignoresSafeArea())
        .onChange(of: unlock.id) { _ in
            miniGameSteps = []
        }
    }
}

private struct GardenAreaMiniGamePanel: View {
    let area: GardenMapAreaKind
    let isCompletedToday: Bool
    @Binding var completedSteps: Set<Int>

    private var requiredSteps: Int {
        area.miniGameKind.requiredSteps
    }

    private var completedCount: Int {
        isCompletedToday ? requiredSteps : completedSteps.count
    }

    private var isComplete: Bool {
        completedCount >= requiredSteps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isComplete ? area.miniGameReadyTitle : area.miniGameTitle)
                        .luminaFont(size: 16, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x3F3428))
                    Text("\(completedCount)/\(requiredSteps)")
                        .luminaFont(size: 11, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x82725B))
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    ForEach(0..<requiredSteps, id: \.self) { index in
                        Capsule()
                            .fill(index < completedCount ? area.tint : Color(hex: 0xE1D5BC))
                            .frame(width: 18, height: 6)
                    }
                }
            }

            switch area.miniGameKind {
            case .route:
                GardenRouteMiniGame(
                    area: area,
                    isCompletedToday: isCompletedToday,
                    completedSteps: $completedSteps
                )
            case .lanterns:
                GardenLanternMiniGame(
                    area: area,
                    isCompletedToday: isCompletedToday,
                    completedSteps: $completedSteps
                )
            case .archive:
                GardenArchiveMiniGame(
                    area: area,
                    isCompletedToday: isCompletedToday,
                    completedSteps: $completedSteps
                )
            }

            if isComplete && !isCompletedToday {
                GardenMiniGameReadyRibbon(area: area)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .padding(14)
        .background(Color(hex: 0xF7EBD2))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(area.tint.opacity(0.20), lineWidth: 1)
        )
    }
}

private struct GardenMiniGameReadyRibbon: View {
    let area: GardenMapAreaKind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .luminaFont(size: 15, weight: .black)
                .foregroundColor(Color(hex: 0xFFF8E8))
                .frame(width: 28, height: 28)
                .background(area.tint)
                .clipShape(Circle())
                .scaleEffect(pulse && !reduceMotion ? 1.08 : 1)

            Text("Ready to place")
                .luminaFont(size: 12, weight: .black, design: .rounded)
                .foregroundColor(Color(hex: 0x3F3428))

            Spacer(minLength: 0)

            Image(systemName: "sparkles")
                .luminaFont(size: 13, weight: .black)
                .foregroundColor(area.tint)
                .opacity(pulse && !reduceMotion ? 1 : 0.55)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(hex: 0xFFF8E8).opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(area.tint.opacity(0.22), lineWidth: 1)
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct GardenRouteMiniGame: View {
    let area: GardenMapAreaKind
    let isCompletedToday: Bool
    @Binding var completedSteps: Set<Int>

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<area.miniGameKind.requiredSteps, id: \.self) { index in
                let isDone = isCompletedToday || completedSteps.contains(index)
                let isNext = index == completedSteps.count

                Button {
                    guard !isCompletedToday, isNext else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        _ = completedSteps.insert(index)
                    }
                } label: {
                    ZStack {
                        Ellipse()
                            .fill(isDone ? area.tint : Color(hex: 0xEFE4CB))
                            .frame(height: 42)
                            .overlay(
                                Ellipse()
                                    .stroke(isNext || isDone ? area.tint : Color(hex: 0xC7B493), lineWidth: 1.4)
                            )
                        Image(systemName: isDone ? "shoeprints.fill" : "circle.fill")
                            .luminaFont(size: isDone ? 16 : 8, weight: .black)
                            .foregroundColor(isDone ? Color(hex: 0xFFF8E8) : Color(hex: 0xB9A783))
                    }
                    .frame(maxWidth: .infinity)
                    .scaleEffect(isNext && !isDone ? 1.04 : 1)
                }
                .buttonStyle(.plain)
                .disabled(isCompletedToday || (!isDone && !isNext))
                .accessibilityLabel("Route stone \(index + 1)")
            }
        }
    }
}

private struct GardenLanternMiniGame: View {
    let area: GardenMapAreaKind
    let isCompletedToday: Bool
    @Binding var completedSteps: Set<Int>

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<area.miniGameKind.requiredSteps, id: \.self) { index in
                let isLit = isCompletedToday || completedSteps.contains(index)

                Button {
                    guard !isCompletedToday else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        _ = completedSteps.insert(index)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isLit ? Color(hex: 0xFFD66B).opacity(0.35) : Color(hex: 0xE1D5BC).opacity(0.70))
                            .blur(radius: isLit ? 4 : 0)
                            .frame(width: 54, height: 54)
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isLit ? area.tint : Color(hex: 0xD3C4A7))
                            .frame(width: 48, height: 54)
                            .overlay(
                                Image(systemName: isLit ? "flame.fill" : "flame")
                                    .luminaFont(size: 18, weight: .black)
                                    .foregroundColor(isLit ? Color(hex: 0xFFF8E8) : Color(hex: 0x82725B))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: 0xFFF8E8).opacity(isLit ? 0.65 : 0.20), lineWidth: 1)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(isCompletedToday || isLit)
                .accessibilityLabel("Lantern \(index + 1)")
            }
        }
    }
}

private struct GardenArchiveMiniGame: View {
    let area: GardenMapAreaKind
    let isCompletedToday: Bool
    @Binding var completedSteps: Set<Int>

    private let cards: [(title: String, icon: String)] = [
        ("Seed", "leaf.fill"),
        ("Cue", "note.text"),
        ("Glow", "sparkles")
    ]

    var body: some View {
        HStack(spacing: 9) {
            ForEach(cards.indices, id: \.self) { index in
                let isFiled = isCompletedToday || completedSteps.contains(index)

                Button {
                    guard !isCompletedToday else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        _ = completedSteps.insert(index)
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: cards[index].icon)
                            .luminaFont(size: 17, weight: .black)
                        Text(cards[index].title)
                            .luminaFont(size: 10, weight: .black, design: .rounded)
                            .lineLimit(1)
                    }
                    .foregroundColor(isFiled ? Color(hex: 0xFFF8E8) : Color(hex: 0x6F604B))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(isFiled ? area.tint : Color(hex: 0xFFF8E8))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isFiled ? Color(hex: 0xFFF8E8).opacity(0.55) : Color(hex: 0xD8C8AB), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isCompletedToday || isFiled)
                .accessibilityLabel("Archive \(cards[index].title)")
            }
        }
    }
}

private struct GardenAreaMilestonePill: View {
    let area: GardenMapAreaKind
    let milestone: GardenAreaMilestoneUnlock

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark")
                .luminaFont(size: 9, weight: .black)
            Text(area.milestoneTitle(stage: milestone.stage))
                .luminaFont(size: 10, weight: .black, design: .rounded)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .foregroundColor(Color(hex: 0xFFF8E8))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(area.tint)
        .clipShape(Capsule())
    }
}

private struct GardenVisitorInvitationSheet: View {
    let invitation: GardenVisitorInvitation
    let progress: Int
    let onAccept: () -> Void
    let onSettleGift: () -> Void
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var didAccept = false

    private var isAccepted: Bool {
        invitation.isAccepted || didAccept
    }

    private var clampedProgress: Int {
        min(progress, invitation.targetCount)
    }

    private var progressFraction: CGFloat {
        guard invitation.targetCount > 0 else { return 0 }
        return min(1, CGFloat(progress) / CGFloat(invitation.targetCount))
    }

    private var canPlaceGift: Bool {
        isAccepted && progress >= invitation.targetCount
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    invitationCard
                    GardenKeepsakeGiftRow(kind: GardenKeepsakeKind.keepsake(for: invitation.visitor))
                    GardenAreaOpeningRow(area: GardenMapAreaKind.area(for: GardenKeepsakeKind.keepsake(for: invitation.visitor)))
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 14)
            }

            actionBar
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 18)
                .background(Color(hex: 0xFFF8E8).opacity(0.96))
        }
        .background(Color(hex: 0xFFF8E8).ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                Text("Grove visitor")
                    .luminaFont(size: 12, weight: .black)
                    .foregroundColor(Color(hex: 0x82725B))
                    .textCase(.uppercase)
                Spacer(minLength: 0)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .luminaFont(size: 13, weight: .black)
                        .foregroundColor(Color(hex: 0x78664E))
                        .frame(width: 34, height: 34)
                        .background(Color(hex: 0xF2E5CE))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close grove visitor")
            }

            HStack(alignment: .center, spacing: 13) {
                GardenVisitorPortrait(visitor: invitation.visitor, isReady: canPlaceGift)

                VStack(alignment: .leading, spacing: 5) {
                    Text(invitation.visitor.displayName)
                        .luminaFont(size: 25, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x3F3428))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(invitation.visitor.roleTitle)
                        .luminaFont(size: 11, weight: .black)
                        .foregroundColor(invitation.visitor.accent)
                        .textCase(.uppercase)
                        .lineLimit(1)
                    Text(invitation.visitor.message)
                        .luminaFont(size: 14, weight: .semibold)
                        .foregroundColor(Color(hex: 0x6F604B))
                        .lineSpacing(2)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
            }
        }
    }

    private var invitationCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: invitation.invitationKind.systemImage)
                    .luminaFont(size: 16, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 40, height: 40)
                    .background(invitation.visitor.accent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(invitation.invitationKind.title)
                        .luminaFont(size: 17, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(invitation.invitationKind.detail)
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundColor(Color(hex: 0x82725B))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0xE4D4B6))
                    Capsule()
                        .fill(canPlaceGift ? Color(hex: 0x5FA461) : invitation.visitor.accent)
                        .frame(width: max(8, geo.size.width * progressFraction))
                }
            }
            .frame(height: 10)

            HStack(spacing: 8) {
                Text("\(clampedProgress)/\(invitation.targetCount) noticed")
                    .luminaFont(size: 12, weight: .black)
                    .foregroundColor(canPlaceGift ? Color(hex: 0x5FA461) : Color(hex: 0x82725B))
                    .lineLimit(1)

                Spacer(minLength: 0)

                GardenSoftDewBadge(label: "dew")
            }
        }
        .padding(14)
        .background(Color(hex: 0xF7E8C8))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: 0xDEC797), lineWidth: 1)
        )
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if !isAccepted {
                Button {
                    didAccept = true
                    onAccept()
                } label: {
                    Label("Stay with this", systemImage: "checkmark.circle.fill")
                        .luminaFont(size: 15, weight: .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(invitation.visitor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    onDismiss()
                } label: {
                    Text("Not now")
                        .luminaFont(size: 15, weight: .black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(width: 108, height: 50)
                        .foregroundColor(Color(hex: 0x7E735F))
                        .background(Color(hex: 0xEFE4D0))
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if canPlaceGift {
                Button(action: onSettleGift) {
                    Label("Place the gift", systemImage: "gift.fill")
                        .luminaFont(size: 15, weight: .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(Color(hex: 0xD99A32))
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    dismiss()
                } label: {
                    Label("Continue exploring", systemImage: "figure.walk")
                        .luminaFont(size: 15, weight: .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(Color(hex: 0x4E4034))
                        .background(Color(hex: 0xEFE4D0))
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct GardenVisitorPortrait: View {
    let visitor: GardenVisitorKind
    let isReady: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(visitor.accent.opacity(0.14))
                .frame(width: 76, height: 86)

            GardenGroundShadow(width: 46, height: 10, opacity: 0.16, blurRadius: 0.7)
                .offset(y: 31)

            Image(visitor.portraitAssetName)
                .interpolation(.high)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 80)
                .shadow(color: Color(hex: 0x17381F).opacity(0.16), radius: 4, x: 0, y: 3)
                .offset(y: 3)

            if isReady {
                Image(systemName: "gift.fill")
                    .luminaFont(size: 10, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 24, height: 22)
                    .background(visitor.accent)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.66), lineWidth: 1))
                    .offset(x: 27, y: -30)
            }
        }
        .frame(width: 78, height: 88)
    }
}

private struct GardenKeepsakeGiftRow: View {
    let kind: GardenKeepsakeKind

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: kind.icon)
                .luminaFont(size: 15, weight: .black)
                .foregroundColor(Color(hex: 0xFFF8E8))
                .frame(width: 36, height: 36)
                .background(kind.tint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Places \(kind.title)")
                    .luminaFont(size: 14, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0x4E4034))
                    .lineLimit(1)
                Text(kind.detail)
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(Color(hex: 0x82725B))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(hex: 0xFFF4D6))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(kind.tint.opacity(0.28), lineWidth: 1)
        )
    }
}

private struct GardenAreaOpeningRow: View {
    let area: GardenMapAreaKind

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: area.icon)
                .luminaFont(size: 15, weight: .black)
                .foregroundColor(Color(hex: 0xFFF8E8))
                .frame(width: 36, height: 36)
                .background(area.tint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Opens \(area.title)")
                    .luminaFont(size: 14, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0x4E4034))
                    .lineLimit(1)
                Text(area.detail)
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(Color(hex: 0x82725B))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(hex: 0xF2F6D9))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(area.tint.opacity(0.28), lineWidth: 1)
        )
    }
}

private struct GardenHabitDetailSheet: View {
    let habit: Habit
    let displayIndex: Int
    let sourceEntry: JournalEntry?
    let sourceMicroPlan: MicroPlan?
    let isCompletedToday: Bool
    let waterDrops: Int
    let onComplete: () -> Void
    let onWater: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var canWater: Bool {
        waterDrops > 0 && habit.plantType != .tree
    }

    private var clampedGrowth: Int {
        min(max(habit.growth, 0), 100)
    }

    private var growthProgress: CGFloat {
        CGFloat(clampedGrowth) / 100
    }

    private var descriptor: GardenTraceObjectDescriptor {
        GardenTraceObjectDescriptor.resolve(for: habit, displayIndex: displayIndex)
    }

    private var plantTint: Color {
        descriptor.tint
    }

    private var originTitle: String {
        descriptor.source.originTitle
    }

    private var originIcon: String {
        descriptor.source.icon
    }

    private var traceAssetName: String {
        descriptor.object.assetName
    }

    private var traceAssetSize: CGSize {
        descriptor.object.assetSize
    }

    private var stageTitle: String {
        descriptor.stageTitle(for: habit.plantType)
    }

    private var traceAgeText: String {
        descriptor.ageText(createdAt: habit.createdAt)
    }

    private var memoryText: String {
        if isCompletedToday {
            return "This \(descriptor.object.title.lowercased()) has already been touched today."
        }
        if let sourceEntry {
            return "This \(descriptor.object.title.lowercased()) came from your reflection on \(sourceEntry.date). It stays visible so the moment can be revisited."
        }
        if let sourceMicroPlan {
            return "This \(descriptor.object.title.lowercased()) came from Therapy. When \(sourceMicroPlan.trigger), the next gentle step is: \(sourceMicroPlan.action)"
        }
        switch habit.plantType {
        case .seed:
            return "A small intention is here. One gentle return is enough."
        case .sprout:
            return "This has started to become easier to notice."
        case .flower:
            return "A few steady days are now visible here."
        case .tree:
            return "This has become part of the grove. It can anchor harder days."
        }
    }

    private var waterTitle: String {
        if habit.plantType == .tree {
            return "Rooted"
        }
        if waterDrops <= 0 {
            return "No dew"
        }
        return "Water"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 13) {
                header

                GardenTraceOriginCard(
                    descriptor: descriptor,
                    ageText: traceAgeText
                )

                GardenHabitMemoryCard(message: memoryText, tint: plantTint)

                if sourceEntry != nil || sourceMicroPlan != nil {
                    GardenHabitSourceCard(
                        habit: habit,
                        sourceEntry: sourceEntry,
                        sourceMicroPlan: sourceMicroPlan,
                        sourceKind: descriptor.source,
                        tint: plantTint
                    )
                }

                GardenHabitProgressMeter(
                    value: growthProgress,
                    percentage: clampedGrowth,
                    tint: plantTint
                )
                .opacity(0.72)

                GardenHabitActionButton(
                    title: isCompletedToday ? "Touched" : "Touch this trace",
                    systemImage: isCompletedToday ? "checkmark.circle.fill" : "sparkles",
                    foreground: isCompletedToday ? Color.white : Color(hex: 0xFFF8E8),
                    background: isCompletedToday ? Color(hex: 0x5FA461) : Color(hex: 0x5B7445),
                    border: isCompletedToday ? Color(hex: 0x5FA461) : Color(hex: 0x5B7445),
                    isDisabled: isCompletedToday,
                    action: onComplete
                )
                .accessibilityHint(isCompletedToday ? "This trace has already been touched." : "Gently notices this trace.")
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: 0xFFF8E8), Color(hex: 0xF8E6C4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: originIcon)
                        .luminaFont(size: 11, weight: .black)
                    Text(originTitle)
                        .luminaFont(size: 12, weight: .black)
                }
                .luminaFont(size: 13, weight: .black)
                .foregroundColor(Color(hex: 0x86745B))
                Spacer(minLength: 0)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .luminaFont(size: 13, weight: .black)
                        .foregroundColor(Color(hex: 0x78664E))
                        .frame(width: 34, height: 34)
                        .background(Color(hex: 0xF1E4CA))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close garden memory")
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(habit.title)
                        .luminaFont(size: 22, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x3F3428))
                        .lineLimit(2)
                        .minimumScaleFactor(0.80)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(stageTitle)
                        .luminaFont(size: 12, weight: .black)
                        .foregroundColor(plantTint)
                        .textCase(.uppercase)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
                .layoutPriority(2)

                Spacer(minLength: 0)

                GardenMemoryPreviewCard(
                    assetName: traceAssetName,
                    size: traceAssetSize,
                    tint: plantTint
                )
            }
        }
    }
}

private struct GardenMemoryPreviewCard: View {
    let assetName: String
    let size: CGSize
    let tint: Color

    var body: some View {
        ZStack {
            GardenTraceNest(tint: tint, variant: assetName.unicodeScalars.reduce(0) { $0 + Int($1.value) }, intensity: 0.58)
                .scaleEffect(0.74)
                .offset(y: 15)

            GardenTraceAssetNode(
                assetName: assetName,
                size: size,
                tint: tint,
                isRooted: true
            )
        }
        .frame(width: 78, height: 74)
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: 0xFFF2DD).opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}

private struct GardenTraceOriginCard: View {
    let descriptor: GardenTraceObjectDescriptor
    let ageText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: descriptor.source.icon)
                    .luminaFont(size: 11, weight: .black)
                    .foregroundColor(descriptor.tint)

                Text(descriptor.source.title)
                    .luminaFont(size: 11, weight: .black)
                    .foregroundColor(Color(hex: 0x7B6D55))
                    .textCase(.uppercase)
                    .tracking(1.0)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(ageText)
                    .luminaFont(size: 10, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0x7B6D55))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(hex: 0xFFF8E8).opacity(0.72))
                    .clipShape(Capsule())
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: descriptor.object.icon)
                    .luminaFont(size: 13, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 30, height: 30)
                    .background(descriptor.tint)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(descriptor.object.title)
                        .luminaFont(size: 15, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(descriptor.object.meaning)
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundColor(Color(hex: 0x6F624E))
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(descriptor.source.detail)
                        .luminaFont(size: 11, weight: .semibold)
                        .foregroundColor(Color(hex: 0x8A7A61))
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFFF4D6).opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(descriptor.tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct GardenHabitPlantCard: View {
    let type: PlantType
    let tint: Color

    private var illustrationScale: CGFloat {
        switch type {
        case .seed: return 0.92
        case .sprout: return 0.88
        case .flower: return 0.84
        case .tree: return 0.68
        }
    }

    var body: some View {
        ZStack {
            GardenPlantIllustration(type: type)
                .scaleEffect(illustrationScale)
        }
            .frame(width: 74, height: 74)
            .clipped()
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xFFF2DD), tint.opacity(0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(hex: 0xF0D8B3), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

private struct GardenHabitMemoryCard: View {
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "leaf.fill")
                .luminaFont(size: 13, weight: .black)
                .foregroundColor(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.13))
                .clipShape(Circle())

            Text(message)
                .luminaFont(size: 14, weight: .semibold)
                .foregroundColor(Color(hex: 0x5F533F))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFFF0D3))
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(Color(hex: 0xDEC797), lineWidth: 1)
        )
    }
}

private struct GardenHabitSourceCard: View {
    let habit: Habit
    let sourceEntry: JournalEntry?
    let sourceMicroPlan: MicroPlan?
    let sourceKind: GardenTraceSourceKind
    let tint: Color

    private var title: String {
        sourceKind.sourceCardTitle
    }

    private var detail: String {
        if let sourceEntry {
            return sourceEntry.summary ?? sourceEntry.reflection ?? habit.description
        }
        if let sourceMicroPlan {
            if let support = sourceMicroPlan.support, !support.isEmpty {
                return support
            }
            return "A tiny plan for when \(sourceMicroPlan.trigger)."
        }
        return habit.description
    }

    private var icon: String {
        sourceKind.icon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .luminaFont(size: 12, weight: .black)
                    .foregroundColor(tint)
                Text(title)
                    .luminaFont(size: 11, weight: .black)
                    .foregroundColor(Color(hex: 0x7B6D55))
                    .textCase(.uppercase)
                    .tracking(1.1)
                Spacer(minLength: 0)
            }

            Text(detail)
                .luminaFont(size: 13, weight: .semibold)
                .foregroundColor(Color(hex: 0x5F533F))
                .lineSpacing(2)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFFF8E8).opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.20), lineWidth: 1)
        )
    }
}

private struct GardenHabitProgressMeter: View {
    let value: CGFloat
    let percentage: Int
    let tint: Color

    private var normalizedValue: CGFloat {
        min(max(value, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rootedness")
                    .luminaFont(size: 12, weight: .black)
                    .foregroundColor(Color(hex: 0x7E735F))
                Spacer()
                Text("\(percentage)%")
                    .luminaFont(size: 12, weight: .black)
                    .foregroundColor(Color(hex: 0x4E4034))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: 0xE8DAC2))
                    if normalizedValue > 0 {
                        Capsule()
                            .fill(tint)
                            .frame(width: max(8, geo.size.width * normalizedValue))
                    }
                }
            }
            .frame(height: 10)
            .accessibilityLabel("Rootedness \(percentage) percent")
        }
    }
}

private struct GardenHabitActionButton: View {
    let title: String
    let systemImage: String
    let foreground: Color
    let background: Color
    let border: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .luminaFont(size: 15, weight: .black)
                    .frame(width: 18)
                Text(title)
                    .luminaFont(size: 14, weight: .black, design: .rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
        }
        .buttonStyle(GardenPressableButtonStyle(pressedScale: 0.98, pressedOpacity: 0.88))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.78 : 1)
    }
}

private struct GardenMemoryShelfSheet: View {
    let habits: [Habit]
    let waterDrops: Int
    let completedHabitIDsToday: Set<String>
    let prompts: [GardenTracePrompt]
    let keptPromptIDs: Set<String>
    let gardenRhythmStages: [GardenRhythmStage]
    let nextMove: GardenNextMove
    let readyTracePromptCount: Int
    let areaLogs: [GardenAreaLogEntry]
    let starterSeeds: [GardenStarterSeed]
    let followUp: FollowUp?
    let onSelect: (Habit) -> Void
    let onSelectArea: (GardenMapAreaKind) -> Void
    let onComplete: (Habit) -> Void
    let onPlantStarter: (GardenStarterSeed) -> Void
    let onTouchPrompt: (GardenTracePrompt) -> Void
    let onCompleteFollowUp: (FollowUp) -> Void
    let onSnoozeFollowUp: (FollowUp) -> Void
    let onMarkFollowUpTooHard: (FollowUp) -> Void

    @State private var showOptionalTending = false

    private var journalMemoryCount: Int {
        habits.filter { $0.sourceJournalEntryID != nil }.count
    }

    private var therapySeedCount: Int {
        habits.filter { $0.sourceMicroPlanID != nil }.count
    }

    private var gardenPracticeCount: Int {
        max(0, habits.count - journalMemoryCount - therapySeedCount)
    }

    private var optionalItemCount: Int {
        prompts.count + starterSeeds.count + areaLogs.count + gardenRhythmStages.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory Shelf")
                        .luminaFont(size: 28, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                    Text("Open what your reflections and conversations left here. Nothing is due.")
                        .luminaFont(size: 13, weight: .semibold)
                        .foregroundColor(Color(hex: 0x82735B))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 6)

                GardenMemorySummaryCard(
                    journalMemoryCount: journalMemoryCount,
                    therapySeedCount: therapySeedCount,
                    gardenPracticeCount: gardenPracticeCount
                )

                if let followUp {
                    FollowUpCheckInCard(
                        followUp: followUp,
                        onDone: { onCompleteFollowUp(followUp) },
                        onLater: { onSnoozeFollowUp(followUp) },
                        onTooHard: { onMarkFollowUpTooHard(followUp) }
                    )
                    .padding(.vertical, 2)
                }

                GardenTraceListSection(
                    habits: habits,
                    completedHabitIDsToday: completedHabitIDsToday,
                    onSelect: onSelect,
                    onComplete: onComplete
                )

                GardenOptionalTendingSection(
                    isExpanded: $showOptionalTending,
                    itemCount: optionalItemCount,
                    rhythmCard: {
                        GardenQuietReturnCard(
                            stages: gardenRhythmStages,
                            nextMove: nextMove,
                            readyTracePromptCount: readyTracePromptCount
                        )
                    },
                    starterSeedSection: {
                        if !starterSeeds.isEmpty {
                            GardenStarterSeedSection(
                                seeds: starterSeeds,
                                onPlant: onPlantStarter
                            )
                        }
                    },
                    promptSection: {
                        if !prompts.isEmpty {
                            VStack(spacing: 9) {
                                ForEach(prompts) { prompt in
                                    GardenTracePromptRow(
                                        prompt: prompt,
                                        isKept: keptPromptIDs.contains(prompt.id),
                                        onTouch: { onTouchPrompt(prompt) }
                                    )
                                }
                            }
                        }
                    },
                    areaLogSection: {
                        GardenAreaLogBookSection(
                            entries: areaLogs,
                            onSelectArea: onSelectArea
                        )
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
        .background(Color(hex: 0xF5E0B5).ignoresSafeArea())
    }
}

private struct GardenMemorySummaryCard: View {
    let journalMemoryCount: Int
    let therapySeedCount: Int
    let gardenPracticeCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "leaf.fill")
                    .luminaFont(size: 15, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: 0x6D8B5F))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("What the grove is holding")
                        .luminaFont(size: 17, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                    Text("A quiet record of what you have written, practiced, and chosen to remember.")
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundColor(Color(hex: 0x82735B))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
            }

            HStack(spacing: 8) {
                GardenMemoryMetricPill(value: "\(journalMemoryCount)", label: "Memories", systemImage: "book.closed.fill", tint: Color(hex: 0x6D8B5F))
                GardenMemoryMetricPill(value: "\(therapySeedCount)", label: "Paths", systemImage: "sparkles", tint: Color(hex: 0xB9822C))
                GardenMemoryMetricPill(value: "\(gardenPracticeCount)", label: "Practices", systemImage: "leaf.fill", tint: Color(hex: 0x4A9F94))
            }

            if gardenPracticeCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw.fill")
                        .luminaFont(size: 10, weight: .black)
                    Text("\(gardenPracticeCount) quiet practice\(gardenPracticeCount == 1 ? "" : "s") are also here.")
                        .luminaFont(size: 11, weight: .black, design: .rounded)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .foregroundColor(Color(hex: 0x7B6C55))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(hex: 0xFFF8E8).opacity(0.60))
                .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color(hex: 0xFFF4D6))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: 0xD9B978), lineWidth: 1)
        )
    }
}

private struct GardenMemoryMetricPill: View {
    let value: String
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .luminaFont(size: 10, weight: .black)
                .foregroundColor(tint)
            Text(value)
                .luminaFont(size: 13, weight: .black, design: .rounded)
                .foregroundColor(Color(hex: 0x4E4034))
            Text(label)
                .luminaFont(size: 10, weight: .black, design: .rounded)
                .foregroundColor(Color(hex: 0x887965))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 7)
        .padding(.vertical, 8)
        .background(Color(hex: 0xFFF8E8).opacity(0.82))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.20), lineWidth: 1))
    }
}

private struct GardenTraceListSection: View {
    let habits: [Habit]
    let completedHabitIDsToday: Set<String>
    let onSelect: (Habit) -> Void
    let onComplete: (Habit) -> Void

    private var visibleHabits: [Habit] {
        Array(habits.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent traces")
                        .luminaFont(size: 18, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                    Text("Tap one to open the memory behind it.")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(Color(hex: 0x887965))
                }

                Spacer(minLength: 0)

                if !habits.isEmpty {
                    Text("\(habits.count)")
                        .luminaFont(size: 12, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x6D5235))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color(hex: 0xFFF8E8).opacity(0.86))
                        .clipShape(Capsule())
                }
            }

            if habits.isEmpty {
                GardenEmptyRoutineCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(visibleHabits.enumerated()), id: \.element.id) { index, habit in
                        GardenTraceRow(
                            habit: habit,
                            displayIndex: index,
                            isCompletedToday: completedHabitIDsToday.contains(habit.id),
                            onSelect: { onSelect(habit) },
                            onComplete: { onComplete(habit) }
                        )
                    }
                }

                if habits.count > visibleHabits.count {
                    Text("\(habits.count - visibleHabits.count) more trace\(habits.count - visibleHabits.count == 1 ? "" : "s") are resting in the grove scene.")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(Color(hex: 0x887965))
                        .padding(.horizontal, 4)
                }
            }
        }
    }
}

private struct GardenTraceRow: View {
    let habit: Habit
    let displayIndex: Int
    let isCompletedToday: Bool
    let onSelect: () -> Void
    let onComplete: () -> Void

    private var descriptor: GardenTraceObjectDescriptor {
        GardenTraceObjectDescriptor.resolve(for: habit, displayIndex: displayIndex)
    }

    private var sourceIcon: String {
        descriptor.source.icon
    }

    private var sourceTint: Color {
        descriptor.tint
    }

    private var subtitle: String {
        if isCompletedToday { return "Touched gently" }
        if habit.sourceJournalEntryID != nil { return "\(descriptor.object.title), \(habit.growth)% rooted" }
        if habit.sourceMicroPlanID != nil { return "\(descriptor.object.title), only when useful" }
        return "\(habit.growth)% rooted · optional return"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            GardenTraceNest(tint: sourceTint, variant: displayIndex, intensity: 0.46)
                                .scaleEffect(0.46)
                                .offset(y: 10)

                            GardenTraceAssetNode(
                                assetName: descriptor.object.assetName,
                                size: CGSize(
                                    width: descriptor.object.assetSize.width * 0.74,
                                    height: descriptor.object.assetSize.height * 0.74
                                ),
                                tint: sourceTint,
                                isRooted: habit.growth >= 72
                            )
                        }
                        .frame(width: 56, height: 56)
                        .background(Color(hex: 0xF3E1B8).opacity(0.84))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Image(systemName: sourceIcon)
                            .luminaFont(size: 9, weight: .black)
                            .foregroundColor(Color(hex: 0xFFF8E8))
                            .frame(width: 22, height: 22)
                            .background(sourceTint)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(hex: 0xFFF8E8), lineWidth: 1.5))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(descriptor.source.title)
                            .luminaFont(size: 9, weight: .black, design: .rounded)
                            .foregroundColor(sourceTint)
                            .textCase(.uppercase)
                            .tracking(1.4)
                            .lineLimit(1)

                        Text(habit.title)
                            .luminaFont(size: 15, weight: .black, design: .rounded)
                            .foregroundColor(Color(hex: 0x4E4034))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)

                        Text(subtitle)
                            .luminaFont(size: 11, weight: .bold)
                            .foregroundColor(Color(hex: 0x887965))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onComplete) {
                Group {
                    if isCompletedToday {
                        Image(systemName: "checkmark.circle.fill")
                            .luminaFont(size: 21, weight: .black)
                            .frame(width: 42, height: 42)
                    } else {
                        Text("Touch")
                            .luminaFont(size: 11, weight: .black, design: .rounded)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(hex: 0xF1E7D4))
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(isCompletedToday ? Color(hex: 0x5FA461) : Color(hex: 0x6D8B5F))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCompletedToday ? "Already touched" : "Touch this trace")
        }
        .padding(12)
        .background(Color(hex: 0xFFF4D6))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: 0xD9B978).opacity(0.82), lineWidth: 1)
        )
    }
}

private struct GardenOptionalTendingSection<Rhythm: View, StarterSeeds: View, Prompts: View, AreaLogs: View>: View {
    @Binding var isExpanded: Bool
    let itemCount: Int
    @ViewBuilder let rhythmCard: () -> Rhythm
    @ViewBuilder let starterSeedSection: () -> StarterSeeds
    @ViewBuilder let promptSection: () -> Prompts
    @ViewBuilder let areaLogSection: () -> AreaLogs
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var expansionAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.22)
    }

    private var expansionTransition: AnyTransition {
        reduceMotion
            ? .identity
            : .opacity.combined(with: .scale(scale: 0.985, anchor: .top))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Button {
                withAnimation(expansionAnimation) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "tray.full.fill")
                        .luminaFont(size: 13, weight: .black)
                        .foregroundColor(Color(hex: 0xFFF8E8))
                        .frame(width: 30, height: 30)
                        .background(Color(hex: 0x8A6A47))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quiet returns")
                            .luminaFont(size: 16, weight: .black, design: .rounded)
                            .foregroundColor(Color(hex: 0x4E4034))
                        Text("Visitors, dew, and area memories stay tucked away.")
                            .luminaFont(size: 11, weight: .bold)
                            .foregroundColor(Color(hex: 0x887965))
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 10)

                    if itemCount > 0 {
                        Text("\(itemCount)")
                            .luminaFont(size: 10, weight: .black, design: .rounded)
                            .foregroundColor(Color(hex: 0x6D5235))
                            .frame(width: 24, height: 24)
                            .background(Color(hex: 0xFFF8E8).opacity(0.78))
                            .clipShape(Circle())
                    }

                    Image(systemName: "chevron.down")
                        .luminaFont(size: 12, weight: .black)
                        .foregroundColor(Color(hex: 0x7B6C55))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(hex: 0xEBD2A4).opacity(0.70))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(hex: 0xC59D60).opacity(0.62), lineWidth: 1)
                )
            }
            .buttonStyle(GardenPressableButtonStyle(pressedScale: 0.985, pressedOpacity: 0.92))

            if isExpanded {
                VStack(spacing: 12) {
                    rhythmCard()
                    starterSeedSection()
                    promptSection()
                    areaLogSection()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
                .transition(expansionTransition)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(expansionAnimation, value: isExpanded)
    }
}

private struct GardenQuietReturnCard: View {
    let stages: [GardenRhythmStage]
    let nextMove: GardenNextMove
    let readyTracePromptCount: Int

    private var completedCount: Int {
        stages.filter(\.isComplete).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "map.fill")
                    .luminaFont(size: 14, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: 0x7D6A54))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("If you want to return")
                        .luminaFont(size: 17, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                    Text("One quiet touch is enough. Nothing breaks if you skip it.")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(Color(hex: 0x887965))
                        .lineLimit(2)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                Text(completedCount == 0 ? "quiet" : "\(completedCount) kept")
                    .luminaFont(size: 12, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0x6D5235))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 56)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color(hex: 0xFFF8E8).opacity(0.82))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                ForEach(stages) { stage in
                    GardenLoopStagePill(stage: stage)
                }
            }

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: nextMove.systemImage)
                    .luminaFont(size: 13, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 30, height: 30)
                    .background(nextMove.tint)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(nextMove.title)
                        .luminaFont(size: 14, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(nextMove.detail)
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(Color(hex: 0x887965))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                if readyTracePromptCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .luminaFont(size: 9, weight: .black)
                        Text("\(readyTracePromptCount)")
                            .luminaFont(size: 11, weight: .black, design: .rounded)
                    }
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(hex: 0xD99A32))
                    .clipShape(Capsule())
                }
            }
            .padding(10)
            .background(Color(hex: 0xFFF4D6))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(nextMove.tint.opacity(0.22), lineWidth: 1)
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xEBD2A4))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: 0xC59D60), lineWidth: 1.1)
        )
    }
}

private struct GardenLoopStagePill: View {
    let stage: GardenRhythmStage

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: stage.isComplete ? "checkmark" : stage.systemImage)
                .luminaFont(size: 12, weight: .black)
                .foregroundColor(stage.isComplete ? Color(hex: 0xFFF8E8) : stage.tint)
                .frame(width: 28, height: 28)
                .background(stage.isComplete ? stage.tint : Color(hex: 0xFFF8E8))
                .clipShape(Circle())
                .overlay(Circle().stroke(stage.tint.opacity(0.24), lineWidth: 1))

            VStack(spacing: 1) {
                Text(stage.title)
                    .luminaFont(size: 11, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0x4E4034))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(stage.progressText)
                    .luminaFont(size: 9, weight: .black, design: .rounded)
                    .foregroundColor(stage.isComplete ? stage.tint : Color(hex: 0x887965))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(stage.isComplete ? stage.tint.opacity(0.13) : Color(hex: 0xFFF4D6))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(stage.isComplete ? stage.tint.opacity(0.28) : Color(hex: 0xD9B978), lineWidth: 1)
        )
        .accessibilityLabel("\(stage.title), \(stage.progressText)")
    }
}

private struct GardenStarterSeedSection: View {
    let seeds: [GardenStarterSeed]
    let onPlant: (GardenStarterSeed) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "leaf.fill")
                    .luminaFont(size: 14, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 30, height: 30)
                    .background(Color(hex: 0x6D8B5F))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text("Leave a small practice")
                        .luminaFont(size: 17, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                    Text("Choose one gentle practice. It becomes a quiet trace only if it helps.")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(Color(hex: 0x887965))
                        .lineLimit(2)
                }
            }

            VStack(spacing: 8) {
                ForEach(seeds) { seed in
                    Button {
                        onPlant(seed)
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: seed.systemImage)
                                .luminaFont(size: 15, weight: .black)
                                .foregroundColor(Color(hex: 0xFFFDF4))
                                .frame(width: 36, height: 36)
                                .background(seed.tint)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(seed.title)
                                    .luminaFont(size: 15, weight: .black, design: .rounded)
                                    .foregroundColor(Color(hex: 0x4E4034))
                                    .lineLimit(1)
                                Text(seed.detail)
                                    .luminaFont(size: 11, weight: .bold)
                                    .foregroundColor(Color(hex: 0x887965))
                                    .lineLimit(1)
                            }
                            .layoutPriority(1)

                            Image(systemName: "plus.circle.fill")
                                .luminaFont(size: 20, weight: .black)
                                .foregroundColor(seed.tint)
                        }
                        .padding(10)
                        .background(Color(hex: 0xFFF4D6))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(hex: 0xEBD2A4))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: 0xC59D60), lineWidth: 1.1)
        )
    }
}

private struct GardenEmptyRoutineCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.circle.fill")
                .luminaFont(size: 24, weight: .black)
                .foregroundColor(Color(hex: 0x6D8B5F))
                .frame(width: 48, height: 48)
                .background(Color(hex: 0xEEF0CF))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("No traces here yet")
                    .luminaFont(size: 16, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0x4E4034))
                Text("Start from a reflection, a Therapy path, or one small practice.")
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(Color(hex: 0x887965))
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Color(hex: 0xFFF4D6))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color(hex: 0xD9B978), lineWidth: 1.2))
    }
}

private struct GardenAreaLogBookSection: View {
    let entries: [GardenAreaLogEntry]
    let onSelectArea: (GardenMapAreaKind) -> Void
    @State private var selectedMemory: GardenAreaChapterMemory?

    private var completedChapterCount: Int {
        entries.reduce(0) { $0 + $1.completedChapterCount }
    }

    private var totalChapterCount: Int {
        entries.reduce(0) { $0 + $1.totalChapterCount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "book.closed.fill")
                    .luminaFont(size: 14, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 30, height: 30)
                    .background(Color(hex: 0x8A6A47))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text("Area Logbook")
                        .luminaFont(size: 17, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                    Text("Collected chapters and visible map changes")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(Color(hex: 0x887965))
                }

                Spacer(minLength: 0)

                Text("\(completedChapterCount)/\(max(totalChapterCount, 1))")
                    .luminaFont(size: 12, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0x6D5235))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color(hex: 0xFFF8E8).opacity(0.82))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(entries) { entry in
                        GardenAreaLogBookCard(
                            entry: entry,
                            onSelect: { onSelectArea(entry.area) },
                            onSelectMemory: { memory in
                                withAnimation(.easeInOut(duration: 0.20)) {
                                    selectedMemory = memory
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 1)
                .padding(.vertical, 2)
            }

            if let selectedMemory {
                GardenAreaMemoryDetailCard(
                    memory: selectedMemory,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            self.selectedMemory = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .padding(12)
        .background(Color(hex: 0xEBD2A4))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: 0xC59D60), lineWidth: 1.1)
        )
    }
}

private struct GardenAreaLogBookCard: View {
    let entry: GardenAreaLogEntry
    let onSelect: () -> Void
    let onSelectMemory: (GardenAreaChapterMemory) -> Void

    private var statusText: String {
        if !entry.isUnlocked { return "Locked" }
        if entry.completedChapterCount >= entry.totalChapterCount { return "Settled" }
        return "Chapter \(entry.completedChapterCount)/\(entry.totalChapterCount)"
    }

    private var detailText: String {
        if !entry.isUnlocked {
            return "Find its keepsake to open this corner of the grove."
        }
        if let nextChapter = entry.nextChapter {
            return nextChapter.objective
        }
        return "Every current chapter has been restored."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 9) {
                Image(systemName: entry.isUnlocked ? entry.area.icon : "lock.fill")
                    .luminaFont(size: 15, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 36, height: 36)
                    .background(entry.isUnlocked ? entry.area.tint : Color(hex: 0xA99879))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.48), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.area.title)
                        .luminaFont(size: 15, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                        .lineLimit(1)
                    Text(statusText)
                        .luminaFont(size: 10, weight: .black, design: .rounded)
                        .foregroundColor(entry.isUnlocked ? entry.area.tint : Color(hex: 0x8E826F))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if entry.isUnlocked {
                    Image(systemName: "chevron.right")
                        .luminaFont(size: 11, weight: .black)
                        .foregroundColor(entry.area.tint)
                }
            }
            }
            .buttonStyle(.plain)
            .disabled(!entry.isUnlocked)

            HStack(spacing: 5) {
                ForEach(1...entry.totalChapterCount, id: \.self) { chapter in
                    Capsule()
                        .fill(chapter <= entry.completedChapterCount ? entry.area.tint : Color(hex: 0xD7C39D))
                        .frame(width: 34, height: 7)
                }
            }

            Text(detailText)
                .luminaFont(size: 11, weight: .bold)
                .foregroundColor(Color(hex: 0x887965))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(1...entry.totalChapterCount, id: \.self) { chapter in
                    if let memory = entry.completedMemories.first(where: { $0.stage == chapter }) {
                        Button {
                            onSelectMemory(memory)
                        } label: {
                            Text("\(chapter)")
                                .luminaFont(size: 10, weight: .black, design: .rounded)
                                .foregroundColor(Color(hex: 0xFFF8E8))
                                .frame(width: 27, height: 24)
                                .background(entry.area.tint)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(entry.area.title) chapter \(chapter) memory")
                    } else {
                        Text("\(chapter)")
                            .luminaFont(size: 10, weight: .black, design: .rounded)
                            .foregroundColor(Color(hex: 0x9B8A70))
                            .frame(width: 27, height: 24)
                            .background(Color(hex: 0xEFE1C4))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }

            HStack(spacing: 7) {
                GardenAreaLogMiniStat(
                    icon: "shoeprints.fill",
                    text: "\(entry.visitCount)"
                )
                GardenAreaLogMiniStat(
                    icon: "sparkles",
                    text: "\(entry.completedChapterCount)"
                )

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .frame(width: 218, height: 208, alignment: .topLeading)
        .background(entry.isUnlocked ? Color(hex: 0xFFF4D6) : Color(hex: 0xE9D8B6))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(entry.isUnlocked ? entry.area.tint.opacity(0.38) : Color(hex: 0xC7B493), lineWidth: 1)
        )
        .opacity(entry.isUnlocked ? 1 : 0.72)
        .accessibilityLabel("\(entry.area.title) \(statusText)")
    }
}

private struct GardenAreaMemoryDetailCard: View {
    let memory: GardenAreaChapterMemory
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(memory.area.tint.opacity(0.14))
                    .frame(width: 78, height: 86)

                GardenAreaEvolvedGroundPatch(
                    area: memory.area,
                    completedStageCount: memory.stage
                )
                .scaleEffect(0.42)

                GardenAreaStageMark(area: memory.area, stage: memory.stage)
                    .scaleEffect(0.68)
            }
            .frame(width: 78, height: 86)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Chapter \(memory.stage)")
                            .luminaFont(size: 10, weight: .black, design: .rounded)
                            .foregroundColor(memory.area.tint)
                            .textCase(.uppercase)
                        Text(memory.title)
                            .luminaFont(size: 16, weight: .black, design: .rounded)
                            .foregroundColor(Color(hex: 0x4E4034))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .luminaFont(size: 10, weight: .black)
                            .foregroundColor(Color(hex: 0x7B6C55))
                            .frame(width: 24, height: 24)
                            .background(Color(hex: 0xEFE1C4))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Text(memory.story)
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(Color(hex: 0x887965))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 7) {
                    Image(systemName: "map.fill")
                        .luminaFont(size: 10, weight: .black)
                        .foregroundColor(Color(hex: 0xFFF8E8))
                        .frame(width: 24, height: 24)
                        .background(memory.area.tint)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(memory.mapChangeTitle)
                            .luminaFont(size: 11, weight: .black, design: .rounded)
                            .foregroundColor(Color(hex: 0x4E4034))
                        Text(memory.mapChangeDetail)
                            .luminaFont(size: 10, weight: .bold)
                            .foregroundColor(Color(hex: 0x887965))
                            .lineLimit(2)
                    }
                }
                .padding(8)
                .background(Color(hex: 0xFFF8E8).opacity(0.70))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(12)
        .background(Color(hex: 0xFFF4D6))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(memory.area.tint.opacity(0.38), lineWidth: 1)
        )
    }
}

private struct GardenAreaLogMiniStat: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .luminaFont(size: 9, weight: .black)
            Text(text)
                .luminaFont(size: 10, weight: .black, design: .rounded)
        }
        .foregroundColor(Color(hex: 0x6D5235))
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(Color(hex: 0xFFF8E8).opacity(0.75))
        .clipShape(Capsule())
    }
}

private struct GardenTracePromptRow: View {
    let prompt: GardenTracePrompt
    let isKept: Bool
    let onTouch: () -> Void

    private var statusText: String {
        if isKept { return "Seen" }
        if prompt.isComplete { return "Notice" }
        return "\(prompt.progress)/\(prompt.goal)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: prompt.systemImage)
                .luminaFont(size: 16, weight: .black)
                .foregroundColor(prompt.isComplete ? Color(hex: 0xFFFDF4) : Color(hex: 0x7E735F))
                .frame(width: 38, height: 38)
                .background(prompt.isComplete ? Color(hex: 0x5FA461) : Color(hex: 0xEFE1C4))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(prompt.title)
                        .luminaFont(size: 15, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .layoutPriority(1)

                    GardenSoftDewBadge(
                        label: "dew",
                        fontSize: 10,
                        iconSize: 9,
                        horizontalPadding: 7,
                        verticalPadding: 3,
                        background: Color(hex: 0xE9F6FA)
                    )
                }

                Text(prompt.detail)
                    .luminaFont(size: 11, weight: .bold)
                    .foregroundColor(Color(hex: 0x887965))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: 0xDEC797).opacity(0.54))
                        Capsule()
                            .fill(prompt.isComplete ? Color(hex: 0x5FA461) : Color(hex: 0xD99A32))
                            .frame(width: max(8, geo.size.width * prompt.progressFraction))
                    }
                }
                .frame(height: 7)
            }

            Spacer(minLength: 4)

            Button(action: onTouch) {
                Text(statusText)
                    .luminaFont(size: 12, weight: .black, design: .rounded)
                    .foregroundColor(prompt.isComplete && !isKept ? Color.white : Color(hex: 0x7B6C55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(width: 72, height: 36)
                    .background(prompt.isComplete && !isKept ? Color(hex: 0xD99A32) : Color(hex: 0xEFE1C4))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!prompt.isComplete || isKept)
        }
        .padding(12)
        .background(Color(hex: 0xFFF4D6))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(hex: 0xD9B978), lineWidth: 1.1))
    }
}

// MARK: - Shapes

private struct IsometricTileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
