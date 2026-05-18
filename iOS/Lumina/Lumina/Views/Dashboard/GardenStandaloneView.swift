import SwiftUI

// MARK: - Garden as a standalone tab
struct GardenStandaloneView: View {
    var body: some View {
        GardenTabView()
            .background(Color(hex: 0xFFF6DF).ignoresSafeArea())
    }
}
