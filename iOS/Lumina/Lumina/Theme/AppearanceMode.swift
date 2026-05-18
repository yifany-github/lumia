import SwiftUI
import UIKit

enum LuminaAppearanceMode: String, CaseIterable, Identifiable, Hashable {
    case system
    case light
    case dark

    static let storageKey = "lumina.appearanceMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var detail: String {
        switch self {
        case .system: return "Matches iOS appearance"
        case .light: return "Always light"
        case .dark: return "Always dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    static func normalized(_ rawValue: String) -> LuminaAppearanceMode {
        LuminaAppearanceMode(rawValue: rawValue) ?? .system
    }

    @MainActor
    static func applyInterfaceStyleOverride(_ rawValue: String) {
        applyInterfaceStyleOverride(normalized(rawValue))
    }

    @MainActor
    static func applyInterfaceStyleOverride(_ mode: LuminaAppearanceMode) {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { window in
                window.overrideUserInterfaceStyle = mode.interfaceStyle
            }
    }
}

struct LuminaAppearancePickerRow: View {
    @Binding var selectionRawValue: String

    private var selection: Binding<LuminaAppearanceMode> {
        Binding(
            get: { LuminaAppearanceMode.normalized(selectionRawValue) },
            set: { selectionRawValue = $0.rawValue }
        )
    }

    private var selectedMode: LuminaAppearanceMode {
        LuminaAppearanceMode.normalized(selectionRawValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.organicPrimary)
                        .frame(width: 30, height: 30)

                    Image(systemName: selectedMode.icon)
                        .luminaFont(size: 13, weight: .semibold)
                        .foregroundColor(.organicPrimaryFg)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Appearance")
                        .luminaFont(size: 15)
                        .foregroundColor(.organicForeground)

                    Text(selectedMode.detail)
                        .luminaFont(size: 12)
                        .foregroundColor(.organicMutedFg)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            Picker("Appearance", selection: selection) {
                ForEach(LuminaAppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .tint(.organicPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color.organicCard)
    }
}
