#if os(macOS)
import SwiftUI
import SDWebImageSwiftUI
import AppKit

struct AllAmiiboView_mac: View {
    @EnvironmentObject var service: AmiiboService
    @State private var selectedAmiibo: Amiibo?
    @Binding var searchText: String
    @Binding var sortOption: SortOption

    var ownedCount: Int {
        filteredAmiibos.filter { service.isOwned($0) }.count
    }
    var ownedAmiiboIDs: Set<String> {
        Set(service.ownedAmiibos.map { $0.id })
    } 
    func relevanceScore(for amiibo: Amiibo, search: String) -> Int {
        let name = amiibo.name.lowercased()
        let search = search.lowercased()

        if !search.isEmpty {
            if name == search { return 100 }
            if name.hasPrefix(search) { return 80 }
            if name.contains(search) { return 60 }
            let gameMatches = allGameNames(for: amiibo).filter {
                $0 == search || $0.hasPrefix(search) || $0.contains(search)
            }
            if !gameMatches.isEmpty { return 40 }
            return 0
        } else {
            return 0
        }
    }
    func allGameNames(for amiibo: Amiibo) -> [String] {
        guard let usage = service.usage(for: amiibo.id) else { return [] }
        let switchGames = usage.gamesSwitch.map { $0.gameName.lowercased() }
        let games3DS = usage.games3DS.map { $0.gameName.lowercased() }
        let gamesWiiU = usage.gamesWiiU.map { $0.gameName.lowercased() }
        return switchGames + games3DS + gamesWiiU
    }

    // Filter Amiibos by searchText matching name OR any game name
    var filteredAmiibos: [Amiibo] {
        var result = service.filteredAmiibos

        if !searchText.isEmpty {
            result = result.filter { amiibo in
                amiibo.name.localizedCaseInsensitiveContains(searchText) ||
                allGameNames(for: amiibo).contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
            result = result.sorted {
                relevanceScore(for: $0, search: searchText) > relevanceScore(for: $1, search: searchText)
            }
        } 
        return result
    }

    private let dateCache = ReleaseDateCache()

    final class ReleaseDateCache {
        private var cache: [String: Date] = [:]

        func getDate(for amiibo: Amiibo) -> Date? {
            if let cached = cache[amiibo.id] {
                return cached
            }
            let date = parseDate(from: amiibo.release?.na ?? "")
            if let date = date {
                cache[amiibo.id] = date
            }
            return date
        }

        private func parseDate(from dateString: String) -> Date? {
            guard !dateString.isEmpty else { return nil }
            let formats = [
                "MM/dd/yyyy",
                "yyyy-MM-dd",
                "MMMM d, yyyy",
                "MMM d, yyyy",
                "yyyy/MM/dd"
            ]
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")

            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            return nil
        }
    }

    var sortedAmiibos: [Amiibo] {
        switch sortOption {
        case .relevance:
            return filteredAmiibos.sorted {
                relevanceScore(for: $0, search: searchText) > relevanceScore(for: $1, search: searchText)
            }
        case .releaseOldest:
            return filteredAmiibos.sorted {
                (dateCache.getDate(for: $0) ?? .distantFuture) < (dateCache.getDate(for: $1) ?? .distantFuture)
            }
        case .releaseNewest:
            return filteredAmiibos.sorted {
                (dateCache.getDate(for: $0) ?? .distantPast) > (dateCache.getDate(for: $1) ?? .distantPast)
            }
        case .owned:
            return filteredAmiibos.sorted {
                (service.isOwned($0) ? 0 : 1) < (service.isOwned($1) ? 0 : 1)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("All Amiibo")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.primary)
                        .padding(.leading, 16)

                    Spacer()

                    Text("\(ownedCount) / \(filteredAmiibos.count)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 16)
                }
                .padding(.vertical, 8)

                // Amiibo List
                List(sortedAmiibos, id: \.id) { amiibo in
                    HStack(spacing: 12) {
                        if let url = amiibo.imageURL {
                            WebImage(url: url)
                                .onSuccess { _, _, cacheType in
                                    print("✅ \(amiibo.name) image loaded from \(cacheType == .none ? "network" : "cache")")
                                }
                                .onFailure { error in
                                    print("❌ Failed to load \(amiibo.name): \(error.localizedDescription)")
                                }
                                .resizable()
                                .indicator(.activity)
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                        } else {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.gray)
                        }

                        Text(amiibo.name)
                            .font(.headline)
                            .foregroundColor(.primary)

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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedAmiibo = amiibo
                    }
                }
                .listStyle(.plain)
                .padding(.bottom, 0)
            }
            .sheet(item: $selectedAmiibo) { amiibo in
                AmiiboDetailView(amiibo: amiibo)
                    .environmentObject(service)
            }
        }
    }
}
#endif
