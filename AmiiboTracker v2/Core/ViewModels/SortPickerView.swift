import SwiftUI

enum SortOption1: String, CaseIterable, Hashable {
    case relevance, oldest, newest, owned

    var label: String {
        switch self {
        case .relevance: return "Relevance"
        case .oldest: return "Oldest"
        case .newest: return "Newest"
        case .owned: return "Owned"
        }
    }
}

struct SortPickerView: View {
    @Binding var sortOption: SortOption1

    var body: some View {
        HStack {
            Spacer() // Push button to right

            Menu {
                ForEach(SortOption1.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        Label(option.label, systemImage: sortOption == option ? "checkmark" : "")
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(ConditionalGlassButtonStyle())
        }
        .padding(.horizontal)
    }
}
