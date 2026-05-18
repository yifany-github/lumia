import Foundation
import FirebaseAuth
import FirebaseCore

// MARK: - Conversation Safety

struct ConversationSafetyEngine {
    private let highRiskPhrases = [
        "kill myself",
        "end my life",
        "suicide",
        "自杀",
        "不想活",
        "结束生命",
        "想死",
        "活不下去"
    ]

    private let mediumRiskPhrases = [
        "hurt myself",
        "self harm",
        "cut myself",
        "hopeless",
        "can't go on",
        "伤害自己",
        "自残",
        "绝望",
        "撑不下去"
    ]

    func assess(_ text: String) -> SafetyAssessment {
        let normalized = text.lowercased()
        let highMatches = highRiskPhrases.filter { normalized.contains($0.lowercased()) }
        if !highMatches.isEmpty {
            return SafetyAssessment(
                riskLevel: .high,
                intent: .crisis,
                reasonCodes: highMatches.map { "high-risk:\($0)" },
                suggestedIntervention: .crisisSupport
            )
        }

        let mediumMatches = mediumRiskPhrases.filter { normalized.contains($0.lowercased()) }
        if !mediumMatches.isEmpty {
            return SafetyAssessment(
                riskLevel: .medium,
                intent: .crisis,
                reasonCodes: mediumMatches.map { "medium-risk:\($0)" },
                suggestedIntervention: .crisisSupport
            )
        }

        return SafetyAssessment.clear
    }

    func crisisResponse(region: String? = nil) -> String {
        let localResource = crisisResource(for: region)
        return """
        I'm really glad you told me. Your safety matters more than continuing this chat.

        If you might hurt yourself or cannot stay safe right now, please contact emergency services now or go to the nearest emergency room.

        \(localResource)

        If you can, move near another person, put distance between yourself and anything you could use to hurt yourself, and tell someone nearby: "I need help staying safe right now."
        """
    }

    private func crisisResource(for region: String?) -> String {
        switch region?.lowercased() {
        case "canada", "ca":
            return "In Canada, call or text 9-8-8 for 24/7 suicide crisis support. For immediate danger, call 9-1-1."
        case "united kingdom", "uk", "gb":
            return "In the UK, call Samaritans at 116 123 for free 24/7 support. For immediate danger, call 999."
        case "australia", "au":
            return "In Australia, call Lifeline at 13 11 14. For immediate danger, call 000."
        default:
            return "In the United States, call or text 988 for 24/7 crisis support. If you are outside the US, contact your local emergency number or crisis line."
        }
    }
}

struct ConversationEngine {
    private let safetyEngine = ConversationSafetyEngine()

    func prepareTurn(userText: String, currentState: ConversationState, region: String? = nil) -> ConversationTurnPreparation {
        let assessment = safetyEngine.assess(userText)
        if assessment.riskLevel >= .high {
            return ConversationTurnPreparation(
                safetyAssessment: assessment,
                nextState: .crisis,
                shouldUseAI: false,
                immediateReply: safetyEngine.crisisResponse(region: region)
            )
        }

        if assessment.riskLevel >= .medium {
            return ConversationTurnPreparation(
                safetyAssessment: assessment,
                nextState: .triage,
                shouldUseAI: true,
                immediateReply: nil
            )
        }

        return ConversationTurnPreparation(
            safetyAssessment: assessment,
            nextState: stableState(for: userText, currentState: currentState),
            shouldUseAI: true,
            immediateReply: nil
        )
    }

    func systemInstruction(
        for therapist: Therapist,
        state: ConversationState,
        riskLevel: RiskLevel,
        contextBrief: String? = nil
    ) -> String {
        let interventionGuidance = InterventionLibrary.shared.promptGuidance(for: state)
        let policy = PromptPolicyVersion.therapySupportV1
        let contextSection = contextBrief.map {
            """

            Optional local context:
            \($0)
            """
        } ?? ""
        return """
        \(therapist.systemInstruction)

        Active prompt policy: \(policy.displayName)
        Policy summary: \(policy.summary)

        Lumina safety and product boundaries:
        - You provide emotional support and self-help reflection, not diagnosis, medical advice, or emergency care.
        - Do not claim to detect mental illness or infer emotion as a fact.
        - If the user expresses self-harm, suicide, immediate danger, or inability to stay safe, prioritize safety and encourage local emergency/crisis resources.
        - Keep replies concise, warm, and practical.

        Current conversation mode: \(state.policyName).
        \(policyInstruction(for: state, riskLevel: riskLevel))

        Recommended intervention scripts:
        \(interventionGuidance)
        \(contextSection)
        """
    }

    func extractMicroPlan(from text: String, sourceSessionID: String? = nil) -> MicroPlan? {
        for rawLine in text.components(separatedBy: .newlines) {
            let line = cleanPlanLine(rawLine)
            guard !line.isEmpty else { continue }
            if let plan = englishIfThenPlan(from: line, sourceSessionID: sourceSessionID) {
                return plan
            }
            if let plan = chineseIfThenPlan(from: line, sourceSessionID: sourceSessionID) {
                return plan
            }
        }
        return nil
    }

    private func stableState(for userText: String, currentState: ConversationState) -> ConversationState {
        switch currentState {
        case .listen, .coach, .plan:
            return currentState
        case .crisis:
            return .triage
        case .checkIn, .triage, .fallback, .wrapUp:
            return inferredState(from: userText)
        }
    }

    private func inferredState(from text: String) -> ConversationState {
        let normalized = text.lowercased()
        if isUnclearInput(normalized) {
            return .fallback
        }

        let planningCues = ["plan", "goal", "habit", "routine", "if then", "具体计划", "计划", "目标", "习惯", "行动"]
        if planningCues.contains(where: { normalized.contains($0) }) {
            return .plan
        }

        let coachingCues = ["advice", "help me", "what should", "solve", "fix", "建议", "怎么办", "解决", "分析"]
        if coachingCues.contains(where: { normalized.contains($0) }) {
            return .coach
        }

        return .listen
    }

    private func isUnclearInput(_ normalizedText: String) -> Bool {
        let trimmed = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let unclearExactMatches = ["...", "idk", "whatever", "not sure", "unsure", "不知道", "不清楚", "随便", "说不清"]
        if unclearExactMatches.contains(trimmed) {
            return true
        }

        let unclearPhrases = ["i don't know", "i dont know", "no idea", "不知道怎么办", "不知道说什么"]
        return unclearPhrases.contains { trimmed.contains($0) }
    }

    private func cleanPlanLine(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-*•0123456789. "))
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func englishIfThenPlan(from line: String, sourceSessionID: String?) -> MicroPlan? {
        let lower = line.lowercased()
        guard let ifRange = lower.range(of: "if ") else { return nil }
        let thenRange = lower.range(of: " then ") ?? lower.range(of: ", then ")
        guard let thenRange else { return nil }

        let triggerStartOffset = lower.distance(from: lower.startIndex, to: ifRange.upperBound)
        let triggerEndOffset = lower.distance(from: lower.startIndex, to: thenRange.lowerBound)
        let actionStartOffset = lower.distance(from: lower.startIndex, to: thenRange.upperBound)
        let triggerStart = line.index(line.startIndex, offsetBy: triggerStartOffset)
        let triggerEnd = line.index(line.startIndex, offsetBy: triggerEndOffset)
        let actionStart = line.index(line.startIndex, offsetBy: actionStartOffset)

        let trigger = cleanPlanSegment(String(line[triggerStart..<triggerEnd]))
        let action = cleanPlanSegment(String(line[actionStart...]))
        return buildMicroPlan(trigger: trigger, action: action, sourceSessionID: sourceSessionID)
    }

    private func chineseIfThenPlan(from line: String, sourceSessionID: String?) -> MicroPlan? {
        guard let ifRange = line.range(of: "如果"),
              let thenRange = line.range(of: "就") else { return nil }
        let trigger = cleanPlanSegment(String(line[ifRange.upperBound..<thenRange.lowerBound]))
        let action = cleanPlanSegment(String(line[thenRange.upperBound...]))
        return buildMicroPlan(trigger: trigger, action: action, sourceSessionID: sourceSessionID)
    }

    private func cleanPlanSegment(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".。!！,，:：;；"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildMicroPlan(trigger: String, action: String, sourceSessionID: String?) -> MicroPlan? {
        guard trigger.count >= 3, action.count >= 3 else { return nil }
        return MicroPlan(
            trigger: trigger,
            action: action,
            sourceSessionID: sourceSessionID
        )
    }

    private func policyInstruction(for state: ConversationState, riskLevel: RiskLevel) -> String {
        let riskInstruction = riskLevel >= .medium
            ? "The latest message has elevated safety risk. Ask one direct safety-check question and keep the next step simple."
            : "No elevated safety signal was detected locally."

        switch state {
        case .listen:
            return """
            \(riskInstruction)
            Listen mode policy:
            - Lead with reflective listening and emotion naming.
            - Ask at most one gentle question.
            - Do not rush into advice unless the user asks for it.
            """
        case .coach:
            return """
            \(riskInstruction)
            Coach mode policy:
            - Clarify the problem and the controllable next step.
            - Offer 2-3 options, not a long list.
            - End with one small action the user can choose or reject.
            """
        case .plan:
            return """
            \(riskInstruction)
            Plan mode policy:
            - Convert the user's concern into a tiny If-Then plan when appropriate.
            - Keep the plan realistic for low-energy moments.
            - Include one follow-up check the user can do later.
            """
        case .triage:
            return """
            \(riskInstruction)
            Triage policy:
            - First determine whether the user wants listening, coaching, or planning.
            - Ask one clear question if intent is unclear.
            """
        case .crisis:
            return """
            Crisis policy:
            - Prioritize immediate safety.
            - Do not continue normal coaching.
            - Encourage local emergency/crisis resources and nearby human support.
            """
        case .fallback:
            return """
            Fallback policy:
            - State uncertainty briefly.
            - Ask one clarifying question or offer Listen, Coach, Plan choices.
            """
        case .checkIn, .wrapUp:
            return """
            \(riskInstruction)
            Check-in/wrap-up policy:
            - Keep the exchange short.
            - Summarize the user's state and offer one next step.
            """
        }
    }
}

private extension ConversationState {
    var policyName: String {
        switch self {
        case .listen: return "Listen"
        case .coach: return "Coach"
        case .plan: return "Plan"
        case .triage: return "Triage"
        case .crisis: return "Crisis"
        case .fallback: return "Fallback"
        case .checkIn: return "Check-in"
        case .wrapUp: return "Wrap-up"
        }
    }
}

// MARK: - Lumina AI Gateway
enum GeminiServiceError: LocalizedError {
    case notSignedIn
    case backendUnavailable
    case backendPermissionMissing
    case emptyResponse
    case invalidResponse
    case gatewayError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in to use Lumina AI."
        case .backendUnavailable:
            return "Lumina AI is not deployed yet. Deploy the Firebase aiGateway function, then try again."
        case .backendPermissionMissing:
            return "Lumina AI is deployed but not callable yet. Redeploy aiGateway with public invoker access."
        case .emptyResponse:
            return "Lumina AI returned an empty response. Try again in a moment."
        case .invalidResponse:
            return "Lumina AI returned a response the app could not read."
        case .gatewayError(let statusCode, let message):
            return "Lumina AI request failed (\(statusCode)): \(message)"
        }
    }
}

class GeminiService {
    static let shared = GeminiService()
    private let fallbackProjectID = "lumia-cd3d2"
    private var cachedRuntimeConfig: LuminaAIRuntimeConfig?
    private var cachedRuntimeConfigDate: Date?
    
    // MARK: - Generate text content
    func generateContent(
        model: String = "gemini-3.1-pro-preview",
        userPrompt: String,
        systemInstruction: String? = nil,
        jsonMode: Bool = false
    ) async throws -> String {
        let result = try await callGateway(
            feature: "healthCheck",
            payload: [
                "message": userPrompt,
                "modelHint": model,
                "jsonMode": jsonMode
            ]
        )
        guard let text = result["text"] as? String else { throw GeminiServiceError.invalidResponse }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GeminiServiceError.emptyResponse }
        return trimmed
    }

    // MARK: - Runtime Config
    func runtimeConfig() async throws -> LuminaAIRuntimeConfig {
        if let cachedRuntimeConfig,
           let cachedRuntimeConfigDate,
           Date().timeIntervalSince(cachedRuntimeConfigDate) < 300 {
            return cachedRuntimeConfig
        }

        let result: [String: Any]
        do {
            result = try await callGateway(feature: "runtimeConfig", payload: [:])
        } catch GeminiServiceError.gatewayError(let statusCode, let message)
            where statusCode == 400 && message.localizedCaseInsensitiveContains("runtimeConfig") {
            let config = LuminaAIRuntimeConfig(
                textModel: "gemini-3-flash-preview",
                liveModel: "gemini-2.5-flash-native-audio-preview-12-2025",
                promptVersion: "local-runtime-fallback"
            )
            cachedRuntimeConfig = config
            cachedRuntimeConfigDate = Date()
            return config
        }
        guard let models = result["models"] as? [String: Any],
              let textModel = models["text"] as? String,
              let liveModel = models["live"] as? String else {
            throw GeminiServiceError.invalidResponse
        }

        let config = LuminaAIRuntimeConfig(
            textModel: textModel,
            liveModel: liveModel,
            promptVersion: result["promptVersion"] as? String ?? ""
        )
        cachedRuntimeConfig = config
        cachedRuntimeConfigDate = Date()
        return config
    }
    
    // MARK: - Analyze Journal Entry
    func analyzeJournalEntry(_ content: String) async throws -> JournalAnalysis {
        let result = try await callGateway(feature: "analyzeJournal", payload: ["content": content])
        guard let json = result["analysis"] as? [String: Any] else { throw GeminiServiceError.invalidResponse }

        return JournalAnalysis(
            title: json["title"] as? String ?? "Untitled Reflection",
            mood: json["mood"] as? String ?? "neutral",
            tags: json["tags"] as? [String] ?? ["Journal"],
            summary: json["summary"] as? String ?? "",
            reflection: json["reflection"] as? String ?? "",
            actionItem: json["actionItem"] as? String ?? "",
            sentimentScore: json["sentimentScore"] as? Int ?? 50,
            energyLevel: json["energyLevel"] as? Int ?? 50,
            anxietyLevel: json["anxietyLevel"] as? Int ?? 20
        )
    }
    
    // MARK: - Analyze Cognitive Distortions
    func analyzeDistortions(_ content: String) async throws -> [CognitiveDistortion] {
        let result = try await callGateway(feature: "analyzeDistortions", payload: ["content": content])
        let jsonArray = result["distortions"] as? [[String: Any]] ?? []

        return jsonArray.compactMap { item in
            guard let originalText = item["originalText"] as? String,
                  let type = item["type"] as? String,
                  let explanation = item["explanation"] as? String,
                  let reframesArr = item["reframes"] as? [[String: Any]] else { return nil }
            
            let reframes = reframesArr.compactMap { r -> ReframingOption? in
                guard let perspective = r["perspective"] as? String,
                      let text = r["text"] as? String else { return nil }
                return ReframingOption(perspective: perspective, text: text)
            }
            
            return CognitiveDistortion(
                originalText: originalText,
                type: type,
                explanation: explanation,
                reframes: reframes
            )
        }
    }
    
    // MARK: - Chat with Therapist
    func chat(
        therapist: Therapist,
        history: [ChatMessage],
        newMessage: String,
        conversationState: ConversationState = .listen,
        riskLevel: RiskLevel = .none,
        contextBrief: String? = nil
    ) async throws -> String {
        let compactHistory = history.suffix(12).map { message in
            [
                "role": message.role.rawValue,
                "text": message.text
            ]
        }

        let result = try await callGateway(
            feature: "therapyChat",
            payload: [
                "therapistID": therapist.id,
                "therapistName": therapist.name,
                "history": Array(compactHistory),
                "newMessage": newMessage,
                "conversationState": conversationState.rawValue,
                "riskLevel": riskLevel.rawValue,
                "contextBrief": contextBrief ?? ""
            ]
        )
        guard let text = result["text"] as? String else { throw GeminiServiceError.invalidResponse }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GeminiServiceError.emptyResponse }
        return trimmed
    }
    
    // MARK: - Sentiment Analysis
    func analyzeSentiment(history: [ChatMessage]) async throws -> EmotionalMetrics {
        let compactHistory = history.prefix(10).map { message in
            [
                "role": message.role.rawValue,
                "text": message.text
            ]
        }
        let result = try await callGateway(feature: "analyzeSentiment", payload: ["history": Array(compactHistory)])
        guard let json = result["metrics"] as? [String: Any] else {
            return EmotionalMetrics()
        }
        
        return EmotionalMetrics(
            wellness: json["wellness"] as? Int ?? 72,
            clarity: json["clarity"] as? Int ?? 65,
            calm: json["calm"] as? Int ?? 58,
            energy: json["energy"] as? Int ?? 60
        )
    }
    
    // MARK: - Deep Insights
    func generateDeepInsights(entries: [JournalEntry]) async throws -> DeepInsights? {
        let entryPayload = entries.prefix(7).map { entry in
            [
                "date": entry.date,
                "mood": entry.mood.rawValue,
                "content": entry.content
            ]
        }
        let result = try await callGateway(feature: "generateDeepInsights", payload: ["entries": Array(entryPayload)])

        guard let json = result["insights"] as? [String: Any],
              let wrappedJson = json["wrapped"] as? [String: Any] else {
            return nil
        }
        
        let triggers: [TriggerInsight] = (json["triggers"] as? [[String: Any]] ?? []).compactMap { t in
            guard let trigger = t["trigger"] as? String,
                  let effect = t["effect"] as? String,
                  let suggestion = t["suggestion"] as? String else { return nil }
            return TriggerInsight(trigger: trigger, effect: effect, suggestion: suggestion)
        }
        
        let wrapped = MentalHealthWrapped(
            lowPointsOvercome: wrappedJson["lowPointsOvercome"] as? Int ?? 0,
            topPositiveWords: wrappedJson["topPositiveWords"] as? [String] ?? [],
            summary: wrappedJson["summary"] as? String ?? "",
            growthArea: wrappedJson["growthArea"] as? String ?? ""
        )
        
        return DeepInsights(triggers: triggers, wrapped: wrapped)
    }

    private func callGateway(feature: String, payload: [String: Any]) async throws -> [String: Any] {
        guard let user = Auth.auth().currentUser else {
            throw GeminiServiceError.notSignedIn
        }
        let token = try await idToken(for: user)
        let projectID = FirebaseApp.app()?.options.projectID ?? fallbackProjectID
        guard let url = URL(string: "https://us-central1-\(projectID).cloudfunctions.net/aiGateway") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "feature": feature,
            "payload": payload
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if isHTMLResponse(data: data, response: http) {
            if http.statusCode == 404 {
                throw GeminiServiceError.backendUnavailable
            }
            if http.statusCode == 401 || http.statusCode == 403 {
                throw GeminiServiceError.backendPermissionMissing
            }
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = gatewayMessage(from: data) ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiServiceError.gatewayError(statusCode: http.statusCode, message: message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GeminiServiceError.invalidResponse
        }
        if let error = json["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown backend error"
            throw GeminiServiceError.gatewayError(statusCode: http.statusCode, message: message)
        }
        return json
    }

    private func idToken(for user: User) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            user.getIDToken { token, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let token, !token.isEmpty else {
                    continuation.resume(throwing: GeminiServiceError.notSignedIn)
                    return
                }
                continuation.resume(returning: token)
            }
        }
    }

    private func gatewayMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let error = json["error"] as? [String: Any] {
            return error["message"] as? String
        }
        if let error = json["error"] as? String {
            return error
        }
        return json["message"] as? String
    }

    private func isHTMLResponse(data: Data, response: HTTPURLResponse) -> Bool {
        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if contentType.contains("text/html") { return true }
        let prefix = String(data: data.prefix(80), encoding: .utf8)?.lowercased() ?? ""
        return prefix.contains("<html") || prefix.contains("<!doctype html")
    }
}

// MARK: - Response Types
struct JournalAnalysis {
    let title: String
    let mood: String
    let tags: [String]
    let summary: String
    let reflection: String
    let actionItem: String
    let sentimentScore: Int
    let energyLevel: Int
    let anxietyLevel: Int
}

struct LuminaAIRuntimeConfig {
    let textModel: String
    let liveModel: String
    let promptVersion: String
}
