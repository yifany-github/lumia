import SwiftUI

// MARK: - Garden as a standalone tab
struct GardenStandaloneView: View {
    var body: some View {
        GardenTabView()
            .background(Color(hex: 0xFFF6DF).ignoresSafeArea())
            .toolbarBackground(Color(hex: 0xF6EFD8).opacity(0.94), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(.light, for: .tabBar)
    }
}
