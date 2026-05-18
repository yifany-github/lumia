import Foundation
import Combine
import CryptoKit
import HealthKit
import UserNotifications
import FirebaseAuth
import FirebaseCore

enum ChatSessionPublishMode: Equatable {
    case immediate
    case deferred
    case silent
}

struct PersistedGardenState: Codable {
    var habits: [Habit] = []
    var waterDrops: Int = 0
    var gardenDecorations: [GardenDecoration] = []
    var claimedGardenQuestIDs: Set<String> = []
    var therapyMicroPlans: [MicroPlan] = []
    var forageItems: [GardenForageItem] = []
    var dailyEvents: [GardenDailyEvent] = []
    var keepsakes: [GardenKeepsake] = []
    var unlockedAreas: [GardenMapAreaUnlock] = []
    var areaVisits: [GardenMapAreaVisit] = []
    var areaMilestones: [GardenAreaMilestoneUnlock] = []

    enum CodingKeys: String, CodingKey {
        case habits
        case waterDrops
        case gardenDecorations
        case claimedGardenQuestIDs
        case therapyMicroPlans
        case forageItems
        case dailyEvents
        case keepsakes
        case unlockedAreas
        case areaVisits
        case areaMilestones
    }

    init(
        habits: [Habit] = [],
        waterDrops: Int = 0,
        gardenDecorations: [GardenDecoration] = [],
        claimedGardenQuestIDs: Set<String> = [],
        therapyMicroPlans: [MicroPlan] = [],
        forageItems: [GardenForageItem] = [],
        dailyEvents: [GardenDailyEvent] = [],
        keepsakes: [GardenKeepsake] = [],
        unlockedAreas: [GardenMapAreaUnlock] = [],
        areaVisits: [GardenMapAreaVisit] = [],
        areaMilestones: [GardenAreaMilestoneUnlock] = []
    ) {
        self.habits = habits
        self.waterDrops = waterDrops
        self.gardenDecorations = gardenDecorations
        self.claimedGardenQuestIDs = claimedGardenQuestIDs
        self.therapyMicroPlans = therapyMicroPlans
        self.forageItems = forageItems
        self.dailyEvents = dailyEvents
        self.keepsakes = keepsakes
        self.unlockedAreas = unlockedAreas
        self.areaVisits = areaVisits
        self.areaMilestones = areaMilestones
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        habits = try container.decodeIfPresent([Habit].self, forKey: .habits) ?? []
        waterDrops = try container.decodeIfPresent(Int.self, forKey: .waterDrops) ?? 0
        gardenDecorations = try container.decodeIfPresent([GardenDecoration].self, forKey: .gardenDecorations) ?? []
        claimedGardenQuestIDs = try container.decodeIfPresent(Set<String>.self, forKey: .claimedGardenQuestIDs) ?? []
        therapyMicroPlans = try container.decodeIfPresent([MicroPlan].self, forKey: .therapyMicroPlans) ?? []
        forageItems = try container.decodeIfPresent([GardenForageItem].self, forKey: .forageItems) ?? []
        dailyEvents = try container.decodeIfPresent([GardenDailyEvent].self, forKey: .dailyEvents) ?? []
        keepsakes = try container.decodeIfPresent([GardenKeepsake].self, forKey: .keepsakes) ?? []
        unlockedAreas = try container.decodeIfPresent([GardenMapAreaUnlock].self, forKey: .unlockedAreas) ?? []
        areaVisits = try container.decodeIfPresent([GardenMapAreaVisit].self, forKey: .areaVisits) ?? []
        areaMilestones = try container.decodeIfPresent([GardenAreaMilestoneUnlock].self, forKey: .areaMilestones) ?? []
    }
}

struct PersistedHealthDataState: Codable {
    var permissionState: HealthPermissionState = .notDetermined
    var summaries: [DailyHealthSummary] = []
    var baseline: HealthBaseline?
    var lastSyncAt: TimeInterval?
    var lastError: String?
    var hasAcknowledgedDataUse: Bool = false
}

struct PersistedJITAIState: Codable {
    var decisions: [JITAIDecision] = []
    var logs: [JITAIInteractionLog] = []
    var suppressedUntil: TimeInterval?
    var maxDailyPrompts: Int = 2
    var quietHoursStart: Int = 22
    var quietHoursEnd: Int = 8
}

struct PersistedNotificationState: Codable {
    var permissionState: NotificationPermissionState = .notDetermined
    var lastScheduledAt: TimeInterval?
    var lastError: String?
    var jitaiNotificationsEnabled: Bool = false
    var jitaiLastScheduledAt: TimeInterval?
    var jitaiScheduledDecisionIDs: Set<String> = []

    init(
        permissionState: NotificationPermissionState = .notDetermined,
        lastScheduledAt: TimeInterval? = nil,
        lastError: String? = nil,
        jitaiNotificationsEnabled: Bool = false,
        jitaiLastScheduledAt: TimeInterval? = nil,
        jitaiScheduledDecisionIDs: Set<String> = []
    ) {
        self.permissionState = permissionState
        self.lastScheduledAt = lastScheduledAt
        self.lastError = lastError
        self.jitaiNotificationsEnabled = jitaiNotificationsEnabled
        self.jitaiLastScheduledAt = jitaiLastScheduledAt
        self.jitaiScheduledDecisionIDs = jitaiScheduledDecisionIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        permissionState = try container.decodeIfPresent(NotificationPermissionState.self, forKey: .permissionState) ?? .notDetermined
        lastScheduledAt = try container.decodeIfPresent(TimeInterval.self, forKey: .lastScheduledAt)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        jitaiNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .jitaiNotificationsEnabled) ?? false
        jitaiLastScheduledAt = try container.decodeIfPresent(TimeInterval.self, forKey: .jitaiLastScheduledAt)
        jitaiScheduledDecisionIDs = try container.decodeIfPresent(Set<String>.self, forKey: .jitaiScheduledDecisionIDs) ?? []
    }
}

struct PersistedEvaluationState: Codable {
    var interventionLogs: [InterventionLog] = []
    var checkIns: [CheckInMetric] = []
    var safetyEvents: [SafetyEvent] = []
}

enum LuminaAccountProvider: String, Codable, CaseIterable, Identifiable, Equatable {
    case email
    case phone
    case apple
    case google

    var id: String { rawValue }

    var title: String {
        switch self {
        case .email: return "Email"
        case .phone: return "Phone"
        case .apple: return "Apple ID"
        case .google: return "Google"
        }
    }
}

struct LuminaAccount: Codable, Identifiable, Equatable {
    var id: String
    var provider: LuminaAccountProvider
    var displayName: String
    var email: String?
    var phone: String?
    var providerUserID: String?
    var createdAt: TimeInterval
    var lastSignedInAt: TimeInterval

    var primaryContact: String {
        email ?? phone ?? provider.title
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        let value = parts.compactMap(\.first).map { String($0) }.prefix(2).joined()
        return value.isEmpty ? String(displayName.prefix(1)).uppercased() : value.uppercased()
    }
}

struct LuminaAccountCredential: Codable, Identifiable, Equatable {
    var id: String
    var provider: LuminaAccountProvider
    var identifier: String
    var accountID: String
    var passwordSalt: String
    var passwordHash: String
    var createdAt: TimeInterval
}

struct PersistedAccountState: Codable {
    var currentAccount: LuminaAccount?
    var accounts: [LuminaAccount] = []
    var credentials: [LuminaAccountCredential] = []
}

enum SubscriptionTier: String, Codable, CaseIterable, Identifiable, Equatable {
    case free
    case premium

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Lumia Plus"
        }
    }
}

enum SubscriptionStatus: String, Codable, CaseIterable, Identifiable, Equatable {
    case unknown
    case active
    case trialing
    case gracePeriod = "grace_period"
    case expired
    case cancelled
    case billingIssue = "billing_issue"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unknown: return "Unknown"
        case .active: return "Active"
        case .trialing: return "Trial"
        case .gracePeriod: return "Grace period"
        case .expired: return "Expired"
        case .cancelled: return "Cancelled"
        case .billingIssue: return "Billing issue"
        }
    }
}

enum SubscriptionProvider: String, Codable, CaseIterable, Identifiable, Equatable {
    case none
    case revenuecat
    case manual

    var id: String { rawValue }
}

enum PremiumFeature: String, Codable, CaseIterable, Identifiable {
    case therapyChat
    case deepInsights
    case liveCall
    case advancedMemory
    case gardenPremium

    var id: String { rawValue }
}

struct SubscriptionState: Codable, Equatable {
    var tier: SubscriptionTier = .free
    var status: SubscriptionStatus = .unknown
    var provider: SubscriptionProvider = .none
    var revenueCatAppUserID: String?
    var productID: String?
    var entitlementID: String?
    var currentPeriodEnd: TimeInterval?
    var willRenew: Bool = false
    var updatedAt: TimeInterval = Date().timeIntervalSince1970

    var hasPremiumAccess: Bool {
        tier == .premium && [.active, .trialing, .gracePeriod].contains(status)
    }

    var displayTitle: String {
        hasPremiumAccess ? tier.title : "Free"
    }

    var displayDetail: String {
        if hasPremiumAccess {
            if let currentPeriodEnd {
                let date = Date(timeIntervalSince1970: currentPeriodEnd).formatted(date: .abbreviated, time: .omitted)
                return willRenew ? "Renews \(date)" : "Active until \(date)"
            }
            return status.title
        }
        if status == .billingIssue {
            return "Payment needs attention"
        }
        return "Upgrade for Live calls and deeper insights"
    }
}

struct PersistedSubscriptionState: Codable {
    var subscription: SubscriptionState = SubscriptionState()
}

enum LuminaAuthError: LocalizedError {
    case invalidName
    case invalidEmail
    case invalidPhone
    case weakPassword
    case passwordMismatch
    case duplicateAccount
    case accountNotFound
    case wrongPassword
    case providerUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Enter a name to create the account."
        case .invalidEmail:
            return "Enter a valid email address."
        case .invalidPhone:
            return "Enter a valid phone number."
        case .weakPassword:
            return "Use at least 8 characters for the password."
        case .passwordMismatch:
            return "The passwords do not match."
        case .duplicateAccount:
            return "An account with this sign-in method already exists."
        case .accountNotFound:
            return "No account was found for those details."
        case .wrongPassword:
            return "The password is incorrect."
        case .providerUnavailable(let message):
            return message
        }
    }
}

struct PersistedProfileState: Codable {
    var userName: String = "User"
    var userBio: String = ""
    var joinDate: Date = Date()
    var dailyReminderEnabled: Bool = false
    var dailyReminderHour: Int = 9
    var hapticFeedbackEnabled: Bool = true
    var useLargeText: Bool = false
    var requireBiometrics: Bool = false
    var useJournalContextInTherapy: Bool = true
    var journalGoalPerWeek: Int = 3
    var meditationGoalMinutes: Int = 10
}

struct PersistedJournalInsightState: Codable {
    var dailyInsight: DailyJournalInsights?
}

struct LuminaPersistedState: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = currentSchemaVersion
    var savedAt: TimeInterval = Date().timeIntervalSince1970
    var chatSessions: [String: ChatSession] = [:]
    var journalEntries: [JournalEntry] = []
    var garden: PersistedGardenState = PersistedGardenState()
    var followUps: [FollowUp] = []
    var health: PersistedHealthDataState = PersistedHealthDataState()
    var jitai: PersistedJITAIState = PersistedJITAIState()
    var notifications: PersistedNotificationState = PersistedNotificationState()
    var evaluation: PersistedEvaluationState = PersistedEvaluationState()
    var profile: PersistedProfileState = PersistedProfileState()
    var account: PersistedAccountState = PersistedAccountState()
    var subscription: PersistedSubscriptionState = PersistedSubscriptionState()
    var journalInsights: PersistedJournalInsightState = PersistedJournalInsightState()

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case savedAt
        case chatSessions
        case journalEntries
        case garden
        case followUps
        case health
        case jitai
        case notifications
        case evaluation
        case profile
        case account
        case subscription
        case journalInsights
    }

    init(
        schemaVersion: Int = currentSchemaVersion,
        savedAt: TimeInterval = Date().timeIntervalSince1970,
        chatSessions: [String: ChatSession] = [:],
        journalEntries: [JournalEntry] = [],
        garden: PersistedGardenState = PersistedGardenState(),
        followUps: [FollowUp] = [],
        health: PersistedHealthDataState = PersistedHealthDataState(),
        jitai: PersistedJITAIState = PersistedJITAIState(),
        notifications: PersistedNotificationState = PersistedNotificationState(),
        evaluation: PersistedEvaluationState = PersistedEvaluationState(),
        profile: PersistedProfileState = PersistedProfileState(),
        account: PersistedAccountState = PersistedAccountState(),
        subscription: PersistedSubscriptionState = PersistedSubscriptionState(),
        journalInsights: PersistedJournalInsightState = PersistedJournalInsightState()
    ) {
        self.schemaVersion = schemaVersion
        self.savedAt = savedAt
        self.chatSessions = chatSessions
        self.journalEntries = journalEntries
        self.garden = garden
        self.followUps = followUps
        self.health = health
        self.jitai = jitai
        self.notifications = notifications
        self.evaluation = evaluation
        self.profile = profile
        self.account = account
        self.subscription = subscription
        self.journalInsights = journalInsights
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        savedAt = try container.decodeIfPresent(TimeInterval.self, forKey: .savedAt) ?? Date().timeIntervalSince1970
        chatSessions = try container.decodeIfPresent([String: ChatSession].self, forKey: .chatSessions) ?? [:]
        journalEntries = try container.decodeIfPresent([JournalEntry].self, forKey: .journalEntries) ?? []
        garden = try container.decodeIfPresent(PersistedGardenState.self, forKey: .garden) ?? PersistedGardenState()
        followUps = try container.decodeIfPresent([FollowUp].self, forKey: .followUps) ?? []
        health = try container.decodeIfPresent(PersistedHealthDataState.self, forKey: .health) ?? PersistedHealthDataState()
        jitai = try container.decodeIfPresent(PersistedJITAIState.self, forKey: .jitai) ?? PersistedJITAIState()
        notifications = try container.decodeIfPresent(PersistedNotificationState.self, forKey: .notifications) ?? PersistedNotificationState()
        evaluation = try container.decodeIfPresent(PersistedEvaluationState.self, forKey: .evaluation) ?? PersistedEvaluationState()
        profile = try container.decodeIfPresent(PersistedProfileState.self, forKey: .profile) ?? PersistedProfileState()
        account = try container.decodeIfPresent(PersistedAccountState.self, forKey: .account) ?? PersistedAccountState()
        subscription = try container.decodeIfPresent(PersistedSubscriptionState.self, forKey: .subscription) ?? PersistedSubscriptionState()
        journalInsights = try container.decodeIfPresent(PersistedJournalInsightState.self, forKey: .journalInsights) ?? PersistedJournalInsightState()
    }
}

final class PersistenceService {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func load() -> LuminaPersistedState? {
        let url = stateURL
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(LuminaPersistedState.self, from: data)
    }

    func save(_ state: LuminaPersistedState) throws {
        let directory = stateDirectory
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: [.atomic])
    }

    private var stateDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Lumina", isDirectory: true)
    }

    private var stateURL: URL {
        stateDirectory.appendingPathComponent("state.json")
    }
}

final class LocalNotificationService {
    static let dailyReminderIdentifier = "lumina.daily.check_in"
    static let jitaiIdentifierPrefix = "lumina.jitai."

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func currentPermissionState() async -> NotificationPermissionState {
        let settings = await center.notificationSettings()
        return Self.permissionState(from: settings.authorizationStatus)
    }

    func requestAuthorization() async -> NotificationPermissionState {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else { return await currentPermissionState() }
            return await currentPermissionState()
        } catch {
            return await currentPermissionState()
        }
    }

    func scheduleDailyReminder(hour: Int) async throws {
        let content = UNMutableNotificationContent()
        content.title = "A quiet check-in"
        content.body = "Take 30 seconds to notice your mood, stress, and next small step."
        content.sound = .default
        content.threadIdentifier = "lumina.daily"
        content.userInfo = [
            "notificationType": "dailyReminder",
            "destinationTab": 0
        ]

        var components = DateComponents()
        components.hour = min(max(hour, 0), 23)
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )

        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])
        try await center.add(request)
    }

    func scheduleJITAIDecision(_ decision: JITAIDecision) async throws {
        let secondsUntilExpiry = decision.expiresAt - Date().timeIntervalSince1970
        guard secondsUntilExpiry > 60 else { return }

        let content = UNMutableNotificationContent()
        content.title = decision.title
        content.body = decision.message
        content.sound = .default
        content.threadIdentifier = "lumina.jitai"
        content.categoryIdentifier = "lumina.jitai"
        content.userInfo = [
            "notificationType": "jitai",
            "decisionID": decision.id,
            "kind": decision.kind.rawValue,
            "destinationTab": decision.destinationTab
        ]

        let delay = min(300, max(60, secondsUntilExpiry / 2))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let identifier = Self.jitaiIdentifierPrefix + decision.id
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        try await center.add(request)
    }

    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])
    }

    func cancelJITAINotification(decisionID: String) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.jitaiIdentifierPrefix + decisionID])
    }

    func cancelJITAINotifications(decisionIDs: Set<String>) {
        let identifiers = decisionIDs.map { Self.jitaiIdentifierPrefix + $0 }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func permissionState(from status: UNAuthorizationStatus) -> NotificationPermissionState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .unknown
        }
    }
}

@MainActor
final class NotificationStore: ObservableObject {
    @Published private(set) var permissionState: NotificationPermissionState = .notDetermined
    @Published private(set) var lastScheduledAt: TimeInterval?
    @Published private(set) var lastError: String?
    @Published private(set) var jitaiNotificationsEnabled = false
    @Published private(set) var jitaiLastScheduledAt: TimeInterval?
    @Published private(set) var jitaiScheduledDecisionIDs: Set<String> = []

    private let service = LocalNotificationService()
    private var jitaiSchedulingDecisionIDs: Set<String> = []

    func restore(_ state: PersistedNotificationState) {
        permissionState = state.permissionState
        lastScheduledAt = state.lastScheduledAt
        lastError = state.lastError
        jitaiNotificationsEnabled = state.jitaiNotificationsEnabled
        jitaiLastScheduledAt = state.jitaiLastScheduledAt
        jitaiScheduledDecisionIDs = state.jitaiScheduledDecisionIDs
        jitaiSchedulingDecisionIDs.removeAll()
    }

    func snapshot() -> PersistedNotificationState {
        PersistedNotificationState(
            permissionState: permissionState,
            lastScheduledAt: lastScheduledAt,
            lastError: lastError,
            jitaiNotificationsEnabled: jitaiNotificationsEnabled,
            jitaiLastScheduledAt: jitaiLastScheduledAt,
            jitaiScheduledDecisionIDs: jitaiScheduledDecisionIDs
        )
    }

    func refreshPermissionState() async {
        permissionState = await service.currentPermissionState()
    }

    @discardableResult
    func enableDailyReminder(hour: Int) async -> Bool {
        lastError = nil
        var state = await service.currentPermissionState()
        if state == .notDetermined {
            state = await service.requestAuthorization()
        }
        permissionState = state

        guard state == .authorized || state == .provisional || state == .ephemeral else {
            lastScheduledAt = nil
            lastError = "Notification permission is not enabled."
            service.cancelDailyReminder()
            return false
        }

        do {
            try await service.scheduleDailyReminder(hour: hour)
            lastScheduledAt = Date().timeIntervalSince1970
            return true
        } catch {
            lastScheduledAt = nil
            lastError = error.localizedDescription
            return false
        }
    }

    func disableDailyReminder() {
        service.cancelDailyReminder()
        lastScheduledAt = nil
        lastError = nil
    }

    @discardableResult
    func enableJITAINotifications() async -> Bool {
        lastError = nil
        var state = await service.currentPermissionState()
        if state == .notDetermined {
            state = await service.requestAuthorization()
        }
        permissionState = state

        guard state == .authorized || state == .provisional || state == .ephemeral else {
            jitaiNotificationsEnabled = false
            jitaiLastScheduledAt = nil
            lastError = "Notification permission is not enabled."
            service.cancelJITAINotifications(decisionIDs: jitaiScheduledDecisionIDs)
            jitaiScheduledDecisionIDs.removeAll()
            return false
        }

        jitaiNotificationsEnabled = true
        return true
    }

    func disableJITAINotifications() {
        service.cancelJITAINotifications(decisionIDs: jitaiScheduledDecisionIDs)
        jitaiNotificationsEnabled = false
        jitaiLastScheduledAt = nil
        jitaiScheduledDecisionIDs.removeAll()
        jitaiSchedulingDecisionIDs.removeAll()
        lastError = nil
    }

    @discardableResult
    func scheduleJITAIDecisionIfNeeded(_ decision: JITAIDecision) async -> Bool {
        guard jitaiNotificationsEnabled else { return false }
        guard decision.expiresAt - Date().timeIntervalSince1970 > 60 else { return false }
        guard !jitaiScheduledDecisionIDs.contains(decision.id) else { return false }
        guard !jitaiSchedulingDecisionIDs.contains(decision.id) else { return false }
        jitaiSchedulingDecisionIDs.insert(decision.id)
        defer { jitaiSchedulingDecisionIDs.remove(decision.id) }

        var state = await service.currentPermissionState()
        if state == .notDetermined {
            state = await service.requestAuthorization()
        }
        permissionState = state

        guard state == .authorized || state == .provisional || state == .ephemeral else {
            lastError = "Notification permission is not enabled."
            return false
        }

        do {
            try await service.scheduleJITAIDecision(decision)
            jitaiScheduledDecisionIDs.insert(decision.id)
            if jitaiScheduledDecisionIDs.count > 48 {
                jitaiScheduledDecisionIDs = Set(jitaiScheduledDecisionIDs.suffix(48))
            }
            jitaiLastScheduledAt = Date().timeIntervalSince1970
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func cancelJITAINotification(decisionID: String) {
        service.cancelJITAINotification(decisionID: decisionID)
        jitaiScheduledDecisionIDs.remove(decisionID)
    }

    func reconcileJITAISchedules(activeDecisionID: String?) {
        let activeIDs = activeDecisionID.map { Set([$0]) } ?? []
        let staleIDs = jitaiScheduledDecisionIDs.subtracting(activeIDs)
        guard !staleIDs.isEmpty else { return }
        service.cancelJITAINotifications(decisionIDs: staleIDs)
        jitaiScheduledDecisionIDs.subtract(staleIDs)
        if jitaiScheduledDecisionIDs.isEmpty {
            jitaiLastScheduledAt = nil
        }
    }
}

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var chatSessions: [String: ChatSession] = [:]
    private var chatSessionPublishScheduled = false

    func restore(_ sessions: [String: ChatSession]) {
        chatSessions = sessions
        chatSessionPublishScheduled = false
    }

    func sessions(for therapist: Therapist) -> [ChatSession] {
        chatSessions.values
            .filter { ($0.therapistID == therapist.id || $0.id == therapist.id) && $0.archivedAt == nil }
            .sorted { $0.lastUpdated > $1.lastUpdated }
    }

    func session(for therapist: Therapist) -> ChatSession? {
        sessions(for: therapist).first
    }

    func saveSession(_ session: ChatSession, publish: ChatSessionPublishMode = .deferred) {
        saveSessions([session], publish: publish)
    }

    func saveSessions(_ sessions: [ChatSession], publish: ChatSessionPublishMode = .deferred) {
        guard !sessions.isEmpty else { return }
        if publish == .immediate {
            objectWillChange.send()
        }
        for session in sessions {
            chatSessions[session.id] = session
        }
        scheduleChatSessionPublishIfNeeded(publish)
    }

    func clearSession(for therapist: Therapist, publish: ChatSessionPublishMode = .deferred) {
        guard chatSessions.values.contains(where: { $0.therapistID == therapist.id || $0.id == therapist.id }) else { return }
        if publish == .immediate {
            objectWillChange.send()
        }
        chatSessions = chatSessions.filter { _, session in
            session.therapistID != therapist.id && session.id != therapist.id
        }
        scheduleChatSessionPublishIfNeeded(publish)
    }

    func deleteSession(id: String, publish: ChatSessionPublishMode = .deferred) {
        guard chatSessions[id] != nil else { return }
        if publish == .immediate {
            objectWillChange.send()
        }
        chatSessions[id] = nil
        scheduleChatSessionPublishIfNeeded(publish)
    }

    func archiveSession(id: String, publish: ChatSessionPublishMode = .deferred) -> ChatSession? {
        guard var session = chatSessions[id] else { return nil }
        if publish == .immediate {
            objectWillChange.send()
        }
        session.archivedAt = Date().timeIntervalSince1970
        session.lastUpdated = Date().timeIntervalSince1970
        chatSessions[id] = session
        scheduleChatSessionPublishIfNeeded(publish)
        return session
    }

    func clearAllChatSessions(publish: ChatSessionPublishMode = .deferred) {
        guard !chatSessions.isEmpty else { return }
        if publish == .immediate {
            objectWillChange.send()
        }
        chatSessions.removeAll()
        scheduleChatSessionPublishIfNeeded(publish)
    }

    private func scheduleChatSessionPublishIfNeeded(_ publish: ChatSessionPublishMode) {
        guard publish == .deferred, !chatSessionPublishScheduled else { return }
        chatSessionPublishScheduled = true
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            self.chatSessionPublishScheduled = false
            self.objectWillChange.send()
        }
    }
}

@MainActor
final class JournalStore: ObservableObject {
    @Published var entries: [JournalEntry] = []

    var averageSentiment: Int {
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0) { $0 + ($1.sentimentScore ?? 50) } / entries.count
    }

    func restore(_ entries: [JournalEntry]) {
        self.entries = entries.filter { !Self.isSeedReflection($0) }
    }

    func addEntry(_ entry: JournalEntry) {
        entries.insert(entry, at: 0)
    }

    func updateEntry(_ entry: JournalEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        }
    }

    func deleteEntry(id: String) {
        entries.removeAll { $0.id == id }
    }

    func togglePin(id: String) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].isPinned.toggle()
    }

    private static func isSeedReflection(_ entry: JournalEntry) -> Bool {
        let seedTitles: Set<String> = [
            "Afternoon Sunshine",
            "Finding calm in chaos",
            "Energy burst!",
            "A bit heavy today"
        ]
        return ["1", "2", "3", "4"].contains(entry.id) && seedTitles.contains(entry.title)
    }
}

@MainActor
final class JournalInsightStore: ObservableObject {
    @Published var dailyInsight: DailyJournalInsights?

    func restore(_ state: PersistedJournalInsightState) {
        dailyInsight = state.dailyInsight
    }

    func snapshot() -> PersistedJournalInsightState {
        PersistedJournalInsightState(dailyInsight: dailyInsight)
    }

    func save(_ insight: DailyJournalInsights) {
        dailyInsight = insight
    }

    func clear() {
        dailyInsight = nil
    }
}

@MainActor
final class GardenStore: ObservableObject {
    @Published var habits: [Habit] = [
        Habit(id: "1", title: "Drink a glass of warm water", description: "Start the day hydrated.", completedAt: nil, createdAt: Date().timeIntervalSince1970, plantType: .sprout, growth: 30),
        Habit(id: "2", title: "Look out the window for 2 mins", description: "Rest your eyes.", completedAt: nil, createdAt: Date().timeIntervalSince1970, plantType: .flower, growth: 70),
        Habit(id: "3", title: "Write one sentence of gratitude", description: "Ground in what is good.", completedAt: nil, createdAt: Date().timeIntervalSince1970, plantType: .seed, growth: 10),
        Habit(id: "4", title: "Take a 5-minute walk", description: "Move to clear the mind.", completedAt: nil, createdAt: Date().timeIntervalSince1970, plantType: .tree, growth: 100),
    ]
    @Published var waterDrops: Int = 5
    @Published var gardenDecorations: [GardenDecoration] = []
    @Published var claimedGardenQuestIDs: Set<String> = []
    @Published var therapyMicroPlans: [MicroPlan] = []
    @Published var forageItems: [GardenForageItem] = []
    @Published var dailyEvents: [GardenDailyEvent] = []
    @Published var keepsakes: [GardenKeepsake] = []
    @Published var unlockedAreas: [GardenMapAreaUnlock] = []
    @Published var areaVisits: [GardenMapAreaVisit] = []
    @Published var areaMilestones: [GardenAreaMilestoneUnlock] = []

    func restore(_ state: PersistedGardenState) {
        habits = state.habits
        waterDrops = state.waterDrops
        gardenDecorations = state.gardenDecorations
        claimedGardenQuestIDs = state.claimedGardenQuestIDs
        therapyMicroPlans = state.therapyMicroPlans
        forageItems = state.forageItems
        dailyEvents = state.dailyEvents
        keepsakes = state.keepsakes
        unlockedAreas = state.unlockedAreas
        areaVisits = state.areaVisits
        areaMilestones = state.areaMilestones
    }

    func snapshot() -> PersistedGardenState {
        PersistedGardenState(
            habits: habits,
            waterDrops: waterDrops,
            gardenDecorations: gardenDecorations,
            claimedGardenQuestIDs: claimedGardenQuestIDs,
            therapyMicroPlans: therapyMicroPlans,
            forageItems: forageItems,
            dailyEvents: dailyEvents,
            keepsakes: keepsakes,
            unlockedAreas: unlockedAreas,
            areaVisits: areaVisits,
            areaMilestones: areaMilestones
        )
    }

    func habit(id: String) -> Habit? {
        habits.first { $0.id == id }
    }

    func completeHabit(id: String) {
        guard let idx = habits.firstIndex(where: { $0.id == id }) else { return }
        if habits[idx].completedAt == nil {
            completeHabit(at: idx, reward: 3)
        } else {
            habits[idx].completedAt = nil
        }
    }

    @discardableResult
    func completeHabitIfNeeded(id: String, reward: Int = 3) -> Bool {
        guard let idx = habits.firstIndex(where: { $0.id == id }),
              habits[idx].completedAt == nil else { return false }
        completeHabit(at: idx, reward: reward)
        return true
    }

    func waterPlant(id: String) {
        guard waterDrops > 0,
              let idx = habits.firstIndex(where: { $0.id == id }),
              habits[idx].plantType != .tree else { return }
        waterDrops -= 1
        habits[idx].growth = min(100, habits[idx].growth + 20)
        let growth = habits[idx].growth
        if growth >= 100 {
            habits[idx].plantType = .tree
        } else if growth >= 60 {
            habits[idx].plantType = .flower
        } else if growth >= 30 {
            habits[idx].plantType = .sprout
        } else {
            habits[idx].plantType = .seed
        }
    }

    func canPlaceGardenDecoration(_ type: GardenDecorationType) -> Bool {
        waterDrops >= type.dewCost
    }

    @discardableResult
    func placeGardenDecoration(type: GardenDecorationType, anchorHabitID: String, x: Double, y: Double) -> Bool {
        guard canPlaceGardenDecoration(type) else { return false }
        waterDrops -= type.dewCost
        gardenDecorations.append(
            GardenDecoration(
                type: type,
                anchorHabitID: anchorHabitID,
                x: min(max(x, 0.10), 0.90),
                y: min(max(y, 0.28), 0.73)
            )
        )
        if gardenDecorations.count > 14 {
            gardenDecorations.removeFirst(gardenDecorations.count - 14)
        }
        return true
    }

    @discardableResult
    func claimGardenQuest(id: String, reward: Int) -> Bool {
        guard !claimedGardenQuestIDs.contains(id), reward > 0 else { return false }
        claimedGardenQuestIDs.insert(id)
        waterDrops += reward
        return true
    }

    var activeForageItems: [GardenForageItem] {
        forageItems.filter { !$0.isClaimed }
    }

    func refreshDailyForage(now: Date = Date()) {
        let dayKey = GardenForageItem.dayKey(for: now)
        forageItems = forageItems.filter { $0.dayKey == dayKey }
        guard forageItems.isEmpty else { return }

        forageItems = Self.dailyForagePositions.enumerated().map { index, position in
            GardenForageItem(
                id: "dew-\(dayKey)-\(index)",
                dayKey: dayKey,
                x: position.x,
                y: position.y,
                reward: index == 0 ? 2 : 1,
                spawnedAt: now.timeIntervalSince1970
            )
        }
    }

    @discardableResult
    func claimForageItem(id: String, now: Date = Date()) -> GardenForageItem? {
        guard let index = forageItems.firstIndex(where: { $0.id == id && !$0.isClaimed }) else {
            return nil
        }

        var item = forageItems[index]
        item.claimedAt = now.timeIntervalSince1970
        forageItems[index] = item
        waterDrops += item.reward
        return item
    }

    func activeDailyEvent(on date: Date = Date()) -> GardenDailyEvent? {
        let dayKey = GardenForageItem.dayKey(for: date)
        return dailyEvents.first { $0.dayKey == dayKey && !$0.isDismissed && !$0.isCompleted }
    }

    func refreshDailyEvent(now: Date = Date()) {
        let dayKey = GardenForageItem.dayKey(for: now)
        dailyEvents = dailyEvents.filter { $0.dayKey == dayKey }
        guard dailyEvents.isEmpty else { return }
        dailyEvents = [GardenDailyEvent.make(for: now)]
    }

    @discardableResult
    func acceptDailyEvent(id: String, now: Date = Date()) -> GardenDailyEvent? {
        guard let index = dailyEvents.firstIndex(where: { $0.id == id && !$0.isDismissed && !$0.isCompleted }) else {
            return nil
        }
        if dailyEvents[index].acceptedAt == nil {
            dailyEvents[index].acceptedAt = now.timeIntervalSince1970
        }
        return dailyEvents[index]
    }

    @discardableResult
    func completeDailyEvent(id: String, progress: Int, now: Date = Date()) -> GardenDailyEvent? {
        guard let index = dailyEvents.firstIndex(where: { $0.id == id && !$0.isDismissed && !$0.isCompleted }),
              dailyEvents[index].isAccepted,
              progress >= dailyEvents[index].taskGoal else {
            return nil
        }

        dailyEvents[index].completedAt = now.timeIntervalSince1970
        waterDrops += dailyEvents[index].reward
        unlockKeepsake(
            kind: GardenKeepsakeKind.reward(for: dailyEvents[index].visitor),
            visitor: dailyEvents[index].visitor,
            sourceEventID: dailyEvents[index].id,
            now: now
        )
        return dailyEvents[index]
    }

    @discardableResult
    func dismissDailyEvent(id: String, now: Date = Date()) -> GardenDailyEvent? {
        guard let index = dailyEvents.firstIndex(where: { $0.id == id && !$0.isCompleted }) else {
            return nil
        }
        dailyEvents[index].dismissedAt = now.timeIntervalSince1970
        return dailyEvents[index]
    }

    @discardableResult
    func unlockKeepsake(
        kind: GardenKeepsakeKind,
        visitor: GardenVisitorKind,
        sourceEventID: String,
        now: Date = Date()
    ) -> GardenKeepsake? {
        if let existing = keepsakes.first(where: { $0.kind == kind }) {
            return existing
        }

        let keepsake = GardenKeepsake(
            kind: kind,
            visitor: visitor,
            unlockedAt: now.timeIntervalSince1970,
            sourceEventID: sourceEventID
        )
        keepsakes.append(keepsake)
        unlockMapArea(
            area: GardenMapAreaKind.reward(for: kind),
            sourceKeepsakeID: keepsake.id,
            now: now
        )
        return keepsake
    }

    @discardableResult
    func unlockMapArea(
        area: GardenMapAreaKind,
        sourceKeepsakeID: String,
        now: Date = Date()
    ) -> GardenMapAreaUnlock? {
        if let existing = unlockedAreas.first(where: { $0.area == area }) {
            return existing
        }

        let unlock = GardenMapAreaUnlock(
            area: area,
            unlockedAt: now.timeIntervalSince1970,
            sourceKeepsakeID: sourceKeepsakeID
        )
        unlockedAreas.append(unlock)
        return unlock
    }

    func areaVisit(area: GardenMapAreaKind, on date: Date = Date()) -> GardenMapAreaVisit? {
        let dayKey = GardenForageItem.dayKey(for: date)
        return areaVisits.first { $0.area == area && $0.dayKey == dayKey }
    }

    func areaVisitCount(area: GardenMapAreaKind) -> Int {
        areaVisits.filter { $0.area == area }.count
    }

    func unlockedAreaMilestones(area: GardenMapAreaKind) -> [GardenAreaMilestoneUnlock] {
        areaMilestones
            .filter { $0.area == area }
            .sorted { $0.stage < $1.stage }
    }

    func nextAreaMilestone(area: GardenMapAreaKind) -> GardenAreaMilestoneDefinition? {
        let unlockedStages = Set(unlockedAreaMilestones(area: area).map(\.stage))
        return area.milestoneDefinitions.first { !unlockedStages.contains($0.stage) }
    }

    @discardableResult
    func completeMapAreaVisit(area: GardenMapAreaKind, now: Date = Date()) -> GardenAreaActionResult? {
        guard unlockedAreas.contains(where: { $0.area == area }),
              areaVisit(area: area, on: now) == nil else {
            return nil
        }

        let visit = GardenMapAreaVisit(
            area: area,
            dayKey: GardenForageItem.dayKey(for: now),
            reward: area.dailyReward,
            completedAt: now.timeIntervalSince1970
        )
        areaVisits.append(visit)

        let completedVisitCount = areaVisitCount(area: area)
        let existingStages = Set(areaMilestones.filter { $0.area == area }.map(\.stage))
        let unlockedMilestones = area.milestoneDefinitions.compactMap { definition -> GardenAreaMilestoneUnlock? in
            guard completedVisitCount >= definition.requiredVisits,
                  !existingStages.contains(definition.stage) else {
                return nil
            }
            return GardenAreaMilestoneUnlock(
                area: area,
                stage: definition.stage,
                requiredVisits: definition.requiredVisits,
                reward: definition.reward,
                unlockedAt: now.timeIntervalSince1970
            )
        }

        areaMilestones.append(contentsOf: unlockedMilestones)
        let result = GardenAreaActionResult(visit: visit, unlockedMilestones: unlockedMilestones)
        waterDrops += result.totalReward
        return result
    }

    @discardableResult
    func addTherapyMicroPlan(_ microPlan: MicroPlan) -> Habit? {
        let normalizedAction = microPlan.action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedAction.isEmpty else { return nil }
        if habits.contains(where: { $0.sourceMicroPlanID == microPlan.id || $0.title.lowercased() == normalizedAction }) {
            return nil
        }

        therapyMicroPlans.append(microPlan)
        let habit = Habit(
            id: "therapy-plan-\(microPlan.id)",
            title: microPlan.action,
            description: "When \(microPlan.trigger), try this tiny plan from Therapy.",
            completedAt: nil,
            createdAt: microPlan.createdAt,
            plantType: .seed,
            growth: 0,
            sourceMicroPlanID: microPlan.id
        )
        habits.insert(habit, at: 0)
        return habit
    }

    private func completeHabit(at index: Int, reward: Int) {
        waterDrops += reward
        habits[index].completedAt = Date().timeIntervalSince1970
        habits[index].growth = max(habits[index].growth, min(100, habits[index].growth + 30))
        updatePlantType(at: index)
    }

    private func updatePlantType(at index: Int) {
        let growth = habits[index].growth
        if growth >= 100 {
            habits[index].plantType = .tree
        } else if growth >= 60 {
            habits[index].plantType = .flower
        } else if growth >= 30 {
            habits[index].plantType = .sprout
        } else {
            habits[index].plantType = .seed
        }
    }

    private static let dailyForagePositions: [(x: Double, y: Double)] = [
        (0.22, 0.24),
        (0.78, 0.36),
        (0.42, 0.56)
    ]
}

@MainActor
final class FollowUpStore: ObservableObject {
    @Published var followUps: [FollowUp] = []

    func restore(_ followUps: [FollowUp]) {
        self.followUps = followUps
    }

    var pendingFollowUps: [FollowUp] {
        followUps
            .filter { $0.status == .pending }
            .sorted { $0.dueAt < $1.dueAt }
    }

    var activeFollowUp: FollowUp? {
        pendingFollowUps.first
    }

    @discardableResult
    func schedule(for microPlan: MicroPlan, habitID: String?, dueAfter seconds: TimeInterval = 86_400) -> FollowUp? {
        guard !followUps.contains(where: { $0.microPlanID == microPlan.id }) else { return nil }
        let followUp = FollowUp(
            microPlanID: microPlan.id,
            habitID: habitID,
            sourceSessionID: microPlan.sourceSessionID,
            prompt: "Check whether this tiny plan still fits.",
            trigger: microPlan.trigger,
            action: microPlan.action,
            createdAt: microPlan.createdAt,
            dueAt: Date().timeIntervalSince1970 + seconds
        )
        followUps.append(followUp)
        return followUp
    }

    @discardableResult
    func record(id: String, status: FollowUpStatus, now: TimeInterval = Date().timeIntervalSince1970) -> FollowUp? {
        guard let index = followUps.firstIndex(where: { $0.id == id }) else { return nil }
        followUps[index].status = status
        followUps[index].respondedAt = now
        return followUps[index]
    }

    @discardableResult
    func record(microPlanID: String, status: FollowUpStatus, now: TimeInterval = Date().timeIntervalSince1970) -> FollowUp? {
        guard let followUp = followUps.first(where: { $0.microPlanID == microPlanID && $0.status == .pending }) else { return nil }
        return record(id: followUp.id, status: status, now: now)
    }

    @discardableResult
    func snooze(id: String, hours: Double = 24) -> FollowUp? {
        guard let index = followUps.firstIndex(where: { $0.id == id && $0.status == .pending }) else { return nil }
        followUps[index].dueAt = Date().timeIntervalSince1970 + hours * 3_600
        return followUps[index]
    }
}

final class HealthKitService {
    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.authorizationDenied)
                }
            }
        }
    }

    func fetchDailySummaries(days: Int) async throws -> [DailyHealthSummary] {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        let startOfToday = calendar.startOfDay(for: Date())
        let count = max(1, min(days, 30))

        return try await withThrowingTaskGroup(of: DailyHealthSummary.self) { group in
            for offset in 0..<count {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday),
                      let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
                group.addTask {
                    try await self.fetchSummary(for: day, end: nextDay)
                }
            }

            var summaries: [DailyHealthSummary] = []
            for try await summary in group {
                summaries.append(summary)
            }
            return summaries.sorted { $0.date > $1.date }
        }
    }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        [
            HKQuantityTypeIdentifier.stepCount,
            .activeEnergyBurned,
            .appleExerciseTime,
            .restingHeartRate,
            .heartRate
        ].compactMap { HKObjectType.quantityType(forIdentifier: $0) }.forEach { types.insert($0) }

        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }

    private func fetchSummary(for start: Date, end: Date) async throws -> DailyHealthSummary {
        async let steps = quantitySum(.stepCount, unit: .count(), start: start, end: end)
        async let energy = quantitySum(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
        async let exercise = quantitySum(.appleExerciseTime, unit: .minute(), start: start, end: end)
        async let restingHR = quantityAverage(.restingHeartRate, unit: heartRateUnit, start: start, end: end)
        async let averageHR = quantityAverage(.heartRate, unit: heartRateUnit, start: start, end: end)
        async let sleep = sleepMinutes(start: start, end: end)

        return try await DailyHealthSummary(
            date: start,
            stepCount: steps,
            activeEnergyKcal: energy,
            exerciseMinutes: exercise,
            sleepMinutes: sleep,
            restingHeartRate: restingHR,
            averageHeartRate: averageHR
        )
    }

    private var heartRateUnit: HKUnit {
        HKUnit.count().unitDivided(by: .minute())
    }

    private func quantitySum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func quantityAverage(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: statistics?.averageQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func sleepMinutes(start: Date, end: Date) async throws -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let asleepValues = Set([
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let totalSeconds = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0) { total, sample in
                        let overlapStart = max(sample.startDate, start)
                        let overlapEnd = min(sample.endDate, end)
                        return total + max(0, overlapEnd.timeIntervalSince(overlapStart))
                    }
                continuation.resume(returning: totalSeconds > 0 ? totalSeconds / 60 : nil)
            }
            healthStore.execute(query)
        }
    }
}

enum HealthKitServiceError: LocalizedError {
    case unavailable
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Health data is not available on this device."
        case .authorizationDenied:
            return "Health permission was not granted."
        }
    }
}

@MainActor
final class HealthDataStore: ObservableObject {
    @Published var permissionState: HealthPermissionState
    @Published var summaries: [DailyHealthSummary] = []
    @Published var baseline: HealthBaseline?
    @Published var lastSyncAt: TimeInterval?
    @Published var isSyncing = false
    @Published var lastError: String?
    @Published var hasAcknowledgedDataUse = false

    private let service = HealthKitService()

    init() {
        permissionState = service.isAvailable ? .notDetermined : .unavailable
    }

    func restore(_ state: PersistedHealthDataState) {
        permissionState = service.isAvailable ? state.permissionState : .unavailable
        summaries = state.summaries
        baseline = state.baseline
        lastSyncAt = state.lastSyncAt
        isSyncing = false
        lastError = state.lastError
        hasAcknowledgedDataUse = state.hasAcknowledgedDataUse
    }

    func snapshot() -> PersistedHealthDataState {
        PersistedHealthDataState(
            permissionState: permissionState,
            summaries: summaries,
            baseline: baseline,
            lastSyncAt: lastSyncAt,
            lastError: lastError,
            hasAcknowledgedDataUse: hasAcknowledgedDataUse
        )
    }

    func acknowledgeDataUse() {
        hasAcknowledgedDataUse = true
    }

    func requestAuthorizationAndSync(days: Int = 14) async {
        guard service.isAvailable else {
            permissionState = .unavailable
            lastError = "Health data is not available on this device."
            return
        }

        isSyncing = true
        lastError = nil
        do {
            try await service.requestAuthorization()
            permissionState = .requestCompleted
            try await syncSummaries(days: days)
        } catch {
            permissionState = .denied
            lastError = error.localizedDescription
            isSyncing = false
        }
    }

    func syncSummaries(days: Int = 14) async throws {
        isSyncing = true
        lastError = nil
        do {
            summaries = try await service.fetchDailySummaries(days: days)
            baseline = Self.computeBaseline(from: summaries)
            lastSyncAt = Date().timeIntervalSince1970
            isSyncing = false
        } catch {
            lastError = error.localizedDescription
            isSyncing = false
            throw error
        }
    }

    func deleteLocalHealthData() {
        summaries = []
        baseline = nil
        lastSyncAt = nil
        lastError = nil
    }

    private static func computeBaseline(from summaries: [DailyHealthSummary]) -> HealthBaseline? {
        let window = Array(summaries.prefix(30))
        guard !window.isEmpty else { return nil }
        let baseline = HealthBaseline(
            windowDays: window.count,
            averageSleepMinutes: average(window.compactMap(\.sleepMinutes)),
            averageSteps: average(window.compactMap(\.stepCount)),
            averageActiveEnergyKcal: average(window.compactMap(\.activeEnergyKcal)),
            averageExerciseMinutes: average(window.compactMap(\.exerciseMinutes)),
            averageRestingHeartRate: average(window.compactMap(\.restingHeartRate))
        )
        return baseline.hasAnySignal ? baseline : nil
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

@MainActor
final class JITAIStore: ObservableObject {
    @Published private(set) var decisions: [JITAIDecision] = []
    @Published private(set) var logs: [JITAIInteractionLog] = []
    @Published private(set) var suppressedUntil: TimeInterval?
    @Published private(set) var maxDailyPrompts = 2
    @Published private(set) var quietHoursStart = 22
    @Published private(set) var quietHoursEnd = 8

    var activeDecision: JITAIDecision? {
        let now = Date().timeIntervalSince1970
        return decisions.first { $0.expiresAt > now }
    }

    func restore(_ state: PersistedJITAIState) {
        decisions = state.decisions
        logs = state.logs
        suppressedUntil = state.suppressedUntil
        maxDailyPrompts = max(1, state.maxDailyPrompts)
        quietHoursStart = min(max(0, state.quietHoursStart), 23)
        quietHoursEnd = min(max(0, state.quietHoursEnd), 23)
    }

    func snapshot() -> PersistedJITAIState {
        PersistedJITAIState(
            decisions: decisions,
            logs: logs,
            suppressedUntil: suppressedUntil,
            maxDailyPrompts: maxDailyPrompts,
            quietHoursStart: quietHoursStart,
            quietHoursEnd: quietHoursEnd
        )
    }

    func setMaxDailyPrompts(_ value: Int) {
        maxDailyPrompts = min(max(value, 1), 5)
    }

    func setQuietHoursStart(_ value: Int) {
        quietHoursStart = min(max(value, 0), 23)
    }

    func setQuietHoursEnd(_ value: Int) {
        quietHoursEnd = min(max(value, 0), 23)
    }

    func refresh(
        entries: [JournalEntry],
        habits: [Habit],
        summaries: [DailyHealthSummary],
        baseline: HealthBaseline?,
        todayCheckIn: CheckInMetric? = nil,
        now: Date = Date()
    ) {
        let nowTimestamp = now.timeIntervalSince1970
        decisions = decisions.filter { $0.expiresAt > nowTimestamp }

        guard !isSuppressed(now: now),
              !isQuietHour(now),
              !hasReachedDailyPromptLimit(now: now) else {
            decisions.removeAll()
            return
        }

        let candidates = makeCandidates(
            entries: entries,
            habits: habits,
            summaries: summaries,
            baseline: baseline,
            todayCheckIn: todayCheckIn,
            now: now
        )
        let eligible = candidates.filter { !hasUserResponded(to: $0.id, on: now) }
        guard let selected = eligible.sorted(by: { $0.confidence > $1.confidence }).first else {
            decisions.removeAll()
            return
        }

        decisions = [selected]
        if !hasLogged(decisionID: selected.id, response: .shown, on: now) {
            logs.append(log(for: selected, response: .shown, now: nowTimestamp))
        }
    }

    @discardableResult
    func recordResponse(decisionID: String, response: JITAIUserResponse, now: Date = Date()) -> JITAIDecision? {
        guard let decision = decisions.first(where: { $0.id == decisionID }) else { return nil }
        logs.append(log(for: decision, response: response, now: now.timeIntervalSince1970))
        decisions.removeAll { $0.id == decisionID }

        if response == .suppressed {
            suppressedUntil = nextQuietRelease(after: now).timeIntervalSince1970
        } else if response == .dismissed && dismissalsToday(now: now) >= 2 {
            suppressedUntil = now.addingTimeInterval(12 * 3_600).timeIntervalSince1970
        }

        return decision
    }

    private func makeCandidates(
        entries: [JournalEntry],
        habits: [Habit],
        summaries: [DailyHealthSummary],
        baseline: HealthBaseline?,
        todayCheckIn: CheckInMetric?,
        now: Date
    ) -> [JITAIDecision] {
        let sortedEntries = entries.sorted { $0.timestamp > $1.timestamp }
        let latestEntry = sortedEntries.first
        let latestSummary = summaries.sorted { $0.date > $1.date }.first
        let dayKey = Self.dayKey(for: now)
        let createdAt = now.timeIntervalSince1970
        let expiresAt = Self.endOfDay(for: now).timeIntervalSince1970
        var candidates: [JITAIDecision] = []

        if let todayCheckIn, todayCheckIn.stressScore >= 8 {
            candidates.append(JITAIDecision(
                id: "jitai-checkin-grounding-\(dayKey)-\(todayCheckIn.id)",
                kind: .grounding,
                title: "Take pressure down first",
                message: "Today's stress check-in is high. A short grounding reset may fit better than another task.",
                actionTitle: "Open Sanctuary",
                destinationTab: 4,
                confidence: 0.80,
                reasonCodes: ["checkin.stress.high", "intervention.grounding", "context.self_report"],
                createdAt: createdAt,
                expiresAt: expiresAt,
                sourceID: todayCheckIn.id
            ))
        }

        if let todayCheckIn, todayCheckIn.moodScore <= 3 {
            candidates.append(JITAIDecision(
                id: "jitai-checkin-recovery-\(dayKey)-\(todayCheckIn.id)",
                kind: .recovery,
                title: "Keep the next step gentle",
                message: "Today's mood check-in is low. Lumia can shift toward recovery instead of pushing momentum.",
                actionTitle: "Open Sanctuary",
                destinationTab: 4,
                confidence: 0.76,
                reasonCodes: ["checkin.mood.low", "intervention.recovery", "context.self_report"],
                createdAt: createdAt,
                expiresAt: expiresAt,
                sourceID: todayCheckIn.id
            ))
        }

        if let latestEntry,
           latestEntry.timestamp > createdAt - 2 * 86_400,
           let anxiety = latestEntry.anxietyLevel,
           anxiety >= 70 {
            candidates.append(JITAIDecision(
                id: "jitai-grounding-\(dayKey)-\(latestEntry.id)",
                kind: .grounding,
                title: "Try a short reset",
                message: "Your latest reflection carried higher anxiety. A grounding exercise may fit better than another big task.",
                actionTitle: "Open Sanctuary",
                destinationTab: 4,
                confidence: 0.82,
                reasonCodes: ["journal.anxiety.high", "intervention.grounding"],
                createdAt: createdAt,
                expiresAt: expiresAt,
                sourceID: latestEntry.id
            ))
        }

        if let sleep = latestSummary?.sleepMinutes,
           let averageSleep = baseline?.averageSleepMinutes,
           averageSleep > 240,
           sleep + 75 < averageSleep {
            candidates.append(JITAIDecision(
                id: "jitai-recovery-\(dayKey)",
                kind: .recovery,
                title: "Keep today lighter",
                message: "Sleep looks below your recent personal range. Lumia can suggest a calmer check-in instead of pushing productivity.",
                actionTitle: "Open Sanctuary",
                destinationTab: 4,
                confidence: 0.74,
                reasonCodes: ["health.sleep.below_personal_range", "intervention.recovery"],
                createdAt: createdAt,
                expiresAt: expiresAt,
                sourceID: latestSummary?.id
            ))
        }

        if let steps = latestSummary?.stepCount,
           let averageSteps = baseline?.averageSteps,
           averageSteps > 1_200,
           steps < averageSteps * 0.45 {
            candidates.append(JITAIDecision(
                id: "jitai-movement-\(dayKey)",
                kind: .movement,
                title: "Choose one gentle move",
                message: "Activity is lower than your recent range. A tiny Garden step can be enough for today.",
                actionTitle: "Open Garden",
                destinationTab: 3,
                confidence: 0.68,
                reasonCodes: ["health.steps.below_personal_range", "garden.tiny_action"],
                createdAt: createdAt,
                expiresAt: expiresAt,
                sourceID: latestSummary?.id
            ))
        }

        if !sortedEntries.contains(where: { Self.isSameDay(Date(timeIntervalSince1970: $0.timestamp), now) }) {
            candidates.append(JITAIDecision(
                id: "jitai-reflection-\(dayKey)",
                kind: .reflection,
                title: "One honest sentence",
                message: "There is no reflection for today yet. A short entry is enough to keep the pattern visible.",
                actionTitle: "Write Reflection",
                destinationTab: 1,
                confidence: 0.58,
                reasonCodes: ["journal.no_entry_today", "intervention.journaling_prompt"],
                createdAt: createdAt,
                expiresAt: expiresAt,
                sourceID: nil
            ))
        }

        if let nextHabit = habits.first(where: { $0.completedAt == nil }) {
            candidates.append(JITAIDecision(
                id: "jitai-garden-\(dayKey)-\(nextHabit.id)",
                kind: .garden,
                title: "Tend one tiny plan",
                message: nextHabit.description,
                actionTitle: "Open Garden",
                destinationTab: 3,
                confidence: 0.52,
                reasonCodes: ["garden.open_habit", "behavior.small_step"],
                createdAt: createdAt,
                expiresAt: expiresAt,
                sourceID: nextHabit.id
            ))
        }

        return candidates
    }

    private func log(for decision: JITAIDecision, response: JITAIUserResponse, now: TimeInterval) -> JITAIInteractionLog {
        JITAIInteractionLog(
            decisionID: decision.id,
            kind: decision.kind,
            response: response,
            reasonCodes: decision.reasonCodes,
            confidence: decision.confidence,
            createdAt: now
        )
    }

    private func isSuppressed(now: Date) -> Bool {
        guard let suppressedUntil else { return false }
        return suppressedUntil > now.timeIntervalSince1970
    }

    private func isQuietHour(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        if quietHoursStart < quietHoursEnd {
            return hour >= quietHoursStart && hour < quietHoursEnd
        }
        return hour >= quietHoursStart || hour < quietHoursEnd
    }

    private func hasReachedDailyPromptLimit(now: Date) -> Bool {
        logs.filter {
            $0.response == .shown &&
            Self.isSameDay(Date(timeIntervalSince1970: $0.createdAt), now)
        }.count >= maxDailyPrompts
    }

    private func dismissalsToday(now: Date) -> Int {
        logs.filter {
            $0.response == .dismissed &&
            Self.isSameDay(Date(timeIntervalSince1970: $0.createdAt), now)
        }.count
    }

    private func hasUserResponded(to decisionID: String, on date: Date) -> Bool {
        logs.contains {
            $0.decisionID == decisionID &&
            $0.response != .shown &&
            Self.isSameDay(Date(timeIntervalSince1970: $0.createdAt), date)
        }
    }

    private func hasLogged(decisionID: String, response: JITAIUserResponse, on date: Date) -> Bool {
        logs.contains {
            $0.decisionID == decisionID &&
            $0.response == response &&
            Self.isSameDay(Date(timeIntervalSince1970: $0.createdAt), date)
        }
    }

    private func nextQuietRelease(after date: Date) -> Date {
        let calendar = Calendar.current
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: date) ?? date)
        return calendar.date(byAdding: .hour, value: quietHoursEnd, to: startOfTomorrow) ?? date.addingTimeInterval(24 * 3_600)
    }

    private static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func endOfDay(for date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date.addingTimeInterval(86_399)
    }
}

@MainActor
final class EvaluationStore: ObservableObject {
    @Published private(set) var interventionLogs: [InterventionLog] = []
    @Published private(set) var checkIns: [CheckInMetric] = []
    @Published private(set) var safetyEvents: [SafetyEvent] = []

    let therapyPolicy = PromptPolicyVersion.therapySupportV1
    let jitaiPolicy = PromptPolicyVersion.jitaiLocalV1

    var todayCheckIn: CheckInMetric? {
        let now = Date()
        return checkIns
            .filter { Calendar.current.isDate(Date(timeIntervalSince1970: $0.createdAt), inSameDayAs: now) }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    var crisisRouteCount: Int {
        safetyEvents.filter { $0.kind == .crisisRoute }.count
    }

    var falsePositiveCount: Int {
        safetyEvents.filter { $0.kind == .falsePositiveFeedback }.count
    }

    var userControlActionCount: Int {
        safetyEvents.filter { $0.kind == .userControlAction }.count
    }

    var canFlagLatestSafetyRoute: Bool {
        safetyEvents.contains { $0.kind == .crisisRoute || $0.kind == .mediumRiskTriage }
    }

    func restore(_ state: PersistedEvaluationState) {
        interventionLogs = state.interventionLogs
        checkIns = state.checkIns
        safetyEvents = state.safetyEvents
    }

    func snapshot() -> PersistedEvaluationState {
        PersistedEvaluationState(
            interventionLogs: interventionLogs,
            checkIns: checkIns,
            safetyEvents: safetyEvents
        )
    }

    @discardableResult
    func recordIntervention(
        source: InterventionLogSource,
        interventionKind: InterventionKind?,
        policy: PromptPolicyVersion,
        reasonCodes: [String],
        confidence: Double? = nil,
        outcome: InterventionOutcome,
        riskLevel: RiskLevel = .none,
        sessionID: String? = nil
    ) -> InterventionLog {
        let log = InterventionLog(
            source: source,
            interventionKind: interventionKind,
            policy: policy,
            reasonCodes: reasonCodes,
            confidence: confidence,
            outcome: outcome,
            riskLevel: riskLevel,
            sessionID: sessionID
        )
        interventionLogs.append(log)
        return log
    }

    @discardableResult
    func recordCheckIn(moodScore: Int, stressScore: Int, note: String?) -> CheckInMetric {
        let checkIn = CheckInMetric(moodScore: moodScore, stressScore: stressScore, note: note)
        checkIns.append(checkIn)
        return checkIn
    }

    @discardableResult
    func recordSafetyEvent(
        kind: SafetyEventKind,
        riskLevel: RiskLevel,
        reasonCodes: [String],
        sourceID: String? = nil,
        note: String? = nil
    ) -> SafetyEvent {
        let event = SafetyEvent(
            kind: kind,
            riskLevel: riskLevel,
            reasonCodes: reasonCodes,
            sourceID: sourceID,
            note: note
        )
        safetyEvents.append(event)
        return event
    }

    @discardableResult
    func flagLatestSafetyRouteFalsePositive() -> SafetyEvent? {
        guard let latest = safetyEvents
            .filter({ $0.kind == .crisisRoute || $0.kind == .mediumRiskTriage })
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first else { return nil }

        return recordSafetyEvent(
            kind: .falsePositiveFeedback,
            riskLevel: latest.riskLevel,
            reasonCodes: latest.reasonCodes + ["feedback.false_positive"],
            sourceID: latest.id,
            note: "User marked the latest safety route as too sensitive."
        )
    }
}

@MainActor
final class ProfileStore: ObservableObject {
    @Published var userName: String = "User"
    @Published var userBio: String = ""
    @Published var joinDate: Date = Date()
    @Published var dailyReminderEnabled: Bool = false
    @Published var dailyReminderHour: Int = 9
    @Published var hapticFeedbackEnabled: Bool = true
    @Published var useLargeText: Bool = false
    @Published var requireBiometrics: Bool = false
    @Published var useJournalContextInTherapy: Bool = true
    @Published var journalGoalPerWeek: Int = 3
    @Published var meditationGoalMinutes: Int = 10

    func restore(_ state: PersistedProfileState) {
        userName = state.userName
        userBio = state.userBio
        joinDate = state.joinDate
        dailyReminderEnabled = state.dailyReminderEnabled
        dailyReminderHour = state.dailyReminderHour
        hapticFeedbackEnabled = state.hapticFeedbackEnabled
        useLargeText = state.useLargeText
        requireBiometrics = state.requireBiometrics
        useJournalContextInTherapy = state.useJournalContextInTherapy
        journalGoalPerWeek = state.journalGoalPerWeek
        meditationGoalMinutes = state.meditationGoalMinutes
    }

    func snapshot() -> PersistedProfileState {
        PersistedProfileState(
            userName: userName,
            userBio: userBio,
            joinDate: joinDate,
            dailyReminderEnabled: dailyReminderEnabled,
            dailyReminderHour: dailyReminderHour,
            hapticFeedbackEnabled: hapticFeedbackEnabled,
            useLargeText: useLargeText,
            requireBiometrics: requireBiometrics,
            useJournalContextInTherapy: useJournalContextInTherapy,
            journalGoalPerWeek: journalGoalPerWeek,
            meditationGoalMinutes: meditationGoalMinutes
        )
    }
}

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var currentAccount: LuminaAccount?
    @Published private(set) var accounts: [LuminaAccount] = []
    private var credentials: [LuminaAccountCredential] = []

    func restore(_ state: PersistedAccountState) {
        currentAccount = state.currentAccount
        accounts = state.accounts
        credentials = state.credentials
    }

    func snapshot() -> PersistedAccountState {
        PersistedAccountState(
            currentAccount: currentAccount,
            accounts: accounts,
            credentials: credentials
        )
    }

    @discardableResult
    func signInRemoteAccount(
        provider: LuminaAccountProvider,
        providerUserID: String,
        displayName: String?,
        email: String?,
        phone: String?
    ) throws -> LuminaAccount {
        let normalizedEmail = try? email.flatMap { try Self.normalizeEmailValue($0) }
        let phoneValue = phone.flatMap { try? self.normalizedPhone($0) }
        let fallbackName = normalizedEmail ?? phoneValue ?? provider.title
        let name = (displayName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName

        if let existing = accounts.first(where: { $0.provider == provider && $0.providerUserID == providerUserID }) {
            signIn(existing)
            return currentAccount ?? existing
        }

        let account = makeAccount(
            provider: provider,
            displayName: name,
            email: normalizedEmail,
            phone: phoneValue,
            providerUserID: providerUserID
        )
        signIn(account)
        return currentAccount ?? account
    }

    @discardableResult
    func registerEmail(displayName: String, email: String, password: String) throws -> LuminaAccount {
        let name = try normalizedDisplayName(displayName)
        let identifier = try normalizedEmail(email)
        try validatePassword(password)
        guard !credentials.contains(where: { $0.provider == .email && $0.identifier == identifier }) else {
            throw LuminaAuthError.duplicateAccount
        }

        let account = makeAccount(provider: .email, displayName: name, email: identifier, phone: nil, providerUserID: nil)
        saveCredential(provider: .email, identifier: identifier, password: password, accountID: account.id)
        signIn(account)
        return account
    }

    @discardableResult
    func signInEmail(email: String, password: String) throws -> LuminaAccount {
        let identifier = try normalizedEmail(email)
        return try signInPasswordAccount(provider: .email, identifier: identifier, password: password)
    }

    @discardableResult
    func registerPhone(displayName: String, phone: String, password: String) throws -> LuminaAccount {
        let name = try normalizedDisplayName(displayName)
        let identifier = try normalizedPhone(phone)
        try validatePassword(password)
        guard !credentials.contains(where: { $0.provider == .phone && $0.identifier == identifier }) else {
            throw LuminaAuthError.duplicateAccount
        }

        let account = makeAccount(provider: .phone, displayName: name, email: nil, phone: identifier, providerUserID: nil)
        saveCredential(provider: .phone, identifier: identifier, password: password, accountID: account.id)
        signIn(account)
        return account
    }

    @discardableResult
    func signInPhone(phone: String, password: String) throws -> LuminaAccount {
        let identifier = try normalizedPhone(phone)
        return try signInPasswordAccount(provider: .phone, identifier: identifier, password: password)
    }

    @discardableResult
    func signInFederated(
        provider: LuminaAccountProvider,
        providerUserID: String,
        displayName: String?,
        email: String?
    ) throws -> LuminaAccount {
        guard provider == .apple || provider == .google else {
            throw LuminaAuthError.providerUnavailable("This provider is not a federated sign-in method.")
        }

        if let existing = accounts.first(where: { $0.provider == provider && $0.providerUserID == providerUserID }) {
            signIn(existing)
            return currentAccount ?? existing
        }

        let fallbackName = provider == .apple ? "Apple User" : "Google User"
        let name = (displayName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName
        let normalizedEmail = try? email.flatMap { try Self.normalizeEmailValue($0) }
        let account = makeAccount(
            provider: provider,
            displayName: name,
            email: normalizedEmail,
            phone: nil,
            providerUserID: providerUserID
        )
        signIn(account)
        return account
    }

    func signOut() {
        currentAccount = nil
    }

    private func makeAccount(
        provider: LuminaAccountProvider,
        displayName: String,
        email: String?,
        phone: String?,
        providerUserID: String?
    ) -> LuminaAccount {
        let account = LuminaAccount(
            id: UUID().uuidString,
            provider: provider,
            displayName: displayName,
            email: email,
            phone: phone,
            providerUserID: providerUserID,
            createdAt: Date().timeIntervalSince1970,
            lastSignedInAt: Date().timeIntervalSince1970
        )
        accounts.append(account)
        return account
    }

    private func signIn(_ account: LuminaAccount) {
        var updated = account
        updated.lastSignedInAt = Date().timeIntervalSince1970
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = updated
        } else {
            accounts.append(updated)
        }
        currentAccount = updated
    }

    private func signInPasswordAccount(
        provider: LuminaAccountProvider,
        identifier: String,
        password: String
    ) throws -> LuminaAccount {
        guard let credential = credentials.first(where: { $0.provider == provider && $0.identifier == identifier }) else {
            throw LuminaAuthError.accountNotFound
        }
        guard Self.passwordHash(password: password, salt: credential.passwordSalt) == credential.passwordHash else {
            throw LuminaAuthError.wrongPassword
        }
        guard let account = accounts.first(where: { $0.id == credential.accountID }) else {
            throw LuminaAuthError.accountNotFound
        }
        signIn(account)
        return currentAccount ?? account
    }

    private func saveCredential(
        provider: LuminaAccountProvider,
        identifier: String,
        password: String,
        accountID: String
    ) {
        let salt = UUID().uuidString
        credentials.append(
            LuminaAccountCredential(
                id: UUID().uuidString,
                provider: provider,
                identifier: identifier,
                accountID: accountID,
                passwordSalt: salt,
                passwordHash: Self.passwordHash(password: password, salt: salt),
                createdAt: Date().timeIntervalSince1970
            )
        )
    }

    private func normalizedDisplayName(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LuminaAuthError.invalidName }
        return trimmed
    }

    private func normalizedEmail(_ value: String) throws -> String {
        try Self.normalizeEmailValue(value)
    }

    private static func normalizeEmailValue(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@"), trimmed.contains("."), trimmed.count >= 5 else {
            throw LuminaAuthError.invalidEmail
        }
        return trimmed
    }

    private func normalizedPhone(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        guard digits.count >= 8 else { throw LuminaAuthError.invalidPhone }
        return trimmed.hasPrefix("+") ? "+\(digits)" : digits
    }

    private func validatePassword(_ value: String) throws {
        guard value.count >= 8 else { throw LuminaAuthError.weakPassword }
    }

    private static func passwordHash(password: String, salt: String) -> String {
        let data = Data("\(salt):\(password)".utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published private(set) var state = SubscriptionState()

    var hasPremiumAccess: Bool {
        state.hasPremiumAccess
    }

    func restore(_ persisted: PersistedSubscriptionState) {
        state = persisted.subscription
    }

    func snapshot() -> PersistedSubscriptionState {
        PersistedSubscriptionState(subscription: state)
    }

    func update(_ nextState: SubscriptionState) {
        state = nextState
    }

    func canUse(_ feature: PremiumFeature) -> Bool {
        switch feature {
        case .therapyChat:
            return true
        case .deepInsights, .liveCall, .advancedMemory, .gardenPremium:
            return hasPremiumAccess
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    // MARK: - Root stores

    let chatStore = ChatStore()
    let journalStore = JournalStore()
    let journalInsightStore = JournalInsightStore()
    let gardenStore = GardenStore()
    let followUpStore = FollowUpStore()
    let healthDataStore = HealthDataStore()
    let jitaiStore = JITAIStore()
    let notificationStore = NotificationStore()
    let evaluationStore = EvaluationStore()
    let profileStore = ProfileStore()
    let accountStore = AccountStore()
    let subscriptionStore = SubscriptionStore()
    let firebaseBackend = FirebaseBackendService()

    private let persistenceService = PersistenceService()
    private var cancellables: Set<AnyCancellable> = []
    private var saveTask: Task<Void, Never>?
    private var didStartLaunchServices = false
    private var cloudSessionSyncTasks: [String: Task<Void, Never>] = [:]

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        restorePersistedState()
        bindStoreChanges()
    }

    private func bindStoreChanges() {
        chatStore.objectWillChange
            .sink { [weak self] _ in self?.storeDidChange() }
            .store(in: &cancellables)
        journalStore.objectWillChange
            .sink { [weak self] _ in self?.storeDidChange() }
            .store(in: &cancellables)
        journalInsightStore.objectWillChange
            .sink { [weak self] _ in self?.storeDidChange() }
            .store(in: &cancellables)
        gardenStore.objectWillChange
            .sink { [weak self] _ in self?.storeDidChange() }
            .store(in: &cancellables)
        followUpStore.objectWillChange
            .sink { [weak self] _ in self?.storeDidChange() }
            .store(in: &cancellables)
        healthDataStore.objectWillChange
            .sink { [weak self] _ in self?.storeDidChange() }
            .store(in: &cancellables)
        jitaiStore.objectWillChange
            .sink { [weak self] _ in self?.storeDidChange() }
            .store(in: &cancellables)
        notificationStore.objectWillChange
            .sink { [weak self] _ in self?.storeDidChange() }
            .store(in: &cancellables)
        evaluationStore.objectWillChange
            .sink { [weak self] _ in self?.storeDidChange() }
            .store(in: &cancellables)
        profileStore.objectWillChange
            .sink { [weak self] _ in self?.storeDidChange() }
            .store(in: &cancellables)
        accountStore.objectWillChange
            .sink { [weak self] _ in self?.storeDidChange() }
            .store(in: &cancellables)
        subscriptionStore.objectWillChange
            .sink { [weak self] _ in self?.storeDidChange() }
            .store(in: &cancellables)
        firebaseBackend.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

    }

    func startPostLaunchServices() {
        guard !didStartLaunchServices else { return }
        didStartLaunchServices = true
        startFirebaseAuthListener()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self else { return }
            await self.refreshNotificationStateOnLaunch()
        }
    }

    private func storeDidChange() {
        objectWillChange.send()
        schedulePersistedStateSave()
    }

    private func restorePersistedState() {
        guard let state = persistenceService.load() else { return }
        chatStore.restore(state.chatSessions)
        journalStore.restore(state.journalEntries)
        journalInsightStore.restore(state.journalInsights)
        gardenStore.restore(state.garden)
        followUpStore.restore(state.followUps)
        healthDataStore.restore(state.health)
        jitaiStore.restore(state.jitai)
        notificationStore.restore(state.notifications)
        evaluationStore.restore(state.evaluation)
        profileStore.restore(state.profile)
        accountStore.restore(state.account)
        subscriptionStore.restore(state.subscription)
    }

    private func schedulePersistedStateSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled, let self else { return }
            self.savePersistedState()
        }
    }

    private func savePersistedState() {
        do {
            try persistenceService.save(snapshot())
        } catch {
            print("Lumia persistence save failed: \(error.localizedDescription)")
        }
    }

    private func refreshNotificationStateOnLaunch() async {
        await notificationStore.refreshPermissionState()
        if profileStore.dailyReminderEnabled {
            let didSchedule = await notificationStore.enableDailyReminder(hour: profileStore.dailyReminderHour)
            if !didSchedule {
                profileStore.dailyReminderEnabled = false
            }
        }
        if notificationStore.jitaiNotificationsEnabled {
            jitaiStore.refresh(
                entries: journalStore.entries,
                habits: gardenStore.habits,
                summaries: healthDataStore.summaries,
                baseline: healthDataStore.baseline,
                todayCheckIn: evaluationStore.todayCheckIn
            )
            await scheduleActiveJITAINotificationIfEligible()
        }
    }

    private func snapshot() -> LuminaPersistedState {
        LuminaPersistedState(
            chatSessions: chatStore.chatSessions,
            journalEntries: journalStore.entries,
            garden: gardenStore.snapshot(),
            followUps: followUpStore.followUps,
            health: healthDataStore.snapshot(),
            jitai: jitaiStore.snapshot(),
            notifications: notificationStore.snapshot(),
            evaluation: evaluationStore.snapshot(),
            profile: profileStore.snapshot(),
            account: accountStore.snapshot(),
            subscription: subscriptionStore.snapshot(),
            journalInsights: journalInsightStore.snapshot()
        )
    }

    // MARK: - Navigation

    @Published var selectedTab: Int = 0
    @Published var activeTherapist: Therapist = allTherapists[0]
    @Published private(set) var pendingTherapyTherapistID: String?

    func requestTherapy(with therapist: Therapist) {
        activeTherapist = therapist
        pendingTherapyTherapistID = therapist.id
        selectedTab = 2
    }

    func consumePendingTherapyRequest() {
        pendingTherapyTherapistID = nil
    }

    func handleNotificationNavigation(_ request: NotificationNavigationRequest) {
        var reasonCodes = ["notification.opened", "notification.\(request.notificationType)"]
        if let destinationTab = request.destinationTab {
            reasonCodes.append("destination.tab.\(destinationTab)")
        }

        if request.notificationType == "jitai",
           let decisionID = request.decisionID,
           jitaiStore.decisions.contains(where: { $0.id == decisionID }) {
            acceptJITAIDecision(id: decisionID)
        } else if let destinationTab = request.destinationTab, (0...4).contains(destinationTab) {
            selectedTab = destinationTab
        }

        evaluationStore.recordSafetyEvent(
            kind: .userControlAction,
            riskLevel: .none,
            reasonCodes: reasonCodes,
            sourceID: request.decisionID
        )
    }

    // MARK: - Chat Sessions

    var chatSessions: [String: ChatSession] {
        chatStore.chatSessions
    }

    func sessions(for therapist: Therapist) -> [ChatSession] {
        chatStore.sessions(for: therapist)
    }

    func session(for therapist: Therapist) -> ChatSession? {
        chatStore.session(for: therapist)
    }

    func saveSession(_ session: ChatSession, publish: ChatSessionPublishMode = .deferred) {
        chatStore.saveSession(session, publish: publish)
        syncTherapySessionToCloud(session)
    }

    func saveSessions(_ sessions: [ChatSession], publish: ChatSessionPublishMode = .deferred) {
        chatStore.saveSessions(sessions, publish: publish)
        sessions.forEach(syncTherapySessionToCloud)
    }

    func clearSession(for therapist: Therapist, publish: ChatSessionPublishMode = .deferred) {
        let sessionIDs = chatStore.sessions(for: therapist).map(\.id)
        chatStore.clearSession(for: therapist, publish: publish)
        deleteTherapySessionsFromCloud(ids: sessionIDs)
    }

    func deleteSession(id: String, publish: ChatSessionPublishMode = .deferred) {
        chatStore.deleteSession(id: id, publish: publish)
        deleteTherapySessionsFromCloud(ids: [id])
    }

    func archiveSession(id: String, publish: ChatSessionPublishMode = .deferred) {
        guard let session = chatStore.archiveSession(id: id, publish: publish) else { return }
        syncTherapySessionToCloud(session)
    }

    func clearAllChatSessions(publish: ChatSessionPublishMode = .deferred) {
        let sessionIDs = Array(chatStore.chatSessions.keys)
        chatStore.clearAllChatSessions(publish: publish)
        deleteTherapySessionsFromCloud(ids: sessionIDs)
        evaluationStore.recordSafetyEvent(
            kind: .userControlAction,
            riskLevel: .none,
            reasonCodes: ["control.clear_chat_history"]
        )
    }

    // MARK: - Journal Entries

    var entries: [JournalEntry] {
        get { journalStore.entries }
        set { journalStore.entries = newValue }
    }

    var averageSentiment: Int {
        journalStore.averageSentiment
    }

    func addEntry(_ entry: JournalEntry) {
        journalStore.addEntry(entry)
        refreshJITAI()
        syncTherapyContextToCloud(for: nil)
    }

    func updateEntry(_ entry: JournalEntry) {
        journalStore.updateEntry(entry)
        refreshJITAI()
        syncTherapyContextToCloud(for: nil)
    }

    func deleteEntry(id: String) {
        journalStore.deleteEntry(id: id)
        refreshJITAI()
        syncTherapyContextToCloud(for: nil)
    }

    func toggleEntryPin(id: String) {
        journalStore.togglePin(id: id)
        refreshJITAI()
        syncTherapyContextToCloud(for: nil)
    }

    func saveTherapySessionReflection(_ session: ChatSession, therapist: Therapist) {
        let meaningfulMessages = session.messages.filter { !$0.isThinking }
        guard meaningfulMessages.count >= 3 else { return }
        let id = "therapy-summary-\(session.id)"
        guard !journalStore.entries.contains(where: { $0.id == id }) else { return }

        let userMessages = meaningfulMessages.filter { $0.role == .user }.suffix(3).map(\.text)
        let modelMessages = meaningfulMessages.filter { $0.role == .model }.suffix(2).map(\.text)
        let content = """
        Therapy session with \(therapist.name).

        What I brought:
        \(userMessages.map { "- \($0)" }.joined(separator: "\n"))

        What felt useful:
        \(modelMessages.map { "- \($0)" }.joined(separator: "\n"))
        """
        let summary = "Saved from Therapy with \(therapist.name)."
        let entry = JournalEntry(
            id: id,
            date: Date(timeIntervalSince1970: session.lastUpdated).formatted(.dateTime.month(.abbreviated).day()),
            timestamp: session.lastUpdated,
            title: "Therapy with \(therapist.name)",
            content: content,
            mood: .neutral,
            tags: ["Therapy", therapist.name],
            reflection: summary,
            actionItem: nil,
            summary: summary,
            sentimentScore: nil,
            energyLevel: nil,
            anxietyLevel: nil,
            therapyMemoryPolicy: .included
        )
        journalStore.addEntry(entry)
        syncTherapyContextToCloud(for: therapist)
    }

    var dailyJournalInsights: DailyJournalInsights? {
        journalInsightStore.dailyInsight
    }

    func saveDailyJournalInsights(_ insights: DailyJournalInsights) {
        journalInsightStore.save(insights)
    }

    func clearDailyJournalInsights() {
        journalInsightStore.clear()
    }

    func journalInsightDateKey(for date: Date = Date()) -> String {
        Self.journalInsightDateFormatter.string(from: date)
    }

    func journalInsightEntryFingerprint() -> String {
        let source = journalStore.entries
            .sorted { $0.timestamp > $1.timestamp }
            .map { entry in
                "\(entry.id)|\(Int(entry.timestamp))|\(entry.title)|\(entry.content)|\(entry.mood.rawValue)"
            }
            .joined(separator: "\n")
        let digest = SHA256.hash(data: Data(source.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static let journalInsightDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Habits and Garden

    var habits: [Habit] {
        get { gardenStore.habits }
        set { gardenStore.habits = newValue }
    }

    var waterDrops: Int {
        get { gardenStore.waterDrops }
        set { gardenStore.waterDrops = newValue }
    }

    var gardenDecorations: [GardenDecoration] {
        get { gardenStore.gardenDecorations }
        set { gardenStore.gardenDecorations = newValue }
    }

    var claimedGardenQuestIDs: Set<String> {
        get { gardenStore.claimedGardenQuestIDs }
        set { gardenStore.claimedGardenQuestIDs = newValue }
    }

    var therapyMicroPlans: [MicroPlan] {
        get { gardenStore.therapyMicroPlans }
        set { gardenStore.therapyMicroPlans = newValue }
    }

    var gardenForageItems: [GardenForageItem] {
        get { gardenStore.forageItems }
        set { gardenStore.forageItems = newValue }
    }

    var gardenDailyEvents: [GardenDailyEvent] {
        get { gardenStore.dailyEvents }
        set { gardenStore.dailyEvents = newValue }
    }

    var gardenKeepsakes: [GardenKeepsake] {
        get { gardenStore.keepsakes }
        set { gardenStore.keepsakes = newValue }
    }

    var gardenUnlockedAreas: [GardenMapAreaUnlock] {
        get { gardenStore.unlockedAreas }
        set { gardenStore.unlockedAreas = newValue }
    }

    var gardenAreaVisits: [GardenMapAreaVisit] {
        get { gardenStore.areaVisits }
        set { gardenStore.areaVisits = newValue }
    }

    var gardenAreaMilestones: [GardenAreaMilestoneUnlock] {
        get { gardenStore.areaMilestones }
        set { gardenStore.areaMilestones = newValue }
    }

    var activeGardenDailyEvent: GardenDailyEvent? {
        gardenStore.activeDailyEvent()
    }

    func completeHabit(id: String) {
        let wasCompleted = gardenStore.habit(id: id)?.completedAt != nil
        gardenStore.completeHabit(id: id)
        if !wasCompleted,
           let microPlanID = gardenStore.habit(id: id)?.sourceMicroPlanID {
            followUpStore.record(microPlanID: microPlanID, status: .completed)
        }
        refreshJITAI()
    }

    func waterPlant(id: String) {
        gardenStore.waterPlant(id: id)
        refreshJITAI()
    }

    func canPlaceGardenDecoration(_ type: GardenDecorationType) -> Bool {
        gardenStore.canPlaceGardenDecoration(type)
    }

    @discardableResult
    func placeGardenDecoration(type: GardenDecorationType, anchorHabitID: String, x: Double, y: Double) -> Bool {
        gardenStore.placeGardenDecoration(type: type, anchorHabitID: anchorHabitID, x: x, y: y)
    }

    @discardableResult
    func claimGardenQuest(id: String, reward: Int) -> Bool {
        gardenStore.claimGardenQuest(id: id, reward: reward)
    }

    func refreshGardenForage(now: Date = Date()) {
        gardenStore.refreshDailyForage(now: now)
    }

    @discardableResult
    func claimGardenForageItem(id: String) -> GardenForageItem? {
        gardenStore.claimForageItem(id: id)
    }

    func refreshGardenDailyEvent(now: Date = Date()) {
        gardenStore.refreshDailyEvent(now: now)
    }

    @discardableResult
    func acceptGardenDailyEvent(id: String) -> GardenDailyEvent? {
        gardenStore.acceptDailyEvent(id: id)
    }

    @discardableResult
    func completeGardenDailyEvent(id: String, progress: Int) -> GardenDailyEvent? {
        gardenStore.completeDailyEvent(id: id, progress: progress)
    }

    @discardableResult
    func dismissGardenDailyEvent(id: String) -> GardenDailyEvent? {
        gardenStore.dismissDailyEvent(id: id)
    }

    @discardableResult
    func completeGardenMapAreaVisit(area: GardenMapAreaKind) -> GardenAreaActionResult? {
        gardenStore.completeMapAreaVisit(area: area)
    }

    @discardableResult
    func addTherapyMicroPlan(_ microPlan: MicroPlan) -> Habit? {
        guard let habit = gardenStore.addTherapyMicroPlan(microPlan) else { return nil }
        followUpStore.schedule(for: microPlan, habitID: habit.id)
        refreshJITAI()
        return habit
    }

    // MARK: - Follow-ups

    var followUps: [FollowUp] {
        get { followUpStore.followUps }
        set { followUpStore.followUps = newValue }
    }

    var activeFollowUp: FollowUp? {
        followUpStore.activeFollowUp
    }

    @discardableResult
    func scheduleFollowUp(for microPlan: MicroPlan, habitID: String?) -> FollowUp? {
        followUpStore.schedule(for: microPlan, habitID: habitID)
    }

    @discardableResult
    func recordFollowUp(id: String, status: FollowUpStatus) -> FollowUp? {
        guard let followUp = followUpStore.record(id: id, status: status) else { return nil }
        if status == .completed, let habitID = followUp.habitID {
            gardenStore.completeHabitIfNeeded(id: habitID, reward: 3)
        }
        evaluationStore.recordIntervention(
            source: .followUp,
            interventionKind: .wrapUp,
            policy: evaluationStore.therapyPolicy,
            reasonCodes: ["follow_up.\(status.rawValue)"],
            outcome: outcome(for: status),
            sessionID: followUp.sourceSessionID
        )
        refreshJITAI()
        return followUp
    }

    @discardableResult
    func snoozeFollowUp(id: String) -> FollowUp? {
        let followUp = followUpStore.snooze(id: id)
        if let followUp {
            evaluationStore.recordIntervention(
                source: .followUp,
                interventionKind: .wrapUp,
                policy: evaluationStore.therapyPolicy,
                reasonCodes: ["follow_up.snoozed"],
                outcome: .snoozed,
                sessionID: followUp.sourceSessionID
            )
        }
        refreshJITAI()
        return followUp
    }

    // MARK: - Health Context

    var healthPermissionState: HealthPermissionState {
        healthDataStore.permissionState
    }

    var healthSummaries: [DailyHealthSummary] {
        healthDataStore.summaries
    }

    var healthBaseline: HealthBaseline? {
        healthDataStore.baseline
    }

    var healthLastSyncAt: TimeInterval? {
        healthDataStore.lastSyncAt
    }

    var healthSyncError: String? {
        healthDataStore.lastError
    }

    var isHealthSyncing: Bool {
        healthDataStore.isSyncing
    }

    var hasAcknowledgedHealthDataUse: Bool {
        healthDataStore.hasAcknowledgedDataUse
    }

    func acknowledgeHealthDataUse() {
        healthDataStore.acknowledgeDataUse()
    }

    func requestHealthAuthorizationAndSync() async {
        await healthDataStore.requestAuthorizationAndSync()
        refreshJITAI()
    }

    func syncHealthSummaries() async {
        try? await healthDataStore.syncSummaries()
        refreshJITAI()
    }

    func deleteLocalHealthData() {
        healthDataStore.deleteLocalHealthData()
        evaluationStore.recordSafetyEvent(
            kind: .userControlAction,
            riskLevel: .none,
            reasonCodes: ["control.delete_local_health_context"]
        )
        refreshJITAI()
    }

    // MARK: - Wellbeing Context

    var wellbeingContext: WellbeingContextSnapshot {
        WellbeingContextEngine.make(
            entries: journalStore.entries,
            checkIns: evaluationStore.checkIns,
            habits: gardenStore.habits,
            followUps: followUpStore.followUps,
            summaries: healthDataStore.summaries,
            baseline: healthDataStore.baseline
        )
    }

    var therapyContextBrief: String? {
        therapyContextBrief(for: nil)
    }

    var therapyContextReasonCodes: [String] {
        therapyContextReasonCodes(for: nil)
    }

    func therapyContextBrief(for therapist: Therapist?) -> String? {
        let journalContext: String?
        guard profileStore.useJournalContextInTherapy else {
            let snapshot = WellbeingContextEngine.make(
                entries: [],
                checkIns: evaluationStore.checkIns,
                habits: gardenStore.habits,
                followUps: followUpStore.followUps,
                summaries: healthDataStore.summaries,
                baseline: healthDataStore.baseline
            )
            journalContext = snapshot.therapyPromptBrief
            if let therapist {
                return joinedTherapyContext(memoryBrief: therapistMemoryBrief(for: therapist), journalContext: journalContext)
            }
            return journalContext
        }
        journalContext = wellbeingContext(for: therapist).therapyPromptBrief
        if let therapist {
            return joinedTherapyContext(memoryBrief: therapistMemoryBrief(for: therapist), journalContext: journalContext)
        }
        return journalContext
    }

    func therapyContextBrief(for therapist: Therapist, excluding sessionID: String?) -> String? {
        let journalContext = profileStore.useJournalContextInTherapy
            ? wellbeingContext(for: therapist).therapyPromptBrief
            : WellbeingContextEngine.make(
                entries: [],
                checkIns: evaluationStore.checkIns,
                habits: gardenStore.habits,
                followUps: followUpStore.followUps,
                summaries: healthDataStore.summaries,
                baseline: healthDataStore.baseline
            ).therapyPromptBrief
        return joinedTherapyContext(
            memoryBrief: therapistMemoryBrief(for: therapist, excluding: sessionID),
            journalContext: journalContext
        )
    }

    private func joinedTherapyContext(memoryBrief: String?, journalContext: String?) -> String? {
        let parts = [memoryBrief, journalContext]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }

    func therapistMemoryBrief(for therapist: Therapist, excluding sessionID: String? = nil) -> String? {
        let priorSessions = chatStore.sessions(for: therapist)
            .filter { $0.id != sessionID && $0.messageCount >= 3 }
            .prefix(3)
        guard !priorSessions.isEmpty else { return nil }

        var lines = [
            "Continuity memory for \(therapist.name):",
            "- You are the same \(therapist.name) the user spoke with before. Maintain your own voice and role; do not present yourself as generic Lumia."
        ]

        for session in priorSessions {
            let userTexts = session.messages
                .filter { $0.role == .user && !$0.isThinking }
                .suffix(2)
                .map { Self.compactTherapyMemoryText($0.text, limit: 130) }
            let modelTexts = session.messages
                .filter { $0.role == .model && !$0.isThinking }
                .suffix(1)
                .map { Self.compactTherapyMemoryText($0.text, limit: 130) }
            let date = Date(timeIntervalSince1970: session.lastUpdated).formatted(.dateTime.month(.abbreviated).day())
            if !userTexts.isEmpty {
                lines.append("- \(date), user brought: \(userTexts.joined(separator: " / "))")
            }
            if let lastGuidance = modelTexts.first, !lastGuidance.isEmpty {
                lines.append("- \(therapist.name) last offered: \(lastGuidance)")
            }
        }

        lines.append("- Use this memory lightly. Mention prior work only when it helps, and let the user correct it.")
        return lines.joined(separator: "\n")
    }

    func hasTherapistMemory(for therapist: Therapist, excluding sessionID: String? = nil) -> Bool {
        chatStore.sessions(for: therapist)
            .contains { $0.id != sessionID && $0.messageCount >= 3 }
    }

    private static func compactTherapyMemoryText(_ text: String, limit: Int) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > limit else { return compact }
        let end = compact.index(compact.startIndex, offsetBy: max(0, limit - 1))
        return String(compact[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    func therapyContextReasonCodes(for therapist: Therapist?) -> [String] {
        guard profileStore.useJournalContextInTherapy else {
            return wellbeingContext.therapyReasonCodes.filter { !$0.hasPrefix("journal.") }
        }
        return wellbeingContext(for: therapist).therapyReasonCodes
    }

    func wellbeingContext(for therapist: Therapist?) -> WellbeingContextSnapshot {
        WellbeingContextEngine.make(
            entries: profileStore.useJournalContextInTherapy ? journalStore.entries : [],
            checkIns: evaluationStore.checkIns,
            habits: gardenStore.habits,
            followUps: followUpStore.followUps,
            summaries: healthDataStore.summaries,
            baseline: healthDataStore.baseline,
            therapistID: therapist?.id
        )
    }

    func isUsingJournalContext(for therapist: Therapist) -> Bool {
        guard profileStore.useJournalContextInTherapy else { return false }
        return wellbeingContext(for: therapist).journalBridge?.isEmpty == false
    }

    func personalizedTherapyOpening(for therapist: Therapist) -> String? {
        if let memory = therapistMemoryBrief(for: therapist),
           let previousFocus = memory
            .components(separatedBy: "\n")
            .first(where: { $0.contains("user brought:") })?
            .replacingOccurrences(of: #"^- [A-Za-z]{3} \d{1,2}, user brought: "#, with: "", options: .regularExpression) {
            let focus = Self.compactTherapyMemoryText(previousFocus, limit: 96)
            return """
            \(therapist.greeting)

            Welcome back. I remember we were near \(focus). We can continue there, or start with what feels most present today.
            """
        }

        guard profileStore.useJournalContextInTherapy,
              let bridge = wellbeingContext(for: therapist).journalBridge,
              !bridge.isEmpty else { return nil }

        let theme = safeJournalTheme(bridge.recurringThemes.first, for: therapist)
        let base: String
        switch therapist.id {
        case "willow":
            base = theme.map { "The recent notes seem to circle around \($0). We can turn that into one small, workable step, or start somewhere else." } ?? "We can look for one clear next step, or begin fresh."
        case "serena":
            base = theme.map { "The recent notes suggest \($0) may be carrying some weight. We can stay with the feeling gently, or start anywhere you like." } ?? "We can begin with what you feel right now."
        case "eden":
            base = theme.map { "The recent notes point toward \($0). If it fits, we can look at the relationship side gently, or choose a different place to begin." } ?? "We can look at connection patterns, or begin fresh."
        case "nimbus":
            base = theme.map { "The recent notes suggest \($0) may be present. We can start with grounding first, or talk through what is here." } ?? "We can keep this low-pressure, or simply start with your breath."
        default:
            base = theme.map { "The recent notes mention \($0). We can start there if useful, or begin somewhere else." } ?? "We can start fresh."
        }

        return "\(therapist.greeting)\n\n\(base)"
    }

    private func safeJournalTheme(_ theme: String?, for therapist: Therapist) -> String? {
        guard let theme = theme?.trimmingCharacters(in: .whitespacesAndNewlines),
              !theme.isEmpty else { return nil }
        let normalized = theme.lowercased()
        let blocked = [
            therapist.id.lowercased(),
            therapist.name.lowercased(),
            therapist.name.replacingOccurrences(of: "Dr. ", with: "").lowercased(),
            "dr willow",
            "doctor",
            "therapy",
            "therapist"
        ]
        guard !blocked.contains(where: { !$0.isEmpty && normalized.contains($0) }) else {
            return nil
        }
        return theme
    }

    var useJournalContextInTherapy: Bool {
        get { profileStore.useJournalContextInTherapy }
        set {
            guard profileStore.useJournalContextInTherapy != newValue else { return }
            profileStore.useJournalContextInTherapy = newValue
            evaluationStore.recordSafetyEvent(
                kind: .userControlAction,
                riskLevel: .none,
                reasonCodes: [newValue ? "control.enable_journal_context_therapy" : "control.disable_journal_context_therapy"]
            )
            syncTherapyContextToCloud(for: nil)
        }
    }

    // MARK: - JITAI

    var activeJITAIDecision: JITAIDecision? {
        jitaiStore.activeDecision
    }

    var jitaiLogs: [JITAIInteractionLog] {
        jitaiStore.logs
    }

    func refreshJITAI() {
        jitaiStore.refresh(
            entries: journalStore.entries,
            habits: gardenStore.habits,
            summaries: healthDataStore.summaries,
            baseline: healthDataStore.baseline,
            todayCheckIn: evaluationStore.todayCheckIn
        )
        notificationStore.reconcileJITAISchedules(activeDecisionID: jitaiStore.activeDecision?.id)
        guard notificationStore.jitaiNotificationsEnabled else { return }
        Task { @MainActor [weak self] in
            await self?.scheduleActiveJITAINotificationIfEligible()
        }
    }

    func acceptJITAIDecision(id: String) {
        guard let decision = jitaiStore.recordResponse(decisionID: id, response: .accepted) else { return }
        notificationStore.cancelJITAINotification(decisionID: id)
        recordJITAIIntervention(decision, outcome: .accepted)
        selectedTab = decision.destinationTab
    }

    func dismissJITAIDecision(id: String) {
        guard let decision = jitaiStore.recordResponse(decisionID: id, response: .dismissed) else { return }
        notificationStore.cancelJITAINotification(decisionID: id)
        recordJITAIIntervention(decision, outcome: .dismissed)
        evaluationStore.recordSafetyEvent(
            kind: .userControlAction,
            riskLevel: .none,
            reasonCodes: ["control.dismiss_jitai_prompt"]
        )
    }

    func suppressJITAIToday(id: String) {
        guard let decision = jitaiStore.recordResponse(decisionID: id, response: .suppressed) else { return }
        notificationStore.cancelJITAINotification(decisionID: id)
        recordJITAIIntervention(decision, outcome: .suppressed)
        evaluationStore.recordSafetyEvent(
            kind: .userControlAction,
            riskLevel: .none,
            reasonCodes: ["control.quiet_jitai_today"]
        )
    }

    private func scheduleActiveJITAINotificationIfEligible() async {
        guard let decision = jitaiStore.activeDecision else { return }
        let didSchedule = await notificationStore.scheduleJITAIDecisionIfNeeded(decision)
        guard didSchedule else { return }
        evaluationStore.recordIntervention(
            source: .jitai,
            interventionKind: interventionKind(for: decision.kind),
            policy: evaluationStore.jitaiPolicy,
            reasonCodes: decision.reasonCodes + ["notification.jitai.scheduled"],
            confidence: decision.confidence,
            outcome: .shown,
            sessionID: decision.sourceID
        )
    }

    private func recordJITAIIntervention(_ decision: JITAIDecision, outcome: InterventionOutcome) {
        evaluationStore.recordIntervention(
            source: .jitai,
            interventionKind: interventionKind(for: decision.kind),
            policy: evaluationStore.jitaiPolicy,
            reasonCodes: decision.reasonCodes,
            confidence: decision.confidence,
            outcome: outcome,
            sessionID: decision.sourceID
        )
    }

    private func interventionKind(for kind: JITAIPromptKind) -> InterventionKind? {
        switch kind {
        case .recovery:
            return .breathing
        case .movement, .garden:
            return .ifThenPlan
        case .reflection:
            return .journalingPrompt
        case .grounding:
            return .grounding
        }
    }

    private func outcome(for status: FollowUpStatus) -> InterventionOutcome {
        switch status {
        case .pending:
            return .shown
        case .completed:
            return .completed
        case .skipped:
            return .dismissed
        case .tooHard:
            return .tooHard
        }
    }

    // MARK: - Evaluation and Governance

    var interventionLogs: [InterventionLog] {
        evaluationStore.interventionLogs
    }

    var checkIns: [CheckInMetric] {
        evaluationStore.checkIns
    }

    var safetyEvents: [SafetyEvent] {
        evaluationStore.safetyEvents
    }

    var todayCheckIn: CheckInMetric? {
        evaluationStore.todayCheckIn
    }

    var activePromptPolicyLabel: String {
        evaluationStore.therapyPolicy.displayName
    }

    var crisisRouteCount: Int {
        evaluationStore.crisisRouteCount
    }

    var falsePositiveSafetyCount: Int {
        evaluationStore.falsePositiveCount
    }

    var userControlActionCount: Int {
        evaluationStore.userControlActionCount
    }

    var canFlagLatestSafetyRoute: Bool {
        evaluationStore.canFlagLatestSafetyRoute
    }

    func recordDailyCheckIn(moodScore: Int, stressScore: Int, note: String?) {
        evaluationStore.recordCheckIn(moodScore: moodScore, stressScore: stressScore, note: note)
        refreshJITAI()
    }

    func recordSanctuaryIntervention(
        kind: InterventionKind,
        outcome: InterventionOutcome,
        reasonCodes: [String],
        riskLevel: RiskLevel = .none
    ) {
        evaluationStore.recordIntervention(
            source: .sanctuary,
            interventionKind: kind,
            policy: evaluationStore.therapyPolicy,
            reasonCodes: reasonCodes,
            outcome: outcome,
            riskLevel: riskLevel
        )
    }

    func flagLatestSafetyRouteFalsePositive() {
        _ = evaluationStore.flagLatestSafetyRouteFalsePositive()
    }

    func recordTherapyTurnEvaluation(sessionID: String?, therapistID: String, metadata: ConversationTurnMetadata) {
        evaluationStore.recordIntervention(
            source: .therapy,
            interventionKind: metadata.suggestedIntervention,
            policy: evaluationStore.therapyPolicy,
            reasonCodes: metadata.reasonCodes + ["therapist.\(therapistID)", "state.\(metadata.stateAfter.rawValue)"],
            outcome: metadata.riskLevel >= .high ? .crisisRouted : .shown,
            riskLevel: metadata.riskLevel,
            sessionID: sessionID
        )

        if metadata.riskLevel >= .high {
            evaluationStore.recordSafetyEvent(
                kind: .crisisRoute,
                riskLevel: metadata.riskLevel,
                reasonCodes: metadata.reasonCodes,
                sourceID: metadata.id
            )
        } else if metadata.riskLevel >= .medium {
            evaluationStore.recordSafetyEvent(
                kind: .mediumRiskTriage,
                riskLevel: metadata.riskLevel,
                reasonCodes: metadata.reasonCodes,
                sourceID: metadata.id
            )
        }
    }

    // MARK: - User Profile and Settings

    var userName: String {
        get { profileStore.userName }
        set { profileStore.userName = newValue }
    }

    var userBio: String {
        get { profileStore.userBio }
        set { profileStore.userBio = newValue }
    }

    var joinDate: Date {
        get { profileStore.joinDate }
        set { profileStore.joinDate = newValue }
    }

    var dailyReminderEnabled: Bool {
        get { profileStore.dailyReminderEnabled }
        set { setDailyReminderEnabled(newValue) }
    }

    var dailyReminderHour: Int {
        get { profileStore.dailyReminderHour }
        set {
            profileStore.dailyReminderHour = min(max(newValue, 0), 23)
            guard profileStore.dailyReminderEnabled else { return }
            Task { @MainActor [weak self] in
                await self?.rescheduleDailyReminder()
            }
        }
    }

    var notificationPermissionState: NotificationPermissionState {
        notificationStore.permissionState
    }

    var notificationLastScheduledAt: TimeInterval? {
        notificationStore.lastScheduledAt
    }

    var jitaiNotificationsEnabled: Bool {
        get { notificationStore.jitaiNotificationsEnabled }
        set { setJITAINotificationsEnabled(newValue) }
    }

    var jitaiNotificationLastScheduledAt: TimeInterval? {
        notificationStore.jitaiLastScheduledAt
    }

    var jitaiMaxDailyPrompts: Int {
        get { jitaiStore.maxDailyPrompts }
        set { setJITAIMaxDailyPrompts(newValue) }
    }

    var jitaiQuietHoursStart: Int {
        get { jitaiStore.quietHoursStart }
        set { setJITAIQuietHoursStart(newValue) }
    }

    var jitaiQuietHoursEnd: Int {
        get { jitaiStore.quietHoursEnd }
        set { setJITAIQuietHoursEnd(newValue) }
    }

    var jitaiQuietHoursLabel: String {
        "\(Self.hourLabel(jitaiStore.quietHoursStart))-\(Self.hourLabel(jitaiStore.quietHoursEnd))"
    }

    var notificationError: String? {
        notificationStore.lastError
    }

    var notificationPermissionLabel: String {
        switch notificationStore.permissionState {
        case .notDetermined:
            return "Not requested"
        case .authorized:
            return "Allowed"
        case .denied:
            return "Blocked"
        case .provisional:
            return "Quietly allowed"
        case .ephemeral:
            return "Temporary"
        case .unknown:
            return "Unknown"
        }
    }

    func refreshNotificationPermissionState() async {
        await notificationStore.refreshPermissionState()
    }

    private func setDailyReminderEnabled(_ enabled: Bool) {
        profileStore.dailyReminderEnabled = enabled
        evaluationStore.recordSafetyEvent(
            kind: .userControlAction,
            riskLevel: .none,
            reasonCodes: [enabled ? "control.enable_daily_reminder" : "control.disable_daily_reminder"]
        )

        if enabled {
            Task { @MainActor [weak self] in
                await self?.rescheduleDailyReminder()
            }
        } else {
            notificationStore.disableDailyReminder()
        }
    }

    private func rescheduleDailyReminder() async {
        let didSchedule = await notificationStore.enableDailyReminder(hour: profileStore.dailyReminderHour)
        if !didSchedule {
            profileStore.dailyReminderEnabled = false
        }
    }

    private func setJITAINotificationsEnabled(_ enabled: Bool) {
        evaluationStore.recordSafetyEvent(
            kind: .userControlAction,
            riskLevel: .none,
            reasonCodes: [enabled ? "control.enable_jitai_notifications" : "control.disable_jitai_notifications"]
        )

        if enabled {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let didEnable = await self.notificationStore.enableJITAINotifications()
                guard didEnable else { return }
                self.jitaiStore.refresh(
                    entries: self.journalStore.entries,
                    habits: self.gardenStore.habits,
                    summaries: self.healthDataStore.summaries,
                    baseline: self.healthDataStore.baseline,
                    todayCheckIn: self.evaluationStore.todayCheckIn
                )
                await self.scheduleActiveJITAINotificationIfEligible()
            }
        } else {
            notificationStore.disableJITAINotifications()
        }
    }

    private func setJITAIMaxDailyPrompts(_ value: Int) {
        guard value != jitaiStore.maxDailyPrompts else { return }
        jitaiStore.setMaxDailyPrompts(value)
        evaluationStore.recordSafetyEvent(
            kind: .userControlAction,
            riskLevel: .none,
            reasonCodes: ["control.jitai_daily_cap.\(jitaiStore.maxDailyPrompts)"]
        )
        refreshJITAI()
    }

    private func setJITAIQuietHoursStart(_ value: Int) {
        guard value != jitaiStore.quietHoursStart else { return }
        jitaiStore.setQuietHoursStart(value)
        evaluationStore.recordSafetyEvent(
            kind: .userControlAction,
            riskLevel: .none,
            reasonCodes: ["control.jitai_quiet_start.\(jitaiStore.quietHoursStart)"]
        )
        refreshJITAI()
    }

    private func setJITAIQuietHoursEnd(_ value: Int) {
        guard value != jitaiStore.quietHoursEnd else { return }
        jitaiStore.setQuietHoursEnd(value)
        evaluationStore.recordSafetyEvent(
            kind: .userControlAction,
            riskLevel: .none,
            reasonCodes: ["control.jitai_quiet_end.\(jitaiStore.quietHoursEnd)"]
        )
        refreshJITAI()
    }

    private static func hourLabel(_ hour: Int) -> String {
        String(format: "%02d:00", min(max(hour, 0), 23))
    }

    var hapticFeedbackEnabled: Bool {
        get { profileStore.hapticFeedbackEnabled }
        set { profileStore.hapticFeedbackEnabled = newValue }
    }

    var useLargeText: Bool {
        get { profileStore.useLargeText }
        set {
            guard profileStore.useLargeText != newValue else { return }
            profileStore.useLargeText = newValue
        }
    }

    var requireBiometrics: Bool {
        get { profileStore.requireBiometrics }
        set { profileStore.requireBiometrics = newValue }
    }

    var journalGoalPerWeek: Int {
        get { profileStore.journalGoalPerWeek }
        set { profileStore.journalGoalPerWeek = newValue }
    }

    var meditationGoalMinutes: Int {
        get { profileStore.meditationGoalMinutes }
        set { profileStore.meditationGoalMinutes = newValue }
    }

    var currentAccount: LuminaAccount? {
        accountStore.currentAccount
    }

    var isSignedIn: Bool {
        accountStore.currentAccount != nil
    }

    @discardableResult
    func registerAccountWithEmail(displayName: String, email: String, password: String, confirmPassword: String) async throws -> LuminaAccount {
        guard password == confirmPassword else { throw LuminaAuthError.passwordMismatch }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw LuminaAuthError.invalidName }
        let user = try await firebaseBackend.registerEmail(displayName: name, email: email, password: password)
        let account = try accountStore.signInRemoteAccount(
            provider: .email,
            providerUserID: user.uid,
            displayName: name,
            email: user.email ?? email,
            phone: user.phoneNumber
        )
        applyAccountProfile(account)
        return account
    }

    @discardableResult
    func signInWithEmail(email: String, password: String) async throws -> LuminaAccount {
        let user = try await firebaseBackend.signInEmail(email: email, password: password)
        let account = try accountStore.signInRemoteAccount(
            provider: .email,
            providerUserID: user.uid,
            displayName: user.displayName,
            email: user.email ?? email,
            phone: user.phoneNumber
        )
        applyAccountProfile(account)
        return account
    }

    @discardableResult
    func registerAccountWithPhone(displayName: String, phone: String, password: String, confirmPassword: String) throws -> LuminaAccount {
        guard password == confirmPassword else { throw LuminaAuthError.passwordMismatch }
        let account = try accountStore.registerPhone(displayName: displayName, phone: phone, password: password)
        applyAccountProfile(account)
        return account
    }

    @discardableResult
    func signInWithPhone(phone: String, password: String) throws -> LuminaAccount {
        let account = try accountStore.signInPhone(phone: phone, password: password)
        applyAccountProfile(account)
        return account
    }

    @discardableResult
    func signInWithApple(providerUserID: String, displayName: String?, email: String?) throws -> LuminaAccount {
        let account = try accountStore.signInFederated(
            provider: .apple,
            providerUserID: providerUserID,
            displayName: displayName,
            email: email
        )
        applyAccountProfile(account)
        return account
    }

    @discardableResult
    func signInWithGoogle() async throws -> LuminaAccount {
        let user = try await firebaseBackend.signInGoogle()
        let account = try accountStore.signInRemoteAccount(
            provider: .google,
            providerUserID: user.uid,
            displayName: user.displayName,
            email: user.email,
            phone: user.phoneNumber
        )
        applyAccountProfile(account)
        return account
    }

    func signOutAccount() {
        try? firebaseBackend.signOut()
        accountStore.signOut()
    }

    private func startFirebaseAuthListener() {
        firebaseBackend.startAuthListener { [weak self] user in
            guard let self, let user else { return }
            do {
                let account = try self.accountStore.signInRemoteAccount(
                    provider: self.accountProvider(for: user),
                    providerUserID: user.uid,
                    displayName: user.displayName,
                    email: user.email,
                    phone: user.phoneNumber
                )
                self.applyAccountProfile(account)
                self.restoreTherapySessionsFromCloud()
                self.refreshSubscriptionFromCloud()
            } catch {
                print("Lumia Firebase auth sync failed: \(error.localizedDescription)")
            }
        }
    }

    func refreshSubscriptionFromCloud() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let subscription = try await self.firebaseBackend.fetchSubscriptionState()
                self.subscriptionStore.update(subscription)
            } catch {
                print("Lumia subscription fetch failed: \(error.localizedDescription)")
            }
        }
    }

    func applyLocalSubscriptionOverride(_ state: SubscriptionState) {
        subscriptionStore.update(state)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.firebaseBackend.saveSubscriptionState(state)
            } catch {
                print("Lumia subscription sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func restoreTherapySessionsFromCloud() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let remoteSessions = try await self.firebaseBackend.fetchTherapySessions()
                guard !remoteSessions.isEmpty else { return }
                self.chatStore.saveSessions(remoteSessions, publish: .deferred)
            } catch {
                print("Lumia therapy cloud fetch failed: \(error.localizedDescription)")
            }
        }
    }

    private func syncTherapySessionToCloud(_ session: ChatSession) {
        cloudSessionSyncTasks[session.id]?.cancel()
        cloudSessionSyncTasks[session.id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, let self else { return }
            do {
                try await self.firebaseBackend.saveTherapySession(session)
            } catch {
                print("Lumia therapy cloud sync failed: \(error.localizedDescription)")
            }
            self.cloudSessionSyncTasks[session.id] = nil
        }
    }

    func syncTherapyContextToCloud(for therapist: Therapist?) {
        let snapshot = wellbeingContext(for: therapist)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.firebaseBackend.saveTherapyContext(snapshot, therapistID: therapist?.id)
            } catch {
                print("Lumia therapy context cloud sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteTherapySessionsFromCloud(ids: [String]) {
        guard !ids.isEmpty else { return }
        ids.forEach { cloudSessionSyncTasks[$0]?.cancel() }
        Task { @MainActor [weak self] in
            guard let self else { return }
            for id in ids {
                do {
                    try await self.firebaseBackend.deleteTherapySession(id: id)
                } catch {
                    print("Lumia therapy cloud delete failed: \(error.localizedDescription)")
                }
                self.cloudSessionSyncTasks[id] = nil
            }
        }
    }

    private func accountProvider(for user: FirebaseAuth.User) -> LuminaAccountProvider {
        let providerIDs = Set(user.providerData.map(\.providerID))
        if providerIDs.contains("apple.com") { return .apple }
        if providerIDs.contains("google.com") { return .google }
        if providerIDs.contains("phone") { return .phone }
        return .email
    }

    private func applyAccountProfile(_ account: LuminaAccount) {
        let currentName = profileStore.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentName.isEmpty || currentName == "User" {
            profileStore.userName = account.displayName
        }
    }

    var subscriptionState: SubscriptionState {
        subscriptionStore.state
    }

    var hasPremiumAccess: Bool {
        subscriptionStore.hasPremiumAccess
    }

    func canUse(_ feature: PremiumFeature) -> Bool {
        subscriptionStore.canUse(feature)
    }
}
