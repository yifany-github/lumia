import SwiftUI

// MARK: - Insights Tab
struct InsightsTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var insights: DeepInsights? = nil
    @State private var isLoading = false
    @State private var errorMsg: String? = nil
    @State private var lastGeneratedAt: TimeInterval?
    @State private var didCheckDailyGeneration = false
    
    var body: some View {
        VStack(spacing: 20) {
            if appState.entries.isEmpty {
                emptyState
            } else if isLoading {
                loadingState
            } else if let insights = insights {
                insightsContent(insights)
            } else {
                insightIntroCard
            }
        }
        .onAppear {
            loadCachedInsights()
            generateDailyInsightsIfNeeded()
        }
    }
    
    var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .luminaFont(size: 28, weight: .bold)
                .foregroundColor(.organicSecondary)
                .frame(width: 58, height: 58)
                .background(Color.organicSecondary.opacity(0.12))
                .clipShape(Circle())
            Text("Patterns will appear here")
                .luminaFont(size: 22, weight: .bold, design: .serif)
                .foregroundColor(.organicForeground)
            Text("After a few entries, today can have one quiet summary.")
                .luminaFont(size: 13, weight: .medium)
                .foregroundColor(.organicMutedFg)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.64), lineWidth: 1)
        }
    }
    
    var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.organicSecondary)
                .scaleEffect(1.25)
            Text("Saving today’s pattern")
                .luminaFont(size: 20, weight: .bold, design: .serif)
                .foregroundColor(.organicForeground)
            Text("Looking across recent entries. Saved for the day.")
                .luminaFont(size: 13, weight: .medium)
                .foregroundColor(.organicMutedFg)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 34)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.64), lineWidth: 1)
        }
    }
    
    var insightIntroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .luminaFont(size: 16, weight: .bold)
                    .foregroundColor(.organicSecondary)
                    .frame(width: 40, height: 40)
                    .background(Color.organicSecondary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Today’s pattern")
                        .luminaFont(size: 23, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                    Text("One saved summary for the day. Refresh only when useful.")
                        .luminaFont(size: 13, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                InsightHintRow(icon: "checkmark.seal.fill", text: "Once a day")
                InsightHintRow(icon: "lock.fill", text: "Saved with your journal")
                InsightHintRow(icon: "arrow.clockwise", text: "Refresh when useful")
            }

            generateButton(title: "Find the pattern")

            if let errorMsg {
                Text(errorMsg)
                    .luminaFont(size: 12, weight: .semibold)
                    .foregroundColor(Color(hex: 0xBE185D))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.64), lineWidth: 1)
        }
    }
    
    func insightsContent(_ insights: DeepInsights) -> some View {
        VStack(spacing: 16) {
            // Mental Health Wrapped
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today’s pattern")
                            .luminaFont(size: 22, weight: .bold, design: .serif)
                            .foregroundColor(.organicForeground)
                        if let lastGeneratedAt {
                            Text("Saved at \(formattedTime(lastGeneratedAt))")
                                .luminaFont(size: 11, weight: .bold)
                                .foregroundColor(.organicMutedFg)
                        }
                    }
                    Spacer(minLength: 0)
                }
                Text(insights.wrapped.summary)
                    .luminaFont(size: 13, weight: .medium)
                    .foregroundColor(.organicMutedFg)
                    .lineSpacing(3)
                
                HStack(spacing: 10) {
                    VStack(alignment: .leading) {
                        Text("STEADY MOMENTS").luminaFont(size: 9, weight: .black).foregroundColor(.organicPrimary).kerning(1)
                        Text("\(insights.wrapped.lowPointsOvercome)").luminaFont(size: 30, weight: .black, design: .serif).foregroundColor(.organicForeground)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("FOCUS").luminaFont(size: 9, weight: .black).foregroundColor(.organicSecondary).kerning(1)
                        Text(insights.wrapped.growthArea).luminaFont(size: 12, weight: .bold).foregroundColor(.organicForeground).multilineTextAlignment(.trailing)
                    }
                }
                
                if !insights.wrapped.topPositiveWords.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WORDS NOTICED").luminaFont(size: 9, weight: .black).foregroundColor(.organicSecondary).kerning(1)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 6)], alignment: .leading, spacing: 6) {
                            ForEach(insights.wrapped.topPositiveWords, id: \.self) { word in
                                Text(word)
                                    .luminaFont(size: 11, weight: .bold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.organicSecondary.opacity(0.15)).cornerRadius(10)
                                    .foregroundColor(.organicSecondary)
                            }
                        }
                    }
                }
            }
            .padding(20).background(Color.organicCard).cornerRadius(28)
            
            // Triggers
            if !insights.triggers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Patterns to notice").luminaFont(size: 18, weight: .bold, design: .serif).foregroundColor(.organicForeground)
                    
                    ForEach(insights.triggers) { trigger in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(trigger.trigger).luminaFont(size: 15, weight: .bold).foregroundColor(.organicForeground)
                            Text(trigger.effect).luminaFont(size: 12, weight: .medium).foregroundColor(.organicMutedFg)
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "lightbulb.fill").luminaFont(size: 11, weight: .bold).foregroundColor(.organicPrimary)
                                Text(trigger.suggestion).luminaFont(size: 12, weight: .semibold).foregroundColor(.organicPrimary)
                            }
                        }
                        .padding(14).background(Color.organicMuted).cornerRadius(16)
                    }
                }
                .padding(20).background(Color.organicCard).cornerRadius(28)
            }
            
            Button(action: { fetchInsights(force: true) }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundColor(.organicMutedFg)
                    .frame(height: 38)
                    .padding(.horizontal, 14)
                    .background(Color.organicMuted.opacity(colorScheme == .dark ? 0.86 : 0.62))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            if let errorMsg {
                Text(errorMsg)
                    .luminaFont(size: 12, weight: .semibold)
                    .foregroundColor(Color(hex: 0xBE185D))
                    .multilineTextAlignment(.center)
            }
        }
    }

    func generateButton(title: String) -> some View {
        Button(action: { fetchInsights(force: true) }) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                Text(title)
            }
            .luminaFont(size: 15, weight: .bold)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.organicSecondary)
            .foregroundColor(colorScheme == .dark ? .organicBackground : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    func loadCachedInsights() {
        guard let cached = appState.dailyJournalInsights,
              cached.dateKey == appState.journalInsightDateKey()
        else { return }
        insights = cached.insights
        lastGeneratedAt = cached.generatedAt
    }

    func generateDailyInsightsIfNeeded() {
        guard !didCheckDailyGeneration else { return }
        didCheckDailyGeneration = true
        guard !appState.entries.isEmpty else { return }
        if let cached = appState.dailyJournalInsights,
           cached.dateKey == appState.journalInsightDateKey() {
            insights = cached.insights
            lastGeneratedAt = cached.generatedAt
            return
        }
        fetchInsights(force: false)
    }

    func fetchInsights(force: Bool) {
        guard !appState.entries.isEmpty else { return }
        if !force,
           let cached = appState.dailyJournalInsights,
           cached.dateKey == appState.journalInsightDateKey() {
            insights = cached.insights
            lastGeneratedAt = cached.generatedAt
            return
        }
        errorMsg = nil
        isLoading = true
        Task {
            do {
                let result = try await GeminiService.shared.generateDeepInsights(entries: appState.entries)
                await MainActor.run {
                    if let result {
                        let saved = DailyJournalInsights(
                            dateKey: appState.journalInsightDateKey(),
                            entryFingerprint: appState.journalInsightEntryFingerprint(),
                            insights: result
                        )
                        appState.saveDailyJournalInsights(saved)
                        insights = result
                        lastGeneratedAt = saved.generatedAt
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false; errorMsg = error.localizedDescription }
            }
        }
    }

    func formattedTime(_ timestamp: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}

private struct InsightHintRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .luminaFont(size: 11, weight: .bold)
                .foregroundColor(.organicPrimary)
                .frame(width: 18, height: 18)
            Text(text)
                .luminaFont(size: 12, weight: .medium)
                .foregroundColor(.organicMutedFg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
