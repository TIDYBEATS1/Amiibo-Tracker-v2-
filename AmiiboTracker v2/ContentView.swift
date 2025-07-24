import SwiftUI
import Firebase
import FirebaseAuth

enum AppTab: Hashable {
    case all, categories, myCollection, settings, search
}

struct ContentView: View {
    @StateObject private var authManager: LocalAuthManager
    @StateObject private var service: AmiiboService
    
    @State private var selectedTab: AppTab = .all
    @State private var searchText = ""
    @State private var showLogin = true
    @State private var sortOption: SortOption = .relevance
    
    init(authManager: LocalAuthManager, service: AmiiboService) {
        _authManager = StateObject(wrappedValue: authManager)
        _service = StateObject(wrappedValue: service)
    }
    
    var body: some View {
        Group {
            if authManager.isSignedIn {
                TabView(selection: $selectedTab) {
                    Tab("All", systemImage: "square.grid.2x2", value: AppTab.all) {
                        platformAmiiboView()
                            .environmentObject(service)
                    }
                    
                    Tab("Categories", systemImage: "folder", value: AppTab.categories) {
                        platformCategories()
                            .environmentObject(service)
                    }
                    
                    Tab("My Collection", systemImage: "checkmark.seal", value: AppTab.myCollection) {
                        MyCollectionView()
                            .environmentObject(service)
                            .environmentObject(authManager) // Make sure it's passed in

                    }
                    
                    Tab("Settings", systemImage: "gear", value: AppTab.settings) {
                        #if os(macOS)
                        SettingsViewMac(localAuth: authManager)
                            .environmentObject(authManager)
                            .environmentObject(service)
                        #else
                        SettingsView(localAuth: authManager)
                            .environmentObject(authManager)
                            .environmentObject(service)
                        #endif
                    }
#if os(iOS)
                    Tab(value: AppTab.search, role: .search) {
                        AllAmiiboView(searchText: $searchText, sortOption: $sortOption)
                            .environmentObject(service)
                            .navigationTitle("Search")
                            .navigationBarTitleDisplayMode(.inline)
                            .searchable(text: $searchText)
                    }
#endif
                }
                .environmentObject(service)
                .environmentObject(authManager)
                .task {
                    await service.fetchAmiibos(force: false)
                    service.prefetchImagesIfNeeded()
                }
#if os(macOS)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                            TextField("Search Amiibo", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(minWidth: 250, maxWidth: 300)
                            
                                .padding(.vertical, 8)

                                Picker("Sort by", selection: $sortOption) {
                                    Text("Relevance").tag(SortOption.relevance)
                                    Text("Oldest").tag(SortOption.releaseOldest)
                                    Text("Newest").tag(SortOption.releaseNewest)
                                    Text("Owned").tag(SortOption.owned)
                                }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 140)
                        }
                        .padding(.horizontal, 8)
                    }
                }
#endif
                
            } else {
                if showLogin {
                    LoginView(
                        authManager: authManager,
                        service: authManager.service,
                        onSwitchToRegister: { showLogin = false }
                    )
                } else {
                    RegisterView(
                        authManager: authManager,
                        service: authManager.service,
                        onSwitchToLogin: { showLogin = true }
                    )
                }
            }
        }
        .animation(.default, value: authManager.isSignedIn)
    }
    
    @ViewBuilder
    func platformAmiiboView() -> some View {
        #if os(macOS)
        AllAmiiboView_mac(searchText: $searchText, sortOption: $sortOption)
#else
        AllAmiiboView(searchText: $searchText, sortOption: $sortOption)
        #endif
    }
    func platformCategories() -> some View {
        #if os(macOS)
        AmiiboSplitView()
        #else
        CategoriesView()
        #endif
    }
}

#Preview {
    ContentView(authManager: LocalAuthManager(service: AmiiboService()), service: AmiiboService())
}
