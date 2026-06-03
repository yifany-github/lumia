import SwiftUI

struct TimelineTabView: View {
    @EnvironmentObject var appState: AppState
    @Binding var editorRoute: JournalEditorRoute?

    @State private var searchText = ""
    @State private var selectedMood: MoodType?
    @State private var entryPendingDelete: JournalEntry?
    @State private var previewEntry: JournalEntry?
    @State private var showingDeleteConfirmation = false

    private var sortedEntries: [JournalEntry] {
        appState.entries.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.timestamp > $1.timestamp
        }
    }

    private var filteredEntries: [JournalEntry] {
        sortedEntries.filter { entry in
            matchesMood(entry) && matchesSearch(entry)
        }
    }

    private var averageSentiment: Int? {
        let scores = sortedEntries.compactMap(\.sentimentScore)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            JournalTimelineSummary(
                entryCount: sortedEntries.count,
                filteredCount: filteredEntries.count,
                averageSentiment: averageSentiment,
                latestEntry: sortedEntries.first
            )

            JournalTimelineTools(
                searchText: $searchText,
                selectedMood: $selectedMood,
                onNewReflection: openNewReflection
            )

            if filteredEntries.isEmpty {
                JournalEmptyState(
                    hasEntries: !sortedEntries.isEmpty,
                    onNewReflection: openNewReflection,
                    onClearFilters: clearFilters
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredEntries) { entry in
                        JournalCard(
                            entry: entry,
                            onOpen: { previewEntry = entry },
                            onEdit: { openEditor(entry) },
                            onTogglePin: { togglePin(entry) },
                            onDelete: { confirmDelete(entry) }
                        )
                    }
                }
            }
        }
        .alert(
            "Delete this reflection?",
            isPresented: $showingDeleteConfirmation,
            presenting: entryPendingDelete
        ) { entry in
            Button("Delete Reflection", role: .destructive) {
                showingDeleteConfirmation = false
                entryPendingDelete = nil
                if previewEntry?.id == entry.id {
                    previewEntry = nil
                }
                withAnimation(.easeInOut(duration: 0.16)) {
                    appState.deleteEntry(id: entry.id)
                }
            }
            Button("Cancel", role: .cancel) {
                entryPendingDelete = nil
            }
        } message: { _ in
            Text("This removes the entry from your journal.")
        }
        .onChange(of: showingDeleteConfirmation) { isPresented in
            if !isPresented {
                entryPendingDelete = nil
            }
        }
        .sheet(item: $previewEntry) { entry in
            JournalPreviewView(
                entry: currentEntry(for: entry) ?? entry,
                onTogglePin: {
                    togglePin(entry)
                    previewEntry = currentEntry(for: entry)
                },
                onDelete: {
                    previewEntry = nil
                    confirmDelete(entry)
                }
            )
        }
    }

    private func openNewReflection() {
        editorRoute = .new()
    }

    private func openEditor(_ entry: JournalEntry) {
        editorRoute = .edit(entry)
    }

    private func togglePin(_ entry: JournalEntry) {
        withAnimation(.easeInOut(duration: 0.18)) {
            appState.toggleEntryPin(id: entry.id)
        }
    }

    private func currentEntry(for entry: JournalEntry) -> JournalEntry? {
        appState.entries.first { $0.id == entry.id }
    }

    private func confirmDelete(_ entry: JournalEntry) {
        entryPendingDelete = entry
        showingDeleteConfirmation = true
    }

    private func clearFilters() {
        searchText = ""
        selectedMood = nil
    }

    private func matchesMood(_ entry: JournalEntry) -> Bool {
        guard let selectedMood else { return true }
        return entry.mood == selectedMood
    }

    private func matchesSearch(_ entry: JournalEntry) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let fields = [
            entry.title,
            entry.displayContent,
            entry.date,
            entry.reflection ?? "",
            entry.actionItem ?? "",
            entry.summary ?? ""
        ] + entry.tags

        return fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

private struct JournalTimelineSummary: View {
    let entryCount: Int
    let filteredCount: Int
    let averageSentiment: Int?
    let latestEntry: JournalEntry?

    private var tint: Color {
        latestEntry?.mood.timelineTint ?? .organicPrimary
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            JournalReflectionBackdrop(tint: tint)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.pages.fill")
                            .luminaFont(size: 12, weight: .bold)
                        Text("Journal")
                            .luminaFont(size: 11, weight: .black)
                            .kerning(1.6)
                            .textCase(.uppercase)
                    }
                    .foregroundColor(.organicPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Color.organicPrimary.opacity(0.10))
                    .clipShape(Capsule())

                    Spacer()

                    Text(metaLine)
                        .luminaFont(size: 10, weight: .black)
                        .foregroundColor(.organicMutedFg)
                        .kerning(1.2)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(latestEntry?.title ?? "Start with one sentence")
                        .luminaFont(size: 24, weight: .bold, design: .serif)
                        .foregroundColor(.organicForeground)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(summaryCopy)
                        .luminaFont(size: 14, weight: .medium)
                        .foregroundColor(.organicMutedFg)
                        .lineSpacing(3)
                        .lineLimit(2)
                }

                if entryCount > 0 {
                    HStack(spacing: 8) {
                        Label("\(entryCount) \(entryCount == 1 ? "entry" : "entries")", systemImage: "scroll.fill")
                        if filteredCount != entryCount {
                            Label("\(filteredCount) showing", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        if let averageSentiment {
                            Label("\(averageSentiment)% tone", systemImage: "waveform.path.ecg")
                        }
                    }
                    .luminaFont(size: 11, weight: .bold)
                    .foregroundColor(.organicMutedFg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 174)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
    }

    private var metaLine: String {
        guard let latestEntry else { return "BEGIN ANYWHERE" }
        return latestEntry.date.uppercased()
    }

    private var summaryCopy: String {
        guard let latestEntry else {
            return "Write a little. Come back when you want."
        }
        if let reflection = latestEntry.reflection, !reflection.isEmpty {
            return reflection
        }
        return latestEntry.displayContent
    }
}

private struct JournalReflectionBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.organicElevated, Color.organicMuted.opacity(0.96), Color.organicCard]
                    : [Color.organicCard, Color.organicMuted.opacity(0.78), Color.organicBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [tint.opacity(colorScheme == .dark ? 0.30 : 0.24), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 320
            )

            RadialGradient(
                colors: [Color.organicSecondary.opacity(colorScheme == .dark ? 0.12 : 0.16), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 280
            )

            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill((index.isMultiple(of: 3) ? tint : Color.organicSecondary).opacity(index.isMultiple(of: 2) ? 0.14 : 0.08))
                    .frame(width: CGFloat(34 + (index * 19) % 90), height: CGFloat(5 + (index * 7) % 18))
                    .rotationEffect(.degrees(Double((index * 31) % 70) - 35))
                    .offset(
                        x: CGFloat((index * 43) % 320) - 160,
                        y: CGFloat((index * 61) % 280) - 140
                    )
                    .blur(radius: CGFloat((index % 4) + 2))
            }
        }
    }
}

private struct JournalTimelineTools: View {
    @Binding var searchText: String
    @Binding var selectedMood: MoodType?
    let onNewReflection: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .luminaFont(size: 13, weight: .bold)
                        .foregroundColor(.organicMutedFg)

                    TextField("Search reflections", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(false)
                        .luminaFont(size: 14, weight: .semibold)
                        .foregroundColor(.organicForeground)
                        .tint(.organicPrimary)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .luminaFont(size: 14, weight: .bold)
                                .foregroundColor(.organicMutedFg.opacity(0.70))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color.organicCard)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.organicBorder.opacity(0.75), lineWidth: 1)
                }

                Button(action: onNewReflection) {
                    Image(systemName: "square.and.pencil")
                        .luminaFont(size: 16, weight: .black)
                        .foregroundColor(.organicPrimaryFg)
                        .frame(width: 48, height: 48)
                        .background(Color.organicPrimary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New reflection")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    JournalMoodChip(
                        title: "All",
                        icon: "circle.grid.2x2.fill",
                        tint: .organicPrimary,
                        isSelected: selectedMood == nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedMood = nil
                        }
                    }

                    ForEach(MoodType.allCases, id: \.self) { mood in
                        JournalMoodChip(
                            title: mood.label,
                            icon: mood.icon,
                            tint: mood.timelineTint,
                            isSelected: selectedMood == mood
                        ) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedMood = mood
                            }
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

private struct JournalMoodChip: View {
    let title: String
    let icon: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .luminaFont(size: 11, weight: .black)
                Text(title)
                    .luminaFont(size: 12, weight: .black)
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .organicPrimaryFg : .organicMutedFg)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(isSelected ? tint : Color.organicCard)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : Color.organicBorder.opacity(0.72), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct JournalCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: JournalEntry
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: entry.mood.icon)
                    .luminaFont(size: 14, weight: .bold)
                    .foregroundColor(entry.mood.timelineTint)
                    .frame(width: 36, height: 36)
                    .background(entry.mood.timelineTint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        if entry.isPinned {
                            Image(systemName: "pin.fill")
                                .luminaFont(size: 8, weight: .black)
                                .foregroundColor(.organicPrimary)
                        }
                        Text(entry.date.uppercased())
                            .luminaFont(size: 9, weight: .black)
                            .foregroundColor(.organicMutedFg)
                            .kerning(1.7)
                    }

                    Text(entry.mood.label)
                        .luminaFont(size: 11, weight: .black)
                        .foregroundColor(.organicMutedFg)
                }

                Spacer(minLength: 8)

                Menu {
                    Button(entry.isPinned ? "Unpin Reflection" : "Pin Reflection", systemImage: entry.isPinned ? "pin.slash" : "pin.fill", action: onTogglePin)
                    Button("Edit Reflection", systemImage: "pencil", action: onEdit)
                    Button("Delete Reflection", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .luminaFont(size: 15, weight: .black)
                        .foregroundColor(.organicMutedFg)
                        .frame(width: 38, height: 38)
                        .background(Color.organicMuted.opacity(0.70))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reflection actions")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(entry.title)
                    .luminaFont(size: 21, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                JournalMarkdownInlineText(
                    text: entry.displayContent,
                    size: 14,
                    weight: .medium,
                    color: .organicMutedFg,
                    lineLimit: 2
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let keptLine {
                Label(keptLine, systemImage: keptIcon)
                    .luminaFont(size: 12, weight: .semibold)
                    .foregroundColor(.organicForeground.opacity(colorScheme == .dark ? 0.82 : 0.72))
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .frame(height: 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.organicMuted.opacity(colorScheme == .dark ? 0.78 : 0.50))
                    .clipShape(Capsule())
            }

            if !entry.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entry.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .luminaFont(size: 10, weight: .black)
                                .foregroundColor(.organicMutedFg)
                                .padding(.horizontal, 10)
                                .frame(height: 24)
                                .background(Color.organicMuted.opacity(0.72))
                                .clipShape(Capsule())
                        }
                        if entry.tags.count > 3 {
                            Text("+\(entry.tags.count - 3)")
                                .luminaFont(size: 10, weight: .black)
                                .foregroundColor(.organicMutedFg)
                                .padding(.horizontal, 9)
                                .frame(height: 24)
                                .background(Color.organicMuted.opacity(0.48))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.organicCard.opacity(colorScheme == .dark ? 0.96 : 0.82))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(entry.isPinned ? Color.organicPrimary.opacity(0.48) : Color.organicBorder.opacity(0.70), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture(perform: onOpen)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens reflection preview")
    }

    private var keptLine: String? {
        if let action = entry.actionItem?.trimmingCharacters(in: .whitespacesAndNewlines), !action.isEmpty {
            return action
        }
        if let reflection = entry.reflection?.trimmingCharacters(in: .whitespacesAndNewlines), !reflection.isEmpty {
            return reflection
        }
        let summary = entry.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return summary.isEmpty ? nil : summary
    }

    private var keptIcon: String {
        entry.actionItem?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? "checkmark.circle.fill"
            : "quote.bubble.fill"
    }
}

private struct JournalPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isEditing = false
    let entry: JournalEntry
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            if isEditing {
                JournalEditorView(editingEntry: entry)
                    .id("preview-edit-\(entry.id)")
            } else {
                previewBody
            }
        }
        .presentationDetents([.large])
    }

    private var previewBody: some View {
        NavigationView {
            ZStack {
                JournalPreviewBackdrop().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: entry.mood.icon)
                                .luminaFont(size: 16, weight: .bold)
                                .foregroundColor(entry.mood.timelineTint)
                                .frame(width: 44, height: 44)
                                .background(entry.mood.timelineTint.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 7) {
                                    if entry.isPinned {
                                        Image(systemName: "pin.fill")
                                            .luminaFont(size: 9, weight: .black)
                                            .foregroundColor(.organicPrimary)
                                    }
                                    Text(entry.date.uppercased())
                                        .luminaFont(size: 10, weight: .black)
                                        .foregroundColor(.organicMutedFg)
                                        .kerning(1.7)
                                }
                                Text(entry.mood.label)
                                    .luminaFont(size: 12, weight: .black)
                                    .foregroundColor(.organicMutedFg)
                            }

                            Spacer(minLength: 0)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text(entry.title)
                                .luminaFont(size: 31, weight: .bold, design: .serif)
                                .foregroundColor(.organicForeground)
                                .fixedSize(horizontal: false, vertical: true)

                            JournalMarkdownText(
                                text: entry.displayContent,
                                baseSize: 16,
                                color: .organicForeground.opacity(colorScheme == .dark ? 0.84 : 0.78)
                            )
                        }

                        if let reflection = entry.reflection, !reflection.isEmpty {
                            JournalPreviewInsight(icon: "quote.bubble.fill", title: "Kept", text: reflection, tint: .organicSecondary)
                        }

                        if let actionItem = entry.actionItem, !actionItem.isEmpty {
                            JournalPreviewInsight(icon: "checkmark.circle.fill", title: "Next", text: actionItem, tint: .organicPrimary)
                        }

                        if let score = entry.sentimentScore {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tone")
                                    .luminaFont(size: 10, weight: .black)
                                    .foregroundColor(.organicMutedFg)
                                    .kerning(1.6)
                                JournalToneMeter(score: score, tint: entry.mood.timelineTint)
                            }
                            .padding(14)
                            .background(Color.organicCard.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        if !entry.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(entry.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .luminaFont(size: 12, weight: .black)
                                            .foregroundColor(.organicMutedFg)
                                            .padding(.horizontal, 12)
                                            .frame(height: 32)
                                            .background(Color.organicMuted.opacity(0.60), in: Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .luminaFont(size: 14, weight: .bold)
                    .foregroundColor(.organicPrimary)
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .luminaFont(size: 13, weight: .bold)
                    .accessibilityLabel("Edit reflection")

                    Menu {
                        Button(entry.isPinned ? "Unpin Reflection" : "Pin Reflection", systemImage: entry.isPinned ? "pin.slash" : "pin.fill", action: onTogglePin)
                        Button("Delete Reflection", systemImage: "trash", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More reflection actions")
                }
            }
        }
    }
}

private struct JournalPreviewBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(hex: 0x071007), Color.organicBackground, Color(hex: 0x19190F)]
                : [Color.organicBackground, Color.organicBackdrop],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct JournalPreviewInsight: View {
    let icon: String
    let title: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .luminaFont(size: 13, weight: .bold)
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .luminaFont(size: 11, weight: .black)
                    .foregroundColor(.organicMutedFg)
                    .textCase(.uppercase)
                    .kerning(1.2)
                JournalMarkdownInlineText(
                    text: text,
                    size: 14,
                    weight: .semibold,
                    color: .organicForeground.opacity(0.84),
                    lineLimit: nil
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.organicCard.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.54), lineWidth: 1)
        }
    }
}

private struct JournalMarkdownText: View {
    let text: String
    let baseSize: CGFloat
    let color: Color

    private var blocks: [JournalMarkdownBlock] {
        JournalMarkdownBlock.parse(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks) { block in
                switch block.kind {
                case .heading1:
                    JournalMarkdownInlineText(
                        text: block.text,
                        size: baseSize + 8,
                        weight: .bold,
                        color: color,
                        lineLimit: nil
                    )
                case .heading2:
                    JournalMarkdownInlineText(
                        text: block.text,
                        size: baseSize + 4,
                        weight: .bold,
                        color: color,
                        lineLimit: nil
                    )
                case .heading3:
                    JournalMarkdownInlineText(
                        text: block.text,
                        size: baseSize + 1,
                        weight: .bold,
                        color: color,
                        lineLimit: nil
                    )
                case .bullet:
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Circle()
                            .fill(Color.organicPrimary.opacity(0.78))
                            .frame(width: 5, height: 5)
                        JournalMarkdownInlineText(
                            text: block.text,
                            size: baseSize,
                            weight: .medium,
                            color: color,
                            lineLimit: nil
                        )
                    }
                case .numbered:
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(block.marker ?? "")
                            .luminaFont(size: baseSize - 1, weight: .black, design: .rounded)
                            .foregroundColor(.organicPrimary)
                            .frame(minWidth: 18, alignment: .trailing)
                        JournalMarkdownInlineText(
                            text: block.text,
                            size: baseSize,
                            weight: .medium,
                            color: color,
                            lineLimit: nil
                        )
                    }
                case .quote:
                    JournalMarkdownInlineText(
                        text: block.text,
                        size: baseSize,
                        weight: .semibold,
                        color: color,
                        lineLimit: nil
                    )
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.organicPrimary.opacity(0.38))
                            .frame(width: 3)
                    }
                case .paragraph:
                    JournalMarkdownInlineText(
                        text: block.text,
                        size: baseSize,
                        weight: .medium,
                        color: color,
                        lineLimit: nil
                    )
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct JournalMarkdownInlineText: View {
    let text: String
    let size: CGFloat
    let weight: Font.Weight
    let color: Color
    let lineLimit: Int?

    private var attributedText: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    var body: some View {
        Text(attributedText)
            .font(.system(size: size, weight: weight, design: .serif))
            .foregroundColor(color)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: lineLimit == nil)
    }
}

private struct JournalMarkdownBlock: Identifiable {
    enum Kind {
        case heading1
        case heading2
        case heading3
        case bullet
        case numbered
        case quote
        case paragraph
    }

    let id: Int
    let kind: Kind
    let text: String
    let marker: String?

    static func parse(_ markdown: String) -> [JournalMarkdownBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [JournalMarkdownBlock] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let id = blocks.count
            if line.hasPrefix("### ") {
                blocks.append(JournalMarkdownBlock(id: id, kind: .heading3, text: String(line.dropFirst(4)), marker: nil))
            } else if line.hasPrefix("## ") {
                blocks.append(JournalMarkdownBlock(id: id, kind: .heading2, text: String(line.dropFirst(3)), marker: nil))
            } else if line.hasPrefix("# ") {
                blocks.append(JournalMarkdownBlock(id: id, kind: .heading1, text: String(line.dropFirst(2)), marker: nil))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                blocks.append(JournalMarkdownBlock(id: id, kind: .bullet, text: String(line.dropFirst(2)), marker: nil))
            } else if line.hasPrefix("> ") {
                blocks.append(JournalMarkdownBlock(id: id, kind: .quote, text: String(line.dropFirst(2)), marker: nil))
            } else if let numbered = numberedLine(line) {
                blocks.append(JournalMarkdownBlock(id: id, kind: .numbered, text: numbered.text, marker: numbered.marker))
            } else {
                blocks.append(JournalMarkdownBlock(id: id, kind: .paragraph, text: line, marker: nil))
            }
        }

        return blocks
    }

    private static func numberedLine(_ line: String) -> (marker: String, text: String)? {
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let marker = line[..<dotIndex]
        guard !marker.isEmpty, marker.allSatisfy({ $0.isNumber }) else { return nil }
        let textStart = line.index(after: dotIndex)
        guard textStart < line.endIndex else { return nil }
        let text = line[textStart...].trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return ("\(marker).", text)
    }
}

private struct JournalToneMeter: View {
    let score: Int
    let tint: Color

    private var clampedScore: Int {
        min(max(score, 0), 100)
    }

    var body: some View {
        HStack(spacing: 9) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.organicMuted)
                    Capsule()
                        .fill(tint.opacity(0.86))
                        .frame(width: geo.size.width * CGFloat(clampedScore) / 100)
                }
            }
            .frame(height: 7)

            Text("\(clampedScore)%")
                .luminaFont(size: 10, weight: .black)
                .foregroundColor(.organicMutedFg)
                .frame(width: 34, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tone score \(clampedScore) percent")
    }
}

private struct JournalEmptyState: View {
    let hasEntries: Bool
    let onNewReflection: () -> Void
    let onClearFilters: () -> Void

    private let examples = [
        JournalGuideExample(
            title: "A tense meeting",
            mood: .anxious,
            body: "I kept replaying what I said. One thing I know for sure: I was trying to be clear, not difficult.",
            cue: "Name the moment, then one fact."
        ),
        JournalGuideExample(
            title: "A small steady thing",
            mood: .calm,
            body: "I drank water before coffee and looked outside for a minute. It did not fix the day, but it softened the start.",
            cue: "Small evidence counts."
        )
    ]

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasEntries ? "line.3.horizontal.decrease.circle" : "square.and.pencil")
                .luminaFont(size: 30, weight: .bold)
                .foregroundColor(.organicPrimary)
                .frame(width: 66, height: 66)
                .background(Color.organicPrimary.opacity(0.10))
                .clipShape(Circle())

            VStack(spacing: 6) {
                Text(hasEntries ? "No matching entries" : "Start with one sentence")
                    .luminaFont(size: 20, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
                    .multilineTextAlignment(.center)
                Text(hasEntries ? "Clear filters or try another phrase." : "Use a shape below, or write your own.")
                    .luminaFont(size: 13, weight: .medium)
                    .foregroundColor(.organicMutedFg)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            if !hasEntries {
                VStack(spacing: 9) {
                    ForEach(examples) { example in
                        JournalGuideExampleCard(example: example)
                    }
                }
                .padding(.top, 2)
            }

            Button(action: hasEntries ? onClearFilters : onNewReflection) {
                Text(hasEntries ? "Clear Filters" : "New Reflection")
                    .luminaFont(size: 13, weight: .black)
                    .foregroundColor(.organicPrimaryFg)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(Color.organicPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.72), lineWidth: 1)
        }
    }
}

private struct JournalGuideExample: Identifiable {
    let id = UUID()
    let title: String
    let mood: MoodType
    let body: String
    let cue: String
}

private struct JournalGuideExampleCard: View {
    let example: JournalGuideExample

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: example.mood.icon)
                .luminaFont(size: 13, weight: .bold)
                .foregroundColor(example.mood.timelineTint)
                .frame(width: 34, height: 34)
                .background(example.mood.timelineTint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text("Example")
                        .luminaFont(size: 9, weight: .black)
                        .foregroundColor(.organicPrimary)
                        .kerning(1.0)
                        .textCase(.uppercase)
                    Text(example.cue)
                        .luminaFont(size: 10, weight: .bold)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(1)
                }

                Text(example.title)
                    .luminaFont(size: 14, weight: .bold, design: .serif)
                    .foregroundColor(.organicForeground)
                    .lineLimit(1)

                Text(example.body)
                    .luminaFont(size: 12, weight: .medium)
                    .foregroundColor(.organicMutedFg)
                    .lineSpacing(2)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Color.organicMuted.opacity(0.40))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

extension MoodType {
    var timelineTint: Color {
        switch self {
        case .happy: return Color(hex: 0xD97706)
        case .calm: return Color(hex: 0x4A90E2)
        case .anxious: return Color(hex: 0x8B5CF6)
        case .sad: return Color(hex: 0x6366F1)
        case .neutral: return Color(hex: 0x78786C)
        case .energetic: return Color(hex: 0xC18C5D)
        }
    }
}
