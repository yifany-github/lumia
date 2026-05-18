import SwiftUI

// MARK: - Pixel Sprites

let PIXEL_PALETTE: [Character: Color] = [
    " ": .clear, "o": Color(hex: 0x382B20), "B": Color(hex: 0x64422E), "b": Color(hex: 0x875D42),
    "d": Color(hex: 0x3A210F), "D": Color(hex: 0x4F3018), "P": Color(hex: 0x9E5A32),
    "p": Color(hex: 0xC77E4E), "H": Color(hex: 0xE3A176), "G": Color(hex: 0x1B4F2C),
    "g": Color(hex: 0x3A874B), "L": Color(hex: 0x5DB86F), "h": Color(hex: 0x8EF09E),
    "l": Color(hex: 0x4E9C5C), "F": Color(hex: 0xE05370), "f": Color(hex: 0xFF8CAC),
    "w": Color(hex: 0xFFFDF4), "W": Color(hex: 0xFFCBE1), "Y": Color(hex: 0xFCA103),
    "y": Color(hex: 0xD68700), "S": Color(hex: 0xFCD29F), "s": Color(hex: 0xC79152)
]

let PIXEL_SPRITES: [String: [String]] = [
    "seed": [
        "          oooo          ",
        "         oSSSso         ",
        "        oSssssso        ",
        "        oSssssso        ",
        "         oSSSso         ",
        "          oooo          "
    ],
    "sprout": [
        "         o    o         ",
        "        oho  oho        ",
        "       oLhloohLho       ",
        "        oggoooLgo       ",
        "         oogggo         ",
        "          oGgo          ",
        "          ogGo          ",
        "          oGgo          "
    ],
    "flower": [
        "          oooo          ",
        "         oWWWWo         ",
        "        oWffWfWo        ",
        "       oFfowwoFfo       ",
        "        oFfffffo        ",
        "         offffo         ",
        "          oooo          ",
        "    oo     oGo     oo   ",
        "   oLho    ogL    ohLo  ",
        "  oLgLgo  ooGoo  ogLLLo "
    ],
    "tree": [
        "         oooooo         ",
        "       oohhhhLhoo       ",
        "      ohhLlllLGhho      ",
        "     ohLllLllLhLhlo     ",
        "    ohllllLllLlllhgho   ",
        "   ohLLllllLlLLllLghgo  ",
        "  oLLllLLhhlLLLLllGgGgo ",
        "       ooobBboo         ",
        "         obBbo          ",
        "         oBBbo          "
    ],
    "pot": [
        "  oooooooooooooooooooo  ",
        " oHHppppppppppppppppHPo ",
        " oPPppppppppppppppppPPo ",
        " oooooooooooooooooooooo ",
        "   oPppppppppppppppPo   ",
        "   oPPppppppppppppPPo   ",
        "   oPPPppppppppppPPPo   ",
        "   oPPPPPPPPPPPPPPPPo   ",
        "   oooooooooooooooooo   "
    ]
]

struct PixelSpriteView: View {
    let spriteName: String
    let size: CGFloat

    var body: some View {
        Canvas { ctx, sz in
            guard let sprite = PIXEL_SPRITES[spriteName] else { return }
            let rows = sprite.count
            let cols = sprite.first?.count ?? 0
            guard cols > 0 else { return }

            let pixelWidth = sz.width / CGFloat(cols)
            let pixelHeight = sz.height / CGFloat(rows)
            for (rowIndex, row) in sprite.enumerated() {
                for (columnIndex, character) in Array(row).enumerated() {
                    guard let color = PIXEL_PALETTE[character], color != .clear else { continue }
                    let rect = CGRect(
                        x: CGFloat(columnIndex) * pixelWidth,
                        y: CGFloat(rowIndex) * pixelHeight,
                        width: pixelWidth,
                        height: pixelHeight
                    )
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }
}

// MARK: - Garden Tab

struct GardenTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTool: GardenTool = .explore
    @State private var selectedBuildType: GardenDecorationType = .lamp
    @State private var selectedHabitID: String?
    @State private var showingTaskBoard = false
    @State private var gardenToast: GardenToast?
    @State private var recentlyWateredHabitID: String?
    @State private var avatarPosition = CGPoint(x: 0.50, y: 0.76)
    @State private var keeperIsWalking = false
    @State private var keeperFacesLeft = false
    @State private var keeperMoveToken = UUID()
    @State private var keeperRoamIndex = 0
    @State private var focusedHabitID: String?
    @State private var selectedDailyEventID: String?
    @State private var selectedAreaUnlockID: String?
    @State private var areaRewardBurst: GardenAreaRewardBurst?

    private var completedCount: Int {
        appState.habits.filter { $0.completedAt != nil }.count
    }

    private var averageGrowth: Int {
        guard !appState.habits.isEmpty else { return 0 }
        return appState.habits.reduce(0) { $0 + $1.growth } / appState.habits.count
    }

    private var completedTherapyPlanCount: Int {
        appState.habits.filter { $0.sourceMicroPlanID != nil && $0.completedAt != nil }.count
    }

    private var gatheredForageToday: Int {
        let dayKey = GardenForageItem.dayKey(for: Date())
        return appState.gardenForageItems.filter { $0.dayKey == dayKey && $0.isClaimed }.count
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

    private var areaLogEntries: [GardenAreaLogEntry] {
        GardenAreaLogEntry.entries(
            unlockedAreas: appState.gardenUnlockedAreas,
            visits: appState.gardenAreaVisits,
            milestones: appState.gardenAreaMilestones
        )
    }

    private var gardenQuests: [GardenQuest] {
        let forageDayKey = GardenForageItem.dayKey(for: Date())
        var quests = [
            GardenQuest(
                id: "gather-dew-\(forageDayKey)",
                title: "Gather morning dew",
                detail: "Find three glowing drops hidden around the grove.",
                progress: min(gatheredForageToday, 3),
                goal: 3,
                reward: 2,
                systemImage: "sparkles"
            ),
            GardenQuest(
                id: "tend-two",
                title: "Tend two plots",
                detail: "Finish any two tiny routines today.",
                progress: min(completedCount, 2),
                goal: 2,
                reward: 2,
                systemImage: "checkmark.seal.fill"
            ),
            GardenQuest(
                id: "grow-grove",
                title: "Reach 60% growth",
                detail: "Water and tend until the grove feels alive.",
                progress: min(averageGrowth, 60),
                goal: 60,
                reward: 2,
                systemImage: "leaf.fill"
            ),
            GardenQuest(
                id: "first-build",
                title: "Place a keepsake",
                detail: "Use Build mode to decorate any plot.",
                progress: min(appState.gardenDecorations.count, 1),
                goal: 1,
                reward: 3,
                systemImage: "hammer.fill"
            )
        ]
        if !appState.therapyMicroPlans.isEmpty {
            quests.insert(
                GardenQuest(
                    id: "try-therapy-plan",
                    title: "Try a therapy plan",
                    detail: "Complete one tiny plan created from Therapy.",
                    progress: min(completedTherapyPlanCount, 1),
                    goal: 1,
                    reward: 3,
                    systemImage: "sparkles"
                ),
                at: 0
            )
        }
        return quests
    }

    private var claimableQuestCount: Int {
        gardenQuests.filter { quest in
            quest.isComplete && !appState.claimedGardenQuestIDs.contains(quest.id)
        }.count
    }

    private var selectedHabit: Habit? {
        guard let selectedHabitID else { return nil }
        return appState.habits.first { $0.id == selectedHabitID }
    }

    private var selectedDailyEvent: GardenDailyEvent? {
        guard let selectedDailyEventID else { return nil }
        return appState.gardenDailyEvents.first { $0.id == selectedDailyEventID }
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

    private var showingDailyEventDetail: Binding<Bool> {
        Binding(
            get: { selectedDailyEventID != nil },
            set: { if !$0 { selectedDailyEventID = nil } }
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
            ZStack {
                GardenGameBackdrop()

                    GardenWorldScene(
                        habits: appState.habits,
                        waterDrops: appState.waterDrops,
                        selectedTool: selectedTool,
                        claimableQuestCount: claimableQuestCount,
                        avatarPosition: avatarPosition,
                        keeperIsWalking: keeperIsWalking,
                        keeperFacesLeft: keeperFacesLeft,
                        focusedHabitID: focusedHabitID,
                        decorations: appState.gardenDecorations,
                        forageItems: appState.gardenForageItems.filter { !$0.isClaimed },
                        keepsakes: appState.gardenKeepsakes,
                        unlockedAreas: appState.gardenUnlockedAreas,
                        completedAreaKindsToday: completedAreaKindsToday,
                        areaVisitCounts: areaVisitCounts,
                        areaMilestoneStages: areaMilestoneStages,
                        dailyEvent: appState.activeGardenDailyEvent,
                        dailyEventProgress: appState.activeGardenDailyEvent.map(dailyEventProgress(for:)) ?? 0,
                        recentlyWateredHabitID: recentlyWateredHabitID,
                        onBoardTap: { showingTaskBoard = true },
                        onWateringCanTap: activateWateringCan,
                        onForageTap: handleForageTap,
                        onAreaTap: handleAreaTap,
                        onVisitorTap: handleVisitorTap,
                        onPlotTap: handlePlotTap
                    )

                VStack(spacing: 0) {
                    GardenGameHUD(
                        waterDrops: appState.waterDrops,
                        completedCount: completedCount,
                        totalCount: appState.habits.count,
                        averageGrowth: averageGrowth
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                    if selectedTool == .build {
                        GardenBuildHint(
                            selectedBuildType: selectedBuildType,
                            canAfford: appState.canPlaceGardenDecoration(selectedBuildType)
                        )
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer(minLength: 0)

                    if let gardenToast {
                        GardenToastView(toast: gardenToast)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 10)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    GardenToolbelt(
                        selectedTool: $selectedTool,
                        selectedBuildType: $selectedBuildType
                    )
                        .padding(.bottom, max(10, proxy.safeAreaInsets.bottom + 8))
                }

                if let areaRewardBurst {
                    GardenAreaRewardBurstView(burst: areaRewardBurst)
                        .frame(width: 150, height: 96)
                        .position(
                            x: proxy.size.width * CGFloat(areaRewardBurst.area.mapPosition.x),
                            y: proxy.size.height * CGFloat(areaRewardBurst.area.mapPosition.y)
                        )
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
        }
        .toolbarBackground(.hidden, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
        .onAppear {
            appState.refreshGardenForage()
            appState.refreshGardenDailyEvent()
        }
        .onReceive(Timer.publish(every: gardenKeeperRoamInterval, on: .main, in: .common).autoconnect()) { _ in
            roamKeeperIfIdle()
        }
        .sheet(isPresented: showingHabitDetail) {
            if let habit = selectedHabit {
                GardenHabitDetailSheet(
                    habit: habit,
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
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingTaskBoard) {
            GardenTaskBoardSheet(
                habits: appState.habits,
                waterDrops: appState.waterDrops,
                quests: gardenQuests,
                claimedQuestIDs: appState.claimedGardenQuestIDs,
                areaLogs: areaLogEntries,
                followUp: appState.activeFollowUp,
                onSelect: { habit in
                    showingTaskBoard = false
                    selectedHabitID = habit.id
                },
                onSelectArea: { area in
                    if let unlock = appState.gardenUnlockedAreas.first(where: { $0.area == area }) {
                        showingTaskBoard = false
                        selectedAreaUnlockID = unlock.id
                    }
                },
                onComplete: { habit in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        appState.completeHabit(id: habit.id)
                    }
                },
                onClaimQuest: claimGardenQuest,
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
        .sheet(isPresented: showingDailyEventDetail) {
            if let event = selectedDailyEvent {
                GardenDailyEventSheet(
                    event: event,
                    progress: dailyEventProgress(for: event),
                    onAccept: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            _ = appState.acceptGardenDailyEvent(id: event.id)
                        }
                    },
                    onClaim: {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            if let completedEvent = appState.completeGardenDailyEvent(
                                id: event.id,
                                progress: dailyEventProgress(for: event)
                            ) {
                                selectedDailyEventID = nil
                                showToast(
                                    title: "Visitor reward",
                                    detail: "+\(completedEvent.reward) dew. \(GardenMapAreaKind.reward(for: GardenKeepsakeKind.reward(for: completedEvent.visitor)).title) opened.",
                                    icon: "gift.fill",
                                    tint: Color(hex: 0xD99A32)
                                )
                            }
                        }
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            _ = appState.dismissGardenDailyEvent(id: event.id)
                            selectedDailyEventID = nil
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
                                showAreaRewardBurst(area: unlock.area, reward: result.totalReward)
                                let milestoneText = result.unlockedMilestones.first.map {
                                    " \(unlock.area.milestoneTitle(stage: $0.stage)) unlocked."
                                } ?? ""
                                showToast(
                                    title: result.unlockedMilestones.isEmpty ? "\(unlock.area.title) tended" : "Area milestone",
                                    detail: "+\(result.totalReward) dew.\(milestoneText)",
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

    private func claimGardenQuest(_ quest: GardenQuest) {
        guard quest.isComplete else { return }
        withAnimation(.easeInOut(duration: 0.20)) {
            if appState.claimGardenQuest(id: quest.id, reward: quest.reward) {
                showToast(
                    title: "Quest reward",
                    detail: "+\(quest.reward) dew from \(quest.title).",
                    icon: "gift.fill",
                    tint: Color(hex: 0xD99A32)
                )
            }
        }
    }

    private func activateWateringCan() {
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedTool = .tend
        }
        showToast(
            title: "Tend mode",
            detail: "Tap a plot and your keeper will walk over.",
            icon: "drop.fill",
            tint: Color(hex: 0x309FD2)
        )
    }

    private func handleForageTap(_ item: GardenForageItem) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            if let claimedItem = appState.claimGardenForageItem(id: item.id) {
                showToast(
                    title: "Dew gathered",
                    detail: "+\(claimedItem.reward) dew. Small discoveries now feed the grove.",
                    icon: "sparkles",
                    tint: Color(hex: 0xD99A32)
                )
            }
        }
    }

    private func handleVisitorTap(_ event: GardenDailyEvent) {
        moveKeeper(
            to: CGPoint(x: event.x, y: min(event.y + 0.08, 0.80)),
            duration: 0.58
        )
        selectedDailyEventID = event.id
    }

    private func handleAreaTap(_ unlock: GardenMapAreaUnlock) {
        moveKeeper(
            to: CGPoint(
                x: unlock.area.mapPosition.x,
                y: min(unlock.area.mapPosition.y + 0.09, 0.80)
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

    private func dailyEventProgress(for event: GardenDailyEvent) -> Int {
        switch event.taskKind {
        case .gatherDew:
            return gatheredForageToday
        case .tendPlot:
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
                y: min(plotPosition.y + 0.085, 0.80)
            ),
            duration: 0.56
        )
        withAnimation(.easeInOut(duration: 0.18)) {
            focusedHabitID = habit.id
        }

        switch selectedTool {
        case .explore:
            showToast(
                title: "Walking over",
                detail: "Opening \(habit.title)'s plant journal.",
                icon: "figure.walk",
                tint: Color(hex: 0x7D6A54)
            )
            openJournal(for: habit.id, after: 0.42)
        case .tend:
            if habit.completedAt == nil {
                withAnimation(.easeInOut(duration: 0.22)) {
                    appState.completeHabit(id: habit.id)
                }
                showToast(
                    title: "Quest tended",
                    detail: "+3 dew. The grove remembers this small win.",
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
                title: "Watered",
                detail: "\(habit.title) gained fresh growth.",
                icon: "drop.fill",
                tint: Color(hex: 0x309FD2)
            )
            clearWaterBurst(after: 1.2)
            clearFocus(after: 1.4)
        case .build:
            let decorationType = selectedBuildType
            if placeDecoration(near: habit, at: plotPosition, type: decorationType) {
                showToast(
                    title: "\(decorationType.title) placed",
                    detail: "-\(decorationType.dewCost) dew. The grove keeps what you build.",
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
        !reduceMotion &&
        !ProcessInfo.processInfo.isLowPowerModeEnabled &&
        focusedHabitID == nil &&
        selectedHabitID == nil &&
        selectedDailyEventID == nil &&
        selectedAreaUnlockID == nil &&
        !showingTaskBoard &&
        recentlyWateredHabitID == nil
    }

    private func roamKeeperIfIdle() {
        guard canRoamKeeper, !gardenKeeperRoamingStops.isEmpty else { return }

        let nextIndex = (keeperRoamIndex + 1) % gardenKeeperRoamingStops.count
        keeperRoamIndex = nextIndex
        let destination = gardenKeeperRoamingStops[nextIndex]
        moveKeeper(
            to: destination,
            duration: keeperMoveDuration(from: avatarPosition, to: destination)
        )
    }

    private func moveKeeper(to destination: CGPoint, duration: Double) {
        let clampedDestination = CGPoint(
            x: min(max(destination.x, 0.12), 0.88),
            y: min(max(destination.y, 0.34), 0.80)
        )
        if abs(clampedDestination.x - avatarPosition.x) > 0.012 {
            keeperFacesLeft = clampedDestination.x < avatarPosition.x
        }

        let allowsMotion = !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
        let token = UUID()
        keeperMoveToken = token
        keeperIsWalking = allowsMotion

        let movementAnimation: Animation? = allowsMotion ? .easeInOut(duration: duration) : nil
        withAnimation(movementAnimation) {
            avatarPosition = clampedDestination
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64((duration + 0.10) * 1_000_000_000))
            guard keeperMoveToken == token else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                keeperIsWalking = false
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

    private func placeDecoration(near habit: Habit, at plotPosition: CGPoint, type: GardenDecorationType) -> Bool {
        let offsets = type.offsets
        let usedCount = appState.gardenDecorations.filter { $0.anchorHabitID == habit.id }.count
        let offset = offsets[usedCount % offsets.count]
        let position = CGPoint(
            x: min(max(plotPosition.x + offset.width, 0.10), 0.90),
            y: min(max(plotPosition.y + offset.height, 0.28), 0.73)
        )

        var didPlace = false
        withAnimation(.easeInOut(duration: 0.24)) {
            didPlace = appState.placeGardenDecoration(
                type: type,
                anchorHabitID: habit.id,
                x: Double(position.x),
                y: Double(position.y)
            )
            if didPlace {
                selectedBuildType = type.next
            }
        }
        return didPlace
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

    private func showAreaRewardBurst(area: GardenMapAreaKind, reward: Int) {
        let burst = GardenAreaRewardBurst(area: area, reward: reward)
        withAnimation(.easeOut(duration: 0.18)) {
            areaRewardBurst = burst
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard areaRewardBurst?.id == burst.id else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                areaRewardBurst = nil
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

private struct GardenAreaRewardBurst: Identifiable {
    let id = UUID()
    let area: GardenMapAreaKind
    let reward: Int
}

private struct GardenQuest: Identifiable {
    let id: String
    let title: String
    let detail: String
    let progress: Int
    let goal: Int
    let reward: Int
    let systemImage: String

    var isComplete: Bool { progress >= goal }

    var progressFraction: CGFloat {
        guard goal > 0 else { return 0 }
        return min(1, CGFloat(progress) / CGFloat(goal))
    }
}

private let gardenPlotPositions: [CGPoint] = [
    CGPoint(x: 0.29, y: 0.43),
    CGPoint(x: 0.72, y: 0.43),
    CGPoint(x: 0.29, y: 0.61),
    CGPoint(x: 0.72, y: 0.61)
]

private let gardenKeeperRoamInterval: TimeInterval = 6.8

private let gardenKeeperRoamingStops: [CGPoint] = [
    CGPoint(x: 0.50, y: 0.76),
    CGPoint(x: 0.34, y: 0.67),
    CGPoint(x: 0.56, y: 0.55),
    CGPoint(x: 0.82, y: 0.50),
    CGPoint(x: 0.64, y: 0.72),
    CGPoint(x: 0.22, y: 0.51),
    CGPoint(x: 0.44, y: 0.37)
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
        case .mira: return "Path keeper"
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

    var idleSpriteAssetNames: [String] {
        switch self {
        case .mira: return ["GardenVisitorMira01", "GardenVisitorMira02"]
        case .sol: return ["GardenVisitorSol01", "GardenVisitorSol02"]
        case .nori: return ["GardenVisitorNori01", "GardenVisitorNori02"]
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
            return "The lanterns are low today. A little care will bring the warm light back."
        case .nori:
            return "I am cataloging tiny wins. Bring me one fresh sign that the grove is awake."
        }
    }
}

private extension GardenDailyEventTaskKind {
    var title: String {
        switch self {
        case .gatherDew: return "Gather dew"
        case .tendPlot: return "Tend a plot"
        }
    }

    var detail: String {
        switch self {
        case .gatherDew:
            return "Collect glowing dew motes hidden around the map."
        case .tendPlot:
            return "Use Tend mode or the board to complete one tiny routine."
        }
    }

    var systemImage: String {
        switch self {
        case .gatherDew: return "drop.fill"
        case .tendPlot: return "checkmark.seal.fill"
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

    var tint: Color {
        switch self {
        case .pathCharm: return Color(hex: 0xC98E45)
        case .sunLantern: return Color(hex: 0xE4AD3D)
        case .seedArchive: return Color(hex: 0x6E8BC8)
        }
    }

    var mapPosition: (x: Double, y: Double) {
        switch self {
        case .pathCharm: return (0.36, 0.25)
        case .sunLantern: return (0.58, 0.34)
        case .seedArchive: return (0.19, 0.68)
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
            return "A small walking loop for one-step quests."
        case .lanternGlade:
            return "A warm clearing for evening visitor chains."
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
            return "Walk the tiny route and collect one dew for showing up."
        case .lanternGlade:
            return "Refresh the clearing light and collect two dew."
        case .archiveCorner:
            return "Place one small win in the archive and collect one dew."
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
        case .route: return "Route complete"
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
        case .pathNook: return (0.31, 0.30)
        case .lanternGlade: return (0.62, 0.25)
        case .archiveCorner: return (0.18, 0.62)
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

private struct GardenAreaRewardBurstView: View {
    let burst: GardenAreaRewardBurst
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
                Text("+\(burst.reward)")
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

// MARK: - Game UI

private enum GardenTool: String, CaseIterable, Identifiable {
    case explore
    case tend
    case build

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explore: return "Explore"
        case .tend: return "Tend"
        case .build: return "Build"
        }
    }

    var systemImage: String {
        switch self {
        case .explore: return "figure.walk"
        case .tend: return "sparkles"
        case .build: return "hammer.fill"
        }
    }

    var tint: Color {
        switch self {
        case .explore: return Color(hex: 0x7D6A54)
        case .tend: return Color(hex: 0x5FA461)
        case .build: return Color(hex: 0xD99A32)
        }
    }
}

private struct GardenGameBackdrop: View {
    private var eveningOpacity: Double {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour < 5 { return 0.18 }
        if hour >= 18 { return 0.08 }
        return 0
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("LuminaGardenBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [
                        Color(hex: 0xFFF4D1).opacity(0.24),
                        Color.clear,
                        Color(hex: 0x315E3C).opacity(0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [Color.black.opacity(0.05), Color.clear, Color.black.opacity(0.07)],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                if eveningOpacity > 0 {
                    Color(hex: 0x273454)
                        .opacity(eveningOpacity)
                    GardenFireflies()
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct GardenFireflies: View {
    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(Color(hex: 0xFFE891).opacity(index.isMultiple(of: 3) ? 0.72 : 0.46))
                    .frame(width: CGFloat(3 + index % 3), height: CGFloat(3 + index % 3))
                    .shadow(color: Color(hex: 0xFFE891).opacity(0.65), radius: 6)
                    .position(
                        x: CGFloat((index * 37 + 18) % 100) / 100 * proxy.size.width,
                        y: CGFloat((index * 23 + 34) % 100) / 100 * proxy.size.height
                    )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GardenGameHUD: View {
    let waterDrops: Int
    let completedCount: Int
    let totalCount: Int
    let averageGrowth: Int

    private var progress: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(completedCount) / CGFloat(totalCount)
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "leaf.fill")
                    .luminaFont(size: 16, weight: .black)
                    .foregroundColor(Color(hex: 0xF4F0D9))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: 0x42683D).opacity(0.92))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text("Lumina Grove")
                        .luminaFont(size: 17, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x24472A))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("\(completedCount)/\(max(totalCount, 1)) tended · \(averageGrowth)% grown")
                        .luminaFont(size: 10, weight: .bold)
                        .foregroundColor(Color(hex: 0x63714D))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.leading, 9)
            .padding(.trailing, 13)
            .padding(.vertical, 7)
            .background(Color(hex: 0xFFF7DE).opacity(0.66))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.58), lineWidth: 1))
            .shadow(color: Color(hex: 0x18371E).opacity(0.14), radius: 9, x: 0, y: 5)
            .layoutPriority(0)

            Spacer(minLength: 6)

            HStack(spacing: 8) {
                GardenHUDChip(value: "\(waterDrops)", icon: "drop.fill", tint: Color(hex: 0x309FD2), label: "Dew")

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .luminaFont(size: 9, weight: .black)
                        Text("\(Int(progress * 100))%")
                            .luminaFont(size: 11, weight: .black, design: .rounded)
                    }
                    .foregroundColor(Color(hex: 0x65583F))

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: 0xD8C797).opacity(0.62))
                            Capsule()
                                .fill(Color(hex: 0x62A75B))
                                .frame(width: max(6, geo.size.width * progress))
                        }
                    }
                    .frame(width: 52, height: 6)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(hex: 0xFFF7DE).opacity(0.66))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.58), lineWidth: 1))
            .shadow(color: Color(hex: 0x18371E).opacity(0.12), radius: 8, x: 0, y: 4)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
        }
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
                .luminaFont(size: 14, weight: .black)
                .foregroundColor(tint)
            Text(value)
                .luminaFont(size: 16, weight: .black, design: .rounded)
                .foregroundColor(Color(hex: 0x4D4032))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .accessibilityLabel("\(label) \(value)")
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(hex: 0xFFF8E8).opacity(0.88))
        .clipShape(Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct GardenBuildHint: View {
    let selectedBuildType: GardenDecorationType
    let canAfford: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: selectedBuildType.systemImage)
                .luminaFont(size: 13, weight: .black)
                .foregroundColor(Color(hex: 0xFFFDF4))
                .frame(width: 28, height: 28)
                .background(selectedBuildType.tint)
                .clipShape(Circle())

            Text(selectedBuildType.title)
                .luminaFont(size: 12, weight: .black, design: .rounded)
                .foregroundColor(Color(hex: 0x3F3428))
                .lineLimit(1)

            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .luminaFont(size: 10, weight: .black)
                    .foregroundColor(Color(hex: 0x309FD2))
                Text("\(selectedBuildType.dewCost)")
                    .luminaFont(size: 12, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0x4D4032))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(hex: 0xFFF8E8).opacity(0.90))
            .clipShape(Capsule())

            Text(canAfford ? "Tap a plot" : "Earn dew first")
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
    @Binding var selectedBuildType: GardenDecorationType

    var body: some View {
        HStack(spacing: 10) {
            ForEach(GardenTool.allCases) { tool in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if tool == .build && selectedTool == .build {
                            selectedBuildType = selectedBuildType.next
                        } else {
                            selectedTool = tool
                        }
                    }
                } label: {
                    HStack(spacing: selectedTool == tool ? 6 : 0) {
                        Image(systemName: tool == .build && selectedTool == .build ? selectedBuildType.systemImage : tool.systemImage)
                            .luminaFont(size: 16, weight: .black)
                        if selectedTool == tool {
                            Text(tool == .build ? selectedBuildType.title : tool.title)
                                .luminaFont(size: 12, weight: .black, design: .rounded)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                    .foregroundColor(selectedTool == tool ? Color(hex: 0xFFFDF4) : tool.tint)
                    .frame(width: selectedTool == tool ? (tool == .build ? 118 : 88) : 40, height: 40)
                    .background(selectedTool == tool ? (tool == .build ? selectedBuildType.tint : tool.tint) : Color(hex: 0xFFF8E8).opacity(0.92))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedTool == tool ? Color.white.opacity(0.48) : Color.white.opacity(0.62), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tool == .build ? "Build \(selectedBuildType.title)" : tool.title)
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
    let claimableQuestCount: Int
    let avatarPosition: CGPoint
    let keeperIsWalking: Bool
    let keeperFacesLeft: Bool
    let focusedHabitID: String?
    let decorations: [GardenDecoration]
    let forageItems: [GardenForageItem]
    let keepsakes: [GardenKeepsake]
    let unlockedAreas: [GardenMapAreaUnlock]
    let completedAreaKindsToday: Set<GardenMapAreaKind>
    let areaVisitCounts: [GardenMapAreaKind: Int]
    let areaMilestoneStages: [GardenMapAreaKind: Set<Int>]
    let dailyEvent: GardenDailyEvent?
    let dailyEventProgress: Int
    let recentlyWateredHabitID: String?
    let onBoardTap: () -> Void
    let onWateringCanTap: () -> Void
    let onForageTap: (GardenForageItem) -> Void
    let onAreaTap: (GardenMapAreaUnlock) -> Void
    let onVisitorTap: (GardenDailyEvent) -> Void
    let onPlotTap: (Habit) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                GardenSceneObjectButton(
                    assetName: "GardenPropBoard",
                    title: "Quest Board",
                    badgeSystemImage: claimableQuestCount > 0 ? "gift.fill" : "list.bullet.clipboard.fill",
                    badgeText: claimableQuestCount > 0 ? "\(claimableQuestCount)" : nil,
                    action: onBoardTap
                )
                .frame(width: 62, height: 58)
                .position(x: proxy.size.width * 0.15, y: proxy.size.height * 0.31)
                .zIndex(0.31)

                GardenSceneObjectButton(
                    assetName: "GardenPropWateringCan",
                    title: "Watering Can",
                    badgeSystemImage: waterDrops > 0 ? "drop.fill" : nil,
                    action: onWateringCanTap
                )
                .frame(width: 48, height: 44)
                .position(x: proxy.size.width * 0.85, y: proxy.size.height * 0.29)
                .zIndex(0.29)

                ForEach(unlockedAreas) { unlock in
                    Button {
                        onAreaTap(unlock)
                    } label: {
                        ZStack {
                            GardenAreaVisualUnlockCluster(
                                area: unlock.area,
                                unlockedStages: areaMilestoneStages[unlock.area] ?? []
                            )

                            GardenMapAreaNode(
                                unlock: unlock,
                                isCompletedToday: completedAreaKindsToday.contains(unlock.area),
                                visitCount: areaVisitCounts[unlock.area] ?? 0,
                                nextMilestone: nextMilestone(for: unlock.area),
                                completedStageCount: areaMilestoneStages[unlock.area]?.count ?? 0
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .position(
                        x: proxy.size.width * CGFloat(unlock.area.mapPosition.x),
                        y: proxy.size.height * CGFloat(unlock.area.mapPosition.y)
                    )
                    .zIndex(Double(unlock.area.mapPosition.y))
                    .accessibilityLabel(unlock.area.title)
                    .accessibilityHint("Open this Garden area")
                }

                ForEach(keepsakes) { keepsake in
                    GardenKeepsakeNode(keepsake: keepsake)
                        .position(
                            x: proxy.size.width * CGFloat(keepsake.kind.mapPosition.x),
                            y: proxy.size.height * CGFloat(keepsake.kind.mapPosition.y)
                        )
                        .zIndex(Double(keepsake.kind.mapPosition.y))
                        .accessibilityLabel(keepsake.kind.title)
                }

                if let dailyEvent {
                    Button {
                        onVisitorTap(dailyEvent)
                    } label: {
                        GardenVisitorNode(
                            event: dailyEvent,
                            progress: dailyEventProgress
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(dailyEvent.visitor.displayName) visitor")
                    .accessibilityHint("Open today's garden request")
                    .position(
                        x: proxy.size.width * CGFloat(dailyEvent.x),
                        y: proxy.size.height * CGFloat(dailyEvent.y)
                    )
                    .zIndex(dailyEvent.y + 0.04)
                }

                ForEach(forageItems) { item in
                    Button {
                        onForageTap(item)
                    } label: {
                        GardenForageNode(item: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Gather dew")
                    .accessibilityHint("Collect dew for building and tending the grove")
                    .position(
                        x: proxy.size.width * CGFloat(item.x),
                        y: proxy.size.height * CGFloat(item.y)
                    )
                    .zIndex(item.y + 0.02)
                }

                ForEach(decorations) { decoration in
                    GardenDecorationNode(type: decoration.type)
                        .frame(width: 42, height: 42)
                        .position(
                            x: proxy.size.width * CGFloat(decoration.x),
                            y: proxy.size.height * CGFloat(decoration.y)
                        )
                        .zIndex(decoration.y + 0.01)
                }

                ForEach(0..<gardenPlotPositions.count, id: \.self) { index in
                    if index < habits.count {
                        let habit = habits[index]
                        Button {
                            onPlotTap(habit)
                        } label: {
                            GardenPlotNode(
                                habit: habit,
                                tool: selectedTool,
                                canWater: waterDrops > 0 && habit.plantType != .tree,
                                isWatering: recentlyWateredHabitID == habit.id,
                                isFocused: focusedHabitID == habit.id
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(habit.title)
                        .accessibilityHint(selectedTool == .explore ? "Open plant journal" : "Use selected garden tool")
                        .position(
                            x: proxy.size.width * gardenPlotPositions[index].x,
                            y: proxy.size.height * gardenPlotPositions[index].y
                        )
                        .zIndex(Double(gardenPlotPositions[index].y))
                    } else {
                        EmptyGardenPlot()
                            .position(
                                x: proxy.size.width * gardenPlotPositions[index].x,
                                y: proxy.size.height * gardenPlotPositions[index].y
                        )
                        .zIndex(Double(gardenPlotPositions[index].y))
                    }
                }

                GardenKeeperAvatar(
                    tool: selectedTool,
                    isWatering: recentlyWateredHabitID != nil,
                    isWalking: keeperIsWalking,
                    facesLeft: keeperFacesLeft
                )
                    .frame(width: 86, height: 92)
                    .position(
                        x: proxy.size.width * avatarPosition.x,
                        y: proxy.size.height * avatarPosition.y
                    )
                    .zIndex(Double(avatarPosition.y) + 0.10)
            }
        }
    }

    private func nextMilestone(for area: GardenMapAreaKind) -> GardenAreaMilestoneDefinition? {
        let unlockedStages = areaMilestoneStages[area] ?? []
        return area.milestoneDefinitions.first { !unlockedStages.contains($0.stage) }
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
    @State private var shimmering = false

    private var allowsIdleMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xFFF4A8).opacity(shimmering && allowsIdleMotion ? 0.20 : 0.36))
                .frame(width: 52, height: 52)
                .blur(radius: 8)

            Circle()
                .stroke(Color(hex: 0xFFFBEA).opacity(0.76), lineWidth: 1.4)
                .frame(width: shimmering && allowsIdleMotion ? 44 : 32, height: shimmering && allowsIdleMotion ? 44 : 32)
                .opacity(shimmering && allowsIdleMotion ? 0.12 : 0.64)

            Image(systemName: "drop.fill")
                .luminaFont(size: 22, weight: .black)
                .foregroundColor(Color(hex: 0x54BFE8))
                .shadow(color: Color(hex: 0xFFF4A8).opacity(0.9), radius: 6, x: 0, y: 0)

            if item.reward > 1 {
                Text("+\(item.reward)")
                    .luminaFont(size: 9, weight: .black, design: .rounded)
                    .foregroundColor(Color(hex: 0x5B4630))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(hex: 0xFFF8E8).opacity(0.92))
                    .clipShape(Capsule())
                    .offset(x: 19, y: -15)
            }
        }
        .frame(width: 58, height: 58)
        .scaleEffect(shimmering && allowsIdleMotion ? 1.05 : 0.96)
        .animation(allowsIdleMotion ? .easeInOut(duration: 1.05).repeatForever(autoreverses: true) : nil, value: shimmering)
        .onAppear {
            guard allowsIdleMotion else { return }
            shimmering = true
        }
    }
}

private struct GardenGroundShadow: View {
    let width: CGFloat
    let height: CGFloat
    var opacity: Double = 0.16
    var blurRadius: CGFloat = 0.5

    var body: some View {
        Ellipse()
            .fill(Color(hex: 0x2A2118).opacity(opacity))
            .frame(width: width, height: height)
            .blur(radius: blurRadius)
            .accessibilityHidden(true)
    }
}

private struct GardenAnimatedSprite: View {
    let assetNames: [String]
    var frameDuration: TimeInterval = 0.56
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allowsFrameAnimation: Bool {
        assetNames.count > 1 && !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        Group {
            if allowsFrameAnimation {
                TimelineView(.periodic(from: .now, by: frameDuration)) { context in
                    sprite(at: frameIndex(for: context.date))
                }
            } else {
                sprite(at: 0)
            }
        }
    }

    private func frameIndex(for date: Date) -> Int {
        guard !assetNames.isEmpty, frameDuration > 0 else { return 0 }
        return Int(date.timeIntervalSinceReferenceDate / frameDuration) % assetNames.count
    }

    @ViewBuilder
    private func sprite(at index: Int) -> some View {
        if assetNames.isEmpty {
            EmptyView()
        } else {
            Image(assetNames[index % assetNames.count])
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        }
    }
}

private struct GardenVisitorNode: View {
    let event: GardenDailyEvent
    let progress: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bobbing = false
    @State private var roamingOffset = CGSize.zero
    @State private var roamingStep = 0

    private var allowsIdleMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var isReady: Bool {
        event.isAccepted && progress >= event.taskGoal
    }

    private var badgeText: String {
        if isReady {
            return "!"
        }
        if event.isAccepted {
            return "\(min(progress, event.taskGoal))/\(event.taskGoal)"
        }
        return "?"
    }

    var body: some View {
        ZStack {
            GardenGroundShadow(width: 48, height: 11, opacity: 0.17, blurRadius: 0.7)
                .offset(y: 35)

            if isReady {
                Circle()
                    .fill(Color(hex: 0xFFE891).opacity(0.20))
                    .frame(width: 78, height: 78)
                    .blur(radius: 10)
                    .offset(y: 2)
            }

            GardenAnimatedSprite(assetNames: event.visitor.idleSpriteAssetNames, frameDuration: 0.72)
                .frame(width: 62, height: 76)
                .shadow(color: Color(hex: 0x17381F).opacity(0.18), radius: 4, x: 0, y: 3)
                .offset(y: 6)

            GardenVisitorStatusBadge(
                text: badgeText,
                systemImage: isReady ? "gift.fill" : nil,
                tint: event.visitor.accent
            )
            .offset(x: 27, y: -28)
        }
        .frame(width: 88, height: 94)
        .offset(roamingOffset)
        .scaleEffect(bobbing && allowsIdleMotion ? 1.015 : 1.0, anchor: .bottom)
        .animation(allowsIdleMotion ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true) : nil, value: bobbing)
        .animation(allowsIdleMotion ? .easeInOut(duration: 2.2) : nil, value: roamingOffset)
        .onReceive(Timer.publish(every: 4.8, on: .main, in: .common).autoconnect()) { _ in
            advanceRoamingOffset()
        }
        .onAppear {
            guard allowsIdleMotion else { return }
            bobbing = true
        }
    }

    private func advanceRoamingOffset() {
        guard allowsIdleMotion else {
            roamingOffset = .zero
            return
        }
        let offsets = event.visitor.roamingOffsets
        guard !offsets.isEmpty else { return }
        roamingStep = (roamingStep + 1) % offsets.count
        roamingOffset = offsets[roamingStep]
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

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.15))
                .frame(width: 42, height: 12)
                .offset(y: 24)

            Circle()
                .fill(keepsake.kind.tint.opacity(0.18))
                .frame(width: 52, height: 52)
                .blur(radius: 8)

            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(hex: 0xFFF8E8).opacity(0.92))
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(keepsake.kind.tint.opacity(0.72), lineWidth: 1.4)
                )
                .shadow(color: Color(hex: 0x17381F).opacity(0.18), radius: 6, x: 0, y: 4)

            Image(systemName: keepsake.kind.icon)
                .luminaFont(size: 19, weight: .black)
                .foregroundColor(keepsake.kind.tint)
        }
        .frame(width: 64, height: 64)
    }
}

private struct GardenMapAreaNode: View {
    let unlock: GardenMapAreaUnlock
    let isCompletedToday: Bool
    let visitCount: Int
    let nextMilestone: GardenAreaMilestoneDefinition?
    let completedStageCount: Int

    private var progressLabel: String {
        if isCompletedToday {
            return "Done"
        }
        guard let nextMilestone else {
            return "Complete"
        }
        return "\(min(visitCount, nextMilestone.requiredVisits))/\(nextMilestone.requiredVisits)"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(unlock.area.tint.opacity(isCompletedToday ? 0.12 : 0.20))
                .frame(width: 108, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color(hex: 0xFFF8E8).opacity(0.56), lineWidth: 1.2)
                )
                .shadow(color: Color(hex: 0x17381F).opacity(0.14), radius: 10, x: 0, y: 6)

            VStack(spacing: 4) {
                Image(systemName: unlock.area.icon)
                    .luminaFont(size: 15, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 28, height: 28)
                    .background(isCompletedToday ? Color(hex: 0x5FA461) : unlock.area.tint.opacity(0.95))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.50), lineWidth: 1))

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

    var body: some View {
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
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xFFD66B).opacity(0.25))
                .blur(radius: 12)
                .frame(width: 72, height: 72)
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

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.13))
                .frame(width: 34, height: 10)
                .offset(y: 16)

            switch type {
            case .lamp:
                Image("GardenPropLamp")
                    .resizable()
                    .scaledToFit()
                    .shadow(color: Color(hex: 0x2F2B1A).opacity(0.22), radius: 6, x: 0, y: 4)
            case .stones:
                GardenStoneCluster()
            case .flowers:
                GardenFlowerCluster()
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GardenStoneCluster: View {
    var body: some View {
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
        }
    }
}

private struct GardenFlowerCluster: View {
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                VStack(spacing: 0) {
                    Circle()
                        .fill(index.isMultiple(of: 2) ? Color(hex: 0xF8E9A6) : Color(hex: 0xF2A4BD))
                        .frame(width: 9, height: 9)
                        .overlay(Circle().fill(Color(hex: 0xE6A53A)).frame(width: 3, height: 3))
                    Capsule()
                        .fill(Color(hex: 0x4E7B49))
                        .frame(width: 2, height: 12)
                }
                .rotationEffect(.degrees(Double(index * 11 - 18)))
                .offset(
                    x: CGFloat([-15, -7, 4, 13, 0][index]),
                    y: CGFloat([3, -5, -2, 2, 7][index])
                )
            }
        }
    }
}

private struct GardenKeeperAvatar: View {
    let tool: GardenTool
    let isWatering: Bool
    let isWalking: Bool
    let facesLeft: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bobbing = false

    private var allowsIdleMotion: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var frameNames: [String] {
        if isWatering {
            return [
                "GardenKeeperWater01",
                "GardenKeeperWater02",
                "GardenKeeperWater03",
                "GardenKeeperWater04"
            ]
        }

        if isWalking {
            return [
                "GardenKeeperWalk01",
                "GardenKeeperWalk02",
                "GardenKeeperWalk03",
                "GardenKeeperWalk04"
            ]
        }

        switch tool {
        case .explore:
            return [
                "GardenKeeperIdle01",
                "GardenKeeperIdle02",
                "GardenKeeperIdle03",
                "GardenKeeperIdle04"
            ]
        case .tend:
            return [
                "GardenKeeperIdle01",
                "GardenKeeperIdle02",
                "GardenKeeperIdle03",
                "GardenKeeperIdle04"
            ]
        case .build:
            return [
                "GardenKeeperInspect01",
                "GardenKeeperInspect02",
                "GardenKeeperInspect03",
                "GardenKeeperInspect04"
            ]
        }
    }

    private var frameDuration: TimeInterval {
        if isWatering {
            return 0.22
        }
        if isWalking {
            return 0.22
        }

        switch tool {
        case .explore: return 0.68
        case .tend: return 0.68
        case .build: return 0.54
        }
    }

    var body: some View {
        ZStack {
            GardenGroundShadow(
                width: isWatering || isWalking ? 56 : 44,
                height: isWatering || isWalking ? 12 : 10,
                opacity: isWatering || isWalking ? 0.18 : 0.15,
                blurRadius: 0.7
            )
            .offset(y: 38)

            GardenAnimatedSprite(assetNames: frameNames, frameDuration: frameDuration)
                .frame(width: isWatering ? 82 : 66, height: 82)
                .scaleEffect(x: facesLeft ? -1 : 1, y: 1)
                .shadow(color: Color(hex: 0x17381F).opacity(0.18), radius: 4, x: 0, y: 3)
                .offset(y: 7)
                .scaleEffect(bobbing && allowsIdleMotion && !isWatering && !isWalking ? 1.014 : 1.0, anchor: .bottom)
                .animation(allowsIdleMotion ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : nil, value: bobbing)
        }
        .onAppear {
            guard allowsIdleMotion else { return }
            bobbing = true
        }
        .accessibilityLabel("Garden keeper")
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

private struct GardenPlotNode: View {
    let habit: Habit
    let tool: GardenTool
    let canWater: Bool
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

            if habit.completedAt != nil {
                Image(systemName: "checkmark.seal.fill")
                    .luminaFont(size: 18, weight: .black)
                    .foregroundColor(Color(hex: 0xFFFDF4))
                    .background(Circle().fill(Color(hex: 0x5FA461)).frame(width: 24, height: 24))
                    .offset(x: 37, y: -34)
            }

            if tool == .tend {
                Image(systemName: canWater || habit.completedAt == nil ? "sparkles" : "book.pages.fill")
                    .luminaFont(size: 15, weight: .black)
                    .foregroundColor(canWater || habit.completedAt == nil ? Color(hex: 0x5FA461) : Color(hex: 0x8B7A65))
                    .padding(6)
                    .background(Color(hex: 0xF2F6D9))
                    .clipShape(Circle())
                    .offset(x: -38, y: -34)
            }

            if tool == .build {
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

    private let offsets: [CGSize] = [
        CGSize(width: -24, height: -8),
        CGSize(width: -10, height: -20),
        CGSize(width: 6, height: -12),
        CGSize(width: 20, height: -24),
        CGSize(width: 30, height: -4)
    ]

    var body: some View {
        ZStack {
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
            rising = true
        }
    }
}

private struct GardenPlantIllustration: View {
    let type: PlantType

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

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: imageSize.width, height: imageSize.height)
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

    private var nextQuest: GardenAreaQuestDefinition? {
        unlock.area.questDefinitions.first { !unlockedStages.contains($0.stage) }
    }

    private var progressFraction: CGFloat {
        guard let nextQuest else { return 1 }
        return min(1, CGFloat(visitCount) / CGFloat(nextQuest.requiredVisits))
    }

    private var progressText: String {
        guard let nextQuest else { return "All chapters complete" }
        return "\(min(visitCount, nextQuest.requiredVisits))/\(nextQuest.requiredVisits) visits"
    }

    private var canClaimAreaAction: Bool {
        isCompletedToday || miniGameSteps.count >= unlock.area.miniGameKind.requiredSteps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(unlock.area.tint.opacity(0.14))
                        .frame(width: 82, height: 92)

                    GardenMapAreaNode(
                        unlock: unlock,
                        isCompletedToday: isCompletedToday,
                        visitCount: visitCount,
                        nextMilestone: nextMilestone,
                        completedStageCount: unlockedMilestones.count
                    )
                    .scaleEffect(0.78)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Garden Area")
                        .luminaFont(size: 12, weight: .black)
                        .foregroundColor(Color(hex: 0x82725B))
                        .textCase(.uppercase)
                    Text(unlock.area.title)
                        .luminaFont(size: 28, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x3F3428))
                    Text(unlock.area.detail)
                        .luminaFont(size: 14, weight: .semibold)
                        .foregroundColor(Color(hex: 0x6F604B))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

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
            }

            HStack(spacing: 11) {
                Image(systemName: isCompletedToday ? "checkmark.seal.fill" : unlock.area.icon)
                    .luminaFont(size: 16, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 38, height: 38)
                    .background(isCompletedToday ? Color(hex: 0x5FA461) : unlock.area.tint)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(isCompletedToday ? "Visited today" : unlock.area.actionTitle)
                        .luminaFont(size: 15, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                    Text(isCompletedToday ? "Come back tomorrow for another small area action." : unlock.area.actionDetail)
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundColor(Color(hex: 0x82725B))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .luminaFont(size: 11, weight: .black)
                        .foregroundColor(Color(hex: 0x309FD2))
                    Text("+\(visit?.reward ?? unlock.area.dailyReward)")
                        .luminaFont(size: 13, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4D4032))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Color(hex: 0xFFF8E8))
                .clipShape(Capsule())
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
                    Text("Area Quest")
                        .luminaFont(size: 12, weight: .black)
                        .foregroundColor(Color(hex: 0x82725B))
                        .textCase(.uppercase)
                    Spacer(minLength: 0)
                    Text("Chapter \(unlockedMilestones.count)/\(unlock.area.questDefinitions.count)")
                        .luminaFont(size: 11, weight: .black, design: .rounded)
                        .foregroundColor(unlock.area.tint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(unlock.area.tint.opacity(0.12))
                        .clipShape(Capsule())
                }

                if let nextQuest {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(nextQuest.title)
                                .luminaFont(size: 18, weight: .black, design: .rounded)
                                .foregroundColor(Color(hex: 0x3F3428))
                            Spacer(minLength: 0)
                            HStack(spacing: 4) {
                                Image(systemName: "drop.fill")
                                    .luminaFont(size: 10, weight: .black)
                                    .foregroundColor(Color(hex: 0x309FD2))
                                Text("+\(nextQuest.reward)")
                                    .luminaFont(size: 12, weight: .black, design: .rounded)
                            }
                            .foregroundColor(Color(hex: 0x4D4032))
                        }

                        Text(nextQuest.story)
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

                            Text(nextQuest.objective)
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
                        Text("All current area chapters are complete.")
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
                } else if canClaimAreaAction {
                    onComplete()
                }
            } label: {
                Label(
                    isCompletedToday ? "Done for today" : (canClaimAreaAction ? "Claim area reward" : unlock.area.miniGameTitle),
                    systemImage: isCompletedToday ? "checkmark.circle.fill" : (canClaimAreaAction ? "gift.fill" : unlock.area.icon)
                )
                    .luminaFont(size: 15, weight: .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundColor(.white)
                    .background(canClaimAreaAction ? (isCompletedToday ? Color(hex: 0x5FA461) : unlock.area.tint) : Color(hex: 0xB6AA96))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canClaimAreaAction)
        }
        .padding(22)
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

            Text("Ready to claim")
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
        ("Plan", "list.bullet.rectangle.fill"),
        ("Win", "checkmark.seal.fill")
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

private struct GardenDailyEventSheet: View {
    let event: GardenDailyEvent
    let progress: Int
    let onAccept: () -> Void
    let onClaim: () -> Void
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var didAccept = false

    private var isAccepted: Bool {
        event.isAccepted || didAccept
    }

    private var clampedProgress: Int {
        min(progress, event.taskGoal)
    }

    private var progressFraction: CGFloat {
        guard event.taskGoal > 0 else { return 0 }
        return min(1, CGFloat(progress) / CGFloat(event.taskGoal))
    }

    private var canClaim: Bool {
        isAccepted && progress >= event.taskGoal
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    taskCard
                    GardenKeepsakeRewardRow(kind: GardenKeepsakeKind.reward(for: event.visitor))
                    GardenAreaUnlockRow(area: GardenMapAreaKind.reward(for: GardenKeepsakeKind.reward(for: event.visitor)))
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
                Text("Garden visitor")
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
                .accessibilityLabel("Close visitor request")
            }

            HStack(alignment: .center, spacing: 13) {
                GardenVisitorPortrait(visitor: event.visitor, isReady: canClaim)

                VStack(alignment: .leading, spacing: 5) {
                    Text(event.visitor.displayName)
                        .luminaFont(size: 25, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x3F3428))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(event.visitor.roleTitle)
                        .luminaFont(size: 11, weight: .black)
                        .foregroundColor(event.visitor.accent)
                        .textCase(.uppercase)
                        .lineLimit(1)
                    Text(event.visitor.message)
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

    private var taskCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: event.taskKind.systemImage)
                    .luminaFont(size: 16, weight: .black)
                    .foregroundColor(Color(hex: 0xFFF8E8))
                    .frame(width: 40, height: 40)
                    .background(event.visitor.accent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.taskKind.title)
                        .luminaFont(size: 17, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(event.taskKind.detail)
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundColor(Color(hex: 0x82725B))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 6)

                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .luminaFont(size: 11, weight: .black)
                        .foregroundColor(Color(hex: 0x309FD2))
                    Text("+\(event.reward)")
                        .luminaFont(size: 13, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4D4032))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Color(hex: 0xFFF8E8))
                .clipShape(Capsule())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0xE4D4B6))
                    Capsule()
                        .fill(canClaim ? Color(hex: 0x5FA461) : event.visitor.accent)
                        .frame(width: max(8, geo.size.width * progressFraction))
                }
            }
            .frame(height: 10)

            Text("\(clampedProgress)/\(event.taskGoal) complete")
                .luminaFont(size: 12, weight: .black)
                .foregroundColor(canClaim ? Color(hex: 0x5FA461) : Color(hex: 0x82725B))
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
                    Label("Accept", systemImage: "checkmark.circle.fill")
                        .luminaFont(size: 15, weight: .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(event.visitor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    onDismiss()
                } label: {
                    Text("Not today")
                        .luminaFont(size: 15, weight: .black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(width: 108, height: 50)
                        .foregroundColor(Color(hex: 0x7E735F))
                        .background(Color(hex: 0xEFE4D0))
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if canClaim {
                Button(action: onClaim) {
                    Label("Claim reward", systemImage: "gift.fill")
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
                    Label("Keep exploring", systemImage: "figure.walk")
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

            GardenAnimatedSprite(assetNames: visitor.idleSpriteAssetNames, frameDuration: 0.74)
                .frame(width: 58, height: 72)
                .shadow(color: Color(hex: 0x17381F).opacity(0.16), radius: 4, x: 0, y: 3)
                .offset(y: 6)

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

private struct GardenKeepsakeRewardRow: View {
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
                Text("Unlocks \(kind.title)")
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

private struct GardenAreaUnlockRow: View {
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
    let waterDrops: Int
    let onComplete: () -> Void
    let onWater: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var isCompleted: Bool {
        habit.completedAt != nil
    }

    private var canWater: Bool {
        waterDrops > 0 && habit.plantType != .tree
    }

    private var clampedGrowth: Int {
        min(max(habit.growth, 0), 100)
    }

    private var growthProgress: CGFloat {
        CGFloat(clampedGrowth) / 100
    }

    private var plantTint: Color {
        switch habit.plantType {
        case .seed: return Color(hex: 0xE2A15F)
        case .sprout: return Color(hex: 0x5FA461)
        case .flower: return Color(hex: 0xD66D90)
        case .tree: return Color(hex: 0x4C9F70)
        }
    }

    private var stageTitle: String {
        switch habit.plantType {
        case .seed: return "Seed of intention"
        case .sprout: return "First steady growth"
        case .flower: return "A visible bloom"
        case .tree: return "Rooted memory"
        }
    }

    private var memoryText: String {
        if isCompleted {
            return "This plant remembers that you showed up for this habit today."
        }
        switch habit.plantType {
        case .seed:
            return "A small intention is already in the soil. It only needs one gentle action."
        case .sprout:
            return "This habit has started to answer your care. Keep the routine light and repeatable."
        case .flower:
            return "A few steady days are becoming visible here. The garden keeps that evidence for you."
        case .tree:
            return "This routine has become part of the grove. It can now anchor harder days."
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

                GardenHabitMemoryCard(message: memoryText, tint: plantTint)

                GardenHabitProgressMeter(
                    value: growthProgress,
                    percentage: clampedGrowth,
                    tint: plantTint
                )

                HStack(spacing: 10) {
                    GardenHabitActionButton(
                        title: isCompleted ? "Tended" : "Mark tended",
                        systemImage: isCompleted ? "checkmark.circle.fill" : "circle",
                        foreground: isCompleted ? Color.white : Color(hex: 0x5B4B3B),
                        background: isCompleted ? Color(hex: 0x5FA461) : Color(hex: 0xF1E2C5),
                        border: isCompleted ? Color(hex: 0x5FA461) : Color(hex: 0xE0CDA7),
                        isDisabled: isCompleted,
                        action: onComplete
                    )
                    .accessibilityHint(isCompleted ? "This habit has already been tended today." : "Marks this habit complete for today.")

                    GardenHabitActionButton(
                        title: waterTitle,
                        systemImage: "drop.fill",
                        foreground: canWater ? Color.white : Color(hex: 0x8E7B61),
                        background: canWater ? Color(hex: 0x3FA8D5) : Color(hex: 0xEFE2CB),
                        border: canWater ? Color(hex: 0x3FA8D5) : Color(hex: 0xE0CDA7),
                        isDisabled: !canWater,
                        action: onWater
                    )
                    .accessibilityHint(canWater ? "Uses one dew to grow this plant." : "Watering is unavailable for this plant right now.")
                }
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
                Text("Plant Journal")
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
                .accessibilityLabel("Close plant journal")
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

                GardenHabitPlantCard(type: habit.plantType, tint: plantTint)
            }
        }
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
                Text("Growth")
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
            .accessibilityLabel("Growth \(percentage) percent")
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
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.78 : 1)
    }
}

private struct GardenTaskBoardSheet: View {
    let habits: [Habit]
    let waterDrops: Int
    let quests: [GardenQuest]
    let claimedQuestIDs: Set<String>
    let areaLogs: [GardenAreaLogEntry]
    let followUp: FollowUp?
    let onSelect: (Habit) -> Void
    let onSelectArea: (GardenMapAreaKind) -> Void
    let onComplete: (Habit) -> Void
    let onClaimQuest: (GardenQuest) -> Void
    let onCompleteFollowUp: (FollowUp) -> Void
    let onSnoozeFollowUp: (FollowUp) -> Void
    let onMarkFollowUpTooHard: (FollowUp) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quest Board")
                        .luminaFont(size: 28, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                    Text("Tend routines, collect dew, then build the grove into your own place.")
                        .luminaFont(size: 13, weight: .semibold)
                        .foregroundColor(Color(hex: 0x82735B))
                }
                .padding(.top, 6)

                if let followUp {
                    FollowUpCheckInCard(
                        followUp: followUp,
                        onDone: { onCompleteFollowUp(followUp) },
                        onLater: { onSnoozeFollowUp(followUp) },
                        onTooHard: { onMarkFollowUpTooHard(followUp) }
                    )
                    .padding(.vertical, 2)
                }

                VStack(spacing: 9) {
                    ForEach(quests) { quest in
                        GardenQuestRow(
                            quest: quest,
                            isClaimed: claimedQuestIDs.contains(quest.id),
                            onClaim: { onClaimQuest(quest) }
                        )
                    }
                }
                .padding(.vertical, 4)

                GardenAreaLogBookSection(
                    entries: areaLogs,
                    onSelectArea: onSelectArea
                )
                .padding(.vertical, 2)

                ForEach(habits) { habit in
                    HStack(spacing: 12) {
                        Button {
                            onSelect(habit)
                        } label: {
                            HStack(spacing: 12) {
                                GardenPlantIllustration(type: habit.plantType)
                                    .frame(width: 58, height: 58)
                                    .background(Color(hex: 0xF3E1B8))
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(habit.title)
                                        .luminaFont(size: 16, weight: .black, design: .rounded)
                                        .foregroundColor(Color(hex: 0x4E4034))
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.82)
                                    Text(habit.completedAt == nil ? "\(habit.growth)% grown · +3 dew when tended" : "Tended today")
                                        .luminaFont(size: 12, weight: .bold)
                                        .foregroundColor(Color(hex: 0x887965))
                                        .lineLimit(1)
                                }
                                .layoutPriority(1)

                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            onComplete(habit)
                        } label: {
                            Image(systemName: habit.completedAt == nil ? "circle" : "checkmark.circle.fill")
                                .luminaFont(size: 22, weight: .black)
                                .foregroundColor(habit.completedAt == nil ? Color(hex: 0xA38E70) : Color(hex: 0x5FA461))
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color(hex: 0xFFF4D6))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color(hex: 0xD9B978), lineWidth: 1.2))
                }

                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                    Text("\(waterDrops) dew available")
                }
                .luminaFont(size: 13, weight: .black)
                .foregroundColor(Color(hex: 0x3FA8D5))
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Color(hex: 0xF5E0B5).ignoresSafeArea())
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
        if entry.completedChapterCount >= entry.totalChapterCount { return "Complete" }
        return "Chapter \(entry.completedChapterCount)/\(entry.totalChapterCount)"
    }

    private var detailText: String {
        if !entry.isUnlocked {
            return "Find its keepsake to open this corner of the grove."
        }
        if let nextQuest = entry.nextQuest {
            return nextQuest.objective
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

private struct GardenQuestRow: View {
    let quest: GardenQuest
    let isClaimed: Bool
    let onClaim: () -> Void

    private var statusText: String {
        if isClaimed { return "Claimed" }
        if quest.isComplete { return "Ready" }
        return "\(quest.progress)/\(quest.goal)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: quest.systemImage)
                .luminaFont(size: 16, weight: .black)
                .foregroundColor(quest.isComplete ? Color(hex: 0xFFFDF4) : Color(hex: 0x7E735F))
                .frame(width: 38, height: 38)
                .background(quest.isComplete ? Color(hex: 0x5FA461) : Color(hex: 0xEFE1C4))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(quest.title)
                        .luminaFont(size: 15, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x4E4034))
                        .lineLimit(1)
                    Text("+\(quest.reward)")
                        .luminaFont(size: 11, weight: .black, design: .rounded)
                        .foregroundColor(Color(hex: 0x309FD2))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(hex: 0xE9F6FA))
                        .clipShape(Capsule())
                }

                Text(quest.detail)
                    .luminaFont(size: 11, weight: .bold)
                    .foregroundColor(Color(hex: 0x887965))
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: 0xDEC797).opacity(0.54))
                        Capsule()
                            .fill(quest.isComplete ? Color(hex: 0x5FA461) : Color(hex: 0xD99A32))
                            .frame(width: max(8, geo.size.width * quest.progressFraction))
                    }
                }
                .frame(height: 7)
            }

            Spacer(minLength: 4)

            Button(action: onClaim) {
                Text(statusText)
                    .luminaFont(size: 12, weight: .black, design: .rounded)
                    .foregroundColor(quest.isComplete && !isClaimed ? Color.white : Color(hex: 0x7B6C55))
                    .frame(width: 72, height: 36)
                    .background(quest.isComplete && !isClaimed ? Color(hex: 0xD99A32) : Color(hex: 0xEFE1C4))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!quest.isComplete || isClaimed)
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
