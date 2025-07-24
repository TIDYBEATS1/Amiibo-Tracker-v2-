import SwiftUI
import SDWebImageSwiftUI

struct LoadingWebImage: View {
    let url: URL?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .frame(width: 64, height: 64)
            }
            WebImage(url: url)
                .onSuccess { _, _, cacheType in
                    DispatchQueue.main.async {
                        isLoading = false
                        if cacheType != .none {
                            print("✅ Loaded image from cache for URL: \(url?.absoluteString ?? "unknown")")
                        } else {
                            print("📡 Loaded image from network for URL: \(url?.absoluteString ?? "unknown")")
                        }
                    }
                }
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .cornerRadius(12)
                .opacity(isLoading ? 0 : 1)
        }
    }
}

struct AllAmiiboView: View {
    @EnvironmentObject var service: AmiiboService
    @State private var selectedAmiibo: Amiibo?
    @Binding var searchText: String
    var dateCache = ReleaseDateCache()
    @State private var parsedReleaseDates: [String: Date] = [:]
    @Binding var sortOption: SortOption
    @State private var selectedSort: SortOption1 = .relevance

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

    var ownedCount: Int {
        service.filteredAmiibos.filter { service.isOwned($0) }.count
    }

    var filteredAmiibos: [Amiibo] {
        guard !searchText.isEmpty else {
            return service.filteredAmiibos
        }

        let query = searchText.lowercased()

        return service.filteredAmiibos.filter { amiibo in
            let nameMatch = amiibo.name.lowercased().contains(query)
            let characterMatch = amiibo.character.lowercased().contains(query) ?? false
            let gameMatch = allGameNames(for: amiibo).contains { $0.contains(query) }

            return nameMatch || characterMatch || gameMatch
        }
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
    func allGameNames(for amiibo: Amiibo) -> [String] {
        guard let usage = service.usage(for: amiibo.id) else { return [] }
        let switchGames = usage.gamesSwitch.map { $0.gameName.lowercased() }
        let games3DS = usage.games3DS.map { $0.gameName.lowercased() }
        let gamesWiiU = usage.gamesWiiU.map { $0.gameName.lowercased() }

        return switchGames + games3DS + gamesWiiU
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("All Amiibo")
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)
                        .padding(.leading, 16)

                    Spacer()

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(ownedCount) / \(filteredAmiibos.count)")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            GeometryReader { geo in
                                let progress = filteredAmiibos.isEmpty ? 0 : CGFloat(ownedCount) / CGFloat(filteredAmiibos.count)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.green)
                                            .frame(width: geo.size.width * progress, height: 4),
                                        alignment: .leading
                                    )
                            }
                            .frame(height: 4)
                            .frame(width: 80)
                        }

                        SortPickerView(sortOption: $selectedSort)
                            .frame(width: 36, height: 36)
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
                
            }
                .padding(.horizontal)
                
                Spacer()

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(sortedAmiibos) { amiibo in
                            amiiboRow(amiibo)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom)
                }
            }
            .sheet(item: $selectedAmiibo) { amiibo in
                AmiiboDetailView(amiibo: amiibo)
                    .environmentObject(service)
            }
        }
    

    @ViewBuilder
    private func amiiboRow(_ amiibo: Amiibo) -> some View {
        HStack {
            LoadingWebImage(url: amiibo.imageURL)

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
                    service.currentUsername = "localUser"
                }
                Task {
                    await service.toggleOwned(for: amiibo)
                }
            } label: {
                let owned = service.isOwned(amiibo)
                Image(systemName: owned ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(owned ? .white : .gray)
                    .padding(6)
                    .background(owned ? Color.green : Color.clear)
                    .cornerRadius(6)
            }
            .buttonStyle(ConditionalGlassButtonStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onTapGesture {
            selectedAmiibo = amiibo
        }
    }
}
