import SwiftUI

// MARK: - Shared UI Components used across multiple views

enum LumiaLegalURL {
    static let privacyPolicy = URL(string: "https://lumia-cd3d2.web.app/privacy.html")!
    static let appleStandardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let hostedTerms = URL(string: "https://lumia-cd3d2.web.app/terms.html")!
    static let termsOfUse = appleStandardEULA
}

struct LumiaAIDataSharingConsentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onAllow: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .luminaFont(size: 22, weight: .black)
                        .foregroundStyle(Color.organicPrimary)
                        .frame(width: 52, height: 52)
                        .background(Color.organicPrimary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("AI data sharing")
                        .luminaFont(size: 28, weight: .bold, design: .serif)
                        .foregroundStyle(Color.organicForeground)

                    Text("Lumia uses AI to generate chat replies, reflections, insights, and live voice responses. Please review what is shared before continuing.")
                        .luminaFont(size: 14, weight: .medium)
                        .foregroundStyle(Color.organicMutedFg)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    LumiaAIConsentRow(
                        icon: "doc.text.fill",
                        title: "Data sent",
                        text: "Messages you send, recent conversation history, selected journal or therapy context, live voice audio/transcripts, and camera frames only when you turn on Share camera."
                    )
                    LumiaAIConsentRow(
                        icon: "building.2.fill",
                        title: "Sent to",
                        text: "Lumia cloud services on Firebase/Google Cloud and Google Gemini/Firebase AI Logic."
                    )
                    LumiaAIConsentRow(
                        icon: "checkmark.shield.fill",
                        title: "Used for",
                        text: "Generating supportive responses and insights for you. Lumia does not use this data for advertising or tracking."
                    )
                }

                HStack(spacing: 14) {
                    Link("Privacy Policy", destination: LumiaLegalURL.privacyPolicy)
                    Link("Terms", destination: LumiaLegalURL.termsOfUse)
                }
                .luminaFont(size: 12, weight: .bold)
                .foregroundStyle(Color.organicPrimary)

                VStack(spacing: 10) {
                    Button(action: onAllow) {
                        Label("Agree and continue", systemImage: "checkmark")
                            .luminaFont(size: 16, weight: .black)
                            .foregroundStyle(Color.organicPrimaryFg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.organicPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: { dismiss() }) {
                        Text("Not now")
                            .luminaFont(size: 14, weight: .bold)
                            .foregroundStyle(Color.organicMutedFg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.organicMuted.opacity(0.82))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .padding(22)
        }
        .background(Color.organicBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .luminaFoldSafeSheet()
    }
}

private struct LumiaAIConsentRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .luminaFont(size: 13, weight: .black)
                .foregroundStyle(Color.organicPrimary)
                .frame(width: 34, height: 34)
                .background(Color.organicPrimary.opacity(0.10))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .luminaFont(size: 13, weight: .black)
                    .foregroundStyle(Color.organicForeground)
                Text(text)
                    .luminaFont(size: 12, weight: .medium)
                    .foregroundStyle(Color.organicMutedFg)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.48), lineWidth: 1)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: LuminaAssetIcon
// ─────────────────────────────────────────────────────────────────────────────
struct LuminaAssetIcon: View {
    let name: String
    let size: CGFloat
    let tint: Color

    var body: some View {
        Image(name)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: tint.opacity(0.10), radius: 3, x: 0, y: 1)
            .accessibilityHidden(true)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: ProfileStat
// ─────────────────────────────────────────────────────────────────────────────
struct ProfileStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(color.opacity(0.1)).frame(width: 38, height: 38)
                Image(systemName: icon).luminaFont(size: 15).foregroundColor(color)
            }
            Text(value)
                .luminaFont(size: 20, weight: .black).foregroundColor(color).minimumScaleFactor(0.6)
            Text(label)
                .luminaFont(size: 9, weight: .bold).foregroundColor(.organicMutedFg)
                .multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(color.opacity(0.05)).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.12), lineWidth: 1))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: SectionHeader
// ─────────────────────────────────────────────────────────────────────────────
struct SectionHeader: View {
    let title: String
    let icon: String
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon).luminaFont(size: 12, weight: .semibold).foregroundColor(.organicPrimary)
            Text(title.uppercased()).luminaFont(size: 11, weight: .black).foregroundColor(.organicMutedFg).kerning(1.5)
        }
        .padding(.bottom, 8).padding(.top, 2)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: SettingsRow
// ─────────────────────────────────────────────────────────────────────────────
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(iconColor).frame(width: 30, height: 30)
                    Image(systemName: icon).luminaFont(size: 13).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).luminaFont(size: 15).foregroundColor(.organicForeground)
                    Text(value).luminaFont(size: 12).foregroundColor(.organicMutedFg)
                }
                Spacer()
                Image(systemName: "chevron.right").luminaFont(size: 12).foregroundColor(Color.organicBorder)
            }
            .padding(.horizontal, 16).padding(.vertical, 11).background(Color.organicCard)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: WellnessSnapshot
// ─────────────────────────────────────────────────────────────────────────────
struct WellnessSnapshot: View {
    let metrics: EmotionalMetrics
    var items: [(String, Int, Color)] {[
        ("Wellness", metrics.wellness, Color.organicPrimary),
        ("Clarity",  metrics.clarity,  Color.organicSecondary),
        ("Calm",     metrics.calm,     Color(hex: 0x4A90E2)),
        ("Energy",   metrics.energy,   Color(hex: 0xD97706)),
    ]}
    var body: some View {
        VStack(spacing: 10) {
            ForEach(items, id: \.0) { label, value, color in
                HStack(spacing: 12) {
                    Text(label)
                        .luminaFont(size: 13, weight: .semibold).foregroundColor(.organicForeground)
                        .frame(width: 68, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.organicMuted)
                            Capsule().fill(color)
                                .frame(width: geo.size.width * CGFloat(value) / 100)
                                .animation(.easeInOut(duration: 0.9), value: value)
                        }
                    }.frame(height: 8)
                    Text("\(value)%")
                        .luminaFont(size: 12, weight: .black).foregroundColor(color)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .padding(16).background(Color.organicCard).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.organicBorder.opacity(0.4), lineWidth: 1))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: SessionHistoryRow
// ─────────────────────────────────────────────────────────────────────────────
struct SessionHistoryRow: View {
    let session: ChatSession
    let therapist: Therapist
    let action: () -> Void
    var accent: Color { Color(hex: therapist.accentHex) }

    var timeAgo: String {
        let diff = Date().timeIntervalSince1970 - session.lastUpdated
        if diff < 3600  { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                TherapistAvatarMark(
                    name: therapist.name,
                    accent: accent,
                    size: 44,
                    radius: 17
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(therapist.name).luminaFont(size: 14, weight: .bold).foregroundColor(.organicForeground)
                        Spacer()
                        Text(timeAgo).luminaFont(size: 10).foregroundColor(.organicMutedFg)
                    }
                    Text(session.lastMessagePreview).luminaFont(size: 12).foregroundColor(.organicMutedFg).lineLimit(1)
                    Text("\(session.messageCount) messages exchanged").luminaFont(size: 10, weight: .semibold).foregroundColor(accent)
                }
            }
            .padding(14).background(Color.organicCard).cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.organicBorder.opacity(0.35), lineWidth: 1))
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: AchievementBadge
// ─────────────────────────────────────────────────────────────────────────────
struct AchievementBadge: View {
    let emoji: String
    let title: String
    let unlocked: Bool
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(unlocked ? Color.organicPrimary.opacity(0.12) : Color.organicMuted)
                    .frame(width: 56, height: 56)
                Text(emoji).luminaFont(size: 26).opacity(unlocked ? 1 : 0.25).grayscale(unlocked ? 0 : 1)
                if unlocked { Circle().stroke(Color.organicPrimary.opacity(0.3), lineWidth: 2).frame(width: 56, height: 56) }
            }
            Text(title)
                .luminaFont(size: 9, weight: .bold)
                .foregroundColor(unlocked ? .organicForeground : .organicBorder)
                .multilineTextAlignment(.center).frame(width: 64)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: GoalProgressRow
// ─────────────────────────────────────────────────────────────────────────────
struct GoalProgressRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let progress: Double
    let color: Color
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(iconColor.opacity(0.1)).frame(width: 36, height: 36)
                Image(systemName: icon).luminaFont(size: 14).foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title).luminaFont(size: 13, weight: .semibold).foregroundColor(.organicForeground)
                    Spacer()
                    Text("\(Int(min(1, progress) * 100))%").luminaFont(size: 11, weight: .black).foregroundColor(color)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.organicMuted)
                        Capsule().fill(color)
                            .frame(width: geo.size.width * min(1, progress))
                            .animation(.easeInOut(duration: 0.8), value: progress)
                    }
                }.frame(height: 5)
                Text(subtitle).luminaFont(size: 11).foregroundColor(.organicMutedFg)
            }
        }
        .padding(14).background(Color.organicCard).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.organicBorder.opacity(0.35), lineWidth: 1))
    }
}
