import SwiftUI
import SDWebImageSwiftUI

enum AmiiboSelection: Hashable {
    case category(String)
    case subcategory(String)
}

struct AmiiboSplitView: View {
    @EnvironmentObject var service: AmiiboService
    
    @State private var selection: AmiiboSelection? = nil
    @State private var detailAmiibo: Amiibo? = nil
    @State private var searchText = ""
    @State private var selectedAmiibo: Amiibo?

    var sortedCategories: [String] {
        service.groupedBySeries.keys
            .filter { $0.lowercased() != "owned" }  // Exclude "Owned" category
            .sorted()
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(sortedCategories, id: \.self) { category in
                    if category == "Animal Crossing" {
                        DisclosureGroup(category) {
                            ForEach(service.animalCrossingSubcategoryMap.keys.sorted(), id: \.self) { subcat in
                                Text(subcat)
                                    .tag(AmiiboSelection.subcategory(subcat))
                            }
                        }
                        .tag(AmiiboSelection.category(category))
                    } else {
                        Text(category)
                            .tag(AmiiboSelection.category(category))
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
            .navigationTitle("Categories")
        } detail: {
            Group {
                switch selection {
                case .subcategory(let subcat):
                    AmiiboListView(amiibos: filteredAmiibos(forSubcategory: subcat))
                        .navigationTitle(subcat)
                case .category(let category):
                    AmiiboListView(amiibos: filteredAmiibos(forCategory: category))
                        .navigationTitle(category)
                case .none:
                    Text("Select a category")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .sheet(item: $detailAmiibo) { amiibo in
                AmiiboDetailView(amiibo: amiibo)
                    .environmentObject(service)
            }
        }
    }

    // MARK: Amiibo List View
    @ViewBuilder
    func AmiiboListView(amiibos: [Amiibo]) -> some View {
        List {
            ForEach(amiibos, id: \.id) { amiibo in
                if let index = service.allAmiibos.firstIndex(where: { $0.id == amiibo.id }) {
                    HStack {
                        WebImage(url: service.allAmiibos[index].imageURL)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(service.allAmiibos[index].name)
                                .font(.headline)
                            Text(service.allAmiibos[index].character)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            Task {
                                await service.toggleOwned(for: service.allAmiibos[index])
                            }
                        } label: {
                            Image(systemName: service.allAmiibos[index].isOwned ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(service.allAmiibos[index].isOwned ? .white : .gray)
                                .padding(6)
                                .background(service.allAmiibos[index].isOwned ? Color.green : Color.clear)
                                .cornerRadius(6)
                        }
                        .buttonStyle(ConditionalGlassButtonStyle())

                        Button {
                            detailAmiibo = service.allAmiibos[index]
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .imageScale(.large)
                        }
                        .buttonStyle(ConditionalGlassButtonStyle())
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        detailAmiibo = service.allAmiibos[index]
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: Filtering
    func filteredAmiibos(forSubcategory subcategory: String) -> [Amiibo] {
        let ids = service.animalCrossingSubcategoryMap[subcategory] ?? []
        print("Subcategory '\(subcategory)' has \(ids.count) Amiibo IDs")

        func normalizeID(_ id: String) -> String {
            id.trimmingCharacters(in: .whitespacesAndNewlines)
              .lowercased()
              .replacingOccurrences(of: "0x", with: "")
        }
        
        let normalizedIDs = Set(ids.map(normalizeID))
        
        let baseList = service.allAmiibos.filter { amiibo in
            let normalizedAmiiboID = normalizeID(amiibo.id)
            let match = normalizedIDs.contains(normalizedAmiiboID)
            if match {
                print("Matched Amiibo: \(amiibo.name) with ID: \(amiibo.id)")
            }
            return match
        }
        
        return filterAmiibos(baseList)
    }

    func filteredAmiibos(forCategory category: String) -> [Amiibo] {
        let baseList = service.groupedBySeries[category] ?? []
        return filterAmiibos(baseList)
    }

    func filterAmiibos(_ list: [Amiibo]) -> [Amiibo] {
        if searchText.isEmpty { return list }
        let query = searchText.lowercased()
        return list.filter {
            $0.name.lowercased().contains(query) || $0.character.lowercased().contains(query)
        }
    }
}
