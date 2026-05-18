import SwiftUI

// MARK: - Journal Editor (mirrors Dashboard.tsx editor modal)
struct JournalEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appState: AppState
    @StateObject private var speechInput = SpeechInputController()

    let editingEntry: JournalEntry?

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var speechInputPrefix: String = ""
    @State private var selectedMood: MoodType = .neutral
    @State private var tags: [String] = []
    @State private var reflection: String = ""
    @State private var actionItem: String = ""
    @State private var sentimentScore: Int = 50
    @State private var energyLevel: Int = 50
    @State private var anxietyLevel: Int = 20
    @State private var therapyMemoryPolicy: JournalTherapyMemoryPolicy = .automatic

    @State private var isAnalyzing = false
    @State private var isPrismMode = false
    @State private var distortions: [CognitiveDistortion] = []
    @State private var isAnalyzingDistortions = false
    @State private var activeDistortion: CognitiveDistortion? = nil
    @State private var errorMsg: String? = nil

    let prompts = [
        "What is one thing that made you smile today?",
        "What was a challenge you faced, and how did you handle it?",
        "Describe a moment where you felt truly at peace.",
        "What is weighing on your mind right now?",
        "What is one thing you are grateful for?",
        "If you could tell your younger self one thing today, what would it be?"
    ]
    @State private var promptIndex = 0

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveEntry: Bool {
        editingEntry != nil || !trimmedTitle.isEmpty || !trimmedContent.isEmpty
    }
    private var canToggleSpeechInput: Bool {
        speechInput.isAvailable && !isAnalyzing && !isAnalyzingDistortions
    }
    private var speechStatusText: String? {
        if let errorMessage = speechInput.errorMessage {
            return errorMessage
        }
        if speechInput.isListening {
            return "Listening..."
        }
        return nil
    }

    init(editingEntry: JournalEntry?) {
        self.editingEntry = editingEntry
        if let e = editingEntry {
            _title = State(initialValue: e.title)
            _content = State(initialValue: e.content)
            _selectedMood = State(initialValue: e.mood)
            _tags = State(initialValue: e.tags)
            _reflection = State(initialValue: e.reflection ?? "")
            _actionItem = State(initialValue: e.actionItem ?? "")
            _sentimentScore = State(initialValue: e.sentimentScore ?? 50)
            _energyLevel = State(initialValue: e.energyLevel ?? 50)
            _anxietyLevel = State(initialValue: e.anxietyLevel ?? 20)
            _therapyMemoryPolicy = State(initialValue: e.therapyMemoryPolicy ?? .automatic)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                JournalEditorBackdrop().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(editingEntry == nil ? "New Reflection" : "Edit Reflection")
                                .luminaFont(size: 28, weight: .bold, design: .serif)
                                .foregroundColor(.organicForeground)

                            Text("Write what happened, let Lumina reflect it back, then keep only what is useful.")
                                .luminaFont(size: 14, weight: .medium)
                                .foregroundColor(.organicMutedFg)
                                .lineSpacing(3)
                        }
                        .padding(.top, 6)

                        Button(action: { promptIndex = (promptIndex + 1) % prompts.count }) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "sparkles")
                                    .luminaFont(size: 13, weight: .bold)
                                    .foregroundColor(.organicSecondary)
                                    .padding(.top, 1)

                                Text(prompts[promptIndex])
                                    .luminaFont(size: 14, weight: .semibold, design: .serif)
                                    .italic()
                                    .foregroundColor(.organicMutedFg)
                                    .multilineTextAlignment(.leading)

                                Spacer(minLength: 8)

                                Image(systemName: "arrow.clockwise")
                                    .luminaFont(size: 12, weight: .bold)
                                    .foregroundColor(.organicMutedFg.opacity(0.74))
                            }
                            .padding(14)
                            .background(JournalEditorSurface(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Shuffle journal prompt")

                        VStack(alignment: .leading, spacing: 14) {
                            ZStack(alignment: .leading) {
                                if title.isEmpty {
                                    Text("Title")
                                        .luminaFont(size: 24, weight: .bold, design: .serif)
                                        .foregroundColor(.organicMutedFg.opacity(0.86))
                                        .padding(.horizontal, 16)
                                }

                                TextField("", text: $title)
                                    .luminaFont(size: 24, weight: .bold, design: .serif)
                                    .foregroundColor(.organicForeground)
                                    .tint(.organicPrimary)
                                    .padding(16)
                            }
                            .background(Color.organicMuted.opacity(0.98))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            ZStack(alignment: .topLeading) {
                                if content.isEmpty {
                                    Text("What's on your mind today?")
                                        .luminaFont(size: 16, weight: .medium, design: .serif)
                                        .foregroundColor(.organicMutedFg.opacity(0.86))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 18)
                                }

                                TextEditor(text: $content)
                                    .luminaFont(size: 16, weight: .medium, design: .serif)
                                    .foregroundColor(.organicForeground)
                                    .tint(.organicPrimary)
                                    .lineSpacing(4)
                                    .frame(minHeight: 190)
                                    .scrollContentBackground(.hidden)
                                    .padding(12)
                            }
                            .background(Color.organicMuted.opacity(0.98))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .padding(16)
                        .background(JournalEditorSurface(cornerRadius: 24))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("MOOD")
                                .luminaFont(size: 10, weight: .black)
                                .foregroundColor(.organicMutedFg)
                                .kerning(1.8)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(MoodType.allCases, id: \.self) { mood in
                                        Button(action: { selectedMood = mood }) {
                                            HStack(spacing: 7) {
                                                Image(systemName: mood.icon)
                                                    .luminaFont(size: 12, weight: .bold)
                                                Text(mood.label)
                                                    .luminaFont(size: 12, weight: .black)
                                            }
                                            .foregroundColor(selectedMood == mood ? .organicPrimaryFg : .organicMutedFg)
                                            .padding(.horizontal, 13)
                                            .frame(height: 36)
                                            .background(selectedMood == mood ? Color.organicPrimary : Color.organicMuted.opacity(0.72))
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 1)
                            }
                        }

                        HStack(spacing: 10) {
                            Button(action: toggleSpeechInput) {
                                Image(systemName: speechInput.isListening ? "mic.slash.fill" : "mic.fill")
                                    .luminaFont(size: 15, weight: .black)
                                    .foregroundColor(speechInput.isListening ? .white : .organicPrimary)
                                    .frame(width: 50, height: 50)
                                    .background(speechInput.isListening ? Color.red.opacity(0.88) : Color.organicCard)
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle()
                                            .strokeBorder(Color.organicBorder.opacity(0.70), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .disabled(!canToggleSpeechInput)
                            .opacity(canToggleSpeechInput ? 1 : 0.72)
                            .accessibilityLabel(speechInput.isListening ? "Stop voice input" : "Start voice input")

                            Button(action: analyzeEntry) {
                                HStack {
                                    if isAnalyzing {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text(isAnalyzing ? "Reflecting..." : "AI Reflection")
                                }
                                .luminaFont(size: 14, weight: .black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(trimmedContent.isEmpty ? Color.organicMuted.opacity(0.96) : Color.organicPrimary)
                                .foregroundColor(trimmedContent.isEmpty ? .organicMutedFg.opacity(0.84) : .organicPrimaryFg)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(trimmedContent.isEmpty || isAnalyzing)

                            Button(action: analyzePrism) {
                                HStack {
                                    if isAnalyzingDistortions {
                                        ProgressView().tint(.organicPrimary)
                                    } else {
                                        Image(systemName: "prism")
                                    }
                                    Text(isAnalyzingDistortions ? "Reading..." : "Prism")
                                }
                                .luminaFont(size: 14, weight: .black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(trimmedContent.isEmpty ? Color.organicMuted.opacity(0.96) : Color.organicAccent)
                                .foregroundColor(trimmedContent.isEmpty ? .organicMutedFg.opacity(0.82) : .organicForeground)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(trimmedContent.isEmpty || isAnalyzingDistortions)
                        }

                        if let speechStatusText {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(speechInput.errorMessage == nil ? Color.organicPrimary : Color.red)
                                    .frame(width: 6, height: 6)
                                Text(speechStatusText)
                                    .luminaFont(size: 11, weight: .semibold)
                                    .foregroundColor(speechInput.errorMessage == nil ? .organicMutedFg : Color.red.opacity(0.86))
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        }

                        if !reflection.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("AI Reflection", systemImage: "sparkles")
                                    .luminaFont(size: 14, weight: .bold)
                                    .foregroundColor(.organicPrimary)

                                Text(reflection)
                                    .luminaFont(size: 14, weight: .medium)
                                    .foregroundColor(.organicForeground)
                                    .lineSpacing(3)

                                if !actionItem.isEmpty {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.organicSecondary)
                                            .padding(.top, 1)
                                        Text(actionItem)
                                            .luminaFont(size: 13, weight: .semibold)
                                            .foregroundColor(.organicMutedFg)
                                    }
                                }

                                HStack(spacing: 8) {
                                    metricBadge(label: "Sentiment", value: sentimentScore, color: .organicPrimary)
                                    metricBadge(label: "Energy", value: energyLevel, color: .organicSecondary)
                                    metricBadge(label: "Anxiety", value: anxietyLevel, color: Color(hex: 0x9B59B6))
                                }

                                if !tags.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(tags, id: \.self) { tag in
                                                tagChip(tag)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(JournalEditorSurface(cornerRadius: 22))
                        }

                        if isPrismMode && !distortions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("The Prism", systemImage: "prism")
                                    .luminaFont(size: 14, weight: .bold)
                                    .foregroundColor(.organicPrimary)

                                ForEach(distortions) { distortion in
                                    DistortionCard(
                                        distortion: distortion,
                                        isActive: activeDistortion?.id == distortion.id,
                                        onTap: { activeDistortion = distortion },
                                        onReframe: { reframed in
                                            applyReframe(original: distortion.originalText, reframed: reframed)
                                        }
                                    )
                                }
                            }
                            .padding(16)
                            .background(JournalEditorSurface(cornerRadius: 22))
                        }

                        if let err = errorMsg {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(Color.dynamic(light: 0xBE185D, dark: 0xFFB4CF))
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.dynamic(light: 0xFCE7F3, dark: 0x3A1422))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Label("Therapy Memory", systemImage: "text.bubble.fill")
                                .luminaFont(size: 13, weight: .black)
                                .foregroundColor(.organicForeground)

                            Picker("Therapy Memory", selection: $therapyMemoryPolicy) {
                                ForEach(JournalTherapyMemoryPolicy.allCases, id: \.rawValue) { policy in
                                    Text(policy.title).tag(policy)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text("Choose whether this reflection may be summarized for Therapy. Full journal text is not sent as context.")
                                .luminaFont(size: 11, weight: .semibold)
                                .foregroundColor(.organicMutedFg)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .background(JournalEditorSurface(cornerRadius: 18))

                        Button(action: saveEntry) {
                            HStack {
                                Image(systemName: "checkmark")
                                Text(editingEntry == nil ? "Save Reflection" : "Update Reflection")
                            }
                            .luminaFont(size: 16, weight: .black)
                            .foregroundColor(canSaveEntry ? .organicPrimaryFg : .organicMutedFg.opacity(0.84))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(canSaveEntry ? Color.organicPrimary : Color.organicMuted.opacity(0.96))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSaveEntry)

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle(editingEntry == nil ? "New Reflection" : "Edit Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.organicBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        speechInput.cancel()
                        presentationMode.wrappedValue.dismiss()
                    }
                        .foregroundColor(.organicMutedFg)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editingEntry == nil ? "Save" : "Update") { saveEntry() }
                        .font(.headline)
                        .foregroundColor(canSaveEntry ? .organicPrimary : .organicMutedFg.opacity(0.82))
                        .disabled(!canSaveEntry)
                }
            }
            .onChange(of: speechInput.transcript) { transcript in
                applySpeechTranscript(transcript)
            }
            .onDisappear {
                speechInput.cancel()
            }
        }
    }

    func metricBadge(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)%")
                .luminaFont(size: 16, weight: .black)
                .foregroundColor(color)
            Text(label)
                .luminaFont(size: 9, weight: .bold)
                .foregroundColor(.organicMutedFg)
                .kerning(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .cornerRadius(12)
    }

    func tagChip(_ tag: String) -> some View {
        Text("#\(tag)")
            .luminaFont(size: 10, weight: .bold)
            .foregroundColor(.organicPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.organicPrimary.opacity(0.10))
            .cornerRadius(10)
    }

    func analyzeEntry() {
        guard !trimmedContent.isEmpty else { return }
        speechInput.stop()
        isAnalyzing = true
        errorMsg = nil
        Task {
            do {
                let analysis = try await GeminiService.shared.analyzeJournalEntry(trimmedContent)
                await MainActor.run {
                    if trimmedTitle.isEmpty { title = analysis.title }
                    if let mood = MoodType(rawValue: analysis.mood) { selectedMood = mood }
                    tags = analysis.tags
                    reflection = analysis.reflection
                    actionItem = analysis.actionItem
                    sentimentScore = analysis.sentimentScore
                    energyLevel = analysis.energyLevel
                    anxietyLevel = analysis.anxietyLevel
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    errorMsg = error.localizedDescription
                }
            }
        }
    }

    func analyzePrism() {
        guard !trimmedContent.isEmpty else { return }
        speechInput.stop()
        isAnalyzingDistortions = true
        isPrismMode = true
        errorMsg = nil
        Task {
            do {
                let result = try await GeminiService.shared.analyzeDistortions(trimmedContent)
                await MainActor.run {
                    distortions = result
                    isAnalyzingDistortions = false
                }
            } catch {
                await MainActor.run {
                    isAnalyzingDistortions = false
                    isPrismMode = false
                    errorMsg = error.localizedDescription
                }
            }
        }
    }

    func applyReframe(original: String, reframed: String) {
        content = content.replacingOccurrences(of: original, with: reframed)
        distortions.removeAll { $0.originalText == original }
        activeDistortion = nil
    }

    func toggleSpeechInput() {
        if speechInput.isListening {
            speechInput.stop()
        } else {
            speechInputPrefix = content.trimmingCharacters(in: .whitespacesAndNewlines)
            speechInput.start()
        }
    }

    func applySpeechTranscript(_ transcript: String) {
        guard !transcript.isEmpty else { return }
        let prefix = speechInputPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        content = prefix.isEmpty ? transcript : "\(prefix) \(transcript)"
    }

    func saveEntry() {
        guard canSaveEntry else { return }
        speechInput.stop()

        let entry = JournalEntry(
            id: editingEntry?.id ?? UUID().uuidString,
            date: editingEntry?.date ?? Date().formatted(.dateTime.month(.abbreviated).day()),
            timestamp: editingEntry?.timestamp ?? Date().timeIntervalSince1970,
            title: trimmedTitle.isEmpty ? "Untitled Reflection" : trimmedTitle,
            content: trimmedContent,
            mood: selectedMood,
            tags: tags.isEmpty ? ["Reflection"] : tags,
            reflection: reflection.isEmpty ? nil : reflection,
            actionItem: actionItem.isEmpty ? nil : actionItem,
            sentimentScore: sentimentScore,
            energyLevel: energyLevel,
            anxietyLevel: anxietyLevel,
            therapyMemoryPolicy: therapyMemoryPolicy == .automatic ? nil : therapyMemoryPolicy,
            isPinned: editingEntry?.isPinned ?? false
        )

        if editingEntry != nil {
            appState.updateEntry(entry)
        } else {
            appState.addEntry(entry)
        }
        presentationMode.wrappedValue.dismiss()
    }
}

private struct JournalEditorSurface: View {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(colorScheme == .dark ? Color.organicElevated : Color.organicCard)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.organicBorder.opacity(colorScheme == .dark ? 0.88 : 0.74), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.05), radius: 16, x: 0, y: 8)
    }
}

private struct JournalEditorBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.organicBackground

            RadialGradient(
                colors: [Color.organicPrimary.opacity(colorScheme == .dark ? 0.18 : 0.12), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 360
            )

            RadialGradient(
                colors: [Color.organicSecondary.opacity(colorScheme == .dark ? 0.10 : 0.12), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
    }
}

// MARK: - Distortion Card (Prism)
struct DistortionCard: View {
    let distortion: CognitiveDistortion
    let isActive: Bool
    let onTap: () -> Void
    let onReframe: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(distortion.type)
                            .luminaFont(size: 10, weight: .black)
                            .foregroundColor(.red)
                            .kerning(1)
                        Text("\"\(distortion.originalText)\"")
                            .luminaFont(size: 13, weight: .bold)
                            .foregroundColor(.organicForeground)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: isActive ? "chevron.up" : "chevron.down")
                        .foregroundColor(.organicMutedFg)
                }
                .padding(12)
                .background(Color.red.opacity(0.06))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            if isActive {
                Text(distortion.explanation)
                    .font(.caption)
                    .foregroundColor(.organicMutedFg)
                    .padding(.horizontal, 4)

                VStack(spacing: 8) {
                    ForEach(distortion.reframes) { reframe in
                        Button(action: { onReframe(reframe.text) }) {
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .frame(width: 8, height: 8)
                                    .foregroundColor(reframe.perspective == "rational" ? .blue : reframe.perspective == "compassionate" ? .pink : .gray)
                                    .padding(.top, 4)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reframe.perspective.uppercased())
                                        .luminaFont(size: 9, weight: .black)
                                        .foregroundColor(.organicMutedFg)
                                        .kerning(1)
                                    Text("\"\(reframe.text)\"")
                                        .font(.caption)
                                        .foregroundColor(.organicForeground)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                    .foregroundColor(.organicPrimary)
                            }
                            .padding(10)
                            .background(Color.organicCard)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.organicBorder.opacity(0.5), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
