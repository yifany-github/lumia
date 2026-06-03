import Foundation
import Combine
import CryptoKit
import Network
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
    var keptGardenPromptIDs: Set<String> = []
    var therapyMicroPlans: [MicroPlan] = []
    var forageItems: [GardenForageItem] = []
    var visitorInvitations: [GardenVisitorInvitation] = []
    var keepsakes: [GardenKeepsake] = []
    var unlockedAreas: [GardenMapAreaUnlock] = []
    var areaVisits: [GardenMapAreaVisit] = []
    var areaMilestones: [GardenAreaMilestoneUnlock] = []

    enum CodingKeys: String, CodingKey {
        case habits
        case waterDrops
        case gardenDecorations
        case keptGardenPromptIDs
        case claimedGardenQuestIDs
        case therapyMicroPlans
        case forageItems
        case visitorInvitations
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
        keptGardenPromptIDs: Set<String> = [],
        therapyMicroPlans: [MicroPlan] = [],
        forageItems: [GardenForageItem] = [],
        visitorInvitations: [GardenVisitorInvitation] = [],
        keepsakes: [GardenKeepsake] = [],
        unlockedAreas: [GardenMapAreaUnlock] = [],
        areaVisits: [GardenMapAreaVisit] = [],
        areaMilestones: [GardenAreaMilestoneUnlock] = []
    ) {
        self.habits = habits
        self.waterDrops = waterDrops
        self.gardenDecorations = gardenDecorations
        self.keptGardenPromptIDs = keptGardenPromptIDs
        self.therapyMicroPlans = therapyMicroPlans
        self.forageItems = forageItems
        self.visitorInvitations = visitorInvitations
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
        keptGardenPromptIDs = try container.decodeIfPresent(Set<String>.self, forKey: .keptGardenPromptIDs)
            ?? container.decodeIfPresent(Set<String>.self, forKey: .claimedGardenQuestIDs)
            ?? []
        therapyMicroPlans = try container.decodeIfPresent([MicroPlan].self, forKey: .therapyMicroPlans) ?? []
        forageItems = try container.decodeIfPresent([GardenForageItem].self, forKey: .forageItems) ?? []
        visitorInvitations = try container.decodeIfPresent([GardenVisitorInvitation].self, forKey: .visitorInvitations)
            ?? container.decodeIfPresent([GardenVisitorInvitation].self, forKey: .dailyEvents)
            ?? []
        keepsakes = try container.decodeIfPresent([GardenKeepsake].self, forKey: .keepsakes) ?? []
        unlockedAreas = try container.decodeIfPresent([GardenMapAreaUnlock].self, forKey: .unlockedAreas) ?? []
        areaVisits = try container.decodeIfPresent([GardenMapAreaVisit].self, forKey: .areaVisits) ?? []
        areaMilestones = try container.decodeIfPresent([GardenAreaMilestoneUnlock].self, forKey: .areaMilestones) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(habits, forKey: .habits)
        try container.encode(waterDrops, forKey: .waterDrops)
        try container.encode(gardenDecorations, forKey: .gardenDecorations)
        try container.encode(keptGardenPromptIDs, forKey: .keptGardenPromptIDs)
        try container.encode(therapyMicroPlans, forKey: .therapyMicroPlans)
        try container.encode(forageItems, forKey: .forageItems)
        try container.encode(visitorInvitations, forKey: .visitorInvitations)
        try container.encode(keepsakes, forKey: .keepsakes)
        try container.encode(unlockedAreas, forKey: .unlockedAreas)
        try container.encode(areaVisits, forKey: .areaVisits)
        try container.encode(areaMilestones, forKey: .areaMilestones)
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

struct SubscriptionUsageState: Codable, Equatable {
    static let freeAIChatDailyLimit = 20
    static let freeVoiceDailyLimitSeconds = 5 * 60
    static let premiumVoiceMonthlyLimitSeconds = 300 * 60

    var dailyKey: String = Self.dayKey()
    var monthlyKey: String = Self.monthKey()
    var aiChatRepliesToday: Int = 0
    var liveCallSecondsToday: Int = 0
    var liveCallSecondsThisMonth: Int = 0

    mutating func normalize(now: Date = Date()) {
        let currentDay = Self.dayKey(for: now)
        if dailyKey != currentDay {
            dailyKey = currentDay
            aiChatRepliesToday = 0
            liveCallSecondsToday = 0
        }

        let currentMonth = Self.monthKey(for: now)
        if monthlyKey != currentMonth {
            monthlyKey = currentMonth
            liveCallSecondsThisMonth = 0
        }
    }

    mutating func recordAIChatReply() {
        normalize()
        aiChatRepliesToday += 1
    }

    mutating func recordLiveCall(seconds: Int) {
        normalize()
        let clamped = max(0, seconds)
        liveCallSecondsToday += clamped
        liveCallSecondsThisMonth += clamped
    }

    static func dayKey(for date: Date = Date()) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    static func monthKey(for date: Date = Date()) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }
}

struct SubscriptionAllowance: Equatable {
    let hasPremiumAccess: Bool
    let aiChatRepliesToday: Int
    let liveCallSecondsToday: Int
    let liveCallSecondsThisMonth: Int

    var aiChatDailyLimit: Int? {
        hasPremiumAccess ? nil : SubscriptionUsageState.freeAIChatDailyLimit
    }

    var voiceLimitSeconds: Int {
        hasPremiumAccess
            ? SubscriptionUsageState.premiumVoiceMonthlyLimitSeconds
            : SubscriptionUsageState.freeVoiceDailyLimitSeconds
    }

    var voiceUsedSeconds: Int {
        hasPremiumAccess ? liveCallSecondsThisMonth : liveCallSecondsToday
    }

    var aiChatRemainingToday: Int? {
        guard let aiChatDailyLimit else { return nil }
        return max(0, aiChatDailyLimit - aiChatRepliesToday)
    }

    var voiceRemainingSeconds: Int {
        max(0, voiceLimitSeconds - voiceUsedSeconds)
    }

    var canUseAIChat: Bool {
        aiChatRemainingToday.map { $0 > 0 } ?? true
    }

    var canStartLiveCall: Bool {
        voiceRemainingSeconds > 0
    }

    var aiUsageText: String {
        if let aiChatDailyLimit {
            return "\(aiChatRemainingToday ?? 0)/\(aiChatDailyLimit) replies left today"
        }
        return "Expanded replies"
    }

    var voiceUsageText: String {
        "\(Self.minutesText(voiceRemainingSeconds)) left"
    }

    var voiceLimitText: String {
        hasPremiumAccess ? "300 min/month" : "5 min/day"
    }

    var headline: String {
        hasPremiumAccess ? "Plus continuity is on" : "Free plan today"
    }

    var detail: String {
        hasPremiumAccess
            ? "Voice time: \(voiceUsageText). Memory and deeper insights are available."
            : "\(aiUsageText). Voice preview: \(voiceUsageText)."
    }

    private static func minutesText(_ seconds: Int) -> String {
        let minutes = Int(ceil(Double(max(0, seconds)) / 60.0))
        return "\(minutes) min"
    }
}

struct PersistedSubscriptionState: Codable {
    var subscription: SubscriptionState = SubscriptionState()
    var usage: SubscriptionUsageState = SubscriptionUsageState()

    enum CodingKeys: String, CodingKey {
        case subscription
        case usage
    }

    init(
        subscription: SubscriptionState = SubscriptionState(),
        usage: SubscriptionUsageState = SubscriptionUsageState()
    ) {
        self.subscription = subscription
        self.usage = usage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subscription = try container.decodeIfPresent(SubscriptionState.self, forKey: .subscription) ?? SubscriptionState()
        usage = try container.decodeIfPresent(SubscriptionUsageState.self, forKey: .usage) ?? SubscriptionUsageState()
    }
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

enum ProfileAvatarID: String, CaseIterable, Codable, Identifiable {
    case cat
    case rabbit
    case dog
    case hamster

    var id: String { rawValue }

    static func fromPersistedValue(_ value: String?) -> ProfileAvatarID {
        guard let value, let avatar = ProfileAvatarID(rawValue: value) else {
            return .cat
        }
        return avatar
    }

    var title: String {
        switch self {
        case .cat: return "Cat"
        case .rabbit: return "Rabbit"
        case .dog: return "Dog"
        case .hamster: return "Hamster"
        }
    }

    var assetName: String {
        switch self {
        case .cat: return "ProfileAvatarCat"
        case .rabbit: return "ProfileAvatarRabbit"
        case .dog: return "ProfileAvatarDog"
        case .hamster: return "ProfileAvatarHamster"
        }
    }
}

enum ProfileGender: String, CaseIterable, Codable, Identifiable {
    case notSpecified
    case woman
    case man
    case nonBinary
    case preferNotToSay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notSpecified: return "Not specified"
        case .woman: return "Woman"
        case .man: return "Man"
        case .nonBinary: return "Non-binary"
        case .preferNotToSay: return "Prefer not to say"
        }
    }

    var profileDetail: String {
        switch self {
        case .notSpecified: return "Not set"
        case .woman, .man, .nonBinary, .preferNotToSay: return title
        }
    }
}

struct PersistedProfileState: Codable {
    var userName: String = "User"
    var userBio: String = ""
    var avatarID: ProfileAvatarID = .cat
    var gender: ProfileGender = .notSpecified
    var joinDate: Date = Date()
    var dailyReminderEnabled: Bool = false
    var dailyReminderHour: Int = 9
    var hapticFeedbackEnabled: Bool = true
    var useLargeText: Bool = false
    var requireBiometrics: Bool = false
    var useJournalContextInTherapy: Bool = true
    var journalGoalPerWeek: Int = 3
    var meditationGoalMinutes: Int = 10

    enum CodingKeys: String, CodingKey {
        case userName
        case userBio
        case avatarID
        case gender
        case joinDate
        case dailyReminderEnabled
        case dailyReminderHour
        case hapticFeedbackEnabled
        case useLargeText
        case requireBiometrics
        case useJournalContextInTherapy
        case journalGoalPerWeek
        case meditationGoalMinutes
    }

    init(
        userName: String = "User",
        userBio: String = "",
        avatarID: ProfileAvatarID = .cat,
        gender: ProfileGender = .notSpecified,
        joinDate: Date = Date(),
        dailyReminderEnabled: Bool = false,
        dailyReminderHour: Int = 9,
        hapticFeedbackEnabled: Bool = true,
        useLargeText: Bool = false,
        requireBiometrics: Bool = false,
        useJournalContextInTherapy: Bool = true,
        journalGoalPerWeek: Int = 3,
        meditationGoalMinutes: Int = 10
    ) {
        self.userName = userName
        self.userBio = userBio
        self.avatarID = avatarID
        self.gender = gender
        self.joinDate = joinDate
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderHour = dailyReminderHour
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
        self.useLargeText = useLargeText
        self.requireBiometrics = requireBiometrics
        self.useJournalContextInTherapy = useJournalContextInTherapy
        self.journalGoalPerWeek = journalGoalPerWeek
        self.meditationGoalMinutes = meditationGoalMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? "User"
        userBio = try container.decodeIfPresent(String.self, forKey: .userBio) ?? ""
        avatarID = ProfileAvatarID.fromPersistedValue(try container.decodeIfPresent(String.self, forKey: .avatarID))
        gender = try container.decodeIfPresent(ProfileGender.self, forKey: .gender) ?? .notSpecified
        joinDate = try container.decodeIfPresent(Date.self, forKey: .joinDate) ?? Date()
        dailyReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .dailyReminderEnabled) ?? false
        dailyReminderHour = try container.decodeIfPresent(Int.self, forKey: .dailyReminderHour) ?? 9
        hapticFeedbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticFeedbackEnabled) ?? true
        useLargeText = try container.decodeIfPresent(Bool.self, forKey: .useLargeText) ?? false
        requireBiometrics = try container.decodeIfPresent(Bool.self, forKey: .requireBiometrics) ?? false
        useJournalContextInTherapy = try container.decodeIfPresent(Bool.self, forKey: .useJournalContextInTherapy) ?? true
        journalGoalPerWeek = try container.decodeIfPresent(Int.self, forKey: .journalGoalPerWeek) ?? 3
        meditationGoalMinutes = try container.decodeIfPresent(Int.self, forKey: .meditationGoalMinutes) ?? 10
    }
}

struct PersistedJournalInsightState: Codable {
    var dailyInsight: DailyJournalInsights?
}

struct TherapySessionDeletionTombstone: Codable, Identifiable, Equatable {
    var id: String
    var deletedAt: TimeInterval
}

struct JournalDeletionTombstone: Codable, Identifiable, Equatable {
    var id: String
    var deletedAt: TimeInterval
}

struct LuminaPersistedState: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = currentSchemaVersion
    var savedAt: TimeInterval = Date().timeIntervalSince1970
    var chatSessions: [String: ChatSession] = [:]
    var therapySessionDeletionTombstones: [TherapySessionDeletionTombstone] = []
    var journalEntries: [JournalEntry] = []
    var journalDeletionTombstones: [JournalDeletionTombstone] = []
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
        case therapySessionDeletionTombstones
        case journalEntries
        case journalDeletionTombstones
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
        therapySessionDeletionTombstones: [TherapySessionDeletionTombstone] = [],
        journalEntries: [JournalEntry] = [],
        journalDeletionTombstones: [JournalDeletionTombstone] = [],
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
        self.therapySessionDeletionTombstones = therapySessionDeletionTombstones
        self.journalEntries = journalEntries
        self.journalDeletionTombstones = journalDeletionTombstones
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
        therapySessionDeletionTombstones = try container.decodeIfPresent([TherapySessionDeletionTombstone].self, forKey: .therapySessionDeletionTombstones) ?? []
        journalEntries = try container.decodeIfPresent([JournalEntry].self, forKey: .journalEntries) ?? []
        journalDeletionTombstones = try container.decodeIfPresent([JournalDeletionTombstone].self, forKey: .journalDeletionTombstones) ?? []
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
    private let saveQueue = DispatchQueue(label: "lumina.persistence.save", qos: .utility)

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

    func saveAsync(_ state: LuminaPersistedState, onError: @escaping (Error) -> Void) {
        saveQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.save(state)
            } catch {
                DispatchQueue.main.async {
                    onError(error)
                }
            }
        }
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
    private(set) var chatSessions: [String: ChatSession] = [:]
    private(set) var deletionTombstones: [TherapySessionDeletionTombstone] = []
    private var chatSessionPublishScheduled = false
    private static let tombstoneRetention: TimeInterval = 60 * 60 * 24 * 180

    func restore(_ sessions: [String: ChatSession], deletionTombstones: [TherapySessionDeletionTombstone] = []) {
        let tombstones = Self.prunedTombstones(deletionTombstones)
        self.deletionTombstones = tombstones
        let tombstoneMap = Self.tombstoneMap(from: tombstones)
        chatSessions = sessions.filter { _, session in
            !Self.isDeleted(session, tombstones: tombstoneMap)
        }
        chatSessionPublishScheduled = false
    }

    func mergeCloudDeletions(_ remoteTombstones: [TherapySessionDeletionTombstone]) {
        guard !remoteTombstones.isEmpty else { return }
        deletionTombstones = Self.prunedTombstones(deletionTombstones + remoteTombstones)
        let tombstoneMap = Self.tombstoneMap(from: deletionTombstones)
        chatSessions = chatSessions.filter { _, session in
            !Self.isDeleted(session, tombstones: tombstoneMap)
        }
        scheduleChatSessionPublishIfNeeded(.deferred)
    }

    func sessions(for therapist: Therapist) -> [ChatSession] {
        chatSessions.values
            .filter { ($0.therapistID == therapist.id || $0.id == therapist.id) && $0.archivedAt == nil }
            .sorted { $0.lastUpdated > $1.lastUpdated }
    }

    func sessionIDs(for therapist: Therapist) -> [String] {
        chatSessions.values
            .filter { $0.therapistID == therapist.id || $0.id == therapist.id }
            .map(\.id)
    }

    func session(for therapist: Therapist) -> ChatSession? {
        sessions(for: therapist).first
    }

    func saveSession(_ session: ChatSession, publish: ChatSessionPublishMode = .deferred) {
        saveSessions([session], publish: publish)
    }

    func saveSessions(_ sessions: [ChatSession], publish: ChatSessionPublishMode = .deferred) {
        guard !sessions.isEmpty else { return }
        let tombstoneMap = Self.tombstoneMap(from: deletionTombstones)
        let saveableSessions = sessions.filter { !Self.isDeleted($0, tombstones: tombstoneMap) }
        guard !saveableSessions.isEmpty else { return }
        if publish == .immediate {
            objectWillChange.send()
        }
        for session in saveableSessions {
            clearTombstoneIfSessionIsNewer(session)
            chatSessions[session.id] = session
        }
        scheduleChatSessionPublishIfNeeded(publish)
    }

    @discardableResult
    func clearSession(for therapist: Therapist, publish: ChatSessionPublishMode = .deferred) -> [TherapySessionDeletionTombstone] {
        guard chatSessions.values.contains(where: { $0.therapistID == therapist.id || $0.id == therapist.id }) else { return [] }
        let tombstones = chatSessions.values
            .filter { $0.therapistID == therapist.id || $0.id == therapist.id }
            .map { TherapySessionDeletionTombstone(id: $0.id, deletedAt: Date().timeIntervalSince1970) }
        if publish == .immediate {
            objectWillChange.send()
        }
        deletionTombstones = Self.prunedTombstones(deletionTombstones + tombstones)
        chatSessions = chatSessions.filter { _, session in
            session.therapistID != therapist.id && session.id != therapist.id
        }
        scheduleChatSessionPublishIfNeeded(publish)
        return tombstones
    }

    @discardableResult
    func deleteSession(id: String, publish: ChatSessionPublishMode = .deferred) -> TherapySessionDeletionTombstone? {
        guard chatSessions[id] != nil else { return nil }
        let tombstone = TherapySessionDeletionTombstone(id: id, deletedAt: Date().timeIntervalSince1970)
        if publish == .immediate {
            objectWillChange.send()
        }
        deletionTombstones = Self.prunedTombstones(deletionTombstones + [tombstone])
        chatSessions[id] = nil
        scheduleChatSessionPublishIfNeeded(publish)
        return tombstone
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

    @discardableResult
    func clearAllChatSessions(publish: ChatSessionPublishMode = .deferred) -> [TherapySessionDeletionTombstone] {
        guard !chatSessions.isEmpty else { return [] }
        let tombstones = chatSessions.values.map {
            TherapySessionDeletionTombstone(id: $0.id, deletedAt: Date().timeIntervalSince1970)
        }
        if publish == .immediate {
            objectWillChange.send()
        }
        deletionTombstones = Self.prunedTombstones(deletionTombstones + tombstones)
        chatSessions.removeAll()
        scheduleChatSessionPublishIfNeeded(publish)
        return tombstones
    }

    private func clearTombstoneIfSessionIsNewer(_ session: ChatSession) {
        guard let tombstone = Self.tombstoneMap(from: deletionTombstones)[session.id],
              session.lastUpdated > tombstone.deletedAt else {
            return
        }
        deletionTombstones.removeAll { $0.id == session.id }
    }

    private static func isDeleted(_ session: ChatSession, tombstones: [String: TherapySessionDeletionTombstone]) -> Bool {
        guard let tombstone = tombstones[session.id] else { return false }
        return tombstone.deletedAt >= session.lastUpdated
    }

    private static func tombstoneMap(from tombstones: [TherapySessionDeletionTombstone]) -> [String: TherapySessionDeletionTombstone] {
        tombstones.reduce(into: [:]) { result, tombstone in
            if let existing = result[tombstone.id], existing.deletedAt >= tombstone.deletedAt {
                return
            }
            result[tombstone.id] = tombstone
        }
    }

    private static func prunedTombstones(_ tombstones: [TherapySessionDeletionTombstone]) -> [TherapySessionDeletionTombstone] {
        let cutoff = Date().timeIntervalSince1970 - tombstoneRetention
        return tombstoneMap(from: tombstones)
            .values
            .filter { $0.deletedAt >= cutoff }
            .sorted { $0.deletedAt > $1.deletedAt }
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
    @Published private(set) var deletionTombstones: [JournalDeletionTombstone] = []

    private static let tombstoneRetention: TimeInterval = 60 * 60 * 24 * 180

    var averageSentiment: Int {
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0) { $0 + ($1.sentimentScore ?? 50) } / entries.count
    }

    func restore(_ entries: [JournalEntry], deletionTombstones: [JournalDeletionTombstone] = []) {
        let tombstones = Self.prunedTombstones(deletionTombstones)
        self.deletionTombstones = tombstones
        let tombstoneMap = Self.tombstoneMap(from: tombstones)
        self.entries = entries.filter {
            !Self.isSeedReflection($0) && !Self.isDeleted($0, tombstones: tombstoneMap)
        }
    }

    func mergeCloudSummaries(_ remoteEntries: [JournalEntry]) {
        guard !remoteEntries.isEmpty else { return }
        let tombstoneMap = Self.tombstoneMap(from: deletionTombstones)
        var merged = entries.filter {
            !Self.isSeedReflection($0) && !Self.isDeleted($0, tombstones: tombstoneMap)
        }

        for remote in remoteEntries where !Self.isSeedReflection(remote) && !Self.isDeleted(remote, tombstones: tombstoneMap) {
            if let index = merged.firstIndex(where: { $0.id == remote.id }) {
                merged[index] = Self.mergedLocalEntry(merged[index], withCloudSummary: remote)
            } else {
                merged.append(remote)
            }
        }

        entries = merged.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.timestamp > $1.timestamp
        }
    }

    func mergeCloudDeletions(_ remoteTombstones: [JournalDeletionTombstone]) {
        guard !remoteTombstones.isEmpty else { return }
        deletionTombstones = Self.prunedTombstones(deletionTombstones + remoteTombstones)
        let tombstoneMap = Self.tombstoneMap(from: deletionTombstones)
        entries.removeAll { Self.isDeleted($0, tombstones: tombstoneMap) }
    }

    func addEntry(_ entry: JournalEntry) {
        clearTombstoneIfEntryIsNewer(entry)
        entries.insert(entry, at: 0)
    }

    func updateEntry(_ entry: JournalEntry) {
        clearTombstoneIfEntryIsNewer(entry)
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        }
    }

    @discardableResult
    func deleteEntry(id: String) -> JournalDeletionTombstone {
        let tombstone = JournalDeletionTombstone(id: id, deletedAt: Date().timeIntervalSince1970)
        deletionTombstones = Self.prunedTombstones(deletionTombstones + [tombstone])
        entries.removeAll { $0.id == id }
        return tombstone
    }

    func togglePin(id: String) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].isPinned.toggle()
    }

    private func clearTombstoneIfEntryIsNewer(_ entry: JournalEntry) {
        guard let tombstone = Self.tombstoneMap(from: deletionTombstones)[entry.id],
              entry.timestamp > tombstone.deletedAt else {
            return
        }
        deletionTombstones.removeAll { $0.id == entry.id }
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

    private static func isDeleted(_ entry: JournalEntry, tombstones: [String: JournalDeletionTombstone]) -> Bool {
        guard let tombstone = tombstones[entry.id] else { return false }
        return tombstone.deletedAt >= entry.timestamp
    }

    private static func tombstoneMap(from tombstones: [JournalDeletionTombstone]) -> [String: JournalDeletionTombstone] {
        tombstones.reduce(into: [:]) { result, tombstone in
            if let existing = result[tombstone.id], existing.deletedAt >= tombstone.deletedAt {
                return
            }
            result[tombstone.id] = tombstone
        }
    }

    private static func prunedTombstones(_ tombstones: [JournalDeletionTombstone]) -> [JournalDeletionTombstone] {
        let cutoff = Date().timeIntervalSince1970 - tombstoneRetention
        return tombstoneMap(from: tombstones)
            .values
            .filter { $0.deletedAt >= cutoff }
            .sorted { $0.deletedAt > $1.deletedAt }
    }

    private static func mergedLocalEntry(_ local: JournalEntry, withCloudSummary remote: JournalEntry) -> JournalEntry {
        JournalEntry(
            id: local.id,
            date: local.date.isEmpty ? remote.date : local.date,
            timestamp: max(local.timestamp, remote.timestamp),
            title: local.title.isEmpty ? remote.title : local.title,
            content: local.content,
            mood: local.mood,
            tags: local.tags.isEmpty ? remote.tags : local.tags,
            reflection: local.reflection ?? remote.reflection,
            actionItem: local.actionItem ?? remote.actionItem,
            summary: local.summary ?? remote.summary,
            sentimentScore: local.sentimentScore ?? remote.sentimentScore,
            energyLevel: local.energyLevel ?? remote.energyLevel,
            anxietyLevel: local.anxietyLevel ?? remote.anxietyLevel,
            therapyMemoryPolicy: local.therapyMemoryPolicy ?? remote.therapyMemoryPolicy,
            isPinned: local.isPinned || remote.isPinned
        )
    }
}

@MainActor
final class JournalInsightStore: ObservableObject {
    @Published var dailyInsight: DailyJournalInsights?

    func restore(_ state: PersistedJournalInsightState) {
        dailyInsight = state.dailyInsight
    }

    func mergeCloudInsight(_ insight: DailyJournalInsights?) {
        guard let insight else { return }
        if let current = dailyInsight, current.generatedAt >= insight.generatedAt {
            return
        }
        dailyInsight = insight
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
    @Published var habits: [Habit] = []
    @Published var waterDrops: Int = 5
    @Published var gardenDecorations: [GardenDecoration] = []
    @Published var keptGardenPromptIDs: Set<String> = []
    @Published var therapyMicroPlans: [MicroPlan] = []
    @Published var forageItems: [GardenForageItem] = []
    @Published var visitorInvitations: [GardenVisitorInvitation] = []
    @Published var keepsakes: [GardenKeepsake] = []
    @Published var unlockedAreas: [GardenMapAreaUnlock] = []
    @Published var areaVisits: [GardenMapAreaVisit] = []
    @Published var areaMilestones: [GardenAreaMilestoneUnlock] = []

    func restore(_ state: PersistedGardenState) {
        habits = state.habits.filter { !Self.isSeedHabit($0) }
        waterDrops = state.waterDrops
        gardenDecorations = state.gardenDecorations
        keptGardenPromptIDs = state.keptGardenPromptIDs
        therapyMicroPlans = state.therapyMicroPlans
        forageItems = state.forageItems
        visitorInvitations = state.visitorInvitations
        keepsakes = state.keepsakes
        unlockedAreas = state.unlockedAreas
        areaVisits = state.areaVisits
        areaMilestones = state.areaMilestones
    }

    func mergeCloudState(_ state: PersistedGardenState) {
        habits = Self.mergeHabits(local: habits, remote: state.habits.filter { !Self.isSeedHabit($0) })
        waterDrops = max(waterDrops, state.waterDrops)
        gardenDecorations = Self.mergeByID(local: gardenDecorations, remote: state.gardenDecorations)
        keptGardenPromptIDs.formUnion(state.keptGardenPromptIDs)
        therapyMicroPlans = Self.mergeByID(local: therapyMicroPlans, remote: state.therapyMicroPlans)
        forageItems = Self.mergeByID(local: forageItems, remote: state.forageItems)
        visitorInvitations = Self.mergeByID(local: visitorInvitations, remote: state.visitorInvitations)
        keepsakes = Self.mergeByID(local: keepsakes, remote: state.keepsakes)
        unlockedAreas = Self.mergeByID(local: unlockedAreas, remote: state.unlockedAreas)
        areaVisits = Self.mergeByID(local: areaVisits, remote: state.areaVisits)
        areaMilestones = Self.mergeByID(local: areaMilestones, remote: state.areaMilestones)
    }

    func snapshot() -> PersistedGardenState {
        PersistedGardenState(
            habits: habits,
            waterDrops: waterDrops,
            gardenDecorations: gardenDecorations,
            keptGardenPromptIDs: keptGardenPromptIDs,
            therapyMicroPlans: therapyMicroPlans,
            forageItems: forageItems,
            visitorInvitations: visitorInvitations,
            keepsakes: keepsakes,
            unlockedAreas: unlockedAreas,
            areaVisits: areaVisits,
            areaMilestones: areaMilestones
        )
    }

    func habit(id: String) -> Habit? {
        habits.first { $0.id == id }
    }

    func isHabitCompletedToday(_ habit: Habit, now: Date = Date()) -> Bool {
        guard let completedAt = habit.completedAt else { return false }
        return Calendar.current.isDate(Date(timeIntervalSince1970: completedAt), inSameDayAs: now)
    }

    func completeHabit(id: String) {
        guard let idx = habits.firstIndex(where: { $0.id == id }) else { return }
        if isHabitCompletedToday(habits[idx]) {
            habits[idx].completedAt = nil
        } else {
            completeHabit(at: idx, dewAmount: 3)
        }
    }

    @discardableResult
    func completeHabitIfNeeded(id: String, dewAmount: Int = 3) -> Bool {
        guard let idx = habits.firstIndex(where: { $0.id == id }),
              !isHabitCompletedToday(habits[idx]) else { return false }
        completeHabit(at: idx, dewAmount: dewAmount)
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

    func canArrangeGardenDecoration(_ type: GardenDecorationType) -> Bool {
        waterDrops >= type.dewCost
    }

    @discardableResult
    func arrangeGardenDecoration(type: GardenDecorationType, anchorHabitID: String, x: Double, y: Double) -> Bool {
        guard canArrangeGardenDecoration(type) else { return false }
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
    func touchGardenPrompt(id: String, dewAmount: Int) -> Bool {
        guard !keptGardenPromptIDs.contains(id), dewAmount > 0 else { return false }
        keptGardenPromptIDs.insert(id)
        waterDrops += dewAmount
        return true
    }

    var activeForageItems: [GardenForageItem] {
        forageItems.filter { !$0.isGathered }
    }

    func refreshAmbientForage(now: Date = Date()) {
        let dayKey = GardenForageItem.dayKey(for: now)
        forageItems = forageItems.filter { $0.dayKey == dayKey }
        if !forageItems.isEmpty {
            forageItems = forageItems.enumerated().map { index, item in
                let position = Self.ambientForagePositions[index % Self.ambientForagePositions.count]
                return GardenForageItem(
                    id: item.id,
                    kind: item.kind,
                    dayKey: item.dayKey,
                    x: position.x,
                    y: position.y,
                    dewAmount: item.dewAmount,
                    spawnedAt: item.spawnedAt,
                    gatheredAt: item.gatheredAt
                )
            }
            return
        }

        forageItems = Self.ambientForagePositions.enumerated().map { index, position in
            GardenForageItem(
                id: "dew-\(dayKey)-\(index)",
                dayKey: dayKey,
                x: position.x,
                y: position.y,
                dewAmount: index == 0 ? 2 : 1,
                spawnedAt: now.timeIntervalSince1970
            )
        }
    }

    @discardableResult
    func gatherForageItem(id: String, now: Date = Date()) -> GardenForageItem? {
        guard let index = forageItems.firstIndex(where: { $0.id == id && !$0.isGathered }) else {
            return nil
        }

        var item = forageItems[index]
        item.gatheredAt = now.timeIntervalSince1970
        forageItems[index] = item
        waterDrops += item.dewAmount
        return item
    }

    func activeVisitorInvitation(on date: Date = Date()) -> GardenVisitorInvitation? {
        let dayKey = GardenForageItem.dayKey(for: date)
        return visitorInvitations.first { $0.dayKey == dayKey && !$0.isDismissed && !$0.isCompleted }
    }

    func refreshVisitorInvitation(now: Date = Date()) {
        let dayKey = GardenForageItem.dayKey(for: now)
        visitorInvitations = visitorInvitations.filter { $0.dayKey == dayKey }
        if !visitorInvitations.isEmpty {
            let updatedPlacement = GardenVisitorInvitation.make(for: now)
            visitorInvitations = visitorInvitations.map { invitation in
                GardenVisitorInvitation(
                    id: invitation.id,
                    dayKey: invitation.dayKey,
                    visitor: invitation.visitor,
                    invitationKind: invitation.invitationKind,
                    targetCount: invitation.targetCount,
                    dewAmount: invitation.dewAmount,
                    x: updatedPlacement.x,
                    y: updatedPlacement.y,
                    spawnedAt: invitation.spawnedAt,
                    acceptedAt: invitation.acceptedAt,
                    completedAt: invitation.completedAt,
                    dismissedAt: invitation.dismissedAt
                )
            }
            return
        }
        visitorInvitations = [GardenVisitorInvitation.make(for: now)]
    }

    @discardableResult
    func acceptVisitorInvitation(id: String, now: Date = Date()) -> GardenVisitorInvitation? {
        guard let index = visitorInvitations.firstIndex(where: { $0.id == id && !$0.isDismissed && !$0.isCompleted }) else {
            return nil
        }
        if visitorInvitations[index].acceptedAt == nil {
            visitorInvitations[index].acceptedAt = now.timeIntervalSince1970
        }
        return visitorInvitations[index]
    }

    @discardableResult
    func settleVisitorInvitation(id: String, progress: Int, now: Date = Date()) -> GardenVisitorInvitation? {
        guard let index = visitorInvitations.firstIndex(where: { $0.id == id && !$0.isDismissed && !$0.isCompleted }),
              visitorInvitations[index].isAccepted,
              progress >= visitorInvitations[index].targetCount else {
            return nil
        }

        visitorInvitations[index].completedAt = now.timeIntervalSince1970
        waterDrops += visitorInvitations[index].dewAmount
        unlockKeepsake(
            kind: GardenKeepsakeKind.keepsake(for: visitorInvitations[index].visitor),
            visitor: visitorInvitations[index].visitor,
            sourceInvitationID: visitorInvitations[index].id,
            now: now
        )
        return visitorInvitations[index]
    }

    @discardableResult
    func dismissVisitorInvitation(id: String, now: Date = Date()) -> GardenVisitorInvitation? {
        guard let index = visitorInvitations.firstIndex(where: { $0.id == id && !$0.isCompleted }) else {
            return nil
        }
        visitorInvitations[index].dismissedAt = now.timeIntervalSince1970
        return visitorInvitations[index]
    }

    @discardableResult
    func unlockKeepsake(
        kind: GardenKeepsakeKind,
        visitor: GardenVisitorKind,
        sourceInvitationID: String,
        now: Date = Date()
    ) -> GardenKeepsake? {
        if let existing = keepsakes.first(where: { $0.kind == kind }) {
            return existing
        }

        let keepsake = GardenKeepsake(
            kind: kind,
            visitor: visitor,
            openedAt: now.timeIntervalSince1970,
            sourceInvitationID: sourceInvitationID
        )
        keepsakes.append(keepsake)
        unlockMapArea(
            area: GardenMapAreaKind.area(for: kind),
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
            dewAmount: area.visitDewAmount,
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
                dewAmount: definition.dewAmount,
                unlockedAt: now.timeIntervalSince1970
            )
        }

        areaMilestones.append(contentsOf: unlockedMilestones)
        let result = GardenAreaActionResult(visit: visit, unlockedMilestones: unlockedMilestones)
        waterDrops += result.totalDewAmount
        return result
    }

    @discardableResult
    func plantStarterRoutine(title: String, description: String) -> Habit? {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else { return nil }
        guard !habits.contains(where: { $0.title.caseInsensitiveCompare(normalizedTitle) == .orderedSame }) else {
            return nil
        }

        let habit = Habit(
            id: "garden-routine-\(Self.slug(normalizedTitle))-\(Int(Date().timeIntervalSince1970))",
            title: normalizedTitle,
            description: normalizedDescription.isEmpty ? "A small routine you chose for the grove." : normalizedDescription,
            completedAt: nil,
            createdAt: Date().timeIntervalSince1970,
            plantType: .seed,
            growth: 0
        )
        habits.insert(habit, at: 0)
        return habit
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

    @discardableResult
    func upsertJournalMemoryPlant(for entry: JournalEntry) -> Habit? {
        let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !content.isEmpty else { return nil }

        let plantTitle = title.isEmpty ? "A saved reflection" : title
        let plantDescription = Self.journalMemoryDescription(for: entry)
        if let index = habits.firstIndex(where: { $0.sourceJournalEntryID == entry.id }) {
            habits[index].title = plantTitle
            habits[index].description = plantDescription
            habits[index].createdAt = entry.timestamp
            habits[index].growth = max(habits[index].growth, 35)
            updatePlantType(at: index)
            return habits[index]
        }

        let habit = Habit(
            id: "journal-memory-\(entry.id)",
            title: plantTitle,
            description: plantDescription,
            completedAt: nil,
            createdAt: entry.timestamp,
            plantType: .sprout,
            growth: 35,
            sourceJournalEntryID: entry.id
        )
        habits.insert(habit, at: 0)
        return habit
    }

    func removeJournalMemoryPlant(entryID: String) {
        habits.removeAll { $0.sourceJournalEntryID == entryID }
    }

    private func completeHabit(at index: Int, dewAmount: Int) {
        waterDrops += dewAmount
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

    private static func isSeedHabit(_ habit: Habit) -> Bool {
        let seedTitles: Set<String> = [
            "Drink a glass of warm water",
            "Look out the window for 2 mins",
            "Write one sentence of gratitude",
            "Take a 5-minute walk"
        ]
        return ["1", "2", "3", "4"].contains(habit.id) && seedTitles.contains(habit.title)
    }

    private static func mergeHabits(local: [Habit], remote: [Habit]) -> [Habit] {
        var merged = local.filter { !isSeedHabit($0) }
        for remoteHabit in remote where !isSeedHabit(remoteHabit) {
            if let index = merged.firstIndex(where: { $0.id == remoteHabit.id }) {
                var localHabit = merged[index]
                localHabit.growth = max(localHabit.growth, remoteHabit.growth)
                localHabit.plantType = Self.strongerPlantType(localHabit.plantType, remoteHabit.plantType)
                switch (localHabit.completedAt, remoteHabit.completedAt) {
                case (nil, let remoteCompletedAt?):
                    localHabit.completedAt = remoteCompletedAt
                case (let localCompletedAt?, let remoteCompletedAt?):
                    localHabit.completedAt = max(localCompletedAt, remoteCompletedAt)
                default:
                    break
                }
                if localHabit.description.isEmpty {
                    localHabit.description = remoteHabit.description
                }
                if localHabit.sourceMicroPlanID == nil {
                    localHabit.sourceMicroPlanID = remoteHabit.sourceMicroPlanID
                }
                if localHabit.sourceJournalEntryID == nil {
                    localHabit.sourceJournalEntryID = remoteHabit.sourceJournalEntryID
                }
                merged[index] = localHabit
            } else {
                merged.append(remoteHabit)
            }
        }
        return merged.sorted { $0.createdAt > $1.createdAt }
    }

    private static func strongerPlantType(_ left: PlantType, _ right: PlantType) -> PlantType {
        func rank(_ type: PlantType) -> Int {
            switch type {
            case .seed: return 0
            case .sprout: return 1
            case .flower: return 2
            case .tree: return 3
            }
        }
        return rank(left) >= rank(right) ? left : right
    }

    private static func mergeByID<Item: Identifiable>(local: [Item], remote: [Item]) -> [Item] where Item.ID == String {
        var merged = local
        for item in remote where !merged.contains(where: { $0.id == item.id }) {
            merged.append(item)
        }
        return merged
    }

    private static func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        return value
            .lowercased()
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce("") { partial, character in
                let string = String(character)
                if partial.last == "-", string == "-" { return partial }
                return partial + string
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func journalMemoryDescription(for entry: JournalEntry) -> String {
        let candidates = [
            entry.summary,
            entry.reflection,
            entry.actionItem,
            entry.content
        ]
        let raw = candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "A reflection saved into the grove."
        let cleaned = raw
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "- ", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > 150 else { return cleaned }
        return String(cleaned.prefix(147)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static let ambientForagePositions: [(x: Double, y: Double)] = [
        (0.18, 0.48),
        (0.82, 0.50),
        (0.57, 0.36)
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

final class HealthContextService {
    var isAvailable: Bool {
        false
    }

    func requestAuthorization() async throws {
        throw HealthContextServiceError.comingSoon
    }

    func fetchDailySummaries(days: Int) async throws -> [DailyHealthSummary] {
        throw HealthContextServiceError.comingSoon
    }
}

enum HealthContextServiceError: LocalizedError {
    case comingSoon

    var errorDescription: String? {
        "Health context is coming soon."
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

    private let service = HealthContextService()

    init() {
        permissionState = service.isAvailable ? .notDetermined : .unavailable
    }

    func restore(_ state: PersistedHealthDataState) {
        guard service.isAvailable else {
            permissionState = .unavailable
            summaries = []
            baseline = nil
            lastSyncAt = nil
            isSyncing = false
            lastError = nil
            hasAcknowledgedDataUse = false
            return
        }
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
            lastError = "Health context is coming soon."
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

        if let nextHabit = habits.first(where: { habit in
            guard let completedAt = habit.completedAt else { return true }
            return !Self.isSameDay(Date(timeIntervalSince1970: completedAt), now)
        }) {
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
    @Published var avatarID: ProfileAvatarID = .cat
    @Published var gender: ProfileGender = .notSpecified
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
        avatarID = state.avatarID
        gender = state.gender
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
            avatarID: avatarID,
            gender: gender,
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
    @Published private(set) var usage = SubscriptionUsageState()

    var hasPremiumAccess: Bool {
        state.hasPremiumAccess
    }

    var allowance: SubscriptionAllowance {
        var normalized = usage
        normalized.normalize()
        return SubscriptionAllowance(
            hasPremiumAccess: hasPremiumAccess,
            aiChatRepliesToday: normalized.aiChatRepliesToday,
            liveCallSecondsToday: normalized.liveCallSecondsToday,
            liveCallSecondsThisMonth: normalized.liveCallSecondsThisMonth
        )
    }

    func restore(_ persisted: PersistedSubscriptionState) {
        state = persisted.subscription
        usage = persisted.usage
        usage.normalize()
    }

    func snapshot() -> PersistedSubscriptionState {
        var normalized = usage
        normalized.normalize()
        return PersistedSubscriptionState(subscription: state, usage: normalized)
    }

    func update(_ nextState: SubscriptionState) {
        state = nextState
    }

    func recordAIChatReply() {
        usage.recordAIChatReply()
    }

    func recordLiveCall(seconds: Int) {
        usage.recordLiveCall(seconds: seconds)
    }

    func canStartAIChatReply() -> Bool {
        allowance.canUseAIChat
    }

    func canStartLiveCall() -> Bool {
        allowance.canStartLiveCall
    }

    func canUse(_ feature: PremiumFeature) -> Bool {
        switch feature {
        case .therapyChat:
            return true
        case .liveCall:
            return canStartLiveCall()
        case .deepInsights, .advancedMemory, .gardenPremium:
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
    let revenueCatService = RevenueCatSubscriptionService()

    @Published private(set) var isNetworkAvailable = true

    private let persistenceService = PersistenceService()
    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "lumina.network.monitor")
    private var cancellables: Set<AnyCancellable> = []
    private var saveTask: Task<Void, Never>?
    private var didStartLaunchServices = false
    private var cloudSessionSyncTasks: [String: Task<Void, Never>] = [:]
    private var cloudSessionDeletionSyncTasks: [String: Task<Void, Never>] = [:]
    private var cloudSessionDeletionBulkSyncTask: Task<Void, Never>?
    private var cloudJournalSummarySyncTasks: [String: Task<Void, Never>] = [:]
    private var cloudJournalDeletionSyncTasks: [String: Task<Void, Never>] = [:]
    private var cloudJournalDeletionBulkSyncTask: Task<Void, Never>?
    private var cloudJournalBulkSyncTask: Task<Void, Never>?
    private var cloudProfileSyncTask: Task<Void, Never>?
    private var cloudSubscriptionSyncTask: Task<Void, Never>?
    private var cloudJournalInsightSyncTask: Task<Void, Never>?
    private var cloudGardenSyncTask: Task<Void, Never>?
    private var cloudRestoreTask: Task<Void, Never>?

    init() {
        restorePersistedState()
        bindStoreChanges()
        startNetworkMonitoring()
    }

    deinit {
        networkMonitor.cancel()
    }

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                let isAvailable = path.status == .satisfied
                let wasUnavailable = !self.isNetworkAvailable
                self.isNetworkAvailable = isAvailable
                if wasUnavailable && isAvailable {
                    self.syncPendingCloudWorkAfterReconnect()
                }
            }
        }
        networkMonitor.start(queue: networkMonitorQueue)
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
            .sink { [weak self] _ in
                self?.storeDidChange()
                self?.scheduleGardenCloudSync()
            }
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
            .sink { [weak self] _ in
                self?.storeDidChange()
                self?.scheduleUserProfileCloudSync()
            }
            .store(in: &cancellables)
        accountStore.objectWillChange
            .sink { [weak self] _ in
                self?.storeDidChange()
                self?.scheduleUserProfileCloudSync()
            }
            .store(in: &cancellables)
        subscriptionStore.objectWillChange
            .sink { [weak self] _ in
                self?.storeDidChange()
                self?.scheduleSubscriptionCloudSync()
            }
            .store(in: &cancellables)
        firebaseBackend.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        revenueCatService.objectWillChange
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
            await self.refreshRevenueCatSubscription()
        }
    }

    private func storeDidChange() {
        objectWillChange.send()
        schedulePersistedStateSave()
    }

    private func restorePersistedState() {
        guard let state = persistenceService.load() else { return }
        chatStore.restore(state.chatSessions, deletionTombstones: state.therapySessionDeletionTombstones)
        journalStore.restore(state.journalEntries, deletionTombstones: state.journalDeletionTombstones)
        journalInsightStore.restore(state.journalInsights)
        gardenStore.restore(state.garden)
        backfillJournalMemoryPlants()
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
        let state = snapshot()
        persistenceService.saveAsync(state) { error in
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
            therapySessionDeletionTombstones: chatStore.deletionTombstones,
            journalEntries: journalStore.entries,
            journalDeletionTombstones: journalStore.deletionTombstones,
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
    @Published private(set) var pendingTherapySessionID: String?

    func requestTherapy(with therapist: Therapist) {
        activeTherapist = therapist
        pendingTherapyTherapistID = therapist.id
        pendingTherapySessionID = nil
        selectedTab = 2
    }

    func requestTherapy(session: ChatSession) {
        let therapistID = session.therapistID == session.id ? session.id : session.therapistID
        if let therapist = allTherapists.first(where: { $0.id == therapistID }) {
            activeTherapist = therapist
        }
        pendingTherapyTherapistID = nil
        pendingTherapySessionID = session.id
        selectedTab = 2
    }

    func consumePendingTherapyRequest() {
        pendingTherapyTherapistID = nil
        pendingTherapySessionID = nil
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
        scheduleLocalSaveIfSilent(publish)
        syncTherapySessionToCloud(session)
    }

    func saveSessions(_ sessions: [ChatSession], publish: ChatSessionPublishMode = .deferred) {
        chatStore.saveSessions(sessions, publish: publish)
        scheduleLocalSaveIfSilent(publish)
        sessions.forEach(syncTherapySessionToCloud)
    }

    func clearSession(for therapist: Therapist, publish: ChatSessionPublishMode = .deferred) {
        let tombstones = chatStore.clearSession(for: therapist, publish: publish)
        scheduleLocalSaveIfSilent(publish)
        syncTherapySessionDeletionsToCloud(tombstones)
    }

    func deleteSession(id: String, publish: ChatSessionPublishMode = .deferred) {
        guard let tombstone = chatStore.deleteSession(id: id, publish: publish) else { return }
        scheduleLocalSaveIfSilent(publish)
        syncTherapySessionDeletionToCloud(tombstone)
    }

    func archiveSession(id: String, publish: ChatSessionPublishMode = .deferred) {
        guard let session = chatStore.archiveSession(id: id, publish: publish) else { return }
        scheduleLocalSaveIfSilent(publish)
        syncTherapySessionToCloud(session)
    }

    func clearAllChatSessions(publish: ChatSessionPublishMode = .deferred) {
        let tombstones = chatStore.clearAllChatSessions(publish: publish)
        scheduleLocalSaveIfSilent(publish)
        syncTherapySessionDeletionsToCloud(tombstones)
        evaluationStore.recordSafetyEvent(
            kind: .userControlAction,
            riskLevel: .none,
            reasonCodes: ["control.clear_chat_history"]
        )
    }

    private func scheduleLocalSaveIfSilent(_ publish: ChatSessionPublishMode) {
        guard publish == .silent else { return }
        schedulePersistedStateSave()
    }

    // MARK: - Journal Entries

    var entries: [JournalEntry] {
        get { journalStore.entries }
        set { journalStore.entries = newValue }
    }

    var averageSentiment: Int {
        journalStore.averageSentiment
    }

    private func backfillJournalMemoryPlants(limit: Int = 8) {
        let recentEntries = journalStore.entries
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
        for entry in recentEntries {
            gardenStore.upsertJournalMemoryPlant(for: entry)
        }
    }

    func addEntry(_ entry: JournalEntry) {
        journalStore.addEntry(entry)
        gardenStore.upsertJournalMemoryPlant(for: entry)
        refreshJITAI()
        syncJournalSummaryToCloud(entry)
        syncTherapyContextToCloud(for: nil)
    }

    func updateEntry(_ entry: JournalEntry) {
        journalStore.updateEntry(entry)
        gardenStore.upsertJournalMemoryPlant(for: entry)
        refreshJITAI()
        syncJournalSummaryToCloud(entry)
        syncTherapyContextToCloud(for: nil)
    }

    func deleteEntry(id: String) {
        let tombstone = journalStore.deleteEntry(id: id)
        gardenStore.removeJournalMemoryPlant(entryID: id)
        refreshJITAI()
        syncJournalDeletionToCloud(tombstone)
        syncTherapyContextToCloud(for: nil)
    }

    func toggleEntryPin(id: String) {
        journalStore.togglePin(id: id)
        refreshJITAI()
        if let entry = journalStore.entries.first(where: { $0.id == id }) {
            syncJournalSummaryToCloud(entry)
        }
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
        # Therapy with \(therapist.name)

        ## What I brought
        \(userMessages.map { "- \($0)" }.joined(separator: "\n"))

        ## What felt useful
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
        gardenStore.upsertJournalMemoryPlant(for: entry)
        syncJournalSummaryToCloud(entry)
        syncTherapyContextToCloud(for: therapist)
    }

    var dailyJournalInsights: DailyJournalInsights? {
        journalInsightStore.dailyInsight
    }

    func saveDailyJournalInsights(_ insights: DailyJournalInsights) {
        journalInsightStore.save(insights)
        syncDailyJournalInsightsToCloud(insights)
    }

    func clearDailyJournalInsights() {
        if let dateKey = journalInsightStore.dailyInsight?.dateKey {
            deleteDailyJournalInsightsFromCloud(dateKey: dateKey)
        }
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

    var keptGardenPromptIDs: Set<String> {
        get { gardenStore.keptGardenPromptIDs }
        set { gardenStore.keptGardenPromptIDs = newValue }
    }

    var therapyMicroPlans: [MicroPlan] {
        get { gardenStore.therapyMicroPlans }
        set { gardenStore.therapyMicroPlans = newValue }
    }

    var gardenForageItems: [GardenForageItem] {
        get { gardenStore.forageItems }
        set { gardenStore.forageItems = newValue }
    }

    var gardenVisitorInvitations: [GardenVisitorInvitation] {
        get { gardenStore.visitorInvitations }
        set { gardenStore.visitorInvitations = newValue }
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

    var activeGardenVisitorInvitation: GardenVisitorInvitation? {
        gardenStore.activeVisitorInvitation()
    }

    func isGardenHabitCompletedToday(_ habit: Habit) -> Bool {
        gardenStore.isHabitCompletedToday(habit)
    }

    func completeHabit(id: String) {
        let wasCompletedToday = gardenStore.habit(id: id).map { gardenStore.isHabitCompletedToday($0) } ?? false
        gardenStore.completeHabit(id: id)
        let isCompletedToday = gardenStore.habit(id: id).map { gardenStore.isHabitCompletedToday($0) } ?? false
        if !wasCompletedToday,
           isCompletedToday,
           let microPlanID = gardenStore.habit(id: id)?.sourceMicroPlanID {
            followUpStore.record(microPlanID: microPlanID, status: .completed)
        }
        refreshJITAI()
    }

    func waterPlant(id: String) {
        gardenStore.waterPlant(id: id)
        refreshJITAI()
    }

    func canArrangeGardenDecoration(_ type: GardenDecorationType) -> Bool {
        gardenStore.canArrangeGardenDecoration(type)
    }

    @discardableResult
    func arrangeGardenDecoration(type: GardenDecorationType, anchorHabitID: String, x: Double, y: Double) -> Bool {
        gardenStore.arrangeGardenDecoration(type: type, anchorHabitID: anchorHabitID, x: x, y: y)
    }

    @discardableResult
    func touchGardenPrompt(id: String, dewAmount: Int) -> Bool {
        gardenStore.touchGardenPrompt(id: id, dewAmount: dewAmount)
    }

    func refreshGardenForage(now: Date = Date()) {
        gardenStore.refreshAmbientForage(now: now)
    }

    @discardableResult
    func gatherGardenForageItem(id: String) -> GardenForageItem? {
        gardenStore.gatherForageItem(id: id)
    }

    func refreshGardenVisitorInvitation(now: Date = Date()) {
        gardenStore.refreshVisitorInvitation(now: now)
    }

    @discardableResult
    func acceptGardenVisitorInvitation(id: String) -> GardenVisitorInvitation? {
        gardenStore.acceptVisitorInvitation(id: id)
    }

    @discardableResult
    func settleGardenVisitorInvitation(id: String, progress: Int) -> GardenVisitorInvitation? {
        gardenStore.settleVisitorInvitation(id: id, progress: progress)
    }

    @discardableResult
    func dismissGardenVisitorInvitation(id: String) -> GardenVisitorInvitation? {
        gardenStore.dismissVisitorInvitation(id: id)
    }

    @discardableResult
    func completeGardenMapAreaVisit(area: GardenMapAreaKind) -> GardenAreaActionResult? {
        gardenStore.completeMapAreaVisit(area: area)
    }

    @discardableResult
    func plantStarterGardenRoutine(title: String, description: String) -> Habit? {
        let habit = gardenStore.plantStarterRoutine(title: title, description: description)
        refreshJITAI()
        return habit
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
            gardenStore.completeHabitIfNeeded(id: habitID, dewAmount: 3)
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
        guard subscriptionStore.canUse(.advancedMemory) else { return nil }
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
        guard subscriptionStore.canUse(.advancedMemory) else { return nil }
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
            "Conversation continuity for \(therapist.name):",
            "- The user has met this guide before. Stay in \(therapist.name)'s voice and continue gently, without sounding like a system recalling data."
        ]

        for session in priorSessions {
            let userTexts = session.messages
                .filter { $0.role == .user && !$0.isThinking }
                .suffix(3)
                .compactMap { Self.safeTherapyMemoryFocus($0.text, for: therapist) }
                .prefix(2)
            let modelTexts = session.messages
                .filter { $0.role == .model && !$0.isThinking }
                .suffix(1)
                .map { Self.compactTherapyMemoryText($0.text, limit: 130) }
            let date = Date(timeIntervalSince1970: session.lastUpdated).formatted(.dateTime.month(.abbreviated).day())
            if !userTexts.isEmpty {
                lines.append("- \(date), previous user thread: \(userTexts.joined(separator: " / "))")
            }
            if let lastGuidance = modelTexts.first, !lastGuidance.isEmpty {
                lines.append("- Prior \(therapist.name) response leaned toward: \(lastGuidance)")
            }
        }

        lines.append("- Use this memory quietly. If you mention it, say it as an invitation, not a fact the user must accept.")
        return lines.joined(separator: "\n")
    }

    func hasTherapistMemory(for therapist: Therapist, excluding sessionID: String? = nil) -> Bool {
        guard subscriptionStore.canUse(.advancedMemory) else { return false }
        return chatStore.sessions(for: therapist)
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
        guard subscriptionStore.canUse(.advancedMemory) else { return [] }
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
        guard subscriptionStore.canUse(.advancedMemory) else { return false }
        guard profileStore.useJournalContextInTherapy else { return false }
        return wellbeingContext(for: therapist).journalBridge?.isEmpty == false
    }

    func personalizedTherapyOpening(for therapist: Therapist) -> String? {
        guard subscriptionStore.canUse(.advancedMemory) else { return nil }
        if let focus = therapistMemoryOpeningFocus(for: therapist) {
            return """
            \(therapist.greeting)

            Welcome back. I remember we were working with \(focus). We can pick up that thread if it still fits, or start with what feels most present today.
            """
        }

        guard profileStore.useJournalContextInTherapy,
              let bridge = wellbeingContext(for: therapist).journalBridge,
              !bridge.isEmpty else { return nil }

        let theme = safeJournalTheme(bridge.recurringThemes.first, for: therapist)
        let base: String
        switch therapist.id {
        case "willow":
            base = theme.map { "There may be a recent thread around \($0). We can make it concrete, or leave it aside and start fresh." } ?? "We can look for one clear next step, or begin fresh."
        case "serena":
            base = theme.map { "\($0) may be carrying some weight lately. We can stay close to the feeling, or begin anywhere you like." } ?? "We can begin with what you feel right now."
        case "eden":
            base = theme.map { "There may be something to notice around \($0). If it fits, we can look at the relationship side gently." } ?? "We can look at connection patterns, or begin fresh."
        case "nimbus":
            base = theme.map { "\($0) may be present lately. We can start with grounding first, or simply talk through what is here." } ?? "We can keep this low-pressure, or simply start with your breath."
        default:
            base = theme.map { "There may be a recent thread around \($0). We can start there only if it feels useful." } ?? "We can start fresh."
        }

        return "\(therapist.greeting)\n\n\(base)"
    }

    private func therapistMemoryOpeningFocus(for therapist: Therapist) -> String? {
        chatStore.sessions(for: therapist)
            .filter { $0.messageCount >= 3 }
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .prefix(3)
            .flatMap { session in
                session.messages
                    .filter { $0.role == .user && !$0.isThinking }
                    .suffix(4)
                    .compactMap { Self.safeTherapyMemoryFocus($0.text, for: therapist) }
            }
            .first
    }

    private static func safeTherapyMemoryFocus(_ rawFocus: String, for therapist: Therapist) -> String? {
        let fragments = rawFocus
            .components(separatedBy: CharacterSet(charactersIn: "/\n"))
            .map { compactTherapyMemoryText($0, limit: 84) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .filter { !$0.isEmpty }

        for compact in fragments {
            if let candidate = safeTherapyMemoryFragment(compact, for: therapist) {
                return candidate
            }
        }

        return nil
    }

    private static func safeTherapyMemoryFragment(_ rawFocus: String, for therapist: Therapist) -> String? {
        var compact = rawFocus
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard compact.count >= 4 else { return nil }

        var normalized = compact.lowercased()
        let blockedExact: Set<String> = [
            "hi",
            "hello",
            "hey",
            "你好",
            "您好",
            "嗨",
            "哈喽",
            "在吗",
            "ok",
            "okay"
        ]
        guard !blockedExact.contains(normalized) else { return nil }

        let greetingFragments = [
            "hi",
            "hello",
            "hey",
            "你好",
            "您好",
            "嗨",
            "哈喽"
        ]
        for greeting in greetingFragments where normalized.hasPrefix(greeting) {
            compact = String(compact.dropFirst(greeting.count))
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            normalized = compact.lowercased()
            break
        }
        guard compact.count >= 4, !blockedExact.contains(normalized) else { return nil }

        let blockedContains = [
            therapist.id.lowercased(),
            therapist.name.lowercased(),
            therapist.name.replacingOccurrences(of: "Dr. ", with: "").lowercased(),
            "dr willow",
            "doctor",
            "therapy",
            "therapist"
        ]
        guard !blockedContains.contains(where: { !$0.isEmpty && normalized.contains($0) }) else {
            return nil
        }

        return compact
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

    var profileAvatarID: ProfileAvatarID {
        get { profileStore.avatarID }
        set { profileStore.avatarID = newValue }
    }

    var profileGender: ProfileGender {
        get { profileStore.gender }
        set { profileStore.gender = newValue }
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
        await refreshRevenueCatSubscription()
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
        await refreshRevenueCatSubscription()
        return account
    }

    @discardableResult
    func registerAccountWithPhone(displayName: String, phone: String, password: String, confirmPassword: String) throws -> LuminaAccount {
        guard password == confirmPassword else { throw LuminaAuthError.passwordMismatch }
        let account = try accountStore.registerPhone(displayName: displayName, phone: phone, password: password)
        applyAccountProfile(account)
        Task { @MainActor [weak self] in await self?.refreshRevenueCatSubscription() }
        return account
    }

    @discardableResult
    func signInWithPhone(phone: String, password: String) throws -> LuminaAccount {
        let account = try accountStore.signInPhone(phone: phone, password: password)
        applyAccountProfile(account)
        Task { @MainActor [weak self] in await self?.refreshRevenueCatSubscription() }
        return account
    }

    @discardableResult
    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?, email: String?) async throws -> LuminaAccount {
        let user = try await firebaseBackend.signInApple(idToken: idToken, rawNonce: rawNonce, fullName: fullName)
        let fallbackDisplayName = fullName.flatMap { components -> String? in
            let name = PersonNameComponentsFormatter().string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
        let account = try accountStore.signInRemoteAccount(
            provider: .apple,
            providerUserID: user.uid,
            displayName: user.displayName ?? fallbackDisplayName,
            email: user.email ?? email,
            phone: user.phoneNumber
        )
        applyAccountProfile(account)
        await refreshRevenueCatSubscription()
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
        await refreshRevenueCatSubscription()
        return account
    }

    func signOutAccount() {
        try? firebaseBackend.signOut()
        accountStore.signOut()
        subscriptionStore.update(SubscriptionState())
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
                self.restoreCloudBackedState()
                self.syncTherapyContextToCloud(for: nil)
                Task { @MainActor [weak self] in await self?.refreshRevenueCatSubscription() }
            } catch {
                print("Lumia Firebase auth sync failed: \(error.localizedDescription)")
            }
        }
    }

    func refreshSubscriptionFromCloud() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let subscription = try await self.firebaseBackend.fetchSubscriptionSnapshot()
                self.subscriptionStore.restore(subscription)
                await self.refreshRevenueCatSubscription()
            } catch {
                print("Lumia subscription fetch failed: \(error.localizedDescription)")
            }
        }
    }

    var revenueCatPlans: [RevenueCatPlan] {
        revenueCatService.plans
    }

    var isMembershipLoading: Bool {
        revenueCatService.isLoading
    }

    var membershipErrorMessage: String? {
        revenueCatService.lastError
    }

    func refreshRevenueCatSubscription() async {
        let state = await revenueCatService.refresh(appUserID: revenueCatAppUserID)
        subscriptionStore.update(state)
    }

    func purchaseSubscriptionPlan(_ planID: String) async throws {
        let state = try await revenueCatService.purchase(planID: planID, appUserID: revenueCatAppUserID)
        subscriptionStore.update(state)
    }

    func restoreRevenueCatPurchases() async throws {
        let state = try await revenueCatService.restorePurchases(appUserID: revenueCatAppUserID)
        subscriptionStore.update(state)
    }

    func applyLocalSubscriptionOverride(_ state: SubscriptionState) {
        subscriptionStore.update(state)
        scheduleSubscriptionCloudSync(delay: 100_000_000)
    }

    private var revenueCatAppUserID: String? {
        firebaseBackend.currentUser?.uid ?? accountStore.currentAccount?.id
    }

    private func restoreCloudBackedState() {
        cloudRestoreTask?.cancel()
        cloudRestoreTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled, let self else { return }

            do {
                if let profile = try await self.firebaseBackend.fetchAppProfile() {
                    self.profileStore.restore(profile)
                    if let account = self.accountStore.currentAccount {
                        self.applyAccountProfile(account)
                    }
                }
            } catch {
                print("Lumia profile cloud fetch failed: \(error.localizedDescription)")
            }

            do {
                let remoteSessionDeletions = try await self.firebaseBackend.fetchTherapySessionDeletions()
                self.chatStore.mergeCloudDeletions(remoteSessionDeletions)
            } catch {
                print("Lumia therapy deletion cloud fetch failed: \(error.localizedDescription)")
            }

            do {
                let remoteSessions = try await self.firebaseBackend.fetchTherapySessions()
                if !remoteSessions.isEmpty {
                    self.chatStore.saveSessions(remoteSessions, publish: .deferred)
                }
            } catch {
                print("Lumia therapy cloud fetch failed: \(error.localizedDescription)")
            }

            do {
                let remoteDeletions = try await self.firebaseBackend.fetchJournalDeletions()
                self.journalStore.mergeCloudDeletions(remoteDeletions)
            } catch {
                print("Lumia journal deletion cloud fetch failed: \(error.localizedDescription)")
            }

            do {
                let remoteSummaries = try await self.firebaseBackend.fetchJournalSummaries()
                self.journalStore.mergeCloudSummaries(remoteSummaries)
            } catch {
                print("Lumia journal summary cloud fetch failed: \(error.localizedDescription)")
            }

            do {
                let insight = try await self.firebaseBackend.fetchLatestDailyJournalInsights()
                self.journalInsightStore.mergeCloudInsight(insight)
            } catch {
                print("Lumia journal insight cloud fetch failed: \(error.localizedDescription)")
            }

            do {
                if let remoteGarden = try await self.firebaseBackend.fetchGardenState() {
                    self.gardenStore.mergeCloudState(remoteGarden)
                }
                self.backfillJournalMemoryPlants()
            } catch {
                print("Lumia garden cloud fetch failed: \(error.localizedDescription)")
            }

            do {
                let subscription = try await self.firebaseBackend.fetchSubscriptionSnapshot()
                self.subscriptionStore.restore(subscription)
            } catch {
                print("Lumia subscription fetch failed: \(error.localizedDescription)")
            }

            self.savePersistedState()
            self.scheduleUserProfileCloudSync(delay: 250_000_000)
            self.syncPendingTherapySessionDeletionsToCloud()
            self.syncPendingJournalDeletionsToCloud()
            self.scheduleAllJournalSummariesCloudSync()
            self.scheduleGardenCloudSync(delay: 450_000_000)
            self.scheduleSubscriptionCloudSync(delay: 450_000_000)
            self.cloudRestoreTask = nil
        }
    }

    private func syncTherapySessionToCloud(_ session: ChatSession) {
        cloudSessionSyncTasks[session.id]?.cancel()
        cloudSessionSyncTasks[session.id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled, let self else { return }
            guard self.canAttemptCloudSync else {
                self.cloudSessionSyncTasks[session.id] = nil
                return
            }
            do {
                try await self.firebaseBackend.saveTherapySession(session)
            } catch {
                print("Lumia therapy cloud sync failed: \(error.localizedDescription)")
            }
            self.cloudSessionSyncTasks[session.id] = nil
        }
    }

    private func syncTherapySessionDeletionToCloud(_ tombstone: TherapySessionDeletionTombstone) {
        syncTherapySessionDeletionsToCloud([tombstone])
    }

    private func syncTherapySessionDeletionsToCloud(_ tombstones: [TherapySessionDeletionTombstone]) {
        guard !tombstones.isEmpty else { return }
        tombstones.forEach {
            cloudSessionSyncTasks[$0.id]?.cancel()
            cloudSessionDeletionSyncTasks[$0.id]?.cancel()
        }
        tombstones.forEach { tombstone in
            cloudSessionDeletionSyncTasks[tombstone.id] = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled, let self else { return }
                guard self.canAttemptCloudSync else {
                    self.cloudSessionDeletionSyncTasks[tombstone.id] = nil
                    self.cloudSessionSyncTasks[tombstone.id] = nil
                    return
                }
                do {
                    try await self.firebaseBackend.saveTherapySessionDeletion(tombstone)
                    try await self.firebaseBackend.deleteTherapySession(id: tombstone.id)
                } catch {
                    print("Lumia therapy deletion cloud sync failed: \(error.localizedDescription)")
                }
                self.cloudSessionDeletionSyncTasks[tombstone.id] = nil
                self.cloudSessionSyncTasks[tombstone.id] = nil
            }
        }
    }

    private func syncPendingTherapySessionDeletionsToCloud() {
        cloudSessionDeletionBulkSyncTask?.cancel()
        cloudSessionDeletionBulkSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, let self else { return }
            let tombstones = self.chatStore.deletionTombstones
            guard !tombstones.isEmpty else {
                self.cloudSessionDeletionBulkSyncTask = nil
                return
            }
            guard self.canAttemptCloudSync else {
                self.cloudSessionDeletionBulkSyncTask = nil
                return
            }
            do {
                try await self.firebaseBackend.saveTherapySessionDeletions(tombstones)
                for tombstone in tombstones {
                    try await self.firebaseBackend.deleteTherapySession(id: tombstone.id)
                }
            } catch {
                print("Lumia pending therapy deletion sync failed: \(error.localizedDescription)")
            }
            self.cloudSessionDeletionBulkSyncTask = nil
        }
    }

    func syncTherapyContextToCloud(for therapist: Therapist?) {
        let snapshot = wellbeingContext(for: therapist)
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.canAttemptCloudSync else { return }
            do {
                try await self.firebaseBackend.saveTherapyContext(snapshot, therapistID: therapist?.id)
            } catch {
                print("Lumia therapy context cloud sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func syncJournalSummaryToCloud(_ entry: JournalEntry) {
        cloudJournalSummarySyncTasks[entry.id]?.cancel()
        cloudJournalSummarySyncTasks[entry.id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled, let self else { return }
            guard self.canAttemptCloudSync else {
                self.cloudJournalSummarySyncTasks[entry.id] = nil
                return
            }
            do {
                try await self.firebaseBackend.saveJournalSummary(entry)
            } catch {
                print("Lumia journal summary cloud sync failed: \(error.localizedDescription)")
            }
            self.cloudJournalSummarySyncTasks[entry.id] = nil
        }
    }

    private func scheduleAllJournalSummariesCloudSync() {
        cloudJournalBulkSyncTask?.cancel()
        cloudJournalBulkSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled, let self else { return }
            guard self.canAttemptCloudSync else {
                self.cloudJournalBulkSyncTask = nil
                return
            }
            do {
                try await self.firebaseBackend.saveJournalSummaries(self.journalStore.entries)
            } catch {
                print("Lumia journal summaries cloud sync failed: \(error.localizedDescription)")
            }
            self.cloudJournalBulkSyncTask = nil
        }
    }

    private func syncJournalDeletionToCloud(_ tombstone: JournalDeletionTombstone) {
        cloudJournalSummarySyncTasks[tombstone.id]?.cancel()
        cloudJournalDeletionSyncTasks[tombstone.id]?.cancel()
        cloudJournalDeletionSyncTasks[tombstone.id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled, let self else { return }
            guard self.canAttemptCloudSync else {
                self.cloudJournalDeletionSyncTasks[tombstone.id] = nil
                self.cloudJournalSummarySyncTasks[tombstone.id] = nil
                return
            }
            do {
                try await self.firebaseBackend.saveJournalDeletion(tombstone)
                try await self.firebaseBackend.deleteJournalSummary(id: tombstone.id)
            } catch {
                print("Lumia journal deletion cloud sync failed: \(error.localizedDescription)")
            }
            self.cloudJournalDeletionSyncTasks[tombstone.id] = nil
            self.cloudJournalSummarySyncTasks[tombstone.id] = nil
        }
    }

    private func syncPendingJournalDeletionsToCloud() {
        cloudJournalDeletionBulkSyncTask?.cancel()
        cloudJournalDeletionBulkSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, let self else { return }
            let tombstones = self.journalStore.deletionTombstones
            guard !tombstones.isEmpty else {
                self.cloudJournalDeletionBulkSyncTask = nil
                return
            }
            guard self.canAttemptCloudSync else {
                self.cloudJournalDeletionBulkSyncTask = nil
                return
            }
            do {
                try await self.firebaseBackend.saveJournalDeletions(tombstones)
                for tombstone in tombstones {
                    try await self.firebaseBackend.deleteJournalSummary(id: tombstone.id)
                }
            } catch {
                print("Lumia pending journal deletion sync failed: \(error.localizedDescription)")
            }
            self.cloudJournalDeletionBulkSyncTask = nil
        }
    }

    private func syncPendingCloudWorkAfterReconnect() {
        chatStore.chatSessions.values.forEach(syncTherapySessionToCloud)
        syncPendingTherapySessionDeletionsToCloud()
        syncPendingJournalDeletionsToCloud()
        scheduleAllJournalSummariesCloudSync()
        scheduleUserProfileCloudSync(delay: 250_000_000)
        scheduleGardenCloudSync(delay: 450_000_000)
        scheduleSubscriptionCloudSync(delay: 450_000_000)
    }

    private func syncDailyJournalInsightsToCloud(_ insights: DailyJournalInsights) {
        cloudJournalInsightSyncTask?.cancel()
        cloudJournalInsightSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, let self else { return }
            guard self.canAttemptCloudSync else {
                self.cloudJournalInsightSyncTask = nil
                return
            }
            do {
                try await self.firebaseBackend.saveDailyJournalInsights(insights)
            } catch {
                print("Lumia journal insight cloud sync failed: \(error.localizedDescription)")
            }
            self.cloudJournalInsightSyncTask = nil
        }
    }

    private func deleteDailyJournalInsightsFromCloud(dateKey: String) {
        cloudJournalInsightSyncTask?.cancel()
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.canAttemptCloudSync else {
                self.cloudJournalInsightSyncTask = nil
                return
            }
            do {
                try await self.firebaseBackend.deleteDailyJournalInsights(dateKey: dateKey)
            } catch {
                print("Lumia journal insight cloud delete failed: \(error.localizedDescription)")
            }
            self.cloudJournalInsightSyncTask = nil
        }
    }

    private func scheduleUserProfileCloudSync(delay: UInt64 = 850_000_000) {
        cloudProfileSyncTask?.cancel()
        cloudProfileSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, let self else { return }
            guard self.canAttemptCloudSync else {
                self.cloudProfileSyncTask = nil
                return
            }
            do {
                try await self.firebaseBackend.saveAppProfile(self.profileStore.snapshot(), account: self.accountStore.currentAccount)
            } catch {
                print("Lumia profile cloud sync failed: \(error.localizedDescription)")
            }
            self.cloudProfileSyncTask = nil
        }
    }

    private func scheduleSubscriptionCloudSync(delay: UInt64 = 850_000_000) {
        cloudSubscriptionSyncTask?.cancel()
        cloudSubscriptionSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, let self else { return }
            guard self.canAttemptCloudSync else {
                self.cloudSubscriptionSyncTask = nil
                return
            }
            do {
                try await self.firebaseBackend.saveSubscriptionSnapshot(self.subscriptionStore.snapshot())
            } catch {
                print("Lumia subscription sync failed: \(error.localizedDescription)")
            }
            self.cloudSubscriptionSyncTask = nil
        }
    }

    private func scheduleGardenCloudSync(delay: UInt64 = 900_000_000) {
        cloudGardenSyncTask?.cancel()
        cloudGardenSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, let self else { return }
            guard self.canAttemptCloudSync else {
                self.cloudGardenSyncTask = nil
                return
            }
            do {
                try await self.firebaseBackend.saveGardenState(self.gardenStore.snapshot())
            } catch {
                print("Lumia garden cloud sync failed: \(error.localizedDescription)")
            }
            self.cloudGardenSyncTask = nil
        }
    }

    private var canAttemptCloudSync: Bool {
        isNetworkAvailable && firebaseBackend.currentUser != nil
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

    var subscriptionAllowance: SubscriptionAllowance {
        subscriptionStore.allowance
    }

    var hasPremiumAccess: Bool {
        subscriptionStore.hasPremiumAccess
    }

    func canUse(_ feature: PremiumFeature) -> Bool {
        subscriptionStore.canUse(feature)
    }

    func canStartAIChatReply() -> Bool {
        subscriptionStore.canStartAIChatReply()
    }

    func canStartLiveCall() -> Bool {
        subscriptionStore.canStartLiveCall()
    }

    func recordAIChatReplyUsed() {
        subscriptionStore.recordAIChatReply()
        scheduleSubscriptionCloudSync(delay: 100_000_000)
    }

    func recordLiveCallSeconds(_ seconds: Int) {
        subscriptionStore.recordLiveCall(seconds: seconds)
        scheduleSubscriptionCloudSync(delay: 100_000_000)
    }
}
