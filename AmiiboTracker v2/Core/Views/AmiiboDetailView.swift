import SwiftUI
import SDWebImageSwiftUI

struct AmiiboDetailView: View {
    let amiibo: Amiibo
    @EnvironmentObject var service: AmiiboService
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Color.gray.opacity(0.2)
                        .frame(width: 0, height: 0)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    if let imageURL = amiibo.imageURL {
                        WebImage(url: imageURL)
                            .resizable()
                            .indicator(.activity)
                            .scaledToFit()
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(Color.gray)
                    }
                }

                Text("**Name:** \(amiibo.name)")
                Text("**Amiibo Series:** \(amiibo.series)")
                Text("**Game Series:** \(amiibo.gameSeries ?? "N/A")")
                Text("**Type:** \(amiibo.type)")
                Text("**Character:** \(amiibo.character)")

                Divider()

                if let release = amiibo.release {
                    if let na = release.na {
                        Text("**NA Release:** \(formattedDate(na))")
                    }
                    if let eu = release.eu {
                        Text("**EU Release:** \(formattedDate(eu))")
                    }
                    if let jp = release.jp {
                        Text("**JP Release:** \(formattedDate(jp))")
                    }
                    if let au = release.au {
                        Text("**AU Release:** \(formattedDate(au))")
                    }
                }

                Divider()

                Text("Compatible Games")
                    .font(.title2.bold())
                    .buttonStyle(ConditionalGlassButtonStyle())

                TextField("Search compatible games", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding([.horizontal, .bottom])

                if let usage = service.usageInfo[normalizeID(amiibo.id)] {
                    GameUsageSection(title: "Switch", games: filtered(usage.gamesSwitch))
                    GameUsageSection(title: "3DS", games: filtered(usage.games3DS))
                    GameUsageSection(title: "Wii U", games: filtered(usage.gamesWiiU))
                
                } else {
                    Text("No usage information available.")
                        .foregroundColor(Color.gray)
                        .italic()
                }
            }
            .padding()
        }
        .navigationTitle(amiibo.name)
        .onAppear {
            print("🔍 Checking usage for Amiibo ID: \(normalizeID(amiibo.id)) - \(amiibo.name)")
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    func filtered(_ games: [AmiiboGameUsage]?) -> [AmiiboGameUsage] {
        guard let games = games else { return [] }
        if searchText.isEmpty { return games }
        return games.filter { $0.gameName.localizedCaseInsensitiveContains(searchText) }
    }
    
    func normalizeID(_ id: String) -> String {
        id.hasPrefix("0x") ? String(id.dropFirst(2)) : id
    }

    func formattedDate(_ isoDateString: String) -> String {
        guard let date = isoDateFormatter.date(from: isoDateString) else { return isoDateString }
        return displayDateFormatter.string(from: date)
    }
}

struct GameUsageSection: View {
    let title: String
    let games: [AmiiboGameUsage]

    var platformIcon: String {
        switch title {
        case "Switch": return "gamecontroller.fill"
        case "3DS": return "gamecontroller"
        case "Wii U": return "tv"
        default: return "questionmark.circle"
        }
    }

    var body: some View {
        if !games.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: platformIcon)
                        .foregroundColor(.accentColor)
                    Text(title)
                        .font(.headline)
                }

                ForEach(games, id: \.gameName) { game in
                    VStack(alignment: .leading) {
                        Text(game.gameName).bold()
                        ForEach(game.amiiboUsage, id: \.usage) { usageEntry in
                            Text("• \(usageEntry.usage)")
                                .font(.subheadline)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding(.top, 8)
        }
    }
}

private let isoDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
}()

private let displayDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()
