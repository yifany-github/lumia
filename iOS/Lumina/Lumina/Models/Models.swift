import Foundation

// MARK: - Therapist / AI Companion

struct Therapist: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    let description: String
    let avatarUrl: String
    let accentHex: UInt
    let greeting: String
    let systemInstruction: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Therapist, rhs: Therapist) -> Bool { lhs.id == rhs.id }
}

let allTherapists: [Therapist] = [
    Therapist(
        id: "willow",
        name: "Dr. Willow",
        role: "Growth & Structure",
        description: "A grounded guide who uses CBT principles to help you break down problems into actionable steps.",
        avatarUrl: "https://api.dicebear.com/7.x/notionists/svg?seed=Willow&backgroundColor=e6dccd&brows=variant10&eyes=variant04",
        accentHex: 0x5D7052,
        greeting: "Hello. Let's take a breath together. What is on your mind today that we can untangle?",
        systemInstruction: "You are Dr. Willow, a grounded and practical AI therapist. You use Cognitive Behavioral Therapy (CBT) principles. Your tone is calm, professional, yet warm. You help users identify negative thought patterns (cognitive distortions) and offer small, actionable steps. Avoid toxic positivity. Focus on growth, stability, and problem-solving. Keep responses concise and empathetic."
    ),
    Therapist(
        id: "serena",
        name: "Serena",
        role: "Warmth & Empathy",
        description: "A compassionate listener who offers a safe space for emotional validation and comfort.",
        avatarUrl: "https://api.dicebear.com/7.x/notionists/svg?seed=Serena&backgroundColor=ffe0b2&hair=variant12&glasses=variant03",
        accentHex: 0xC18C5D,
        greeting: "Hi there. I'm here to listen with an open heart. How are you feeling right now?",
        systemInstruction: "You are Serena, a warm and deeply empathetic AI companion. Your goal is emotional validation. You listen actively, reflect the user's feelings, and offer comfort. Your tone is gentle, affectionate, and soothing. You make the user feel heard and understood. You prioritize emotional safety above solutions. Keep responses concise and warm."
    ),
    Therapist(
        id: "atlas",
        name: "Atlas",
        role: "Perspective & Stoicism",
        description: "A calm presence to help you find resilience and objective perspective in difficult times.",
        avatarUrl: "https://api.dicebear.com/7.x/notionists/svg?seed=Marcus&backgroundColor=e0e0e0",
        accentHex: 0x78786C,
        greeting: "Greetings. The mountain stands still amidst the storm. Let us look at your challenges with clarity.",
        systemInstruction: "You are Atlas, a stoic and calm AI mentor. You help users find perspective and resilience. You draw upon Stoic philosophy. Your tone is steady, deep, and reassuring. You do not coddle, but you empower the user to find strength within their own character. Keep responses concise."
    ),
    Therapist(
        id: "nimbus",
        name: "Nimbus",
        role: "Mindfulness & Flow",
        description: "A gentle guide for meditation, breathing, and finding the present moment.",
        avatarUrl: "https://api.dicebear.com/7.x/notionists/svg?seed=Nimbus&backgroundColor=bbdefb&lips=variant05",
        accentHex: 0x4A90E2,
        greeting: "Breathe in... and breathe out. I am here to help you return to the present moment.",
        systemInstruction: "You are Nimbus, a mindfulness and meditation coach. Your speech is slow, poetic, and rhythmic. You encourage deep breathing and grounding techniques. You help users detach from anxiety about the future or regret about the past. Focus on the 'now', sensory details, and acceptance. Keep responses concise and peaceful."
    ),
    Therapist(
        id: "nova",
        name: "Nova",
        role: "Purpose & Drive",
        description: "An energetic coach to help you overcome burnout, set goals, and rediscover your spark.",
        avatarUrl: "https://api.dicebear.com/7.x/notionists/svg?seed=Nova&backgroundColor=ffecb3&hair=variant32&glasses=variant09",
        accentHex: 0xD97706,
        greeting: "Ready to ignite your potential? Let's turn those obstacles into stepping stones.",
        systemInstruction: "You are Nova, a motivational coach and career strategist. Your tone is energetic, encouraging, and forward-looking. You specialize in overcoming burnout, imposter syndrome, and procrastination. You use techniques from Positive Psychology and Coaching. Keep responses concise and energizing."
    ),
    Therapist(
        id: "eden",
        name: "Eden",
        role: "Connection & Harmony",
        description: "A relationship expert focused on healthy communication, setting boundaries, and social dynamics.",
        avatarUrl: "https://api.dicebear.com/7.x/notionists/svg?seed=Eden&backgroundColor=f8bbd0&hair=variant46",
        accentHex: 0xBE185D,
        greeting: "Relationships act as mirrors. Tell me about the connections you're navigating today.",
        systemInstruction: "You are Eden, a specialist in interpersonal relationships and family dynamics. You focus on attachment theory, non-violent communication (NVC), and setting healthy boundaries. Your tone is gentle but firm when it comes to self-respect. Keep responses concise and relational."
    ),
    Therapist(
        id: "orion",
        name: "Orion",
        role: "Logic & Clarity",
        description: "An analytical mind to help you untangle complex situations through logic and reason.",
        avatarUrl: "https://api.dicebear.com/7.x/notionists/svg?seed=Orion&backgroundColor=b2dfdb&glasses=variant02&beard=variant08",
        accentHex: 0x0F766E,
        greeting: "Let us examine the facts. I am here to help you analyze the situation objectively.",
        systemInstruction: "You are Orion, a logical and analytical advisor. You use Socratic questioning and critical thinking. You help remove emotional fog to see the facts. Your tone is precise, intellectual, and objective. Keep responses concise and analytical."
    ),
    Therapist(
        id: "luna",
        name: "Luna",
        role: "Dreams & Depth",
        description: "A muse for your subconscious. Explore dreams, artistic blocks, and the deeper symbols of your life.",
        avatarUrl: "https://api.dicebear.com/7.x/notionists/svg?seed=Luna&backgroundColor=d1c4e9&hair=variant58",
        accentHex: 0x6D28D9,
        greeting: "The night whispers secrets. Share your dreams or creative thoughts, and let us find their meaning.",
        systemInstruction: "You are Luna, a guide to the subconscious and creativity. You draw from Jungian psychology (archetypes, shadow work) and art therapy. Your tone is mystical, intuitive, and abstract. You help users interpret dreams and explore the deeper, symbolic meaning of their experiences. Keep responses concise and evocative."
    )
]

// MARK: - Chat

struct ChatMessage: Identifiable, Codable {
    let id: String
    let role: MessageRole
    let text: String
    var isThinking: Bool = false
}

enum MessageRole: String, Codable {
    case user, model
}

enum ConversationState: String, Codable {
    case checkIn
    case triage
    case listen
    case coach
    case plan
    case crisis
    case fallback
    case wrapUp
}

enum UserIntent: String, Codable {
    case listening
    case coaching
    case planning
    case crisis
    case unsure
}

enum RiskLevel: Int, Comparable, Codable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum InterventionKind: String, CaseIterable, Identifiable, Codable {
    case reflectiveListening
    case affectLabeling
    case grounding
    case breathing
    case ifThenPlan
    case journalingPrompt
    case crisisSupport
    case fallbackClarification
    case wrapUp

    var id: String { rawValue }
}

struct InterventionScript: Identifiable {
    let kind: InterventionKind
    let title: String
    let userFacingSummary: String
    let promptGuidance: String

    var id: String { kind.rawValue }
}

struct InterventionLibrary {
    static let shared = InterventionLibrary()

    let affirmations = [
        "I am allowed to move slowly and still move forward.",
        "My feelings are real, and they do not have to decide my whole day.",
        "One small grounded action is enough for this moment.",
        "I can ask for support before things become unbearable.",
        "Rest can be part of recovery, not a failure of effort.",
        "I can notice a thought without having to obey it.",
        "A difficult moment can be met one breath at a time.",
        "I do not need to solve everything before taking the next step."
    ]

    private let scripts: [InterventionKind: InterventionScript] = [
        .reflectiveListening: InterventionScript(
            kind: .reflectiveListening,
            title: "Reflective Listening",
            userFacingSummary: "Name what is being carried and help the user feel understood before moving toward action.",
            promptGuidance: "Reflect the user's situation in one or two sentences, name a likely emotion tentatively, and ask at most one open question."
        ),
        .affectLabeling: InterventionScript(
            kind: .affectLabeling,
            title: "Affect Labeling",
            userFacingSummary: "Turn a vague feeling into a gentler, more specific emotional label.",
            promptGuidance: "Offer one or two possible emotion labels using tentative language such as 'it sounds like' or 'maybe', without claiming certainty."
        ),
        .grounding: InterventionScript(
            kind: .grounding,
            title: "Grounding",
            userFacingSummary: "Bring attention back to the body and surroundings when the user feels flooded.",
            promptGuidance: "Suggest one brief grounding action that can be done immediately, such as naming three visible objects or feeling both feet on the floor."
        ),
        .breathing: InterventionScript(
            kind: .breathing,
            title: "Box Breathing",
            userFacingSummary: "A 4-4-4-4 breath pattern for a short nervous-system reset.",
            promptGuidance: "If the user wants calming, offer a short breathing reset: inhale 4, hold 4, exhale 4, hold 4. Do not overstate medical effects."
        ),
        .ifThenPlan: InterventionScript(
            kind: .ifThenPlan,
            title: "If-Then Plan",
            userFacingSummary: "Convert an intention into one tiny action tied to a real trigger.",
            promptGuidance: "Create one tiny implementation intention in the format: If [specific trigger], then I will [small action]. Keep it realistic for low-energy moments."
        ),
        .journalingPrompt: InterventionScript(
            kind: .journalingPrompt,
            title: "Journal Prompt",
            userFacingSummary: "Give the user a simple reflection prompt when words are hard to find.",
            promptGuidance: "Offer one concise journaling prompt that helps clarify the feeling, need, or next step."
        ),
        .crisisSupport: InterventionScript(
            kind: .crisisSupport,
            title: "Crisis Support",
            userFacingSummary: "Prioritize immediate safety and nearby human support.",
            promptGuidance: "Prioritize immediate safety, local emergency or crisis resources, and moving near a trusted person. Do not continue normal coaching."
        ),
        .fallbackClarification: InterventionScript(
            kind: .fallbackClarification,
            title: "Clarify",
            userFacingSummary: "Offer a simple choice when the user's need is unclear.",
            promptGuidance: "Briefly state uncertainty and offer three choices: listen, think through options, or make a small plan."
        ),
        .wrapUp: InterventionScript(
            kind: .wrapUp,
            title: "Wrap-Up",
            userFacingSummary: "Close with one remembered insight and one gentle next step.",
            promptGuidance: "Summarize the useful point in one sentence and suggest one tiny follow-up check for later."
        )
    ]

    func script(for kind: InterventionKind) -> InterventionScript {
        scripts[kind] ?? scripts[.reflectiveListening]!
    }

    func primaryIntervention(for state: ConversationState) -> InterventionKind? {
        switch state {
        case .listen:
            return .reflectiveListening
        case .coach:
            return .grounding
        case .plan:
            return .ifThenPlan
        case .crisis:
            return .crisisSupport
        case .fallback, .triage, .checkIn:
            return .fallbackClarification
        case .wrapUp:
            return .wrapUp
        }
    }

    func interventions(for state: ConversationState) -> [InterventionScript] {
        switch state {
        case .listen:
            return [.reflectiveListening, .affectLabeling].map(script)
        case .coach:
            return [.grounding, .breathing, .journalingPrompt].map(script)
        case .plan:
            return [.ifThenPlan, .wrapUp].map(script)
        case .crisis:
            return [.crisisSupport].map(script)
        case .fallback, .triage, .checkIn:
            return [.fallbackClarification, .reflectiveListening].map(script)
        case .wrapUp:
            return [.wrapUp].map(script)
        }
    }

    func promptGuidance(for state: ConversationState) -> String {
        interventions(for: state)
            .map { "- \($0.title): \($0.promptGuidance)" }
            .joined(separator: "\n")
    }
}

struct MicroPlan: Identifiable, Codable {
    let id: String
    var trigger: String
    var action: String
    var support: String?
    var sourceSessionID: String?
    var createdAt: TimeInterval

    init(
        id: String = UUID().uuidString,
        trigger: String,
        action: String,
        support: String? = nil,
        sourceSessionID: String? = nil,
        createdAt: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.support = support
        self.sourceSessionID = sourceSessionID
        self.createdAt = createdAt
    }
}

enum FollowUpStatus: String, Codable {
    case pending
    case completed
    case skipped
    case tooHard
}

struct FollowUp: Identifiable, Codable {
    let id: String
    var microPlanID: String
    var habitID: String?
    var sourceSessionID: String?
    var prompt: String
    var trigger: String
    var action: String
    var createdAt: TimeInterval
    var dueAt: TimeInterval
    var status: FollowUpStatus
    var respondedAt: TimeInterval?

    init(
        id: String = UUID().uuidString,
        microPlanID: String,
        habitID: String? = nil,
        sourceSessionID: String? = nil,
        prompt: String,
        trigger: String,
        action: String,
        createdAt: TimeInterval = Date().timeIntervalSince1970,
        dueAt: TimeInterval,
        status: FollowUpStatus = .pending,
        respondedAt: TimeInterval? = nil
    ) {
        self.id = id
        self.microPlanID = microPlanID
        self.habitID = habitID
        self.sourceSessionID = sourceSessionID
        self.prompt = prompt
        self.trigger = trigger
        self.action = action
        self.createdAt = createdAt
        self.dueAt = dueAt
        self.status = status
        self.respondedAt = respondedAt
    }
}

enum HealthPermissionState: String, Codable {
    case unavailable
    case notDetermined
    case requestCompleted
    case denied
}

enum NotificationPermissionState: String, Codable {
    case notDetermined
    case authorized
    case denied
    case provisional
    case ephemeral
    case unknown
}

struct NotificationNavigationRequest: Identifiable, Equatable {
    let id: String
    var notificationType: String
    var decisionID: String?
    var destinationTab: Int?

    init(
        id: String = UUID().uuidString,
        notificationType: String,
        decisionID: String? = nil,
        destinationTab: Int? = nil
    ) {
        self.id = id
        self.notificationType = notificationType
        self.decisionID = decisionID
        self.destinationTab = destinationTab
    }
}

struct DailyHealthSummary: Identifiable, Codable {
    let id: String
    var date: Date
    var stepCount: Double?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Double?
    var sleepMinutes: Double?
    var restingHeartRate: Double?
    var averageHeartRate: Double?
    var syncedAt: TimeInterval

    init(
        id: String = UUID().uuidString,
        date: Date,
        stepCount: Double? = nil,
        activeEnergyKcal: Double? = nil,
        exerciseMinutes: Double? = nil,
        sleepMinutes: Double? = nil,
        restingHeartRate: Double? = nil,
        averageHeartRate: Double? = nil,
        syncedAt: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.date = date
        self.stepCount = stepCount
        self.activeEnergyKcal = activeEnergyKcal
        self.exerciseMinutes = exerciseMinutes
        self.sleepMinutes = sleepMinutes
        self.restingHeartRate = restingHeartRate
        self.averageHeartRate = averageHeartRate
        self.syncedAt = syncedAt
    }
}

struct HealthBaseline: Codable {
    var windowDays: Int
    var averageSleepMinutes: Double?
    var averageSteps: Double?
    var averageActiveEnergyKcal: Double?
    var averageExerciseMinutes: Double?
    var averageRestingHeartRate: Double?

    var hasAnySignal: Bool {
        averageSleepMinutes != nil ||
        averageSteps != nil ||
        averageActiveEnergyKcal != nil ||
        averageExerciseMinutes != nil ||
        averageRestingHeartRate != nil
    }
}

enum JITAIPromptKind: String, Codable {
    case recovery
    case movement
    case reflection
    case grounding
    case garden
}

enum JITAIUserResponse: String, Codable {
    case shown
    case accepted
    case dismissed
    case suppressed
}

struct JITAIDecision: Identifiable, Codable {
    let id: String
    var kind: JITAIPromptKind
    var title: String
    var message: String
    var actionTitle: String
    var destinationTab: Int
    var confidence: Double
    var reasonCodes: [String]
    var createdAt: TimeInterval
    var expiresAt: TimeInterval
    var sourceID: String?
}

struct JITAIInteractionLog: Identifiable, Codable {
    let id: String
    var decisionID: String
    var kind: JITAIPromptKind
    var response: JITAIUserResponse
    var reasonCodes: [String]
    var confidence: Double
    var createdAt: TimeInterval

    init(
        id: String = UUID().uuidString,
        decisionID: String,
        kind: JITAIPromptKind,
        response: JITAIUserResponse,
        reasonCodes: [String],
        confidence: Double,
        createdAt: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.decisionID = decisionID
        self.kind = kind
        self.response = response
        self.reasonCodes = reasonCodes
        self.confidence = confidence
        self.createdAt = createdAt
    }
}

struct PromptPolicyVersion: Codable {
    let id: String
    let version: String
    let summary: String

    var displayName: String {
        "\(id) \(version)"
    }

    static let therapySupportV1 = PromptPolicyVersion(
        id: "therapy-support",
        version: "v1",
        summary: "Safety-first Listen / Coach / Plan state machine with local crisis triage."
    )

    static let jitaiLocalV1 = PromptPolicyVersion(
        id: "jitai-local",
        version: "v1",
        summary: "Local in-app recommendations with reason codes, daily cap, quiet hours, and user suppression."
    )
}

enum InterventionLogSource: String, Codable {
    case therapy
    case jitai
    case sanctuary
    case garden
    case followUp
}

enum InterventionOutcome: String, Codable {
    case shown
    case accepted
    case dismissed
    case suppressed
    case completed
    case snoozed
    case tooHard
    case crisisRouted
}

enum SafetyEventKind: String, Codable {
    case mediumRiskTriage
    case crisisRoute
    case falsePositiveFeedback
    case userControlAction
}

struct InterventionLog: Identifiable, Codable {
    let id: String
    var source: InterventionLogSource
    var interventionKind: InterventionKind?
    var promptPolicyID: String
    var promptPolicyVersion: String
    var reasonCodes: [String]
    var confidence: Double?
    var outcome: InterventionOutcome
    var riskLevel: RiskLevel
    var sessionID: String?
    var createdAt: TimeInterval

    init(
        id: String = UUID().uuidString,
        source: InterventionLogSource,
        interventionKind: InterventionKind?,
        policy: PromptPolicyVersion,
        reasonCodes: [String],
        confidence: Double? = nil,
        outcome: InterventionOutcome,
        riskLevel: RiskLevel = .none,
        sessionID: String? = nil,
        createdAt: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.source = source
        self.interventionKind = interventionKind
        self.promptPolicyID = policy.id
        self.promptPolicyVersion = policy.version
        self.reasonCodes = reasonCodes
        self.confidence = confidence
        self.outcome = outcome
        self.riskLevel = riskLevel
        self.sessionID = sessionID
        self.createdAt = createdAt
    }
}

struct CheckInMetric: Identifiable, Codable {
    let id: String
    var moodScore: Int
    var stressScore: Int
    var note: String?
    var createdAt: TimeInterval

    init(
        id: String = UUID().uuidString,
        moodScore: Int,
        stressScore: Int,
        note: String? = nil,
        createdAt: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.moodScore = max(0, min(10, moodScore))
        self.stressScore = max(0, min(10, stressScore))
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : note
        self.createdAt = createdAt
    }
}

struct SafetyEvent: Identifiable, Codable {
    let id: String
    var kind: SafetyEventKind
    var riskLevel: RiskLevel
    var reasonCodes: [String]
    var sourceID: String?
    var note: String?
    var createdAt: TimeInterval

    init(
        id: String = UUID().uuidString,
        kind: SafetyEventKind,
        riskLevel: RiskLevel,
        reasonCodes: [String],
        sourceID: String? = nil,
        note: String? = nil,
        createdAt: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.kind = kind
        self.riskLevel = riskLevel
        self.reasonCodes = reasonCodes
        self.sourceID = sourceID
        self.note = note
        self.createdAt = createdAt
    }
}

enum WellbeingSignalSource: String, Codable {
    case checkIn
    case journal
    case health
    case garden
    case followUp
}

enum WellbeingSignalTone: String, Codable {
    case steady
    case attention
    case recovery
    case progress
}

struct WellbeingSignal: Identifiable, Codable {
    let id: String
    var source: WellbeingSignalSource
    var tone: WellbeingSignalTone
    var title: String
    var detail: String
    var reasonCodes: [String]
    var confidence: Double
    var createdAt: TimeInterval

    init(
        id: String = UUID().uuidString,
        source: WellbeingSignalSource,
        tone: WellbeingSignalTone,
        title: String,
        detail: String,
        reasonCodes: [String],
        confidence: Double,
        createdAt: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.source = source
        self.tone = tone
        self.title = title
        self.detail = detail
        self.reasonCodes = reasonCodes
        self.confidence = min(max(confidence, 0), 1)
        self.createdAt = createdAt
    }
}

struct WellbeingContextSnapshot: Identifiable, Codable {
    let id: String
    var generatedAt: TimeInterval
    var headline: String
    var summary: String
    var confidence: Double
    var signals: [WellbeingSignal]
    var journalBridge: JournalTherapyContextBridge?

    var primarySignal: WellbeingSignal? {
        signals.first
    }

    var therapyPromptBrief: String? {
        guard !signals.isEmpty || !(journalBridge?.isEmpty ?? true) else { return nil }
        let signalLines = signals.isEmpty
            ? "- No strong wellbeing signals today."
            : signals.prefix(4).map { signal in
                "- \(signal.source.promptLabel): \(signal.title). \(signal.detail) Reason codes: \(signal.reasonCodes.joined(separator: ", "))."
            }.joined(separator: "\n")

        let journalSection = journalBridge?.promptSection ?? ""

        return """
        Local wellbeing context brief from Lumia:
        - This brief is derived from user-visible local app data.
        - It contains no raw Health samples and must not be treated as diagnosis or proof of mood.
        - Prefer explicit self-report over passive context.
        - Journal context is summarized; do not quote private journal text back unless the user explicitly asks.

        Headline: \(headline)
        Summary: \(summary)
        Confidence: \(Int((confidence * 100).rounded()))%

        Signals:
        \(signalLines)
        \(journalSection)

        Use this only to adapt tone, pressure level, and intervention choice. Do not mention Health or sensor context unless the user asks or it is directly relevant.
        """
    }

    var therapyReasonCodes: [String] {
        let signalCodes = signals.flatMap(\.reasonCodes)
        let journalCodes = journalBridge?.reasonCodes ?? []
        guard !signalCodes.isEmpty || !journalCodes.isEmpty else { return [] }
        return Array(Set(["context.brief.used"] + signalCodes + journalCodes)).sorted()
    }
}

struct JournalTherapyContextBridge: Codable {
    var entryCount: Int
    var moodPattern: String?
    var recurringThemes: [String]
    var usefulReflections: [String]
    var savedActions: [String]
    var latestNote: String?
    var generatedAt: TimeInterval

    var isEmpty: Bool {
        entryCount == 0 &&
        moodPattern == nil &&
        recurringThemes.isEmpty &&
        usefulReflections.isEmpty &&
        savedActions.isEmpty &&
        latestNote == nil
    }

    var promptSection: String? {
        guard !isEmpty else { return nil }
        var lines: [String] = [
            "",
            "Recent reflection context:",
            "- Window: last 14 days, summarized from \(entryCount) journal entr\(entryCount == 1 ? "y" : "ies")."
        ]
        if let moodPattern {
            lines.append("- Mood pattern: \(moodPattern)")
        }
        if !recurringThemes.isEmpty {
            lines.append("- Recurring themes: \(recurringThemes.prefix(5).joined(separator: ", ")).")
        }
        if !usefulReflections.isEmpty {
            lines.append("- Useful reflections: \(usefulReflections.prefix(3).joined(separator: " / "))")
        }
        if !savedActions.isEmpty {
            lines.append("- Saved action items: \(savedActions.prefix(3).joined(separator: " / "))")
        }
        if let latestNote {
            lines.append("- Latest journal signal: \(latestNote)")
        }
        lines.append("- Use this to be more personally relevant while staying gentle. Do not imply surveillance or certainty.")
        return lines.joined(separator: "\n")
    }

    var reasonCodes: [String] {
        guard !isEmpty else { return [] }
        var codes = ["journal.bridge.used"]
        if !recurringThemes.isEmpty { codes.append("journal.themes.available") }
        if !usefulReflections.isEmpty { codes.append("journal.reflections.available") }
        if !savedActions.isEmpty { codes.append("journal.actions.available") }
        return codes
    }
}

enum JournalTherapyContextBridgeEngine {
    static func make(entries: [JournalEntry], therapistID: String? = nil, now: Date = Date()) -> JournalTherapyContextBridge? {
        let cutoff = now.timeIntervalSince1970 - 14 * 86_400
        let recent = entries
            .filter {
                $0.timestamp >= cutoff
                && $0.therapyMemoryPolicy != .excluded
                && !$0.id.hasPrefix("therapy-summary-")
            }
            .sorted { $0.timestamp > $1.timestamp }

        guard !recent.isEmpty else { return nil }

        let prioritized = prioritize(recent, therapistID: therapistID)
        let moodPattern = summarizeMoodPattern(from: prioritized)
        let themes = extractThemes(from: prioritized, therapistID: therapistID)
        let reflections = prioritized.compactMap { entry in
            sanitize(entry.reflection ?? entry.summary, limit: 145)
        }
        let actions = prioritized.compactMap { entry in
            sanitize(entry.actionItem, limit: 110)
        }
        let latest = latestSignal(from: prioritized.first)

        return JournalTherapyContextBridge(
            entryCount: recent.count,
            moodPattern: moodPattern,
            recurringThemes: Array(themes.prefix(5)),
            usefulReflections: Array(reflections.prefix(3)),
            savedActions: Array(actions.prefix(3)),
            latestNote: latest,
            generatedAt: now.timeIntervalSince1970
        )
    }

    private static func prioritize(_ entries: [JournalEntry], therapistID: String?) -> [JournalEntry] {
        entries.sorted { lhs, rhs in
            let left = score(lhs, therapistID: therapistID)
            let right = score(rhs, therapistID: therapistID)
            if left == right { return lhs.timestamp > rhs.timestamp }
            return left > right
        }
    }

    private static func score(_ entry: JournalEntry, therapistID: String?) -> Int {
        var score = entry.therapyMemoryPolicy == .included ? 20 : 0
        let text = [
            entry.title,
            entry.content,
            entry.summary ?? "",
            entry.reflection ?? "",
            entry.actionItem ?? "",
            entry.tags.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        switch therapistID {
        case "willow":
            score += matches(["thought", "pattern", "stuck", "stress", "pressure", "action", "step", "plan", "avoid", "procrastinate"], in: text)
            if entry.actionItem != nil { score += 6 }
        case "serena":
            score += matches(["feel", "felt", "sad", "lonely", "hurt", "overwhelmed", "cry", "comfort", "seen", "emotion"], in: text)
            if entry.reflection != nil { score += 5 }
        case "eden":
            score += matches(["relationship", "partner", "friend", "family", "conflict", "boundary", "mother", "father", "communication"], in: text)
        case "nimbus":
            score += matches(["anxiety", "anxious", "panic", "sleep", "body", "breath", "tension", "restless", "worry"], in: text)
            if (entry.anxietyLevel ?? 0) >= 60 { score += 5 }
        case "nova":
            score += matches(["burnout", "goal", "motivation", "energy", "career", "finish", "start", "drive"], in: text)
            if entry.actionItem != nil { score += 4 }
        case "atlas":
            score += matches(["control", "accept", "resilience", "hard", "challenge", "perspective", "fear"], in: text)
        case "orion":
            score += matches(["decision", "facts", "logic", "confused", "choice", "reason", "think"], in: text)
        case "luna":
            score += matches(["dream", "creative", "symbol", "meaning", "art", "memory", "subconscious"], in: text)
        default:
            score += 0
        }
        return score
    }

    private static func summarizeMoodPattern(from entries: [JournalEntry]) -> String? {
        let grouped = Dictionary(grouping: entries, by: \.mood)
        let sortedMoods = grouped.sorted { lhs, rhs in
            if lhs.value.count == rhs.value.count {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.value.count > rhs.value.count
        }
        guard let primary = sortedMoods.first else { return nil }

        let sentimentValues = entries.compactMap(\.sentimentScore)
        let sentimentText: String
        if sentimentValues.isEmpty {
            sentimentText = "sentiment not yet scored"
        } else {
            let average = sentimentValues.reduce(0, +) / sentimentValues.count
            if average >= 70 {
                sentimentText = "mostly positive tone"
            } else if average <= 40 {
                sentimentText = "lower emotional tone"
            } else {
                sentimentText = "mixed emotional tone"
            }
        }

        return "\(primary.key.rawValue) appeared most often; \(sentimentText)."
    }

    private static func extractThemes(from entries: [JournalEntry], therapistID: String?) -> [String] {
        var keywordMap: [(label: String, keywords: [String])] = [
            ("work pressure", ["work", "job", "boss", "deadline", "meeting", "career", "school", "study", "exam", "project"]),
            ("relationship stress", ["relationship", "partner", "friend", "family", "mother", "father", "conflict", "lonely", "breakup"]),
            ("anxiety", ["anxious", "anxiety", "panic", "worry", "worried", "fear", "scared", "overthinking"]),
            ("low energy", ["tired", "exhausted", "burnout", "fatigue", "drained", "sleep", "insomnia"]),
            ("self-worth", ["failure", "worth", "enough", "guilt", "shame", "confidence", "imposter"]),
            ("motivation", ["stuck", "procrastinate", "motivation", "goal", "habit", "start", "finish"]),
            ("grief or sadness", ["sad", "grief", "loss", "cry", "miss", "hopeless"]),
            ("health or body", ["health", "body", "pain", "doctor", "exercise", "walk", "food"])
        ]

        switch therapistID {
        case "willow":
            keywordMap.insert(("thought patterns", ["thought", "pattern", "belief", "avoid", "spiral", "should", "always", "never"]), at: 0)
        case "serena":
            keywordMap.insert(("emotional validation", ["feel", "felt", "unseen", "hurt", "comfort", "soft", "heavy"]), at: 0)
        case "eden":
            keywordMap.insert(("boundaries and repair", ["boundary", "repair", "apology", "communicate", "needs", "respect"]), at: 0)
        case "nimbus":
            keywordMap.insert(("body and nervous system", ["breath", "body", "tension", "sleep", "restless", "ground"]), at: 0)
        default:
            break
        }

        let text = entries.map { entry in
            [
                entry.title,
                entry.content,
                entry.summary ?? "",
                entry.reflection ?? "",
                entry.actionItem ?? "",
                entry.tags.joined(separator: " ")
            ].joined(separator: " ")
        }
        .joined(separator: " ")
        .lowercased()

        let scored = keywordMap.compactMap { item -> (String, Int)? in
            let score = item.keywords.reduce(0) { count, keyword in
                count + occurrences(of: keyword, in: text)
            }
            return score > 0 ? (item.label, score) : nil
        }
        .sorted { lhs, rhs in
            if lhs.1 == rhs.1 { return lhs.0 < rhs.0 }
            return lhs.1 > rhs.1
        }
        .map(\.0)

        if !scored.isEmpty {
            return scored
        }

        let tags = entries
            .flatMap(\.tags)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        let groupedTags = Dictionary(grouping: tags, by: { $0 })
        return groupedTags
            .sorted { lhs, rhs in
                if lhs.value.count == rhs.value.count { return lhs.key < rhs.key }
                return lhs.value.count > rhs.value.count
            }
            .prefix(5)
            .map(\.key)
    }

    private static func latestSignal(from entry: JournalEntry?) -> String? {
        guard let entry else { return nil }
        if let summary = sanitize(entry.summary, limit: 130) {
            return summary
        }
        if let reflection = sanitize(entry.reflection, limit: 130) {
            return reflection
        }
        if !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return sanitize(entry.title, limit: 90)
        }
        return sanitize(entry.content, limit: 130)
    }

    private static func sanitize(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let compact = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compact.isEmpty else { return nil }
        if compact.count <= limit {
            return compact
        }
        let end = compact.index(compact.startIndex, offsetBy: max(0, limit - 1))
        return String(compact[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func occurrences(of keyword: String, in text: String) -> Int {
        text.components(separatedBy: keyword).count - 1
    }

    private static func matches(_ keywords: [String], in text: String) -> Int {
        keywords.reduce(0) { $0 + occurrences(of: $1, in: text) }
    }
}

private extension WellbeingSignalSource {
    var promptLabel: String {
        switch self {
        case .checkIn:
            return "Daily check-in"
        case .journal:
            return "Reflection"
        case .health:
            return "Health context"
        case .garden:
            return "Garden"
        case .followUp:
            return "Follow-up"
        }
    }
}

enum WellbeingContextEngine {
    static func make(
        entries: [JournalEntry],
        checkIns: [CheckInMetric],
        habits: [Habit],
        followUps: [FollowUp],
        summaries: [DailyHealthSummary],
        baseline: HealthBaseline?,
        therapistID: String? = nil,
        now: Date = Date()
    ) -> WellbeingContextSnapshot {
        let nowTimestamp = now.timeIntervalSince1970
        var signals: [WellbeingSignal] = []

        if let checkIn = latestTodayCheckIn(from: checkIns, now: now) {
            if checkIn.stressScore >= 7 {
                signals.append(WellbeingSignal(
                    id: "context-checkin-stress-\(checkIn.id)",
                    source: .checkIn,
                    tone: .attention,
                    title: "Stress is elevated",
                    detail: "Today's check-in suggests a lower-pressure support path may fit better.",
                    reasonCodes: ["checkin.stress.high", "context.self_report"],
                    confidence: 0.84,
                    createdAt: nowTimestamp
                ))
            }
            if checkIn.moodScore <= 3 {
                signals.append(WellbeingSignal(
                    id: "context-checkin-mood-\(checkIn.id)",
                    source: .checkIn,
                    tone: .recovery,
                    title: "Mood is lower today",
                    detail: "A recovery or grounding action should be prioritized over productivity prompts.",
                    reasonCodes: ["checkin.mood.low", "intervention.recovery"],
                    confidence: 0.82,
                    createdAt: nowTimestamp
                ))
            }
        }

        if let latestEntry = entries.sorted(by: { $0.timestamp > $1.timestamp }).first,
           latestEntry.timestamp > nowTimestamp - 2 * 86_400 {
            if let anxiety = latestEntry.anxietyLevel, anxiety >= 70 {
                signals.append(WellbeingSignal(
                    id: "context-journal-anxiety-\(latestEntry.id)",
                    source: .journal,
                    tone: .attention,
                    title: "Reflection shows anxiety",
                    detail: "The latest journal entry carries higher anxiety, so grounding should stay close.",
                    reasonCodes: ["journal.anxiety.high", "intervention.grounding"],
                    confidence: 0.78,
                    createdAt: nowTimestamp
                ))
            }
            if let energy = latestEntry.energyLevel, energy <= 35 {
                signals.append(WellbeingSignal(
                    id: "context-journal-energy-\(latestEntry.id)",
                    source: .journal,
                    tone: .recovery,
                    title: "Energy looks low",
                    detail: "Keep the next step small enough to complete without forcing momentum.",
                    reasonCodes: ["journal.energy.low", "behavior.small_step"],
                    confidence: 0.66,
                    createdAt: nowTimestamp
                ))
            }
        }

        if let latestSummary = summaries.sorted(by: { $0.date > $1.date }).first {
            if let sleep = latestSummary.sleepMinutes,
               let averageSleep = baseline?.averageSleepMinutes,
               averageSleep > 240,
               sleep + 75 < averageSleep {
                signals.append(WellbeingSignal(
                    id: "context-health-sleep-\(latestSummary.id)",
                    source: .health,
                    tone: .recovery,
                    title: "Sleep is below range",
                    detail: "Sleep appears below your recent personal range, so recovery-oriented suggestions should rank higher.",
                    reasonCodes: ["health.sleep.below_personal_range", "intervention.recovery"],
                    confidence: 0.72,
                    createdAt: nowTimestamp
                ))
            }
            if let steps = latestSummary.stepCount,
               let averageSteps = baseline?.averageSteps,
               averageSteps > 1_200,
               steps < averageSteps * 0.45 {
                signals.append(WellbeingSignal(
                    id: "context-health-steps-\(latestSummary.id)",
                    source: .health,
                    tone: .attention,
                    title: "Movement is below range",
                    detail: "Activity is lower than your recent personal range; a tiny Garden action may be enough.",
                    reasonCodes: ["health.steps.below_personal_range", "garden.tiny_action"],
                    confidence: 0.64,
                    createdAt: nowTimestamp
                ))
            }
            if let resting = latestSummary.restingHeartRate,
               let averageResting = baseline?.averageRestingHeartRate,
               resting > averageResting + 8 {
                signals.append(WellbeingSignal(
                    id: "context-health-resting-hr-\(latestSummary.id)",
                    source: .health,
                    tone: .attention,
                    title: "Resting heart rate is higher",
                    detail: "Resting heart rate appears above your recent range; treat this only as gentle context.",
                    reasonCodes: ["health.resting_hr.above_personal_range", "context.not_diagnostic"],
                    confidence: 0.58,
                    createdAt: nowTimestamp
                ))
            }
        }

        if let dueFollowUp = followUps
            .filter({ $0.status == .pending && $0.dueAt <= nowTimestamp })
            .sorted(by: { $0.dueAt < $1.dueAt })
            .first {
            signals.append(WellbeingSignal(
                id: "context-followup-\(dueFollowUp.id)",
                source: .followUp,
                tone: .attention,
                title: "A plan is ready for review",
                detail: dueFollowUp.prompt,
                reasonCodes: ["follow_up.due", "behavior.small_step"],
                confidence: 0.62,
                createdAt: nowTimestamp
            ))
        }

        let completedToday = habits.filter {
            guard let completedAt = $0.completedAt else { return false }
            return Calendar.current.isDate(Date(timeIntervalSince1970: completedAt), inSameDayAs: now)
        }.count
        if completedToday > 0 {
            signals.append(WellbeingSignal(
                id: "context-garden-progress-\(Self.dayKey(for: now))",
                source: .garden,
                tone: .progress,
                title: "Progress is visible",
                detail: "\(completedToday) Garden step\(completedToday == 1 ? "" : "s") completed today.",
                reasonCodes: ["garden.progress", "behavior.reinforcement"],
                confidence: 0.60,
                createdAt: nowTimestamp
            ))
        }

        let sortedSignals = signals.sorted { lhs, rhs in
            if lhs.confidence == rhs.confidence {
                return tonePriority(lhs.tone) > tonePriority(rhs.tone)
            }
            return lhs.confidence > rhs.confidence
        }
        let topSignals = Array(sortedSignals.prefix(4))
        let confidence = topSignals.isEmpty ? 0 : topSignals.map(\.confidence).reduce(0, +) / Double(topSignals.count)
        let journalBridge = JournalTherapyContextBridgeEngine.make(entries: entries, therapistID: therapistID, now: now)

        return WellbeingContextSnapshot(
            id: "wellbeing-\(Self.dayKey(for: now))",
            generatedAt: nowTimestamp,
            headline: headline(for: topSignals.first),
            summary: summary(for: topSignals.first),
            confidence: confidence,
            signals: topSignals,
            journalBridge: journalBridge
        )
    }

    private static func latestTodayCheckIn(from checkIns: [CheckInMetric], now: Date) -> CheckInMetric? {
        checkIns
            .filter { Calendar.current.isDate(Date(timeIntervalSince1970: $0.createdAt), inSameDayAs: now) }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private static func headline(for signal: WellbeingSignal?) -> String {
        guard let signal else { return "Context is still forming" }
        switch signal.tone {
        case .steady:
            return "Context looks steady"
        case .attention:
            return "A little more support may fit"
        case .recovery:
            return "Today may need a lighter pace"
        case .progress:
            return "Small wins are showing"
        }
    }

    private static func summary(for signal: WellbeingSignal?) -> String {
        signal?.detail ?? "Add a check-in, reflection, or Health sync to make support less generic."
    }

    private static func tonePriority(_ tone: WellbeingSignalTone) -> Int {
        switch tone {
        case .attention:
            return 4
        case .recovery:
            return 3
        case .progress:
            return 2
        case .steady:
            return 1
        }
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct SafetyAssessment: Codable {
    var riskLevel: RiskLevel
    var intent: UserIntent
    var reasonCodes: [String]
    var suggestedIntervention: InterventionKind?

    static let clear = SafetyAssessment(
        riskLevel: .none,
        intent: .unsure,
        reasonCodes: [],
        suggestedIntervention: nil
    )
}

struct ConversationTurnResult: Codable {
    var reply: String
    var nextState: ConversationState
    var intent: UserIntent
    var riskLevel: RiskLevel
    var suggestedIntervention: InterventionKind?
    var microPlan: MicroPlan?
}

struct ConversationTurnPreparation: Codable {
    var safetyAssessment: SafetyAssessment
    var nextState: ConversationState
    var shouldUseAI: Bool
    var immediateReply: String?

    var suggestedIntervention: InterventionKind? {
        safetyAssessment.suggestedIntervention ?? InterventionLibrary.shared.primaryIntervention(for: nextState)
    }
}

struct ConversationTurnMetadata: Identifiable, Codable {
    let id: String
    var timestamp: TimeInterval
    var stateBefore: ConversationState
    var stateAfter: ConversationState
    var intent: UserIntent
    var riskLevel: RiskLevel
    var reasonCodes: [String]
    var suggestedIntervention: InterventionKind?
    var usedAI: Bool

    init(
        id: String = UUID().uuidString,
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        stateBefore: ConversationState,
        stateAfter: ConversationState,
        intent: UserIntent,
        riskLevel: RiskLevel,
        reasonCodes: [String],
        suggestedIntervention: InterventionKind?,
        usedAI: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.stateBefore = stateBefore
        self.stateAfter = stateAfter
        self.intent = intent
        self.riskLevel = riskLevel
        self.reasonCodes = reasonCodes
        self.suggestedIntervention = suggestedIntervention
        self.usedAI = usedAI
    }
}

struct ChatSession: Identifiable, Codable {
    let id: String
    let therapistID: String
    var messages: [ChatMessage]
    var metrics: EmotionalMetrics = EmotionalMetrics()
    var conversationState: ConversationState = .checkIn
    var lastRiskLevel: RiskLevel = .none
    var turnMetadata: [ConversationTurnMetadata] = []
    var lastUpdated: TimeInterval = Date().timeIntervalSince1970
    var archivedAt: TimeInterval?

    init(
        id: String = UUID().uuidString,
        therapistID: String? = nil,
        messages: [ChatMessage],
        metrics: EmotionalMetrics = EmotionalMetrics(),
        conversationState: ConversationState = .checkIn,
        lastRiskLevel: RiskLevel = .none,
        turnMetadata: [ConversationTurnMetadata] = [],
        lastUpdated: TimeInterval = Date().timeIntervalSince1970,
        archivedAt: TimeInterval? = nil
    ) {
        self.id = id
        self.therapistID = therapistID ?? id
        self.messages = messages
        self.metrics = metrics
        self.conversationState = conversationState
        self.lastRiskLevel = lastRiskLevel
        self.turnMetadata = turnMetadata
        self.lastUpdated = lastUpdated
        self.archivedAt = archivedAt
    }

    var messageCount: Int { messages.filter { !$0.isThinking }.count }
    var lastMessagePreview: String { messages.last(where: { !$0.isThinking })?.text ?? "" }

    mutating func append(_ message: ChatMessage) {
        messages.append(message)
        lastUpdated = Date().timeIntervalSince1970
    }
}

// MARK: - Emotional Metrics

struct EmotionalMetrics: Codable {
    var wellness: Int = 72
    var clarity: Int = 65
    var calm: Int = 58
    var energy: Int = 60
}

// MARK: - Journal

struct JournalEntry: Identifiable, Codable {
    let id: String
    var date: String
    var timestamp: TimeInterval
    var title: String
    var content: String
    var mood: MoodType
    var tags: [String]
    var reflection: String?
    var actionItem: String?
    var summary: String?
    var sentimentScore: Int?
    var energyLevel: Int?
    var anxietyLevel: Int?
    var therapyMemoryPolicy: JournalTherapyMemoryPolicy? = nil
    var isPinned: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case timestamp
        case title
        case content
        case mood
        case tags
        case reflection
        case actionItem
        case summary
        case sentimentScore
        case energyLevel
        case anxietyLevel
        case therapyMemoryPolicy
        case isPinned
    }

    init(
        id: String,
        date: String,
        timestamp: TimeInterval,
        title: String,
        content: String,
        mood: MoodType,
        tags: [String],
        reflection: String? = nil,
        actionItem: String? = nil,
        summary: String? = nil,
        sentimentScore: Int? = nil,
        energyLevel: Int? = nil,
        anxietyLevel: Int? = nil,
        therapyMemoryPolicy: JournalTherapyMemoryPolicy? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.date = date
        self.timestamp = timestamp
        self.title = title
        self.content = content
        self.mood = mood
        self.tags = tags
        self.reflection = reflection
        self.actionItem = actionItem
        self.summary = summary
        self.sentimentScore = sentimentScore
        self.energyLevel = energyLevel
        self.anxietyLevel = anxietyLevel
        self.therapyMemoryPolicy = therapyMemoryPolicy
        self.isPinned = isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        mood = try container.decode(MoodType.self, forKey: .mood)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        reflection = try container.decodeIfPresent(String.self, forKey: .reflection)
        actionItem = try container.decodeIfPresent(String.self, forKey: .actionItem)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        sentimentScore = try container.decodeIfPresent(Int.self, forKey: .sentimentScore)
        energyLevel = try container.decodeIfPresent(Int.self, forKey: .energyLevel)
        anxietyLevel = try container.decodeIfPresent(Int.self, forKey: .anxietyLevel)
        therapyMemoryPolicy = try container.decodeIfPresent(JournalTherapyMemoryPolicy.self, forKey: .therapyMemoryPolicy)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

enum JournalTherapyMemoryPolicy: String, CaseIterable, Codable {
    case automatic
    case included
    case excluded

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .included: return "Use in Therapy"
        case .excluded: return "Do not use"
        }
    }
}

enum MoodType: String, CaseIterable, Codable {
    case happy, calm, anxious, sad, neutral, energetic
    
    var icon: String {
        switch self {
        case .happy: return "sun.max.fill"
        case .calm: return "cloud.fill"
        case .anxious: return "waveform.path.ecg"
        case .sad: return "moon.fill"
        case .neutral: return "face.smiling"
        case .energetic: return "bolt.fill"
        }
    }
    
    var label: String { rawValue.capitalized }
}

// MARK: - Cognitive Distortion (Prism)

struct ReframingOption: Identifiable {
    let id = UUID()
    let perspective: String  // "rational", "compassionate", "stoic"
    let text: String
}

struct CognitiveDistortion: Identifiable {
    let id = UUID()
    let originalText: String
    let type: String
    let explanation: String
    let reframes: [ReframingOption]
}

// MARK: - Habits (Garden)

enum PlantType: String, CaseIterable, Codable {
    case seed, sprout, flower, tree
}

struct Habit: Identifiable, Codable {
    let id: String
    var title: String
    var description: String
    var completedAt: TimeInterval?
    var createdAt: TimeInterval
    var plantType: PlantType
    var growth: Int
    var sourceMicroPlanID: String? = nil
}

enum GardenDecorationType: String, CaseIterable, Identifiable, Codable {
    case lamp
    case stones
    case flowers

    var id: String { rawValue }

    var dewCost: Int {
        switch self {
        case .lamp: return 2
        case .stones: return 1
        case .flowers: return 2
        }
    }
}

struct GardenDecoration: Identifiable, Codable {
    let id: String
    let type: GardenDecorationType
    let anchorHabitID: String
    let x: Double
    let y: Double

    init(
        id: String = UUID().uuidString,
        type: GardenDecorationType,
        anchorHabitID: String,
        x: Double,
        y: Double
    ) {
        self.id = id
        self.type = type
        self.anchorHabitID = anchorHabitID
        self.x = x
        self.y = y
    }
}

enum GardenForageKind: String, CaseIterable, Identifiable, Codable {
    case dewMote

    var id: String { rawValue }
}

struct GardenForageItem: Identifiable, Codable {
    let id: String
    let kind: GardenForageKind
    let dayKey: String
    let x: Double
    let y: Double
    let reward: Int
    let spawnedAt: TimeInterval
    var claimedAt: TimeInterval?

    var isClaimed: Bool { claimedAt != nil }

    init(
        id: String,
        kind: GardenForageKind = .dewMote,
        dayKey: String,
        x: Double,
        y: Double,
        reward: Int = 1,
        spawnedAt: TimeInterval,
        claimedAt: TimeInterval? = nil
    ) {
        self.id = id
        self.kind = kind
        self.dayKey = dayKey
        self.x = x
        self.y = y
        self.reward = reward
        self.spawnedAt = spawnedAt
        self.claimedAt = claimedAt
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

enum GardenVisitorKind: String, CaseIterable, Identifiable, Codable {
    case mira
    case sol
    case nori

    var id: String { rawValue }
}

enum GardenDailyEventTaskKind: String, CaseIterable, Identifiable, Codable {
    case gatherDew
    case tendPlot

    var id: String { rawValue }
}

struct GardenDailyEvent: Identifiable, Codable {
    let id: String
    let dayKey: String
    let visitor: GardenVisitorKind
    let taskKind: GardenDailyEventTaskKind
    let taskGoal: Int
    let reward: Int
    let x: Double
    let y: Double
    let spawnedAt: TimeInterval
    var acceptedAt: TimeInterval?
    var completedAt: TimeInterval?
    var dismissedAt: TimeInterval?

    var isAccepted: Bool { acceptedAt != nil }
    var isCompleted: Bool { completedAt != nil }
    var isDismissed: Bool { dismissedAt != nil }

    init(
        id: String,
        dayKey: String,
        visitor: GardenVisitorKind,
        taskKind: GardenDailyEventTaskKind,
        taskGoal: Int,
        reward: Int,
        x: Double,
        y: Double,
        spawnedAt: TimeInterval,
        acceptedAt: TimeInterval? = nil,
        completedAt: TimeInterval? = nil,
        dismissedAt: TimeInterval? = nil
    ) {
        self.id = id
        self.dayKey = dayKey
        self.visitor = visitor
        self.taskKind = taskKind
        self.taskGoal = taskGoal
        self.reward = reward
        self.x = x
        self.y = y
        self.spawnedAt = spawnedAt
        self.acceptedAt = acceptedAt
        self.completedAt = completedAt
        self.dismissedAt = dismissedAt
    }

    static func make(for date: Date, calendar: Calendar = .current) -> GardenDailyEvent {
        let dayKey = GardenForageItem.dayKey(for: date, calendar: calendar)
        let seed = dayKey.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let visitors = GardenVisitorKind.allCases
        let tasks = GardenDailyEventTaskKind.allCases
        let positions: [(x: Double, y: Double)] = [
            (0.42, 0.30),
            (0.63, 0.52),
            (0.21, 0.55)
        ]
        let taskKind = tasks[seed % tasks.count]
        let taskGoal: Int
        let reward: Int
        switch taskKind {
        case .gatherDew:
            taskGoal = 2
            reward = 3
        case .tendPlot:
            taskGoal = 1
            reward = 2
        }

        let position = positions[seed % positions.count]
        return GardenDailyEvent(
            id: "visitor-\(dayKey)",
            dayKey: dayKey,
            visitor: visitors[seed % visitors.count],
            taskKind: taskKind,
            taskGoal: taskGoal,
            reward: reward,
            x: position.x,
            y: position.y,
            spawnedAt: date.timeIntervalSince1970
        )
    }
}

enum GardenKeepsakeKind: String, CaseIterable, Identifiable, Codable {
    case pathCharm
    case sunLantern
    case seedArchive

    var id: String { rawValue }

    static func reward(for visitor: GardenVisitorKind) -> GardenKeepsakeKind {
        switch visitor {
        case .mira: return .pathCharm
        case .sol: return .sunLantern
        case .nori: return .seedArchive
        }
    }
}

struct GardenKeepsake: Identifiable, Codable {
    let id: String
    let kind: GardenKeepsakeKind
    let visitor: GardenVisitorKind
    let unlockedAt: TimeInterval
    let sourceEventID: String

    init(
        id: String? = nil,
        kind: GardenKeepsakeKind,
        visitor: GardenVisitorKind,
        unlockedAt: TimeInterval,
        sourceEventID: String
    ) {
        self.id = id ?? "keepsake-\(kind.rawValue)"
        self.kind = kind
        self.visitor = visitor
        self.unlockedAt = unlockedAt
        self.sourceEventID = sourceEventID
    }
}

enum GardenAreaMiniGameKind: String, CaseIterable, Identifiable, Codable {
    case route
    case lanterns
    case archive

    var id: String { rawValue }

    var requiredSteps: Int { 3 }
}

enum GardenMapAreaKind: String, CaseIterable, Identifiable, Codable {
    case pathNook
    case lanternGlade
    case archiveCorner

    var id: String { rawValue }

    var miniGameKind: GardenAreaMiniGameKind {
        switch self {
        case .pathNook: return .route
        case .lanternGlade: return .lanterns
        case .archiveCorner: return .archive
        }
    }

    var dailyReward: Int {
        switch self {
        case .pathNook: return 1
        case .lanternGlade: return 2
        case .archiveCorner: return 1
        }
    }

    static func reward(for keepsake: GardenKeepsakeKind) -> GardenMapAreaKind {
        switch keepsake {
        case .pathCharm: return .pathNook
        case .sunLantern: return .lanternGlade
        case .seedArchive: return .archiveCorner
        }
    }

    var milestoneDefinitions: [GardenAreaMilestoneDefinition] {
        switch self {
        case .pathNook:
            return [
                GardenAreaMilestoneDefinition(area: self, stage: 1, requiredVisits: 2, reward: 2),
                GardenAreaMilestoneDefinition(area: self, stage: 2, requiredVisits: 4, reward: 3),
                GardenAreaMilestoneDefinition(area: self, stage: 3, requiredVisits: 7, reward: 5)
            ]
        case .lanternGlade:
            return [
                GardenAreaMilestoneDefinition(area: self, stage: 1, requiredVisits: 2, reward: 3),
                GardenAreaMilestoneDefinition(area: self, stage: 2, requiredVisits: 5, reward: 4),
                GardenAreaMilestoneDefinition(area: self, stage: 3, requiredVisits: 8, reward: 6)
            ]
        case .archiveCorner:
            return [
                GardenAreaMilestoneDefinition(area: self, stage: 1, requiredVisits: 2, reward: 2),
                GardenAreaMilestoneDefinition(area: self, stage: 2, requiredVisits: 4, reward: 4),
                GardenAreaMilestoneDefinition(area: self, stage: 3, requiredVisits: 6, reward: 5)
            ]
        }
    }

    func milestoneDefinition(stage: Int) -> GardenAreaMilestoneDefinition? {
        milestoneDefinitions.first { $0.stage == stage }
    }

    var questDefinitions: [GardenAreaQuestDefinition] {
        milestoneDefinitions.map { milestone in
            GardenAreaQuestDefinition(
                area: self,
                stage: milestone.stage,
                requiredVisits: milestone.requiredVisits,
                reward: milestone.reward,
                title: questTitle(stage: milestone.stage),
                objective: questObjective(stage: milestone.stage, requiredVisits: milestone.requiredVisits),
                story: questStory(stage: milestone.stage)
            )
        }
    }

    func questDefinition(stage: Int) -> GardenAreaQuestDefinition? {
        questDefinitions.first { $0.stage == stage }
    }

    var mapEvolutionDefinitions: [GardenAreaMapEvolutionDefinition] {
        milestoneDefinitions.map { milestone in
            let anchor = mapEvolutionAnchor(stage: milestone.stage)
            return GardenAreaMapEvolutionDefinition(
                area: self,
                stage: milestone.stage,
                localXOffset: anchor.x,
                localYOffset: anchor.y,
                scale: anchor.scale
            )
        }
    }

    func mapEvolutionDefinition(stage: Int) -> GardenAreaMapEvolutionDefinition? {
        mapEvolutionDefinitions.first { $0.stage == stage }
    }

    func mapEvolutionTitle(stage: Int) -> String {
        switch (self, stage) {
        case (.pathNook, 1): return "Trail sign placed"
        case (.pathNook, 2): return "Stone loop connected"
        case (.pathNook, 3): return "Quiet route opened"
        case (.lanternGlade, 1): return "First lantern lit"
        case (.lanternGlade, 2): return "Glow lines restored"
        case (.lanternGlade, 3): return "Night light gathered"
        case (.archiveCorner, 1): return "Seed label saved"
        case (.archiveCorner, 2): return "Routine shelf built"
        case (.archiveCorner, 3): return "Catalog board bound"
        default: return "Map changed"
        }
    }

    func mapEvolutionDetail(stage: Int) -> String {
        switch (self, stage) {
        case (.pathNook, 1):
            return "A wooden marker now anchors the walking corner."
        case (.pathNook, 2):
            return "More stones make the path readable from the map."
        case (.pathNook, 3):
            return "A green side route completes the reset trail."
        case (.lanternGlade, 1):
            return "A warm lamp gives the clearing its first glow."
        case (.lanternGlade, 2):
            return "Soft light lines connect the glade together."
        case (.lanternGlade, 3):
            return "A brighter center marks the glade as a gathering spot."
        case (.archiveCorner, 1):
            return "The first label turns a win into something findable."
        case (.archiveCorner, 2):
            return "A small shelf begins organizing the corner."
        case (.archiveCorner, 3):
            return "The catalog board records the area as restored."
        default:
            return "The garden remembers this completed chapter."
        }
    }

    private func questTitle(stage: Int) -> String {
        switch (self, stage) {
        case (.pathNook, 1): return "Mark the first stone"
        case (.pathNook, 2): return "Connect the loop"
        case (.pathNook, 3): return "Open the quiet route"
        case (.lanternGlade, 1): return "Hang the first lantern"
        case (.lanternGlade, 2): return "Warm the evening line"
        case (.lanternGlade, 3): return "Welcome a night visitor"
        case (.archiveCorner, 1): return "Label the first seed"
        case (.archiveCorner, 2): return "Build the routine shelf"
        case (.archiveCorner, 3): return "Bind the growth catalog"
        default: return "Tend the area"
        }
    }

    private func questObjective(stage: Int, requiredVisits: Int) -> String {
        switch self {
        case .pathNook:
            return "Complete \(requiredVisits) short loop\(requiredVisits == 1 ? "" : "s")"
        case .lanternGlade:
            return "Light the glade \(requiredVisits) time\(requiredVisits == 1 ? "" : "s")"
        case .archiveCorner:
            return "File \(requiredVisits) tiny memor\(requiredVisits == 1 ? "y" : "ies")"
        }
    }

    private func questStory(stage: Int) -> String {
        switch (self, stage) {
        case (.pathNook, 1):
            return "A small marker makes the first step easier to choose."
        case (.pathNook, 2):
            return "Stone by stone, the loop starts to feel familiar."
        case (.pathNook, 3):
            return "The quiet route becomes a place for short resets."
        case (.lanternGlade, 1):
            return "One warm lamp gives the clearing a steady center."
        case (.lanternGlade, 2):
            return "More light lets the glade hold evening visits longer."
        case (.lanternGlade, 3):
            return "The clearing is bright enough to welcome company."
        case (.archiveCorner, 1):
            return "One named seed makes progress easier to find again."
        case (.archiveCorner, 2):
            return "The shelf begins turning routines into a record."
        case (.archiveCorner, 3):
            return "The catalog gathers small wins into a visible history."
        default:
            return "Repeated care changes this part of the garden."
        }
    }

    private func mapEvolutionAnchor(stage: Int) -> (x: Double, y: Double, scale: Double) {
        switch (self, stage) {
        case (.pathNook, 1): return (-52, 31, 0.94)
        case (.pathNook, 2): return (45, 26, 1.02)
        case (.pathNook, 3): return (0, -43, 1.04)
        case (.lanternGlade, 1): return (-48, 27, 0.96)
        case (.lanternGlade, 2): return (45, 24, 1.00)
        case (.lanternGlade, 3): return (0, -45, 1.08)
        case (.archiveCorner, 1): return (-46, 30, 0.96)
        case (.archiveCorner, 2): return (44, 25, 1.02)
        case (.archiveCorner, 3): return (0, -42, 1.05)
        default: return (0, 0, 1)
        }
    }
}

struct GardenAreaMilestoneDefinition: Identifiable, Equatable {
    let area: GardenMapAreaKind
    let stage: Int
    let requiredVisits: Int
    let reward: Int

    var id: String {
        "area-milestone-definition-\(area.rawValue)-\(stage)"
    }
}

struct GardenAreaQuestDefinition: Identifiable, Equatable {
    let area: GardenMapAreaKind
    let stage: Int
    let requiredVisits: Int
    let reward: Int
    let title: String
    let objective: String
    let story: String

    var id: String {
        "area-quest-definition-\(area.rawValue)-\(stage)"
    }
}

struct GardenAreaMapEvolutionDefinition: Identifiable, Equatable {
    let area: GardenMapAreaKind
    let stage: Int
    let localXOffset: Double
    let localYOffset: Double
    let scale: Double

    var id: String {
        "area-map-evolution-\(area.rawValue)-\(stage)"
    }
}

struct GardenAreaChapterMemory: Identifiable, Equatable {
    let area: GardenMapAreaKind
    let stage: Int
    let title: String
    let story: String
    let objective: String
    let mapChangeTitle: String
    let mapChangeDetail: String
    let evolution: GardenAreaMapEvolutionDefinition

    var id: String {
        "area-chapter-memory-\(area.rawValue)-\(stage)"
    }
}

struct GardenAreaLogEntry: Identifiable, Equatable {
    let area: GardenMapAreaKind
    let isUnlocked: Bool
    let visitCount: Int
    let completedQuests: [GardenAreaQuestDefinition]
    let nextQuest: GardenAreaQuestDefinition?

    var id: String { area.rawValue }

    var completedChapterCount: Int {
        completedQuests.count
    }

    var totalChapterCount: Int {
        area.questDefinitions.count
    }

    var progressFraction: Double {
        guard totalChapterCount > 0 else { return 0 }
        return min(1, Double(completedChapterCount) / Double(totalChapterCount))
    }

    var completedMemories: [GardenAreaChapterMemory] {
        completedQuests.compactMap { quest in
            guard let evolution = area.mapEvolutionDefinition(stage: quest.stage) else {
                return nil
            }
            return GardenAreaChapterMemory(
                area: area,
                stage: quest.stage,
                title: quest.title,
                story: quest.story,
                objective: quest.objective,
                mapChangeTitle: area.mapEvolutionTitle(stage: quest.stage),
                mapChangeDetail: area.mapEvolutionDetail(stage: quest.stage),
                evolution: evolution
            )
        }
    }

    static func entries(
        unlockedAreas: [GardenMapAreaUnlock],
        visits: [GardenMapAreaVisit],
        milestones: [GardenAreaMilestoneUnlock]
    ) -> [GardenAreaLogEntry] {
        let unlockedAreaKinds = Set(unlockedAreas.map(\.area))
        let visitsByArea = Dictionary(grouping: visits, by: \.area)
        let milestoneStagesByArea = Dictionary(grouping: milestones, by: \.area)
            .mapValues { Set($0.map(\.stage)) }

        return GardenMapAreaKind.allCases.map { area in
            let completedStages = milestoneStagesByArea[area] ?? []
            let completedQuests = area.questDefinitions.filter { completedStages.contains($0.stage) }
            let nextQuest = area.questDefinitions.first { !completedStages.contains($0.stage) }

            return GardenAreaLogEntry(
                area: area,
                isUnlocked: unlockedAreaKinds.contains(area),
                visitCount: visitsByArea[area]?.count ?? 0,
                completedQuests: completedQuests,
                nextQuest: unlockedAreaKinds.contains(area) ? nextQuest : nil
            )
        }
    }
}

struct GardenMapAreaUnlock: Identifiable, Codable {
    let id: String
    let area: GardenMapAreaKind
    let unlockedAt: TimeInterval
    let sourceKeepsakeID: String

    init(
        id: String? = nil,
        area: GardenMapAreaKind,
        unlockedAt: TimeInterval,
        sourceKeepsakeID: String
    ) {
        self.id = id ?? "area-\(area.rawValue)"
        self.area = area
        self.unlockedAt = unlockedAt
        self.sourceKeepsakeID = sourceKeepsakeID
    }
}

struct GardenMapAreaVisit: Identifiable, Codable {
    let id: String
    let area: GardenMapAreaKind
    let dayKey: String
    let reward: Int
    let completedAt: TimeInterval

    init(
        id: String? = nil,
        area: GardenMapAreaKind,
        dayKey: String,
        reward: Int,
        completedAt: TimeInterval
    ) {
        self.id = id ?? "area-visit-\(area.rawValue)-\(dayKey)"
        self.area = area
        self.dayKey = dayKey
        self.reward = reward
        self.completedAt = completedAt
    }
}

struct GardenAreaMilestoneUnlock: Identifiable, Codable {
    let id: String
    let area: GardenMapAreaKind
    let stage: Int
    let requiredVisits: Int
    let reward: Int
    let unlockedAt: TimeInterval

    init(
        id: String? = nil,
        area: GardenMapAreaKind,
        stage: Int,
        requiredVisits: Int,
        reward: Int,
        unlockedAt: TimeInterval
    ) {
        self.id = id ?? "area-milestone-\(area.rawValue)-\(stage)"
        self.area = area
        self.stage = stage
        self.requiredVisits = requiredVisits
        self.reward = reward
        self.unlockedAt = unlockedAt
    }
}

struct GardenAreaActionResult {
    let visit: GardenMapAreaVisit
    let unlockedMilestones: [GardenAreaMilestoneUnlock]

    var totalReward: Int {
        visit.reward + unlockedMilestones.reduce(0) { $0 + $1.reward }
    }
}

// MARK: - Deep Insights

struct TriggerInsight: Identifiable, Codable {
    let id: String
    let trigger: String
    let effect: String
    let suggestion: String

    init(
        id: String = UUID().uuidString,
        trigger: String,
        effect: String,
        suggestion: String
    ) {
        self.id = id
        self.trigger = trigger
        self.effect = effect
        self.suggestion = suggestion
    }
}

struct MentalHealthWrapped: Codable {
    let lowPointsOvercome: Int
    let topPositiveWords: [String]
    let summary: String
    let growthArea: String
}

struct DeepInsights: Codable {
    let triggers: [TriggerInsight]
    let wrapped: MentalHealthWrapped
}

struct DailyJournalInsights: Codable {
    let id: String
    let dateKey: String
    let generatedAt: TimeInterval
    let entryFingerprint: String
    let insights: DeepInsights

    init(
        id: String = UUID().uuidString,
        dateKey: String,
        generatedAt: TimeInterval = Date().timeIntervalSince1970,
        entryFingerprint: String,
        insights: DeepInsights
    ) {
        self.id = id
        self.dateKey = dateKey
        self.generatedAt = generatedAt
        self.entryFingerprint = entryFingerprint
        self.insights = insights
    }
}
