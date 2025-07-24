import SwiftUI
import SDWebImageSwiftUI

struct AmiibosByCategoryView: View {
    let category: String
    let fetchAmiibos: (String) -> [Amiibo]
    @State private var selectedAmiibo: Amiibo?
    @EnvironmentObject var service: AmiiboService

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(fetchAmiibos(category)) { amiibo in
                    // Find index for consistent reference to full data
                    if let index = service.allAmiibos.firstIndex(where: { $0.id == amiibo.id }) {
                        amiiboRow(service.allAmiibos[index])
                            .onTapGesture {
                                selectedAmiibo = service.allAmiibos[index]
                            }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
        .navigationTitle(category)
        .sheet(item: $selectedAmiibo) { amiibo in
            AmiiboDetailView(amiibo: amiibo)
                .environmentObject(service)
        }
    }

    @ViewBuilder
    private func amiiboRow(_ amiibo: Amiibo) -> some View {
        HStack {
            WebImage(url: amiibo.imageURL)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(amiibo.name)
                    .font(.headline)
                Text(amiibo.character)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                if service.currentUsername == nil {
                    service.currentUsername = "localUser"
                }
                Task {
                    await service.toggleOwned(for: amiibo)
                }
            } label: {
                Image(systemName: service.isOwned(amiibo) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(service.isOwned(amiibo) ? .white : .gray)
                    .padding(6)
                    .background(service.isOwned(amiibo) ? Color.green : Color.clear)
                    .cornerRadius(6)
            }
            .buttonStyle(ConditionalGlassButtonStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
