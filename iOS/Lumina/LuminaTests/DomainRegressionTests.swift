import XCTest
@testable import Lumina

@MainActor
final class DomainRegressionTests: XCTestCase {
    func testSafetyEngineRoutesHighRiskWithoutAI() {
        let result = ConversationEngine().prepareTurn(
            userText: "I want to kill myself tonight",
            currentState: .listen
        )

        XCTAssertEqual(result.safetyAssessment.riskLevel, .high)
        XCTAssertEqual(result.nextState, .crisis)
        XCTAssertFalse(result.shouldUseAI)
        XCTAssertNotNil(result.immediateReply)
    }

    func testJITAIDoesNotCreatePromptDuringQuietHours() {
        let store = JITAIStore()
        store.setQuietHoursStart(22)
        store.setQuietHoursEnd(8)

        store.refresh(
            entries: [],
            habits: [],
            summaries: [],
            baseline: nil,
            now: fixedDate(hour: 23)
        )

        XCTAssertNil(store.activeDecision)
        XCTAssertTrue(store.logs.isEmpty)
    }

    func testJITAIDailyCapRemovesActiveDecisionAfterShownLimit() {
        let store = JITAIStore()
        store.setMaxDailyPrompts(1)
        let now = fixedDate(hour: 12)

        store.refresh(entries: [], habits: [], summaries: [], baseline: nil, now: now)
        XCTAssertNotNil(store.activeDecision)
        XCTAssertEqual(store.logs.filter { $0.response == .shown }.count, 1)

        store.refresh(entries: [], habits: [], summaries: [], baseline: nil, now: now)
        XCTAssertNil(store.activeDecision)
    }

    func testJITAIPrefersExplicitStressCheckInOverPassiveReflectionPrompt() {
        let store = JITAIStore()
        let now = fixedDate(hour: 12)
        let checkIn = CheckInMetric(
            id: "stress-check",
            moodScore: 5,
            stressScore: 9,
            createdAt: now.timeIntervalSince1970
        )

        store.refresh(
            entries: [],
            habits: [],
            summaries: [],
            baseline: nil,
            todayCheckIn: checkIn,
            now: now
        )

        XCTAssertEqual(store.activeDecision?.kind.rawValue, JITAIPromptKind.grounding.rawValue)
        XCTAssertTrue(store.activeDecision?.reasonCodes.contains("checkin.stress.high") == true)
    }

    func testWellbeingContextBriefUsesDerivedSignalsWithoutRawHealthValues() throws {
        let now = fixedDate(hour: 12)
        let checkIn = CheckInMetric(
            id: "context-check",
            moodScore: 4,
            stressScore: 8,
            createdAt: now.timeIntervalSince1970
        )
        let summary = DailyHealthSummary(
            id: "health-day",
            date: now,
            stepCount: 300,
            sleepMinutes: 300,
            restingHeartRate: 82
        )
        let baseline = HealthBaseline(
            windowDays: 14,
            averageSleepMinutes: 480,
            averageSteps: 8_000,
            averageActiveEnergyKcal: nil,
            averageExerciseMinutes: nil,
            averageRestingHeartRate: 68
        )

        let context = WellbeingContextEngine.make(
            entries: [],
            checkIns: [checkIn],
            habits: [],
            followUps: [],
            summaries: [summary],
            baseline: baseline,
            now: now
        )

        XCTAssertEqual(context.primarySignal?.source.rawValue, WellbeingSignalSource.checkIn.rawValue)
        XCTAssertTrue(context.therapyReasonCodes.contains("context.brief.used"))
        let brief = try XCTUnwrap(context.therapyPromptBrief)
        XCTAssertTrue(brief.contains("Local wellbeing context brief"))
        XCTAssertTrue(brief.contains("must not be treated as diagnosis"))
        XCTAssertFalse(brief.contains("8_000"))
        XCTAssertFalse(brief.contains("480"))
        XCTAssertFalse(brief.contains("300"))
        XCTAssertFalse(brief.contains("82"))
    }

    func testPersistedNotificationStateDecodesBeforeJITAISchedulerFields() throws {
        let data = """
        {
          "permissionState": "authorized",
          "lastScheduledAt": 123.0,
          "lastError": null
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PersistedNotificationState.self, from: data)

        XCTAssertEqual(decoded.permissionState, .authorized)
        XCTAssertEqual(decoded.lastScheduledAt, 123.0)
        XCTAssertFalse(decoded.jitaiNotificationsEnabled)
        XCTAssertNil(decoded.jitaiLastScheduledAt)
        XCTAssertTrue(decoded.jitaiScheduledDecisionIDs.isEmpty)
    }

    func testGardenDailyForageSpawnsStableItemsAndClaimAddsDew() throws {
        let store = GardenStore()
        store.waterDrops = 0
        let now = fixedDate(hour: 10)

        store.refreshDailyForage(now: now)
        let firstIDs = store.forageItems.map(\.id)

        XCTAssertEqual(store.forageItems.count, 3)
        XCTAssertEqual(store.activeForageItems.count, 3)

        store.refreshDailyForage(now: now)
        XCTAssertEqual(store.forageItems.map(\.id), firstIDs)

        let firstItem = try XCTUnwrap(store.forageItems.first)
        let claimedItem = try XCTUnwrap(store.claimForageItem(id: firstItem.id, now: now))

        XCTAssertEqual(store.waterDrops, claimedItem.reward)
        XCTAssertEqual(store.activeForageItems.count, 2)
        XCTAssertTrue(store.forageItems.first { $0.id == firstItem.id }?.isClaimed == true)

        let tomorrow = fixedDate(day: 11, hour: 10)
        store.refreshDailyForage(now: tomorrow)
        XCTAssertEqual(store.forageItems.count, 3)
        XCTAssertNotEqual(store.forageItems.map(\.id), firstIDs)
        XCTAssertTrue(store.forageItems.allSatisfy { $0.dayKey == GardenForageItem.dayKey(for: tomorrow) })
    }

    func testPersistedGardenStateDecodesBeforeForageItems() throws {
        let data = """
        {
          "habits": [],
          "waterDrops": 5,
          "gardenDecorations": [],
          "claimedGardenQuestIDs": [],
          "therapyMicroPlans": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PersistedGardenState.self, from: data)

        XCTAssertEqual(decoded.waterDrops, 5)
        XCTAssertTrue(decoded.forageItems.isEmpty)
        XCTAssertTrue(decoded.dailyEvents.isEmpty)
        XCTAssertTrue(decoded.keepsakes.isEmpty)
        XCTAssertTrue(decoded.unlockedAreas.isEmpty)
        XCTAssertTrue(decoded.areaVisits.isEmpty)
        XCTAssertTrue(decoded.areaMilestones.isEmpty)
    }

    func testGardenDailyEventSpawnsStableAndCompletesWithReward() throws {
        let store = GardenStore()
        store.waterDrops = 0
        let now = fixedDate(hour: 9)

        store.refreshDailyEvent(now: now)
        let event = try XCTUnwrap(store.activeDailyEvent(on: now))
        let eventID = event.id

        store.refreshDailyEvent(now: now)
        XCTAssertEqual(store.activeDailyEvent(on: now)?.id, eventID)

        let acceptedEvent = try XCTUnwrap(store.acceptDailyEvent(id: eventID, now: now))
        XCTAssertTrue(acceptedEvent.isAccepted)
        XCTAssertNil(store.completeDailyEvent(id: eventID, progress: event.taskGoal - 1, now: now))

        let completedEvent = try XCTUnwrap(store.completeDailyEvent(id: eventID, progress: event.taskGoal, now: now))
        XCTAssertTrue(completedEvent.isCompleted)
        XCTAssertEqual(store.waterDrops, completedEvent.reward)
        XCTAssertNil(store.activeDailyEvent(on: now))
        XCTAssertEqual(store.keepsakes.count, 1)
        XCTAssertEqual(store.keepsakes.first?.kind, GardenKeepsakeKind.reward(for: completedEvent.visitor))
        XCTAssertEqual(store.unlockedAreas.count, 1)
        XCTAssertEqual(
            store.unlockedAreas.first?.area,
            GardenMapAreaKind.reward(for: GardenKeepsakeKind.reward(for: completedEvent.visitor))
        )
    }

    func testGardenKeepsakeUnlocksOnlyOncePerVisitorRewardKind() throws {
        let store = GardenStore()
        let now = fixedDate(hour: 9)
        let firstEvent = GardenDailyEvent(
            id: "visitor-a",
            dayKey: "2026-05-10",
            visitor: .mira,
            taskKind: .tendPlot,
            taskGoal: 1,
            reward: 2,
            x: 0.4,
            y: 0.4,
            spawnedAt: now.timeIntervalSince1970,
            acceptedAt: now.timeIntervalSince1970
        )
        let secondEvent = GardenDailyEvent(
            id: "visitor-b",
            dayKey: "2026-05-11",
            visitor: .mira,
            taskKind: .gatherDew,
            taskGoal: 1,
            reward: 3,
            x: 0.4,
            y: 0.4,
            spawnedAt: now.timeIntervalSince1970,
            acceptedAt: now.timeIntervalSince1970
        )

        store.dailyEvents = [firstEvent, secondEvent]

        XCTAssertNotNil(store.completeDailyEvent(id: firstEvent.id, progress: 1, now: now))
        XCTAssertNotNil(store.completeDailyEvent(id: secondEvent.id, progress: 1, now: now))
        XCTAssertEqual(store.keepsakes.count, 1)
        XCTAssertEqual(store.keepsakes.first?.kind, .pathCharm)
        XCTAssertEqual(store.unlockedAreas.count, 1)
        XCTAssertEqual(store.unlockedAreas.first?.area, .pathNook)
    }

    func testGardenMapAreaUnlocksOnlyOncePerKeepsakeReward() throws {
        let store = GardenStore()
        let now = fixedDate(hour: 9)

        let first = try XCTUnwrap(
            store.unlockKeepsake(
                kind: .sunLantern,
                visitor: .sol,
                sourceEventID: "event-a",
                now: now
            )
        )
        let second = try XCTUnwrap(
            store.unlockKeepsake(
                kind: .sunLantern,
                visitor: .sol,
                sourceEventID: "event-b",
                now: now
            )
        )

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(store.keepsakes.count, 1)
        XCTAssertEqual(store.unlockedAreas.count, 1)
        XCTAssertEqual(store.unlockedAreas.first?.area, .lanternGlade)
    }

    func testGardenMapAreaVisitRewardsOnlyOncePerDay() throws {
        let store = GardenStore()
        store.waterDrops = 0
        let now = fixedDate(hour: 9)

        XCTAssertNil(store.completeMapAreaVisit(area: .pathNook, now: now))

        _ = store.unlockMapArea(
            area: .pathNook,
            sourceKeepsakeID: "keepsake-pathCharm",
            now: now
        )

        let result = try XCTUnwrap(store.completeMapAreaVisit(area: .pathNook, now: now))
        XCTAssertEqual(result.visit.reward, GardenMapAreaKind.pathNook.dailyReward)
        XCTAssertEqual(store.waterDrops, GardenMapAreaKind.pathNook.dailyReward)
        XCTAssertNil(store.completeMapAreaVisit(area: .pathNook, now: now))

        let tomorrow = fixedDate(day: 11, hour: 9)
        let nextResult = try XCTUnwrap(store.completeMapAreaVisit(area: .pathNook, now: tomorrow))
        XCTAssertNotEqual(nextResult.visit.dayKey, result.visit.dayKey)
        XCTAssertEqual(store.areaVisits.count, 2)
    }

    func testGardenAreaMilestonesUnlockAtVisitThresholdsOnce() throws {
        let store = GardenStore()
        store.waterDrops = 0
        let firstDay = fixedDate(hour: 9)

        _ = store.unlockMapArea(
            area: .pathNook,
            sourceKeepsakeID: "keepsake-pathCharm",
            now: firstDay
        )

        let firstResult = try XCTUnwrap(store.completeMapAreaVisit(area: .pathNook, now: firstDay))
        XCTAssertTrue(firstResult.unlockedMilestones.isEmpty)
        XCTAssertEqual(store.waterDrops, GardenMapAreaKind.pathNook.dailyReward)

        let secondDay = fixedDate(day: 11, hour: 9)
        let secondResult = try XCTUnwrap(store.completeMapAreaVisit(area: .pathNook, now: secondDay))
        let firstMilestone = try XCTUnwrap(secondResult.unlockedMilestones.first)

        XCTAssertEqual(firstMilestone.stage, 1)
        XCTAssertEqual(firstMilestone.requiredVisits, 2)
        XCTAssertEqual(firstMilestone.reward, 2)
        XCTAssertEqual(store.areaMilestones.count, 1)
        XCTAssertEqual(secondResult.totalReward, GardenMapAreaKind.pathNook.dailyReward + firstMilestone.reward)
        XCTAssertEqual(store.waterDrops, GardenMapAreaKind.pathNook.dailyReward * 2 + firstMilestone.reward)

        XCTAssertNil(store.completeMapAreaVisit(area: .pathNook, now: secondDay))
        XCTAssertEqual(store.areaMilestones.count, 1)

        let thirdDay = fixedDate(day: 12, hour: 9)
        let thirdResult = try XCTUnwrap(store.completeMapAreaVisit(area: .pathNook, now: thirdDay))
        XCTAssertTrue(thirdResult.unlockedMilestones.isEmpty)
        XCTAssertEqual(store.areaMilestones.count, 1)
    }

    func testGardenAreaMilestoneDefinitionsAreOrderedAndStable() {
        for area in GardenMapAreaKind.allCases {
            let definitions = area.milestoneDefinitions
            XCTAssertEqual(definitions.count, 3)
            XCTAssertEqual(definitions.map(\.stage), [1, 2, 3])
            XCTAssertEqual(Set(definitions.map(\.id)).count, definitions.count)
            XCTAssertEqual(definitions.map(\.requiredVisits), definitions.map(\.requiredVisits).sorted())
            XCTAssertTrue(definitions.allSatisfy { $0.reward > 0 })
        }
    }

    func testGardenAreasHaveDistinctMiniGameActions() {
        let miniGames = GardenMapAreaKind.allCases.map(\.miniGameKind)

        XCTAssertEqual(Set(miniGames).count, GardenMapAreaKind.allCases.count)
        XCTAssertTrue(miniGames.allSatisfy { $0.requiredSteps == 3 })
        XCTAssertEqual(GardenMapAreaKind.pathNook.miniGameKind, .route)
        XCTAssertEqual(GardenMapAreaKind.lanternGlade.miniGameKind, .lanterns)
        XCTAssertEqual(GardenMapAreaKind.archiveCorner.miniGameKind, .archive)
    }

    func testGardenAreaQuestDefinitionsTrackMilestoneChains() {
        for area in GardenMapAreaKind.allCases {
            let quests = area.questDefinitions
            let milestones = area.milestoneDefinitions

            XCTAssertEqual(quests.count, milestones.count)
            XCTAssertEqual(quests.map(\.stage), milestones.map(\.stage))
            XCTAssertEqual(quests.map(\.requiredVisits), milestones.map(\.requiredVisits))
            XCTAssertEqual(quests.map(\.reward), milestones.map(\.reward))
            XCTAssertEqual(Set(quests.map(\.id)).count, quests.count)
            XCTAssertTrue(quests.allSatisfy { !$0.title.isEmpty && !$0.objective.isEmpty && !$0.story.isEmpty })
            XCTAssertEqual(area.questDefinition(stage: 2)?.stage, 2)
        }
    }

    func testGardenAreaMapEvolutionDefinitionsTrackQuestChapters() {
        for area in GardenMapAreaKind.allCases {
            let evolutionMarks = area.mapEvolutionDefinitions
            let quests = area.questDefinitions

            XCTAssertEqual(evolutionMarks.count, quests.count)
            XCTAssertEqual(evolutionMarks.map(\.stage), quests.map(\.stage))
            XCTAssertEqual(Set(evolutionMarks.map(\.id)).count, evolutionMarks.count)
            XCTAssertTrue(evolutionMarks.allSatisfy { $0.scale >= 0.85 && $0.scale <= 1.15 })
            XCTAssertTrue(evolutionMarks.allSatisfy { abs($0.localXOffset) <= 64 })
            XCTAssertTrue(evolutionMarks.allSatisfy { abs($0.localYOffset) <= 56 })
            XCTAssertEqual(area.mapEvolutionDefinition(stage: 3)?.stage, 3)
        }
    }

    func testGardenAreaLogEntriesSummarizeUnlocksVisitsAndChapters() throws {
        let now = fixedDate(day: 13, hour: 10)
        let pathUnlock = GardenMapAreaUnlock(
            area: .pathNook,
            unlockedAt: now.timeIntervalSince1970,
            sourceKeepsakeID: "path-keepsake"
        )
        let visits = [
            GardenMapAreaVisit(
                area: .pathNook,
                dayKey: "2026-05-12",
                reward: GardenMapAreaKind.pathNook.dailyReward,
                completedAt: now.timeIntervalSince1970
            ),
            GardenMapAreaVisit(
                area: .pathNook,
                dayKey: "2026-05-13",
                reward: GardenMapAreaKind.pathNook.dailyReward,
                completedAt: now.timeIntervalSince1970
            )
        ]
        let milestones = [
            GardenAreaMilestoneUnlock(
                area: .pathNook,
                stage: 1,
                requiredVisits: 2,
                reward: 2,
                unlockedAt: now.timeIntervalSince1970
            )
        ]

        let entries = GardenAreaLogEntry.entries(
            unlockedAreas: [pathUnlock],
            visits: visits,
            milestones: milestones
        )
        let pathEntry = try XCTUnwrap(entries.first { $0.area == .pathNook })
        let lockedEntry = try XCTUnwrap(entries.first { $0.area == .lanternGlade })

        XCTAssertEqual(entries.count, GardenMapAreaKind.allCases.count)
        XCTAssertTrue(pathEntry.isUnlocked)
        XCTAssertEqual(pathEntry.visitCount, 2)
        XCTAssertEqual(pathEntry.completedChapterCount, 1)
        XCTAssertEqual(pathEntry.totalChapterCount, GardenMapAreaKind.pathNook.questDefinitions.count)
        XCTAssertEqual(pathEntry.completedQuests.first?.stage, 1)
        XCTAssertEqual(pathEntry.nextQuest?.stage, 2)
        XCTAssertGreaterThan(pathEntry.progressFraction, 0)

        XCTAssertFalse(lockedEntry.isUnlocked)
        XCTAssertEqual(lockedEntry.visitCount, 0)
        XCTAssertTrue(lockedEntry.completedQuests.isEmpty)
        XCTAssertNil(lockedEntry.nextQuest)
    }

    func testGardenAreaChapterMemoriesIncludeStoryAndMapChange() throws {
        let now = fixedDate(day: 14, hour: 10)
        let archiveUnlock = GardenMapAreaUnlock(
            area: .archiveCorner,
            unlockedAt: now.timeIntervalSince1970,
            sourceKeepsakeID: "archive-keepsake"
        )
        let milestones = [
            GardenAreaMilestoneUnlock(
                area: .archiveCorner,
                stage: 1,
                requiredVisits: 2,
                reward: 2,
                unlockedAt: now.timeIntervalSince1970
            ),
            GardenAreaMilestoneUnlock(
                area: .archiveCorner,
                stage: 2,
                requiredVisits: 4,
                reward: 4,
                unlockedAt: now.timeIntervalSince1970
            )
        ]

        let entries = GardenAreaLogEntry.entries(
            unlockedAreas: [archiveUnlock],
            visits: [],
            milestones: milestones
        )
        let archiveEntry = try XCTUnwrap(entries.first { $0.area == .archiveCorner })
        let memories = archiveEntry.completedMemories

        XCTAssertEqual(memories.map(\.stage), [1, 2])
        XCTAssertTrue(memories.allSatisfy { !$0.story.isEmpty })
        XCTAssertTrue(memories.allSatisfy { !$0.mapChangeTitle.isEmpty })
        XCTAssertTrue(memories.allSatisfy { !$0.mapChangeDetail.isEmpty })
        XCTAssertEqual(memories.first?.evolution.stage, 1)
        XCTAssertEqual(memories.last?.evolution.area, .archiveCorner)
        XCTAssertEqual(archiveEntry.nextQuest?.stage, 3)
    }

    private func fixedDate(day: Int = 10, hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar.current
        components.year = 2099
        components.month = 5
        components.day = day
        components.hour = hour
        components.minute = 0
        components.second = 0
        return components.date!
    }
}
