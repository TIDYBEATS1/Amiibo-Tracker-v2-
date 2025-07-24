import SwiftUI
import SDWebImageSwiftUI

struct MyCollectionView: View {
    @EnvironmentObject var service: AmiiboService
    @State private var selectedAmiibo: Amiibo?

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                if service.ownedAmiibos.isEmpty {
                    Text("You don’t own any Amiibos yet.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(service.ownedAmiibos) { amiibo in
                                amiiboRow(amiibo)
                                    .onTapGesture {
                                        selectedAmiibo = amiibo
                                    }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("My Collection")
            .sheet(item: $selectedAmiibo) { amiibo in
                AmiiboDetailView(amiibo: amiibo)
                    .environmentObject(service)
            }
            .task {
                if let username = service.currentUsername {
                    await service.loadOwnedAmiibosLocally(for: username)
                } else {
                    service.currentUsername = "localUser"
                }
            }
            .onChange(of: service.currentUsername) { newUsername in
                Task {
                    if let username = newUsername {
                        await service.loadOwnedAmiibosLocally(for: username)
                    } else {
                        service.clearOwnedAmiibos()
                    }
                }
            }
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
                Text(amiibo.series ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                if service.currentUsername == nil {
                    service.currentUsername = "localUser" // or prompt for username
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

#Preview {
    MyCollectionView()
        .environmentObject(AmiiboService())
}
