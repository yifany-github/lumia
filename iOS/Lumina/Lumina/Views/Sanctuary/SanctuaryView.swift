import SwiftUI

// MARK: - Sanctuary
struct SanctuaryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var activeSheet: SanctuarySheet?
    @State private var selectedFeeling: SanctuaryFeeling = .tense
    @State private var affirmationIndex = 0
    @State private var affirmationFlipping = false

    private let interventionLibrary = InterventionLibrary.shared
    private var affirmations: [String] { interventionLibrary.affirmations }
    private var recommendedNeed: SanctuaryNeed { selectedFeeling.recommendedNeed }

    private var currentAffirmation: String {
        guard affirmations.indices.contains(affirmationIndex) else {
            return "One steady breath is enough for this moment."
        }
        return affirmations[affirmationIndex]
    }
    
    var body: some View {
        ZStack {
            Color.organicBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    SanctuaryHeroHeader()

                    SanctuaryFeelingPicker(selection: $selectedFeeling)

                    SanctuaryPrimaryToolCard(
                        feeling: selectedFeeling,
                        need: recommendedNeed,
                        action: { open(recommendedNeed, reason: "sanctuary.recommendation.\(selectedFeeling.rawValue)") }
                    )

                    SanctuaryToolShelf(
                        recommendedNeed: recommendedNeed,
                        action: { open($0, reason: "sanctuary.tool.secondary.\($0.rawValue)") }
                    )

                    SanctuaryAffirmationCard(
                        affirmation: currentAffirmation,
                        isFlipping: affirmationFlipping,
                        action: nextAffirmation
                    )

                    SanctuarySafetyStrip(
                        action: openCrisis
                    )

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .slowExhale:
                SlowExhaleExerciseView {
                    complete(.breathing, reason: "sanctuary.slow_exhale_completed")
                }
            case .breathing:
                BreathingExerciseView {
                    complete(.breathing, reason: "sanctuary.breathing_completed")
                }
            case .bodyScan:
                BodyScanExerciseView {
                    complete(.grounding, reason: "sanctuary.body_scan_completed")
                }
            case .grounding:
                GroundingExerciseView {
                    complete(.grounding, reason: "sanctuary.grounding_completed")
                }
            case .journalPrompt:
                SanctuaryJournalPromptView(
                    affirmation: currentAffirmation,
                    onOpenJournal: {
                        complete(.journalingPrompt, reason: "sanctuary.journal_prompt_accepted")
                        activeSheet = nil
                        appState.selectedTab = 1
                    }
                )
            case .support:
                SanctuarySupportChoiceView(
                    onTalkToGuide: {
                        activeSheet = nil
                        let therapist = allTherapists.first(where: { $0.name == "Serena" }) ?? allTherapists[0]
                        appState.requestTherapy(with: therapist)
                        recordLater(
                            kind: .reflectiveListening,
                            outcome: .accepted,
                            reason: "sanctuary.support.talk_to_guide"
                        )
                    },
                    onGroundFirst: {
                        activeSheet = .grounding
                        recordLater(
                            kind: .grounding,
                            outcome: .accepted,
                            reason: "sanctuary.support.ground_first"
                        )
                    },
                    onCrisisResources: {
                        openCrisis()
                    }
                )
            case .crisis:
                CrisisSupportView { resource in
                    recordLater(
                        kind: .crisisSupport,
                        outcome: .accepted,
                        reason: "sanctuary.safety_resource.\(resource)"
                    )
                }
            }
        }
    }

    private func open(_ need: SanctuaryNeed, reason: String) {
        activeSheet = need.sheet
        recordLater(kind: need.kind, outcome: .accepted, reason: reason)
    }

    private func openCrisis() {
        activeSheet = .crisis
        recordLater(kind: .crisisSupport, outcome: .shown, reason: "sanctuary.safety_opened")
    }

    private func complete(_ kind: InterventionKind, reason: String) {
        recordLater(kind: kind, outcome: .completed, reason: reason)
    }

    private func recordLater(kind: InterventionKind, outcome: InterventionOutcome, reason: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            appState.recordSanctuaryIntervention(
                kind: kind,
                outcome: outcome,
                reasonCodes: [reason]
            )
        }
    }

    private func nextAffirmation() {
        guard !affirmations.isEmpty, !affirmationFlipping else { return }
        affirmationFlipping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            affirmationIndex = (affirmationIndex + 1) % max(1, affirmations.count)
            affirmationFlipping = false
        }
    }
}

private enum SanctuarySheet: String, Identifiable {
    case slowExhale
    case breathing
    case bodyScan
    case grounding
    case journalPrompt
    case support
    case crisis

    var id: String { rawValue }
}

private enum SanctuaryFeeling: String, CaseIterable, Identifiable {
    case tense
    case scattered
    case heavy
    case needPerson

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tense:
            return "Tense"
        case .scattered:
            return "Scattered"
        case .heavy:
            return "Heavy"
        case .needPerson:
            return "Need a person"
        }
    }

    var icon: String {
        switch self {
        case .tense:
            return "waveform.path.ecg"
        case .scattered:
            return "sparkles"
        case .heavy:
            return "moon.zzz.fill"
        case .needPerson:
            return "person.2.fill"
        }
    }

    var quietLabel: String {
        switch self {
        case .tense:
            return "Start with the out-breath."
        case .scattered:
            return "Let the room become the anchor."
        case .heavy:
            return "Let the body do less."
        case .needPerson:
            return "You do not have to handle it alone."
        }
    }

    var recommendedNeed: SanctuaryNeed {
        switch self {
        case .tense:
            return .slowExhale
        case .scattered:
            return .ground
        case .heavy:
            return .bodyScan
        case .needPerson:
            return .person
        }
    }
}

private enum SanctuaryNeed: String, CaseIterable, Identifiable {
    case slowExhale
    case breathe
    case bodyScan
    case ground
    case write
    case person

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slowExhale:
            return "Slow exhale"
        case .breathe:
            return "Box breath"
        case .bodyScan:
            return "Body scan"
        case .ground:
            return "Ground"
        case .write:
            return "Words"
        case .person:
            return "Person"
        }
    }

    var icon: String {
        switch self {
        case .slowExhale:
            return "wind"
        case .breathe:
            return "wind"
        case .bodyScan:
            return "person.fill"
        case .ground:
            return "hand.raised.fill"
        case .write:
            return "square.and.pencil"
        case .person:
            return "person.2.fill"
        }
    }

    var headline: String {
        switch self {
        case .slowExhale:
            return "Lengthen the out-breath"
        case .breathe:
            return "Settle your breath"
        case .bodyScan:
            return "Soften one place at a time"
        case .ground:
            return "Come back to the room"
        case .write:
            return "Find one sentence"
        case .person:
            return "Find a person"
        }
    }

    var body: String {
        switch self {
        case .slowExhale:
            return "A short 3-6 breath pattern for tension. No counting perfection needed."
        case .breathe:
            return "Follow a slow four-part breath. Stop whenever you have enough."
        case .bodyScan:
            return "Move attention through the body and release one small area."
        case .ground:
            return "Notice a few simple details around you. No need to do it perfectly."
        case .write:
            return "Use a short prompt when your thoughts feel tangled."
        case .person:
            return "Talk with a gentle guide, ground first, or open safety resources."
        }
    }

    var actionTitle: String {
        switch self {
        case .slowExhale:
            return "Start slow exhale"
        case .breathe:
            return "Start breathing"
        case .bodyScan:
            return "Start body scan"
        case .ground:
            return "Start grounding"
        case .write:
            return "Show prompt"
        case .person:
            return "Choose support"
        }
    }

    var kind: InterventionKind {
        switch self {
        case .slowExhale:
            return .breathing
        case .breathe:
            return .breathing
        case .bodyScan:
            return .grounding
        case .ground:
            return .grounding
        case .write:
            return .journalingPrompt
        case .person:
            return .reflectiveListening
        }
    }

    var sheet: SanctuarySheet {
        switch self {
        case .slowExhale:
            return .slowExhale
        case .breathe:
            return .breathing
        case .bodyScan:
            return .bodyScan
        case .ground:
            return .grounding
        case .write:
            return .journalPrompt
        case .person:
            return .support
        }
    }

    var tint: Color {
        switch self {
        case .slowExhale:
            return .organicPrimary
        case .breathe:
            return .organicPrimary
        case .bodyScan:
            return Color(hex: 0x8B7A65)
        case .ground:
            return Color(hex: 0x8B7A65)
        case .write:
            return .organicSecondary
        case .person:
            return .organicSecondary
        }
    }
}

private struct SanctuaryHeroHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sanctuary")
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(.organicPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.organicPrimary.opacity(0.10))
                    .clipShape(Capsule())

                Spacer()

                Image(systemName: "leaf.fill")
                    .luminaFont(size: 17, weight: .semibold)
                    .foregroundColor(.organicPrimary)
                    .frame(width: 38, height: 38)
                    .background(Color.organicPrimary.opacity(0.10))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Take one quiet minute")
                    .luminaFont(size: 32, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text("Pick what feels useful. Leave the rest.")
                    .luminaFont(size: 15, weight: .medium)
                    .foregroundColor(.organicMutedFg)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }
}

private struct SanctuaryFeelingPicker: View {
    @Binding var selection: SanctuaryFeeling

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What is closest?")
                .luminaFont(size: 12, weight: .bold)
                .foregroundColor(.organicMutedFg)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(SanctuaryFeeling.allCases) { feeling in
                    SanctuaryFeelingButton(
                        feeling: feeling,
                        isSelected: selection == feeling,
                        action: {
                            selection = feeling
                        }
                    )
                }
            }
        }
    }
}

private struct SanctuaryFeelingButton: View {
    let feeling: SanctuaryFeeling
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: feeling.icon)
                    .luminaFont(size: 13, weight: .semibold)
                    .foregroundColor(isSelected ? feeling.recommendedNeed.tint : .organicMutedFg)
                    .frame(width: 28, height: 28)
                    .background((isSelected ? feeling.recommendedNeed.tint : Color.organicMutedFg).opacity(0.10))
                    .clipShape(Circle())

                Text(feeling.title)
                    .luminaFont(size: 13, weight: .bold)
                    .foregroundColor(isSelected ? .organicForeground : .organicMutedFg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isSelected ? feeling.recommendedNeed.tint.opacity(0.12) : Color.organicCard.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(isSelected ? feeling.recommendedNeed.tint.opacity(0.2) : Color.organicBorder.opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SanctuaryToolShelf: View {
    let recommendedNeed: SanctuaryNeed
    let action: (SanctuaryNeed) -> Void

    private var tools: [SanctuaryNeed] {
        [.slowExhale, .breathe, .bodyScan, .ground, .write]
            .filter { $0 != recommendedNeed }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Other small tools")
                .luminaFont(size: 12, weight: .bold)
                .foregroundColor(.organicMutedFg)

            HStack(spacing: 8) {
                ForEach(tools) { need in
                    Button {
                        action(need)
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: need.icon)
                                .luminaFont(size: 13, weight: .semibold)
                                .foregroundColor(need.tint)
                            Text(need.title)
                                .luminaFont(size: 12, weight: .bold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .foregroundColor(.organicForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(Color.organicCard.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.organicBorder.opacity(0.44), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SanctuaryPrimaryToolCard: View {
    let feeling: SanctuaryFeeling
    let need: SanctuaryNeed
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: need.icon)
                        .luminaFont(size: 22, weight: .semibold)
                        .foregroundColor(need.tint)
                        .frame(width: 54, height: 54)
                        .background(need.tint.opacity(0.11))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(feeling.quietLabel)
                            .luminaFont(size: 11, weight: .bold)
                            .foregroundColor(.organicMutedFg)
                        Text(need.headline)
                            .luminaFont(size: 24, weight: .bold, design: .serif)
                            .foregroundColor(.organicForeground)
                            .lineLimit(2)
                        Text(need.body)
                            .luminaFont(size: 14, weight: .medium)
                            .foregroundColor(.organicMutedFg)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    Text(need.actionTitle)
                        .luminaFont(size: 13, weight: .bold)
                    Image(systemName: "arrow.right")
                        .luminaFont(size: 11, weight: .bold)
                }
                .foregroundColor(need.tint)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(need.tint.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.organicCard)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.organicBorder.opacity(0.58), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SanctuaryAffirmationCard: View {
    let affirmation: String
    let isFlipping: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "quote.opening")
                            .luminaFont(size: 14, weight: .semibold)
                            .foregroundColor(.organicSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.organicAccent.opacity(0.72))
                            .clipShape(Circle())
                        Text("A line to hold")
                            .luminaFont(size: 16, weight: .bold, design: .serif)
                            .foregroundColor(.organicForeground)
                    }
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundColor(.organicSecondary)
                        .frame(width: 30, height: 30)
                        .background(Color.organicSecondary.opacity(0.10))
                        .clipShape(Circle())
                }

                Text(affirmation)
                    .luminaFont(size: 18, weight: .semibold, design: .serif)
                    .foregroundColor(.organicForeground)
                    .italic()
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(isFlipping ? 0 : 1)
                    .scaleEffect(isFlipping ? 0.98 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isFlipping)

                Text("Tap for another")
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(.organicMutedFg)
            }
            .padding(18)
            .background(Color.organicMuted.opacity(0.48))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SanctuarySafetyStrip: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "shield.fill")
                    .luminaFont(size: 16, weight: .semibold)
                    .foregroundColor(.organicSecondary)
                    .frame(width: 40, height: 40)
                    .background(Color.organicSecondary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Need support now?")
                        .luminaFont(size: 15, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                    Text("Open crisis and helpline resources.")
                        .luminaFont(size: 12, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .luminaFont(size: 11, weight: .bold)
                    .foregroundColor(.organicMutedFg)
            }
            .padding(16)
            .background(Color.organicCard.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.organicBorder.opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SanctuaryJournalPromptView: View {
    @Environment(\.dismiss) private var dismiss
    let affirmation: String
    let onOpenJournal: () -> Void
    @State private var promptIndex = 0

    private let prompts = [
        "What feels loudest right now?",
        "What would make the next ten minutes softer?",
        "What can wait until later?",
        "What do I need to hear from myself?"
    ]

    private var currentPrompt: String {
        prompts[promptIndex % prompts.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(.organicMutedFg)
                        .frame(width: 34, height: 34)
                        .background(Color.organicMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "square.and.pencil")
                    .luminaFont(size: 24, weight: .semibold)
                    .foregroundColor(.organicSecondary)
                    .frame(width: 56, height: 56)
                    .background(Color.organicAccent.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("One sentence is enough")
                        .luminaFont(size: 28, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                    Text("Use this prompt as a starting point, or ignore it.")
                        .luminaFont(size: 14, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(currentPrompt)
                        .luminaFont(size: 24, weight: .semibold, design: .serif)
                        .foregroundColor(.organicForeground)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(affirmation)
                        .luminaFont(size: 13, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .lineSpacing(3)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.organicCard)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.organicBorder.opacity(0.55), lineWidth: 1)
                }

                HStack(spacing: 10) {
                    Button {
                        promptIndex = (promptIndex + 1) % prompts.count
                    } label: {
                        Label("Another", systemImage: "arrow.clockwise")
                            .luminaFont(size: 13, weight: .bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.organicMuted)
                            .foregroundColor(.organicForeground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onOpenJournal) {
                        Label("Open Journal", systemImage: "arrow.right")
                            .luminaFont(size: 13, weight: .bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.organicSecondary.opacity(0.14))
                            .foregroundColor(.organicSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.organicBackground.ignoresSafeArea())
    }
}

// MARK: - Slow Exhale
struct SlowExhaleExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void
    @State private var isActive = false
    @State private var phase: ExhalePhase = .ready
    @State private var timeRemaining = 0
    @State private var completedRounds = 0
    @State private var timer: Timer? = nil

    init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }

    enum ExhalePhase {
        case ready
        case inhale
        case exhale

        var label: String {
            switch self {
            case .ready:
                return "Ready"
            case .inhale:
                return "Inhale"
            case .exhale:
                return "Exhale"
            }
        }

        var duration: Int {
            switch self {
            case .ready:
                return 0
            case .inhale:
                return 3
            case .exhale:
                return 6
            }
        }

        var circleScale: CGFloat {
            switch self {
            case .ready:
                return 0.68
            case .inhale:
                return 1.0
            case .exhale:
                return 0.46
            }
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Spacer()
                Button(action: { stop(); dismiss() }) {
                    Image(systemName: "xmark")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(.organicMutedFg)
                        .frame(width: 34, height: 34)
                        .background(Color.organicMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            VStack(spacing: 8) {
                Image(systemName: "wind")
                    .luminaFont(size: 22, weight: .semibold)
                    .foregroundColor(.organicPrimary)
                    .frame(width: 52, height: 52)
                    .background(Color.organicPrimary.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text("Slow exhale")
                    .luminaFont(size: 30, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
                Text("Inhale for 3. Exhale for 6. Let the out-breath do most of the work.")
                    .luminaFont(size: 14, weight: .medium)
                    .foregroundColor(.organicMutedFg)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 28)
            }

            ZStack {
                Circle()
                    .stroke(Color.organicPrimary.opacity(0.12), lineWidth: 2)
                    .frame(width: 250, height: 250)

                Circle()
                    .fill(Color.organicPrimary.opacity(0.16))
                    .frame(width: 250 * phase.circleScale, height: 250 * phase.circleScale)
                    .animation(.easeInOut(duration: Double(max(phase.duration, 1))), value: phase.circleScale)
                    .overlay {
                        VStack(spacing: 8) {
                            Text(phase.label)
                                .luminaFont(size: 24, weight: .bold, design: .serif)
                                .foregroundColor(.organicPrimary)
                            if isActive {
                                Text("\(timeRemaining)")
                                    .luminaFont(size: 42, weight: .bold, design: .rounded)
                                    .foregroundColor(.organicPrimary.opacity(0.7))
                            }
                        }
                    }
            }
            .frame(height: 270)

            HStack(spacing: 10) {
                Button(action: { isActive ? stop() : start() }) {
                    Text(isActive ? "Pause" : "Start")
                        .luminaFont(size: 15, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(isActive ? Color.organicMuted : Color.organicPrimary)
                        .foregroundColor(isActive ? .organicPrimary : .organicPrimaryFg)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    stop()
                    onComplete()
                    dismiss()
                } label: {
                    Text("Done for now")
                        .luminaFont(size: 15, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.organicCard)
                        .foregroundColor(.organicForeground)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .strokeBorder(Color.organicBorder.opacity(0.58), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            if completedRounds > 0 {
                Text("One slow round counts.")
                    .luminaFont(size: 13, weight: .semibold)
                    .foregroundColor(.organicMutedFg)
            }

            Spacer()
        }
        .background(Color.organicBackground.ignoresSafeArea())
        .onDisappear { stop() }
    }

    private func start() {
        timer?.invalidate()
        timer = nil
        isActive = true
        completedRounds = 0
        run(.inhale)
    }

    private func run(_ nextPhase: ExhalePhase) {
        guard isActive else { return }
        phase = nextPhase
        timeRemaining = nextPhase.duration
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                t.invalidate()
                if nextPhase == .exhale {
                    completedRounds += 1
                }
                run(nextPhase == .inhale ? .exhale : .inhale)
            }
        }
    }

    private func stop() {
        isActive = false
        timer?.invalidate()
        timer = nil
        phase = .ready
        timeRemaining = 0
    }
}

// MARK: - Body Scan
private struct BodyScanStep: Identifiable {
    let id: Int
    let title: String
    let cue: String
    let icon: String
}

struct BodyScanExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void
    @State private var checked: Set<Int> = []

    private let steps = [
        BodyScanStep(id: 0, title: "Jaw", cue: "Let your jaw unhook a little.", icon: "face.smiling"),
        BodyScanStep(id: 1, title: "Shoulders", cue: "Let them drop one small notch.", icon: "figure.stand"),
        BodyScanStep(id: 2, title: "Hands", cue: "Open your fingers or rest your palms.", icon: "hand.raised.fill"),
        BodyScanStep(id: 3, title: "Chest", cue: "Make a little more room for breath.", icon: "heart.fill"),
        BodyScanStep(id: 4, title: "Legs", cue: "Feel the surface holding you.", icon: "figure.walk")
    ]

    init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(.organicMutedFg)
                        .frame(width: 34, height: 34)
                        .background(Color.organicMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "person.fill")
                            .luminaFont(size: 23, weight: .semibold)
                            .foregroundColor(Color(hex: 0x8B7A65))
                            .frame(width: 56, height: 56)
                            .background(Color(hex: 0x8B7A65).opacity(0.11))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        Text("Body scan")
                            .luminaFont(size: 30, weight: .bold, design: .serif)
                            .foregroundColor(.organicForeground)
                        Text("Check only what feels useful. This can be under a minute.")
                            .luminaFont(size: 14, weight: .medium)
                            .foregroundColor(.organicMutedFg)
                            .lineSpacing(3)
                    }

                    VStack(spacing: 10) {
                        ForEach(steps) { step in
                            Button {
                                if checked.contains(step.id) {
                                    checked.remove(step.id)
                                } else {
                                    checked.insert(step.id)
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: step.icon)
                                        .luminaFont(size: 17, weight: .semibold)
                                        .foregroundColor(Color(hex: 0x8B7A65))
                                        .frame(width: 42, height: 42)
                                        .background(Color(hex: 0x8B7A65).opacity(0.10))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(step.title)
                                            .luminaFont(size: 15, weight: .bold)
                                            .foregroundColor(.organicForeground)
                                        Text(step.cue)
                                            .luminaFont(size: 12, weight: .medium)
                                            .foregroundColor(.organicMutedFg)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    Image(systemName: checked.contains(step.id) ? "checkmark.circle.fill" : "circle")
                                        .luminaFont(size: 18, weight: .semibold)
                                        .foregroundColor(checked.contains(step.id) ? .organicPrimary : .organicMutedFg.opacity(0.55))
                                }
                                .padding(16)
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

                    Button {
                        onComplete()
                        dismiss()
                    } label: {
                        Text(checked.isEmpty ? "Done for now" : "Finish")
                            .luminaFont(size: 15, weight: .bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(hex: 0x8B7A65).opacity(0.14))
                            .foregroundColor(Color(hex: 0x8B7A65))
                            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Color.organicBackground.ignoresSafeArea())
    }
}

// MARK: - Support Choice
private struct SanctuarySupportChoiceView: View {
    @Environment(\.dismiss) private var dismiss
    let onTalkToGuide: () -> Void
    let onGroundFirst: () -> Void
    let onCrisisResources: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(.organicMutedFg)
                        .frame(width: 34, height: 34)
                        .background(Color.organicMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "person.2.fill")
                    .luminaFont(size: 23, weight: .semibold)
                    .foregroundColor(.organicSecondary)
                    .frame(width: 56, height: 56)
                    .background(Color.organicSecondary.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Find a person")
                        .luminaFont(size: 30, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                    Text("Choose the amount of support that feels right.")
                        .luminaFont(size: 14, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .lineSpacing(3)
                }

                VStack(spacing: 10) {
                    SanctuarySupportButton(
                        title: "Talk with Serena",
                        subtitle: "A warm guide for being heard.",
                        icon: "message.fill",
                        tint: .organicSecondary,
                        action: onTalkToGuide
                    )
                    SanctuarySupportButton(
                        title: "Ground first",
                        subtitle: "Take one minute before deciding.",
                        icon: "hand.raised.fill",
                        tint: Color(hex: 0x8B7A65),
                        action: onGroundFirst
                    )
                    SanctuarySupportButton(
                        title: "Open safety resources",
                        subtitle: "Crisis and helpline options.",
                        icon: "shield.fill",
                        tint: .organicPrimary,
                        action: onCrisisResources
                    )
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.organicBackground.ignoresSafeArea())
    }
}

private struct SanctuarySupportButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .luminaFont(size: 17, weight: .semibold)
                    .foregroundColor(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.11))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .luminaFont(size: 16, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                    Text(subtitle)
                        .luminaFont(size: 12, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .luminaFont(size: 11, weight: .bold)
                    .foregroundColor(.organicMutedFg)
            }
            .padding(16)
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

// MARK: - Breathing Exercise
struct BreathingExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void
    @State private var phase: BreathPhase = .ready
    @State private var isActive = false
    @State private var timeRemaining = 4
    @State private var timer: Timer? = nil
    @State private var cyclePhase = 0
    @State private var completedCycles = 0

    init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }
    
    enum BreathPhase {
        case ready, inhale, holdIn, exhale, holdOut
        
        var label: String {
            switch self {
            case .ready:
                return "Ready"
            case .inhale:
                return "Inhale"
            case .holdIn:
                return "Hold"
            case .exhale:
                return "Exhale"
            case .holdOut:
                return "Rest"
            }
        }
    }
    
    let phases: [BreathPhase] = [.inhale, .holdIn, .exhale, .holdOut]
    
    var circleScale: CGFloat {
        switch phase {
        case .inhale:  return 1.0
        case .holdIn:  return 1.0
        case .exhale:  return 0.4
        case .holdOut: return 0.4
        case .ready:   return 0.7
        }
    }
    
    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Spacer()
                Button(action: { stopBreathing(); dismiss() }) {
                    Image(systemName: "xmark")
                        .luminaFont(size: 11, weight: .bold)
                        .frame(width: 34, height: 34)
                        .background(Color.organicMuted)
                        .clipShape(Circle())
                        .foregroundColor(.organicMutedFg)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            VStack(spacing: 8) {
                Image(systemName: "wind")
                    .luminaFont(size: 22, weight: .semibold)
                    .foregroundColor(.organicPrimary)
                    .frame(width: 52, height: 52)
                    .background(Color.organicPrimary.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text("Box breathing")
                    .luminaFont(size: 30, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
                Text("Breathe in four gentle parts. Stop whenever you have enough.")
                    .luminaFont(size: 14, weight: .medium)
                    .foregroundColor(.organicMutedFg)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 28)
            }
            
            ZStack {
                Circle()
                    .stroke(Color.organicPrimary.opacity(0.12), lineWidth: 2)
                    .frame(width: 260, height: 260)
                
                Circle()
                    .fill(Color.organicPrimary.opacity(0.17))
                    .frame(width: 260 * circleScale, height: 260 * circleScale)
                    .animation(.easeInOut(duration: 4.0), value: circleScale)
                    .overlay(
                        VStack(spacing: 8) {
                            Text(phase.label)
                                .luminaFont(size: 24, weight: .bold, design: .serif)
                                .foregroundColor(.organicPrimary)
                            if isActive {
                                Text("\(timeRemaining)")
                                    .luminaFont(size: 42, weight: .bold, design: .rounded)
                                    .foregroundColor(Color.organicPrimary.opacity(0.7))
                            }
                        }
                    )
                
                Circle()
                    .stroke(Color.organicPrimary, lineWidth: 3)
                    .frame(width: 260, height: 260)
                    .opacity(0.15)
                    .scaleEffect(circleScale)
                    .animation(.easeInOut(duration: 4.0), value: circleScale)
            }
            .frame(height: 280)

            HStack(spacing: 10) {
                Button(action: { isActive ? stopBreathing() : startBreathing() }) {
                    Text(isActive ? "Pause" : "Start")
                        .luminaFont(size: 15, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(isActive ? Color.organicMuted : Color.organicPrimary)
                        .foregroundColor(isActive ? .organicPrimary : .organicPrimaryFg)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    stopBreathing()
                    onComplete()
                    dismiss()
                } label: {
                    Text("Done for now")
                        .luminaFont(size: 15, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.organicCard)
                        .foregroundColor(.organicForeground)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .strokeBorder(Color.organicBorder.opacity(0.58), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            if completedCycles > 0 {
                Text("One round is enough.")
                    .luminaFont(size: 13, weight: .semibold)
                    .foregroundColor(.organicMutedFg)
            }
            
            Spacer()
        }
        .background(Color.organicBackground.ignoresSafeArea())
        .onDisappear {
            stopBreathing()
        }
    }
    
    func startBreathing() {
        timer?.invalidate()
        timer = nil
        isActive = true
        cyclePhase = 0
        completedCycles = 0
        advancePhase()
    }
    
    func advancePhase() {
        guard isActive else { return }
        phase = phases[cyclePhase % 4]
        timeRemaining = 4
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                t.invalidate()
                cyclePhase += 1
                if cyclePhase % phases.count == 0 {
                    completedCycles += 1
                }
                if isActive { advancePhase() }
            }
        }
    }
    
    func stopBreathing() {
        isActive = false
        timer?.invalidate()
        timer = nil
        phase = .ready
        timeRemaining = 4
        cyclePhase = 0
    }
}

// MARK: - Grounding
private struct GroundingStep: Identifiable {
    let id: Int
    let count: String
    let label: String
    let icon: String
}

struct GroundingExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void
    @State private var checked: Set<Int> = []

    private let steps = [
        GroundingStep(id: 0, count: "5", label: "things you can see", icon: "eye.fill"),
        GroundingStep(id: 1, count: "4", label: "things you can feel", icon: "hand.tap.fill"),
        GroundingStep(id: 2, count: "3", label: "sounds around you", icon: "ear.fill"),
        GroundingStep(id: 3, count: "2", label: "slow breaths", icon: "wind"),
        GroundingStep(id: 4, count: "1", label: "kind sentence to yourself", icon: "heart.fill")
    ]

    init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .luminaFont(size: 11, weight: .bold)
                        .foregroundColor(.organicMutedFg)
                        .frame(width: 34, height: 34)
                        .background(Color.organicMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "hand.raised.fill")
                            .luminaFont(size: 23, weight: .semibold)
                            .foregroundColor(Color(hex: 0x8B7A65))
                            .frame(width: 56, height: 56)
                            .background(Color(hex: 0x8B7A65).opacity(0.11))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Text("Come back to the room")
                            .luminaFont(size: 30, weight: .bold, design: .serif)
                            .foregroundColor(.organicForeground)
                        Text("Tap each line as you notice it. Leaving some blank is fine.")
                            .luminaFont(size: 14, weight: .medium)
                            .foregroundColor(.organicMutedFg)
                            .lineSpacing(3)
                    }

                    VStack(spacing: 10) {
                        ForEach(steps) { step in
                            Button {
                                if checked.contains(step.id) {
                                    checked.remove(step.id)
                                } else {
                                    checked.insert(step.id)
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Text(step.count)
                                        .luminaFont(size: 22, weight: .bold, design: .serif)
                                        .foregroundColor(Color(hex: 0x8B7A65))
                                        .frame(width: 42, height: 42)
                                        .background(Color(hex: 0x8B7A65).opacity(0.10))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(step.label)
                                            .luminaFont(size: 15, weight: .bold)
                                            .foregroundColor(.organicForeground)
                                        Text(checked.contains(step.id) ? "Noted" : "Take your time")
                                            .luminaFont(size: 12, weight: .medium)
                                            .foregroundColor(.organicMutedFg)
                                    }

                                    Spacer()

                                    Image(systemName: checked.contains(step.id) ? "checkmark.circle.fill" : step.icon)
                                        .luminaFont(size: 18, weight: .semibold)
                                        .foregroundColor(checked.contains(step.id) ? .organicPrimary : .organicMutedFg)
                                }
                                .padding(16)
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

                    Button {
                        onComplete()
                        dismiss()
                    } label: {
                        Text(checked.isEmpty ? "Done for now" : "Finish")
                            .luminaFont(size: 15, weight: .bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(hex: 0x8B7A65).opacity(0.14))
                            .foregroundColor(Color(hex: 0x8B7A65))
                            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Color.organicBackground.ignoresSafeArea())
    }
}

// MARK: - Crisis Support
struct CrisisSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let onResourceOpened: (String) -> Void

    init(onResourceOpened: @escaping (String) -> Void = { _ in }) {
        self.onResourceOpened = onResourceOpened
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .luminaFont(size: 11, weight: .bold)
                            .foregroundColor(.organicMutedFg)
                            .frame(width: 34, height: 34)
                            .background(Color.organicCard.opacity(0.72))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "shield.fill")
                    .luminaFont(size: 38, weight: .semibold)
                    .foregroundColor(.organicSecondary)
                Text("Immediate support")
                    .luminaFont(size: 30, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
                Text("If there is immediate danger, call emergency services now. These resources can connect you with a person.")
                    .luminaFont(size: 14, weight: .medium)
                    .foregroundColor(.organicMutedFg)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(24)
            .background(Color.organicSecondary.opacity(0.08))
            
            ScrollView {
                VStack(spacing: 12) {
                    CrisisResourceButton(
                        title: "988 Suicide & Crisis Lifeline",
                        subtitle: "Available 24/7. Free and confidential.",
                        actionTitle: "Call",
                        icon: "phone.fill",
                        tint: .organicSecondary,
                        action: { open("988", url: "tel:988") }
                    )

                    CrisisResourceButton(
                        title: "Crisis Text Line",
                        subtitle: "Text HOME to 741741.",
                        actionTitle: "Text",
                        icon: "message.fill",
                        tint: Color(hex: 0x4A90E2),
                        action: { open("text_line", url: "sms:741741&body=HOME") }
                    )

                    CrisisResourceButton(
                        title: "International support",
                        subtitle: "Find a helpline in your country.",
                        actionTitle: "Open",
                        icon: "globe",
                        tint: .organicPrimary,
                        action: { open("findahelpline", url: "https://findahelpline.com") }
                    )

                    Button(action: { dismiss() }) {
                        Text("I am safe, return to Lumina")
                            .luminaFont(size: 13, weight: .bold)
                            .foregroundColor(.organicMutedFg)
                            .padding(.top, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
        }
        .background(Color.organicBackground.ignoresSafeArea())
    }

    private func open(_ resource: String, url: String) {
        guard let url = URL(string: url) else { return }
        onResourceOpened(resource)
        openURL(url)
    }
}

private struct CrisisResourceButton: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .luminaFont(size: 17, weight: .semibold)
                    .foregroundColor(tint)
                    .frame(width: 46, height: 46)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .luminaFont(size: 16, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                        .lineLimit(2)
                    Text(subtitle)
                        .luminaFont(size: 12, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(actionTitle)
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(tint)
            }
            .padding(16)
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
