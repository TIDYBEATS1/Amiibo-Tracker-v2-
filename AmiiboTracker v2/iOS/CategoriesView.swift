import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var service: AmiiboService
    @State private var expandedCategory: String? = nil
    @State private var selectedAmiibo: Amiibo?

    var sortedCategories: [String] {
        Array(service.groupedBySeries.keys).sorted()
    }

    var body: some View {
        Group {
            #if os(macOS)
            NavigationView {
                categoryList
                    .listStyle(SidebarListStyle())
                    .frame(minWidth: 250)
                    .navigationTitle("Categories")

                Text("Select a category")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #else
            NavigationStack {
                categoryList
                    .listStyle(InsetGroupedListStyle())
                    .navigationTitle("Categories")
            }
            #endif
        }
        .sheet(item: $selectedAmiibo) { amiibo in
            AmiiboDetailView(amiibo: amiibo)
                .environmentObject(service)
        }
    }

    private var categoryList: some View {
        List {
            ForEach(sortedCategories, id: \.self) { category in
                if category == "Animal Crossing" {
                    // Expandable header button
                    Button(action: {
                        withAnimation {
                            expandedCategory = (expandedCategory == category) ? nil : category
                        }
                    }) {
                        HStack {
                            Text(category)
                                .font(.headline)
                            Spacer()
                            Image(systemName: expandedCategory == category ? "chevron.down" : "chevron.right")
                                .foregroundColor(.accentColor)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Subcategories and "View All"
                    if expandedCategory == category {
                        NavigationLink(
                            destination: AmiibosByCategoryView(
                                category: category,
                                fetchAmiibos: { _ in service.groupedBySeries[category] ?? [] }
                            )
                        ) {
                            Text("View All \(category)")
                                .fontWeight(.medium)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.leading, 20)
                        .padding(.vertical, 4)

                        ForEach(service.animalCrossingSubcategoryMap.keys.sorted(), id: \.self) { subcat in
                            NavigationLink(
                                destination: AmiibosByCategoryView(
                                    category: subcat,
                                    fetchAmiibos: { _ in
                                        service.amiibos(forIDs: service.animalCrossingSubcategoryMap[subcat] ?? [])
                                    }
                                )
                            ) {
                                Text(subcat)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.leading, 20)
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    NavigationLink(
                        destination: AmiibosByCategoryView(
                            category: category,
                            fetchAmiibos: { _ in service.groupedBySeries[category] ?? [] }
                        )
                    ) {
                        Text(category)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
    }
}
